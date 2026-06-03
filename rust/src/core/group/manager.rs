use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::bus::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::group::{GroupInfo, GroupMember, SetGroupInfoFields};
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{
    CREATE_GROUP, GET_GROUPS_INFO, GET_GROUP_INFO, SET_GROUP_INFO, JOIN_GROUP, QUIT_GROUP,
    DISMISS_GROUP, GET_GROUP_MEMBER_LIST, GET_GROUP_MEMBERS_INFO, SET_GROUP_MEMBER_INFO,
    KICK_GROUP_MEMBER, GET_JOINED_GROUP_LIST, INVITE_USER_TO_GROUP,
    GET_GROUP_APPLICATION_LIST, GET_RECV_GROUP_APPLICATION_LIST, GET_SEND_GROUP_APPLICATION_LIST,
    GET_GROUP_APPLICATION_UNHANDLED_COUNT,
    ACCEPT_GROUP_APPLICATION, REFUSE_GROUP_APPLICATION,
    TRANSFER_GROUP_OWNER, MUTE_GROUP, CANCEL_MUTE_GROUP, MUTE_GROUP_MEMBER, CANCEL_MUTE_GROUP_MEMBER,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::info;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetJoinedGroupListReq {
    #[serde(rename = "fromUserID")]
    pub user_id: String,
    #[serde(rename = "pagination")]
    pub pagination: Pagination,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Pagination {
    #[serde(rename = "pageNumber")]
    pub page_number: i32,
    #[serde(rename = "showNumber")]
    pub show_number: i32,
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

pub struct GroupManager {
    http_client: Arc<HttpApiClient>,
    event_bus: Arc<EventBus>,
    user_id: Arc<RwLock<String>>,
    groups: Arc<RwLock<Vec<GroupInfo>>>,
    members: Arc<RwLock<Vec<GroupMember>>>,
}

impl GroupManager {
    pub fn new(http_client: Arc<HttpApiClient>, event_bus: Arc<EventBus>, user_id: String) -> Self {
        Self {
            http_client,
            event_bus,
            user_id: Arc::new(RwLock::new(user_id)),
            groups: Arc::new(RwLock::new(Vec::new())),
            members: Arc::new(RwLock::new(Vec::new())),
        }
    }

    pub async fn set_user_id(&self, user_id: String) {
        *self.user_id.write().await = user_id.clone();
        info!("GroupManager user_id 已更新为: {}", user_id);
    }

    pub async fn get_joined_group_list(&self) -> Vec<GroupInfo> {
        self.groups.read().await.clone()
    }

    pub async fn sync_groups(&self) -> Result<()> {
        let user_id = self.user_id.read().await.clone();
        let req = GetJoinedGroupListReq {
            user_id,
            pagination: Pagination {
                page_number: 1,
                show_number: 1000,
            },
        };

        let resp: GetJoinedGroupListResp = self.http_client.post(GET_JOINED_GROUP_LIST, &req).await?;

        let groups: Vec<GroupInfo> = resp
            .groups
            .unwrap_or_default()
            .into_iter()
            .map(|s| server_to_group_info(s))
            .collect();

        *self.groups.write().await = groups.clone();

        info!("群组列表已同步, count={}", groups.len());
        Ok(())
    }

    pub async fn get_groups_info(&self, group_ids: Vec<String>) -> Result<Vec<GroupInfo>> {
        let req = GetGroupsInfoReq {
            group_ids: group_ids.clone(),
        };

        let resp: GetGroupsInfoResp = self.http_client.post(GET_GROUPS_INFO, &req).await?;

        let groups: Vec<GroupInfo> = resp
            .groups_info
            .into_iter()
            .map(|s| server_to_group_info(s))
            .collect();

        Ok(groups)
    }

    pub async fn create_group(
        &self,
        group_name: String,
        face_url: Option<String>,
        introduction: Option<String>,
        notification: Option<String>,
        member_user_ids: Vec<String>,
        admin_user_ids: Vec<String>,
        owner_user_id: String,
    ) -> Result<GroupInfo> {
        let req = CreateGroupReq {
            group_info: CreateGroupInfo {
                group_name,
                face_url,
                introduction,
                notification,
                group_type: 2,  // 2 = 普通群（与 Go SDK 一致）
                ex: None,
            },
            member_user_ids,
            admin_user_ids,
            owner_user_id,
        };

        let resp: CreateGroupResp = self.http_client.post(CREATE_GROUP, &req).await?;

        let group = server_to_group_info(resp.group);
        self.groups.write().await.push(group.clone());

        self.event_bus.publish(SdkEvent::GroupCreated {
            group_id: group.group_id.clone(),
        });

        info!("群组已创建: {}", group.group_id);
        Ok(group)
    }

    pub async fn join_group(&self, group_id: String, req_msg: Option<String>) -> Result<()> {
        let req = JoinGroupReq {
            group_id: group_id.clone(),
            req_msg,
            join_source: 1,
            ex: None,
        };

        let _resp: serde_json::Value = self.http_client.post(JOIN_GROUP, &req).await?;

        info!("已申请加入群组: {}", group_id);
        Ok(())
    }

    pub async fn quit_group(&self, group_id: String) -> Result<()> {
        let req = QuitGroupReq {
            group_id: group_id.clone(),
        };

        let _resp: serde_json::Value = self.http_client.post(QUIT_GROUP, &req).await?;

        self.groups.write().await.retain(|g| g.group_id != group_id);
        self.members.write().await.retain(|m| m.group_id != group_id);

        info!("已退出群组: {}", group_id);
        Ok(())
    }

    pub async fn dismiss_group(&self, group_id: String) -> Result<()> {
        let req = DismissGroupReq {
            group_id: group_id.clone(),
        };

        let _resp: serde_json::Value = self.http_client.post(DISMISS_GROUP, &req).await?;

        self.groups.write().await.retain(|g| g.group_id != group_id);
        self.members.write().await.retain(|m| m.group_id != group_id);

        self.event_bus.publish(SdkEvent::GroupDismissed {
            group_id: group_id.clone(),
        });

        info!("群组已解散: {}", group_id);
        Ok(())
    }

    pub async fn set_group_info(&self, updates: SetGroupInfoFields) -> Result<()> {
        let req = SetGroupInfoReq {
            group_id: updates.group_id.clone(),
            group_name: updates.group_name,
            face_url: updates.face_url,
            introduction: updates.introduction,
            notification: updates.notification,
            ex: updates.ex,
        };

        let _resp: serde_json::Value = self.http_client.post(SET_GROUP_INFO, &req).await?;

        if let Some(group) = self
            .groups
            .write()
            .await
            .iter_mut()
            .find(|g| g.group_id == updates.group_id)
        {
            if let Some(name) = &req.group_name {
                group.group_name = name.clone();
            }
            if let Some(url) = &req.face_url {
                group.face_url = url.clone();
            }
        }

        self.event_bus.publish(SdkEvent::GroupInfoChanged {
            group_id: updates.group_id.clone(),
        });

        info!("群组信息已更新: {}", updates.group_id);
        Ok(())
    }

    pub async fn is_in_group(&self, group_id: &str) -> bool {
        self.groups.read().await.iter().any(|g| g.group_id == group_id)
    }

    pub async fn group_count(&self) -> usize {
        self.groups.read().await.len()
    }

    pub async fn get_group_member_list(
        &self,
        group_id: String,
        filter: i32,
        offset: u32,
        count: u32,
    ) -> Result<Vec<GroupMember>> {
        let req = GetGroupMemberListReq {
            group_id: group_id.clone(),
            filter,
            pagination: Pagination {
                page_number: if offset == 0 { 1 } else { offset as i32 },
                show_number: count as i32,
            },
            keyword: String::new(),
        };

        let resp: GetGroupMemberListResp = self.http_client.post(GET_GROUP_MEMBER_LIST, &req).await?;

        let members: Vec<GroupMember> = resp
            .members
            .unwrap_or_default()
            .into_iter()
            .map(|s| server_to_group_member(s))
            .collect();

        Ok(members)
    }

    pub async fn get_group_members_info(
        &self,
        group_id: String,
        user_ids: Vec<String>,
    ) -> Result<Vec<GroupMember>> {
        let req = GetGroupMembersInfoReq {
            group_id: group_id.clone(),
            user_ids,
        };

        let resp: GetGroupMembersInfoResp = self.http_client.post(GET_GROUP_MEMBERS_INFO, &req).await?;

        let members: Vec<GroupMember> = resp
            .members_info
            .into_iter()
            .map(|s| server_to_group_member(s))
            .collect();

        Ok(members)
    }

    pub async fn kick_group_member(
        &self,
        group_id: String,
        user_ids: Vec<String>,
        reason: Option<String>,
    ) -> Result<()> {
        let req = KickGroupMemberReq {
            group_id: group_id.clone(),
            user_id_list: user_ids,
            reason,
        };

        let _resp: serde_json::Value = self.http_client.post(KICK_GROUP_MEMBER, &req).await?;

        self.members
            .write()
            .await
            .retain(|m| m.group_id != group_id || !req.user_id_list.contains(&m.user_id));

        info!("群成员已踢出: group={}", group_id);
        Ok(())
    }

    pub async fn invite_user_to_group(
        &self,
        group_id: String,
        user_ids: Vec<String>,
        reason: Option<String>,
    ) -> Result<()> {
        let req = InviteUserToGroupReq {
            group_id: group_id.clone(),
            user_id_list: user_ids,
            reason,
        };

        let _resp: serde_json::Value = self.http_client.post(INVITE_USER_TO_GROUP, &req).await?;

        info!("已邀请用户加入群组: group={}", group_id);
        Ok(())
    }

    pub async fn set_group_member_info(&self, updates: SetGroupMemberFields) -> Result<()> {
        let req = SetGroupMemberInfoReq {
            group_id: updates.group_id.clone(),
            user_id: updates.user_id.clone(),
            nickname: updates.nickname,
            face_url: updates.face_url,
            role_level: updates.role_level,
            ex: updates.ex,
        };

        let _resp: serde_json::Value = self.http_client.post(SET_GROUP_MEMBER_INFO, &req).await?;

        info!("群成员信息已更新: group={}, user={}", updates.group_id, updates.user_id);
        Ok(())
    }

    pub async fn get_group_application_list(&self) -> Result<GetGroupApplicationListResp> {
        let user_id = self.user_id.read().await.clone();
        let req = GetGroupApplicationListReq {
            from_user_id: user_id,
            pagination: Pagination {
                page_number: 1,
                show_number: 1000,
            },
        };
        let resp: GetGroupApplicationListResp = self.http_client.post(GET_GROUP_APPLICATION_LIST, &req).await?;
        Ok(resp)
    }

    /// 获取管理员收到的群组申请列表（对齐 Go SDK GetGroupApplicationListAsRecipient）
    pub async fn get_group_application_list_as_recipient(&self) -> Result<GetGroupApplicationListResp> {
        let user_id = self.user_id.read().await.clone();
        let req = GetGroupApplicationListReq {
            from_user_id: user_id,
            pagination: Pagination {
                page_number: 1,
                show_number: 1000,
            },
        };
        let resp: GetGroupApplicationListResp = self.http_client.post(GET_RECV_GROUP_APPLICATION_LIST, &req).await?;
        Ok(resp)
    }

    /// 获取自己发出的群组申请列表（对齐 Go SDK GetGroupApplicationListAsApplicant）
    pub async fn get_group_application_list_as_applicant(&self) -> Result<GetGroupApplicationListResp> {
        let user_id = self.user_id.read().await.clone();
        let req = GetGroupApplicationListReq {
            from_user_id: user_id,
            pagination: Pagination {
                page_number: 1,
                show_number: 1000,
            },
        };
        let resp: GetGroupApplicationListResp = self.http_client.post(GET_SEND_GROUP_APPLICATION_LIST, &req).await?;
        Ok(resp)
    }

    /// 获取未处理的群组申请数量（对齐 Go SDK GetGroupApplicationUnhandledCount）
    pub async fn get_group_application_unhandled_count(&self) -> Result<i32> {
        #[derive(Serialize)]
        struct UnhandledCountReq {
            user_id: String,
        }
        let user_id = self.user_id.read().await.clone();
        let req = UnhandledCountReq { user_id };
        #[derive(Deserialize, Default)]
        struct UnhandledCountResp {
            count: i32,
        }
        let resp: UnhandledCountResp = self.http_client.post(GET_GROUP_APPLICATION_UNHANDLED_COUNT, &req).await?;
        Ok(resp.count)
    }

    pub async fn accept_group_application(&self, group_id: String, user_id: String, handle_msg: Option<String>) -> Result<()> {
        let req = AcceptGroupApplicationReq {
            group_id: group_id.clone(),
            from_user_id: user_id.clone(),
            handle_msg,
        };
        let _resp: serde_json::Value = self.http_client.post(ACCEPT_GROUP_APPLICATION, &req).await?;

        // 对齐 Go SDK: 接受群组申请后同步群组列表
        if let Err(e) = self.sync_groups().await {
            tracing::warn!("接受群组申请后同步群组列表失败: {}", e);
        }

        info!("群组申请已接受: group={}, user={}", group_id, user_id);
        Ok(())
    }

    pub async fn refuse_group_application(&self, group_id: String, user_id: String, handle_msg: Option<String>) -> Result<()> {
        let req = RefuseGroupApplicationReq {
            group_id: group_id.clone(),
            from_user_id: user_id.clone(),
            handle_msg,
        };
        let _resp: serde_json::Value = self.http_client.post(REFUSE_GROUP_APPLICATION, &req).await?;
        info!("群组申请已拒绝: group={}, user={}", group_id, user_id);
        Ok(())
    }

    /// 转让群主
    pub async fn transfer_group_owner(&self, group_id: String, new_owner_user_id: String) -> Result<()> {
        let req = serde_json::json!({
            "groupID": group_id,
            "newOwnerUserID": new_owner_user_id,
        });
        let _resp: serde_json::Value = self.http_client.post(TRANSFER_GROUP_OWNER, &req).await?;
        if let Err(e) = self.sync_groups().await {
            tracing::warn!("转让群主后同步群组列表失败: {}", e);
        }
        info!("群主已转让: group={}, new_owner={}", group_id, new_owner_user_id);
        Ok(())
    }

    /// 全局禁言/解除禁言群组
    pub async fn mute_group(&self, group_id: String, is_mute: bool) -> Result<()> {
        let req = serde_json::json!({
            "groupID": group_id,
            "isMute": is_mute,
        });
        let route = if is_mute { MUTE_GROUP } else { CANCEL_MUTE_GROUP };
        let _resp: serde_json::Value = self.http_client.post(route, &req).await?;
        info!("群组禁言状态已更新: group={}, is_mute={}", group_id, is_mute);
        Ok(())
    }

    /// 禁言/解除禁言群成员
    pub async fn mute_group_member(&self, group_id: String, user_id: String, muted_seconds: i64) -> Result<()> {
        let req = serde_json::json!({
            "groupID": group_id,
            "userID": user_id,
            "mutedSeconds": muted_seconds,
        });
        let route = if muted_seconds > 0 { MUTE_GROUP_MEMBER } else { CANCEL_MUTE_GROUP_MEMBER };
        let _resp: serde_json::Value = self.http_client.post(route, &req).await?;
        info!("群成员禁言状态已更新: group={}, user={}, seconds={}", group_id, user_id, muted_seconds);
        Ok(())
    }

    pub async fn clear(&self) {
        self.groups.write().await.clear();
        self.members.write().await.clear();
        info!("群组数据已清空");
    }
}

fn server_to_group_info(s: ServerGroupInfo) -> GroupInfo {
    GroupInfo {
        group_id: s.group_id,
        group_name: s.group_name,
        face_url: s.face_url,
        introduction: s.introduction,
        notification: s.notification,
        owner_user_id: s.owner_user_id,
        create_time: s.create_time,
        member_count: s.member_count,
        status: s.status,
    }
}

fn server_to_group_member(s: ServerGroupMember) -> GroupMember {
    GroupMember {
        group_id: s.group_id,
        user_id: s.user_id,
        nickname: s.nickname,
        face_url: s.face_url,
        role_level: s.role_level,
        join_time: s.join_time,
        join_source: s.join_source.to_string(),
    }
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_server_to_group_info_conversion() {
        let server = ServerGroupInfo {
            group_id: "group_123".to_string(),
            group_name: "Test Group".to_string(),
            face_url: "https://example.com/group.jpg".to_string(),
            notification: "Welcome!".to_string(),
            introduction: "A test group".to_string(),
            owner_user_id: "owner_1".to_string(),
            create_time: 1234567890,
            member_count: 10,
            status: 0,
            creator_user_id: "owner_1".to_string(),
            group_type: 0,
            ex: String::new(),
        };

        let domain = server_to_group_info(server);
        assert_eq!(domain.group_id, "group_123");
        assert_eq!(domain.group_name, "Test Group");
        assert_eq!(domain.member_count, 10);
    }

    #[test]
    fn test_server_to_group_member_conversion() {
        let server = ServerGroupMember {
            group_id: "group_123".to_string(),
            user_id: "user_456".to_string(),
            nickname: "Test Member".to_string(),
            face_url: "https://example.com/member.jpg".to_string(),
            role_level: 1,
            join_time: 1234567890,
            join_source: 1,
            operator_user_id: "owner_1".to_string(),
            ex: String::new(),
        };

        let domain = server_to_group_member(server);
        assert_eq!(domain.group_id, "group_123");
        assert_eq!(domain.user_id, "user_456");
        assert_eq!(domain.nickname, "Test Member");
    }

    #[test]
    fn test_get_joined_group_list_req_serialization() {
        let req = GetJoinedGroupListReq {
            user_id: "test_user".to_string(),
            pagination: Pagination {
                page_number: 1,
                show_number: 100,
            },
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("pagination"));
        assert!(json.contains("pageNumber"));
    }

    #[test]
    fn test_create_group_req_serialization() {
        let req = CreateGroupReq {
            group_info: CreateGroupInfo {
                group_name: "New Group".to_string(),
                face_url: Some("https://example.com/group.jpg".to_string()),
                introduction: None,
                notification: None,
                group_type: 0,
                ex: None,
            },
            member_user_ids: vec!["user_1".to_string()],
            admin_user_ids: vec![],
            owner_user_id: "owner_1".to_string(),
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("groupInfo"));
        assert!(json.contains("New Group"));
    }

    #[test]
    fn test_kick_group_member_req_serialization() {
        let req = KickGroupMemberReq {
            group_id: "group_123".to_string(),
            user_id_list: vec!["user_456".to_string()],
            reason: Some("violation".to_string()),
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("groupID"));
        assert!(json.contains("kickedUserIDs"));
        assert!(json.contains("violation"));
    }
}
