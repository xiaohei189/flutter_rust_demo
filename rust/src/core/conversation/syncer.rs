use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::conversation::Conversation;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn};

/// 会话同步器
pub struct ConversationSyncer {
    /// 事件总线
    event_bus: Arc<EventBus>,
    /// 同步版本
    sync_version: Arc<RwLock<i64>>,
    /// 是否首次同步
    is_first_sync: Arc<RwLock<bool>>,
}

impl ConversationSyncer {
    pub fn new(event_bus: Arc<EventBus>) -> Self {
        Self {
            event_bus,
            sync_version: Arc::new(RwLock::new(0)),
            is_first_sync: Arc::new(RwLock::new(true)),
        }
    }

    /// 执行增量同步
    pub async fn sync_incremental(&self, version: i64) -> Result<Vec<Conversation>> {
        info!("开始增量同步会话，版本: {}", version);
        self.event_bus.publish(SdkEvent::SyncStarted);

        let current_version = *self.sync_version.read().await;
        if version <= current_version {
            warn!("版本号未更新，跳过同步: current={}, new={}", current_version, version);
            return Ok(vec![]);
        }

        let conversations = self.pull_conversations_from_server(version).await?;
        
        self.process_conversations(&conversations).await?;
        
        *self.sync_version.write().await = version;
        *self.is_first_sync.write().await = false;

        self.event_bus.publish(SdkEvent::SyncFinished);
        info!("增量同步完成，同步 {} 个会话", conversations.len());

        Ok(conversations)
    }

    /// 执行全量同步
    pub async fn sync_full(&self) -> Result<Vec<Conversation>> {
        info!("开始全量同步会话");
        self.event_bus.publish(SdkEvent::SyncStarted);

        let conversations = self.pull_all_conversations_from_server().await?;
        
        self.process_conversations(&conversations).await?;
        
        *self.is_first_sync.write().await = false;

        self.event_bus.publish(SdkEvent::SyncFinished);
        info!("全量同步完成，同步 {} 个会话", conversations.len());

        Ok(conversations)
    }

    /// 从服务器拉取会话
    async fn pull_conversations_from_server(&self, version: i64) -> Result<Vec<Conversation>> {
        debug!("从服务器拉取增量会话，版本: {}", version);
        Ok(vec![])
    }

    /// 从服务器拉取所有会话
    async fn pull_all_conversations_from_server(&self) -> Result<Vec<Conversation>> {
        debug!("从服务器拉取所有会话");
        Ok(vec![])
    }

    /// 处理会话数据（插入/更新/删除）
    async fn process_conversations(&self, conversations: &[Conversation]) -> Result<()> {
        for conv in conversations {
            match conv.sync_action.as_deref() {
                Some("insert") | Some("update") => {
                    debug!("处理会话: {} ({})", conv.conversation_id, conv.sync_action.as_deref().unwrap_or("unknown"));
                }
                Some("delete") => {
                    debug!("删除会话: {}", conv.conversation_id);
                }
                _ => {
                    warn!("未知的同步操作: {:?}", conv.sync_action);
                }
            }
        }
        Ok(())
    }

    /// 获取当前同步版本
    pub async fn get_sync_version(&self) -> i64 {
        *self.sync_version.read().await
    }

    /// 检查是否首次同步
    pub async fn is_first_sync(&self) -> bool {
        *self.is_first_sync.read().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_conversation_syncer_creation() {
        let event_bus = Arc::new(EventBus::new());
        let syncer = ConversationSyncer::new(event_bus);

        assert_eq!(syncer.get_sync_version().await, 0);
        assert!(syncer.is_first_sync().await);
    }

    #[tokio::test]
    async fn test_conversation_syncer_incremental() {
        let event_bus = Arc::new(EventBus::new());
        let syncer = ConversationSyncer::new(event_bus);

        let result = syncer.sync_incremental(1).await;
        assert!(result.is_ok());
        assert_eq!(syncer.get_sync_version().await, 1);
        assert!(!syncer.is_first_sync().await);
    }

    #[tokio::test]
    async fn test_conversation_syncer_skip_same_version() {
        let event_bus = Arc::new(EventBus::new());
        let syncer = ConversationSyncer::new(event_bus);

        syncer.sync_incremental(1).await.unwrap();
        
        let result = syncer.sync_incremental(1).await;
        assert!(result.is_ok());
        assert!(result.unwrap().is_empty());
    }
}
