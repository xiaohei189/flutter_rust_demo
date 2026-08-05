//! online 域外部服务线格式类型（请求/响应 DTO）
//!
//! 对齐 Go SDK HTTP 契约。
//! 当前由 core::online\::service 消费；如需端口化，可收敛为 $(OnlineStatusService.Replace('Service',''))ServerApi trait。

use crate::error::Result;
use async_trait::async_trait;
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

/// 在线状态域服务端 API（入向契约：SDK → OpenIM 服务端）
#[async_trait]
pub trait OnlineStatusServerApi: Send + Sync {
    async fn get_user_status(&self, req: &GetUserStatusReq) -> Result<GetUserStatusResp>;
    async fn subscribe_users_status(&self, req: &SubscribeUsersStatusReq) -> Result<SubscribeUsersStatusResp>;
    async fn unsubscribe_users_status(&self, req: &UnsubscribeUsersStatusReq) -> Result<()>;
    async fn get_subscribe_users_status(&self) -> Result<GetSubscribeUsersStatusResp>;
}
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_user_status_req_serialization() {
        let req = GetUserStatusReq {
            user_ids: vec!["user_1".to_string(), "user_2".to_string()],
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("userIDs"));
        assert!(json.contains("user_1"));
    }

    #[test]
    fn test_subscribe_users_status_req_serialization() {
        let req = SubscribeUsersStatusReq { user_ids: vec!["user_1".to_string()] };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("userIDs"));
    }

    #[test]
    fn test_user_status_item_deserialization() {
        let json = r#"{"userID":"user_1","status":1,"platformIDs":[1,2]}"#;
        let item: UserStatusItem = serde_json::from_str(json).unwrap();
        assert_eq!(item.user_id, "user_1");
        assert_eq!(item.status, 1);
        assert_eq!(item.platform_ids, vec![1, 2]);
    }

    #[test]
    fn test_online_status_creation() {
        let status = OnlineStatus {
            user_id: "user_1".to_string(),
            status: 1,
            platform_ids: vec![1],
        };
        assert_eq!(status.user_id, "user_1");
        assert_eq!(status.status, 1);
    }

    #[test]
    fn test_unsubscribe_users_status_req_serialization() {
        let req = UnsubscribeUsersStatusReq { user_ids: vec!["user_1".to_string()] };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("userIDs"));
    }

    #[test]
    fn test_get_user_status_resp_deserialization() {
        let json = r#"{"usersStatus":[{"userID":"user_1","status":1,"platformIDs":[1]}]}"#;
        let resp: GetUserStatusResp = serde_json::from_str(json).unwrap();
        assert_eq!(resp.users_status.len(), 1);
        assert_eq!(resp.users_status[0].status, 1);
    }
}
