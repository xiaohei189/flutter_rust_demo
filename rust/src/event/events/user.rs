//! 用户监听 trait 与用户事件。
//!
//! 说明：`UserEvent` 为用户域事件，经 `UserListener` 分发（预留外部 SDK / 后续 Dart 流）。

use crate::model::user::UserInfo;

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
/// 事件 → 回调 的统一分发（Service 通过它把领域事件交给 Listener）
pub trait UserListenerExt: UserListener {
    fn emit(&self, event: UserEvent) {
        match event {
            UserEvent::UserInfoUpdated { user } => self.on_user_info_updated(&user),
            UserEvent::UserStatusChanged { user_id, status, platform_ids } => self.on_user_status_changed(&user_id, status, &platform_ids),
        }
    }
}
impl<T: UserListener + ?Sized> UserListenerExt for T {}