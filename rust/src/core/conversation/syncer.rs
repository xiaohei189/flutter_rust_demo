//! 会话同步器 - 增量/全量同步（对齐 Go SDK `IncrSyncConversations` + `VersionSynchronizer`）

use crate::domain::error::types::{Result, SdkError};
use crate::domain::listener::conversation::ConversationEvent;
use crate::domain::model::conversation::Conversation;
use crate::infra::database::conversation_dao::ConversationDao;
use crate::infra::database::sync_version_dao::SyncVersionDao;

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn, error};

use super::api::{ConversationServerApi, HttpConversationApi};
use super::converter::{domain_to_local, server_to_domain};

// ========== 常量 ==========

/// 版本同步表名（对齐 Go SDK `model_struct.LocalConversation{}.TableName()`）
const CONVERSATION_TABLE_NAME: &str = "local_conversations";

pub struct ConversationSyncer {
    api: Arc<dyn ConversationServerApi>,
    dao: Arc<ConversationDao>,
    pub(crate) event_tx: Arc<std::sync::Mutex<Option<tokio::sync::mpsc::UnboundedSender<ConversationEvent>>>>,
    sync_version_dao: Arc<SyncVersionDao>,
    user_id: Arc<RwLock<String>>,
    /// WebSocket 连接管理器（用于 sync_conversation_hash_read_seqs 的 RPC 调用）
    connection: Option<Arc<crate::core::connection::manager::ConnectionManager>>,
    /// 增量同步互斥锁（对齐 Go SDK `conversationSyncMutex`）
    sync_mutex: tokio::sync::Mutex<()>,
}

impl ConversationSyncer {
    pub fn new(
        http_client: Arc<crate::infra::http::client::HttpApiClient>,
        dao: Arc<ConversationDao>,
        sync_version_dao: Arc<SyncVersionDao>,
        user_id: String,
    ) -> Self {
        Self {
            api: Arc::new(HttpConversationApi::new(http_client)),
            dao,
            event_tx: Arc::new(std::sync::Mutex::new(None)),
            sync_version_dao,
            user_id: Arc::new(RwLock::new(user_id)),
            connection: None,
            sync_mutex: tokio::sync::Mutex::new(()),
        }
    }

    /// 使用自定义 API 实现构造（用于测试 mock）
    #[cfg(test)]
    pub fn new_with_api(
        api: Arc<dyn ConversationServerApi>,
        dao: Arc<ConversationDao>,
        sync_version_dao: Arc<SyncVersionDao>,
        user_id: String,
    ) -> Self {
        Self {
            api,
            dao,
            event_tx: Arc::new(std::sync::Mutex::new(None)),
            sync_version_dao,
            user_id: Arc::new(RwLock::new(user_id)),
            connection: None,
            sync_mutex: tokio::sync::Mutex::new(()),
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

    /// 设置 WebSocket 连接管理器（用于 Hash Read Seq 同步）
    pub fn set_connection(&mut self, connection: Arc<crate::core::connection::manager::ConnectionManager>) {
        self.connection = Some(connection);
    }

    pub async fn set_user_id(&self, user_id: String) {
        let mut uid = self.user_id.write().await;
        *uid = user_id;
    }

    // ========================================================================
    // 增量同步（对齐 Go SDK `IncrSyncConversations` + `VersionSynchronizer`）
    // ========================================================================

    /// 增量同步会话（版本号持久化到数据库，对齐 Go SDK `VersionSynchronizer.IncrementalSync`）
    pub async fn sync_incremental(&self) -> Result<Vec<Conversation>> {
        let user_id = self.user_id.read().await.clone();

        // 1. 从数据库获取本地版本信息（对齐 Go SDK `getVersionInfo`）
        let (local_version_id, local_version) = match self
            .sync_version_dao
            .get_version_sync(CONVERSATION_TABLE_NAME, &user_id)
            .await?
        {
            Some((vid, v)) => (vid, v),
            None => (String::new(), 0),
        };

        info!(
            "开始增量同步会话，版本: {}, version_id: {}",
            local_version, local_version_id
        );

        // 注意：不发布 SyncStarted/SyncFinished 事件，避免与 MessageSyncer 冲突
        // 会话变化通过 ConversationChanged/ConversationDeleted 事件单独通知

        // 2. 请求增量数据
        let resp = match self
            .api
            .pull_incremental(user_id.clone(), local_version, local_version_id.clone())
            .await
        {
            Ok(r) => r,
            Err(e) => {
                return Err(e);
            }
        };

        // 3. 如果服务端返回 full=true，回退到全量同步（对齐 Go SDK `FullSyncer`）
        if resp.full {
            info!("增量同步返回 full=true，执行全量同步");
            return self.sync_full().await;
        }

        // 4. 处理增量变更
        for conv_id in &resp.delete {
            self.dao.delete(conv_id).await?;
            self.send(ConversationEvent::Deleted(vec![conv_id.clone()]));
        }

        for s in &resp.update {
            let domain = server_to_domain(s.clone());
            let local = domain_to_local(domain);
            self.dao.upsert_preserving_local_fields(&local).await?;
        }

        for s in &resp.insert {
            let domain = server_to_domain(s.clone());
            let local = domain_to_local(domain);
            self.dao.upsert_preserving_local_fields(&local).await?;
        }

        if !resp.update.is_empty() || !resp.insert.is_empty() {
            let changed: Vec<Conversation> = resp
                .update
                .iter()
                .chain(resp.insert.iter())
                .map(|s| server_to_domain(s.clone()))
                .collect();
            self.send(ConversationEvent::Changed(changed));
        }

        // 5. 持久化版本号到数据库（对齐 Go SDK `updateVersionInfo`）
        if let Err(e) = self
            .sync_version_dao
            .set_version_sync(
                CONVERSATION_TABLE_NAME,
                &user_id,
                &resp.version_id,
                resp.version,
            )
            .await
        {
            warn!("更新会话同步版本失败: {}", e);
        }

        info!(
            "增量同步完成，insert={}, update={}, delete={}",
            resp.insert.len(),
            resp.update.len(),
            resp.delete.len()
        );

        let inserted_convs: Vec<Conversation> =
            resp.insert.iter().map(|s| server_to_domain(s.clone())).collect();
        Ok(inserted_convs)
    }

    /// 加锁版本的增量同步（对齐 Go SDK `IncrSyncConversationsWithLock`）
    pub async fn sync_incremental_with_lock(&self) -> Result<Vec<Conversation>> {
        let _guard = self.sync_mutex.lock().await;
        self.sync_incremental().await
    }

    // ========================================================================
    // 全量同步
    // ========================================================================

    pub async fn sync_full(&self) -> Result<Vec<Conversation>> {
        info!("开始全量同步会话");

        let user_id = self.user_id.read().await.clone();
        let resp = match self.api.pull_all(user_id).await {
            Ok(r) => r,
            Err(e) => {
                return Err(e);
            }
        };

        let conversations: Vec<Conversation> = resp
            .conversations
            .unwrap_or_default()
            .into_iter()
            .map(server_to_domain)
            .collect();

        // 保留本地 latest_msg 等字段：先记录本地所有会话 ID
        let local_ids: std::collections::HashSet<String> = self
            .dao
            .get_all()
            .await
            .unwrap_or_default()
            .into_iter()
            .map(|lc| lc.conversation_id)
            .collect();

        // 使用保留本地字段的 upsert 方法插入所有服务端会话
        for conv in &conversations {
            let local = domain_to_local(conv.clone());
            self.dao.upsert_preserving_local_fields(&local).await?;
        }

        // 删除服务端不再返回的会话（即本地存在但服务端不存在的）
        let server_ids: std::collections::HashSet<String> = conversations
            .iter()
            .map(|c| c.conversation_id.clone())
            .collect();
        for local_id in &local_ids {
            if !server_ids.contains(local_id) {
                self.dao.delete(local_id).await?;
            }
        }

        info!("全量同步完成，同步 {} 个会话", conversations.len());
        self.send(ConversationEvent::Changed(conversations.clone()));

        // 总未读数由 handler.rs 统一发布
        Ok(conversations)
    }

    // ========================================================================
    // Hash Read Seq 同步（对齐 Go SDK `SyncAllConversationHashReadSeqs`）
    // ========================================================================

    /// 从服务端同步所有会话的 maxSeq 和 hasReadSeq（对齐 Go SDK `sync.go:11-151`）
    ///
    /// 用于准确计算未读数：unreadCount = maxSeq - hasReadSeq
    /// 关键差异：Go SDK 会为本地不存在的会话从服务端拉取完整数据并插入，
    /// 此处补齐该逻辑。
    pub async fn sync_conversation_hash_read_seqs(
        &self,
        max_seq_recorder: &crate::core::message::handler::MaxSeqRecorder,
    ) -> Result<()> {
        let connection = match &self.connection {
            Some(c) => c,
            None => {
                warn!("[ConvSync] sync_conversation_hash_read_seqs: connection 未设置，跳过");
                return Ok(());
            }
        };

        let user_id = self.user_id.read().await.clone();
        use crate::domain::constant::types::ws_req_identifier;
        use crate::protocol::msg::{
            GetConversationsHasReadAndMaxSeqReq, GetConversationsHasReadAndMaxSeqResp,
        };

        info!("[ConvSync] get_conversations_hash_read_seq 请求: user_id={}", user_id);

        let resp: GetConversationsHasReadAndMaxSeqResp = connection
            .send_rpc(
                ws_req_identifier::GET_CONV_MAX_READ_SEQ,
                &GetConversationsHasReadAndMaxSeqReq {
                    user_id,
                    conversation_i_ds: vec![],
                    return_pinned: false,
                },
            )
            .await
            .map_err(|e| {
                error!("[ConvSync] 获取会话 Hash Read Seq 失败: {}", e);
                SdkError::network(format!("sync hash read seq failed: {}", e))
            })?;

        info!("[ConvSync] get_conversations_hash_read_seq: {} conversations", resp.seqs.len());

        if resp.seqs.is_empty() {
            return Ok(());
        }

        let mut changed_ids: Vec<String> = Vec::new();
        let mut conversation_ids_need_sync: Vec<String> = Vec::new();

        // 获取所有本地会话
        let local_conversations = self.dao.get_all().await.unwrap_or_default();
        let mut local_map: HashMap<String, crate::infra::database::models::LocalConversation> =
            HashMap::new();
        for conv in local_conversations {
            local_map.insert(conv.conversation_id.clone(), conv);
        }

        // 遍历服务端返回的 seqs
        for (conv_id, seq_info) in &resp.seqs {
            // 更新 MaxSeqRecorder 内存记录（对齐 Go SDK maxSeqRecorder.Set）
            max_seq_recorder.set(conv_id, seq_info.max_seq);

            // 计算未读数：maxSeq - hasReadSeq
            let unread_count = if seq_info.max_seq > seq_info.has_read_seq {
                (seq_info.max_seq - seq_info.has_read_seq) as i32
            } else {
                0
            };

            if let Some(local_conv) = local_map.get(conv_id) {
                // 本地存在该会话 -> 检查是否需要更新未读数
                if local_conv.unread_count != unread_count {
                    if let Err(e) = self.dao.update_unread_count(conv_id, unread_count).await {
                        error!(
                            "[ConvSync] 更新会话 {} 未读数失败: {}",
                            conv_id, e
                        );
                    }
                    changed_ids.push(conv_id.clone());
                }
            } else {
                // 本地不存在该会话 -> 收集待同步列表（对齐 Go SDK sync.go:82）
                conversation_ids_need_sync.push(conv_id.clone());
            }
        }

        // 同步不存在于本地的会话（对齐 Go SDK sync.go:87-123）
        if !conversation_ids_need_sync.is_empty() {
            info!(
                "[ConvSync] {} 个会话不在本地，从服务端拉取",
                conversation_ids_need_sync.len()
            );
            let user_id = self.user_id.read().await.clone();
            match self
                .api
                .pull_conversations_by_ids(user_id, conversation_ids_need_sync.clone())
                .await
            {
                Ok(server_convs) => {
                    let mut conversations_to_insert = Vec::new();
                    for s in &server_convs {
                        let mut domain = server_to_domain(s.clone());
                        // 计算未读数
                        if let Some(seq_info) = resp.seqs.get(&domain.conversation_id) {
                            let unread_count = if seq_info.max_seq > seq_info.has_read_seq {
                                (seq_info.max_seq - seq_info.has_read_seq) as i32
                            } else {
                                0
                            };
                            domain.unread_count = unread_count;
                        }
                        let local = domain_to_local(domain.clone());
                        if let Err(e) = self.dao.upsert(&local).await {
                            error!(
                                "[ConvSync] 插入会话 {} 失败: {}",
                                domain.conversation_id, e
                            );
                        } else {
                            conversations_to_insert.push(domain);
                        }
                    }
                    if !conversations_to_insert.is_empty() {
                        changed_ids.extend(
                            conversations_to_insert
                                .iter()
                                .map(|c| c.conversation_id.clone()),
                        );
                        self.send(ConversationEvent::Changed(conversations_to_insert));
                    }
                }
                Err(e) => {
                    error!(
                        "[ConvSync] 从服务端拉取缺失会话失败: {}",
                        e
                    );
                }
            }
        }

        // 对齐 Go SDK：syncHashReadSeqs 只更新 DB，不直接发布事件
        // 事件由 handle_messages_internal 末尾统一发布

        Ok(())
    }

    // ========================================================================
    // 版本查询（供外部使用）
    // ========================================================================

    pub async fn get_sync_version(&self) -> u64 {
        let user_id = self.user_id.read().await.clone();
        match self
            .sync_version_dao
            .get_version_sync(CONVERSATION_TABLE_NAME, &user_id)
            .await
        {
            Ok(Some((_, v))) => v,
            _ => 0,
        }
    }

    pub async fn get_sync_version_id(&self) -> String {
        let user_id = self.user_id.read().await.clone();
        match self
            .sync_version_dao
            .get_version_sync(CONVERSATION_TABLE_NAME, &user_id)
            .await
        {
            Ok(Some((vid, _))) => vid,
            _ => String::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;
    use crate::infra::http::client::HttpApiClient;

    #[tokio::test]
    async fn test_conversation_syncer_creation() {
        let pool = create_pool_memory().await.unwrap();
        let dao = Arc::new(ConversationDao::new(pool.clone()));
        let sync_version_dao = Arc::new(SyncVersionDao::new(pool));
        let http_client = Arc::new(HttpApiClient::new(
            "http://localhost:10002".to_string(),
            "test_token".to_string(),
            "test_op".to_string(),
        ));
        let syncer = ConversationSyncer::new(
            http_client,
            dao,
            sync_version_dao,
            "test_user".to_string(),
        );

        assert_eq!(syncer.get_sync_version().await, 0);
        assert_eq!(syncer.get_sync_version_id().await, "");
    }
}
