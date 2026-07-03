use crate::domain::model::friend::FriendInfo;
use super::ListenerSet;

/// friend 事件（对齐 Go SDK FriendListener）
pub trait FriendListener: Send + Sync {
    fn on_added(&self, _friends: &[FriendInfo]) {}
    fn on_deleted(&self, _user_id: &str) {}
    fn on_info_changed(&self, _friends: &[FriendInfo]) {}
    fn on_black_added(&self, _user_id: &str) {}
    fn on_black_deleted(&self, _user_id: &str) {}
    fn on_application_added(&self, _user_id: &str) {}
    fn on_application_accepted(&self, _user_id: &str) {}
    fn on_application_rejected(&self, _user_id: &str) {}
}

// === 以下为旧 ListenerSet 模式，逐步迁移后删除 ===

pub struct FriendListeners {
    pub pub on_added: ListenerSet<Vec<FriendInfo>>,
    pub on_deleted: ListenerSet<String>,
    pub on_info_changed: ListenerSet<Vec<FriendInfo>>,
    pub on_black_added: ListenerSet<String>,
    pub on_black_deleted: ListenerSet<String>,
    pub on_application_added: ListenerSet<String>,
    pub on_application_accepted: ListenerSet<String>,
    pub on_application_rejected: ListenerSet<String>,
}

impl FriendListeners {
    pub fn new() -> Self {
        Self {
            on_added: ListenerSet::new(),
            on_deleted: ListenerSet::new(),
            on_info_changed: ListenerSet::new(),
            on_black_added: ListenerSet::new(),
            on_black_deleted: ListenerSet::new(),
            on_application_added: ListenerSet::new(),
            on_application_accepted: ListenerSet::new(),
            on_application_rejected: ListenerSet::new(),
        }
    }
}
