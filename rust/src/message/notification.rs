//! 通知消息处理器
//!
//! 对齐 Go SDK 的 DoNotification 机制，按 content_type 范围路由通知消息到对应模块。
//! 好友通知 (1200-1299) → friend 模块
//! 用户通知 (1301-1399) → user 模块
//! 群组通知 (1500-1599) → group 模块
//!
//! 重要：服务端 MsgData.content 是 JSON 字节（非 protobuf），
//! 对齐 Go SDK `UnmarshalNotificationElem`：先解析外层 NotificationElem，
//! 再解析内层 detail 到目标类型。

use crate::domain::constant::notification_type;
use crate::conversation::syncer::ConversationSyncer;
use crate::event::events::friend::{FriendEvent, FriendListener, FriendListenerExt};
use crate::event::events::group::{GroupEvent, GroupListener, GroupListenerExt};
use crate::event::events::user::{UserEvent, UserListener, UserListenerExt};
use crate::friend::service::FriendService;
use crate::group::service::GroupService;
use crate::message::MessageProcessor;
use crate::domain::model::UserId;
use crate::user::service::UserService;
use openim_protocol::sdkws::MsgData;
use std::sync::Arc;
use tracing::{debug, info, warn};

use crate::domain::model::notification_types::*;

// NotificationHandler
// ============================================================

#[allow(dead_code)]
pub struct NotificationHandler {
    friend_manager: Arc<FriendService>,
    group_manager: Arc<GroupService>,
    user_manager: Arc<UserService>,
    conversation_syncer: Arc<ConversationSyncer>,
    message_processor: Arc<MessageProcessor>,
    friend_listener: Arc<dyn FriendListener>,
    group_listener: Arc<dyn GroupListener>,
    user_listener: Arc<dyn UserListener>,
    user_id: UserId,
}

impl NotificationHandler {
    pub fn new(
        friend_manager: Arc<FriendService>,
        group_manager: Arc<GroupService>,
        user_manager: Arc<UserService>,
        conversation_syncer: Arc<ConversationSyncer>,
        message_processor: Arc<MessageProcessor>,
        friend_listener: Arc<dyn FriendListener>,
        group_listener: Arc<dyn GroupListener>,
        user_listener: Arc<dyn UserListener>,
        user_id: UserId,
    ) -> Self {
        Self {
            friend_manager,
            group_manager,
            user_manager,
            conversation_syncer,
            message_processor,
            friend_listener,
            group_listener,
            user_listener,
            user_id,
        }
    }

    /// 处理通知消息列表（对齐 Go SDK Work() 方法的 CmdNotification 路由）
    pub async fn handle_notifications(&self, msgs: &[MsgData]) {
        for msg in msgs {
            if let Err(e) = self.handle_single_notification(msg).await {
                warn!("[NOTIFY] 处理失败: content_type={} err={}", msg.content_type, e);
            }
        }
    }

    async fn handle_single_notification(&self, msg: &MsgData) -> anyhow::Result<()> {
        let ct = msg.content_type;
        match ct {
            // ========== 好友通知 (1200-1299) ==========
            notification_type::FRIEND_APPLICATION_APPROVED => {
                self.handle_friend_application_approved(&msg.content).await?;
            }
            notification_type::FRIEND_APPLICATION_REJECTED => {
                self.handle_friend_application_rejected(&msg.content).await?;
            }
            notification_type::FRIEND_APPLICATION => {
                self.handle_friend_application_added(&msg.content).await?;
            }
            notification_type::FRIEND_ADDED | notification_type::FRIEND_REMARK_SET | notification_type::FRIEND_INFO_UPDATED | notification_type::FRIENDS_INFO_UPDATE => {
                if let Err(e) = self.friend_manager.sync_friends_incremental().await {
                    warn!("[NOTIFY] 增量同步好友列表失败: {}", e);
                }
            }
            notification_type::FRIEND_DELETED => {
                if let Err(e) = self.friend_manager.sync_friends_incremental().await {
                    warn!("[NOTIFY] 增量同步好友列表失败: {}", e);
                }
            }
            notification_type::BLACK_ADDED => {
                if let Err(e) = self.friend_manager.sync_blacks().await {
                    warn!("[NOTIFY] 同步黑名单失败: {}", e);
                }
            }
            notification_type::BLACK_DELETED => {
                if let Err(e) = self.friend_manager.sync_blacks().await {
                    warn!("[NOTIFY] 同步黑名单失败: {}", e);
                }
            }

            // ========== 用户通知 (1301-1399) ==========
            notification_type::USER_INFO_UPDATED => {
                self.handle_user_info_updated(&msg.content).await?;
            }

            // ========== 群组通知 (1500-1599) ==========
            notification_type::GROUP_CREATED
            | notification_type::GROUP_INFO_SET
            | notification_type::GROUP_OWNER_TRANSFERRED
            | notification_type::GROUP_MEMBER_MUTED
            | notification_type::GROUP_MEMBER_CANCEL_MUTED
            | notification_type::GROUP_MUTED
            | notification_type::GROUP_CANCEL_MUTED
            | notification_type::GROUP_MEMBER_SET_TO_ADMIN
            | notification_type::GROUP_MEMBER_SET_TO_ORDINARY_USER
            | notification_type::GROUP_INFO_SET_ANNOUNCEMENT
            | notification_type::GROUP_INFO_SET_NAME => {
                self.handle_group_info_changed(msg).await;
            }
            notification_type::GROUP_MEMBER_INFO_SET => {
                self.handle_group_member_info_changed(msg).await;
            }
            notification_type::MEMBER_QUIT | notification_type::MEMBER_KICKED => {
                self.handle_group_member_deleted(msg).await;
            }
            notification_type::MEMBER_INVITED | notification_type::MEMBER_ENTER => {
                self.handle_group_member_added(msg).await;
            }
            notification_type::GROUP_DISMISSED => {
                self.handle_group_dismissed(msg).await;
            }
            notification_type::JOIN_GROUP_APPLICATION => {
                self.handle_group_application_added(&msg.content).await?;
            }
            notification_type::GROUP_APPLICATION_ACCEPTED => {
                self.handle_group_application_accepted(&msg.content).await?;
            }
            notification_type::GROUP_APPLICATION_REJECTED => {
                self.handle_group_application_rejected(&msg.content).await?;
            }

            // ========== 会话通知 (1300, 1701) ==========
            notification_type::CONVERSATION_CHANGE => {
                if let Err(e) = self.conversation_syncer.sync_incremental_with_lock().await {
                    warn!("[NOTIFY] 增量同步会话列表失败: {}", e);
                }
            }
            notification_type::CONVERSATION_PRIVATE_CHAT => {
                if let Err(e) = self.conversation_syncer.sync_incremental_with_lock().await {
                    warn!("[NOTIFY] 增量同步会话列表失败: {}", e);
                }
            }

            // ========== 消息撤回通知 (2101) ==========
            notification_type::REVOKE => {
                self.handle_revoke_notification(&msg.content).await?;
            }

            // ========== 已读回执通知 (2200) ==========
            notification_type::HAS_READ_RECEIPT => {
                self.message_processor.handle_read_receipt_from_msg_data(msg).await?;
            }

            _ => {
                debug!("[NOTIFY] 未处理: content_type={}", ct);
            }
        }
        Ok(())
    }

    /// 处理消息撤回通知（2101）
    /// 对齐 Go SDK do_revoke_msg: UnmarshalNotificationElem → RevokeMsgTips (JSON)
    async fn handle_revoke_notification(&self, content: &[u8]) -> anyhow::Result<()> {
        // 记录原始通知内容用于调试
        let raw_str = String::from_utf8_lossy(content);
        info!("[REVOKE-DEBUG-RAW] 原始通知内容前200字: {}", &raw_str[..raw_str.len().min(200)]);
        let tips: RevokeMsgTipsJson = unmarshal_notification_elem(content)?;
        info!(
            "[REVOKE-DEBUG-PARSED] 解析结果: revoker_nickname='{}', revoker_role={}, user_id='{}', seq={}, conv='{}'",
            tips.revoker_nickname, tips.revoker_role, tips.revoker_user_id, tips.seq, tips.conversation_id
        );

        // 委托给 MessageProcessor 处理（构造 protobuf 类型兼容的结构）
        let revoke_tips = openim_protocol::sdkws::RevokeMsgTips {
            revoker_user_id: tips.revoker_user_id,
            client_msg_id: tips.client_msg_id,
            revoke_time: tips.revoke_time,
            sesstion_type: tips.sesstion_type,
            seq: tips.seq,
            conversation_id: tips.conversation_id,
            is_admin_revoke: tips.is_admin_revoke,
        };

        if let Err(e) = self.message_processor.handle_revoke_notification(&revoke_tips, &tips.revoker_nickname, tips.revoker_role).await {
            warn!("[NOTIFY] 处理撤回通知失败: {}", e);
            return Err(anyhow::anyhow!("处理撤回通知失败: {}", e));
        }

        Ok(())
    }

    // ========== 好友通知处理 ==========

    /// 1201 - 好友申请被接受
    async fn handle_friend_application_approved(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips: FriendApplicationApprovedTipsJson = unmarshal_notification_elem(content)?;
        let request = &tips.request;

        let application_json = serde_json::json!({
            "userId": request.from_user_id,
            "nickname": request.from_nickname,
            "faceUrl": request.from_face_url,
            "handleResult": request.handle_result,
            "handleMsg": tips.handle_msg,
            "createTime": request.create_time,
        })
        .to_string();

        if let Err(e) = self.friend_manager.sync_friends_incremental().await {
            warn!("[NOTIFY] 接受好友申请后增量同步好友列表失败: {}", e);
        }

        self.friend_listener.emit(FriendEvent::ApplicationAccepted(application_json));

        Ok(())
    }

    /// 1202 - 好友申请被拒绝
    async fn handle_friend_application_rejected(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips: FriendApplicationRejectedTipsJson = unmarshal_notification_elem(content)?;
        let request = &tips.request;

        let application_json = serde_json::json!({
            "userId": request.from_user_id,
            "nickname": request.from_nickname,
            "faceUrl": request.from_face_url,
            "handleResult": request.handle_result,
            "handleMsg": tips.handle_msg,
            "createTime": request.create_time,
        })
        .to_string();

        self.friend_listener.emit(FriendEvent::ApplicationRejected(application_json));

        Ok(())
    }

    /// 1203 - 收到好友申请
    async fn handle_friend_application_added(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips: FriendApplicationTipsJson = unmarshal_notification_elem(content)?;
        let request = &tips.request;

        let application_json = serde_json::json!({
            "userId": request.from_user_id,
            "nickname": request.from_nickname,
            "faceUrl": request.from_face_url,
            "handleResult": request.handle_result,
            "reqMsg": request.req_msg,
            "createTime": request.create_time,
        })
        .to_string();

        self.friend_listener.emit(FriendEvent::ApplicationAdded(application_json));

        Ok(())
    }

    // ========== 用户通知处理 ==========

    /// 1303 - 用户信息更新
    async fn handle_user_info_updated(&self, content: &[u8]) -> anyhow::Result<()> {
        let user_info: UserInfoJson = unmarshal_notification_elem(content)?;

        self.user_listener.emit(UserEvent::UserInfoUpdated {
            user: crate::domain::model::user::UserInfo {
                user_id: user_info.user_id,
                nickname: user_info.nickname,
                face_url: user_info.face_url,
                gender: 0,
                telephone: String::new(),
                email: String::new(),
                remark: user_info.ex,
                global_recv_msg_opt: user_info.global_recv_msg_opt,
            },
        });

        Ok(())
    }

    // ========== 群组通知处理 ==========

    /// 1503 - 收到群组申请
    async fn handle_group_application_added(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips: JoinGroupApplicationTipsJson = unmarshal_notification_elem(content)?;
        let request = &tips.request;
        let group_id = tips
            .group
            .as_ref()
            .map(|g| g.group_id.clone())
            .or_else(|| request.group_info.as_ref().map(|g| g.group_id.clone()))
            .unwrap_or_default();

        let application_json = serde_json::json!({
            "groupId": group_id,
            "userId": request.user_info.as_ref().map(|u| u.user_id.clone()).unwrap_or_default(),
            "nickname": request.user_info.as_ref().map(|u| u.nickname.clone()).unwrap_or_default(),
            "faceUrl": request.user_info.as_ref().map(|u| u.face_url.clone()).unwrap_or_default(),
            "handleResult": request.handle_result,
            "reason": request.req_msg,
        })
        .to_string();

        self.group_listener.emit(GroupEvent::ApplicationAdded(application_json));

        Ok(())
    }

    /// 1505 - 群组申请被接受
    async fn handle_group_application_accepted(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips: GroupApplicationAcceptedTipsJson = unmarshal_notification_elem(content)?;
        let request = &tips.request;
        let group_id = tips
            .group
            .as_ref()
            .map(|g| g.group_id.clone())
            .or_else(|| request.group_info.as_ref().map(|g| g.group_id.clone()))
            .unwrap_or_default();

        if let Err(e) = self.group_manager.sync_groups_incremental().await {
            warn!("[NOTIFY] 接受群组申请后增量同步群组列表失败: {}", e);
        }

        let application_json = serde_json::json!({
            "groupId": group_id,
            "userId": request.user_info.as_ref().map(|u| u.user_id.clone()).unwrap_or_default(),
            "nickname": request.user_info.as_ref().map(|u| u.nickname.clone()).unwrap_or_default(),
            "faceUrl": request.user_info.as_ref().map(|u| u.face_url.clone()).unwrap_or_default(),
            "handleResult": request.handle_result,
            "handleMsg": tips.handle_msg,
        })
        .to_string();

        self.group_listener.emit(GroupEvent::ApplicationApproved(application_json));

        Ok(())
    }

    /// 1506 - 群组申请被拒绝
    async fn handle_group_application_rejected(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips: GroupApplicationRejectedTipsJson = unmarshal_notification_elem(content)?;
        let request = &tips.request;
        let group_id = tips
            .group
            .as_ref()
            .map(|g| g.group_id.clone())
            .or_else(|| request.group_info.as_ref().map(|g| g.group_id.clone()))
            .unwrap_or_default();

        let application_json = serde_json::json!({
            "groupId": group_id,
            "userId": request.user_info.as_ref().map(|u| u.user_id.clone()).unwrap_or_default(),
            "nickname": request.user_info.as_ref().map(|u| u.nickname.clone()).unwrap_or_default(),
            "faceUrl": request.user_info.as_ref().map(|u| u.face_url.clone()).unwrap_or_default(),
            "handleResult": request.handle_result,
            "handleMsg": tips.handle_msg,
        })
        .to_string();

        self.group_listener.emit(GroupEvent::ApplicationRejected(application_json));

        Ok(())
    }

    async fn handle_group_info_changed(&self, msg: &MsgData) {
        let group_id = self.parse_group_id(&msg.content);
        if let Err(e) = self.group_manager.sync_groups_incremental().await {
            warn!("[NOTIFY] 增量同步群组列表失败: {}", e);
        }
        if !group_id.is_empty() {
            if let Ok(groups) = self.group_manager.get_groups_info(vec![group_id]).await {
                if let Some(group) = groups.into_iter().next() {
                    self.group_listener.emit(GroupEvent::GroupInfoChanged(group));
                }
            }
        }
    }

    async fn handle_group_member_added(&self, msg: &MsgData) {
        let detail: GroupMemberJoinedTipsJson = unmarshal_notification_elem(&msg.content).unwrap_or_default();
        let group_id = detail.group.as_ref().map(|g| g.group_id.clone()).unwrap_or_default();
        if let Err(e) = self.group_manager.sync_groups_incremental().await {
            warn!("[NOTIFY] 增量同步群组列表失败: {}", e);
        }
        if !group_id.is_empty() {
            let user = detail.invited_user_list.first().or(detail.entrant_user.as_ref());
            if let Some(user) = user {
                self.group_listener.emit(GroupEvent::MemberAdded(self.group_member(group_id, user)));
            }
        }
    }

    async fn handle_group_member_deleted(&self, msg: &MsgData) {
        let detail: GroupMemberRemovedTipsJson = unmarshal_notification_elem(&msg.content).unwrap_or_default();
        let group_id = detail.group.as_ref().map(|g| g.group_id.clone()).unwrap_or_default();
        if let Err(e) = self.group_manager.sync_groups_incremental().await {
            warn!("[NOTIFY] 增量同步群组列表失败: {}", e);
        }
        if !group_id.is_empty() {
            let user = detail.quit_user.as_ref().or_else(|| detail.kicked_user_list.first());
            if let Some(user) = user {
                self.group_listener.emit(GroupEvent::MemberDeleted(self.group_member(group_id, user)));
            }
        }
    }

    async fn handle_group_member_info_changed(&self, msg: &MsgData) {
        let detail: GroupMemberInfoSetTipsJson = unmarshal_notification_elem(&msg.content).unwrap_or_default();
        let group_id = detail.group.as_ref().map(|g| g.group_id.clone()).unwrap_or_default();
        if let Err(e) = self.group_manager.sync_groups_incremental().await {
            warn!("[NOTIFY] 增量同步群组列表失败: {}", e);
        }
        if !group_id.is_empty() {
            if let Some(user) = &detail.changed_user {
                self.group_listener.emit(GroupEvent::MemberInfoChanged(self.group_member(group_id, user)));
            }
        }
    }

    fn group_member(&self, group_id: String, user: &PublicUserInfoJson) -> crate::domain::model::group::GroupMember {
        crate::domain::model::group::GroupMember {
            group_id,
            user_id: user.user_id.clone(),
            nickname: user.nickname.clone(),
            face_url: user.face_url.clone(),
            role_level: 0,
            join_time: 0,
            join_source: String::new(),
        }
    }

    async fn handle_group_dismissed(&self, msg: &MsgData) {
        let group_id = self.parse_group_id(&msg.content);
        if let Err(e) = self.group_manager.sync_groups_incremental().await {
            warn!("[NOTIFY] 增量同步群组列表失败: {}", e);
        }
        if !group_id.is_empty() {
            if let Ok(groups) = self.group_manager.get_groups_info(vec![group_id]).await {
                if let Some(group) = groups.into_iter().next() {
                    self.group_listener.emit(GroupEvent::Dismissed(group));
                }
            }
        }
    }

    fn parse_group_id(&self, content: &[u8]) -> String {
        unmarshal_notification_elem::<GroupChangeInfoJson>(content).map(|t| t.effective_group_id()).unwrap_or_default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::client::context::Repositories;
    use crate::infra::db::pool::create_pool_memory;
    use crate::infra::db::*;

    use crate::event::hub::EventHub;
    use crate::event::test_util::*;
    use crate::infra::http::client::HttpApiClient;
    use crate::infra::http::conversation::ConversationServerApi;
    use crate::infra::http::friend::FriendServerApi;
    use crate::infra::http::group::GroupServerApi;

    use crate::domain::model::UserId;
    use std::sync::Arc;

    fn make_repositories(pool: sqlx::SqlitePool) -> Arc<Repositories> {
        Arc::new(Repositories {
            message_repo: Arc::new(MessageDao::new(pool.clone())),
            conversation_repo: Arc::new(ConversationDao::new(pool.clone())),
            friend_repo: Arc::new(FriendDao::new(pool.clone())),
            user_repo: Arc::new(UserDao::new(pool.clone())),
            group_repo: Arc::new(GroupDao::new(pool.clone())),
            sync_version_repo: Arc::new(SyncVersionDao::new(pool.clone())),
            notification_seq_repo: Arc::new(NotificationSeqDao::new(pool.clone())),
            sending_message_repo: Arc::new(SendingMessageDao::new(pool)),
        })
    }

    fn make_http_client() -> Arc<HttpApiClient> {
        Arc::new(HttpApiClient::new("http://localhost:10002".to_string(), "test_token".to_string(), "test_op".to_string()))
    }

    #[tokio::test]
    async fn test_notification_handler_fallback_unhandled() {
        let pool = create_pool_memory().await.unwrap();
        let repos = make_repositories(pool);
        let http = make_http_client();
        let hub = EventHub::new();
        let user_id = UserId::new("test_user");

        let friend_api: Arc<dyn FriendServerApi> = Arc::new(crate::infra::http::friend_api::HttpFriendApi::new(http.clone()));
        let friend_service = Arc::new(FriendService::new(friend_api, repos.clone(), user_id.clone(), hub.clone()));

        let group_api: Arc<dyn GroupServerApi> = Arc::new(crate::infra::http::group_api::HttpGroupApi::new(http.clone()));
        let group_service = Arc::new(GroupService::new(group_api, repos.clone(), user_id.clone(), hub.clone()));

        let user_service = Arc::new(UserService::new(Arc::new(crate::infra::http::user_api::HttpUserApi::new(http.clone())), hub.clone()));

        let conv_api: Arc<dyn ConversationServerApi> = Arc::new(crate::infra::http::conversation_api::HttpConversationApi::new(http.clone()));
        let syncer = Arc::new(ConversationSyncer::new_with_api(conv_api, repos.clone(), user_id.clone(), hub.clone()));

        let processor = Arc::new(MessageProcessor::new(repos.clone(), user_id.clone(), hub.clone(), hub.clone()));

        let handler = NotificationHandler::new(
            friend_service,
            group_service,
            user_service,
            syncer,
            processor,
            noop_friend_listener(),
            noop_group_listener(),
            noop_user_listener(),
            user_id,
        );

        // 未处理的通知类型不应 panic
        let msg = MsgData {
            content_type: 9999,
            content: br#"{"detail":"{\"key\":\"value\"}"}"#.to_vec(),
            ..Default::default()
        };
        handler.handle_single_notification(&msg).await.unwrap();
    }

    #[tokio::test]
    async fn test_notification_handler_empty_list() {
        let pool = create_pool_memory().await.unwrap();
        let repos = make_repositories(pool);
        let http = make_http_client();
        let hub = EventHub::new();
        let user_id = UserId::new("test_user");

        let friend_api: Arc<dyn FriendServerApi> = Arc::new(crate::infra::http::friend_api::HttpFriendApi::new(http.clone()));
        let friend_service = Arc::new(FriendService::new(friend_api, repos.clone(), user_id.clone(), hub.clone()));

        let group_api: Arc<dyn GroupServerApi> = Arc::new(crate::infra::http::group_api::HttpGroupApi::new(http.clone()));
        let group_service = Arc::new(GroupService::new(group_api, repos.clone(), user_id.clone(), hub.clone()));

        let user_service = Arc::new(UserService::new(Arc::new(crate::infra::http::user_api::HttpUserApi::new(http.clone())), hub.clone()));

        let conv_api: Arc<dyn ConversationServerApi> = Arc::new(crate::infra::http::conversation_api::HttpConversationApi::new(http.clone()));
        let syncer = Arc::new(ConversationSyncer::new_with_api(conv_api, repos.clone(), user_id.clone(), hub.clone()));

        let processor = Arc::new(MessageProcessor::new(repos.clone(), user_id.clone(), hub.clone(), hub.clone()));

        let handler = NotificationHandler::new(friend_service, group_service, user_service, syncer, processor, hub.clone(), hub.clone(), hub.clone(), user_id);

        handler.handle_notifications(&[]).await;
    }

    #[tokio::test]
    async fn test_notification_friend_deleted_triggers_sync() {
        let pool = create_pool_memory().await.unwrap();
        let hub = EventHub::new();
        let mut rx = hub.take_friend_rx().unwrap();
        let handler = make_handler_with_hub(pool, &hub);

        let msg = MsgData {
            content_type: crate::domain::constant::notification_type::FRIEND_DELETED,
            content: br#"{"detail":"{\"userID\":\"user_2\"}"}"#.to_vec(),
            ..Default::default()
        };
        handler.handle_single_notification(&msg).await.unwrap();

        // 对齐 Go：好友删除通知只触发增量同步，事件由同步器在拿到完整好友信息后发布
        assert!(rx.try_recv().is_err(), "通知本身不应直接发布 Deleted 事件");
    }

    #[tokio::test]
    async fn test_notification_group_member_added_dispatch() {
        let pool = create_pool_memory().await.unwrap();
        let hub = EventHub::new();
        let mut rx = hub.take_group_rx().unwrap();
        let handler = make_handler_with_hub(pool, &hub);

        let msg = MsgData {
            content_type: crate::domain::constant::notification_type::MEMBER_INVITED,
            content: br#"{"detail":"{\"group\":{\"groupID\":\"group_1\"},\"invitedUserList\":[{\"userID\":\"user_9\"}]}"}"#.to_vec(),
            ..Default::default()
        };
        handler.handle_single_notification(&msg).await.unwrap();

        let event = rx.try_recv().expect("应发布群成员加入事件");
        match event {
            GroupEvent::MemberAdded(member) => {
                assert_eq!(member.group_id, "group_1");
                assert_eq!(member.user_id, "user_9");
            }
            other => panic!("期望 MemberAdded，实际 {:?}", other),
        }
    }

    #[tokio::test]
    async fn test_notification_group_member_info_changed_dispatch() {
        let pool = create_pool_memory().await.unwrap();
        let hub = EventHub::new();
        let mut rx = hub.take_group_rx().unwrap();
        let handler = make_handler_with_hub(pool, &hub);

        let msg = MsgData {
            content_type: crate::domain::constant::notification_type::GROUP_MEMBER_INFO_SET,
            content: br#"{"detail":"{\"group\":{\"groupID\":\"group_1\"},\"changedUser\":{\"userID\":\"user_9\",\"nickname\":\"NewName\"}}"}"#.to_vec(),
            ..Default::default()
        };
        handler.handle_single_notification(&msg).await.unwrap();

        let event = rx.try_recv().expect("应发布群成员信息变更事件");
        match event {
            GroupEvent::MemberInfoChanged(member) => {
                assert_eq!(member.group_id, "group_1");
                assert_eq!(member.user_id, "user_9");
                assert_eq!(member.nickname, "NewName");
            }
            other => panic!("期望 MemberInfoChanged，实际 {:?}", other),
        }
    }

    // ========================================================================
    // 具体通知类型分发测试（通过 EventHub 断言事件路由）
    // ========================================================================

    /// 构造带 hub listener 的 handler（申请类/用户类通知不触发网络调用）
    fn make_handler_with_hub(pool: sqlx::SqlitePool, hub: &Arc<EventHub>) -> NotificationHandler {
        let repos = make_repositories(pool);
        let http = make_http_client();
        let user_id = UserId::new("test_user");

        let friend_api: Arc<dyn FriendServerApi> = Arc::new(crate::infra::http::friend_api::HttpFriendApi::new(http.clone()));
        let friend_service = Arc::new(FriendService::new(friend_api, repos.clone(), user_id.clone(), hub.clone()));

        let group_api: Arc<dyn GroupServerApi> = Arc::new(crate::infra::http::group_api::HttpGroupApi::new(http.clone()));
        let group_service = Arc::new(GroupService::new(group_api, repos.clone(), user_id.clone(), hub.clone()));

        let user_service = Arc::new(UserService::new(Arc::new(crate::infra::http::user_api::HttpUserApi::new(http.clone())), hub.clone()));

        let conv_api: Arc<dyn ConversationServerApi> = Arc::new(crate::infra::http::conversation_api::HttpConversationApi::new(http.clone()));
        let syncer = Arc::new(ConversationSyncer::new_with_api(conv_api, repos.clone(), user_id.clone(), hub.clone()));

        let processor = Arc::new(MessageProcessor::new(repos.clone(), user_id.clone(), hub.clone(), hub.clone()));

        NotificationHandler::new(friend_service, group_service, user_service, syncer, processor, hub.clone(), hub.clone(), hub.clone(), user_id)
    }

    #[tokio::test]
    async fn test_notification_user_info_updated_dispatch() {
        let pool = create_pool_memory().await.unwrap();
        let hub = EventHub::new();
        let mut user_rx = hub.take_user_rx().unwrap();
        let handler = make_handler_with_hub(pool, &hub);

        let detail = serde_json::json!({
            "userID": "user_1",
            "nickname": "新昵称",
            "faceURL": "http://avatar",
            "ex": "remark",
            "globalRecvMsgOpt": 1
        });
        let msg = MsgData {
            content_type: notification_type::USER_INFO_UPDATED,
            content: serde_json::json!({ "detail": detail.to_string() }).to_string().into_bytes(),
            ..Default::default()
        };

        handler.handle_single_notification(&msg).await.unwrap();

        match user_rx.try_recv().unwrap() {
            UserEvent::UserInfoUpdated { user } => {
                assert_eq!(user.user_id, "user_1");
                assert_eq!(user.nickname, "新昵称");
                assert_eq!(user.face_url, "http://avatar");
                assert_eq!(user.remark, "remark");
                assert_eq!(user.global_recv_msg_opt, 1);
            }
            other => panic!("期望 UserInfoUpdated，实际 {:?}", other),
        }
    }

    #[tokio::test]
    async fn test_notification_friend_application_added_dispatch() {
        let pool = create_pool_memory().await.unwrap();
        let hub = EventHub::new();
        let mut friend_rx = hub.take_friend_rx().unwrap();
        let handler = make_handler_with_hub(pool, &hub);

        let detail = serde_json::json!({
            "request": {
                "fromUserID": "user_a",
                "fromNickname": "Alice",
                "fromFaceURL": "http://face",
                "handleResult": 0,
                "reqMsg": "Hello!",
                "createTime": 1000
            }
        });
        let msg = MsgData {
            content_type: notification_type::FRIEND_APPLICATION,
            content: serde_json::json!({ "detail": detail.to_string() }).to_string().into_bytes(),
            ..Default::default()
        };

        handler.handle_single_notification(&msg).await.unwrap();

        match friend_rx.try_recv().unwrap() {
            FriendEvent::ApplicationAdded(json) => {
                let v: serde_json::Value = serde_json::from_str(&json).unwrap();
                assert_eq!(v["userId"], "user_a");
                assert_eq!(v["nickname"], "Alice");
                assert_eq!(v["faceUrl"], "http://face");
                assert_eq!(v["reqMsg"], "Hello!");
            }
            other => panic!("期望 ApplicationAdded，实际 {:?}", other),
        }
    }

    #[tokio::test]
    async fn test_notification_group_application_added_dispatch() {
        let pool = create_pool_memory().await.unwrap();
        let hub = EventHub::new();
        let mut group_rx = hub.take_group_rx().unwrap();
        let handler = make_handler_with_hub(pool, &hub);

        let detail = serde_json::json!({
            "request": {
                "groupInfo": { "groupID": "group_1" },
                "userInfo": { "userID": "user_a", "nickname": "Alice", "faceURL": "" },
                "handleResult": 0,
                "reqMsg": "Please add me"
            }
        });
        let msg = MsgData {
            content_type: notification_type::JOIN_GROUP_APPLICATION,
            content: serde_json::json!({ "detail": detail.to_string() }).to_string().into_bytes(),
            ..Default::default()
        };

        handler.handle_single_notification(&msg).await.unwrap();

        match group_rx.try_recv().unwrap() {
            GroupEvent::ApplicationAdded(json) => {
                let v: serde_json::Value = serde_json::from_str(&json).unwrap();
                assert_eq!(v["groupId"], "group_1");
                assert_eq!(v["userId"], "user_a");
                assert_eq!(v["nickname"], "Alice");
                assert_eq!(v["reason"], "Please add me");
            }
            other => panic!("期望 ApplicationAdded，实际 {:?}", other),
        }
    }

    #[tokio::test]
    async fn test_notification_revoke_dispatch() {
        let pool = create_pool_memory().await.unwrap();
        let repos = make_repositories(pool.clone());
        let hub = EventHub::new();
        let handler = make_handler_with_hub(pool, &hub);
        let message_repo = repos.message_repo.clone();

        // 预置被撤回的消息
        message_repo
            .batch_insert(&[crate::domain::model::local::LocalChatLog {
                conversation_id: "conv_revoke".to_string(),
                client_msg_id: "msg_target".to_string(),
                server_msg_id: String::new(),
                send_id: "user_1".to_string(),
                recv_id: "user_2".to_string(),
                sender_platform_id: 1,
                sender_nick_name: "Bob".to_string(),
                sender_face_url: String::new(),
                session_type: 1,
                msg_from: 100,
                content_type: 101,
                content: "original".to_string(),
                is_read: 0,
                status: 2,
                seq: 5,
                send_time: 1000,
                create_time: 1000,
                attached_info: String::new(),
                ex: String::new(),
                local_ex: String::new(),
                group_id: String::new(),
            }])
            .await
            .unwrap();

        let detail = serde_json::json!({
            "revokerUserID": "user_1",
            "clientMsgID": "msg_target",
            "revokeTime": 9999,
            "sesstionType": 1,
            "seq": 5,
            "conversationID": "conv_revoke",
            "isAdminRevoke": false,
            "revokerNickname": "Alice",
            "revokerRole": 0
        });
        let msg = MsgData {
            content_type: notification_type::REVOKE,
            content: serde_json::json!({ "detail": detail.to_string() }).to_string().into_bytes(),
            ..Default::default()
        };

        handler.handle_single_notification(&msg).await.unwrap();

        // 消息内容已替换为撤回通知
        let revoked = message_repo.get_by_conversation_and_seq("conv_revoke", 5).await.unwrap().unwrap();
        assert_eq!(revoked.content_type, notification_type::REVOKE);
        assert!(revoked.content.contains("revokerNickname"));
    }
}
