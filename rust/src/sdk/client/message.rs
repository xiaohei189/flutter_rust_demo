use crate::domain::error::types::Result;
use crate::domain::error::types::SdkError;
use crate::domain::model::message::MessageInfo;
use crate::infra::database::models::LocalChatLog;
use crate::sdk::client::types::{
    DeleteMessagesReq, GetHistoryMessagesReq, GetHistoryMessagesResult, MarkMessagesAsReadReq, RevokeMessageReq,
    SearchMessagesReq, SendMessageReq,
};
use crate::sdk::client::OpenIMClient;
use openim_protocol::sdkws::MsgData;

impl OpenIMClient {
    pub async fn send_message(&self, req: SendMessageReq) -> std::result::Result<MsgData, SdkError> {
        let client_msg_id = req.client_msg_id.unwrap_or_else(|| {
            format!("msg_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())
        });

        let pending_msg = crate::core::message::sender::PendingMessage {
            client_msg_id: client_msg_id.clone(),
            send_id: self.context.user_id.lock().unwrap().clone(),
            recv_id: req.recv_id,
            group_id: req.group_id,
            sender_platform_id: self.context.config.platform_id,
            sender_nickname: String::new(),
            sender_face_url: String::new(),
            session_type: req.session_type.into(),
            msg_from: 100,
            content_type: req.content_type.into(),
            content: req.content,
        };

        self.message_sender.send_message(pending_msg).await?;

        let send_time = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        Ok(MsgData {
            client_msg_id,
            send_id: self.context.user_id.lock().unwrap().clone(),
            send_time,
            create_time: send_time,
            content_type: 0,
            session_type: 0,
            ..Default::default()
        })
    }

    pub async fn get_history_messages(&self, req: GetHistoryMessagesReq) -> std::result::Result<GetHistoryMessagesResult, SdkError> {
        let start_time = if req.start_client_msg_id.is_empty() {
            0
        } else {
            let msg = self.message_handler.message_dao()
                .get_by_client_msg_id(&req.conversation_id, &req.start_client_msg_id)
                .await?;
            msg.map(|m| m.send_time).unwrap_or(0)
        };

        let messages = self.message_handler.message_dao()
            .get_by_conversation(&req.conversation_id, start_time, req.count)
            .await?;

        let is_end = messages.len() < req.count as usize;

        let msg_info_list: Vec<MessageInfo> = messages.into_iter()
            .rev()
            .map(|m| {
                let msg_data = MsgData {
                    server_msg_id: m.server_msg_id,
                    client_msg_id: m.client_msg_id,
                    send_id: m.send_id,
                    recv_id: m.recv_id,
                    sender_platform_id: m.sender_platform_id,
                    sender_nickname: m.sender_nick_name,
                    sender_face_url: m.sender_face_url,
                    session_type: m.session_type,
                    msg_from: m.msg_from,
                    content_type: m.content_type,
                    content: m.content.into_bytes(),
                    seq: m.seq,
                    send_time: m.send_time,
                    create_time: m.create_time,
                    status: m.status,
                    is_read: m.is_read != 0,
                    group_id: m.group_id,
                    attached_info: m.attached_info,
                    ex: m.ex,
                    ..Default::default()
                };
                MessageInfo::from(msg_data)
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
            req.session_type.into(),
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
            req.session_type.into(),
            req.has_read_seq,
            req.seqs,
        ).await
    }

    pub async fn mark_conversation_as_read(&self, conversation_id: String, session_type: i32) -> Result<()> {
        self.message_service.mark_conversation_as_read(conversation_id, session_type).await
    }

    pub async fn search_local_messages(&self, req: SearchMessagesReq) -> std::result::Result<Vec<LocalChatLog>, SdkError> {
        self.message_service.search_local_messages(
            req.conversation_id,
            req.keyword,
            100,
        ).await
    }
}
