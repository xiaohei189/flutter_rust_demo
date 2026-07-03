use crate::domain::model::friend::FriendInfo;
use super::ListenerSet;

/// Dart 侧好友事件
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

pub struct FriendListener {
    pub on_added: ListenerSet<Vec<FriendInfo>>,
    pub on_deleted: ListenerSet<String>,
    pub on_info_changed: ListenerSet<Vec<FriendInfo>>,
    pub on_black_added: ListenerSet<String>,
    pub on_black_deleted: ListenerSet<String>,
    pub on_application_added: ListenerSet<String>,
    pub on_application_accepted: ListenerSet<String>,
    pub on_application_rejected: ListenerSet<String>,
}

impl FriendListener {
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
