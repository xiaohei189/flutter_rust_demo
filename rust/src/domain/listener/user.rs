use crate::domain::model::user::UserInfo;

/// 用户/在线状态事件 trait
pub trait UserListener: Send + Sync {
    fn on_user_info_updated(&self, _user: &UserInfo) {}
    fn on_user_status_changed(&self, _user_id: &str, _status: i32, _platform_ids: &[i32]) {}
}
