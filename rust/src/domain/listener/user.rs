use crate::domain::model::user::UserInfo;
use super::ListenerSet;

/// 用户/在线状态事件（UserInfoUpdated, UserStatusChanged）
pub struct UserListener {
    pub on_user_info_updated: ListenerSet<UserInfo>,
    pub on_user_status_changed: ListenerSet<(String, i32, Vec<i32>)>, // (user_id, status, platform_ids)
}

impl UserListener {
    pub fn new() -> Self {
        Self {
            on_user_info_updated: ListenerSet::new(),
            on_user_status_changed: ListenerSet::new(),
        }
    }
}
