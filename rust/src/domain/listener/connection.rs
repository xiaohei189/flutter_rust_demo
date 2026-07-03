use super::ListenerSet;

/// Dart 侧连接事件
pub enum ConnectionEvent {
    Connecting,
    Connected,
    Disconnected(String),
    ConnectFailed(String),
    KickedOffline(String),
    TokenExpired,
    Reconnecting { attempt: u32, max_attempts: u32 },
    LoginSuccess(String),
}

/// 内部 listener（自然类型回调，bridge 层转为 ConnectionEvent）
pub struct ConnectionListener {
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

impl ConnectionListener {
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
