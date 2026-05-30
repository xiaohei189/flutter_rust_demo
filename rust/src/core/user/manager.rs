use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::bus::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::user::UserInfo;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info};

/// 用户管理器
pub struct UserManager {
    /// 用户信息缓存
    users: Arc<RwLock<Option<UserInfo>>>,
    /// 事件总线
    event_bus: Arc<EventBus>,
}

impl UserManager {
    pub fn new(event_bus: Arc<EventBus>) -> Self {
        Self {
            users: Arc::new(RwLock::new(None)),
            event_bus,
        }
    }

    /// 获取当前用户信息
    pub async fn get_self_user_info(&self) -> Result<UserInfo> {
        if let Some(user) = self.users.read().await.clone() {
            Ok(user)
        } else {
            Err(SdkError::unknown("用户未登录"))
        }
    }

    /// 设置当前用户信息
    pub async fn set_self_user_info(&self, user_info: UserInfo) {
        *self.users.write().await = Some(user_info);
        info!("用户信息已更新");
    }

    /// 更新用户信息
    pub async fn update_user_info(&self, updates: UserInfoUpdate) -> Result<()> {
        if let Some(user) = self.users.write().await.as_mut() {
            if let Some(nickname) = updates.nickname {
                user.nickname = nickname;
            }
            if let Some(face_url) = updates.face_url {
                user.face_url = face_url;
            }
            if let Some(gender) = updates.gender {
                user.gender = gender;
            }
            if let Some(email) = updates.email {
                user.email = email;
            }

            let user_json = serde_json::to_value(&user).unwrap_or_default();
            self.event_bus.publish(SdkEvent::UserInfoUpdated {
                user: user_json,
            });
            

            info!("用户信息已更新");
            Ok(())
        } else {
            Err(SdkError::unknown("用户未登录"))
        }
    }

    /// 获取用户 ID
    pub async fn get_user_id(&self) -> Result<String> {
        if let Some(user) = self.users.read().await.as_ref() {
            Ok(user.user_id.clone())
        } else {
            Err(SdkError::unknown("用户未登录"))
        }
    }

    /// 检查是否已登录
    pub async fn is_logged_in(&self) -> bool {
        self.users.read().await.is_some()
    }

    /// 清除用户信息（登出时调用）
    pub async fn clear(&self) {
        *self.users.write().await = None;
        info!("用户信息已清除");
    }
}

/// 用户信息更新
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct UserInfoUpdate {
    pub nickname: Option<String>,
    pub face_url: Option<String>,
    pub gender: Option<i32>,
    pub email: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_user_manager_creation() {
        let event_bus = Arc::new(EventBus::new());
        let manager = UserManager::new(event_bus);

        assert!(!manager.is_logged_in().await);
        assert!(manager.get_self_user_info().await.is_err());
    }

    #[tokio::test]
    async fn test_user_manager_set_and_get() {
        let event_bus = Arc::new(EventBus::new());
        let manager = UserManager::new(event_bus);

        let user_info = UserInfo {
            user_id: "user_123".to_string(),
            nickname: "Test User".to_string(),
            face_url: "https://example.com/avatar.jpg".to_string(),
            gender: 1,
            telephone: "13800138000".to_string(),
            email: "test@example.com".to_string(),
            remark: String::new(),
            global_recv_msg_opt: 0,
        };

        manager.set_self_user_info(user_info).await;
        assert!(manager.is_logged_in().await);

        let retrieved = manager.get_self_user_info().await.unwrap();
        assert_eq!(retrieved.user_id, "user_123");
        assert_eq!(retrieved.nickname, "Test User");
    }

    #[tokio::test]
    async fn test_user_manager_update() {
        let event_bus = Arc::new(EventBus::new());
        let manager = UserManager::new(event_bus);

        let user_info = UserInfo {
            user_id: "user_123".to_string(),
            nickname: "Old Name".to_string(),
            face_url: String::new(),
            gender: 0,
            telephone: String::new(),
            email: String::new(),
            remark: String::new(),
            global_recv_msg_opt: 0,
        };

        manager.set_self_user_info(user_info).await;

        manager
            .update_user_info(UserInfoUpdate {
                nickname: Some("New Name".to_string()),
                face_url: Some("https://example.com/new.jpg".to_string()),
                ..Default::default()
            })
            .await
            .unwrap();

        let retrieved = manager.get_self_user_info().await.unwrap();
        assert_eq!(retrieved.nickname, "New Name");
        assert_eq!(retrieved.face_url, "https://example.com/new.jpg");
    }

    #[tokio::test]
    async fn test_user_manager_clear() {
        let event_bus = Arc::new(EventBus::new());
        let manager = UserManager::new(event_bus);

        let user_info = UserInfo {
            user_id: "user_123".to_string(),
            nickname: "Test User".to_string(),
            face_url: String::new(),
            gender: 0,
            telephone: String::new(),
            email: String::new(),
            remark: String::new(),
            global_recv_msg_opt: 0,
        };

        manager.set_self_user_info(user_info).await;
        assert!(manager.is_logged_in().await);

        manager.clear().await;
        assert!(!manager.is_logged_in().await);
    }
}
