use crate::domain::constant::types::content_type;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::conversation::Conversation;
use crate::domain::model::message::ReceivedMessage;
use crate::infra::database::{ConversationDao, MessageDao};
use crate::infra::database::models::{LocalChatLog, LocalConversation};
use std::sync::Arc;
use tracing::{debug, info, warn};

pub struct MessageHandler {
    message_dao: Arc<MessageDao>,
    conversation_dao: Arc<ConversationDao>,
    event_bus: Arc<EventBus>,
}

impl MessageHandler {
    pub fn new(
        message_dao: Arc<MessageDao>,
        conversation_dao: Arc<ConversationDao>,
        event_bus: Arc<EventBus>,
    ) -> Self {
        Self {
            message_dao,
            conversation_dao,
            event_bus,
        }
    }

    pub fn message_dao(&self) -> Arc<MessageDao> {
        self.message_dao.clone()
    }

    fn is_tip_message(content_type_val: i32) -> bool {
        content_type_val >= content_type::NOTIFICATION_BEGIN && content_type_val <= content_type::NOTIFICATION_END
    }

    fn should_store_message(content_type_val: i32) -> bool {
        !Self::is_tip_message(content_type_val)
            && content_type_val != content_type::TYPING
            && content_type_val != content_type::CUSTOM_MSG_ONLINE_ONLY
    }

    fn should_update_conversation(content_type_val: i32) -> bool {
        Self::should_store_message(content_type_val)
            && content_type_val != content_type::CUSTOM_MSG_NOT_TRIGGER_CONVERSATION
    }

    pub async fn handle_messages(&self, messages: Vec<ReceivedMessage>) -> Result<()> {
        if messages.is_empty() {
            return Ok(());
        }

        info!("handling {} messages", messages.len());

        let store_logs: Vec<LocalChatLog> = messages
            .iter()
            .filter(|m| Self::should_store_message(m.content_type))
            .map(|m| LocalChatLog {
                conversation_id: m.conversation_id.clone(),
                client_msg_id: m.client_msg_id.clone(),
                server_msg_id: m.server_msg_id.clone(),
                send_id: m.send_id.clone(),
                recv_id: m.recv_id.clone(),
                sender_platform_id: m.sender_platform_id,
                sender_nick_name: m.sender_nick_name.clone(),
                sender_face_url: m.sender_face_url.clone(),
                session_type: m.session_type,
                msg_from: m.msg_from,
                content_type: m.content_type,
                content: m.content.clone(),
                is_read: 0,
                status: 2,
                seq: m.seq,
                send_time: m.send_time,
                create_time: m.create_time,
                attached_info: String::new(),
                ex: String::new(),
                local_ex: String::new(),
                group_id: m.group_id.clone(),
            })
            .collect();

        if !store_logs.is_empty() {
            self.message_dao.batch_insert(&store_logs).await?;
        }

        let mut seen_convs = std::collections::HashSet::new();
        for msg in &messages {
            let is_conversation_update = Self::should_update_conversation(msg.content_type);

            if seen_convs.insert(&msg.conversation_id) {
                let existing = self.conversation_dao.get_by_id(&msg.conversation_id).await?;
                if existing.is_none() {
                    let show_name = if msg.session_type == 1 {
                        msg.sender_nick_name.clone()
                    } else {
                        format!("Group_{}", msg.group_id)
                    };

                    let unread_count = if is_conversation_update { 1 } else { 0 };

                    let conv = LocalConversation {
                        conversation_id: msg.conversation_id.clone(),
                        conversation_type: msg.session_type,
                        user_id: if msg.session_type == 1 { msg.send_id.clone() } else { String::new() },
                        group_id: if msg.session_type == 2 { msg.group_id.clone() } else { String::new() },
                        show_name,
                        face_url: msg.sender_face_url.clone(),
                        latest_msg: if is_conversation_update { msg.content.clone() } else { String::new() },
                        latest_msg_send_time: if is_conversation_update { msg.send_time } else { 0 },
                        unread_count,
                        recv_msg_opt: 0,
                        is_pinned: 0,
                        is_private_chat: 0,
                        burn_duration: 0,
                        group_at_type: 0,
                        is_not_in_group: 0,
                        update_unread_count_time: 0,
                        attached_info: String::new(),
                        ex: String::new(),
                        draft_text: String::new(),
                        draft_text_time: 0,
                        max_seq: msg.seq,
                        min_seq: 0,
                        is_msg_destruct: 0,
                        msg_destruct_time: 0,
                    };
                    self.conversation_dao.upsert(&conv).await?;
                    info!("创建新会话: {}", msg.conversation_id);
                } else if is_conversation_update {
                    self.conversation_dao
                        .update_after_new_message(
                            &msg.conversation_id,
                            &msg.content,
                            msg.send_time,
                            msg.seq,
                        )
                        .await?;
                }
            }

            if msg.content_type != content_type::TYPING {
                self.event_bus.publish(SdkEvent::NewMessage {
                    message: msg.clone(),
                });
            }
        }

        info!("handled {} messages", messages.len());
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

    fn make_msg(id: &str, conv_id: &str, seq: i64) -> ReceivedMessage {
        ReceivedMessage {
            server_msg_id: format!("srv_{}", id),
            client_msg_id: id.to_string(),
            send_id: "user_1".into(),
            recv_id: "user_2".into(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: format!("{{\"text\":\"hello {}\"}}", id),
            seq,
            send_time: seq * 1000,
            create_time: seq * 1000,
            conversation_id: conv_id.to_string(),
            group_id: String::new(),
        }
    }

    #[tokio::test]
    async fn test_handle_messages() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool));
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(message_dao, conversation_dao, event_bus);

        let msgs = vec![
            make_msg("msg_1", "conv_1", 1),
            make_msg("msg_2", "conv_1", 2),
        ];

        handler.handle_messages(msgs).await.unwrap();
    }

    #[tokio::test]
    async fn test_dedup_via_insert_ignore() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(message_dao, conversation_dao, event_bus);

        let msgs = vec![make_msg("msg_1", "conv_1", 1)];
        handler.handle_messages(msgs.clone()).await.unwrap();
        handler.handle_messages(msgs).await.unwrap();

        let chat_logs = MessageDao::new(pool)
            .get_by_conversation("conv_1", 0, 100)
            .await
            .unwrap();
        assert_eq!(chat_logs.len(), 1);
    }
}
