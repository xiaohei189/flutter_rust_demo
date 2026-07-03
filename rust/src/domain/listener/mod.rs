//! 模块化 Listener（对齐 Go SDK trait 接口模式）
//!
//! 每个模块定义 trait（ConnectionListener / ConversationListener / ...）
//! 消费者实现 trait，注册到对应模块的 ListenerRegistry 中

pub mod conversation;
pub mod connection;
pub mod friend;
pub mod group;
pub mod message;
pub mod user;
pub mod bridge;

use std::sync::Arc;

/// 通用 Listener 注册器（存 trait object）
pub struct ListenerRegistry<L: ?Sized + Send + Sync> {
    listeners: std::sync::RwLock<Vec<Arc<L>>>,
}

impl<L: ?Sized + Send + Sync> ListenerRegistry<L> {
    pub fn new() -> Self {
        Self {
            listeners: std::sync::RwLock::new(Vec::new()),
        }
    }

    pub fn register(&self, listener: Arc<L>) {
        self.listeners.write().unwrap().push(listener);
    }

    /// 遍历所有已注册 listener 并调用 f
    pub fn for_each(&self, f: impl Fn(&L)) {
        let listeners = self.listeners.read().unwrap().clone();
        for listener in &listeners {
            f(&**listener);
        }
    }
}

impl<L: ?Sized + Send + Sync> Default for ListenerRegistry<L> {
    fn default() -> Self {
        Self::new()
    }
}
