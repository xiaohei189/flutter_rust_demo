use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn};

/// 会话消息同步状态
#[derive(Clone, Debug)]
pub struct ConversationSyncState {
    /// 会话 ID
    pub conversation_id: String,
    /// 本地最大 seq
    pub max_seq: i64,
    /// 服务器最大 seq
    pub server_max_seq: i64,
    /// 是否正在同步
    pub is_syncing: bool,
}

/// 消息同步器
pub struct MessageSyncer {
    /// 各会话的同步状态
    sync_states: Arc<RwLock<HashMap<String, ConversationSyncState>>>,
    /// 事件总线
    event_bus: Arc<EventBus>,
    /// 并发拉取限制
    max_concurrent_pulls: usize,
}

impl MessageSyncer {
    pub fn new(event_bus: Arc<EventBus>) -> Self {
        Self {
            sync_states: Arc::new(RwLock::new(HashMap::new())),
            event_bus,
            max_concurrent_pulls: 5,
        }
    }

    /// 初始化会话同步状态
    pub async fn init_conversation(&self, conversation_id: String, max_seq: i64) {
        let state = ConversationSyncState {
            conversation_id: conversation_id.clone(),
            max_seq,
            server_max_seq: 0,
            is_syncing: false,
        };
        let conv_id = conversation_id.clone();
        self.sync_states
            .write()
            .await
            .insert(conversation_id, state);
        debug!("初始化会话同步状态: conversation_id={}, max_seq={}", conv_id, max_seq);
    }

    /// 更新本地最大 seq
    pub async fn update_local_max_seq(&self, conversation_id: &str, seq: i64) {
        if let Some(state) = self.sync_states.write().await.get_mut(conversation_id) {
            if seq > state.max_seq {
                state.max_seq = seq;
            }
        }
    }

    /// 更新服务器最大 seq
    pub async fn update_server_max_seq(&self, conversation_id: &str, server_max_seq: i64) {
        if let Some(state) = self.sync_states.write().await.get_mut(conversation_id) {
            state.server_max_seq = server_max_seq;
        }
    }

    /// 检查是否需要同步
    pub async fn needs_sync(&self, conversation_id: &str) -> bool {
        if let Some(state) = self.sync_states.read().await.get(conversation_id) {
            return state.max_seq < state.server_max_seq && !state.is_syncing;
        }
        true
    }

    /// 标记同步开始
    pub async fn mark_sync_started(&self, conversation_id: &str) {
        if let Some(state) = self.sync_states.write().await.get_mut(conversation_id) {
            state.is_syncing = true;
        }
    }

    /// 标记同步完成
    pub async fn mark_sync_finished(&self, conversation_id: &str) {
        if let Some(state) = self.sync_states.write().await.get_mut(conversation_id) {
            state.is_syncing = false;
        }
    }

    /// 获取需要同步的会话列表
    pub async fn get_conversations_needing_sync(&self) -> Vec<String> {
        let states = self.sync_states.read().await;
        states
            .iter()
            .filter(|(_, state)| state.max_seq < state.server_max_seq && !state.is_syncing)
            .map(|(id, _)| id.clone())
            .collect()
    }

    /// 通知同步进度
    fn notify_sync_progress(&self, conversation_id: &str, pulled_count: usize) {
        self.event_bus.publish(SdkEvent::SyncProgress {
            progress: 0,
            message: format!("正在拉取 {} 的消息: {} 条", conversation_id, pulled_count),
        });
    }

    /// 通知同步完成
    fn notify_sync_finished(&self, conversation_id: &str) {
        info!("会话消息同步完成: {}", conversation_id);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_message_syncer_init() {
        let event_bus = Arc::new(EventBus::new());
        let syncer = MessageSyncer::new(event_bus);

        syncer
            .init_conversation("conv_1".to_string(), 100)
            .await;

        assert!(syncer.needs_sync("conv_1").await);
    }

    #[tokio::test]
    async fn test_message_syncer_seq_update() {
        let event_bus = Arc::new(EventBus::new());
        let syncer = MessageSyncer::new(event_bus);

        syncer
            .init_conversation("conv_1".to_string(), 100)
            .await;
        syncer.update_server_max_seq("conv_1", 200).await;

        assert!(syncer.needs_sync("conv_1").await);

        syncer.update_local_max_seq("conv_1", 200).await;
        assert!(!syncer.needs_sync("conv_1").await);
    }

    #[tokio::test]
    async fn test_message_syncer_sync_marking() {
        let event_bus = Arc::new(EventBus::new());
        let syncer = MessageSyncer::new(event_bus);

        syncer
            .init_conversation("conv_1".to_string(), 100)
            .await;
        syncer.update_server_max_seq("conv_1", 200).await;

        assert!(syncer.needs_sync("conv_1").await);

        syncer.mark_sync_started("conv_1").await;
        assert!(!syncer.needs_sync("conv_1").await);

        syncer.mark_sync_finished("conv_1").await;
        assert!(syncer.needs_sync("conv_1").await);
    }

    #[tokio::test]
    async fn test_message_syncer_get_conversations_needing_sync() {
        let event_bus = Arc::new(EventBus::new());
        let syncer = MessageSyncer::new(event_bus);

        syncer
            .init_conversation("conv_1".to_string(), 100)
            .await;
        syncer.update_server_max_seq("conv_1", 200).await;

        syncer
            .init_conversation("conv_2".to_string(), 300)
            .await;
        syncer.update_server_max_seq("conv_2", 300).await;

        let needing_sync = syncer.get_conversations_needing_sync().await;
        assert_eq!(needing_sync.len(), 1);
        assert!(needing_sync.contains(&"conv_1".to_string()));
    }
}
