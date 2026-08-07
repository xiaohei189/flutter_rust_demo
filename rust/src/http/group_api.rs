//! HTTP 适配器 — impl GroupServerApi for HttpGroupApi
//!
//! trait 定义在 `domain::ports::group`

use crate::error::Result;
use crate::http::client::HttpApiClient;
use crate::http::group::{
    AcceptGroupApplicationReq, CreateGroupReq, CreateGroupResp, DismissGroupReq, GetGroupApplicationListReq, GetGroupApplicationListResp, GetGroupMemberListReq, GetGroupMemberListResp,
    GetGroupMembersInfoReq, GetGroupMembersInfoResp, GetGroupsInfoReq, GetGroupsInfoResp, GetIncrementalJoinGroupReq, GetIncrementalJoinGroupResp, GetJoinedGroupListReq, GetJoinedGroupListResp,
    GetUserReqApplicationListReq, GroupServerApi, InviteUserToGroupReq, JoinGroupReq, KickGroupMemberReq, QuitGroupReq, RefuseGroupApplicationReq, SetGroupInfoReq, SetGroupMemberInfoReq,
};
use crate::http::routes::{
    ACCEPT_GROUP_APPLICATION, CANCEL_MUTE_GROUP, CANCEL_MUTE_GROUP_MEMBER, CREATE_GROUP, DISMISS_GROUP, GET_GROUPS_INFO, GET_GROUP_APPLICATION_LIST, GET_GROUP_APPLICATION_UNHANDLED_COUNT,
    GET_GROUP_MEMBERS_INFO, GET_GROUP_MEMBER_LIST, GET_INCREMENTAL_JOIN_GROUP, GET_JOINED_GROUP_LIST, GET_RECV_GROUP_APPLICATION_LIST, GET_SEND_GROUP_APPLICATION_LIST, INVITE_USER_TO_GROUP,
    JOIN_GROUP, KICK_GROUP_MEMBER, MUTE_GROUP, MUTE_GROUP_MEMBER, QUIT_GROUP, REFUSE_GROUP_APPLICATION, SET_GROUP_INFO, SET_GROUP_MEMBER_INFO, TRANSFER_GROUP_OWNER,
};
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::sync::Arc;

/// 基于 HTTP 的生产实现
pub struct HttpGroupApi {
    http_client: Arc<HttpApiClient>,
}

impl HttpGroupApi {
    pub fn new(http_client: Arc<HttpApiClient>) -> Self {
        Self { http_client }
    }
}

#[async_trait]
impl GroupServerApi for HttpGroupApi {
    async fn get_joined_group_list(&self, req: &GetJoinedGroupListReq) -> Result<GetJoinedGroupListResp> {
        Ok(self.http_client.post(GET_JOINED_GROUP_LIST, req).await?)
    }

    async fn get_incremental_join_group(&self, req: &GetIncrementalJoinGroupReq) -> Result<GetIncrementalJoinGroupResp> {
        Ok(self.http_client.post(GET_INCREMENTAL_JOIN_GROUP, req).await?)
    }

    async fn get_groups_info(&self, req: &GetGroupsInfoReq) -> Result<GetGroupsInfoResp> {
        Ok(self.http_client.post(GET_GROUPS_INFO, req).await?)
    }

    async fn create_group(&self, req: &CreateGroupReq) -> Result<CreateGroupResp> {
        Ok(self.http_client.post(CREATE_GROUP, req).await?)
    }

    async fn join_group(&self, req: &JoinGroupReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(JOIN_GROUP, req).await?;
        Ok(())
    }

    async fn quit_group(&self, req: &QuitGroupReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(QUIT_GROUP, req).await?;
        Ok(())
    }

    async fn dismiss_group(&self, req: &DismissGroupReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(DISMISS_GROUP, req).await?;
        Ok(())
    }

    async fn set_group_info(&self, req: &SetGroupInfoReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(SET_GROUP_INFO, req).await?;
        Ok(())
    }

    async fn get_group_member_list(&self, req: &GetGroupMemberListReq) -> Result<GetGroupMemberListResp> {
        Ok(self.http_client.post(GET_GROUP_MEMBER_LIST, req).await?)
    }

    async fn get_group_members_info(&self, req: &GetGroupMembersInfoReq) -> Result<GetGroupMembersInfoResp> {
        Ok(self.http_client.post(GET_GROUP_MEMBERS_INFO, req).await?)
    }

    async fn kick_group_member(&self, req: &KickGroupMemberReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(KICK_GROUP_MEMBER, req).await?;
        Ok(())
    }

    async fn invite_user_to_group(&self, req: &InviteUserToGroupReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(INVITE_USER_TO_GROUP, req).await?;
        Ok(())
    }

    async fn set_group_member_info(&self, req: &SetGroupMemberInfoReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(SET_GROUP_MEMBER_INFO, req).await?;
        Ok(())
    }

    async fn get_group_application_list(&self, req: &GetGroupApplicationListReq) -> Result<GetGroupApplicationListResp> {
        Ok(self.http_client.post(GET_GROUP_APPLICATION_LIST, req).await?)
    }

    async fn get_recv_group_application_list(&self, req: &GetGroupApplicationListReq) -> Result<GetGroupApplicationListResp> {
        Ok(self.http_client.post(GET_RECV_GROUP_APPLICATION_LIST, req).await?)
    }

    async fn get_send_group_application_list(&self, req: &GetUserReqApplicationListReq) -> Result<GetGroupApplicationListResp> {
        Ok(self.http_client.post(GET_SEND_GROUP_APPLICATION_LIST, req).await?)
    }

    async fn get_group_application_unhandled_count(&self, user_id: &str) -> Result<i32> {
        #[derive(Serialize)]
        struct UnhandledCountReq {
            #[serde(rename = "userID")]
            user_id: String,
        }
        #[derive(Deserialize, Default)]
        struct UnhandledCountResp {
            count: i32,
        }
        let req = UnhandledCountReq { user_id: user_id.to_string() };
        let resp: UnhandledCountResp = self.http_client.post(GET_GROUP_APPLICATION_UNHANDLED_COUNT, &req).await?;
        Ok(resp.count)
    }

    async fn accept_group_application(&self, req: &AcceptGroupApplicationReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(ACCEPT_GROUP_APPLICATION, req).await?;
        Ok(())
    }

    async fn refuse_group_application(&self, req: &RefuseGroupApplicationReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(REFUSE_GROUP_APPLICATION, req).await?;
        Ok(())
    }

    async fn transfer_group_owner(&self, group_id: &str, new_owner_user_id: &str) -> Result<()> {
        let req = serde_json::json!({
            "groupID": group_id,
            "newOwnerUserID": new_owner_user_id,
        });
        let _: serde_json::Value = self.http_client.post(TRANSFER_GROUP_OWNER, &req).await?;
        Ok(())
    }

    async fn mute_group(&self, group_id: &str, is_mute: bool) -> Result<()> {
        let req = serde_json::json!({
            "groupID": group_id,
            "isMute": is_mute,
        });
        let route = if is_mute { MUTE_GROUP } else { CANCEL_MUTE_GROUP };
        let _: serde_json::Value = self.http_client.post(route, &req).await?;
        Ok(())
    }

    async fn mute_group_member(&self, group_id: &str, user_id: &str, muted_seconds: i64) -> Result<()> {
        let req = serde_json::json!({
            "groupID": group_id,
            "userID": user_id,
            "mutedSeconds": muted_seconds,
        });
        let route = if muted_seconds > 0 { MUTE_GROUP_MEMBER } else { CANCEL_MUTE_GROUP_MEMBER };
        let _: serde_json::Value = self.http_client.post(route, &req).await?;
        Ok(())
    }
}
