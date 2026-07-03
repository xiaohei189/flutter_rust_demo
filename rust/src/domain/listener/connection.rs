use super::ListenerSet;

/// 连接事件（对齐 Go SDK ConnectionListener）
pub trait ConnectionListener: Send + Sync {
    fn on_connecting(&self) {}
    fn on_connected(&self) {}
    fn on_disconnected(&self, _reason: &str) {}
    fn on_kicked_offline(&self, _reason: &str) {}
    fn on_token_expired(&self) {}
    fn on_reconnecting(&self, _attempt: u32, _max_attempts: u32) {}
    fn on_login_success(&self, _user_id: &str) {}
    fn on_logout(&self) {}
}

// === 以下为旧 ListenerSet 模式，逐步迁移后删除 ===

pub struct ConnectionListeners {
    pub on_connecting: ListenerSet<()>,
    pub on_connected: ListenerSet<()>,
    pub on_disconnected: ListenerSet<String>,
    pub on_connect_failed: ListenerSet<String>,
    pub on_kicked_offline: ListenerSet<String>,
    pub on_token_expired: ListenerSet<()>,
    pub on_reconnecting: ListenerSet<(u32, u32)>,
    pub on_login_success: ListenerSet<String>,
    pub on_logout: ListenerSet<()>,
}

impl ConnectionListeners {
    pub fn new() -> Self {
        Self {
            on_connecting: ListenerSet::new(),
            on_connected: ListenerSet::new(),
            on_disconnected: ListenerSet::new(),
            on_connect_failed: ListenerSet::new(),
            on_kicked_offline: ListenerSet::new(),
            on_token_expired: ListenerSet::new(),
            on_reconnecting: ListenerSet::new(),
            on_login_success: ListenerSet::new(),
            on_logout: ListenerSet::new(),
        }
    }
}
