//! 消息删除逻辑

use super::MessageService;
use crate::domain::error::Result;
use crate::event::events::message::{MessageEvent, MessageListenerExt};
use crate::http::message::DeleteMessagesReq;

use tracing::info;

impl MessageService {
    /// 删除消息（对齐 Go SDK deleteMessage）
    ///
    /// 服务端 API 需要 seqs，从本地数据库查找。
    pub async fn delete_messages(&self, req: DeleteMessagesReq) -> Result<()> {
        // 从本地数据库查找每条消息的 seq
        let mut seqs = Vec::new();
        for client_msg_id in &req.client_msg_ids {
            if let Ok(Some(msg)) = self.repositories.message_repo.get_by_client_msg_id(&req.conversation_id, client_msg_id).await {
                if msg.seq > 0 {
                    seqs.push(msg.seq);
                }
            }
        }

        // 通知服务端（失败则整体失败，本地不变更）
        let user_id = self.user_id.get().await;
        self.api.delete_on_server(&req.conversation_id, &seqs, &user_id).await?;

        // 服务端成功后删除本地
        self.apply_local_delete(&req.conversation_id, &req.client_msg_ids).await?;

        info!("消息已删除: conversation_id={}, count={}", req.conversation_id, req.client_msg_ids.len());
        Ok(())
    }

    /// 本地删除逻辑（服务端已确认成功后调用）
    pub(crate) async fn apply_local_delete(&self, conversation_id: &str, client_msg_ids: &[String]) -> Result<()> {
        for client_msg_id in client_msg_ids {
            // 对齐 Go SDK：软删（status=4），保留记录避免 seq 空洞被 gap 补拉复活
            self.repositories.message_repo.mark_as_deleted(conversation_id, client_msg_id).await?;
        }

        self.message_listener.emit(MessageEvent::Deleted {
            conversation_id: conversation_id.to_string(),
            client_msg_ids: client_msg_ids.to_vec(),
        });

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::client::context::Repositories;
    use crate::domain::constant::msg_status;
    use crate::db::pool::create_pool_memory;
    use crate::db::*;
    use crate::domain::error::SdkError;
    use crate::event::events::message::MessageEvent;
    use crate::event::hub::EventHub;
    use crate::http::message::{MarkConversationAsReadReq, MarkMessagesAsReadReq, MessageServerApi, RevokeMessageReq};
    use crate::domain::model::local::LocalChatLog;
    use crate::domain::model::UserId;
    use async_trait::async_trait;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Arc;

    struct MockDeleteApi {
        delete_calls: AtomicUsize,
        fail: bool,
    }

    impl MockDeleteApi {
        fn new() -> Self {
            Self {
                delete_calls: AtomicUsize::new(0),
                fail: false,
            }
        }
        fn with_fail(fail: bool) -> Self {
            Self {
                delete_calls: AtomicUsize::new(0),
                fail,
            }
        }
        fn delete_count(&self) -> usize {
            self.delete_calls.load(Ordering::SeqCst)
        }
    }

    #[async_trait]
    impl MessageServerApi for MockDeleteApi {
        async fn revoke_on_server(&self, _req: &RevokeMessageReq) -> Result<()> {
            Ok(())
        }
        async fn delete_on_server(&self, _conversation_id: &str, _seqs: &[i64], _user_id: &str) -> Result<()> {
            self.delete_calls.fetch_add(1, Ordering::SeqCst);
            if self.fail {
                return Err(SdkError::network("mock delete failure".to_string()));
            }
            Ok(())
        }
        async fn mark_messages_as_read_on_server(&self, _req: &MarkMessagesAsReadReq) -> Result<()> {
            Ok(())
        }
        async fn mark_conversation_as_read_on_server(&self, _req: &MarkConversationAsReadReq) -> Result<()> {
            Ok(())
        }
        async fn get_server_time(&self) -> Result<i64> {
            Ok(0)
        }
    }

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

    fn make_msg(conv_id: &str, client_msg_id: &str, seq: i64) -> LocalChatLog {
        LocalChatLog {
            conversation_id: conv_id.to_string(),
            client_msg_id: client_msg_id.to_string(),
            server_msg_id: String::new(),
            send_id: "user_a".to_string(),
            recv_id: "user_b".to_string(),
            sender_platform_id: 1,
            sender_nick_name: "Test".to_string(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: "hello".to_string(),
            is_read: 0,
            status: 2,
            seq,
            send_time: 1000,
            create_time: 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        }
    }

    fn make_service_with_api(pool: sqlx::SqlitePool, api: Arc<MockDeleteApi>) -> (super::MessageService, tokio::sync::mpsc::UnboundedReceiver<MessageEvent>) {
        let repos = make_repositories(pool);
        let hub = EventHub::new();
        let msg_rx = hub.take_message_rx().unwrap();
        let service = super::MessageService {
            repositories: repos.clone(),
            api,
            user_id: UserId::new("test_user"),
            listener: crate::event::test_util::noop_conversation_listener(),
            message_listener: hub.clone(),
            checker: None,
            seq_pull_context: Arc::new(tokio::sync::Mutex::new(crate::message::receive::checker::SeqPullContext::default())),
        };
        (service, msg_rx)
    }

    #[tokio::test]
    async fn test_delete_messages_success() {
        let pool = create_pool_memory().await.unwrap();
        let api = Arc::new(MockDeleteApi::new());
        let (service, mut msg_rx) = make_service_with_api(pool.clone(), api.clone());
        let dao = MessageDao::new(pool.clone());
        dao.batch_insert(&[make_msg("conv_1", "m1", 1), make_msg("conv_1", "m2", 2), make_msg("conv_1", "m3", 3)])
            .await
            .unwrap();

        let req = DeleteMessagesReq {
            conversation_id: "conv_1".to_string(),
            client_msg_ids: vec!["m1".to_string(), "m3".to_string()],
        };
        service.delete_messages(req).await.unwrap();

        // 服务端调用一次
        assert_eq!(api.delete_count(), 1);
        // 本地软删（status=4，记录保留），m2 保持正常
        let m1 = dao.get_by_client_msg_id("conv_1", "m1").await.unwrap().unwrap();
        let m3 = dao.get_by_client_msg_id("conv_1", "m3").await.unwrap().unwrap();
        let m2 = dao.get_by_client_msg_id("conv_1", "m2").await.unwrap().unwrap();
        assert_eq!(m1.status, msg_status::HAS_DELETED);
        assert_eq!(m3.status, msg_status::HAS_DELETED);
        assert_eq!(m2.status, msg_status::SEND_SUCCESS);
        // Deleted 事件发布
        match msg_rx.try_recv().unwrap() {
            MessageEvent::Deleted { conversation_id, client_msg_ids } => {
                assert_eq!(conversation_id, "conv_1");
                assert_eq!(client_msg_ids, vec!["m1", "m3"]);
            }
            other => panic!("期望 Deleted 事件，实际 {:?}", other),
        }
    }

    #[tokio::test]
    async fn test_delete_messages_skips_zero_seq() {
        let pool = create_pool_memory().await.unwrap();
        let api = Arc::new(MockDeleteApi::new());
        let (service, _msg_rx) = make_service_with_api(pool.clone(), api.clone());
        let dao = MessageDao::new(pool);
        // seq=0 表示尚未分配服务端 seq（发送中/失败消息），不应传给服务端
        dao.batch_insert(&[make_msg("conv_1", "m_local", 0)]).await.unwrap();

        let req = DeleteMessagesReq {
            conversation_id: "conv_1".to_string(),
            client_msg_ids: vec!["m_local".to_string()],
        };
        service.delete_messages(req).await.unwrap();

        assert_eq!(api.delete_count(), 1, "即使 seqs 为空也会调用服务端");
        // 本地仍软删
        let m = dao.get_by_client_msg_id("conv_1", "m_local").await.unwrap().unwrap();
        assert_eq!(m.status, msg_status::HAS_DELETED);
    }

    #[tokio::test]
    async fn test_delete_messages_server_failure_keeps_local() {
        let pool = create_pool_memory().await.unwrap();
        let api = Arc::new(MockDeleteApi::with_fail(true));
        let (service, mut msg_rx) = make_service_with_api(pool.clone(), api.clone());
        let dao = MessageDao::new(pool);
        dao.batch_insert(&[make_msg("conv_1", "m1", 1)]).await.unwrap();

        let req = DeleteMessagesReq {
            conversation_id: "conv_1".to_string(),
            client_msg_ids: vec!["m1".to_string()],
        };
        let result = service.delete_messages(req).await;
        assert!(result.is_err(), "服务端失败应返回错误");
        // 本地消息保留、无事件
        assert!(dao.get_by_client_msg_id("conv_1", "m1").await.unwrap().is_some());
        assert!(msg_rx.try_recv().is_err(), "失败时不应发布 Deleted 事件");
    }

    #[test]
    fn test_delete_module_compiles() {
        // 模块加载验证（保留原占位测试的意图）
        assert_eq!(msg_status::HAS_DELETED, 4);
    }
}
