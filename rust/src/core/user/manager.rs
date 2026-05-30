use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::bus::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::user::UserInfo;
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{GET_USERS_INFO, UPDATE_USER_INFO};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetUsersInfoReq {
    #[serde(rename = "userIDList")]
    pub user_id_list: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ServerUserInfo {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    pub gender: i32,
    pub telephone: String,
    pub email: String,
    pub ex: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetUsersInfoResp {
    #[serde(rename = "usersInfo")]
    pub users_info: Vec<ServerUserInfo>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UpdateUserInfoReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: Option<String>,
    #[serde(rename = "faceURL")]
    pub face_url: Option<String>,
    pub gender: Option<i32>,
    pub email: Option<String>,
    pub ex: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UpdateUserInfoResp {}

pub struct UserManager {
    http_client: Arc<HttpApiClient>,
    event_bus: Arc<EventBus>,
    self_user: Arc<RwLock<Option<UserInfo>>>,
}

impl UserManager {
    pub fn new(http_client: Arc<HttpApiClient>, event_bus: Arc<EventBus>) -> Self {
        Self {
            http_client,
            event_bus,
            self_user: Arc::new(RwLock::new(None)),
        }
    }

    pub async fn get_users_info(&self, user_ids: Vec<String>) -> Result<Vec<UserInfo>> {
        let req = GetUsersInfoReq {
            user_id_list: user_ids.clone(),
        };

        let resp: GetUsersInfoResp = self.http_client.post(GET_USERS_INFO, &req).await?;

        let users = resp
            .users_info
            .into_iter()
            .map(|s| server_to_domain(s))
            .collect();

        Ok(users)
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
        let user_id = self_user
            .as_ref()
            .ok_or_else(|| SdkError::unknown("用户未登录"))?
            .user_id
            .clone();

        let req = UpdateUserInfoReq {
            user_id: user_id.clone(),
            nickname: updates.nickname.clone(),
            face_url: updates.face_url.clone(),
            gender: updates.gender,
            email: updates.email.clone(),
            ex: None,
        };

        let _resp: UpdateUserInfoResp = self.http_client.post(UPDATE_USER_INFO, &req).await?;

        if let Some(user) = self.self_user.write().await.as_mut() {
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
        }

        info!("用户信息已更新到服务器");
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

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct UpdateUserFields {
    pub nickname: Option<String>,
    pub face_url: Option<String>,
    pub gender: Option<i32>,
    pub email: Option<String>,
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
        assert!(json.contains("userIDList"));
        assert!(json.contains("user_1"));
    }

    #[test]
    fn test_update_user_info_req_serialization() {
        let req = UpdateUserInfoReq {
            user_id: "user_123".to_string(),
            nickname: Some("New Name".to_string()),
            face_url: None,
            gender: Some(1),
            email: None,
            ex: None,
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("userID"));
        assert!(json.contains("New Name"));
    }
}
