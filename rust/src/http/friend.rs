//! 好友域外部服务线格式类型（请求/响应 DTO）
//!
//! 对齐 Go SDK `internal/relation/relation.go` 的 HTTP 契约。
//! 当前由 `core::friend::service` 消费；如需端口化，可收敛为 `FriendServerApi` trait。

use crate::domain::error::Result;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use crate::http::types::Pagination;
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFriendListReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "pagination")]
    pub pagination: Pagination,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FriendUserInfo {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    pub ex: String,
    #[serde(rename = "createTime", default)]
    pub create_time: i64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FriendServerInfo {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    pub remark: String,
    #[serde(rename = "createTime", default)]
    pub create_time: i64,
    #[serde(rename = "friendUser")]
    pub friend_user: FriendUserInfo,
    #[serde(rename = "addSource", default)]
    pub add_source: i32,
    #[serde(rename = "operatorUserID", default)]
    pub operator_user_id: String,
    #[serde(default)]
    pub ex: String,
    #[serde(rename = "isPinned", default)]
    pub is_pinned: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetFriendListResp {
    #[serde(rename = "friendsInfo", default)]
    pub friends_info: Option<Vec<FriendServerInfo>>,
    #[serde(rename = "total", default)]
    pub total: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AddFriendReq {
    #[serde(rename = "fromUserID")]
    pub from_user_id: String,
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
    #[serde(rename = "reqMsg")]
    pub req_msg: Option<String>,
    #[serde(rename = "ex", skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DeleteFriendReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "friendUserID")]
    pub friend_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFriendIdListResp {
    #[serde(rename = "friendIDs")]
    pub friend_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AddBlackReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "blackUserID")]
    pub black_user_id: String,
    #[serde(rename = "ex", skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RemoveBlackReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "blackUserID")]
    pub black_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetBlackListResp {
    #[serde(rename = "blacks", default)]
    pub blacks: Vec<BlackServerInfo>,
    #[serde(default)]
    pub total: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct BlackUserInfo {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    pub ex: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BlackServerInfo {
    #[serde(rename = "ownerUserID", default)]
    pub owner_user_id: String,
    #[serde(rename = "createTime", default)]
    pub create_time: i64,
    #[serde(rename = "blackUserInfo", default)]
    pub black_user_info: BlackUserInfo,
    #[serde(rename = "addSource", default)]
    pub add_source: i32,
    #[serde(rename = "operatorUserID", default)]
    pub operator_user_id: String,
    #[serde(default)]
    pub ex: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFriendApplyListReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "pagination")]
    pub pagination: Pagination,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetFriendApplyListResp {
    #[serde(rename = "applyInfos", default)]
    pub apply_infos: Option<Vec<FriendApplyInfo>>,
    #[serde(rename = "total", default)]
    pub total: i32,
}

/// 服务端原始好友申请对象（对齐 sdkws.FriendRequest）
#[derive(Clone, Debug, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct ServerFriendRequest {
    #[serde(rename = "fromUserID", default)]
    pub from_user_id: String,
    #[serde(rename = "fromNickname", default)]
    pub from_nickname: String,
    #[serde(rename = "fromFaceURL", default)]
    pub from_face_url: String,
    #[serde(rename = "toUserID", default)]
    pub to_user_id: String,
    #[serde(rename = "toNickname", default)]
    pub to_nickname: String,
    #[serde(rename = "toFaceURL", default)]
    pub to_face_url: String,
    #[serde(rename = "handleResult", default)]
    pub handle_result: i32,
    #[serde(rename = "reqMsg", default)]
    pub req_msg: String,
    #[serde(rename = "createTime", default)]
    pub create_time: i64,
    #[serde(rename = "handlerUserID", default)]
    pub handler_user_id: String,
    #[serde(default)]
    pub ex: String,
}

/// 服务端好友申请列表响应（字段名为 friendRequests）
#[derive(Clone, Debug, Deserialize, Default)]
pub struct GetFriendApplyListServerResp {
    #[serde(rename = "FriendRequests", default)]
    pub friend_requests: Vec<ServerFriendRequest>,
    #[serde(default)]
    pub total: i32,
}

impl From<GetFriendApplyListServerResp> for GetFriendApplyListResp {
    fn from(resp: GetFriendApplyListServerResp) -> Self {
        Self {
            apply_infos: Some(
                resp.friend_requests
                    .into_iter()
                    .map(|r| FriendApplyInfo {
                        user_id: r.from_user_id,
                        nickname: r.from_nickname,
                        face_url: r.from_face_url,
                        gender: 0,
                        create_time: r.create_time,
                        add_source: 0,
                        ex: r.ex,
                        req_msg: Some(r.req_msg),
                        handle_result: r.handle_result,
                        handle_msg: None,
                    })
                    .collect(),
            ),
            total: resp.total,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FriendApplyInfo {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    pub gender: i32,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    #[serde(rename = "addSource")]
    pub add_source: i32,
    pub ex: String,
    pub req_msg: Option<String>,
    pub handle_result: i32,
    pub handle_msg: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AcceptFriendApplicationReq {
    #[serde(rename = "fromUserID")]
    pub from_user_id: String,
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
    #[serde(rename = "handleResult")]
    pub handle_result: i32,
    #[serde(rename = "handleMsg")]
    pub handle_msg: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RefuseFriendApplicationReq {
    #[serde(rename = "fromUserID")]
    pub from_user_id: String,
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
    #[serde(rename = "handleResult")]
    pub handle_result: i32,
    #[serde(rename = "handleMsg")]
    pub handle_msg: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CheckFriendResult {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "result")]
    pub result: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetIncrementalFriendsReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub version: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetIncrementalFriendsResp {
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub full: bool,
    #[serde(default, deserialize_with = "crate::http::de_vec_or_default")]
    pub delete: Vec<String>,
    #[serde(default, deserialize_with = "crate::http::de_vec_or_default")]
    pub insert: Vec<FriendServerInfo>,
    #[serde(default, deserialize_with = "crate::http::de_vec_or_default")]
    pub update: Vec<FriendServerInfo>,
    #[serde(rename = "sortVersion", default)]
    pub sort_version: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFullFriendUserIDsReq {
    #[serde(rename = "idHash")]
    pub id_hash: u64,
    #[serde(rename = "userID")]
    pub user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetFullFriendUserIDsResp {
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub equal: bool,
    #[serde(rename = "userIDs", default)]
    pub user_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SearchFriendsParam {
    #[serde(rename = "keywordList")]
    pub keyword_list: Vec<String>,
    #[serde(rename = "isSearchUserID", default)]
    pub is_search_user_id: bool,
    #[serde(rename = "isSearchNickname", default)]
    pub is_search_nickname: bool,
    #[serde(rename = "isSearchRemark", default)]
    pub is_search_remark: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SearchFriendItem {
    #[serde(rename = "friendUserID")]
    pub friend_user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    pub remark: String,
    pub ex: String,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    /// 1=好友, 2=黑名单
    #[serde(rename = "relationship")]
    pub relationship: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetDesignatedFriendsReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "friendUserIDs")]
    pub friend_user_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetDesignatedFriendsResp {
    #[serde(rename = "friendsInfo", default)]
    pub friends_info: Vec<FriendServerInfo>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UpdateFriendsReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "friendUserIDs")]
    pub friend_user_ids: Vec<String>,
    #[serde(rename = "isPinned", skip_serializing_if = "Option::is_none")]
    pub is_pinned: Option<bool>,
    #[serde(rename = "remark", skip_serializing_if = "Option::is_none")]
    pub remark: Option<String>,
    #[serde(rename = "ex", skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
}

/// 好友域服务端 API（入向契约：SDK → OpenIM 服务端）
#[async_trait]
pub trait FriendServerApi: Send + Sync {
    async fn get_friend_list(&self, req: &GetFriendListReq) -> Result<GetFriendListResp>;
    async fn get_incremental_friends(&self, req: &GetIncrementalFriendsReq) -> Result<GetIncrementalFriendsResp>;
    async fn get_designated_friends(&self, req: &GetDesignatedFriendsReq) -> Result<GetDesignatedFriendsResp>;
    async fn update_friends(&self, req: &UpdateFriendsReq) -> Result<()>;
    async fn add_friend(&self, req: &AddFriendReq) -> Result<()>;
    async fn delete_friend(&self, req: &DeleteFriendReq) -> Result<()>;
    async fn check_friend(&self, user_ids: &[String]) -> Result<Vec<CheckFriendResult>>;
    async fn get_black_list(&self, user_id: &str) -> Result<GetBlackListResp>;
    async fn add_black(&self, req: &AddBlackReq) -> Result<()>;
    async fn remove_black(&self, req: &RemoveBlackReq) -> Result<()>;
    async fn get_friend_apply_list(&self, req: &GetFriendApplyListReq) -> Result<GetFriendApplyListResp>;
    async fn get_self_friend_apply_list(&self, req: &GetFriendApplyListReq) -> Result<GetFriendApplyListResp>;
    async fn get_self_unhandled_apply_count(&self, user_id: &str) -> Result<i32>;
    async fn accept_friend_application(&self, req: &AcceptFriendApplicationReq) -> Result<()>;
    async fn refuse_friend_application(&self, req: &RefuseFriendApplicationReq) -> Result<()>;
}
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add_friend_req_serialization() {
        let req = AddFriendReq {
            from_user_id: "user_a".to_string(),
            to_user_id: "user_b".to_string(),
            req_msg: Some("Hello!".to_string()),
            ex: None,
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("fromUserID"));
        assert!(json.contains("toUserID"));
        assert!(json.contains("Hello!"));
    }

    #[test]
    fn test_friend_apply_info_deserialization() {
        let json = r#"{"userID":"user_1","nickname":"Test","faceURL":"http://example.com/avatar.jpg","gender":1,"createTime":1234567890,"addSource":1,"ex":"","reqMsg":"Hello","handle_result":0,"handle_msg":null}"#;
        let info: FriendApplyInfo = serde_json::from_str(json).unwrap();
        assert_eq!(info.user_id, "user_1");
        assert_eq!(info.nickname, "Test");
    }

    #[test]
    fn test_accept_friend_application_req_serialization() {
        let req = AcceptFriendApplicationReq {
            from_user_id: "user_a".to_string(),
            to_user_id: "user_b".to_string(),
            handle_result: 1,
            handle_msg: Some("Accepted".to_string()),
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("fromUserID"));
        assert!(json.contains("toUserID"));
        assert!(json.contains("handleResult"));
        assert!(json.contains("Accepted"));
    }

    #[test]
    fn test_get_friend_apply_list_req_serialization() {
        let req = GetFriendApplyListReq {
            user_id: "user_a".to_string(),
            pagination: Pagination { page_number: 1, show_number: 50 },
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("pagination"));
    }

    #[test]
    fn test_check_friend_result_deserialization() {
        let json = r#"{"userID":"user_1","result":1}"#;
        let result: CheckFriendResult = serde_json::from_str(json).unwrap();
        assert_eq!(result.user_id, "user_1");
        assert_eq!(result.result, 1);
    }

    #[test]
    fn test_get_incremental_friends_req_serialization() {
        let req = GetIncrementalFriendsReq {
            user_id: "user_a".to_string(),
            version_id: "v1".to_string(),
            version: 5,
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("userID"));
        assert!(json.contains("versionID"));
        assert!(json.contains("version"));
    }

    #[test]
    fn test_incremental_friends_resp_null_arrays() {
        let json = r#"{"version":1,"versionID":"v1","full":true,"delete":null,"insert":null,"update":null,"sortVersion":0}"#;
        let resp: GetIncrementalFriendsResp = serde_json::from_str(json).unwrap();
        assert!(resp.delete.is_empty());
        assert!(resp.insert.is_empty());
        assert!(resp.update.is_empty());
    }

    #[test]
    fn test_update_friends_req_serialization_with_pinned() {
        let req = UpdateFriendsReq {
            owner_user_id: "user_a".to_string(),
            friend_user_ids: vec!["user_b".to_string()],
            is_pinned: Some(true),
            remark: None,
            ex: None,
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("isPinned"));
        assert!(json.contains("true"));
        assert!(!json.contains("remark"));
    }

    #[test]
    fn test_search_friend_item_deserialization() {
        let json = r#"{"friendUserID":"user_1","nickname":"Test","faceURL":"","remark":"","ex":"","createTime":1000,"relationship":1}"#;
        let item: SearchFriendItem = serde_json::from_str(json).unwrap();
        assert_eq!(item.friend_user_id, "user_1");
        assert_eq!(item.relationship, 1);
    }

    #[test]
    fn test_black_list_resp_deserialization() {
        let json = r#"{"blacks":[{"ownerUserID":"me","createTime":1,"blackUserInfo":{"userID":"black_1","nickname":"Blocked User","faceURL":"","ex":""},"addSource":0,"operatorUserID":"me","ex":""}],"total":1}"#;
        let resp: GetBlackListResp = serde_json::from_str(json).unwrap();
        assert_eq!(resp.total, 1);
        assert_eq!(resp.blacks.len(), 1);
        assert_eq!(resp.blacks[0].black_user_info.user_id, "black_1");
        assert_eq!(resp.blacks[0].black_user_info.nickname, "Blocked User");
    }
}
