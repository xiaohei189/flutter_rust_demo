use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::bus::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::listener::group::{GroupListener, GroupEvent};
use crate::domain::event::types::GroupReadReceipt;
use crate::domain::model::group::{GroupInfo, GroupMember, SetGroupInfoFields};
use crate::infra::database::group_dao::GroupDao;
use crate::infra::database::models::LocalGroup;
use crate::infra::database::sync_version_dao::SyncVersionDao;
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{
    CREATE_GROUP, GET_GROUPS_INFO, GET_GROUP_INFO, SET_GROUP_INFO, JOIN_GROUP, QUIT_GROUP,
    DISMISS_GROUP, GET_FULL_JOIN_GROUP_IDS, GET_GROUP_MEMBER_LIST, GET_GROUP_MEMBERS_INFO,
    GET_INCREMENTAL_JOIN_GROUP, GET_JOINED_GROUP_LIST, INVITE_USER_TO_GROUP,
    SET_GROUP_MEMBER_INFO, KICK_GROUP_MEMBER,
    GET_GROUP_APPLICATION_LIST, GET_RECV_GROUP_APPLICATION_LIST, GET_SEND_GROUP_APPLICATION_LIST,
    GET_GROUP_APPLICATION_UNHANDLED_COUNT,
    ACCEPT_GROUP_APPLICATION, REFUSE_GROUP_APPLICATION,
    TRANSFER_GROUP_OWNER, MUTE_GROUP, CANCEL_MUTE_GROUP, MUTE_GROUP_MEMBER, CANCEL_MUTE_GROUP_MEMBER,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn};

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

// ========== 增量同步类型 ==========

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

pub struct GroupManager {
    http_client: Arc<HttpApiClient>,
    user_id: Arc<RwLock<String>>,
    groups: Arc<RwLock<Vec<GroupInfo>>>,
    members: Arc<RwLock<Vec<GroupMember>>>,
    group_dao: Arc<GroupDao>,
    sync_version_dao: Arc<SyncVersionDao>,
    pub(crate) event_tx: Arc<std::sync::Mutex<Option<tokio::sync::mpsc::UnboundedSender<GroupEvent>>>>,
}

impl GroupManager {
    pub fn new(
        http_client: Arc<HttpApiClient>,
        user_id: String,
        group_dao: Arc<GroupDao>,
        sync_version_dao: Arc<SyncVersionDao>,
    ) -> Self {
        Self {
            http_client,
            user_id: Arc::new(RwLock::new(user_id)),
            groups: Arc::new(RwLock::new(Vec::new())),
            members: Arc::new(RwLock::new(Vec::new())),
            group_dao,
            sync_version_dao,
            event_tx: Arc::new(std::sync::Mutex::new(None)),
        }
    }

    pub fn set_event_sender(&self, tx: tokio::sync::mpsc::UnboundedSender<GroupEvent>) {
        *self.event_tx.lock().unwrap() = Some(tx);
    }

    pub(crate) fn send(&self, e: GroupEvent) {
        if let Some(tx) = &*self.event_tx.lock().unwrap() { let _ = tx.send(e); }
    }

    fn notify_group(&self, f: impl FnOnce(&dyn GroupListener)) {
        if let Some(l) = &*self.group_listener.read().unwrap() { f(&**l); }
    }

    fn on_joined_group_added(&self, g: &GroupInfo) { self.notify_group(|l| l.on_joined_group_added(g)); }
    fn on_group_info_changed(&self, g: &GroupInfo) { self.notify_group(|l| l.on_group_info_changed(g)); }
    fn on_group_read_receipt(&self, r: &[GroupReadReceipt]) { self.notify_group(|l| l.on_group_read_receipt(r)); }

    pub async fn set_user_id(&self, user_id: String) {
        *self.user_id.write().await = user_id.clone();
        debug!("GroupManager user_id 已更新为: {}", user_id);
    }

    /// 从本地数据库加载群组列表到内存缓存
    /// 在登录时调用，确保切换账号后能立即显示已有数据
    pub async fn load_groups_from_db(&self) {
        match self.group_dao.get_all_groups().await {
            Ok(local_groups) => {
                let groups: Vec<GroupInfo> = local_groups.iter().map(local_to_group_info).collect();
                let count = groups.len();
                *self.groups.write().await = groups;
                info!("从数据库加载群组列表完成, count={}", count);
            }
            Err(e) => {
                warn!("从数据库加载群组列表失败: {}", e);
            }
        }
    }

    pub async fn get_joined_group_list(&self) -> Vec<GroupInfo> {
        self.groups.read().await.clone()
    }

    /// 全量同步群组列表（对齐 Go SDK FullSync）
    pub async fn sync_groups(&self) -> Result<()> {
        let user_id = self.user_id.read().await.clone();
        let req = GetJoinedGroupListReq {
            user_id: user_id.clone(),
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

        // 持久化到数据库
        for group in &groups {
            let local = group_info_to_local(group);
            if let Err(e) = self.group_dao.upsert_group(&local).await {
                warn!("全量同步群组到数据库失败: {}", e);
            }
        }

        // 更新内存缓存
        *self.groups.write().await = groups.clone();

        info!("群组列表已全量同步, count={}", groups.len());
        Ok(())
    }

    /// 增量同步群组列表（对齐 Go SDK IncrSyncJoinGroup / VersionSynchronizer）
    ///
    /// 1. 从 local_sync_version 读取本地版本
    /// 2. 调用 get_incremental_join_groups 获取增量数据
    /// 3. 如果 full=true 回退到全量同步
    /// 4. 否则处理 delete/insert/update 增量合并
    /// 5. 更新版本号
    pub async fn sync_groups_incremental(&self) -> Result<()> {
        let user_id = self.user_id.read().await.clone();
        let table_name = "local_groups";

        // 1. 获取本地版本
        let (version_id, version) = match self.sync_version_dao.get_version_sync(table_name, &user_id).await? {
            Some((vid, v)) => (vid, v),
            None => (String::new(), 0),
        };

        info!("开始增量同步群组, version={}, version_id={}", version, version_id);

        // 2. 请求增量数据
        let req = GetIncrementalJoinGroupReq {
            user_id: user_id.clone(),
            version_id: version_id.clone(),
            version,
        };

        let resp: GetIncrementalJoinGroupResp = match self.http_client.post(GET_INCREMENTAL_JOIN_GROUP, &req).await {
            Ok(r) => r,
            Err(e) => {
                warn!("增量同步群组请求失败, 回退全量同步: {}", e);
                return self.sync_groups().await;
            }
        };

        // 3. full=true 回退全量
        if resp.full {
            info!("服务端返回 full=true, 执行全量同步群组");
            return self.sync_groups().await;
        }

        // 4. 处理增量变更

        // 4a. 删除
        if !resp.delete.is_empty() {
            info!("增量同步: 删除 {} 个群组", resp.delete.len());
            for group_id in &resp.delete {
                if let Err(e) = self.group_dao.delete_group(group_id).await {
                    warn!("增量删除群组数据库操作失败: {}", e);
                }
            }
            self.groups.write().await.retain(|g| !resp.delete.contains(&g.group_id));
        }

        // 4b. 新增
        for s in &resp.insert {
            let group_info = server_to_group_info(s.clone());
            let local = group_info_to_local(&group_info);
            if let Err(e) = self.group_dao.upsert_group(&local).await {
                warn!("增量插入群组数据库操作失败: {}", e);
            }
            self.groups.write().await.push(group_info);
        }

        // 4c. 更新
        for s in &resp.update {
            let group_info = server_to_group_info(s.clone());
            let local = group_info_to_local(&group_info);
            if let Err(e) = self.group_dao.upsert_group(&local).await {
                warn!("增量更新群组数据库操作失败: {}", e);
            }
            let mut groups = self.groups.write().await;
            if let Some(existing) = groups.iter_mut().find(|g| g.group_id == group_info.group_id) {
                *existing = group_info;
            } else {
                groups.push(group_info);
            }
        }

        // 4d. 排序版本变化时刷新内存列表
        if resp.sort_version > 0 {
            info!("群组排序版本变化 (sortVersion={}), 刷新内存列表", resp.sort_version);
            if let Ok(local_groups) = self.group_dao.get_all_groups().await {
                let groups: Vec<GroupInfo> = local_groups.iter().map(local_to_group_info).collect();
                *self.groups.write().await = groups;
            }
        }

        // 5. 更新版本号
        if let Err(e) = self.sync_version_dao.set_version_sync(table_name, &user_id, &resp.version_id, resp.version).await {
            warn!("更新群组同步版本失败: {}", e);
        }

        info!("增量同步群组完成, insert={}, update={}, delete={}",
            resp.insert.len(), resp.update.len(), resp.delete.len());
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

    /// 分页获取已加入群组列表（对齐 Go SDK `GetJoinedGroupListPage`）
    ///
    /// 优先从服务端分页获取，返回指定页的群组列表。
    pub async fn get_joined_group_list_page(
        &self,
        offset: i32,
        count: i32,
    ) -> Result<Vec<GroupInfo>> {
        let user_id = self.user_id.read().await.clone();
        let req = GetJoinedGroupListReq {
            user_id,
            pagination: Pagination {
                page_number: if offset == 0 { 1 } else { offset },
                show_number: count,
            },
        };

        let resp: GetJoinedGroupListResp = self.http_client.post(GET_JOINED_GROUP_LIST, &req).await?;

        let groups: Vec<GroupInfo> = resp
            .groups
            .unwrap_or_default()
            .into_iter()
            .map(server_to_group_info)
            .collect();

        Ok(groups)
    }

    /// 搜索群组（对齐 Go SDK `SearchGroups`）
    ///
    /// 在本地缓存中按 group_id 或 group_name 模糊搜索。
    pub async fn search_groups(&self, keyword: &str) -> Vec<GroupInfo> {
        let kw = keyword.to_lowercase();
        self.groups
            .read()
            .await
            .iter()
            .filter(|g| {
                g.group_id.to_lowercase().contains(&kw)
                    || g.group_name.to_lowercase().contains(&kw)
            })
            .cloned()
            .collect()
    }

    /// 获取群主和管理员列表（对齐 Go SDK `GetGroupMemberOwnerAndAdmin`）
    ///
    /// 从服务端获取 roleLevel >= 2（管理员和群主）的成员。
    pub async fn get_group_member_owner_and_admin(
        &self,
        group_id: String,
    ) -> Result<Vec<GroupMember>> {
        // filter=3 表示获取群主+管理员
        self.get_group_member_list(group_id, 3, 0, 1000).await
    }

    /// 按加入时间筛选群成员（对齐 Go SDK `GetGroupMemberListByJoinTimeFilter`）
    ///
    /// 从服务端分页获取指定加入时间范围内的群成员。
    pub async fn get_group_member_list_by_join_time_filter(
        &self,
        group_id: String,
        offset: i32,
        count: i32,
        join_time_begin: i64,
        join_time_end: i64,
        filter_user_ids: Vec<String>,
    ) -> Result<Vec<GroupMember>> {
        // 先从服务端获取全部成员（使用 filter=0 表示所有成员）
        let all_members = self.get_group_member_list(group_id, 0, 0, 10000).await?;

        let end_time = if join_time_end == 0 {
            i64::MAX
        } else {
            join_time_end
        };

        let filter_set: std::collections::HashSet<String> = filter_user_ids.into_iter().collect();

        let filtered: Vec<GroupMember> = all_members
            .into_iter()
            .filter(|m| {
                m.join_time >= join_time_begin
                    && m.join_time <= end_time
                    && !filter_set.contains(&m.user_id)
            })
            .skip(offset.max(0) as usize)
            .take(count.max(0) as usize)
            .collect();

        Ok(filtered)
    }

    /// 搜索群成员（对齐 Go SDK `SearchGroupMembers`）
    ///
    /// 在本地缓存中按 user_id 或 nickname 模糊搜索指定群组的成员。
    pub async fn search_group_members(
        &self,
        group_id: &str,
        keyword: &str,
    ) -> Vec<GroupMember> {
        let kw = keyword.to_lowercase();
        self.members
            .read()
            .await
            .iter()
            .filter(|m| {
                m.group_id == group_id
                    && (m.user_id.to_lowercase().contains(&kw)
                        || m.nickname.to_lowercase().contains(&kw))
            })
            .cloned()
            .collect()
    }

    /// 获取指定用户在群组中的存在情况（对齐 Go SDK `GetUsersInGroup`）
    ///
    /// 返回传入 user_ids 中存在于该群组的用户 ID 列表。
    pub async fn get_users_in_group(
        &self,
        group_id: &str,
        user_ids: Vec<String>,
    ) -> Vec<String> {
        let members = self.members.read().await;
        let member_set: std::collections::HashSet<String> = members
            .iter()
            .filter(|m| m.group_id == group_id)
            .map(|m| m.user_id.clone())
            .collect();

        user_ids
            .into_iter()
            .filter(|uid| member_set.contains(uid))
            .collect()
    }

    /// 检查本地群组是否已全量同步（对齐 Go SDK `CheckLocalGroupFullSync`）
    ///
    /// 简化实现：检查本地缓存中是否有群组数据。
    pub async fn check_local_group_full_sync(&self) -> bool {
        // 如果 groups 缓存非空，认为已同步
        // 完整实现应比对版本同步表
        !self.groups.read().await.is_empty()
    }

    /// 检查群成员是否已全量同步（对齐 Go SDK `CheckGroupMemberFullSync`）
    ///
    /// 简化实现：检查本地缓存中是否有该群组的成员数据。
    pub async fn check_group_member_full_sync(&self, group_id: &str) -> bool {
        self.members
            .read()
            .await
            .iter()
            .any(|m| m.group_id == group_id)
    }

    /// 同步指定群组的成员列表到本地缓存
    pub async fn sync_group_members(&self, group_id: &str) -> Result<()> {
        let members = self.get_group_member_list(group_id.to_string(), 0, 0, 10000).await?;

        let mut cache = self.members.write().await;
        cache.retain(|m| m.group_id != group_id);
        cache.extend(members);

        info!("群成员列表已同步: group={}", group_id);
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

fn group_info_to_local(g: &GroupInfo) -> LocalGroup {
    LocalGroup {
        group_id: g.group_id.clone(),
        name: g.group_name.clone(),
        notification: g.notification.clone(),
        introduction: g.introduction.clone(),
        face_url: g.face_url.clone(),
        create_time: g.create_time,
        status: g.status,
        creator_user_id: String::new(),
        group_type: 0,
        owner_user_id: g.owner_user_id.clone(),
        member_count: g.member_count as i32,
        ex: String::new(),
        attached_info: String::new(),
        need_verification: 0,
        look_member_info: 0,
        apply_member_friend: 0,
        notification_update_time: 0,
        notification_user_id: String::new(),
    }
}

fn local_to_group_info(l: &LocalGroup) -> GroupInfo {
    GroupInfo {
        group_id: l.group_id.clone(),
        group_name: l.name.clone(),
        face_url: l.face_url.clone(),
        introduction: l.introduction.clone(),
        notification: l.notification.clone(),
        owner_user_id: l.owner_user_id.clone(),
        create_time: l.create_time,
        member_count: l.member_count as u32,
        status: l.status,
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
