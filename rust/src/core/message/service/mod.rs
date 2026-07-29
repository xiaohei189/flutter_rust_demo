//! 消息服务 — 用户主动发起的消息操作（撤回/删除/标记已读/搜索）
//!
//! 对齐 Go SDK `internal/conversation_msg/` 中的用户操作类方法。
//!
//! # 与 handler 的区别
//!
//! - `MessageHandler`：处理服务端**推送**的消息（被动接收）
//! - `MessageService`：处理用户**主动发起**的操作（调用 HTTP API + 更新本地 DB）
//!
//! # 子模块
//!
//! | 文件 | 职责 |
//! |------|------|
//! | [`req`] | HTTP API 请求体 DTO |
//! | [`revoke`] | 消息撤回 |
//! | [`delete`] | 消息删除 |
//! | [`read`] | 标记已读（单会话/批量/按 seq） |
//! | [`search`] | 本地消息搜索 |

mod req;
mod revoke;
mod delete;
mod read;
mod search;

pub use req::*;

use crate::domain::event::EventBus;
use crate::domain::listener::conversation::ConversationEvent;
use crate::infra::database::{ConversationDao, MessageDao};
use std::sync::Arc;

/// 消息服务 — 用户主动发起的消息操作（撤回/删除/标记已读/搜索）
///
/// 对齐 Go SDK `internal/conversation_msg/` 中的用户操作类方法。
///
/// # 与 handler 的区别
///
/// - `MessageHandler`：处理服务端**推送**的消息（被动接收）
/// - `MessageService`：处理用户**主动发起**的操作（调用 HTTP API + 更新本地 DB）
pub struct MessageService {
    pub(crate) message_dao: Arc<MessageDao>,
    pub(crate) conversation_dao: Arc<ConversationDao>,
    pub(crate) event_bus: Arc<EventBus>,
    pub(crate) event_tx: Arc<std::sync::Mutex<Option<tokio::sync::mpsc::UnboundedSender<ConversationEvent>>>>,
    pub(crate) http_client: Arc<crate::infra::http::client::HttpApiClient>,
    pub(crate) user_id: Arc<std::sync::Mutex<String>>,
}

impl MessageService {
    pub fn new(
        message_dao: Arc<MessageDao>,
        conversation_dao: Arc<ConversationDao>,
        event_bus: Arc<EventBus>,
        http_client: Arc<crate::infra::http::client::HttpApiClient>,
        user_id: String,
    ) -> Self {
        Self {
            message_dao,
            conversation_dao,
            event_bus,
            event_tx: Arc::new(std::sync::Mutex::new(None)),
            http_client,
            user_id: Arc::new(std::sync::Mutex::new(user_id)),
        }
    }

    pub fn set_event_sender(&self, tx: tokio::sync::mpsc::UnboundedSender<ConversationEvent>) {
        *self.event_tx.lock().unwrap() = Some(tx);
    }

    pub(crate) fn send(&self, e: ConversationEvent) {
        let has_tx = self.event_tx.lock().unwrap().is_some();
        tracing::info!("[SEND] {:?}, has_subscriber={}", &e, has_tx);
        if let Some(tx) = &*self.event_tx.lock().unwrap() { let _ = tx.send(e); }
    }

    pub fn set_user_id(&self, user_id: String) {
        let mut uid = self.user_id.lock().unwrap();
        *uid = user_id;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;
    use crate::infra::database::models::{LocalChatLog, LocalConversation};
    use crate::infra::http::client::HttpApiClient;
    use std::sync::Arc;

    fn make_service(
        message_dao: Arc<MessageDao>,
        conversation_dao: Arc<ConversationDao>,
    ) -> MessageService {
        let event_bus = Arc::new(EventBus::new());
        // 使用不可达地址，HTTP 调用会失败但不影响本地 DB 逻辑测试
        let http_client = Arc::new(HttpApiClient::new(
            "http://127.0.0.1:1".to_string(),
            "test_token".to_string(),
            "test_op".to_string(),
        ));
        MessageService::new(message_dao, conversation_dao, event_bus, http_client, "user_1".to_string())
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
            is_pinned: 0,
            is_private_chat: 0,
            burn_duration: 0,
            group_at_type: 0,
            is_not_in_group: 0,
            update_unread_count_time: 0,
            attached_info: String::new(),
            ex: String::new(),
            draft_text: String::new(),
            draft_text_time: 0,
            max_seq: 10,
            min_seq: 0,
            is_msg_destruct: 0,
            msg_destruct_time: 0,
        }
    }

    #[tokio::test]
    async fn test_search_local_messages() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let service = make_service(message_dao.clone(), conversation_dao);

        // 插入测试消息
        let msgs = vec![
            make_local_msg("conv_s", "msg_1", 1, "user_2"),
            make_local_msg("conv_s", "msg_2", 2, "user_2"),
        ];
        message_dao.batch_insert(&msgs).await.unwrap();

        // 搜索包含 "hello" 的消息
        let results = service.search_local_messages(
            "conv_s".to_string(),
            "hello".to_string(),
            10,
        ).await.unwrap();
        assert_eq!(results.len(), 2);

        // 搜索不存在的关键词
        let results = service.search_local_messages(
            "conv_s".to_string(),
            "nonexistent".to_string(),
            10,
        ).await.unwrap();
        assert_eq!(results.len(), 0);
    }

    #[tokio::test]
    async fn test_mark_conversation_as_read_clears_unread() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let service = make_service(message_dao.clone(), conversation_dao.clone());

        // 插入未读消息 + 会话
        let msgs = vec![
            make_local_msg("conv_read", "msg_1", 1, "user_2"),
            make_local_msg("conv_read", "msg_2", 2, "user_2"),
        ];
        message_dao.batch_insert(&msgs).await.unwrap();
        conversation_dao.upsert(&make_conv("conv_read", 2)).await.unwrap();

        // 标记已读（HTTP 失败但本地 DB 仍更新）
        service.mark_conversation_message_as_read("conv_read".to_string(), 1).await.unwrap();

        // 验证未读数清零
        let conv = conversation_dao.get_by_id("conv_read").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 0, "unread should be 0 after mark as read");

        // 验证消息标记为已读
        let logs = message_dao.get_by_conversation("conv_read", 0, 100).await.unwrap();
        assert!(logs.iter().all(|m| m.is_read == 1), "all messages should be marked read");
    }

    #[tokio::test]
    async fn test_mark_conversation_as_read_already_zero() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let service = make_service(message_dao.clone(), conversation_dao.clone());

        // 未读数已为 0
        conversation_dao.upsert(&make_conv("conv_zero", 0)).await.unwrap();

        // 应提前返回，不报错
        let result = service.mark_conversation_message_as_read("conv_zero".to_string(), 1).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_mark_all_conversation_as_read() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let service = make_service(message_dao.clone(), conversation_dao.clone());

        // 两个未读会话
        message_dao.batch_insert(&[
            make_local_msg("conv_a", "a_1", 1, "user_2"),
            make_local_msg("conv_b", "b_1", 1, "user_2"),
        ]).await.unwrap();
        conversation_dao.upsert(&make_conv("conv_a", 1)).await.unwrap();
        conversation_dao.upsert(&make_conv("conv_b", 3)).await.unwrap();

        service.mark_all_conversation_as_read().await.unwrap();

        let conv_a = conversation_dao.get_by_id("conv_a").await.unwrap().unwrap();
        let conv_b = conversation_dao.get_by_id("conv_b").await.unwrap().unwrap();
        assert_eq!(conv_a.unread_count, 0);
        assert_eq!(conv_b.unread_count, 0);
    }
}
