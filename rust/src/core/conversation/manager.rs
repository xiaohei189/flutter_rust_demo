//! 会话管理器 - 本地 CRUD（置顶、免打扰、未读数、草稿等）

use crate::domain::error::Result;
use crate::event::publisher::EventPublisher;
use crate::event::listener::conversation::ConversationEvent;
use crate::domain::model::local::LocalConversation;
use crate::sdk::context::Stores;

use std::sync::Arc;
use tracing::{debug, info};

pub struct ConversationManager {
    /// 外部依赖
    stores: Arc<Stores>,
    /// 事件
    pub(crate) events: EventPublisher<ConversationEvent>,
}

impl ConversationManager {
    pub fn new(stores: Arc<Stores>) -> Self {
        Self {
            stores,
            events: EventPublisher::new(),
        }
    }

    pub fn set_event_sender(&self, tx: tokio::sync::mpsc::UnboundedSender<ConversationEvent>) {
        self.events.set_sender(tx);
    }

    pub(crate) fn send(&self, e: ConversationEvent) {
        tracing::info!("[SEND] {:?}, has_subscriber={}", &e, self.events.has_subscriber());
        self.events.publish(e);
    }

    pub fn dao(&self) -> Arc<dyn crate::domain::repository::conversation::ConversationRepository> {
        self.stores.conversation_repo.clone()
}

    pub async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        let mut local_convs = self.stores.conversation_repo.get_all().await?;

        // 回填空的 latest_msg（从消息数据库获取最新消息）
        for conv in &mut local_convs {
            if conv.latest_msg.is_empty() {
                if let Ok(messages) = self.stores.message_repo.get_latest(&conv.conversation_id, 1).await {
                    if let Some(latest) = messages.first() {
                        conv.latest_msg = latest.content.clone();
                        conv.latest_msg_send_time = latest.send_time;
                        let _ = self.stores.conversation_repo.update_latest_msg(
                            &conv.conversation_id,
                            &latest.content,
                            latest.send_time,
                        ).await;
                    }
                }
            }
        }

        Ok(local_convs)
    }

    pub async fn get_conversation(&self, conversation_id: &str) -> Result<Option<LocalConversation>> {
        self.stores.conversation_repo.get_by_id(conversation_id).await
    }

    pub async fn upsert_conversation(&self, conv: LocalConversation) -> Result<()> {
        self.stores.conversation_repo.upsert(&conv).await?;
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
        self.stores.conversation_repo.delete(conversation_id).await?;
        self.send(ConversationEvent::Deleted(vec![conversation_id.to_string()]));
        Ok(())
    }

    pub async fn set_pinned(&self, conversation_id: &str, is_pinned: bool) -> Result<()> {
        self.stores.conversation_repo.set_pinned(conversation_id, is_pinned).await?;
        info!("会话 {} 置顶状态设置为: {}", conversation_id, is_pinned);
        Ok(())
    }

    pub async fn set_private_chat(&self, conversation_id: &str, is_private: bool) -> Result<()> {
        self.stores.conversation_repo.set_private_chat(conversation_id, is_private).await?;
        info!("会话 {} 免打扰状态设置为: {}", conversation_id, is_private);
        Ok(())
    }

    pub async fn update_unread_count(&self, conversation_id: &str, unread_count: i32) -> Result<()> {
        self.stores.conversation_repo.update_unread_count(conversation_id, unread_count).await?;
        debug!("会话 {} 未读消息数更新为: {}", conversation_id, unread_count);
        Ok(())
    }

    pub async fn set_draft(&self, conversation_id: &str, draft_text: &str) -> Result<()> {
        let draft_time = chrono::Utc::now().timestamp_millis();
        self.stores.conversation_repo.set_draft(conversation_id, draft_text, draft_time).await?;
        debug!("会话 {} 草稿已设置", conversation_id);
        Ok(())
    }

    pub async fn clear_draft(&self, conversation_id: &str) -> Result<()> {
        self.set_draft(conversation_id, "").await
    }

    pub async fn get_pinned_conversations(&self) -> Result<Vec<LocalConversation>> {
        self.stores.conversation_repo.get_pinned().await
    }

    pub async fn count(&self) -> Result<i32> {
        self.stores.conversation_repo.count().await
    }

    pub async fn clear_all(&self) -> Result<()> {
        self.stores.conversation_repo.clear_all().await?;
        info!("会话数据已清空");
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;
    use crate::infra::database::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};

    fn make_test_stores(pool: sqlx::SqlitePool) -> Arc<Stores> {
        Arc::new(Stores {
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
        let manager = ConversationManager::new(make_test_stores(pool));
        assert_eq!(manager.count().await.unwrap(), 0);
    }

    #[tokio::test]
    async fn test_conversation_manager_upsert() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationManager::new(make_test_stores(pool));
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
        let manager = ConversationManager::new(make_test_stores(pool));
        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await.unwrap();
        assert_eq!(manager.count().await.unwrap(), 1);
        manager.delete_conversation("conv_1").await.unwrap();
        assert_eq!(manager.count().await.unwrap(), 0);
    }

    #[tokio::test]
    async fn test_conversation_manager_set_pinned() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationManager::new(make_test_stores(pool));
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
        let manager = ConversationManager::new(make_test_stores(pool));
        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await.unwrap();
        manager.update_unread_count("conv_1", 5).await.unwrap();
        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 5);
    }

    #[tokio::test]
    async fn test_conversation_manager_set_draft() {
        let pool = create_pool_memory().await.unwrap();
        let manager = ConversationManager::new(make_test_stores(pool));
        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await.unwrap();
        manager.set_draft("conv_1", "test draft").await.unwrap();
        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.draft_text, "test draft");
        manager.clear_draft("conv_1").await.unwrap();
        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.draft_text, "");
    }
}
