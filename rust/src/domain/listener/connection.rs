use super::ListenerSet;

/// 连接状态事件（替代 SdkEvent::Connecting/Connected/... 的 EventBus 广播）
pub struct ConnectionListener {
    pub on_connecting: ListenerSet<()>,
    pub on_connected: ListenerSet<()>,
    pub on_disconnected: ListenerSet<String>,
    pub on_connect_failed: ListenerSet<String>,
    pub on_kicked_offline: ListenerSet<String>,
    pub on_token_expired: ListenerSet<()>,
    pub on_reconnecting: ListenerSet<(u32, u32)>,
    pub on_login_success: ListenerSet<String>,
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
        }
    }
}
