//! 用户操作管道: Client -> [Service] -> HTTP API + DB + Events
//!
//! 处理用户主动发起的消息操作（撤回/删除/标记已读/搜索）

mod delete;
mod query;
mod read;
mod revoke;
mod search;

use crate::core::context::Repositories;
use crate::core::event::events::conversation::{ConversationEvent, ConversationListener, ConversationListenerExt};
use crate::core::event::events::message::MessageListener;
use crate::infra::http::message::MessageServerApi;
use crate::core::message::receive::checker::{MessageChecker, SeqPullContext};
use crate::domain::model::UserId;
use std::sync::Arc;

/// 消息服务 — 用户主动发起的消息操作（撤回/删除/标记已读/搜索）
pub struct MessageService {
    pub(crate) repositories: Arc<Repositories>,
    pub(crate) api: Arc<dyn MessageServerApi>,
    pub(crate) user_id: UserId,
    pub(crate) listener: Arc<dyn ConversationListener>,
    pub(crate) message_listener: Arc<dyn MessageListener>,
    pub(crate) checker: Option<Arc<MessageChecker>>,
    /// 翻页拉取结束 seq 缓存（对齐 Go conversation_seq_cache.go）
    pub(crate) seq_pull_context: Arc<tokio::sync::Mutex<SeqPullContext>>,
}

impl MessageService {
    pub fn new(repositories: Arc<Repositories>, api: Arc<dyn MessageServerApi>, listener: Arc<dyn ConversationListener>, message_listener: Arc<dyn MessageListener>, user_id: UserId) -> Self {
        Self {
            repositories,
            api,
            user_id,
            listener,
            message_listener,
            checker: None,
            seq_pull_context: Arc::new(tokio::sync::Mutex::new(SeqPullContext::default())),
        }
    }

    /// 注入消息连续性检查器，历史查询时补拉服务端缺失 seq（对齐 Go 三层 Gap 检查）
    pub fn with_checker(mut self, checker: Arc<MessageChecker>) -> Self {
        self.checker = Some(checker);
        self
    }

    pub(crate) fn send(&self, e: ConversationEvent) {
        self.listener.emit(e);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sdk::client::{GetHistoryMessagesReq, SearchMessagesReq};
    use crate::infra::db::pool::create_pool_memory;
    use crate::infra::db::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};
    use crate::infra::http::message::{DeleteMessagesReq, MarkConversationAsReadReq, MarkMessagesAsReadReq, MessageServerApi, RevokeMessageReq};
    use crate::domain::model::local::{LocalChatLog, LocalConversation};
    use crate::domain::model::UserId;
    use std::sync::Arc;
    use std::time::Duration;

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

    pub(crate) struct SuccessMockApi;

    #[async_trait::async_trait]
    impl MessageServerApi for SuccessMockApi {
        async fn revoke_on_server(&self, _req: &RevokeMessageReq) -> crate::domain::error::Result<()> {
            Ok(())
        }
        async fn delete_on_server(&self, _c: &str, _s: &[i64], _u: &str) -> crate::domain::error::Result<()> {
            Ok(())
        }
        async fn mark_conversation_as_read_on_server(&self, _req: &MarkConversationAsReadReq) -> crate::domain::error::Result<()> {
            Ok(())
        }
        async fn mark_messages_as_read_on_server(&self, _req: &MarkMessagesAsReadReq) -> crate::domain::error::Result<()> {
            Ok(())
        }
        async fn get_server_time(&self) -> crate::domain::error::Result<i64> {
            Ok(0)
        }
    }

    pub(crate) struct FailMockApi;

    #[async_trait::async_trait]
    impl MessageServerApi for FailMockApi {
        async fn revoke_on_server(&self, _req: &RevokeMessageReq) -> crate::domain::error::Result<()> {
            Err(crate::domain::error::SdkError::api(1001, "server error"))
        }
        async fn delete_on_server(&self, _c: &str, _s: &[i64], _u: &str) -> crate::domain::error::Result<()> {
            Err(crate::domain::error::SdkError::api(1001, "server error"))
        }
        async fn mark_conversation_as_read_on_server(&self, _req: &MarkConversationAsReadReq) -> crate::domain::error::Result<()> {
            Err(crate::domain::error::SdkError::api(1001, "server error"))
        }
        async fn mark_messages_as_read_on_server(&self, _req: &MarkMessagesAsReadReq) -> crate::domain::error::Result<()> {
            Err(crate::domain::error::SdkError::api(1001, "server error"))
        }
        async fn get_server_time(&self) -> crate::domain::error::Result<i64> {
            Err(crate::domain::error::SdkError::api(1001, "server error"))
        }
    }

    pub(crate) fn make_service(repositories: Arc<Repositories>) -> MessageService {
        let api: Arc<dyn MessageServerApi> = Arc::new(SuccessMockApi);
        MessageService::new(
            repositories,
            api,
            crate::core::event::test_util::noop_conversation_listener(),
            crate::core::event::test_util::noop_message_listener(),
            UserId::new("user_1"),
        )
    }

    pub(crate) fn make_service_with_api(repositories: Arc<Repositories>, api: Arc<dyn MessageServerApi>) -> MessageService {
        MessageService::new(
            repositories,
            api,
            crate::core::event::test_util::noop_conversation_listener(),
            crate::core::event::test_util::noop_message_listener(),
            UserId::new("user_1"),
        )
    }

    fn make_local_msg(conv_id: &str, client_msg_id: &str, seq: i64, send_id: &str) -> LocalChatLog {
        LocalChatLog {
            conversation_id: conv_id.to_string(),
            client_msg_id: client_msg_id.to_string(),
            server_msg_id: format!("srv_{}", client_msg_id),
            send_id: send_id.to_string(),
            recv_id: "user_2".to_string(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: format!("{{\"text\":\"hello {}\"}}", client_msg_id),
            is_read: 0,
            status: 1,
            seq,
            send_time: seq * 1000,
            create_time: seq * 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        }
    }

    fn make_conv(conv_id: &str, unread: i32) -> LocalConversation {
        LocalConversation {
            conversation_id: conv_id.to_string(),
            conversation_type: 1,
            user_id: String::new(),
            group_id: String::new(),
            show_name: String::new(),
            face_url: String::new(),
            latest_msg: String::new(),
            latest_msg_send_time: 0,
            unread_count: unread,
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
            max_seq: 10,
            min_seq: 0,
            is_msg_destruct: false,
            msg_destruct_time: 0,
        }
    }

    #[tokio::test]
    async fn test_search_local_messages() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let service = make_service(repositories);
        message_dao
            .batch_insert(&[make_local_msg("conv_s", "msg_1", 1, "user_2"), make_local_msg("conv_s", "msg_2", 2, "user_2")])
            .await
            .unwrap();
        let results = service
            .search_local_messages(SearchMessagesReq {
                conversation_id: "conv_s".to_string(),
                keyword: "hello".to_string(),
                sender_user_ids: vec![],
                message_types: vec![],
                start_time: 0,
                end_time: 0,
                offset: 0,
                count: 10,
            })
            .await
            .unwrap();
        assert_eq!(results.len(), 2);
    }

    #[tokio::test]
    async fn test_search_local_messages_with_filters() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let service = make_service(repositories);

        let mut msg1 = make_local_msg("conv_filter", "msg_1", 1, "user_2");
        msg1.send_time = 1000;
        msg1.content_type = crate::domain::constant::content_type::TEXT;
        let mut msg2 = make_local_msg("conv_filter", "msg_2", 2, "user_3");
        msg2.send_time = 2000;
        msg2.content_type = crate::domain::constant::content_type::PICTURE;
        message_dao.batch_insert(&[msg1, msg2]).await.unwrap();

        let results = service
            .search_local_messages(SearchMessagesReq {
                conversation_id: "conv_filter".to_string(),
                keyword: "hello".to_string(),
                sender_user_ids: vec!["user_3".to_string()],
                message_types: vec![crate::domain::constant::content_type::PICTURE],
                start_time: 1500,
                end_time: 3000,
                offset: 0,
                count: 10,
            })
            .await
            .unwrap();

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].client_msg_id, "msg_2");
    }

    #[tokio::test]
    async fn test_deleted_message_excluded_from_history_and_search() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let service = make_service(repositories);
        message_dao.batch_insert(&[make_local_msg("conv_del", "msg_del", 1, "user_2")]).await.unwrap();
        message_dao.mark_as_deleted("conv_del", "msg_del").await.unwrap();

        let history = service
            .get_history_messages(&GetHistoryMessagesReq {
                conversation_id: "conv_del".to_string(),
                start_client_msg_id: String::new(),
                count: 10,
            })
            .await
            .unwrap();
        assert!(history.messages.is_empty());

        let search = service
            .search_local_messages(SearchMessagesReq {
                conversation_id: "conv_del".to_string(),
                keyword: "hello".to_string(),
                sender_user_ids: vec![],
                message_types: vec![],
                start_time: 0,
                end_time: 0,
                offset: 0,
                count: 10,
            })
            .await
            .unwrap();
        assert!(search.is_empty());
    }

    #[tokio::test]
    async fn test_mark_conversation_as_read_clears_unread() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let service = make_service(repositories);
        message_dao
            .batch_insert(&[make_local_msg("conv_read", "msg_1", 1, "user_2"), make_local_msg("conv_read", "msg_2", 2, "user_2")])
            .await
            .unwrap();
        conversation_dao.upsert(&make_conv("conv_read", 2)).await.unwrap();
        service.mark_conversation_message_as_read("conv_read".to_string(), 1).await.unwrap();
        let conv = conversation_dao.get_by_id("conv_read").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 0);
    }

    #[tokio::test]
    async fn test_mark_all_conversation_as_read_clears_unread_and_skips_clean() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let conversation_dao = repositories.conversation_repo.clone();
        let service = make_service(repositories);

        conversation_dao.upsert(&make_conv("conv_all_1", 3)).await.unwrap();
        conversation_dao.upsert(&make_conv("conv_all_2", 0)).await.unwrap();

        service.mark_all_conversation_as_read().await.unwrap();

        assert_eq!(conversation_dao.get_by_id("conv_all_1").await.unwrap().unwrap().unread_count, 0);
        assert_eq!(conversation_dao.get_by_id("conv_all_2").await.unwrap().unwrap().unread_count, 0);
    }

    #[tokio::test]
    async fn test_revoke_message_success_marks_local() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let service = make_service(repositories);
        message_dao.batch_insert(&[make_local_msg("conv_r", "msg_r1", 5, "user_1")]).await.unwrap();
        service
            .revoke_message(RevokeMessageReq {
                conversation_id: "conv_r".into(),
                seq: 5,
                user_id: "user_1".into(),
                client_msg_id: "msg_r1".into(),
                session_type: 1,
            })
            .await
            .unwrap();
        let msg = message_dao.get_by_client_msg_id("conv_r", "msg_r1").await.unwrap().unwrap();
        assert_eq!(msg.content_type, crate::domain::constant::notification_type::REVOKE);
    }

    #[tokio::test]
    async fn test_revoke_waits_for_seq_sync() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let service = make_service(repositories);

        let dao = message_dao.clone();
        let task = tokio::spawn(async move {
            tokio::time::sleep(Duration::from_millis(20)).await;
            dao.batch_insert(&[make_local_msg("conv_w", "msg_w", 5, "user_1")]).await.unwrap();
        });

        let seq = service.wait_for_message_sync_seq_inner("conv_w", "msg_w", 5, Duration::from_millis(10)).await.unwrap();
        assert_eq!(seq, 5);
        task.await.unwrap();
    }

    #[tokio::test]
    async fn test_revoke_seq_missing_after_max_attempts() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let service = make_service(repositories);

        let result = service.wait_for_message_sync_seq_inner("conv_missing", "msg_x", 3, Duration::from_millis(1)).await;
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("seq 未同步"));
    }

    #[tokio::test]
    async fn test_revoke_with_zero_seq_resolves_from_local() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let service = make_service(repositories);
        message_dao.batch_insert(&[make_local_msg("conv_z", "msg_z", 9, "user_1")]).await.unwrap();

        service
            .revoke_message(RevokeMessageReq {
                conversation_id: "conv_z".into(),
                seq: 0,
                user_id: "user_1".into(),
                client_msg_id: "msg_z".into(),
                session_type: 1,
            })
            .await
            .unwrap();

        let msg = message_dao.get_by_client_msg_id("conv_z", "msg_z").await.unwrap().unwrap();
        assert_eq!(msg.content_type, crate::domain::constant::notification_type::REVOKE);
    }

    #[tokio::test]
    async fn test_revoke_server_failure_keeps_local_unchanged() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let api: Arc<dyn MessageServerApi> = Arc::new(FailMockApi);
        let service = make_service_with_api(repositories, api);
        message_dao.batch_insert(&[make_local_msg("conv_f", "msg_f", 3, "user_1")]).await.unwrap();

        let result = service
            .revoke_message(RevokeMessageReq {
                conversation_id: "conv_f".into(),
                seq: 3,
                user_id: "user_1".into(),
                client_msg_id: "msg_f".into(),
                session_type: 1,
            })
            .await;
        assert!(result.is_err());

        let msg = message_dao.get_by_client_msg_id("conv_f", "msg_f").await.unwrap().unwrap();
        assert_eq!(msg.content_type, 101);
    }

    #[tokio::test]
    async fn test_delete_messages_success_soft_deletes_local() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let service = make_service(repositories);
        message_dao
            .batch_insert(&[make_local_msg("conv_d", "msg_d1", 1, "user_2"), make_local_msg("conv_d", "msg_d2", 2, "user_2")])
            .await
            .unwrap();
        service
            .delete_messages(DeleteMessagesReq {
                conversation_id: "conv_d".into(),
                client_msg_ids: vec!["msg_d1".into(), "msg_d2".into()],
            })
            .await
            .unwrap();
        let msg = message_dao.get_by_client_msg_id("conv_d", "msg_d1").await.unwrap().unwrap();
        assert_eq!(msg.status, crate::domain::constant::msg_status::HAS_DELETED, "本地删除应保留记录并标记为已删除");
    }

    #[tokio::test]
    async fn test_mark_messages_as_read_success() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let service = make_service(repositories);
        message_dao
            .batch_insert(&[make_local_msg("conv_mr", "m1", 1, "user_2"), make_local_msg("conv_mr", "m2", 2, "user_2")])
            .await
            .unwrap();
        service
            .mark_messages_as_read(MarkMessagesAsReadReq {
                conversation_id: "conv_mr".into(),
                user_id: "user_1".into(),
                session_type: 1,
                has_read_seq: 2,
                seqs: vec![1, 2],
            })
            .await
            .unwrap();
        let logs = message_dao.get_by_conversation("conv_mr", 0, 100).await.unwrap();
        assert!(logs.iter().all(|m| m.is_read == 1));
    }

    #[tokio::test]
    async fn test_mark_messages_as_read_server_failure_keeps_unread() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let api: Arc<dyn MessageServerApi> = Arc::new(FailMockApi);
        let service = make_service_with_api(repositories, api);
        message_dao
            .batch_insert(&[make_local_msg("conv_mrf", "m1", 1, "user_2"), make_local_msg("conv_mrf", "m2", 2, "user_2")])
            .await
            .unwrap();

        let result = service
            .mark_messages_as_read(MarkMessagesAsReadReq {
                conversation_id: "conv_mrf".into(),
                user_id: "user_1".into(),
                session_type: 1,
                has_read_seq: 2,
                seqs: vec![1, 2],
            })
            .await;
        assert!(result.is_err());

        let logs = message_dao.get_by_conversation("conv_mrf", 0, 100).await.unwrap();
        assert!(logs.iter().all(|m| m.is_read == 0));
    }

    #[tokio::test]
    async fn test_mark_conversation_as_read_server_failure_still_clears_local() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let api: Arc<dyn MessageServerApi> = Arc::new(FailMockApi);
        let service = make_service_with_api(repositories, api);
        message_dao
            .batch_insert(&[make_local_msg("conv_crf", "m1", 1, "user_2"), make_local_msg("conv_crf", "m2", 2, "user_2")])
            .await
            .unwrap();
        conversation_dao.upsert(&make_conv("conv_crf", 2)).await.unwrap();

        // 对齐 Go SDK：会话已读属于尽力而为，服务端失败不阻断本地清未读。
        service.mark_conversation_message_as_read("conv_crf".to_string(), 1).await.unwrap();
        let conv = conversation_dao.get_by_id("conv_crf").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 0);
    }
}
