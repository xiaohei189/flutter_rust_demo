//! 用户监听 trait 与用户事件。
//!
//! 说明：`UserEvent` 为内部事件总线承载的用户域事件（经 `SdkEvent::User` 分发）。

use crate::domain::model::user::UserInfo;

/// 用户域事件（内部事件总线使用）
#[derive(Clone, Debug)]
pub enum UserEvent {
    /// 用户资料更新
    UserInfoUpdated {
        user: UserInfo,
    },
    /// 在线状态变更
    UserStatusChanged {
        user_id: String,
        status: i32,
        platform_ids: Vec<i32>,
    },
}

impl UserEvent {
    /// 事件类型字符串（用于日志与测试）
    pub fn as_str(&self) -> &'static str {
        match self {
            UserEvent::UserInfoUpdated { .. } => "user_info_updated",
            UserEvent::UserStatusChanged { .. } => "user_status_changed",
        }
    }
}

/// 用户/在线状态事件 trait
pub trait UserListener: Send + Sync {
    fn on_user_info_updated(&self, _user: &UserInfo) {}
    fn on_user_status_changed(&self, _user_id: &str, _status: i32, _platform_ids: &[i32]) {}
}