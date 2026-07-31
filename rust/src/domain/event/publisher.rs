//! 通用事件发布器 — 替代各模块中重复的 event_tx 模式
//!
//! 所有需要发布事件的模块统一使用此类型，
//! 消除 `event_tx` + `set_event_sender()` + `send()` 的 9 处重复代码。

use std::sync::{Arc, Mutex};
use tokio::sync::mpsc::UnboundedSender;

/// 通用事件发布器
///
/// # 设计
///
/// - 内部使用 `Arc<Mutex<Option<UnboundedSender<T>>>>`
/// - Clone 廉价（Arc 共享），多个组件可共享同一发布器
/// - 发布时若无订阅者则静默丢弃（不 panic）
///
/// # 用法
///
/// ```ignore
/// let events = EventPublisher::<ConversationEvent>::new();
/// events.set_sender(tx);
/// events.publish(ConversationEvent::TotalUnreadCountChanged(0));
/// ```
pub struct EventPublisher<T> {
    tx: Arc<Mutex<Option<UnboundedSender<T>>>>,
}

impl<T> EventPublisher<T> {
    /// 创建空的发布器（无订阅者）
    pub fn new() -> Self {
        Self { tx: Arc::new(Mutex::new(None)) }
    }

    /// 设置事件发送通道（由 SDK 初始化时调用）
    pub fn set_sender(&self, tx: UnboundedSender<T>) {
        *self.tx.lock().unwrap() = Some(tx);
    }

    /// 发布事件（无订阅者时静默丢弃）
    pub fn publish(&self, event: T) {
        if let Some(tx) = &*self.tx.lock().unwrap() {
            let _ = tx.send(event);
        }
    }

    /// 是否有订阅者
    pub fn has_subscriber(&self) -> bool {
        self.tx.lock().unwrap().is_some()
    }
}

impl<T> Default for EventPublisher<T> {
    fn default() -> Self {
        Self::new()
    }
}

impl<T> Clone for EventPublisher<T> {
    fn clone(&self) -> Self {
        Self { tx: self.tx.clone() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_publish_without_subscriber_does_not_panic() {
        let publisher = EventPublisher::<String>::new();
        publisher.publish("hello".to_string());
        assert!(!publisher.has_subscriber());
    }

    #[test]
    fn test_publish_with_subscriber_receives_event() {
        let publisher = EventPublisher::<String>::new();
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        publisher.set_sender(tx);

        assert!(publisher.has_subscriber());
        publisher.publish("event_1".to_string());
        assert_eq!(rx.try_recv().unwrap(), "event_1");
    }

    #[test]
    fn test_clone_shares_same_channel() {
        let publisher = EventPublisher::<i32>::new();
        let cloned = publisher.clone();
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        publisher.set_sender(tx);

        // 通过 clone 发布，原始 publisher 的订阅者也能收到
        cloned.publish(42);
        assert_eq!(rx.try_recv().unwrap(), 42);
    }

    #[test]
    fn test_publish_after_receiver_dropped() {
        let publisher = EventPublisher::<String>::new();
        let (tx, rx) = tokio::sync::mpsc::unbounded_channel();
        publisher.set_sender(tx);
        drop(rx);

        // 接收端 drop 后发布不应 panic
        publisher.publish("lost".to_string());
    }
}
