use crate::domain::error::Result;
use crate::core::event::events::group::{GroupEvent, GroupListener, GroupListenerExt};

use crate::infra::http::GroupServerApi;
use crate::domain::model::group::{GroupInfo, GroupMember, SetGroupInfoFields};
use crate::domain::model::local::LocalGroup;
use crate::domain::model::UserId;

use crate::client::context::Repositories;
use crate::infra::http::group::*;
use crate::infra::http::Pagination;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn};

// ========== 增量同步类型 ==========

#[allow(dead_code)]
pub struct GroupService {
    /// 外部依赖
    api: Arc<dyn GroupServerApi>,
    repositories: Arc<Repositories>,
    /// 身份
    user_id: UserId,
    /// 内部状态
    groups: Arc<RwLock<Vec<GroupInfo>>>,
    members: Arc<RwLock<Vec<GroupMember>>>,
    /// 事件出口（Listener trait）
    pub(crate) listener: Arc<dyn GroupListener>,
}

impl GroupService {
    pub fn new(api: Arc<dyn GroupServerApi>, repositories: Arc<Repositories>, user_id: UserId, listener: Arc<dyn GroupListener>) -> Self {
        Self {
            api,
            repositories,
            user_id,
            groups: Arc::new(RwLock::new(Vec::new())),
            members: Arc::new(RwLock::new(Vec::new())),
            listener,
        }
    }

    #[allow(dead_code)]
    pub(crate) fn send(&self, e: GroupEvent) {
        self.listener.emit(e);
    }

    /// 从本地数据库加载群组列表到内存缓存
    /// 在登录时调用，确保切换账号后能立即显示已有数据
    pub async fn load_groups_from_db(&self) {
        match self.repositories.group_repo.get_all_groups().await {
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
        let user_id = self.user_id.get().await;
        let req = GetJoinedGroupListReq {
            user_id: user_id.clone(),
            pagination: Pagination { page_number: 1, show_number: 1000 },
        };

        let resp = self.api.get_joined_group_list(&req).await?;

        let groups: Vec<GroupInfo> = resp.groups.unwrap_or_default().into_iter().map(server_to_group_info).collect();

        // 持久化到数据库
        for group in &groups {
            let local = group_info_to_local(group);
            if let Err(e) = self.repositories.group_repo.upsert_group(&local).await {
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
        let user_id = self.user_id.get().await;
        let table_name = "local_groups";

        // 1. 获取本地版本
        let (version_id, version) = match self.repositories.sync_version_repo.get_version_sync(table_name, &user_id).await? {
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

        let resp: GetIncrementalJoinGroupResp = match self.api.get_incremental_join_group(&req).await {
            Ok(r) => r,
            Err(e) => {
                warn!("增量同步群组请求失败, 回退全量同步: {}", e);
                return self.sync_groups().await;
            }
        };

        // 3. full=true 回退全量
        if resp.full {
            info!("服务端返回 full=true, 执行全量同步群组");
            let version_id = resp.version_id;
            let version = resp.version;
            let r = self.sync_groups().await;
            // 全量同步完成后持久化服务端返回的版本，避免下次启动再次全量
            if let Err(e) = self.repositories.sync_version_repo.set_version_sync(table_name, &user_id, &version_id, version).await {
                warn!("全量同步后更新群组同步版本失败: {}", e);
            }
            return r;
        }

        // 4. 处理增量变更

        // 4a. 删除
        if !resp.delete.is_empty() {
            info!("增量同步: 删除 {} 个群组", resp.delete.len());
            for group_id in &resp.delete {
                if let Err(e) = self.repositories.group_repo.delete_group(group_id).await {
                    warn!("增量删除群组数据库操作失败: {}", e);
                }
            }
            self.groups.write().await.retain(|g| !resp.delete.contains(&g.group_id));
        }

        // 4b. 新增
        for s in &resp.insert {
            let group_info = server_to_group_info(s.clone());
            let local = group_info_to_local(&group_info);
            if let Err(e) = self.repositories.group_repo.upsert_group(&local).await {
                warn!("增量插入群组数据库操作失败: {}", e);
            }
            self.groups.write().await.push(group_info);
        }

        // 4c. 更新
        for s in &resp.update {
            let group_info = server_to_group_info(s.clone());
            let local = group_info_to_local(&group_info);
            if let Err(e) = self.repositories.group_repo.upsert_group(&local).await {
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
            if let Ok(local_groups) = self.repositories.group_repo.get_all_groups().await {
                let groups: Vec<GroupInfo> = local_groups.iter().map(local_to_group_info).collect();
                *self.groups.write().await = groups;
            }
        }

        // 5. 更新版本号
        if let Err(e) = self.repositories.sync_version_repo.set_version_sync(table_name, &user_id, &resp.version_id, resp.version).await {
            warn!("更新群组同步版本失败: {}", e);
        }

        info!("增量同步群组完成, insert={}, update={}, delete={}", resp.insert.len(), resp.update.len(), resp.delete.len());
        Ok(())
    }

    pub async fn get_groups_info(&self, group_ids: Vec<String>) -> Result<Vec<GroupInfo>> {
        let req = GetGroupsInfoReq { group_ids: group_ids.clone() };

        let resp = self.api.get_groups_info(&req).await?;

        let groups: Vec<GroupInfo> = resp.groups_info.into_iter().map(server_to_group_info).collect();

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
        // 服务端会自动把 ownerUserID 追加为成员，成员/管理员列表里不能重复包含群主。
        let member_user_ids = member_user_ids.into_iter().filter(|id| id != &owner_user_id).collect::<Vec<_>>();
        let admin_user_ids = admin_user_ids.into_iter().filter(|id| id != &owner_user_id).collect::<Vec<_>>();
        let req = CreateGroupReq {
            group_info: CreateGroupInfo {
                group_name,
                face_url,
                introduction,
                notification,
                group_type: 2, // 2 = 普通群（与 Go SDK 一致）
                ex: None,
                creator_user_id: owner_user_id.clone(),
            },
            member_user_ids,
            admin_user_ids,
            owner_user_id,
        };

        let resp = self.api.create_group(&req).await?;

        let group = server_to_group_info(resp.group);
        self.groups.write().await.push(group.clone());

        info!("群组已创建: {}", group.group_id);
        Ok(group)
    }

    pub async fn join_group(&self, group_id: String, req_msg: Option<String>) -> Result<()> {
        let user_id = self.user_id.get().await;
        let req = JoinGroupReq {
            group_id: group_id.clone(),
            req_msg,
            join_source: 1,
            inviter_user_id: user_id,
            ex: None,
        };

        self.api.join_group(&req).await?;

        info!("已申请加入群组: {}", group_id);
        Ok(())
    }

    pub async fn quit_group(&self, group_id: String) -> Result<()> {
        let user_id = self.user_id.get().await;
        let req = QuitGroupReq { group_id: group_id.clone(), user_id };

        self.api.quit_group(&req).await?;

        self.groups.write().await.retain(|g| g.group_id != group_id);
        self.members.write().await.retain(|m| m.group_id != group_id);

        info!("已退出群组: {}", group_id);
        Ok(())
    }

    pub async fn dismiss_group(&self, group_id: String) -> Result<()> {
        let req = DismissGroupReq {
            group_id: group_id.clone(),
            delete_member: true,
        };

        self.api.dismiss_group(&req).await?;

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

        self.api.set_group_info(&req).await?;

        if let Some(group) = self.groups.write().await.iter_mut().find(|g| g.group_id == updates.group_id) {
            if let Some(name) = &req.group_name {
                group.group_name = name.clone();
            }
            if let Some(url) = &req.face_url {
                group.face_url = url.clone();
            }
            if let Some(introduction) = &req.introduction {
                group.introduction = introduction.clone();
            }
            if let Some(notification) = &req.notification {
                group.notification = notification.clone();
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

    pub async fn get_group_member_list(&self, group_id: String, filter: i32, offset: u32, count: u32) -> Result<Vec<GroupMember>> {
        let req = GetGroupMemberListReq {
            group_id: group_id.clone(),
            filter,
            pagination: Pagination {
                page_number: if offset == 0 { 1 } else { offset as i32 },
                show_number: count as i32,
            },
            keyword: String::new(),
        };

        let resp = self.api.get_group_member_list(&req).await?;

        let members: Vec<GroupMember> = resp.members.unwrap_or_default().into_iter().map(server_to_group_member).collect();

        Ok(members)
    }

    pub async fn get_group_members_info(&self, group_id: String, user_ids: Vec<String>) -> Result<Vec<GroupMember>> {
        let req = GetGroupMembersInfoReq { group_id: group_id.clone(), user_ids };

        let resp = self.api.get_group_members_info(&req).await?;

        let members: Vec<GroupMember> = resp.members_info.into_iter().map(server_to_group_member).collect();

        Ok(members)
    }

    pub async fn kick_group_member(&self, group_id: String, user_ids: Vec<String>, reason: Option<String>) -> Result<()> {
        let req = KickGroupMemberReq {
            group_id: group_id.clone(),
            user_id_list: user_ids,
            reason,
        };

        self.api.kick_group_member(&req).await?;

        self.members.write().await.retain(|m| m.group_id != group_id || !req.user_id_list.contains(&m.user_id));

        info!("群成员已踢出: group={}", group_id);
        Ok(())
    }

    pub async fn invite_user_to_group(&self, group_id: String, user_ids: Vec<String>, reason: Option<String>) -> Result<()> {
        let req = InviteUserToGroupReq {
            group_id: group_id.clone(),
            user_id_list: user_ids,
            reason,
        };

        self.api.invite_user_to_group(&req).await?;

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

        self.api.set_group_member_info(&req).await?;

        info!("群成员信息已更新: group={}, user={}", updates.group_id, updates.user_id);
        Ok(())
    }

    pub async fn get_group_application_list(&self) -> Result<GetGroupApplicationListResp> {
        let user_id = self.user_id.get().await;
        let req = GetGroupApplicationListReq {
            from_user_id: user_id,
            pagination: Pagination { page_number: 1, show_number: 1000 },
        };
        let resp = self.api.get_group_application_list(&req).await?;
        Ok(resp)
    }

    /// 获取管理员收到的群组申请列表（对齐 Go SDK GetGroupApplicationListAsRecipient）
    pub async fn get_group_application_list_as_recipient(&self) -> Result<GetGroupApplicationListResp> {
        let user_id = self.user_id.get().await;
        let req = GetGroupApplicationListReq {
            from_user_id: user_id,
            pagination: Pagination { page_number: 1, show_number: 1000 },
        };
        let resp = self.api.get_recv_group_application_list(&req).await?;
        Ok(resp)
    }

    /// 获取自己发出的群组申请列表（对齐 Go SDK GetGroupApplicationListAsApplicant）
    pub async fn get_group_application_list_as_applicant(&self) -> Result<GetGroupApplicationListResp> {
        let user_id = self.user_id.get().await;
        let req = GetUserReqApplicationListReq {
            user_id,
            pagination: Pagination { page_number: 1, show_number: 1000 },
        };
        let resp = self.api.get_send_group_application_list(&req).await?;
        Ok(resp)
    }

    /// 获取未处理的群组申请数量（对齐 Go SDK GetGroupApplicationUnhandledCount）
    pub async fn get_group_application_unhandled_count(&self) -> Result<i32> {
        let user_id = self.user_id.get().await;
        self.api.get_group_application_unhandled_count(&user_id).await
    }

    pub async fn accept_group_application(&self, group_id: String, user_id: String, handle_msg: Option<String>) -> Result<()> {
        let req = AcceptGroupApplicationReq {
            group_id: group_id.clone(),
            from_user_id: user_id.clone(),
            handle_msg,
            handle_result: 1,
        };
        self.api.accept_group_application(&req).await?;

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
            handle_result: -1,
        };
        self.api.refuse_group_application(&req).await?;
        info!("群组申请已拒绝: group={}, user={}", group_id, user_id);
        Ok(())
    }

    /// 转让群主
    pub async fn transfer_group_owner(&self, group_id: String, new_owner_user_id: String) -> Result<()> {
        self.api.transfer_group_owner(&group_id, &new_owner_user_id).await?;
        if let Err(e) = self.sync_groups().await {
            tracing::warn!("转让群主后同步群组列表失败: {}", e);
        }
        info!("群主已转让: group={}, new_owner={}", group_id, new_owner_user_id);
        Ok(())
    }

    /// 全局禁言/解除禁言群组
    pub async fn mute_group(&self, group_id: String, is_mute: bool) -> Result<()> {
        self.api.mute_group(&group_id, is_mute).await?;
        info!("群组禁言状态已更新: group={}, is_mute={}", group_id, is_mute);
        Ok(())
    }

    /// 禁言/解除禁言群成员
    pub async fn mute_group_member(&self, group_id: String, user_id: String, muted_seconds: i64) -> Result<()> {
        self.api.mute_group_member(&group_id, &user_id, muted_seconds).await?;
        info!("群成员禁言状态已更新: group={}, user={}, seconds={}", group_id, user_id, muted_seconds);
        Ok(())
    }

    /// 分页获取已加入群组列表（对齐 Go SDK `GetJoinedGroupListPage`）
    ///
    /// 优先从服务端分页获取，返回指定页的群组列表。
    pub async fn get_joined_group_list_page(&self, offset: i32, count: i32) -> Result<Vec<GroupInfo>> {
        let user_id = self.user_id.get().await;
        let req = GetJoinedGroupListReq {
            user_id,
            pagination: Pagination {
                page_number: if offset == 0 { 1 } else { offset },
                show_number: count,
            },
        };

        let resp = self.api.get_joined_group_list(&req).await?;

        let groups: Vec<GroupInfo> = resp.groups.unwrap_or_default().into_iter().map(server_to_group_info).collect();

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
            .filter(|g| g.group_id.to_lowercase().contains(&kw) || g.group_name.to_lowercase().contains(&kw))
            .cloned()
            .collect()
    }

    /// 获取群主和管理员列表（对齐 Go SDK `GetGroupMemberOwnerAndAdmin`）
    ///
    /// 从服务端获取 roleLevel >= 2（管理员和群主）的成员。
    pub async fn get_group_member_owner_and_admin(&self, group_id: String) -> Result<Vec<GroupMember>> {
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

        let end_time = if join_time_end == 0 { i64::MAX } else { join_time_end };

        let filter_set: std::collections::HashSet<String> = filter_user_ids.into_iter().collect();

        let filtered: Vec<GroupMember> = all_members
            .into_iter()
            .filter(|m| m.join_time >= join_time_begin && m.join_time <= end_time && !filter_set.contains(&m.user_id))
            .skip(offset.max(0) as usize)
            .take(count.max(0) as usize)
            .collect();

        Ok(filtered)
    }

    /// 搜索群成员（对齐 Go SDK `SearchGroupMembers`）
    ///
    /// 在本地缓存中按 user_id 或 nickname 模糊搜索指定群组的成员。
    pub async fn search_group_members(&self, group_id: &str, keyword: &str) -> Vec<GroupMember> {
        if !self.has_members(group_id).await {
            let _ = self.sync_group_members(group_id).await;
        }
        let kw = keyword.to_lowercase();
        self.members
            .read()
            .await
            .iter()
            .filter(|m| m.group_id == group_id && (m.user_id.to_lowercase().contains(&kw) || m.nickname.to_lowercase().contains(&kw)))
            .cloned()
            .collect()
    }

    /// 获取指定用户在群组中的存在情况（对齐 Go SDK `GetUsersInGroup`）
    ///
    /// 返回传入 user_ids 中存在于该群组的用户 ID 列表。
    pub async fn get_users_in_group(&self, group_id: &str, user_ids: Vec<String>) -> Vec<String> {
        if !self.has_members(group_id).await {
            let _ = self.sync_group_members(group_id).await;
        }
        let members = self.members.read().await;
        let member_set: std::collections::HashSet<String> = members.iter().filter(|m| m.group_id == group_id).map(|m| m.user_id.clone()).collect();

        user_ids.into_iter().filter(|uid| member_set.contains(uid)).collect()
    }

    async fn has_members(&self, group_id: &str) -> bool {
        self.members.read().await.iter().any(|m| m.group_id == group_id)
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
        self.members.read().await.iter().any(|m| m.group_id == group_id)
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
            pagination: Pagination { page_number: 1, show_number: 100 },
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
                creator_user_id: "owner_1".to_string(),
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
