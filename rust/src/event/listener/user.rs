//! 用户监听 trait。
//!
//! 说明：用户事件未定义独立的 `UserEvent` 枚举——用户/在线状态事件统一走
//! [`SdkEvent`](crate::event::types::SdkEvent)，待与 `*Event` 体系合并时统一。

use crate::domain::model::user::UserInfo;

/// 用户/在线状态事件 trait
pub trait UserListener: Send + Sync {
    fn on_user_info_updated(&self, _user: &UserInfo) {}
    fn on_user_status_changed(&self, _user_id: &str, _status: i32, _platform_ids: &[i32]) {}
}
