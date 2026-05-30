use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::conversation::Conversation;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info};

/// 会话管理器
pub struct ConversationManager {
    /// 会话缓存
    conversations: Arc<RwLock<HashMap<String, Conversation>>>,
    /// 事件总线
    event_bus: Arc<EventBus>,
}

impl ConversationManager {
    pub fn new(event_bus: Arc<EventBus>) -> Self {
        Self {
            conversations: Arc::new(RwLock::new(HashMap::new())),
            event_bus,
        }
    }

    /// 获取所有会话
    pub async fn get_all_conversations(&self) -> Vec<Conversation> {
        self.conversations
            .read()
            .await
            .values()
            .cloned()
            .collect()
    }

    /// 获取单个会话
    pub async fn get_conversation(&self, conversation_id: &str) -> Option<Conversation> {
        self.conversations.read().await.get(conversation_id).cloned()
    }

    /// 插入或更新会话
    pub async fn upsert_conversation(&self, conv: Conversation) {
        let conv_id = conv.conversation_id.clone();
        self.conversations.write().await.insert(conv_id, conv);
    }

    /// 批量插入或更新会话
    pub async fn upsert_conversations(&self, conversations: Vec<Conversation>) {
        let mut guard = self.conversations.write().await;
        for conv in conversations {
            guard.insert(conv.conversation_id.clone(), conv);
        }
    }

    /// 删除会话
    pub async fn delete_conversation(&self, conversation_id: &str) -> bool {
        self.conversations
            .write()
            .await
            .remove(conversation_id)
            .is_some()
    }

    /// 设置会话置顶状态
    pub async fn set_pinned(&self, conversation_id: &str, is_pinned: bool) -> Result<()> {
        if let Some(conv) = self.conversations.write().await.get_mut(conversation_id) {
            conv.is_pinned = is_pinned;
            info!("会话 {} 置顶状态设置为: {}", conversation_id, is_pinned);
            Ok(())
        } else {
            Err(SdkError::unknown(format!("会话不存在: {}", conversation_id)))
        }
    }

    /// 设置免打扰状态
    pub async fn set_private_chat(&self, conversation_id: &str, is_private: bool) -> Result<()> {
        if let Some(conv) = self.conversations.write().await.get_mut(conversation_id) {
            conv.is_private_chat = is_private;
            info!("会话 {} 免打扰状态设置为: {}", conversation_id, is_private);
            Ok(())
        } else {
            Err(SdkError::unknown(format!("会话不存在: {}", conversation_id)))
        }
    }

    /// 更新未读消息数
    pub async fn update_unread_count(&self, conversation_id: &str, unread_count: i32) -> Result<()> {
        if let Some(conv) = self.conversations.write().await.get_mut(conversation_id) {
            conv.unread_count = unread_count;
            debug!("会话 {} 未读消息数更新为: {}", conversation_id, unread_count);
            Ok(())
        } else {
            Err(SdkError::unknown(format!("会话不存在: {}", conversation_id)))
        }
    }

    /// 设置草稿
    pub async fn set_draft(&self, conversation_id: &str, draft_text: &str) -> Result<()> {
        if let Some(conv) = self.conversations.write().await.get_mut(conversation_id) {
            conv.draft_text = draft_text.to_string();
            conv.draft_text_time = chrono::Utc::now().timestamp_millis();
            debug!("会话 {} 草稿已设置", conversation_id);
            Ok(())
        } else {
            Err(SdkError::unknown(format!("会话不存在: {}", conversation_id)))
        }
    }

    /// 清空草稿
    pub async fn clear_draft(&self, conversation_id: &str) -> Result<()> {
        self.set_draft(conversation_id, "").await
    }

    /// 获取置顶会话列表
    pub async fn get_pinned_conversations(&self) -> Vec<Conversation> {
        self.conversations
            .read()
            .await
            .values()
            .filter(|conv| conv.is_pinned)
            .cloned()
            .collect()
    }

    /// 获取会话数量
    pub async fn count(&self) -> usize {
        self.conversations.read().await.len()
    }

    /// 清空所有会话
    pub async fn clear(&self) {
        self.conversations.write().await.clear();
        info!("会话数据已清空");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
        }
    }

    #[tokio::test]
    async fn test_conversation_manager_creation() {
        let event_bus = Arc::new(EventBus::new());
        let manager = ConversationManager::new(event_bus);

        assert_eq!(manager.count().await, 0);
    }

    #[tokio::test]
    async fn test_conversation_manager_upsert() {
        let event_bus = Arc::new(EventBus::new());
        let manager = ConversationManager::new(event_bus);

        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await;

        assert_eq!(manager.count().await, 1);

        let retrieved = manager.get_conversation("conv_1").await;
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().conversation_id, "conv_1");
    }

    #[tokio::test]
    async fn test_conversation_manager_delete() {
        let event_bus = Arc::new(EventBus::new());
        let manager = ConversationManager::new(event_bus);

        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await;
        assert_eq!(manager.count().await, 1);

        let deleted = manager.delete_conversation("conv_1").await;
        assert!(deleted);
        assert_eq!(manager.count().await, 0);
    }

    #[tokio::test]
    async fn test_conversation_manager_set_pinned() {
        let event_bus = Arc::new(EventBus::new());
        let manager = ConversationManager::new(event_bus);

        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await;

        manager.set_pinned("conv_1", true).await.unwrap();
        let conv = manager.get_conversation("conv_1").await.unwrap();
        assert!(conv.is_pinned);

        manager.set_pinned("conv_1", false).await.unwrap();
        let conv = manager.get_conversation("conv_1").await.unwrap();
        assert!(!conv.is_pinned);
    }

    #[tokio::test]
    async fn test_conversation_manager_update_unread_count() {
        let event_bus = Arc::new(EventBus::new());
        let manager = ConversationManager::new(event_bus);

        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await;

        manager.update_unread_count("conv_1", 5).await.unwrap();
        let conv = manager.get_conversation("conv_1").await.unwrap();
        assert_eq!(conv.unread_count, 5);
    }

    #[tokio::test]
    async fn test_conversation_manager_set_draft() {
        let event_bus = Arc::new(EventBus::new());
        let manager = ConversationManager::new(event_bus);

        let conv = create_test_conversation("conv_1");
        manager.upsert_conversation(conv).await;

        manager.set_draft("conv_1", "test draft").await.unwrap();
        let conv = manager.get_conversation("conv_1").await.unwrap();
        assert_eq!(conv.draft_text, "test draft");

        manager.clear_draft("conv_1").await.unwrap();
        let conv = manager.get_conversation("conv_1").await.unwrap();
        assert_eq!(conv.draft_text, "");
    }

    #[tokio::test]
    async fn test_conversation_manager_get_pinned() {
        let event_bus = Arc::new(EventBus::new());
        let manager = ConversationManager::new(event_bus);

        let conv1 = create_test_conversation("conv_1");
        let mut conv2 = create_test_conversation("conv_2");
        conv2.is_pinned = true;

        manager.upsert_conversation(conv1).await;
        manager.upsert_conversation(conv2).await;

        let pinned = manager.get_pinned_conversations().await;
        assert_eq!(pinned.len(), 1);
        assert_eq!(pinned[0].conversation_id, "conv_2");
    }
}
