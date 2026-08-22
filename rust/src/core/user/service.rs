use crate::domain::error::{Result, SdkError};
use crate::core::context::Repositories;
use crate::core::event::events::user::{UserEvent, UserListener, UserListenerExt};
use crate::infra::http::UserServerApi;
use crate::domain::model::local::LocalUser;
use crate::domain::model::user::UserInfo;

use crate::infra::http::user::*;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn};

pub struct UserService {
    api: Arc<dyn UserServerApi>,
    repositories: Arc<Repositories>,
    listener: Arc<dyn UserListener>,
    self_user: Arc<RwLock<Option<UserInfo>>>,
}

impl UserService {
    pub fn new(api: Arc<dyn UserServerApi>, repositories: Arc<Repositories>, listener: Arc<dyn UserListener>) -> Self {
        Self {
            api,
            repositories,
            listener,
            self_user: Arc::new(RwLock::new(None)),
        }
    }

    pub async fn get_users_info(&self, user_ids: Vec<String>) -> Result<Vec<UserInfo>> {
        let req = GetUsersInfoReq { user_id_list: user_ids.clone() };

        let resp = self.api.get_users_info(&req).await?;

        let users = resp.users_info.into_iter().map(server_to_domain).collect();

        // 写入本地用户表（对齐 Go SDK `batchAddFaceURLAndName` 的 GetUsersInfo 落库），供会话名称补全使用
        for user in &users {
            if let Err(e) = self.save_user_info(user).await {
                warn!("保存用户信息到本地失败: {}", e);
            }
        }

        Ok(users)
    }

    /// 保存用户信息到本地 users 表（对齐 Go SDK `saveUserInfo`），供会话名称补全使用
    pub async fn save_user_info(&self, user: &UserInfo) -> Result<()> {
        self.repositories
            .user_repo
            .upsert(&LocalUser {
                user_id: user.user_id.clone(),
                name: user.nickname.clone(),
                face_url: user.face_url.clone(),
                create_time: 0,
                app_manger_level: 0,
                ex: user.remark.clone(),
                attached_info: String::new(),
                global_recv_msg_opt: user.global_recv_msg_opt,
            })
            .await
    }

    /// 获取用户客户端配置（对齐 Go SDK `GetUserClientConfig` user/api.go L88-94）
    pub async fn get_user_client_config(&self) -> Result<std::collections::HashMap<String, String>> {
        let user_id = self.self_user.read().await.as_ref().ok_or_else(|| SdkError::unknown("用户未登录"))?.user_id.clone();
        let req = GetUserClientConfigReq { user_id };
        let resp = self.api.get_user_client_config(&req).await?;
        Ok(resp.raw_config)
    }

    pub async fn get_self_user_info(&self) -> Result<UserInfo> {
        if let Some(user) = self.self_user.read().await.clone() {
            Ok(user)
        } else {
            Err(SdkError::unknown("用户未登录"))
        }
    }

    pub async fn set_self_user_info(&self, user_info: UserInfo) {
        *self.self_user.write().await = Some(user_info);
        info!("本地用户信息已更新");
    }

    pub async fn update_self_user_info(&self, updates: UpdateUserFields) -> Result<()> {
        let self_user = self.self_user.read().await.clone();
        let user_id = self_user.as_ref().ok_or_else(|| SdkError::unknown("用户未登录"))?.user_id.clone();

        let req = UpdateUserInfoReq {
            user_info: UpdateUserInfoData {
                user_id: user_id.clone(),
                nickname: updates.nickname.clone(),
                face_url: updates.face_url.clone(),
                gender: updates.gender,
                email: updates.email.clone(),
                ex: updates.ex.clone(),
            },
        };

        let _resp = self.api.update_user_info(&req).await?;

        let updated_user = {
            let mut guard = self.self_user.write().await;
            if let Some(user) = guard.as_mut() {
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
                if let Some(ex) = updates.ex {
                    user.remark = ex;
                }
                Some(user.clone())
            } else {
                None
            }
        };

        if let Some(updated_user) = updated_user {
            // 写入本地用户表，供会话名称补全使用
            if let Err(e) = self.save_user_info(&updated_user).await {
                warn!("更新本地用户表失败: {}", e);
            }
            self.listener.emit(UserEvent::UserInfoUpdated { user: updated_user });
        }

        info!("用户信息已更新到服务器");
        Ok(())
    }

    /// 设置全局消息接收选项
    pub async fn set_global_msg_recv_opt(&self, global_recv_opt: i32) -> Result<()> {
        let user_id = self.get_user_id().await?;
        self.api.set_global_msg_recv_opt(&user_id, global_recv_opt).await?;
        info!("全局消息接收选项已更新: opt={}", global_recv_opt);
        Ok(())
    }

    pub async fn get_user_id(&self) -> Result<String> {
        if let Some(user) = self.self_user.read().await.as_ref() {
            Ok(user.user_id.clone())
        } else {
            Err(SdkError::unknown("用户未登录"))
        }
    }

    pub async fn is_logged_in(&self) -> bool {
        self.self_user.read().await.is_some()
    }

    pub async fn clear(&self) {
        *self.self_user.write().await = None;
        info!("用户信息已清除");
    }
}

fn server_to_domain(s: ServerUserInfo) -> UserInfo {
    UserInfo {
        user_id: s.user_id,
        nickname: s.nickname,
        face_url: s.face_url,
        gender: s.gender,
        telephone: s.telephone,
        email: s.email,
        remark: s.ex,
        global_recv_msg_opt: 0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_server_to_domain_conversion() {
        let server = ServerUserInfo {
            user_id: "user_123".to_string(),
            nickname: "Test User".to_string(),
            face_url: "https://example.com/avatar.jpg".to_string(),
            gender: 1,
            telephone: "13800138000".to_string(),
            email: "test@example.com".to_string(),
            ex: String::new(),
        };

        let domain = server_to_domain(server);
        assert_eq!(domain.user_id, "user_123");
        assert_eq!(domain.nickname, "Test User");
        assert_eq!(domain.gender, 1);
    }

    #[test]
    fn test_get_users_info_req_serialization() {
        let req = GetUsersInfoReq {
            user_id_list: vec!["user_1".to_string(), "user_2".to_string()],
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("userIDs"));
        assert!(json.contains("user_1"));
    }

    #[test]
    fn test_update_user_info_req_serialization() {
        let req = UpdateUserInfoReq {
            user_info: UpdateUserInfoData {
                user_id: "user_123".to_string(),
                nickname: Some("New Name".to_string()),
                face_url: None,
                gender: Some(1),
                email: None,
                ex: None,
            },
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("userInfo"));
        assert!(json.contains("userID"));
        assert!(json.contains("New Name"));
    }
}
