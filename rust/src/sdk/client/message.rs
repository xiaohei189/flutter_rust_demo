use crate::core::message::sender::PendingMessage;
use crate::domain::error::types::Result;
use crate::domain::error::types::SdkError;
use crate::domain::model::message::MessageInfo;
use crate::infra::database::models::LocalChatLog;
use crate::sdk::client::OpenIMClient;
use openim_protocol::sdkws::MsgData;

impl OpenIMClient {
    /// 发送消息
    pub async fn send_message(
        &self,
        recv_id: String,
        group_id: String,
        session_type: i32,
        content_type: i32,
        content: String,
        client_msg_id: Option<String>,
    ) -> std::result::Result<MsgData, SdkError> {
        let client_msg_id = client_msg_id.unwrap_or_else(|| {
            format!("msg_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())
        });

        let pending_msg = PendingMessage {
            client_msg_id: client_msg_id.clone(),
            send_id: self.context.user_id.lock().unwrap().clone(),
            recv_id,
            group_id,
            sender_platform_id: self.context.config.platform_id,
            sender_nickname: String::new(),
            sender_face_url: String::new(),
            session_type,
            msg_from: 100,
            content_type,
            content,
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
            content_type,
            session_type,
            ..Default::default()
        })
    }

    /// 获取历史消息
    pub async fn get_history_messages(&self, conversation_id: String, start_seq: i64, count: i64) -> std::result::Result<Vec<MessageInfo>, SdkError> {
        let messages = self.message_handler.message_dao()
            .get_by_conversation(&conversation_id, start_seq, start_seq + count)
            .await?;

        let msg_info_list: Vec<MessageInfo> = messages.into_iter()
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
                    group_id: m.group_id,
                    ..Default::default()
                };
                MessageInfo::from(msg_data)
            })
            .collect();

        Ok(msg_info_list)
    }

    /// 撤回消息
    pub async fn revoke_message(&self, conversation_id: String, seq: i64, client_msg_id: String, session_type: i32) -> Result<()> {
        self.message_service.revoke_message(conversation_id, seq, client_msg_id, session_type).await
    }

    /// 删除消息
    pub async fn delete_messages(&self, conversation_id: String, client_msg_ids: Vec<String>) -> Result<()> {
        self.message_service.delete_messages(conversation_id, client_msg_ids).await
    }

    /// 标记消息已读
    pub async fn mark_messages_as_read(&self, conversation_id: String, session_type: i32, has_read_seq: i64, seqs: Vec<i64>) -> Result<()> {
        self.message_service.mark_messages_as_read(conversation_id, session_type, has_read_seq, seqs).await
    }

    /// 本地搜索消息
    pub async fn search_local_messages(&self, conversation_id: String, keyword: String) -> std::result::Result<Vec<LocalChatLog>, SdkError> {
        self.message_service.search_local_messages(conversation_id, keyword, 100).await
    }

    /// 发送 PendingMessage（测试用，直接传入已构建的消息对象）
    pub async fn send_pending_message(&self, msg: PendingMessage) -> std::result::Result<(), SdkError> {
        self.message_sender.send_message(msg).await
    }
}
