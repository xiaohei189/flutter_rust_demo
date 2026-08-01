use crate::domain::model::friend::FriendInfo;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum FriendEvent {
    Added(Vec<FriendInfo>),
    Deleted(String),
    InfoChanged(Vec<FriendInfo>),
    BlackAdded(String),
    BlackDeleted(String),
    ApplicationAdded(String),
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
    fn on_application_accepted(&self, _user_id: &str) {}
    fn on_application_rejected(&self, _user_id: &str) {}
}

