use std::sync::Arc;

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

pub struct ConnectionListeners {
    listener: std::sync::RwLock<Option<Arc<dyn ConnectionListener>>>,
}

impl ConnectionListeners {
    pub fn new() -> Self {
        Self { listener: std::sync::RwLock::new(None) }
    }

    pub fn set(&self, l: Arc<dyn ConnectionListener>) {
        *self.listener.write().unwrap() = Some(l);
    }

    fn call(&self, f: impl FnOnce(&dyn ConnectionListener)) {
        if let Some(l) = &*self.listener.read().unwrap() {
            f(&**l);
        }
    }

    pub fn on_connected(&self)   { self.call(|l| l.on_connected()); }
    pub fn on_connecting(&self)  { self.call(|l| l.on_connecting()); }
    pub fn on_disconnected(&self, r: &str) { self.call(|l| l.on_disconnected(r)); }
    pub fn on_kicked_offline(&self, r: &str) { self.call(|l| l.on_kicked_offline(r)); }
    pub fn on_token_expired(&self) { self.call(|l| l.on_token_expired()); }
    pub fn on_reconnecting(&self, a: u32, m: u32) { self.call(|l| l.on_reconnecting(a, m)); }
    pub fn on_login_success(&self, id: &str) { self.call(|l| l.on_login_success(id)); }
    pub fn on_logout(&self) { self.call(|l| l.on_logout()); }
}
