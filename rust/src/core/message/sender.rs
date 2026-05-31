use crate::core::connection::manager::ConnectionManager;
use crate::core::file::uploader::FileUploader;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::infra::database::conversation_dao::ConversationDao;
use crate::infra::database::MessageDao;
use crate::infra::database::models::LocalChatLog;
use crate::protocol::sdkws::{MsgData, UserSendMsgResp};
use prost::Message;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::path::Path;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::sync::mpsc;
use tracing::{error, info, debug};

#[derive(Clone, Serialize, Deserialize)]
pub struct SendMsgResp {
    #[serde(rename = "serverMsgID")]
    pub server_msg_id: String,
    #[serde(rename = "clientMsgID")]
    pub client_msg_id: String,
    #[serde(rename = "sendTime")]
    pub send_time: i64,
}

#[derive(Clone, Debug)]
pub struct PendingMessage {
    pub client_msg_id: String,
    pub send_id: String,
    pub recv_id: String,
    pub group_id: String,
    pub sender_platform_id: i32,
    pub sender_nickname: String,
    pub sender_face_url: String,
    pub session_type: i32,
    pub msg_from: i32,
    pub content_type: i32,
    pub content: String,
}

struct MessageChannels {
    text_tx: mpsc::Sender<PendingMessage>,
    text_rx: Option<mpsc::Receiver<PendingMessage>>,
    media_tx: mpsc::Sender<PendingMessage>,
    media_rx: Option<mpsc::Receiver<PendingMessage>>,
}

pub struct MessageSender {
    connection: Arc<ConnectionManager>,
    event_bus: Arc<EventBus>,
    channels: MessageChannels,
    user_id: String,
    platform_id: i32,
    message_dao: Arc<MessageDao>,
    conversation_dao: Arc<ConversationDao>,
    file_uploader: Arc<FileUploader>,
}

impl MessageSender {
    pub fn new(
        connection: Arc<ConnectionManager>,
        event_bus: Arc<EventBus>,
        user_id: String,
        platform_id: i32,
        message_dao: Arc<MessageDao>,
        conversation_dao: Arc<ConversationDao>,
        file_uploader: Arc<FileUploader>,
    ) -> Self {
        let (text_tx, text_rx) = mpsc::channel(100);
        let (media_tx, media_rx) = mpsc::channel(100);

        Self {
            connection,
            event_bus,
            channels: MessageChannels {
                text_tx,
                text_rx: Some(text_rx),
                media_tx,
                media_rx: Some(media_rx),
            },
            user_id,
            platform_id,
            message_dao,
            conversation_dao,
            file_uploader,
        }
    }

    pub fn start_workers(&mut self) {
        let text_rx = self.channels.text_rx.take().expect("text_rx already taken");
        let media_rx = self.channels.media_rx.take().expect("media_rx already taken");
        let sender_clone = Arc::new(self.clone_for_worker());
        let sender_clone_for_media = sender_clone.clone();

        tokio::spawn(async move {
            let mut rx = text_rx;
            while let Some(msg) = rx.recv().await {
                let sender = sender_clone.clone();
                tokio::spawn(async move {
                    match sender.do_send_message(msg).await {
                        Ok(resp) => {
                            info!("消息发送成功: client_msg_id={}", resp.client_msg_id);
                        }
                        Err(e) => {
                            error!("消息发送失败: {}", e);
                        }
                    }
                });
            }
        });

        tokio::spawn(async move {
            let mut rx = media_rx;
            while let Some(msg) = rx.recv().await {
                let sender = sender_clone_for_media.clone();
                tokio::spawn(async move {
                    match sender.do_send_message(msg).await {
                        Ok(resp) => {
                            info!("媒体消息发送成功: client_msg_id={}", resp.client_msg_id);
                        }
                        Err(e) => {
                            error!("媒体消息发送失败: {}", e);
                        }
                    }
                });
            }
        });

        info!("消息发送 Workers 已启动");
    }

    pub async fn send_message(&self, msg: PendingMessage) -> Result<()> {
        match msg.content_type {
            101 | 106 | 113 | 114 | 115 | 117 | 118 => {
                self.channels.text_tx.send(msg).await
                    .map_err(|e| SdkError::message_send(format!("send text message failed: {}", e)))
            }
            _ => {
                self.channels.media_tx.send(msg).await
                    .map_err(|e| SdkError::message_send(format!("send media message failed: {}", e)))
            }
        }
    }

    fn conversation_id_for_msg(&self, msg: &PendingMessage) -> String {
        if msg.session_type == 1 {
            // single chat: si_{send_id}_{recv_id}, ensure sorted order
            let mut ids = vec![msg.send_id.clone(), msg.recv_id.clone()];
            ids.sort();
            format!("si_{}_{}", ids[0], ids[1])
        } else {
            // group chat: g_{group_id}
            format!("g_{}", msg.group_id)
        }
    }

    async fn persist_sent_message(&self, msg: &PendingMessage, resp: &UserSendMsgResp) -> Result<()> {
        let conversation_id = self.conversation_id_for_msg(msg);

        let content_str = msg.content.clone();

        let local_log = LocalChatLog {
            conversation_id: conversation_id.clone(),
            client_msg_id: resp.client_msg_id.clone(),
            server_msg_id: resp.server_msg_id.clone(),
            send_id: msg.send_id.clone(),
            recv_id: msg.recv_id.clone(),
            sender_platform_id: msg.sender_platform_id,
            sender_nick_name: msg.sender_nickname.clone(),
            sender_face_url: msg.sender_face_url.clone(),
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: content_str.clone(),
            is_read: 1,
            status: 1,
            seq: 0,
            send_time: resp.send_time,
            create_time: resp.send_time,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: msg.group_id.clone(),
        };

        self.message_dao.batch_insert(&[local_log]).await?;

        self.conversation_dao.update_after_sent_message(
            &conversation_id,
            &content_str,
            resp.send_time,
        ).await?;

        debug!("已持久化发送消息: client_msg_id={}, conv={}", resp.client_msg_id, conversation_id);
        Ok(())
    }

    /// 插入消息到本地数据库（发送前，Go SDK 对应 InsertMessage）
    async fn insert_message_before_send(&self, msg: &PendingMessage, send_time: i64) -> Result<()> {
        let conversation_id = self.conversation_id_for_msg(msg);

        let content_str = msg.content.clone();

        let local_log = LocalChatLog {
            conversation_id: conversation_id.clone(),
            client_msg_id: msg.client_msg_id.clone(),
            server_msg_id: String::new(),
            send_id: msg.send_id.clone(),
            recv_id: msg.recv_id.clone(),
            sender_platform_id: msg.sender_platform_id,
            sender_nick_name: msg.sender_nickname.clone(),
            sender_face_url: msg.sender_face_url.clone(),
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: content_str,
            is_read: 1,
            status: 1,
            seq: 0,
            send_time,
            create_time: send_time,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: msg.group_id.clone(),
        };

        self.message_dao.batch_insert(&[local_log]).await?;

        self.conversation_dao.update_after_sent_message(
            &conversation_id,
            &msg.content,
            send_time,
        ).await?;

        debug!("发送前插入消息: client_msg_id={}, conv={}", msg.client_msg_id, conversation_id);
        Ok(())
    }

    async fn do_send_message(&self, msg: PendingMessage) -> Result<SendMsgResp> {
        let send_time = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        let content = self.process_media_content(&msg).await?;

        self.insert_message_before_send(&msg, send_time).await?;

        let msg_data = MsgData {
            send_id: msg.send_id.clone(),
            recv_id: msg.recv_id.clone(),
            group_id: msg.group_id.clone(),
            client_msg_id: msg.client_msg_id.clone(),
            server_msg_id: String::new(),
            sender_platform_id: msg.sender_platform_id,
            sender_nickname: msg.sender_nickname.clone(),
            sender_face_url: msg.sender_face_url.clone(),
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: content.clone().into_bytes(),
            seq: 0,
            send_time,
            create_time: send_time,
            status: 0,
            is_read: false,
            options: std::collections::HashMap::new(),
            offline_push_info: None,
            at_user_id_list: vec![],
            attached_info: String::new(),
            ex: String::new(),
        };

        let resp: UserSendMsgResp = match self.connection
            .send_rpc(1003, &msg_data).await
        {
            Ok(r) => r,
            Err(e) => {
                self.message_dao.update_send_status(&msg.client_msg_id, 3).await?;
                self.event_bus.publish(SdkEvent::MessageSendFailed {
                    client_msg_id: msg.client_msg_id.clone(),
                    error: format!("{}", e),
                });
                return Err(SdkError::message_send(format!("send message via ws failed: {}", e)));
            }
        };

        if let Err(e) = self.message_dao.update_send_status(&msg.client_msg_id, 2).await {
            error!("更新发送状态失败: {}", e);
        }

        let conversation_id = self.conversation_id_for_msg(&msg);

        self.event_bus.publish(SdkEvent::MessageSent {
            client_msg_id: resp.client_msg_id.clone(),
            server_msg_id: resp.server_msg_id.clone(),
            send_time: resp.send_time,
            status: 2,
            conversation_id,
            send_id: msg.send_id.clone(),
            recv_id: msg.recv_id.clone(),
            group_id: msg.group_id.clone(),
            session_type: msg.session_type,
            content_type: msg.content_type,
            content: msg.content.clone(),
            sender_nickname: msg.sender_nickname.clone(),
            sender_face_url: msg.sender_face_url.clone(),
        });

        Ok(SendMsgResp {
            server_msg_id: resp.server_msg_id,
            client_msg_id: resp.client_msg_id,
            send_time: resp.send_time,
        })
    }

    async fn process_media_content(&self, msg: &PendingMessage) -> Result<String> {
        let media_types = [102, 103, 104, 105];
        if !media_types.contains(&msg.content_type) {
            return Ok(msg.content.clone());
        }

        let mut value: Value = match serde_json::from_str(&msg.content) {
            Ok(v) => v,
            Err(_) => return Ok(msg.content.clone()),
        };

        let source_path = match value.get("sourcePath").and_then(|v| v.as_str()) {
            Some(p) => p.to_string(),
            None => return Ok(msg.content.clone()),
        };

        let path = Path::new(&source_path);
        if !path.exists() {
            info!("sourcePath 文件不存在，跳过上传: {}", source_path);
            return Ok(msg.content.clone());
        }

        let file_name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();

        info!("开始上传媒体文件: content_type={}, path={}", msg.content_type, source_path);

        let upload_result = self.file_uploader.upload_file(&source_path, &file_name, None).await?;
        let url = upload_result.url;

        info!("媒体文件上传成功: url={}", url);

        if msg.content_type == 102 {
            let source_picture = json!({
                "url": url,
            });
            value["sourcePicture"] = source_picture;
        } else {
            value["sourceUrl"] = json!(url);
        }

        value.as_object_mut()
            .and_then(|map| map.remove("sourcePath"));

        let new_content = serde_json::to_string(&value)
            .unwrap_or_else(|_| msg.content.clone());

        Ok(new_content)
    }

    fn clone_for_worker(&self) -> Self {
        Self {
            connection: self.connection.clone(),
            event_bus: self.event_bus.clone(),
            channels: MessageChannels {
                text_tx: self.channels.text_tx.clone(),
                text_rx: None,
                media_tx: self.channels.media_tx.clone(),
                media_rx: None,
            },
            user_id: self.user_id.clone(),
            platform_id: self.platform_id,
            message_dao: self.message_dao.clone(),
            conversation_dao: self.conversation_dao.clone(),
            file_uploader: self.file_uploader.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;
    use crate::infra::http::client::HttpApiClient;
    use tokio_util::sync::CancellationToken;

    #[test]
    fn test_pending_message_creation() {
        let msg = PendingMessage {
            client_msg_id: "msg_123".to_string(),
            send_id: "user_1".to_string(),
            recv_id: "user_2".to_string(),
            group_id: String::new(),
            sender_platform_id: 1,
            sender_nickname: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: r#"{"text":"hello"}"#.to_string(),
        };

        assert_eq!(msg.client_msg_id, "msg_123");
        assert_eq!(msg.content_type, 101);
    }

    #[test]
    fn test_msg_data_serialization() {
        let msg_data = MsgData {
            send_id: "user_1".to_string(),
            recv_id: "user_2".to_string(),
            group_id: String::new(),
            client_msg_id: "msg_123".to_string(),
            server_msg_id: String::new(),
            sender_platform_id: 1,
            sender_nickname: "Test".to_string(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: r#"{"text":"hello"}"#.to_string().into_bytes(),
            seq: 0,
            send_time: 1234567890,
            create_time: 1234567890,
            status: 0,
            is_read: false,
            options: std::collections::HashMap::new(),
            offline_push_info: None,
            at_user_id_list: vec![],
            attached_info: String::new(),
            ex: String::new(),
        };

        let bytes = msg_data.encode_to_vec();
        assert!(!bytes.is_empty());

        let decoded = MsgData::decode(bytes.as_slice()).unwrap();
        assert_eq!(decoded.client_msg_id, "msg_123");
        assert_eq!(decoded.content_type, 101);
    }

    #[test]
    fn test_send_msg_resp_deserialization() {
        let json = r#"{"serverMsgID":"srv_123","clientMsgID":"cli_123","sendTime":1234567890}"#;
        let resp: SendMsgResp = serde_json::from_str(json).unwrap();
        assert_eq!(resp.server_msg_id, "srv_123");
        assert_eq!(resp.client_msg_id, "cli_123");
        assert_eq!(resp.send_time, 1234567890);
    }

    #[test]
    fn test_pending_message_content_type() {
        let msg = PendingMessage {
            client_msg_id: "msg_ct_101".to_string(),
            send_id: "user_1".to_string(),
            recv_id: "user_2".to_string(),
            group_id: String::new(),
            sender_platform_id: 1,
            sender_nickname: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: r#"{"content":"hello"}"#.to_string(),
        };

        assert_eq!(msg.content_type, 101);
        assert_eq!(msg.content, r#"{"content":"hello"}"#);
        assert_eq!(msg.client_msg_id, "msg_ct_101");
        assert_eq!(msg.send_id, "user_1");
        assert_eq!(msg.recv_id, "user_2");
        assert_eq!(msg.session_type, 1);
        assert_eq!(msg.msg_from, 100);
        assert!(msg.group_id.is_empty());
        assert!(msg.sender_nickname.is_empty());
        assert!(msg.sender_face_url.is_empty());
    }

    async fn make_test_sender() -> MessageSender {
        let event_bus = Arc::new(EventBus::new());
        let cancel_token = CancellationToken::new();
        let connection = Arc::new(ConnectionManager::new(event_bus.clone(), cancel_token));
        let http_client = Arc::new(HttpApiClient::new(
            "http://localhost".to_string(),
            "test_token".to_string(),
            "test_op".to_string(),
        ));
        let file_uploader = Arc::new(FileUploader::new(http_client));
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool));

        MessageSender::new(
            connection,
            event_bus,
            "user_1".to_string(),
            1,
            message_dao,
            conversation_dao,
            file_uploader,
        )
    }

    #[tokio::test]
    async fn test_process_media_content_text() {
        let sender = make_test_sender().await;
        let content = r#"{"content":"hello"}"#.to_string();
        let text_types = [101, 106, 113, 114, 115, 117, 118];

        for &ct in &text_types {
            let msg = PendingMessage {
                client_msg_id: format!("msg_{}", ct),
                send_id: "user_1".to_string(),
                recv_id: "user_2".to_string(),
                group_id: String::new(),
                sender_platform_id: 1,
                sender_nickname: String::new(),
                sender_face_url: String::new(),
                session_type: 1,
                msg_from: 100,
                content_type: ct,
                content: content.clone(),
            };
            let result = sender.process_media_content(&msg).await.unwrap();
            assert_eq!(
                result, content,
                "content_type {} should pass through unchanged",
                ct
            );
        }
    }

    #[tokio::test]
    async fn test_process_media_content_picture() {
        let sender = make_test_sender().await;
        let content = r#"{"sourcePath":"/tmp/test.jpg"}"#.to_string();
        let msg = PendingMessage {
            client_msg_id: "msg_pic".to_string(),
            send_id: "user_1".to_string(),
            recv_id: "user_2".to_string(),
            group_id: String::new(),
            sender_platform_id: 1,
            sender_nickname: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 102,
            content: content.clone(),
        };

        let result = sender.process_media_content(&msg).await;
        assert!(result.is_ok(), "should handle gracefully even if file does not exist");
        assert_eq!(result.unwrap(), content, "content should remain unchanged when sourcePath file is missing");
    }
}
