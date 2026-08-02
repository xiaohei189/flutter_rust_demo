//! # EventBus — 全局事件总线（广播模式）
//!
//! ## 使用场景
//!
//! 用于 "一对多" 广播：一个事件需要被多个独立订阅者接收。
//! 典型场景：SdkEvent 分发给多个 listener（消息、推送、日志）。
//!
//! | 特性 | EventBus | EventSender |
//! |------|----------|-------------|
//! | 模式 | 广播 (broadcast) | 点对点 (mpsc) |
//! | 订阅者 | 多个 | 单一 |
//! | 背压 | 滞后丢弃 | 无界 |
//! | 事件丢失 | 可能（接收端慢时） | 不会（除非 channel 关闭） |
//!
//! ## 选择指南
//!
//! - 需要多个模块同时收到同一事件 → `EventBus`
//! - 需要确保事件不丢失 → `EventSender`
//! - 登录前的事件缓冲 → `EventSender`（通过 unbounded channel 预创建接收器）

use super::types::SdkEvent;
use tokio::sync::broadcast;
use tokio_stream::wrappers::BroadcastStream;

const EVENT_CHANNEL_CAPACITY: usize = 1024;

pub struct EventBus {
    sender: broadcast::Sender<SdkEvent>,
}

impl EventBus {
    pub fn new() -> Self {
        let (sender, _) = broadcast::channel(EVENT_CHANNEL_CAPACITY);
        Self { sender }
    }

    pub fn publish(&self, event: SdkEvent) {
        let _ = self.sender.send(event);
    }

    pub fn subscribe(&self) -> EventSubscription {
        EventSubscription {
            receiver: self.sender.subscribe(),
        }
    }

    pub fn subscribe_stream(&self) -> BroadcastStream<SdkEvent> {
        BroadcastStream::new(self.sender.subscribe())
    }

    pub fn subscriber_count(&self) -> usize {
        self.sender.receiver_count()
    }
}

impl Default for EventBus {
    fn default() -> Self {
        Self::new()
    }
}

pub struct EventSubscription {
    receiver: broadcast::Receiver<SdkEvent>,
}

impl EventSubscription {
    pub async fn next(&mut self) -> Option<SdkEvent> {
        loop {
            match self.receiver.recv().await {
                Ok(event) => return Some(event),
                Err(broadcast::error::RecvError::Lagged(n)) => {
                    tracing::warn!("Event bus lagged, dropped {} events", n);
                }
                Err(broadcast::error::RecvError::Closed) => {
                    return None;
                }
            }
        }
    }

    pub fn try_next(&mut self) -> Option<SdkEvent> {
        match self.receiver.try_recv() {
            Ok(event) => Some(event),
            Err(broadcast::error::TryRecvError::Empty) => None,
            Err(broadcast::error::TryRecvError::Lagged(n)) => {
                tracing::warn!("Event bus lagged, dropped {} events", n);
                None
            }
            Err(broadcast::error::TryRecvError::Closed) => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::event::events::conversation::ConversationEvent;
    use crate::event::events::message::MessageEvent;

    #[tokio::test]
    async fn test_event_bus_publish_and_subscribe() {
        let bus = EventBus::new();
        let mut sub = bus.subscribe();

        bus.publish(SdkEvent::Conversation(ConversationEvent::SyncStarted));
        bus.publish(SdkEvent::Conversation(ConversationEvent::SyncFinished));

        let event1 = sub.try_next();
        assert!(event1.is_some());

        let event2 = sub.try_next();
        assert!(event2.is_some());
    }

    #[tokio::test]
    async fn test_event_bus_multiple_subscribers() {
        let bus = EventBus::new();
        let mut sub1 = bus.subscribe();
        let mut sub2 = bus.subscribe();

        bus.publish(SdkEvent::Message(MessageEvent::SendFailed {
            client_msg_id: "msg_1".into(),
            error: "boom".into(),
        }));

        let event1 = sub1.try_next();
        let event2 = sub2.try_next();

        assert!(event1.is_some());
        assert!(event2.is_some());
    }

    #[test]
    fn test_event_bus_default() {
        let bus = EventBus::default();
        assert_eq!(bus.subscriber_count(), 0);
    }
}

