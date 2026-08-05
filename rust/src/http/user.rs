//! user 域外部服务线格式类型（请求/响应 DTO）
//!
//! 对齐 Go SDK HTTP 契约。

use crate::error::Result;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetUsersInfoReq {
    #[serde(rename = "userIDs")]
    pub user_id_list: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ServerUserInfo {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    #[serde(default)]
    pub gender: i32,
    #[serde(default)]
    pub telephone: String,
    #[serde(default)]
    pub email: String,
    #[serde(default)]
    pub ex: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetUsersInfoResp {
    #[serde(rename = "usersInfo")]
    pub users_info: Vec<ServerUserInfo>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UpdateUserInfoReq {
    #[serde(rename = "userInfo")]
    pub user_info: UpdateUserInfoData,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UpdateUserInfoData {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub nickname: Option<String>,
    #[serde(rename = "faceURL", skip_serializing_if = "Option::is_none")]
    pub face_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gender: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub email: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct UpdateUserInfoResp {}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct UpdateUserFields {
    pub nickname: Option<String>,
    pub face_url: Option<String>,
    pub gender: Option<i32>,
    pub email: Option<String>,
}

/// 用户域服务端 API（入向契约：SDK → OpenIM 服务端）
#[async_trait]
pub trait UserServerApi: Send + Sync {
    async fn get_users_info(&self, req: &GetUsersInfoReq) -> Result<GetUsersInfoResp>;
    async fn update_user_info(&self, req: &UpdateUserInfoReq) -> Result<UpdateUserInfoResp>;
    async fn set_global_msg_recv_opt(&self, user_id: &str, global_recv_opt: i32) -> Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_users_info_req_serialization() {
        let req = GetUsersInfoReq {
            user_id_list: vec!["user_1".to_string()],
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("userIDs"));
    }

    #[test]
    fn test_update_user_info_req_serialization() {
        let req = UpdateUserInfoReq {
            user_info: UpdateUserInfoData {
                user_id: "user_1".to_string(),
                nickname: Some("NewName".to_string()),
                face_url: None,
                gender: None,
                email: None,
                ex: None,
            },
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("userInfo"));
        assert!(json.contains("nickname"));
        assert!(json.contains("NewName"));
    }
}
