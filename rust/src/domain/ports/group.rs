//! 群组域外部服务线格式类型（请求/响应 DTO）
//!
//! 对齐 Go SDK `internal/group/group.go` 的 HTTP 契约。
//! 当前由 `core::group::service` 消费；如需端口化，可收敛为 `GroupServerApi` trait。

use serde::{Deserialize, Serialize};

use crate::domain::ports::types::Pagination;
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetJoinedGroupListReq {
    #[serde(rename = "fromUserID")]
    pub user_id: String,
    #[serde(rename = "pagination")]
    pub pagination: Pagination,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct ServerGroupInfo {
    #[serde(rename = "groupID", default)]
    pub group_id: String,
    #[serde(rename = "groupName", default)]
    pub group_name: String,
    #[serde(rename = "notification", default)]
    pub notification: String,
    #[serde(rename = "introduction", default)]
    pub introduction: String,
    #[serde(rename = "faceURL", default)]
    pub face_url: String,
    #[serde(rename = "ownerUserID", default)]
    pub owner_user_id: String,
    #[serde(rename = "createTime", default)]
    pub create_time: i64,
    #[serde(rename = "memberCount", default)]
    pub member_count: u32,
    #[serde(default)]
    pub status: i32,
    #[serde(rename = "creatorUserID", default)]
    pub creator_user_id: String,
    #[serde(rename = "groupType", default)]
    pub group_type: i32,
    #[serde(default)]
    pub ex: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetJoinedGroupListResp {
    #[serde(default)]
    pub groups: Option<Vec<ServerGroupInfo>>,
    #[serde(rename = "total", default)]
    pub total: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetGroupsInfoReq {
    #[serde(rename = "groupIDs")]
    pub group_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetGroupsInfoResp {
    #[serde(rename = "groupInfos", default)]
    pub groups_info: Vec<ServerGroupInfo>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CreateGroupReq {
    #[serde(rename = "groupInfo")]
    pub group_info: CreateGroupInfo,
    #[serde(rename = "memberUserIDs")]
    pub member_user_ids: Vec<String>,
    #[serde(rename = "adminUserIDs")]
    pub admin_user_ids: Vec<String>,
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CreateGroupInfo {
    #[serde(rename = "groupName")]
    pub group_name: String,
    #[serde(rename = "faceURL")]
    pub face_url: Option<String>,
    pub introduction: Option<String>,
    pub notification: Option<String>,
    #[serde(rename = "groupType")]
    pub group_type: i32,
    pub ex: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct CreateGroupResp {
    #[serde(rename = "groupInfo", default)]
    pub group: ServerGroupInfo,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct JoinGroupReq {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "reqMsg")]
    pub req_msg: Option<String>,
    #[serde(rename = "joinSource")]
    pub join_source: i32,
    pub ex: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct QuitGroupReq {
    #[serde(rename = "groupID")]
    pub group_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DismissGroupReq {
    #[serde(rename = "groupID")]
    pub group_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SetGroupInfoReq {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "groupName")]
    pub group_name: Option<String>,
    #[serde(rename = "faceURL")]
    pub face_url: Option<String>,
    pub introduction: Option<String>,
    pub notification: Option<String>,
    pub ex: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetGroupMemberListReq {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "filter")]
    pub filter: i32,
    #[serde(rename = "pagination")]
    pub pagination: Pagination,
    #[serde(rename = "keyword", default, skip_serializing_if = "String::is_empty")]
    pub keyword: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ServerGroupMember {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    #[serde(rename = "roleLevel")]
    pub role_level: i32,
    #[serde(rename = "joinTime")]
    pub join_time: i64,
    #[serde(rename = "joinSource")]
    pub join_source: i32,
    #[serde(rename = "operatorUserID")]
    pub operator_user_id: String,
    pub ex: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetGroupMemberListResp {
    #[serde(default)]
    pub members: Option<Vec<ServerGroupMember>>,
    #[serde(rename = "total", default)]
    pub total: u32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetGroupMembersInfoReq {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "userIDs")]
    pub user_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetGroupMembersInfoResp {
    #[serde(rename = "membersInfo", default)]
    pub members_info: Vec<ServerGroupMember>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct KickGroupMemberReq {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "kickedUserIDs")]
    pub user_id_list: Vec<String>,
    #[serde(rename = "reason", default, skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct InviteUserToGroupReq {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "invitedUserIDs")]
    pub user_id_list: Vec<String>,
    #[serde(rename = "reason", default, skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SetGroupMemberInfoReq {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: Option<String>,
    #[serde(rename = "faceURL")]
    pub face_url: Option<String>,
    #[serde(rename = "roleLevel")]
    pub role_level: Option<i32>,
    pub ex: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetGroupApplicationListReq {
    #[serde(rename = "fromUserID")]
    pub from_user_id: String,
    #[serde(rename = "pagination")]
    pub pagination: Pagination,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetGroupApplicationListResp {
    #[serde(rename = "groupRequests", default)]
    pub group_requests: Option<Vec<GroupApplyInfo>>,
    #[serde(rename = "total", default)]
    pub total: u32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GroupApplyInfo {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    #[serde(default)]
    pub reason: String,
    #[serde(rename = "handleResult")]
    pub handle_result: i32,
    pub ex: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AcceptGroupApplicationReq {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "fromUserID")]
    pub from_user_id: String,
    #[serde(rename = "handleMsg")]
    pub handle_msg: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RefuseGroupApplicationReq {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "fromUserID")]
    pub from_user_id: String,
    #[serde(rename = "handleMsg")]
    pub handle_msg: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetIncrementalJoinGroupReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub version: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetIncrementalJoinGroupResp {
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub full: bool,
    #[serde(default)]
    pub delete: Vec<String>,
    #[serde(default)]
    pub insert: Vec<ServerGroupInfo>,
    #[serde(default)]
    pub update: Vec<ServerGroupInfo>,
    #[serde(rename = "sortVersion", default)]
    pub sort_version: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFullJoinGroupIDsReq {
    #[serde(rename = "idHash")]
    pub id_hash: u64,
    #[serde(rename = "userID")]
    pub user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetFullJoinGroupIDsResp {
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub equal: bool,
    #[serde(rename = "groupIDs", default)]
    pub group_ids: Vec<String>,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct SetGroupMemberFields {
    pub group_id: String,
    pub user_id: String,
    pub nickname: Option<String>,
    pub face_url: Option<String>,
    pub role_level: Option<i32>,
    pub ex: Option<String>,
}
