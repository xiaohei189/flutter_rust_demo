use crate::core::connection::manager::ConnectionManager;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::infra::database::conversation_dao::ConversationDao;
use crate::infra::database::MessageDao;
use crate::infra::database::models::LocalChatLog;
use crate::protocol::sdkws::{MsgData, UserSendMsgResp};
use prost::Message;
use serde::{Deserialize, Serialize};
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
}

impl MessageSender {
    pub fn new(
        connection: Arc<ConnectionManager>,
        event_bus: Arc<EventBus>,
        user_id: String,
        platform_id: i32,
        message_dao: Arc<MessageDao>,
        conversation_dao: Arc<ConversationDao>,
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

    async fn do_send_message(&self, msg: PendingMessage) -> Result<SendMsgResp> {
        let send_time = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

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
            content: msg.content.clone().into_bytes(),
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
                self.event_bus.publish(SdkEvent::MessageSendFailed {
                    client_msg_id: msg.client_msg_id.clone(),
                    error: format!("{}", e),
                });
                return Err(SdkError::message_send(format!("send message via ws failed: {}", e)));
            }
        };

        if let Err(e) = self.persist_sent_message(&msg, &resp).await {
            error!("持久化发送消息失败: {}", e);
        }

        self.event_bus.publish(SdkEvent::MessageSent {
            client_msg_id: resp.client_msg_id.clone(),
            server_msg_id: resp.server_msg_id.clone(),
            send_time: resp.send_time,
        });

        Ok(SendMsgResp {
            server_msg_id: resp.server_msg_id,
            client_msg_id: resp.client_msg_id,
            send_time: resp.send_time,
        })
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
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
}
