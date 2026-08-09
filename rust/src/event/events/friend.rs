use crate::model::friend::FriendInfo;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum FriendEvent {
    Added(Vec<FriendInfo>),
    Deleted(String),
    InfoChanged(Vec<FriendInfo>),
    BlackAdded(String),
    BlackDeleted(String),
    ApplicationAdded(String),
    ApplicationDeleted(String),
    ApplicationAccepted(String),
    ApplicationRejected(String),
}

impl FriendEvent {
    /// 事件类型字符串（用于日志与测试）
    pub fn as_str(&self) -> &'static str {
        match self {
            FriendEvent::Added(_) => "added",
            FriendEvent::Deleted(_) => "deleted",
            FriendEvent::InfoChanged(_) => "info_changed",
            FriendEvent::BlackAdded(_) => "black_added",
            FriendEvent::BlackDeleted(_) => "black_deleted",
            FriendEvent::ApplicationAdded(_) => "application_added",
            FriendEvent::ApplicationDeleted(_) => "application_deleted",
            FriendEvent::ApplicationAccepted(_) => "application_accepted",
            FriendEvent::ApplicationRejected(_) => "application_rejected",
        }
    }
}

/// friend 事件（对齐 Go SDK FriendListener）
pub trait FriendListener: Send + Sync {
    fn on_added(&self, _friends: &[FriendInfo]) {}
    fn on_deleted(&self, _user_id: &str) {}
    fn on_info_changed(&self, _friends: &[FriendInfo]) {}
    fn on_black_added(&self, _user_id: &str) {}
    fn on_black_deleted(&self, _user_id: &str) {}
    fn on_application_added(&self, _user_id: &str) {}
    fn on_application_deleted(&self, _user_id: &str) {}
    fn on_application_accepted(&self, _user_id: &str) {}
    fn on_application_rejected(&self, _user_id: &str) {}
}

/// 事件 → 回调 的统一分发（Service 通过它把领域事件交给 Listener）
pub trait FriendListenerExt: FriendListener {
    fn emit(&self, event: FriendEvent) {
        match event {
            FriendEvent::Added(friends) => self.on_added(&friends),
            FriendEvent::Deleted(user_id) => self.on_deleted(&user_id),
            FriendEvent::InfoChanged(friends) => self.on_info_changed(&friends),
            FriendEvent::BlackAdded(user_id) => self.on_black_added(&user_id),
            FriendEvent::BlackDeleted(user_id) => self.on_black_deleted(&user_id),
            FriendEvent::ApplicationAdded(user_id) => self.on_application_added(&user_id),
            FriendEvent::ApplicationDeleted(user_id) => self.on_application_deleted(&user_id),
            FriendEvent::ApplicationAccepted(user_id) => self.on_application_accepted(&user_id),
            FriendEvent::ApplicationRejected(user_id) => self.on_application_rejected(&user_id),
        }
    }
}
impl<T: FriendListener + ?Sized> FriendListenerExt for T {}
