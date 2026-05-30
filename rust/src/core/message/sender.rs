use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::{mpsc, RwLock};
use tokio::time::timeout;
use tracing::{debug, error, info, warn};

/// 消息发送状态
#[derive(Clone, Debug, PartialEq, Default)]
pub enum SendStatus {
    #[default]
    Pending,
    Sending,
    Sent { server_msg_id: String, send_time: i64 },
    Failed { error: String },
}

/// 待发送消息
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PendingMessage {
    /// 客户端消息 ID
    pub client_msg_id: String,
    /// 发送者 ID
    pub send_id: String,
    /// 接收者 ID
    pub recv_id: String,
    /// 会话类型 (1:单聊, 2:群聊, 3:超级群, 4:通知)
    pub session_type: i32,
    /// 消息内容 (JSON)
    pub content: String,
    /// 消息类型
    pub content_type: i32,
    /// 操作 ID
    pub operation_id: String,
    /// 发送状态
    #[serde(skip)]
    pub status: SendStatus,
}

/// 消息发送通道
struct SendChannel {
    /// 文本消息通道
    text_tx: mpsc::UnboundedSender<PendingMessage>,
    /// 媒体消息通道
    media_tx: mpsc::UnboundedSender<PendingMessage>,
}

/// 消息发送队列管理器
pub struct MessageSender {
    /// 发送通道
    channels: SendChannel,
    /// 事件总线
    event_bus: Arc<EventBus>,
    /// 发送超时时间
    timeout: Duration,
    /// 最大重试次数
    max_retries: u32,
}

impl MessageSender {
    pub fn new(event_bus: Arc<EventBus>) -> Self {
        let (text_tx, text_rx) = mpsc::unbounded_channel::<PendingMessage>();
        let (media_tx, media_rx) = mpsc::unbounded_channel::<PendingMessage>();

        let channels = SendChannel { text_tx, media_tx };

        Self {
            channels,
            event_bus,
            timeout: Duration::from_secs(3),
            max_retries: 100,
        }
    }

    /// 发送文本消息（保证有序）
    pub async fn send_text_message(&self, msg: PendingMessage) -> Result<()> {
        debug!("发送文本消息: client_msg_id={}", msg.client_msg_id);
        
        self.channels
            .text_tx
            .send(msg)
            .map_err(|e| SdkError::message_send(format!("发送文本消息失败: {}", e)))?;

        Ok(())
    }

    /// 发送媒体消息（图片、视频、文件等）
    pub async fn send_media_message(&self, msg: PendingMessage) -> Result<()> {
        debug!("发送媒体消息: client_msg_id={}", msg.client_msg_id);
        
        self.channels
            .media_tx
            .send(msg)
            .map_err(|e| SdkError::message_send(format!("发送媒体消息失败: {}", e)))?;

        Ok(())
    }

    /// 根据消息类型自动选择发送通道
    pub async fn send_message(&self, msg: PendingMessage) -> Result<()> {
        match msg.content_type {
            101 | 106 | 113 | 114 | 115 | 117 | 118 => {
                self.send_text_message(msg).await
            }
            _ => self.send_media_message(msg).await,
        }
    }

    /// 启动发送 Worker
    pub fn start_workers<F, Fut>(
        &self,
        send_fn: F,
    ) -> (tokio::task::JoinHandle<()>, tokio::task::JoinHandle<()>)
    where
        F: Fn(PendingMessage) -> Fut + Send + Clone + 'static,
        Fut: std::future::Future<Output = Result<PendingMessage>> + Send,
    {
        let text_rx = self.channels.text_tx.clone();
        let media_rx = self.channels.media_tx.clone();
        let event_bus = self.event_bus.clone();
        let timeout = self.timeout;
        let max_retries = self.max_retries;

        let text_worker = tokio::spawn(async move {
            info!("文本消息发送 Worker 已启动");
        });

        let media_worker = tokio::spawn(async move {
            info!("媒体消息发送 Worker 已启动");
        });

        (text_worker, media_worker)
    }

    /// 通知消息发送成功
    fn notify_message_sent(&self, client_msg_id: String, server_msg_id: String, send_time: i64) {
        self.event_bus.publish(SdkEvent::MessageSent {
            client_msg_id,
            server_msg_id,
            send_time,
        });
    }

    /// 通知消息发送失败
    fn notify_message_failed(&self, client_msg_id: String, error: String) {
        self.event_bus.publish(SdkEvent::MessageSendFailed {
            client_msg_id,
            error,
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_message_sender_creation() {
        let event_bus = Arc::new(EventBus::new());
        let sender = MessageSender::new(event_bus);
        assert_eq!(sender.timeout, Duration::from_secs(3));
        assert_eq!(sender.max_retries, 100);
    }

    #[test]
    fn test_pending_message_creation() {
        let msg = PendingMessage {
            client_msg_id: "msg_123".to_string(),
            send_id: "user_1".to_string(),
            recv_id: "user_2".to_string(),
            session_type: 1,
            content: r#"{"text":"hello"}"#.to_string(),
            content_type: 101,
            operation_id: "op_123".to_string(),
            status: SendStatus::Pending,
        };

        assert_eq!(msg.client_msg_id, "msg_123");
        assert_eq!(msg.content_type, 101);
        assert_eq!(msg.status, SendStatus::Pending);
    }

    #[test]
    fn test_send_status_transitions() {
        let mut status = SendStatus::Pending;
        assert_eq!(status, SendStatus::Pending);

        status = SendStatus::Sending;
        assert_eq!(status, SendStatus::Sending);

        status = SendStatus::Sent {
            server_msg_id: "server_123".to_string(),
            send_time: 1234567890,
        };
        assert!(matches!(status, SendStatus::Sent { .. }));

        status = SendStatus::Failed {
            error: "timeout".to_string(),
        };
        assert!(matches!(status, SendStatus::Failed { .. }));
    }
}
