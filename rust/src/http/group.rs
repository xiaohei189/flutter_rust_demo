//! 群组域外部服务线格式类型（请求/响应 DTO）
//!
//! 对齐 Go SDK `internal/group/group.go` 的 HTTP 契约。
//! 当前由 `core::group::service` 消费；如需端口化，可收敛为 `GroupServerApi` trait。

use crate::error::Result;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use crate::http::types::Pagination;
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

/// 群组域服务端 API（入向契约：SDK → OpenIM 服务端）
#[async_trait]
pub trait GroupServerApi: Send + Sync {
    async fn get_joined_group_list(&self, req: &GetJoinedGroupListReq) -> Result<GetJoinedGroupListResp>;
    async fn get_incremental_join_group(&self, req: &GetIncrementalJoinGroupReq) -> Result<GetIncrementalJoinGroupResp>;
    async fn get_groups_info(&self, req: &GetGroupsInfoReq) -> Result<GetGroupsInfoResp>;
    async fn create_group(&self, req: &CreateGroupReq) -> Result<CreateGroupResp>;
    async fn join_group(&self, req: &JoinGroupReq) -> Result<()>;
    async fn quit_group(&self, req: &QuitGroupReq) -> Result<()>;
    async fn dismiss_group(&self, req: &DismissGroupReq) -> Result<()>;
    async fn set_group_info(&self, req: &SetGroupInfoReq) -> Result<()>;
    async fn get_group_member_list(&self, req: &GetGroupMemberListReq) -> Result<GetGroupMemberListResp>;
    async fn get_group_members_info(&self, req: &GetGroupMembersInfoReq) -> Result<GetGroupMembersInfoResp>;
    async fn kick_group_member(&self, req: &KickGroupMemberReq) -> Result<()>;
    async fn invite_user_to_group(&self, req: &InviteUserToGroupReq) -> Result<()>;
    async fn set_group_member_info(&self, req: &SetGroupMemberInfoReq) -> Result<()>;
    async fn get_group_application_list(&self, req: &GetGroupApplicationListReq) -> Result<GetGroupApplicationListResp>;
    async fn get_recv_group_application_list(&self, req: &GetGroupApplicationListReq) -> Result<GetGroupApplicationListResp>;
    async fn get_send_group_application_list(&self, req: &GetGroupApplicationListReq) -> Result<GetGroupApplicationListResp>;
    async fn get_group_application_unhandled_count(&self, user_id: &str) -> Result<i32>;
    async fn accept_group_application(&self, req: &AcceptGroupApplicationReq) -> Result<()>;
    async fn refuse_group_application(&self, req: &RefuseGroupApplicationReq) -> Result<()>;
    async fn transfer_group_owner(&self, group_id: &str, new_owner_user_id: &str) -> Result<()>;
    async fn mute_group(&self, group_id: &str, is_mute: bool) -> Result<()>;
    async fn mute_group_member(&self, group_id: &str, user_id: &str, muted_seconds: i64) -> Result<()>;
}
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_join_group_req_serialization() {
        let req = JoinGroupReq {
            group_id: "group_123".to_string(),
            req_msg: Some("Please add me".to_string()),
            join_source: 1,
            ex: None,
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("groupID"));
        assert!(json.contains("Please add me"));
    }

    #[test]
    fn test_accept_group_application_req_serialization() {
        let req = AcceptGroupApplicationReq {
            group_id: "group_123".to_string(),
            from_user_id: "user_a".to_string(),
            handle_msg: Some("Welcome".to_string()),
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("groupID"));
        assert!(json.contains("fromUserID"));
    }

    #[test]
    fn test_group_apply_info_deserialization() {
        let json = r#"{"userID":"user_1","nickname":"Test","faceURL":"","gender":1,"createTime":1000,"addSource":1,"ex":"","reqMsg":"Join","handleResult":0,"handleMsg":null,"groupID":"group_123","groupName":"Test Group"}"#;
        let info: GroupApplyInfo = serde_json::from_str(json).unwrap();
        assert_eq!(info.user_id, "user_1");
        assert_eq!(info.group_id, "group_123");
    }

    #[test]
    fn test_set_group_info_req_serialization() {
        let req = SetGroupInfoReq {
            group_id: "group_123".to_string(),
            group_name: Some("Updated Group".to_string()),
            face_url: Some("http://example.com/group.jpg".to_string()),
            introduction: None,
            notification: None,
            ex: None,
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("groupName"));
        assert!(json.contains("Updated Group"));
    }

    #[test]
    fn test_set_group_member_info_req_serialization() {
        let req = SetGroupMemberInfoReq {
            group_id: "group_123".to_string(),
            user_id: "user_b".to_string(),
            nickname: Some("NewName".to_string()),
            face_url: None,
            role_level: None,
            ex: None,
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("groupID"));
        assert!(json.contains("NewName"));
    }
}
