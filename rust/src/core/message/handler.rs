use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tracing::{debug, info, warn};

/// 接收到的消息
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ReceivedMessage {
    /// 服务器消息 ID
    pub server_msg_id: String,
    /// 客户端消息 ID
    pub client_msg_id: String,
    /// 发送者 ID
    pub send_id: String,
    /// 接收者 ID
    pub recv_id: String,
    /// 会话类型
    pub session_type: i32,
    /// 消息内容类型
    pub content_type: i32,
    /// 消息内容 (JSON)
    pub content: String,
    /// 消息 seq
    pub seq: i64,
    /// 发送时间戳
    pub send_time: i64,
    /// 服务器时间戳
    pub server_time: i64,
}

/// 消息处理器
pub struct MessageHandler {
    /// 事件总线
    event_bus: Arc<EventBus>,
    /// 已处理消息的缓存（用于去重）
    processed_messages: Arc<tokio::sync::RwLock<lru::LruCache<String, bool>>>,
}

impl MessageHandler {
    pub fn new(event_bus: Arc<EventBus>) -> Self {
        Self {
            event_bus,
            processed_messages: Arc::new(tokio::sync::RwLock::new(
                lru::LruCache::new(std::num::NonZeroUsize::new(10000).unwrap()),
            )),
        }
    }

    /// 处理接收到的消息
    pub async fn handle_message(&self, msg: ReceivedMessage) -> Result<()> {
        debug!("处理消息: server_msg_id={}", msg.server_msg_id);

        if self.is_duplicate(&msg.server_msg_id).await {
            debug!("消息已处理，跳过: {}", msg.server_msg_id);
            return Ok(());
        }

        self.mark_as_processed(&msg.server_msg_id).await;

        self.event_bus.publish(SdkEvent::NewMessage {
            message: serde_json::to_value(&msg).unwrap_or_default(),
        });

        info!("消息处理完成: server_msg_id={}", msg.server_msg_id);
        Ok(())
    }

    /// 检查消息是否已处理（去重）
    async fn is_duplicate(&self, msg_id: &str) -> bool {
        self.processed_messages.read().await.contains(msg_id)
    }

    /// 标记消息为已处理
    async fn mark_as_processed(&self, msg_id: &str) {
        self.processed_messages
            .write()
            .await
            .put(msg_id.to_string(), true);
    }

    /// 批量处理消息
    pub async fn handle_messages(&self, messages: Vec<ReceivedMessage>) -> Result<()> {
        info!("批量处理消息: {} 条", messages.len());
        for msg in messages {
            if let Err(e) = self.handle_message(msg).await {
                warn!("处理消息失败: {}", e);
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_message_handler_creation() {
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(event_bus);
    }

    #[tokio::test]
    async fn test_message_handler_deduplication() {
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(event_bus);

        let msg = ReceivedMessage {
            server_msg_id: "msg_123".to_string(),
            client_msg_id: "client_123".to_string(),
            send_id: "user_1".to_string(),
            recv_id: "user_2".to_string(),
            session_type: 1,
            content_type: 101,
            content: r#"{"text":"hello"}"#.to_string(),
            seq: 1,
            send_time: 1234567890,
            server_time: 1234567890,
        };

        let result1 = handler.handle_message(msg.clone()).await;
        assert!(result1.is_ok());

        let result2 = handler.handle_message(msg.clone()).await;
        assert!(result2.is_ok());
    }

    #[tokio::test]
    async fn test_message_handler_batch() {
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(event_bus);

        let messages = vec![
            ReceivedMessage {
                server_msg_id: "msg_1".to_string(),
                client_msg_id: "client_1".to_string(),
                send_id: "user_1".to_string(),
                recv_id: "user_2".to_string(),
                session_type: 1,
                content_type: 101,
                content: r#"{"text":"hello 1"}"#.to_string(),
                seq: 1,
                send_time: 1234567890,
                server_time: 1234567890,
            },
            ReceivedMessage {
                server_msg_id: "msg_2".to_string(),
                client_msg_id: "client_2".to_string(),
                send_id: "user_1".to_string(),
                recv_id: "user_2".to_string(),
                session_type: 1,
                content_type: 101,
                content: r#"{"text":"hello 2"}"#.to_string(),
                seq: 2,
                send_time: 1234567891,
                server_time: 1234567891,
            },
        ];

        let result = handler.handle_messages(messages).await;
        assert!(result.is_ok());
    }
}
