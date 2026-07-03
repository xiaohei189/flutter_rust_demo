use crate::domain::error::types::{Result, SdkError};
use crate::domain::listener::conversation::ConversationListener;
use crate::domain::model::conversation::Conversation;
use crate::infra::database::conversation_dao::ConversationDao;
use crate::infra::database::message_dao::MessageDao;
use crate::infra::database::models::LocalConversation;
use std::sync::Arc;
use tracing::{debug, info};

pub struct ConversationManager {
    dao: Arc<ConversationDao>,
    message_dao: Arc<MessageDao>,
    conversation_listener: Arc<ConversationListener>,
}

impl ConversationManager {
    pub fn new(dao: Arc<ConversationDao>, message_dao: Arc<MessageDao>, conversation_listener: Arc<ConversationListener>) -> Self {
        Self { dao, message_dao, conversation_listener }
    }

    pub fn dao(&self) -> Arc<ConversationDao> {
        self.dao.clone()
    }

    pub async fn get_all_conversations(&self) -> Result<Vec<Conversation>> {
        let mut local_convs = self.dao.get_all().await?;
        
        // 回填空的 latest_msg（从消息数据库获取最新消息）
        for conv in &mut local_convs {
            if conv.latest_msg.is_empty() {
                if let Ok(messages) = self.message_dao.get_latest(&conv.conversation_id, 1).await {
                    if let Some(latest) = messages.first() {
                        conv.latest_msg = latest.content.clone();
                        conv.latest_msg_send_time = latest.send_time;
                        // 更新数据库
                        let _ = self.dao.update_latest_msg(
                            &conv.conversation_id,
                            &latest.content,
                            latest.send_time,
                        ).await;
                    }
                }
            }
        }
        
        Ok(local_convs.into_iter().map(|lc| local_to_domain(lc)).collect())
    }

    pub async fn get_conversation(&self, conversation_id: &str) -> Result<Option<Conversation>> {
        match self.dao.get_by_id(conversation_id).await? {
            Some(lc) => Ok(Some(local_to_domain(lc))),
            None => Ok(None),
        }
    }

    pub async fn upsert_conversation(&self, conv: Conversation) -> Result<()> {
        let local = domain_to_local(conv.clone());
        self.dao.upsert(&local).await?;
        self.conversation_listener.on_changed.notify(&vec![conv]);
        Ok(())
    }

    pub async fn upsert_conversations(&self, conversations: Vec<Conversation>) -> Result<()> {
        for conv in conversations {
            self.upsert_conversation(conv).await?;
        }
        Ok(())
    }

    pub async fn delete_conversation(&self, conversation_id: &str) -> Result<()> {
        self.dao.delete(conversation_id).await?;
        self.conversation_listener.on_deleted.notify(&vec![conversation_id.to_string()]);
        Ok(())
    }

    pub async fn set_pinned(&self, conversation_id: &str, is_pinned: bool) -> Result<()> {
        self.dao.set_pinned(conversation_id, is_pinned).await?;
        info!("会话 {} 置顶状态设置为: {}", conversation_id, is_pinned);
        Ok(())
    }

    pub async fn set_private_chat(&self, conversation_id: &str, is_private: bool) -> Result<()> {
        self.dao.set_private_chat(conversation_id, is_private).await?;
        info!("会话 {} 免打扰状态设置为: {}", conversation_id, is_private);
        Ok(())
    }

    pub async fn update_unread_count(&self, conversation_id: &str, unread_count: i32) -> Result<()> {
        self.dao.update_unread_count(conversation_id, unread_count).await?;
        debug!("会话 {} 未读消息数更新为: {}", conversation_id, unread_count);
        Ok(())
    }

    pub async fn set_draft(&self, conversation_id: &str, draft_text: &str) -> Result<()> {
        let draft_time = chrono::Utc::now().timestamp_millis();
        self.dao.set_draft(conversation_id, draft_text, draft_time).await?;
        debug!("会话 {} 草稿已设置", conversation_id);
        Ok(())
    }

    pub async fn clear_draft(&self, conversation_id: &str) -> Result<()> {
        self.set_draft(conversation_id, "").await
    }

    pub async fn get_pinned_conversations(&self) -> Result<Vec<Conversation>> {
        let local_convs = self.dao.get_pinned().await?;
        Ok(local_convs.into_iter().map(|lc| local_to_domain(lc)).collect())
    }

    pub async fn count(&self) -> Result<usize> {
        self.dao.count().await
    }

    pub async fn clear_all(&self) -> Result<()> {
        self.dao.clear_all().await?;
        info!("会话数据已清空");
        Ok(())
    }
}

fn local_to_domain(lc: LocalConversation) -> Conversation {
    Conversation {
        conversation_id: lc.conversation_id,
        conversation_type: lc.conversation_type,
        user_id: lc.user_id,
        group_id: lc.group_id,
        show_name: lc.show_name,
        face_url: lc.face_url,
        recv_msg_opt: lc.recv_msg_opt,
        unread_count: lc.unread_count,
        group_at_type: lc.group_at_type,
        latest_msg_seq: lc.max_seq,
        latest_msg: lc.latest_msg,
        latest_msg_send_time: lc.latest_msg_send_time,
        draft_text: lc.draft_text,
        draft_text_time: lc.draft_text_time,
        is_pinned: lc.is_pinned != 0,
        is_private_chat: lc.is_private_chat != 0,
        is_not_in_group: lc.is_not_in_group != 0,
        update_flag: 0,
        sync_action: None,
        update_unread_count_time: lc.update_unread_count_time,
        max_seq: lc.max_seq,
        min_seq: lc.min_seq,
        is_msg_destruct: lc.is_msg_destruct != 0,
        msg_destruct_time: lc.msg_destruct_time,
        is_private: lc.is_private_chat != 0,
        burn_duration: lc.burn_duration,
        ex: lc.ex,
    }
}

pub fn domain_to_local(conv: Conversation) -> LocalConversation {
    LocalConversation {
        conversation_id: conv.conversation_id,
        conversation_type: conv.conversation_type,
        user_id: conv.user_id,
        group_id: conv.group_id,
        show_name: conv.show_name,
        face_url: conv.face_url,
        latest_msg: conv.latest_msg,
        latest_msg_send_time: conv.latest_msg_send_time,
        unread_count: conv.unread_count,
        recv_msg_opt: conv.recv_msg_opt,
        is_pinned: if conv.is_pinned { 1 } else { 0 },
        is_private_chat: if conv.is_private_chat { 1 } else { 0 },
        burn_duration: 0,
        group_at_type: conv.group_at_type,
        is_not_in_group: if conv.is_not_in_group { 1 } else { 0 },
        update_unread_count_time: 0,
        attached_info: String::new(),
        ex: String::new(),
        draft_text: conv.draft_text,
        draft_text_time: conv.draft_text_time,
        max_seq: conv.latest_msg_seq,
        min_seq: 0,
        is_msg_destruct: 0,
        msg_destruct_time: 0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

    fn create_test_conversation(id: &str) -> Conversation {
        Conversation {
            conversation_id: id.to_string(),
            conversation_type: 1,
            user_id: "user_1".to_string(),
            group_id: String::new(),
            show_name: format!("Conversation {}", id),
            face_url: String::new(),
            recv_msg_opt: 0,
            unread_count: 0,
            group_at_type: 0,
            latest_msg_seq: 0,
            latest_msg: String::new(),
            latest_msg_send_time: 0,
            draft_text: String::new(),
            draft_text_time: 0,
            is_pinned: false,
            is_private_chat: false,
            is_not_in_group: false,
            update_flag: 0,
            sync_action: None,
            update_unread_count_time: 0,
            max_seq: 0,
            min_seq: 0,
            is_msg_destruct: false,
            msg_destruct_time: 0,
            is_private: false,
            burn_duration: 0,
            ex: String::new(),
        }
    }

    #[tokio::test]
    async fn test_conversation_manager_creation() {
        let pool = create_pool_memory().await.unwrap();
        let dao = Arc::new(ConversationDao::new(pool.clone()));
        let message_dao = Arc::new(MessageDao::new(pool));
        let conversation_listener = Arc::new(ConversationListener::new());
        let manager = ConversationManager::new(dao, message_dao, conversation_listener);

        assert_eq!(manager.count().await.unwrap(), 0);
    }

    #[tokio::test]
    async fn test_conversation_manager_upsert() {
        let pool = create_pool_memory().await.unwrap();
        let dao = Arc::new(ConversationDao::new(pool.clone()));
        let message_dao = Arc::new(MessageDao::new(pool));
        let conversation_listener = Arc::new(ConversationListener::new());
        let manager = ConversationManager::new(dao, message_dao, conversation_listener);

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
        let dao = Arc::new(ConversationDao::new(pool.clone()));
        let message_dao = Arc::new(MessageDao::new(pool));
        let conversation_listener = Arc::new(ConversationListener::new());
        let manager = ConversationManager::new(dao, message_dao, conversation_listener);

        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await.unwrap();
        assert_eq!(manager.count().await.unwrap(), 1);

        manager.delete_conversation("conv_1").await.unwrap();
        assert_eq!(manager.count().await.unwrap(), 0);
    }

    #[tokio::test]
    async fn test_conversation_manager_set_pinned() {
        let pool = create_pool_memory().await.unwrap();
        let dao = Arc::new(ConversationDao::new(pool.clone()));
        let message_dao = Arc::new(MessageDao::new(pool));
        let conversation_listener = Arc::new(ConversationListener::new());
        let manager = ConversationManager::new(dao, message_dao, conversation_listener);

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
        let dao = Arc::new(ConversationDao::new(pool.clone()));
        let message_dao = Arc::new(MessageDao::new(pool));
        let conversation_listener = Arc::new(ConversationListener::new());
        let manager = ConversationManager::new(dao, message_dao, conversation_listener);

        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await.unwrap();

        manager.update_unread_count("conv_1", 5).await.unwrap();
        let conv = manager.get_conversation("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 5);
    }

    #[tokio::test]
    async fn test_conversation_manager_set_draft() {
        let pool = create_pool_memory().await.unwrap();
        let dao = Arc::new(ConversationDao::new(pool.clone()));
        let message_dao = Arc::new(MessageDao::new(pool));
        let conversation_listener = Arc::new(ConversationListener::new());
        let manager = ConversationManager::new(dao, message_dao, conversation_listener);

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
