//! 好友域外部服务线格式类型（请求/响应 DTO）
//!
//! 对齐 Go SDK `internal/relation/relation.go` 的 HTTP 契约。
//! 当前由 `core::friend::service` 消费；如需端口化，可收敛为 `FriendServerApi` trait。

use crate::error::Result;
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
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DeleteFriendReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFriendIdListResp {
    #[serde(rename = "friendIDs")]
    pub friend_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AddBlackReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RemoveBlackReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetBlackListResp {
    #[serde(rename = "blacksInfo", default)]
    pub blacks_info: Vec<BlackServerInfo>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BlackServerInfo {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    pub ex: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFriendApplyListReq {
    #[serde(rename = "userID")]
    pub from_user_id: String,
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
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
    #[serde(rename = "handleMsg")]
    pub handle_msg: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RefuseFriendApplicationReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
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
    #[serde(default)]
    pub delete: Vec<String>,
    #[serde(default)]
    pub insert: Vec<FriendServerInfo>,
    #[serde(default)]
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
    async fn get_black_list(&self) -> Result<GetBlackListResp>;
    async fn add_black(&self, req: &AddBlackReq) -> Result<()>;
    async fn remove_black(&self, req: &RemoveBlackReq) -> Result<()>;
    async fn get_friend_apply_list(&self, req: &GetFriendApplyListReq) -> Result<GetFriendApplyListResp>;
    async fn get_self_friend_apply_list(&self, req: &GetFriendApplyListReq) -> Result<GetFriendApplyListResp>;
    async fn get_self_unhandled_apply_count(&self, user_id: &str) -> Result<i32>;
    async fn accept_friend_application(&self, req: &AcceptFriendApplicationReq) -> Result<()>;
    async fn refuse_friend_application(&self, req: &RefuseFriendApplicationReq) -> Result<()>;
}