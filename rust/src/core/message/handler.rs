use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::infra::database::{ConversationDao, MessageDao};
use crate::infra::database::models::LocalChatLog;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tracing::{debug, info, warn};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ReceivedMessage {
    pub server_msg_id: String,
    pub client_msg_id: String,
    pub send_id: String,
    pub recv_id: String,
    pub sender_platform_id: i32,
    pub sender_nick_name: String,
    pub sender_face_url: String,
    pub session_type: i32,
    pub msg_from: i32,
    pub content_type: i32,
    pub content: String,
    pub seq: i64,
    pub send_time: i64,
    pub create_time: i64,
    pub conversation_id: String,
    pub group_id: String,
}

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

    pub async fn handle_messages(&self, messages: Vec<ReceivedMessage>) -> Result<()> {
        if messages.is_empty() {
            return Ok(());
        }

        info!("handling {} messages", messages.len());

        let logs: Vec<LocalChatLog> = messages
            .iter()
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

        self.message_dao.batch_insert(&logs).await?;

        let mut seen_convs = std::collections::HashSet::new();
        for msg in &messages {
            if seen_convs.insert(&msg.conversation_id) {
                self.conversation_dao
                    .update_after_new_message(
                        &msg.conversation_id,
                        &msg.content,
                        msg.send_time,
                        msg.seq,
                    )
                    .await?;
            }

            self.event_bus.publish(SdkEvent::NewMessage {
                message: serde_json::to_value(msg).unwrap_or_default(),
            });
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
