use crate::domain::constant::enums::MessageSendStatus;
use crate::domain::error::types::Result;
use crate::domain::error::types::SdkError;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::message::MessageInfo;
use crate::domain::model::msg_struct::{get_msg_id, MsgStruct};
use crate::domain::model::msg_struct::MSG_STATUS_SENDING;
use crate::infra::database::models::LocalChatLog;
use crate::protocol::sdkws::{MsgData, UserSendMsgResp};
use crate::sdk::client::types::{
    DeleteMessagesReq, GetHistoryMessagesReq, GetHistoryMessagesResult, MarkMessagesAsReadReq, RevokeMessageReq,
    SearchMessagesReq,
};
use crate::sdk::client::OpenIMClient;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};
use tracing::{info, error, debug};
use serde_json::{json, Value};

impl OpenIMClient {
    pub async fn send_msg(&self, mut msg: MsgStruct, source_id: &str) -> std::result::Result<MsgData, SdkError> {
        let send_id = self.context.user_id.lock().unwrap().clone();
        let platform_id = self.context.config.platform_id;
        let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as i64;

        msg.send_id = send_id;
        msg.sender_platform_id = platform_id;
        msg.client_msg_id = get_msg_id(&msg.send_id);
        msg.create_time = now;
        msg.send_time = now;
        msg.status = MSG_STATUS_SENDING;
        msg.is_read = false;
        if msg.session_type == 1 {
            msg.recv_id = source_id.to_string();
        } else {
            msg.group_id = source_id.to_string();
        }

        let resp = self.do_send_message(msg.clone()).await?;

        let mut result = MsgData::from(&msg);
        result.server_msg_id = resp.server_msg_id;
        result.send_time = resp.send_time;
        result.status = 2;
        Ok(result)
    }

    async fn do_send_message(&self, msg: MsgStruct) -> std::result::Result<UserSendMsgResp, SdkError> {
        let send_time = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        let content = self.process_media_content(&msg).await?;

        self.insert_message_before_send(&msg, send_time).await?;

        let mut msg_data = MsgData::from(&msg);
        msg_data.content = content.into_bytes();
        msg_data.send_time = send_time;
        msg_data.create_time = send_time;

        let resp: UserSendMsgResp = match self.connection.send_rpc(1003, &msg_data).await {
            Ok(r) => r,
            Err(e) => {
                self.context.message_dao.update_send_status(&msg.client_msg_id, MessageSendStatus::SendFailed).await?;
                self.event_bus.publish(SdkEvent::MessageSendFailed {
                    client_msg_id: msg.client_msg_id.clone(),
                    error: format!("{}", e),
                });
                return Err(SdkError::message_send(format!("send message via ws failed: {}", e)));
            }
        };

        if let Err(e) = self.context.message_dao.update_after_send_success(&msg.client_msg_id, &resp.server_msg_id, resp.send_time).await {
            error!("更新发送结果失败: {}", e);
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

        Ok(resp)
    }

    fn conversation_id_for_msg(&self, msg: &MsgStruct) -> String {
        if msg.session_type == 1 {
            let mut ids = vec![msg.send_id.clone(), msg.recv_id.clone()];
            ids.sort();
            format!("si_{}_{}", ids[0], ids[1])
        } else {
            format!("g_{}", msg.group_id)
        }
    }

    async fn insert_message_before_send(&self, msg: &MsgStruct, send_time: i64) -> Result<()> {
        let conversation_id = self.conversation_id_for_msg(msg);

        let mut local_log = LocalChatLog::from(msg);
        local_log.conversation_id = conversation_id.clone();
        local_log.send_time = send_time;
        local_log.create_time = send_time;
        local_log.status = MessageSendStatus::Sending as i32;

        self.context.message_dao.batch_insert(&[local_log]).await?;
        self.context.conversation_dao.update_after_sent_message(
            &conversation_id,
            &msg.content,
            send_time,
        ).await?;

        debug!("发送前插入消息: client_msg_id={}, conv={}", msg.client_msg_id, conversation_id);
        Ok(())
    }

    async fn process_media_content(&self, msg: &MsgStruct) -> std::result::Result<String, SdkError> {
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
            let source_picture = json!({ "url": url });
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

    pub async fn send_text_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
        let mut msg = MsgStruct::create_text_message(text);
        msg.session_type = session_type;
        self.send_msg(msg, source_id).await
    }

    pub async fn send_markdown_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
        let mut msg = MsgStruct::create_markdown_message(text);
        msg.session_type = session_type;
        self.send_msg(msg, source_id).await
    }

    pub async fn send_advanced_text_message(&self, text: &str, entities: Vec<crate::domain::model::msg_struct::MessageEntity>, source_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
        let mut msg = MsgStruct::create_advanced_text_message(text, entities);
        msg.session_type = session_type;
        self.send_msg(msg, source_id).await
    }

    pub async fn send_image_message(&self, file_path: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
        let upload_result = self.file_uploader.upload_image(file_path).await
            .map_err(|e| SdkError::message_send(format!("upload image failed: {}", e)))?;
        let source = crate::domain::model::msg_struct::PictureBaseInfo {
            width: 0, height: 0, picture_type: String::new(),
            size: upload_result.size as i64, url: upload_result.url, uuid: String::new(),
        };
        let mut msg = MsgStruct::create_image_message(
            file_path, source,
            crate::domain::model::msg_struct::PictureBaseInfo::default(),
            crate::domain::model::msg_struct::PictureBaseInfo::default(),
        );
        msg.session_type = session_type;
        self.send_msg(msg, source_id).await
    }

    pub async fn get_history_messages(&self, req: GetHistoryMessagesReq) -> std::result::Result<GetHistoryMessagesResult, SdkError> {
        info!("get_history_messages: conversation_id={}, start_client_msg_id={}, count={}",
              req.conversation_id, req.start_client_msg_id, req.count);

        let start_time = if req.start_client_msg_id.is_empty() {
            0
        } else {
            let msg = self.message_handler.message_dao()
                .get_by_client_msg_id(&req.conversation_id, &req.start_client_msg_id)
                .await?;
            let st = msg.as_ref().map(|m| m.send_time).unwrap_or(0);
            info!("通过 client_msg_id 查询到 send_time={}", st);
            st
        };

        let messages = self.message_handler.message_dao()
            .get_by_conversation(&req.conversation_id, start_time, req.count)
            .await?;

        info!("数据库查询返回 {} 条消息", messages.len());

        let is_end = messages.len() < req.count as usize;

        let msg_info_list: Vec<MessageInfo> = messages.into_iter()
            .rev()
            .map(|m| {
                let msg_struct = MsgStruct::from(&m);
                MessageInfo::from(MsgData::from(&msg_struct))
            })
            .collect();

        Ok(GetHistoryMessagesResult {
            messages: msg_info_list,
            is_end,
        })
    }

    pub async fn revoke_message(&self, req: RevokeMessageReq) -> Result<()> {
        self.message_service.revoke_message(
            req.conversation_id,
            req.seq,
            req.client_msg_id,
            req.session_type,
        ).await
    }

    pub async fn delete_messages(&self, req: DeleteMessagesReq) -> Result<()> {
        self.message_service.delete_messages(
            req.conversation_id,
            req.client_msg_ids,
        ).await
    }

    pub async fn mark_messages_as_read(&self, req: MarkMessagesAsReadReq) -> Result<()> {
        self.message_service.mark_messages_as_read(
            req.conversation_id,
            req.session_type,
            req.has_read_seq,
            req.seqs,
        ).await
    }

    pub async fn search_local_messages(&self, req: SearchMessagesReq) -> std::result::Result<Vec<LocalChatLog>, SdkError> {
        self.message_service.search_local_messages(
            req.conversation_id,
            req.keyword,
            100,
        ).await
    }
}
