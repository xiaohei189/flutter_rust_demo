use crate::domain::error::Result;
use crate::core::conversation::service::{CleanupSource, ConversationService};
use crate::core::event::events::group::{GroupEvent, GroupListener, GroupListenerExt};

use crate::infra::http::GroupServerApi;
use crate::domain::model::group::{GroupInfo, GroupMember, SetGroupInfoFields};
use crate::domain::model::local::{LocalConversation, LocalGroup};
use crate::domain::model::UserId;

use crate::sdk::client::context::Repositories;
use crate::infra::http::group::*;
use crate::infra::http::Pagination;
use crate::domain::constant::types::group_status;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn};

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
    /// 群失效后的会话清理/对账（由 builder 注入；未注入时跳过并记日志）
    conversation_service: Option<Arc<ConversationService>>,
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
            conversation_service: None,
            listener,
        }
    }

    /// 注入会话服务：群不再可用（被解散/自己被移出/主动退出）时，
    /// 会话清理与对账统一走 `ConversationService`，保证删库与 `Deleted` 事件成对发生。
    pub fn with_conversation_service(mut self, conversation_service: Arc<ConversationService>) -> Self {
        self.conversation_service = Some(conversation_service);
        self
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
        // 内存群列表刚被服务端结果替换，以它为准对齐一次会话表（全量同步也会漏掉服务端不下发的会话删除）
        self.reconcile_group_conversations(CleanupSource::Sync).await;
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
                // 被解散 / 被移出群时服务端只把群标记为删除，
                // 本地会话不会自动消失，这里一并清理，避免残留进不去的死群。
                // 清理统一走 ConversationService（删库 + 广播 Deleted），
                // 不在群服务里直接删会话表，避免「删了库 UI 不知道」和无事件删除。
                self.remove_local_group_state(group_id, CleanupSource::Sync).await;
            }
        }

        // 4b. 新增
        for s in &resp.insert {
            let group_info = server_to_group_info(s.clone());
            let local = group_info_to_local(&group_info);
            if let Err(e) = self.repositories.group_repo.upsert_group(&local).await {
                warn!("增量插入群组数据库操作失败: {}", e);
            }
            // 服务端会为群成员预建 `sg_<groupID>` 会话，但客户端只在收到群通知
            // 或会话同步时才落库；通知丢失/离线补拉失败时成员端就没有该群的会话。
            // 群同步新增分支是最终兜底：确保本地会话存在（已存在时不动本地字段）。
            self.ensure_group_conversation(&group_info).await;
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
        // 兜底对账：推送缺失时，内存群列表已是最新，用它清掉历史遗留的孤儿群会话
        self.reconcile_group_conversations(CleanupSource::Sync).await;
        Ok(())
    }

    pub async fn get_groups_info(&self, group_ids: Vec<String>) -> Result<Vec<GroupInfo>> {
        let req = GetGroupsInfoReq { group_ids: group_ids.clone() };

        let resp = self.api.get_groups_info(&req).await?;

        let groups: Vec<GroupInfo> = resp.groups_info.into_iter().map(server_to_group_info).collect();

        // 服务端群资料落库：会话列表/群设置页的群名、头像由本地 group 表补全，
        // 不落库会出现「改完群名，会话列表与设置页还是旧名」。
        for group in &groups {
            // 已解散的群不能落库：落库后「我的群组」会列出进不去的群，
            // 对账也会把它当成仍有效的群而放过孤儿会话。
            if group.status == group_status::DISMISSED {
                debug!("跳过落库已解散群: group={}", group.group_id);
                continue;
            }
            self.persist_group_info(group).await;
        }

        Ok(groups)
    }

    /// 用服务端群资料更新本地群表。
    ///
    /// 服务端不下发 `creator_user_id`/`group_type`/`need_verification` 等字段，
    /// 因此写入前先读出本地已有记录并保留这些字段，避免被清空。
    async fn persist_group_info(&self, server: &GroupInfo) {
        let mut local = group_info_to_local(server);
        if let Ok(Some(existing)) = self.repositories.group_repo.get_group(&server.group_id).await {
            local.creator_user_id = existing.creator_user_id;
            local.group_type = existing.group_type;
            local.ex = existing.ex;
            local.attached_info = existing.attached_info;
            local.need_verification = existing.need_verification;
            local.look_member_info = existing.look_member_info;
            local.apply_member_friend = existing.apply_member_friend;
            local.notification_update_time = existing.notification_update_time;
            local.notification_user_id = existing.notification_user_id;
        }
        if let Err(e) = self.repositories.group_repo.upsert_group(&local).await {
            warn!("群资料落库失败: group={}, err={}", server.group_id, e);
        }
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

        // 服务端创建群时会为每个成员创建会话（sg_<groupID>），
        // 但增量会话同步不保证立刻把它推下来。这里直接落本地：
        // 1) 群信息持久化，重启后群列表不丢；
        // 2) 会话落库，创建后立刻能在会话列表看到并进入聊天。
        if let Err(e) = self.repositories.group_repo.upsert_group(&group_info_to_local(&group)).await {
            warn!("创建群后写入本地群组失败: {}", e);
        }
        // 统一走 ConversationService：落库并广播 Changed，UI 立即刷新。
        // 不再直接写 conversation_repo（那条路径不发事件）。
        self.ensure_group_conversation(&group).await;

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

        self.remove_local_group_state(&group_id, CleanupSource::LocalAction).await;

        info!("已退出群组: {}", group_id);
        Ok(())
    }

    pub async fn dismiss_group(&self, group_id: String) -> Result<()> {
        let req = DismissGroupReq {
            group_id: group_id.clone(),
            // 服务端只在 deleteMember=false 时才向成员投递并持久化
            // GroupDismissedNotification(1511)；成员记录由 push 服务随后异步清理。
            // 传 true 会直接删成员并跳过通知，成员端只能等重连后的增量同步才发现群没了。
            delete_member: false,
        };

        self.api.dismiss_group(&req).await?;

        self.remove_local_group_state(&group_id, CleanupSource::LocalAction).await;

        info!("群组已解散: {}", group_id);
        Ok(())
    }

    /// 确保群有一个本地 `sg_<groupID>` 会话（无消息的群也要能在会话列表看到）。
    ///
    /// 服务端会为群成员预建会话，但客户端只在收到群通知（1501/1502）或会话同步时
    /// 落库；通知丢失、离线补拉失败时，成员端就只剩「通讯录 → 我的群组」入口。
    /// 这里在「群同步新增」与「本端建群」两个入口兜底创建。
    ///
    /// 已存在时直接返回，不覆盖本地未读/草稿/置顶等字段，重复调用安全。
    async fn ensure_group_conversation(&self, group: &GroupInfo) {
        let Some(conversation_service) = &self.conversation_service else {
            return;
        };
        let conversation_id = format!("sg_{}", group.group_id);
        match conversation_service.get_conversation(&conversation_id).await {
            Ok(Some(_)) => return,
            Ok(None) => {}
            Err(e) => {
                warn!("检查群会话失败: group={}, err={}", group.group_id, e);
                return;
            }
        }
        let conversation = LocalConversation {
            conversation_id,
            conversation_type: 3,
            user_id: String::new(),
            group_id: group.group_id.clone(),
            show_name: group.group_name.clone(),
            face_url: group.face_url.clone(),
            latest_msg: String::new(),
            latest_msg_send_time: chrono::Utc::now().timestamp_millis(),
            unread_count: 0,
            recv_msg_opt: 0,
            is_pinned: false,
            is_private_chat: false,
            burn_duration: 0,
            group_at_type: 0,
            is_not_in_group: false,
            update_unread_count_time: 0,
            attached_info: String::new(),
            ex: String::new(),
            draft_text: String::new(),
            draft_text_time: 0,
            max_seq: 0,
            min_seq: 0,
            is_msg_destruct: false,
            msg_destruct_time: 0,
        };
        if let Err(e) = conversation_service.upsert_conversation(conversation).await {
            warn!("补建群会话失败: group={}, err={}", group.group_id, e);
        } else {
            info!("补建群会话: group_id={}", group.group_id);
        }
    }

    /// 退出/解散群后清理本地群资料与群会话。
    ///
    /// 服务端增量会话同步不保证立刻下发该会话的删除，若不主动清理，
    /// 会话列表会残留无法进入的「死群」。
    /// 会话删除统一委托 `ConversationService`：删库与 `Deleted` 事件必须成对发生。
    async fn remove_local_group_state(&self, group_id: &str, source: CleanupSource) {
        self.groups.write().await.retain(|g| g.group_id != group_id);
        self.members.write().await.retain(|m| m.group_id != group_id);
        if let Err(e) = self.repositories.group_repo.delete_group(group_id).await {
            warn!("清理本地群资料失败: group={}, err={}", group_id, e);
        }
        let conversation_id = format!("sg_{}", group_id);
        match &self.conversation_service {
            Some(conversation_service) => {
                if let Err(e) = conversation_service.delete_conversation_with_source(&conversation_id, source).await {
                    warn!("清理本地群会话失败: cleanup_source={}, group_id={}, conversation_id={}, err={}", source.as_str(), group_id, conversation_id, e);
                }
            }
            None => warn!("会话服务未注入，跳过本地群会话清理: group_id={}, conversation_id={}", group_id, conversation_id),
        }
    }

    /// 对齐「群集合 → 会话集合」（清理服务端未推送删除的孤儿群会话）。
    ///
    /// 调用时机有两个：群全量/增量同步成功后；以及消息同步结束后的兜底——离线补拉的
    /// 群解散通知（1511）走的是「会话消息」通道，会为已解散的群建出本地会话且不经过
    /// 通知处理器，只靠群同步时机的对账清不掉。
    ///
    /// 内存群列表为空时直接跳过：此时群同步尚未完成（或确实没有群），继续做对账会把
    /// 所有 `sg_*` 会话误判成孤儿。
    /// 用内存列表而不是 DB 群表：全量同步只 upsert 不删行，群表可能残留过期群。
    pub(crate) async fn reconcile_group_conversations(&self, source: CleanupSource) {
        let Some(conversation_service) = &self.conversation_service else {
            return;
        };
        // 先快照，避免持读锁期间再取写锁做清理
        let groups = self.groups.read().await.clone();
        if groups.is_empty() {
            debug!("群会话对账跳过: cleanup_source={}, 内存群列表为空", source.as_str());
            return;
        }

        // 已解散（status=2）的群可能由旧版本「群资料落库」残留，按群失效统一清理：
        // 群资料、成员缓存与会话一起删，会话删除仍走 ConversationService 并广播事件。
        let dismissed: Vec<String> = groups
            .iter()
            .filter(|g| g.status == group_status::DISMISSED)
            .map(|g| g.group_id.clone())
            .collect();
        if !dismissed.is_empty() {
            // 一次对账可能清掉多个已解散群：日志聚合为一行，避免刷屏
            info!(
                "已解散群对齐本地状态: cleanup_source={}, count={}, groups={}",
                source.as_str(),
                dismissed.len(),
                dismissed.join(",")
            );
        }
        for group_id in &dismissed {
            self.remove_local_group_state(group_id, source).await;
        }

        let valid_group_ids: Vec<String> = self
            .groups
            .read()
            .await
            .iter()
            .filter(|g| g.status != group_status::DISMISSED)
            .map(|g| g.group_id.clone())
            .collect();
        match conversation_service.reconcile_group_conversations(&valid_group_ids, source).await {
            Ok(removed) if removed > 0 => info!("群会话对账完成: cleanup_source={}, removed={}", source.as_str(), removed),
            Ok(_) => {}
            Err(e) => warn!("群会话对账失败: cleanup_source={}, err={}", source.as_str(), e),
        }
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

        // 以服务端最新资料为准刷新内存缓存并落库（含群名），
        // 否则会话列表/群设置页仍显示本地旧的群名。
        match self.get_groups_info(vec![updates.group_id.clone()]).await {
            Ok(groups) => {
                let mut cache = self.groups.write().await;
                for group in groups {
                    match cache.iter_mut().find(|g| g.group_id == group.group_id) {
                        Some(existing) => *existing = group,
                        None => cache.push(group),
                    }
                }
            }
            Err(e) => warn!("设置群信息后刷新本地群资料失败: group={}, err={}", updates.group_id, e),
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
            members: vec![crate::infra::http::group::SetGroupMemberInfoItem {
                group_id: updates.group_id.clone(),
                user_id: updates.user_id.clone(),
                nickname: updates.nickname,
                face_url: updates.face_url,
                role_level: updates.role_level.map(denormalize_role_level),
                ex: updates.ex,
            }],
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
        // 只有群主能转让，oldOwnerUserID 取当前登录用户（服务端要求该字段非空）。
        let old_owner_user_id = self.user_id.get().await;
        self.api.transfer_group_owner(&group_id, &old_owner_user_id, &new_owner_user_id).await?;
        if let Err(e) = self.sync_groups().await {
            tracing::warn!("转让群主后同步群组列表失败: {}", e);
        }
        // 本地角色随之变化（我 → 成员、对方 → 群主），刷新本地群资料。
        if let Ok(groups) = self.get_groups_info(vec![group_id.clone()]).await {
            let mut cache = self.groups.write().await;
            for group in groups {
                match cache.iter_mut().find(|g| g.group_id == group.group_id) {
                    Some(existing) => *existing = group,
                    None => cache.push(group),
                }
            }
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
        role_level: normalize_role_level(s.role_level),
        join_time: s.join_time,
        join_source: s.join_source.to_string(),
        mute_end_time: s.mute_end_time,
    }
}

/// 服务端角色等级：100=群主、60=管理员、20=普通成员；
/// 客户端领域模型统一为 3/2/1，供 UI 判断权限。
fn normalize_role_level(raw: i32) -> i32 {
    match raw {
        100 => 3,
        60 => 2,
        20 => 1,
        value @ 1..=3 => value,
        _ => 1,
    }
}

/// 客户端角色 3/2/1 -> 服务端 100/60/20。
///
/// 服务端 `set_group_member_info` 只接受 100/60/20，直接传 2 会返回
/// `ArgsError`。已是服务端值时保持原值，便于复用。
fn denormalize_role_level(level: i32) -> i32 {
    match level {
        3 => 100,
        2 => 60,
        1 => 20,
        value @ (20 | 60 | 100) => value,
        _ => 20,
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
    use crate::core::conversation::service::ConversationService;
    use crate::core::event::events::conversation::ConversationEvent;
    use crate::core::event::hub::EventHub;

    /// 只关心「增量同步返回 delete=[...]」的服务端桩；其余接口不该被调用
    struct IncrementalDeleteGroupApi {
        deleted_group_ids: Vec<String>,
        inserted_groups: Vec<ServerGroupInfo>,
    }

    #[async_trait::async_trait]
    impl GroupServerApi for IncrementalDeleteGroupApi {
        async fn get_incremental_join_group(&self, _req: &GetIncrementalJoinGroupReq) -> Result<GetIncrementalJoinGroupResp> {
            Ok(GetIncrementalJoinGroupResp {
                version: 2,
                version_id: "v2".to_string(),
                full: false,
                delete: self.deleted_group_ids.clone(),
                insert: self.inserted_groups.clone(),
                update: Vec::new(),
                sort_version: 0,
            })
        }
        async fn get_joined_group_list(&self, _req: &GetJoinedGroupListReq) -> Result<GetJoinedGroupListResp> {
            unimplemented!("本用例只走增量同步删除分支")
        }
        async fn get_groups_info(&self, _req: &GetGroupsInfoReq) -> Result<GetGroupsInfoResp> {
            unimplemented!()
        }
        async fn create_group(&self, _req: &CreateGroupReq) -> Result<CreateGroupResp> {
            unimplemented!()
        }
        async fn join_group(&self, _req: &JoinGroupReq) -> Result<()> {
            unimplemented!()
        }
        async fn quit_group(&self, _req: &QuitGroupReq) -> Result<()> {
            unimplemented!()
        }
        async fn dismiss_group(&self, _req: &DismissGroupReq) -> Result<()> {
            unimplemented!()
        }
        async fn set_group_info(&self, _req: &SetGroupInfoReq) -> Result<()> {
            unimplemented!()
        }
        async fn get_group_member_list(&self, _req: &GetGroupMemberListReq) -> Result<GetGroupMemberListResp> {
            unimplemented!()
        }
        async fn get_group_members_info(&self, _req: &GetGroupMembersInfoReq) -> Result<GetGroupMembersInfoResp> {
            unimplemented!()
        }
        async fn kick_group_member(&self, _req: &KickGroupMemberReq) -> Result<()> {
            unimplemented!()
        }
        async fn invite_user_to_group(&self, _req: &InviteUserToGroupReq) -> Result<()> {
            unimplemented!()
        }
        async fn set_group_member_info(&self, _req: &SetGroupMemberInfoReq) -> Result<()> {
            unimplemented!()
        }
        async fn get_group_application_list(&self, _req: &GetGroupApplicationListReq) -> Result<GetGroupApplicationListResp> {
            unimplemented!()
        }
        async fn get_recv_group_application_list(&self, _req: &GetGroupApplicationListReq) -> Result<GetGroupApplicationListResp> {
            unimplemented!()
        }
        async fn get_send_group_application_list(&self, _req: &GetUserReqApplicationListReq) -> Result<GetGroupApplicationListResp> {
            unimplemented!()
        }
        async fn get_group_application_unhandled_count(&self, _user_id: &str) -> Result<i32> {
            unimplemented!()
        }
        async fn accept_group_application(&self, _req: &AcceptGroupApplicationReq) -> Result<()> {
            unimplemented!()
        }
        async fn refuse_group_application(&self, _req: &RefuseGroupApplicationReq) -> Result<()> {
            unimplemented!()
        }
        async fn transfer_group_owner(&self, _group_id: &str, _old_owner_user_id: &str, _new_owner_user_id: &str) -> Result<()> {
            unimplemented!()
        }
        async fn mute_group(&self, _group_id: &str, _is_mute: bool) -> Result<()> {
            unimplemented!()
        }
        async fn mute_group_member(&self, _group_id: &str, _user_id: &str, _muted_seconds: i64) -> Result<()> {
            unimplemented!()
        }
    }

    fn local_group(group_id: &str) -> LocalGroup {
        LocalGroup {
            group_id: group_id.to_string(),
            name: format!("群 {}", group_id),
            ..Default::default()
        }
    }

    fn group_conversation(group_id: &str) -> LocalConversation {
        LocalConversation {
            conversation_id: format!("sg_{}", group_id),
            conversation_type: 3,
            group_id: group_id.to_string(),
            show_name: format!("群 {}", group_id),
            ..Default::default()
        }
    }

    fn server_group(group_id: &str) -> ServerGroupInfo {
        ServerGroupInfo {
            group_id: group_id.to_string(),
            group_name: format!("群 {}", group_id),
            face_url: String::new(),
            notification: String::new(),
            introduction: String::new(),
            owner_user_id: "owner_1".to_string(),
            create_time: 1000,
            member_count: 2,
            status: group_status::OK,
            creator_user_id: "owner_1".to_string(),
            group_type: 2,
            ex: String::new(),
        }
    }

    /// 增量同步删除分支：群资料与会话都要清理，且会话删除只广播一次（走 ConversationService）
    #[tokio::test]
    async fn test_sync_incremental_delete_cleans_group_conversation_once() {
        let pool = crate::infra::db::pool::create_pool_memory().await.unwrap();
        let repositories = Repositories::new(&pool);
        let hub = EventHub::new();
        let mut conv_rx = hub.take_conv_rx().unwrap();
        let conversation_service = Arc::new(ConversationService::new(repositories.clone(), hub.clone()));
        let service = GroupService::new(
            Arc::new(IncrementalDeleteGroupApi { deleted_group_ids: vec!["group_1".to_string()], inserted_groups: vec![] }),
            repositories.clone(),
            UserId::new("test_user"),
            hub.clone(),
        )
        .with_conversation_service(conversation_service.clone());

        // 预置：本地群资料 + 该群会话（服务端解散后两者都要被清掉）
        repositories.group_repo.upsert_group(&local_group("group_1")).await.unwrap();
        conversation_service.upsert_conversation(group_conversation("group_1")).await.unwrap();
        let _ = conv_rx.try_recv();

        service.sync_groups_incremental().await.unwrap();

        assert!(repositories.group_repo.get_group("group_1").await.unwrap().is_none(), "群资料必须清理");
        assert!(conversation_service.get_conversation("sg_group_1").await.unwrap().is_none(), "群失效后本地会话必须清理");
        match conv_rx.try_recv().expect("应广播会话删除事件") {
            ConversationEvent::Deleted(ids) => assert_eq!(ids, vec!["sg_group_1".to_string()]),
            other => panic!("期望 Deleted 事件，实际 {:?}", other.as_str()),
        }
        assert!(conv_rx.try_recv().is_err(), "删除分支与对账不应重复广播同一条会话删除");
    }

    /// 增量同步新增群时补建本地会话（覆盖「群通知丢失/离线补拉失败」的成员端），重复执行幂等。
    #[tokio::test]
    async fn test_sync_incremental_insert_creates_group_conversation() {
        let pool = crate::infra::db::pool::create_pool_memory().await.unwrap();
        let repositories = Repositories::new(&pool);
        let hub = EventHub::new();
        let mut conv_rx = hub.take_conv_rx().unwrap();
        let conversation_service = Arc::new(ConversationService::new(repositories.clone(), hub.clone()));
        let service = GroupService::new(
            Arc::new(IncrementalDeleteGroupApi {
                deleted_group_ids: vec![],
                inserted_groups: vec![server_group("group_new")],
            }),
            repositories.clone(),
            UserId::new("test_user"),
            hub.clone(),
        )
        .with_conversation_service(conversation_service.clone());

        service.sync_groups_incremental().await.unwrap();

        let conv = conversation_service
            .get_conversation("sg_group_new")
            .await
            .unwrap()
            .expect("无消息新群也应有本地会话");
        assert_eq!(conv.conversation_type, 3);
        assert_eq!(conv.group_id, "group_new");
        assert!(conv.latest_msg.is_empty(), "无消息新群不应伪造消息预览");
        match conv_rx.try_recv().expect("应广播会话新增事件") {
            ConversationEvent::Changed(list) => assert_eq!(list.len(), 1),
            other => panic!("期望 Changed 事件，实际 {:?}", other.as_str()),
        }

        // 同一个新增再来一次：会话已存在，不应重复广播
        service.sync_groups_incremental().await.unwrap();
        assert!(conv_rx.try_recv().is_err(), "会话已存在时不应再次广播");
    }

    /// 内存群列表为空（群同步未完成）时不做对账：否则会把所有 `sg_*` 会话误判成孤儿删掉。
    #[tokio::test]
    async fn test_reconcile_skips_when_group_list_empty() {
        let pool = crate::infra::db::pool::create_pool_memory().await.unwrap();
        let repositories = Repositories::new(&pool);
        let hub = EventHub::new();
        let mut conv_rx = hub.take_conv_rx().unwrap();
        let conversation_service = Arc::new(ConversationService::new(repositories.clone(), hub.clone()));
        let service = GroupService::new(
            Arc::new(IncrementalDeleteGroupApi { deleted_group_ids: vec![], inserted_groups: vec![] }),
            repositories.clone(),
            UserId::new("test_user"),
            hub.clone(),
        )
        .with_conversation_service(conversation_service.clone());

        conversation_service.upsert_conversation(group_conversation("group_1")).await.unwrap();
        let _ = conv_rx.try_recv();

        service.reconcile_group_conversations(CleanupSource::Sync).await;

        assert!(
            conversation_service.get_conversation("sg_group_1").await.unwrap().is_some(),
            "群列表为空时对账必须跳过，不能删掉群会话"
        );
        assert!(conv_rx.try_recv().is_err(), "跳过对账时不应广播删除事件");
    }

    /// 已解散（status=2）的群即便残留在内存/群表里，也要清群资料、成员缓存与会话。
    /// 现实中它来自旧版本「群资料落库」：`get_groups_info` 会把 status=2 的群写回群表。
    #[tokio::test]
    async fn test_reconcile_cleans_dismissed_group_left_in_local_state() {
        let pool = crate::infra::db::pool::create_pool_memory().await.unwrap();
        let repositories = Repositories::new(&pool);
        let hub = EventHub::new();
        let mut conv_rx = hub.take_conv_rx().unwrap();
        let conversation_service = Arc::new(ConversationService::new(repositories.clone(), hub.clone()));
        let service = GroupService::new(
            Arc::new(IncrementalDeleteGroupApi { deleted_group_ids: vec![], inserted_groups: vec![] }),
            repositories.clone(),
            UserId::new("test_user"),
            hub.clone(),
        )
        .with_conversation_service(conversation_service.clone());

        repositories.group_repo.upsert_group(&local_group("group_dead")).await.unwrap();
        conversation_service.upsert_conversation(group_conversation("group_dead")).await.unwrap();
        let _ = conv_rx.try_recv();
        service.groups.write().await.push(GroupInfo {
            group_id: "group_dead".to_string(),
            group_name: "已解散群".to_string(),
            face_url: String::new(),
            introduction: String::new(),
            notification: String::new(),
            owner_user_id: String::new(),
            create_time: 0,
            member_count: 0,
            status: group_status::DISMISSED,
        });

        service.reconcile_group_conversations(CleanupSource::Sync).await;

        assert!(repositories.group_repo.get_group("group_dead").await.unwrap().is_none(), "已解散群的群资料必须清理");
        assert!(conversation_service.get_conversation("sg_group_dead").await.unwrap().is_none(), "已解散群的会话必须清理");
        assert!(
            service.groups.read().await.iter().all(|g| g.group_id != "group_dead"),
            "内存群列表不应残留已解散群"
        );
        match conv_rx.try_recv().expect("应广播会话删除事件") {
            ConversationEvent::Deleted(ids) => assert_eq!(ids, vec!["sg_group_dead".to_string()]),
            other => panic!("期望 Deleted 事件，实际 {:?}", other.as_str()),
        }
    }

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
            role_level: 100,
            join_time: 1234567890,
            join_source: 1,
            operator_user_id: "owner_1".to_string(),
            ex: String::new(),
            mute_end_time: 1793000000000,
        };

        let domain = server_to_group_member(server);
        assert_eq!(domain.group_id, "group_123");
        assert_eq!(domain.user_id, "user_456");
        assert_eq!(domain.nickname, "Test Member");
        assert_eq!(domain.role_level, 3);
        assert_eq!(domain.mute_end_time, 1793000000000);
    }

    #[test]
    fn test_normalize_role_level() {
        assert_eq!(normalize_role_level(100), 3);
        assert_eq!(normalize_role_level(60), 2);
        assert_eq!(normalize_role_level(20), 1);
        // 已是客户端等级时保持原值
        assert_eq!(normalize_role_level(3), 3);
        assert_eq!(normalize_role_level(2), 2);
        assert_eq!(normalize_role_level(1), 1);
    }

    #[test]
    fn test_denormalize_role_level() {
        assert_eq!(denormalize_role_level(3), 100);
        assert_eq!(denormalize_role_level(2), 60);
        assert_eq!(denormalize_role_level(1), 20);
        // 已是服务端值时保持原值
        assert_eq!(denormalize_role_level(100), 100);
        assert_eq!(denormalize_role_level(60), 60);
        assert_eq!(denormalize_role_level(20), 20);
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
