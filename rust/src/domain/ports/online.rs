//! online 域外部服务线格式类型（请求/响应 DTO）
//!
//! 对齐 Go SDK HTTP 契约。
//! 当前由 core::online\::service 消费；如需端口化，可收敛为 $(OnlineStatusService.Replace('Service',''))ServerApi trait。

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetUserStatusReq {
    #[serde(rename = "userIDs")]
    pub user_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UserStatusItem {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "status")]
    pub status: i32,
    #[serde(rename = "platformIDs")]
    pub platform_ids: Vec<i32>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetUserStatusResp {
    #[serde(rename = "usersStatus", default)]
    pub users_status: Vec<UserStatusItem>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SubscribeUsersStatusReq {
    #[serde(rename = "userIDs")]
    pub user_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct SubscribeUsersStatusResp {
    #[serde(rename = "usersStatus", default)]
    pub users_status: Vec<UserStatusItem>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UnsubscribeUsersStatusReq {
    #[serde(rename = "userIDs")]
    pub user_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetSubscribeUsersStatusResp {
    #[serde(rename = "usersStatus", default)]
    pub users_status: Vec<UserStatusItem>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct OnlineStatus {
    pub user_id: String,
    pub status: i32,
    pub platform_ids: Vec<i32>,
}
