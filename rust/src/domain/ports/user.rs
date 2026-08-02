//! user 域外部服务线格式类型（请求/响应 DTO）
//!
//! 对齐 Go SDK HTTP 契约。
//! 当前由 core::user\::service 消费；如需端口化，可收敛为 $(UserService.Replace('Service',''))ServerApi trait。

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
