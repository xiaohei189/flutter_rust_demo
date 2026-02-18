//! 群组 HTTP API 客户端，路径与 openim-sdk-core pkg/api/api.go 完全一致

use crate::im::api::routes;
use crate::im::http::{extract_data, make_client, HttpClient};
use crate::im::model::conversation::RequestPagination;
use crate::im::model::group::{IncrementalJoinGroupResp, ServerGroupInfo, ServerGroupMemberFullInfo};
use crate::im::model::message::EmptyResp;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

/// POST /group/get_groups_info 请求体（与 protocol GetGroupsInfoReq 对齐）
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct GetGroupsInfoReq {
    group_i_ds: Vec<String>,
}

/// POST /group/get_groups_info 响应 data 部分
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GetGroupsInfoData {
    group_infos: Vec<ServerGroupInfo>,
}

/// 增量群成员单条请求（与 Go GetIncrementalGroupMemberReq 对齐）
#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GetIncrementalGroupMemberReq {
    pub group_id: String,
    #[serde(skip_serializing_if = "String::is_empty")]
    pub version_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<u64>,
}

/// 批量增量群成员响应：groupID -> IncrementalGroupMemberResp
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BatchIncrementalGroupMemberResp {
    #[serde(default)]
    pub resp_list: HashMap<String, crate::im::model::group::IncrementalGroupMemberResp>,
}

// ----- 与 Go api 对齐的请求/响应（camelCase） -----

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateGroupReq {
    pub member_user_i_ds: Vec<String>,
    pub group_info: serde_json::Value,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub admin_user_i_ds: Vec<String>,
    pub owner_user_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub send_message: Option<bool>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateGroupResp {
    pub group_info: Option<ServerGroupInfo>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SetGroupInfoExReq {
    pub group_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub notification: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub introduction: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub face_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub need_verification: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub look_member_info: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub apply_member_friend: Option<i32>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct JoinGroupReq {
    pub group_id: String,
    pub req_message: String,
    pub join_source: i32,
    pub inviter_user_id: String,
    #[serde(skip_serializing_if = "String::is_empty")]
    pub ex: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct QuitGroupReq {
    pub group_id: String,
    pub user_id: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GetJoinedGroupListReq {
    pub pagination: RequestPagination,
    pub from_user_id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetJoinedGroupListResp {
    pub total: u32,
    #[serde(default)]
    pub groups: Vec<ServerGroupInfo>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GetGroupMemberListReq {
    pub pagination: RequestPagination,
    pub group_id: String,
    pub filter: i32,
    #[serde(skip_serializing_if = "String::is_empty")]
    pub keyword: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetGroupMemberListResp {
    pub total: u32,
    #[serde(default)]
    pub members: Vec<ServerGroupMemberFullInfo>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GetGroupMembersInfoReq {
    pub group_id: String,
    pub user_i_ds: Vec<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetGroupMembersInfoResp {
    #[serde(default)]
    pub members: Vec<ServerGroupMemberFullInfo>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InviteUserToGroupReq {
    pub group_id: String,
    pub reason: String,
    pub invited_user_i_ds: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub send_message: Option<bool>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct KickGroupMemberReq {
    pub group_id: String,
    pub kicked_user_i_ds: Vec<String>,
    #[serde(skip_serializing_if = "String::is_empty")]
    pub reason: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub send_message: Option<bool>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TransferGroupReq {
    pub group_id: String,
    pub old_owner_user_id: String,
    pub new_owner_user_id: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GetRecvGroupApplicationListReq {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pagination: Option<RequestPagination>,
    pub from_user_id: String,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub group_i_ds: Vec<String>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub handle_results: Vec<i32>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GetSendGroupApplicationListReq {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pagination: Option<RequestPagination>,
    pub user_id: String,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub group_i_ds: Vec<String>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub handle_results: Vec<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupApplicationListResp {
    pub total: u32,
    #[serde(default)]
    pub group_requests: Vec<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GetGroupApplicationUnhandledCountReq {
    pub user_id: String,
    pub time: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetGroupApplicationUnhandledCountResp {
    pub count: i64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AcceptGroupApplicationReq {
    pub group_id: String,
    pub from_user_id: String,
    pub handled_msg: String,
    pub handle_result: i32,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DismissGroupReq {
    pub group_id: String,
    pub delete_member: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub send_message: Option<bool>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MuteGroupMemberReq {
    pub group_id: String,
    pub user_id: String,
    pub muted_seconds: u32,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CancelMuteGroupMemberReq {
    pub group_id: String,
    pub user_id: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MuteGroupReq {
    pub group_id: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CancelMuteGroupReq {
    pub group_id: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SetGroupMemberInfoItem {
    pub group_id: String,
    pub user_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub nickname: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub face_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub role_level: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SetGroupMemberInfoReq {
    pub members: Vec<SetGroupMemberInfoItem>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GetFullJoinedGroupIDsReq {
    pub user_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id_hash: Option<u64>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetFullJoinedGroupIDsResp {
    pub version: u64,
    pub version_id: String,
    pub equal: bool,
    #[serde(rename = "groupIDs", default)]
    pub group_ids: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GetFullGroupMemberUserIDsReq {
    pub group_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id_hash: Option<u64>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetFullGroupMemberUserIDsResp {
    pub version: u64,
    pub version_id: String,
    pub equal: bool,
    #[serde(rename = "userIDs", default)]
    pub user_ids: Vec<String>,
}

/// 群组相关 HTTP API 客户端
#[derive(Clone)]
pub struct GroupApi {
    client: HttpClient,
    api_base_url: String,
    user_id: String,
}

impl GroupApi {
    pub fn new(client: reqwest::Client, api_base_url: String, user_id: String, token: &str) -> Self {
        Self {
            client: make_client(client, token),
            api_base_url,
            user_id,
        }
    }

    /// 增量拉取当前用户加入的群列表（与 Go getIncrementalJoinGroup 对齐）
    pub async fn get_incremental_join_groups(&self, version: u64, version_id: &str) -> Result<IncrementalJoinGroupResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, routes::GROUP_GET_INCREMENTAL_JOIN_GROUPS);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "version": version,
                "versionID": version_id,
            }))
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("HTTP request failed: {}", e))?;
        extract_data(resp).await
    }

    /// 批量拉取各群的增量成员（与 Go getIncrementalGroupMemberBatch 对齐）
    pub async fn get_incremental_group_members_batch(
        &self,
        req_list: &[GetIncrementalGroupMemberReq],
    ) -> Result<HashMap<String, crate::im::model::group::IncrementalGroupMemberResp>> {
        if req_list.is_empty() {
            return Ok(HashMap::new());
        }
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, routes::GROUP_GET_INCREMENTAL_GROUP_MEMBERS_BATCH);
        let body = serde_json::json!({
            "userID": self.user_id,
            "reqList": req_list,
        });
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&body)
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("HTTP request failed: {}", e))?;
        let data: BatchIncrementalGroupMemberResp = extract_data(resp).await?;
        Ok(data.resp_list)
    }

    /// 拉取指定群信息（与 Go getGroupsInfoFromServer / api.GetGroupsInfo 对齐），POST /group/get_groups_info
    pub async fn get_groups_info(&self, group_ids: Vec<String>) -> Result<Vec<ServerGroupInfo>> {
        if group_ids.is_empty() {
            return Ok(Vec::new());
        }
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, routes::GROUP_GET_GROUPS_INFO);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&GetGroupsInfoReq {
                group_i_ds: group_ids,
            })
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("get_groups_info request failed: {}", e))?;
        let data: GetGroupsInfoData = extract_data(resp).await?;
        Ok(data.group_infos)
    }

    async fn post_json<T: Serialize, R: serde::de::DeserializeOwned>(&self, path: &str, payload: T) -> Result<R> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, path);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&payload)
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("group api request failed: {}", e))?;
        extract_data(resp).await
    }

    /// CreateGroup = "/group/create_group"
    pub async fn create_group(&self, req: CreateGroupReq) -> Result<CreateGroupResp> {
        self.post_json(routes::GROUP_CREATE_GROUP, req).await
    }

    /// SetGroupInfoEx = "/group/set_group_info_ex"
    pub async fn set_group_info_ex(&self, req: SetGroupInfoExReq) -> Result<EmptyResp> {
        self.post_json(routes::GROUP_SET_GROUP_INFO_EX, req).await
    }

    /// JoinGroup = "/group/join_group"
    pub async fn join_group(&self, req: JoinGroupReq) -> Result<EmptyResp> {
        self.post_json(routes::GROUP_JOIN_GROUP, req).await
    }

    /// QuitGroup = "/group/quit_group"
    pub async fn quit_group(&self, group_id: &str) -> Result<EmptyResp> {
        let req = QuitGroupReq { group_id: group_id.to_string(), user_id: self.user_id.clone() };
        self.post_json(routes::GROUP_QUIT_GROUP, req).await
    }

    /// GetJoinedGroupList = "/group/get_joined_group_list"
    pub async fn get_joined_group_list(&self, pagination: RequestPagination) -> Result<GetJoinedGroupListResp> {
        let req = GetJoinedGroupListReq { pagination, from_user_id: self.user_id.clone() };
        self.post_json(routes::GROUP_GET_JOINED_GROUP_LIST, req).await
    }

    /// GetGroupMemberList = "/group/get_group_member_list"
    pub async fn get_group_member_list(&self, req: GetGroupMemberListReq) -> Result<GetGroupMemberListResp> {
        self.post_json(routes::GROUP_GET_GROUP_MEMBER_LIST, req).await
    }

    /// GetGroupMembersInfo = "/group/get_group_members_info"
    pub async fn get_group_members_info(&self, group_id: &str, user_ids: Vec<String>) -> Result<GetGroupMembersInfoResp> {
        let req = GetGroupMembersInfoReq { group_id: group_id.to_string(), user_i_ds: user_ids };
        self.post_json(routes::GROUP_GET_GROUP_MEMBERS_INFO, req).await
    }

    /// InviteUserToGroup = "/group/invite_user_to_group"
    pub async fn invite_user_to_group(&self, req: InviteUserToGroupReq) -> Result<EmptyResp> {
        self.post_json(routes::GROUP_INVITE_USER_TO_GROUP, req).await
    }

    /// KickGroupMember = "/group/kick_group"
    pub async fn kick_group_member(&self, req: KickGroupMemberReq) -> Result<EmptyResp> {
        self.post_json(routes::GROUP_KICK_GROUP, req).await
    }

    /// TransferGroup = "/group/transfer_group"
    pub async fn transfer_group(&self, req: TransferGroupReq) -> Result<EmptyResp> {
        self.post_json(routes::GROUP_TRANSFER_GROUP, req).await
    }

    /// GetRecvGroupApplicationList = "/group/get_recv_group_applicationList"（from_user_id 一般为当前用户）
    pub async fn get_recv_group_application_list(&self, req: GetRecvGroupApplicationListReq) -> Result<GroupApplicationListResp> {
        self.post_json(routes::GROUP_GET_RECV_GROUP_APPLICATION_LIST, req).await
    }

    /// GetSendGroupApplicationList = "/group/get_user_req_group_applicationList"（user_id 一般为当前用户）
    pub async fn get_send_group_application_list(&self, req: GetSendGroupApplicationListReq) -> Result<GroupApplicationListResp> {
        self.post_json(routes::GROUP_GET_SEND_GROUP_APPLICATION_LIST, req).await
    }

    /// GetGroupApplicationUnhandledCount = "/group/get_group_application_unhandled_count"
    pub async fn get_group_application_unhandled_count(&self, time: i64) -> Result<GetGroupApplicationUnhandledCountResp> {
        let req = GetGroupApplicationUnhandledCountReq { user_id: self.user_id.clone(), time };
        self.post_json(routes::GROUP_GET_GROUP_APPLICATION_UNHANDLED_COUNT, req).await
    }

    /// AcceptGroupApplication = "/group/group_application_response"
    pub async fn accept_group_application(&self, req: AcceptGroupApplicationReq) -> Result<EmptyResp> {
        self.post_json(routes::GROUP_ACCEPT_GROUP_APPLICATION, req).await
    }

    /// DismissGroup = "/group/dismiss_group"
    pub async fn dismiss_group(&self, req: DismissGroupReq) -> Result<EmptyResp> {
        self.post_json(routes::GROUP_DISMISS_GROUP, req).await
    }

    /// MuteGroupMember = "/group/mute_group_member"
    pub async fn mute_group_member(&self, req: MuteGroupMemberReq) -> Result<EmptyResp> {
        self.post_json(routes::GROUP_MUTE_GROUP_MEMBER, req).await
    }

    /// CancelMuteGroupMember = "/group/cancel_mute_group_member"
    pub async fn cancel_mute_group_member(&self, req: CancelMuteGroupMemberReq) -> Result<EmptyResp> {
        self.post_json(routes::GROUP_CANCEL_MUTE_GROUP_MEMBER, req).await
    }

    /// MuteGroup = "/group/mute_group"
    pub async fn mute_group(&self, group_id: &str) -> Result<EmptyResp> {
        self.post_json(routes::GROUP_MUTE_GROUP, MuteGroupReq { group_id: group_id.to_string() }).await
    }

    /// CancelMuteGroup = "/group/cancel_mute_group"
    pub async fn cancel_mute_group(&self, group_id: &str) -> Result<EmptyResp> {
        self.post_json(routes::GROUP_CANCEL_MUTE_GROUP, CancelMuteGroupReq { group_id: group_id.to_string() }).await
    }

    /// SetGroupMemberInfo = "/group/set_group_member_info"
    pub async fn set_group_member_info(&self, req: SetGroupMemberInfoReq) -> Result<EmptyResp> {
        self.post_json(routes::GROUP_SET_GROUP_MEMBER_INFO, req).await
    }

    /// GetFullJoinedGroupIDs = "/group/get_full_join_group_ids"
    pub async fn get_full_joined_group_ids(&self, id_hash: Option<u64>) -> Result<GetFullJoinedGroupIDsResp> {
        let req = GetFullJoinedGroupIDsReq { user_id: self.user_id.clone(), id_hash };
        self.post_json(routes::GROUP_GET_FULL_JOIN_GROUP_IDS, req).await
    }

    /// GetFullGroupMemberUserIDs = "/group/get_full_group_member_user_ids"
    pub async fn get_full_group_member_user_ids(&self, group_id: &str, id_hash: Option<u64>) -> Result<GetFullGroupMemberUserIDsResp> {
        let req = GetFullGroupMemberUserIDsReq { group_id: group_id.to_string(), id_hash };
        self.post_json(routes::GROUP_GET_FULL_GROUP_MEMBER_USER_IDS, req).await
    }
}
