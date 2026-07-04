use serde::{Deserialize, Serialize};

/// Dart 侧连接事件
#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum ConnectionEvent {
    Connecting,
    Connected,
    Disconnected(String),
    ConnectFailed(String),
    KickedOffline(String),
    TokenExpired,
    Reconnecting { attempt: u32, max_attempts: u32 },
    LoginSuccess(String),
    Logout,
}

/// 连接事件 trait（对齐 Go SDK ConnectionListener 接口）
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
