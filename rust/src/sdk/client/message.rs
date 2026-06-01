use crate::domain::error::types::Result;
use crate::domain::error::types::SdkError;
use crate::domain::model::message::MessageInfo;
use crate::domain::model::msg_struct::MsgStruct;
use crate::infra::database::models::LocalChatLog;
use crate::sdk::client::types::{
    DeleteMessagesReq, GetHistoryMessagesReq, GetHistoryMessagesResult, MarkMessagesAsReadReq, RevokeMessageReq,
    SearchMessagesReq, SendMessageReq,
};
use crate::sdk::client::OpenIMClient;
use openim_protocol::sdkws::MsgData;
use tracing::info;

impl OpenIMClient {
    /// 发送消息（MsgStruct → channel → 发送）
    pub async fn send_msg(&self, msg: MsgStruct) -> std::result::Result<MsgData, SdkError> {
        self.message_sender.send_message(msg.clone()).await?;

        let send_time = msg.send_time;

        Ok(MsgData {
            client_msg_id: msg.client_msg_id,
            send_id: msg.send_id,
            send_time,
            create_time: msg.create_time,
            content_type: msg.content_type,
            session_type: msg.session_type,
            status: msg.status,
            is_read: msg.is_read,
            seq: msg.seq,
            ..Default::default()
        })
    }

    /// 一步发送文本消息（Flutter 调用入口）
    pub async fn send_text_message(&self, text: &str, recv_id: &str, group_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
        let send_id = self.context.user_id.lock().unwrap().clone();
        let platform_id = self.context.config.platform_id;
        let mut msg = MsgStruct::create_text_message(text, &send_id, platform_id);
        msg.recv_id = recv_id.to_string();
        msg.group_id = group_id.to_string();
        msg.session_type = session_type;
        self.send_msg(msg).await
    }

    /// 一步发送 Markdown 消息
    pub async fn send_markdown_message(&self, text: &str, recv_id: &str, group_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
        let send_id = self.context.user_id.lock().unwrap().clone();
        let platform_id = self.context.config.platform_id;
        let mut msg = MsgStruct::create_markdown_message(text, &send_id, platform_id);
        msg.recv_id = recv_id.to_string();
        msg.group_id = group_id.to_string();
        msg.session_type = session_type;
        self.send_msg(msg).await
    }

    /// 一步发送富文本消息
    pub async fn send_advanced_text_message(&self, text: &str, entities: Vec<crate::domain::model::msg_struct::MessageEntity>, recv_id: &str, group_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
        let send_id = self.context.user_id.lock().unwrap().clone();
        let platform_id = self.context.config.platform_id;
        let mut msg = MsgStruct::create_advanced_text_message(text, entities, &send_id, platform_id);
        msg.recv_id = recv_id.to_string();
        msg.group_id = group_id.to_string();
        msg.session_type = session_type;
        self.send_msg(msg).await
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
        for m in &messages {
            info!("  msg: client_msg_id={}, send_time={}, content_len={}", 
                  m.client_msg_id, m.send_time, m.content.len());
        }

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
