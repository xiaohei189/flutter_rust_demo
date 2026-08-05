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

impl ConnectionEvent {
    /// 事件类型字符串（用于日志与测试）
    pub fn as_str(&self) -> &'static str {
        match self {
            ConnectionEvent::Connecting => "connecting",
            ConnectionEvent::Connected => "connected",
            ConnectionEvent::Disconnected(_) => "disconnected",
            ConnectionEvent::ConnectFailed(_) => "connect_failed",
            ConnectionEvent::KickedOffline(_) => "kicked_offline",
            ConnectionEvent::TokenExpired => "token_expired",
            ConnectionEvent::Reconnecting { .. } => "reconnecting",
            ConnectionEvent::LoginSuccess(_) => "login_success",
            ConnectionEvent::Logout => "logout",
        }
    }
}

/// 连接事件 trait（对齐 Go SDK ConnectionListener 接口）
pub trait ConnectionListener: Send + Sync {
    fn on_connecting(&self) {}
    fn on_connected(&self) {}
    fn on_disconnected(&self, _reason: &str) {}
    fn on_connect_failed(&self, _error: &str) {}
    fn on_kicked_offline(&self, _reason: &str) {}
    fn on_token_expired(&self) {}
    fn on_reconnecting(&self, _attempt: u32, _max_attempts: u32) {}
    fn on_login_success(&self, _user_id: &str) {}
    fn on_logout(&self) {}
}

/// 事件 → 回调 的统一分发（Service 通过它把领域事件交给 Listener）
pub trait ConnectionListenerExt: ConnectionListener {
    fn emit(&self, event: ConnectionEvent) {
        match event {
            ConnectionEvent::Connecting => self.on_connecting(),
            ConnectionEvent::Connected => self.on_connected(),
            ConnectionEvent::Disconnected(reason) => self.on_disconnected(&reason),
            ConnectionEvent::ConnectFailed(error) => self.on_connect_failed(&error),
            ConnectionEvent::KickedOffline(reason) => self.on_kicked_offline(&reason),
            ConnectionEvent::TokenExpired => self.on_token_expired(),
            ConnectionEvent::Reconnecting { attempt, max_attempts } => self.on_reconnecting(attempt, max_attempts),
            ConnectionEvent::LoginSuccess(user_id) => self.on_login_success(&user_id),
            ConnectionEvent::Logout => self.on_logout(),
        }
    }
}
impl<T: ConnectionListener + ?Sized> ConnectionListenerExt for T {}
