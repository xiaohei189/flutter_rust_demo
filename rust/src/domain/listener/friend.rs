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

