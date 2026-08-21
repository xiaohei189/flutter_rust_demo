//! 会话管理器 - 本地 CRUD（置顶、免打扰、未读数、草稿等）

use crate::sdk::client::context::Repositories;
use crate::domain::error::Result;
use crate::core::event::events::conversation::{ConversationEvent, ConversationListener, ConversationListenerExt};
use crate::infra::http::conversation::{ConversationServerApi, SetConversationReq};
use crate::domain::model::local::LocalConversation;
use crate::domain::model::UserId;

use std::sync::Arc;
use tracing::{debug, info, warn};

pub struct ConversationService {
    /// 外部依赖
    repositories: Arc<Repositories>,
    /// 服务端 API（用于同步设置到服务器）
    server_api: Option<Arc<dyn ConversationServerApi>>,
    /// 当前登录用户 ID（同步会话设置到服务器时使用）
    user_id: Option<UserId>,
    /// 事件出口（Listener trait）
    pub(crate) listener: Arc<dyn ConversationListener>,
}

impl ConversationService {
    pub fn new(repositories: Arc<Repositories>, listener: Arc<dyn ConversationListener>) -> Self {
        Self {
            repositories,
            server_api: None,
            user_id: None,
            listener,
        }
    }

    /// 设置服务端 API（builder 调用）
    pub fn with_server_api(mut self, api: Arc<dyn ConversationServerApi>) -> Self {
        self.server_api = Some(api);
        self
    }

    /// 设置当前登录用户 ID
    pub fn with_user_id(mut self, user_id: UserId) -> Self {
        self.user_id = Some(user_id);
        self
    }

    pub(crate) fn send(&self, e: ConversationEvent) {
        self.listener.emit(e);
    }

    pub async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        let mut local_convs = self.repositories.conversation_repo.get_all().await?;

        // 回填空的 latest_msg（从消息数据库获取最新消息）
        for conv in &mut local_convs {
            if conv.latest_msg.is_empty() {
                if let Ok(messages) = self.repositories.message_repo.get_latest(&conv.conversation_id, 1).await {
                    if let Some(latest) = messages.first() {
                        conv.latest_msg = latest.content.clone();
                        conv.latest_msg_send_time = latest.send_time;
                        let _ = self.repositories.conversation_repo.update_latest_msg(&conv.conversation_id, &latest.content, latest.send_time).await;
                    }
                }
            }
        }

        Ok(local_convs)
    }

    pub async fn get_conversation(&self, conversation_id: &str) -> Result<Option<LocalConversation>> {
        self.repositories.conversation_repo.get_by_id(conversation_id).await
    }

    pub async fn upsert_conversation(&self, conv: LocalConversation) -> Result<()> {
        self.repositories.conversation_repo.upsert(&conv).await?;
        self.send(ConversationEvent::Changed(vec![conv]));
        Ok(())
    }

    pub async fn upsert_conversations(&self, conversations: Vec<LocalConversation>) -> Result<()> {
        for conv in conversations {
            self.upsert_conversation(conv).await?;
        }
        Ok(())
    }

    pub async fn delete_conversation(&self, conversation_id: &str) -> Result<()> {
        self.repositories.conversation_repo.delete(conversation_id).await?;
        self.send(ConversationEvent::Deleted(vec![conversation_id.to_string()]));
        Ok(())
    }

    pub async fn set_pinned(&self, conversation_id: &str, is_pinned: bool) -> Result<()> {
        self.repositories.conversation_repo.set_pinned(conversation_id, is_pinned).await?;
        if let Some(api) = &self.server_api {
            let existing = self.repositories.conversation_repo.get_by_id(conversation_id).await?;
            let mut req = SetConversationReq {
                user_ids: Vec::new(),
                conversation_id: conversation_id.to_string(),
                conversation_type: None,
                user_id: None,
                group_id: None,
                recv_msg_opt: None,
                is_pinned: Some(is_pinned),
                is_private_chat: None,
                group_at_type: None,
                ex: None,
            };
            if let Some(conv) = &existing {
                req.conversation_type = Some(conv.conversation_type);
                req.user_id = Some(conv.user_id.clone());
                req.group_id = Some(conv.group_id.clone());
            }
            if let Some(uid) = &self.user_id {
                req.user_ids.push(uid.get().await);
            }
            if let Err(e) = api.set_conversation_on_server(&req).await {
                warn!("同步会话置顶状态到服务器失败: {}", e);
            }
        }
        info!("会话 {} 置顶状态设置为: {}", conversation_id, is_pinned);
        Ok(())
    }

    pub async fn set_private_chat(&self, conversation_id: &str, is_private: bool) -> Result<()> {
        self.repositories.conversation_repo.set_private_chat(conversation_id, is_private).await?;
        if let Some(api) = &self.server_api {
            let existing = self.repositories.conversation_repo.get_by_id(conversation_id).await?;
            let mut req = SetConversationReq {
                user_ids: Vec::new(),
                conversation_id: conversation_id.to_string(),
                conversation_type: None,
                user_id: None,
                group_id: None,
                recv_msg_opt: None,
                is_pinned: None,
                is_private_chat: Some(is_private),
                group_at_type: None,
                ex: None,
            };
            if let Some(conv) = &existing {
                req.conversation_type = Some(conv.conversation_type);
                req.user_id = Some(conv.user_id.clone());
                req.group_id = Some(conv.group_id.clone());
            }
            if let Some(uid) = &self.user_id {
                req.user_ids.push(uid.get().await);
            }
            if let Err(e) = api.set_conversation_on_server(&req).await {
                warn!("同步会话私聊状态到服务器失败: {}", e);
            }
        }
        info!("会话 {} 免打扰状态设置为: {}", conversation_id, is_private);
        Ok(())
    }

    pub async fn update_unread_count(&self, conversation_id: &str, unread_count: i32) -> Result<()> {
        self.repositories.conversation_repo.update_unread_count(conversation_id, unread_count).await?;
        debug!("会话 {} 未读消息数更新为: {}", conversation_id, unread_count);
        Ok(())
    }

    pub async fn set_draft(&self, conversation_id: &str, draft_text: &str) -> Result<()> {
        let draft_time = chrono::Utc::now().timestamp_millis();
        self.repositories.conversation_repo.set_draft(conversation_id, draft_text, draft_time).await?;
        debug!("会话 {} 草稿已设置", conversation_id);
        Ok(())
    }

    pub async fn clear_draft(&self, conversation_id: &str) -> Result<()> {
        self.set_draft(conversation_id, "").await
    }

    pub async fn get_pinned_conversations(&self) -> Result<Vec<LocalConversation>> {
        self.repositories.conversation_repo.get_pinned().await
    }

    pub async fn count(&self) -> Result<i32> {
        self.repositories.conversation_repo.count().await
    }

    /// 获取全部会话（纯读，不含 latest_msg 回填）
    pub async fn get_all(&self) -> Result<Vec<LocalConversation>> {
        self.repositories.conversation_repo.get_all().await
    }

    /// 分页获取会话（置顶优先、按时间倒序）
    pub async fn get_split(&self, offset: i64, count: i64) -> Result<Vec<LocalConversation>> {
        self.repositories.conversation_repo.get_split(offset, count).await
    }

    /// 按 ID 列表批量获取会话
    pub async fn get_multiple(&self, conversation_ids: &[String]) -> Result<Vec<LocalConversation>> {
        self.repositories.conversation_repo.get_multiple(conversation_ids).await
    }

    /// 搜索会话（按 show_name 模糊匹配）
    pub async fn search(&self, keyword: &str) -> Result<Vec<LocalConversation>> {
        self.repositories.conversation_repo.search(keyword).await
    }

    /// 重置会话（未读数/最新消息/草稿等），使其不出现在会话列表中（隐藏）
    pub async fn reset(&self, conversation_id: &str) -> Result<()> {
        self.repositories.conversation_repo.reset(conversation_id).await
    }

    /// 隐藏全部会话（对齐 Go SDK `HideAllConversations`）
    pub async fn hide_all_conversations(&self) -> Result<()> {
        let conversations = self.get_all().await?;
        for conversation in conversations {
            self.reset(&conversation.conversation_id).await?;
        }
        Ok(())
    }

    /// 通用会话信息设置：按 conversation_id 查找已有会话，更新非空字段后 upsert
    /// 同步到服务器（如果 server_api 已设置）
    pub async fn set_conversation(
        &self,
        conversation_id: &str,
        recv_msg_opt: Option<i32>,
        is_pinned: Option<bool>,
        is_private_chat: Option<bool>,
        group_at_type: Option<i32>,
        ex: Option<&str>,
    ) -> Result<()> {
        let existing = self.repositories.conversation_repo.get_by_id(conversation_id).await?;
        let mut conv = existing.clone().unwrap_or_else(|| LocalConversation {
            conversation_id: conversation_id.to_string(),
            ..Default::default()
        });
        if let Some(opt) = recv_msg_opt {
            conv.recv_msg_opt = opt;
        }
        if let Some(pinned) = is_pinned {
            conv.is_pinned = pinned;
        }
        if let Some(private) = is_private_chat {
            conv.is_private_chat = private;
        }
        if let Some(at_type) = group_at_type {
            conv.group_at_type = at_type;
        }
        if let Some(ex_val) = ex {
            conv.ex = ex_val.to_string();
        }
        if existing.is_some() {
            self.repositories
                .conversation_repo
                .update_partial(conversation_id, recv_msg_opt, is_pinned, is_private_chat, group_at_type, ex)
                .await?;
        } else {
            self.repositories.conversation_repo.upsert(&conv).await?;
        }

        // 同步到服务器
        if let Some(api) = &self.server_api {
            let mut req = SetConversationReq {
                user_ids: Vec::new(),
                conversation_id: conversation_id.to_string(),
                conversation_type: Some(conv.conversation_type),
                user_id: Some(conv.user_id.clone()),
                group_id: Some(conv.group_id.clone()),
                recv_msg_opt,
                is_pinned,
                is_private_chat,
                group_at_type,
                ex: ex.map(|s| s.to_string()),
            };
            if let Some(uid) = &self.user_id {
                req.user_ids.push(uid.get().await);
            }
            if let Err(e) = api.set_conversation_on_server(&req).await {
                warn!("同步会话设置到服务器失败: {}", e);
            }
        }

        info!("会话 {} 已更新并同步到服务器", conversation_id);
        Ok(())
    }

    pub async fn clear_all(&self) -> Result<()> {
        self.repositories.conversation_repo.clear_all().await?;
        info!("会话数据已清空");
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::db::pool::create_pool_memory;
    use crate::infra::db::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};

    fn make_test_repositories(pool: sqlx::SqlitePool) -> Arc<Repositories> {
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

    fn create_test_conversation(id: &str) -> LocalConversation {
        LocalConversation {
            conversation_id: id.to_string(),
            conversation_type: 1,
            user_id: "user_1".to_string(),
            group_id: String::new(),
            show_name: format!("Conversation {}", id),
            face_url: String::new(),
            latest_msg: String::new(),
            latest_msg_send_time: 0,
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
        }
    }

    #[tokio::test]
    async fn test_conversation_manager_creation() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        assert_eq!(manager.count().await.unwrap(), 0);
    }

    #[tokio::test]
    async fn test_conversation_manager_upsert() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await.unwrap();
        assert_eq!(manager.count().await.unwrap(), 1);
        let retrieved = manager.get_conversation("conv_1").await.unwrap();
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().conversation_id, "conv_1");
    }

    #[tokio::test]
    async fn test_conversation_manager_delete() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await.unwrap();
        assert_eq!(manager.count().await.unwrap(), 1);
        manager.delete_conversation("conv_1").await.unwrap();
        assert_eq!(manager.count().await.unwrap(), 0);
    }

    #[tokio::test]
    async fn test_conversation_manager_set_pinned() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await.unwrap();
        manager.set_pinned("conv_1", true).await.unwrap();
        let pinned = manager.get_pinned_conversations().await.unwrap();
        assert_eq!(pinned.len(), 1);
        assert_eq!(pinned[0].conversation_id, "conv_1");
        manager.set_pinned("conv_1", false).await.unwrap();
        let pinned = manager.get_pinned_conversations().await.unwrap();
        assert_eq!(pinned.len(), 0);
    }

    #[tokio::test]
    async fn test_conversation_manager_update_unread_count() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await.unwrap();
        manager.update_unread_count("conv_1", 5).await.unwrap();
        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 5);
    }

    #[tokio::test]
    async fn test_conversation_manager_set_draft() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await.unwrap();
        manager.set_draft("conv_1", "test draft").await.unwrap();
        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.draft_text, "test draft");
        manager.clear_draft("conv_1").await.unwrap();
        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.draft_text, "");
    }

    // ========================================================================
    // set_conversation：服务端同步 + 本地回写
    // ========================================================================

    #[tokio::test]
    async fn test_set_conversation_updates_existing_fields() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        manager.upsert_conversation(create_test_conversation("conv_1")).await.unwrap();

        manager.set_conversation("conv_1", Some(2), Some(true), Some(true), Some(3), Some("ex_val")).await.unwrap();

        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.recv_msg_opt, 2);
        assert!(conv.is_pinned);
        assert!(conv.is_private_chat);
        assert_eq!(conv.group_at_type, 3);
        assert_eq!(conv.ex, "ex_val");
        // 未传入字段保持原值
        assert_eq!(conv.show_name, "Conversation conv_1");
    }

    #[tokio::test]
    async fn test_set_conversation_creates_new_when_missing() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());

        manager.set_conversation("conv_new", Some(2), None, None, None, None).await.unwrap();

        let conv = manager.get_conversation("conv_new").await.unwrap().unwrap();
        assert_eq!(conv.recv_msg_opt, 2);
        assert!(!conv.is_pinned);
        assert_eq!(conv.conversation_type, 0);
    }

    #[tokio::test]
    async fn test_set_conversation_partial_updates_do_not_overwrite() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        manager.upsert_conversation(create_test_conversation("conv_partial")).await.unwrap();

        let _ = tokio::join!(
            manager.set_conversation("conv_partial", Some(2), None, None, None, None),
            manager.set_conversation("conv_partial", None, Some(true), None, None, None),
            manager.set_conversation("conv_partial", None, None, Some(true), None, None),
        );

        let conv = manager.get_conversation("conv_partial").await.unwrap().unwrap();
        assert_eq!(conv.recv_msg_opt, 2);
        assert!(conv.is_pinned);
        assert!(conv.is_private_chat);
    }

    #[tokio::test]
    async fn test_set_conversation_none_fields_keep_existing() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        manager
            .upsert_conversation(LocalConversation {
                conversation_id: "conv_1".to_string(),
                recv_msg_opt: 1,
                is_pinned: true,
                ..Default::default()
            })
            .await
            .unwrap();

        // 只更新 recv_msg_opt，其余传 None 应保持
        manager.set_conversation("conv_1", Some(2), None, None, None, None).await.unwrap();

        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.recv_msg_opt, 2);
        assert!(conv.is_pinned, "is_pinned 未被覆盖应保持 true");
    }

    #[tokio::test]
    async fn test_set_conversation_syncs_to_server() {
        let pool = create_pool_memory().await.unwrap();
        let api = Arc::new(crate::infra::http::conversation::MockConversationApi::new());
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener()).with_server_api(api.clone());
        manager.upsert_conversation(create_test_conversation("conv_1")).await.unwrap();

        manager.set_conversation("conv_1", Some(2), Some(true), None, None, Some("ex")).await.unwrap();

        // 服务端被调用且请求参数正确（仅传非 None 字段）
        let calls = api.set_calls();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].conversation_id, "conv_1");
        assert_eq!(calls[0].recv_msg_opt, Some(2));
        assert_eq!(calls[0].is_pinned, Some(true));
        assert_eq!(calls[0].is_private_chat, None);
        assert_eq!(calls[0].group_at_type, None);
        assert_eq!(calls[0].ex.as_deref(), Some("ex"));

        // 本地已回写
        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.recv_msg_opt, 2);
        assert!(conv.is_pinned);
        assert_eq!(conv.ex, "ex");
    }

    #[tokio::test]
    async fn test_set_conversation_server_failure_keeps_local_success() {
        let pool = create_pool_memory().await.unwrap();
        let api = Arc::new(crate::infra::http::conversation::MockConversationApi::new().with_set_fail(true));
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener()).with_server_api(api.clone());
        manager.upsert_conversation(create_test_conversation("conv_1")).await.unwrap();

        // 服务端失败不应影响本地更新结果
        manager.set_conversation("conv_1", Some(2), None, None, None, None).await.unwrap();

        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.recv_msg_opt, 2);
    }

    // ========================================================================
    // 查询族：get_split / get_multiple / search / reset / 回填
    // ========================================================================

    fn create_conv_with_time(id: &str, latest_msg_send_time: i64, pinned: bool) -> LocalConversation {
        LocalConversation {
            conversation_id: id.to_string(),
            conversation_type: 1,
            user_id: "user_1".to_string(),
            group_id: String::new(),
            show_name: format!("Chat_{}", id),
            face_url: String::new(),
            latest_msg: format!("msg_{}", id),
            latest_msg_send_time,
            unread_count: 0,
            recv_msg_opt: 0,
            is_pinned: pinned,
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
        }
    }

    #[tokio::test]
    async fn test_get_split_pinned_first_then_time_desc() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        manager.upsert_conversation(create_conv_with_time("conv_old", 1000, false)).await.unwrap();
        manager.upsert_conversation(create_conv_with_time("conv_new", 3000, false)).await.unwrap();
        manager.upsert_conversation(create_conv_with_time("conv_pinned", 2000, true)).await.unwrap();

        let list = manager.get_split(0, 10).await.unwrap();
        assert_eq!(list.len(), 3);
        // 置顶优先，其余按时间倒序
        assert_eq!(list[0].conversation_id, "conv_pinned");
        assert_eq!(list[1].conversation_id, "conv_new");
        assert_eq!(list[2].conversation_id, "conv_old");
    }

    #[tokio::test]
    async fn test_get_split_filters_hidden_and_paginates() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        // latest_msg_send_time = 0 的会话被过滤（reset 后隐藏）
        manager.upsert_conversation(create_conv_with_time("conv_hidden", 0, false)).await.unwrap();
        manager.upsert_conversation(create_conv_with_time("conv_1", 1000, false)).await.unwrap();
        manager.upsert_conversation(create_conv_with_time("conv_2", 2000, false)).await.unwrap();
        manager.upsert_conversation(create_conv_with_time("conv_3", 3000, false)).await.unwrap();

        let list = manager.get_split(0, 2).await.unwrap();
        assert_eq!(list.len(), 2);
        assert_eq!(list[0].conversation_id, "conv_3");
        assert_eq!(list[1].conversation_id, "conv_2");

        let list = manager.get_split(2, 2).await.unwrap();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].conversation_id, "conv_1");
    }

    #[tokio::test]
    async fn test_get_multiple() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        manager.upsert_conversation(create_test_conversation("conv_1")).await.unwrap();
        manager.upsert_conversation(create_test_conversation("conv_2")).await.unwrap();
        manager.upsert_conversation(create_test_conversation("conv_3")).await.unwrap();

        let list = manager.get_multiple(&["conv_1".to_string(), "conv_3".to_string()]).await.unwrap();
        let mut ids: Vec<String> = list.into_iter().map(|c| c.conversation_id).collect();
        ids.sort();
        assert_eq!(ids, vec!["conv_1", "conv_3"]);

        // 空列表直接返回空
        let empty = manager.get_multiple(&[]).await.unwrap();
        assert!(empty.is_empty());
    }

    #[tokio::test]
    async fn test_search_by_show_name() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        manager.upsert_conversation(create_conv_with_time("conv_alice", 1000, false)).await.unwrap();
        manager.upsert_conversation(create_conv_with_time("conv_bob", 2000, false)).await.unwrap();

        let found = manager.search("alice").await.unwrap();
        assert_eq!(found.len(), 1);
        assert_eq!(found[0].conversation_id, "conv_alice");

        let none = manager.search("nobody").await.unwrap();
        assert!(none.is_empty());
    }

    #[tokio::test]
    async fn test_reset_hides_conversation() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        let mut conv = create_conv_with_time("conv_1", 1000, false);
        conv.unread_count = 5;
        conv.draft_text = "draft".to_string();
        manager.upsert_conversation(conv).await.unwrap();

        manager.reset("conv_1").await.unwrap();

        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 0);
        assert_eq!(conv.latest_msg, "");
        assert_eq!(conv.latest_msg_send_time, 0);
        assert_eq!(conv.draft_text, "");
        // reset 后不再出现在分页列表中
        let list = manager.get_split(0, 10).await.unwrap();
        assert!(list.is_empty());
    }

    #[tokio::test]
    async fn test_reset_missing_conversation_returns_error() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        assert!(manager.reset("conv_missing").await.is_err());
    }

    #[tokio::test]
    async fn test_hide_all_conversations_hides_all() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationService::new(make_test_repositories(pool), crate::core::event::test_util::noop_conversation_listener());
        manager.upsert_conversation(create_conv_with_time("conv_1", 1000, false)).await.unwrap();
        manager.upsert_conversation(create_conv_with_time("conv_2", 2000, false)).await.unwrap();

        manager.hide_all_conversations().await.unwrap();

        let list = manager.get_split(0, 10).await.unwrap();
        assert!(list.is_empty());
    }

    #[tokio::test]
    async fn test_get_all_conversations_backfills_latest_msg() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool.clone());
        let manager = ConversationService::new(repositories.clone(), crate::core::event::test_util::noop_conversation_listener());

        // 会话 latest_msg 为空，但消息库有最新消息
        manager.upsert_conversation(create_test_conversation("conv_1")).await.unwrap();
        let message_repo = repositories.message_repo.clone();
        let msg = crate::domain::model::local::LocalChatLog {
            conversation_id: "conv_1".to_string(),
            client_msg_id: "m1".to_string(),
            server_msg_id: String::new(),
            send_id: "u1".to_string(),
            recv_id: "u2".to_string(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: "最新内容".to_string(),
            is_read: 0,
            status: 2,
            seq: 1,
            send_time: 8888,
            create_time: 8888,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        };
        message_repo.batch_insert(&[msg]).await.unwrap();

        let list = manager.get_all_conversations().await.unwrap();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].latest_msg, "最新内容");
        assert_eq!(list[0].latest_msg_send_time, 8888);

        // 回填已持久化到会话表
        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.latest_msg, "最新内容");
    }
}
