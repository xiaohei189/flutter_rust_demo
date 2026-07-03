//! 模块化 Listener（对齐 Go SDK 每个模块独立 listener 接口的模式）
//!
//! 当前 EventBus 混合了所有事件类型，Go SDK 按模块区分：
//!   ConversationListener / FriendListener / GroupListener / ConnectionListener
//!
//! 重构原则：
//!   - 内部调用：模块直接通知已注册的 listener
//!   - Dart 桥接：注册 listener → 转为统一 Stream 发给 Flutter
//!   - 逐步迁移，不在 EventBus 上叠加新机制

pub mod conversation;
pub mod connection;
pub mod friend;
pub mod group;
pub mod message;
pub mod bridge;

use std::sync::Arc;

/// 回调注册器，线程安全
pub struct ListenerSet<T: Send + Sync + 'static> {
    listeners: std::sync::RwLock<Vec<Arc<dyn Fn(&T) + Send + Sync>>>,
}

impl<T: Send + Sync + 'static> ListenerSet<T> {
    pub fn new() -> Self {
        Self {
            listeners: std::sync::RwLock::new(Vec::new()),
        }
    }

    pub fn register<F: Fn(&T) + Send + Sync + 'static>(&self, f: F) {
        self.listeners.write().unwrap().push(Arc::new(f));
    }

    /// 同步通知所有已注册 listener
    pub fn notify(&self, event: &T) {
        let listeners = self.listeners.read().unwrap().clone();
        for listener in &listeners {
            listener(event);
        }
    }
}
