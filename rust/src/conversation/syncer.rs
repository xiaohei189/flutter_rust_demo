//! 会话同步器 - 增量/全量同步（对齐 Go SDK `IncrSyncConversations` + `VersionSynchronizer`）

use crate::client::context::Repositories;
use crate::error::{Result, SdkError};
use crate::event::events::conversation::{ConversationEvent, ConversationListener, ConversationListenerExt};
use crate::model::local::LocalConversation;
use crate::model::UserId;

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, error, info, warn};

use crate::http::conversation::ConversationServerApi;
use crate::http::conversation_api::HttpConversationApi;

// ========== 常量 ==========

/// 版本同步表名（对齐 Go SDK `model_struct.LocalConversation{}.TableName()`）
const CONVERSATION_TABLE_NAME: &str = "local_conversations";

pub struct ConversationSyncer {
    /// 外部依赖
    api: Arc<dyn ConversationServerApi>,
    repositories: Arc<Repositories>,
    /// 身份
    user_id: UserId,
    /// 事件出口（Listener trait）
    pub(crate) listener: Arc<dyn ConversationListener>,
    /// WebSocket 连接管理器（用于 sync_conversation_hash_read_seqs 的 RPC 调用）
    connection: Option<Arc<crate::connection::manager::ConnectionManager>>,
    /// 增量同步互斥锁（对齐 Go SDK `conversationSyncMutex`）
    sync_mutex: tokio::sync::Mutex<()>,
}

impl ConversationSyncer {
    pub fn new(http_client: Arc<crate::http::client::HttpApiClient>, repositories: Arc<Repositories>, user_id: UserId, listener: Arc<dyn ConversationListener>) -> Self {
        Self {
            api: Arc::new(HttpConversationApi::new(http_client)),
            repositories,
            user_id,
            listener,
            connection: None,
            sync_mutex: tokio::sync::Mutex::new(()),
        }
    }

    /// 使用自定义 API 实现构造（用于测试 mock）
    #[cfg(test)]
    pub fn new_with_api(api: Arc<dyn ConversationServerApi>, repositories: Arc<Repositories>, user_id: UserId, listener: Arc<dyn ConversationListener>) -> Self {
        Self {
            api,
            repositories,
            user_id,
            listener,
            connection: None,
            sync_mutex: tokio::sync::Mutex::new(()),
        }
    }

    pub(crate) fn send(&self, e: ConversationEvent) {
        self.listener.emit(e);
    }

    /// 设置 WebSocket 连接管理器（用于 Hash Read Seq 同步）
    pub fn set_connection(&mut self, connection: Arc<crate::connection::manager::ConnectionManager>) {
        self.connection = Some(connection);
    }

    // ========================================================================
    // 增量同步（对齐 Go SDK `IncrSyncConversations` + `VersionSynchronizer`）
    // ========================================================================

    /// 增量同步会话（版本号持久化到数据库，对齐 Go SDK `VersionSynchronizer.IncrementalSync`）
    pub async fn sync_incremental(&self) -> Result<Vec<LocalConversation>> {
        let user_id = self.user_id.get().await;

        // 1. 从数据库获取本地版本信息（对齐 Go SDK `getVersionInfo`）
        let (local_version_id, local_version) = match self.repositories.sync_version_repo.get_version_sync(CONVERSATION_TABLE_NAME, &user_id).await? {
            Some((vid, v)) => (vid, v),
            None => (String::new(), 0),
        };

        info!("开始增量同步会话，版本: {}, version_id: {}", local_version, local_version_id);

        // 注意：不发布 SyncStarted/SyncFinished 事件，避免与 MessageSyncer 冲突
        // 会话变化通过 ConversationChanged/ConversationDeleted 事件单独通知

        // 2. 请求增量数据
        let resp = match self.api.pull_incremental(user_id.clone(), local_version, local_version_id.clone()).await {
            Ok(r) => r,
            Err(e) => {
                return Err(e);
            }
        };

        // 3. 如果服务端返回 full=true，回退到全量同步（对齐 Go SDK `FullSyncer`）
        if resp.full {
            info!("增量同步返回 full=true，执行全量同步");
            let version_id = resp.version_id;
            let version = resp.version;
            let r = self.sync_full().await;
            // 全量同步完成后持久化服务端返回的版本，避免下次启动再次全量
            if let Err(e) = self
                .repositories
                .sync_version_repo
                .set_version_sync(CONVERSATION_TABLE_NAME, &user_id, &version_id, version)
                .await
            {
                warn!("全量同步后更新会话同步版本失败: {}", e);
            }
            return r;
        }

        // 4. 处理增量变更
        for conv_id in &resp.delete {
            self.repositories.conversation_repo.delete(conv_id).await?;
            self.send(ConversationEvent::Deleted(vec![conv_id.clone()]));
        }

        for s in &resp.update {
            let local: LocalConversation = s.clone().into();
            self.repositories.conversation_repo.upsert_preserving_local_fields(&local).await?;
        }

        for s in &resp.insert {
            let local: LocalConversation = s.clone().into();
            self.repositories.conversation_repo.upsert_preserving_local_fields(&local).await?;
        }

        if !resp.update.is_empty() || !resp.insert.is_empty() {
            let changed: Vec<LocalConversation> = resp.update.iter().chain(resp.insert.iter()).map(|s| s.clone().into()).collect();
            self.send(ConversationEvent::Changed(changed));
        }

        // 5. 持久化版本号到数据库（对齐 Go SDK `updateVersionInfo`）
        if let Err(e) = self
            .repositories
            .sync_version_repo
            .set_version_sync(CONVERSATION_TABLE_NAME, &user_id, &resp.version_id, resp.version)
            .await
        {
            warn!("更新会话同步版本失败: {}", e);
        }

        info!("增量同步完成，insert={}, update={}, delete={}", resp.insert.len(), resp.update.len(), resp.delete.len());

        let inserted_convs: Vec<LocalConversation> = resp.insert.iter().map(|s| s.clone().into()).collect();
        Ok(inserted_convs)
    }

    /// 加锁版本的增量同步（对齐 Go SDK `IncrSyncConversationsWithLock`）
    pub async fn sync_incremental_with_lock(&self) -> Result<Vec<LocalConversation>> {
        let _guard = self.sync_mutex.lock().await;
        self.sync_incremental().await
    }

    // ========================================================================
    // 全量同步
    // ========================================================================

    pub async fn sync_full(&self) -> Result<Vec<LocalConversation>> {
        info!("开始全量同步会话");

        let user_id = self.user_id.get().await;
        let resp = match self.api.pull_all(user_id).await {
            Ok(r) => r,
            Err(e) => {
                return Err(e);
            }
        };

        let conversations: Vec<LocalConversation> = resp.conversations.unwrap_or_default().into_iter().map(|s| s.into()).collect();

        // 保留本地 latest_msg 等字段：先记录本地所有会话 ID
        let local_ids: std::collections::HashSet<String> = self
            .repositories
            .conversation_repo
            .get_all()
            .await
            .unwrap_or_default()
            .into_iter()
            .map(|lc| lc.conversation_id)
            .collect();

        // 使用保留本地字段的 upsert 方法插入所有服务端会话
        for conv in &conversations {
            let local = conv.clone();
            self.repositories.conversation_repo.upsert_preserving_local_fields(&local).await?;
        }

        // 删除服务端不再返回的会话（即本地存在但服务端不存在的）
        let server_ids: std::collections::HashSet<String> = conversations.iter().map(|c| c.conversation_id.clone()).collect();
        for local_id in &local_ids {
            if !server_ids.contains(local_id) {
                self.repositories.conversation_repo.delete(local_id).await?;
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
    pub async fn sync_conversation_hash_read_seqs(&self, max_seq_recorder: &crate::message::MaxSeqRecorder) -> Result<()> {
        let connection = match &self.connection {
            Some(c) => c,
            None => {
                warn!("[ConvSync] sync_conversation_hash_read_seqs: connection 未设置，跳过");
                return Ok(());
            }
        };

        let user_id = self.user_id.get().await;
        use crate::constant::ws_req_identifier;
        use openim_protocol::msg::{GetConversationsHasReadAndMaxSeqReq, GetConversationsHasReadAndMaxSeqResp};

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
        let local_conversations = self.repositories.conversation_repo.get_all().await.unwrap_or_default();
        let mut local_map: HashMap<String, crate::model::local::LocalConversation> = HashMap::new();
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
                    if let Err(e) = self.repositories.conversation_repo.update_unread_count(conv_id, unread_count).await {
                        error!("[ConvSync] 更新会话 {} 未读数失败: {}", conv_id, e);
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
            info!("[ConvSync] {} 个会话不在本地，从服务端拉取", conversation_ids_need_sync.len());
            let user_id = self.user_id.get().await;
            match self.api.pull_conversations_by_ids(user_id, conversation_ids_need_sync.clone()).await {
                Ok(server_convs) => {
                    let mut conversations_to_insert = Vec::new();
                    for s in &server_convs {
                        let mut domain: LocalConversation = s.clone().into();
                        // 计算未读数
                        if let Some(seq_info) = resp.seqs.get(&domain.conversation_id) {
                            let unread_count = if seq_info.max_seq > seq_info.has_read_seq {
                                (seq_info.max_seq - seq_info.has_read_seq) as i32
                            } else {
                                0
                            };
                            domain.unread_count = unread_count;
                        }
                        let local = domain.clone();
                        if let Err(e) = self.repositories.conversation_repo.upsert(&local).await {
                            error!("[ConvSync] 插入会话 {} 失败: {}", domain.conversation_id, e);
                        } else {
                            conversations_to_insert.push(domain);
                        }
                    }
                    if !conversations_to_insert.is_empty() {
                        changed_ids.extend(conversations_to_insert.iter().map(|c| c.conversation_id.clone()));
                        self.send(ConversationEvent::Changed(conversations_to_insert));
                    }
                }
                Err(e) => {
                    error!("[ConvSync] 从服务端拉取缺失会话失败: {}", e);
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
        let user_id = self.user_id.get().await;
        match self.repositories.sync_version_repo.get_version_sync(CONVERSATION_TABLE_NAME, &user_id).await {
            Ok(Some((_, v))) => v,
            _ => 0,
        }
    }

    pub async fn get_all_conversation_ids(&self) -> Result<Vec<String>> {
        let user_id = self.user_id.get().await;
        let resp = self.api.pull_full_conversation_ids(user_id).await?;
        Ok(resp.conversation_ids)
    }

    pub async fn get_sync_version_id(&self) -> String {
        let user_id = self.user_id.get().await;
        match self.repositories.sync_version_repo.get_version_sync(CONVERSATION_TABLE_NAME, &user_id).await {
            Ok(Some((vid, _))) => vid,
            _ => String::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::pool::create_pool_memory;
    use crate::db::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};
    use crate::event::events::conversation::ConversationEvent;
    use crate::event::hub::EventHub;
    use crate::http::client::HttpApiClient;
    use crate::http::conversation::{GetFullConversationIDsResp, GetIncrementalConversationResp, MockConversationApi, ServerConversation};
    use crate::message::MaxSeqRecorder;
    use crate::model::UserId;

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

    fn make_server_conv(id: &str, pinned: bool, recv_msg_opt: i32) -> ServerConversation {
        ServerConversation {
            owner_user_id: "test_user".to_string(),
            conversation_id: id.to_string(),
            conversation_type: 1,
            recv_msg_opt,
            user_id: "user_1".to_string(),
            group_id: String::new(),
            is_pinned: pinned,
            is_private_chat: false,
            group_at_type: 0,
            ex: String::new(),
            attached_info: String::new(),
            burn_duration: 0,
            min_seq: 0,
            max_seq: 0,
            msg_destruct_time: 0,
            is_msg_destruct: false,
        }
    }

    /// 构造带 EventHub listener 的 syncer
    fn make_syncer_with_hub(api: Arc<dyn ConversationServerApi>, repositories: Arc<Repositories>) -> (ConversationSyncer, tokio::sync::mpsc::UnboundedReceiver<ConversationEvent>) {
        let hub = EventHub::new();
        let rx = hub.take_conv_rx().unwrap();
        let syncer = ConversationSyncer::new_with_api(api, repositories, UserId::new("test_user"), hub);
        (syncer, rx)
    }

    #[tokio::test]
    async fn test_conversation_syncer_creation() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let http_client = Arc::new(HttpApiClient::new("http://localhost:10002".to_string(), "test_token".to_string(), "test_op".to_string()));
        let syncer = ConversationSyncer::new(http_client, repositories, UserId::new("test_user"), crate::event::test_util::noop_conversation_listener());

        assert_eq!(syncer.get_sync_version().await, 0);
        assert_eq!(syncer.get_sync_version_id().await, "");
    }

    #[tokio::test]
    async fn test_sync_incremental_insert_update_delete() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);

        // 预置本地会话：conv_update 将被 update，conv_delete 将被 delete
        repositories
            .conversation_repo
            .upsert(&LocalConversation {
                conversation_id: "conv_update".to_string(),
                recv_msg_opt: 0,
                is_pinned: false,
                ..Default::default()
            })
            .await
            .unwrap();
        repositories
            .conversation_repo
            .upsert(&LocalConversation {
                conversation_id: "conv_delete".to_string(),
                ..Default::default()
            })
            .await
            .unwrap();

        let inc = GetIncrementalConversationResp {
            version: 42,
            version_id: "ver_42".to_string(),
            full: false,
            delete: vec!["conv_delete".to_string()],
            insert: vec![make_server_conv("conv_insert", false, 0)],
            update: vec![make_server_conv("conv_update", true, 2)],
        };
        let api = Arc::new(MockConversationApi::new().with_incremental(inc));
        let (syncer, mut rx) = make_syncer_with_hub(api, repositories.clone());

        let inserted = syncer.sync_incremental().await.unwrap();
        assert_eq!(inserted.len(), 1);
        assert_eq!(inserted[0].conversation_id, "conv_insert");

        // 版本已持久化
        assert_eq!(syncer.get_sync_version().await, 42);
        assert_eq!(syncer.get_sync_version_id().await, "ver_42");

        // 数据库状态：update 生效、insert 入库、delete 移除
        let updated = repositories.conversation_repo.get_by_id("conv_update").await.unwrap().unwrap();
        assert!(updated.is_pinned);
        assert_eq!(updated.recv_msg_opt, 2);
        assert!(repositories.conversation_repo.get_by_id("conv_insert").await.unwrap().is_some());
        assert!(repositories.conversation_repo.get_by_id("conv_delete").await.unwrap().is_none());

        // 事件：先 Deleted 后 Changed（update+insert 合并）
        match rx.try_recv().unwrap() {
            ConversationEvent::Deleted(ids) => assert_eq!(ids, vec!["conv_delete"]),
            other => panic!("期望 Deleted 事件，实际 {:?}", other.as_str()),
        }
        match rx.try_recv().unwrap() {
            ConversationEvent::Changed(convs) => {
                let ids: Vec<&str> = convs.iter().map(|c| c.conversation_id.as_str()).collect();
                assert_eq!(ids, vec!["conv_update", "conv_insert"]);
            }
            other => panic!("期望 Changed 事件，实际 {:?}", other.as_str()),
        }
        assert!(rx.try_recv().is_err(), "不应有额外事件");
    }

    #[tokio::test]
    async fn test_sync_incremental_empty_no_events_and_version_persisted() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);

        let inc = GetIncrementalConversationResp {
            version: 7,
            version_id: "v7".to_string(),
            full: false,
            delete: vec![],
            insert: vec![],
            update: vec![],
        };
        let api = Arc::new(MockConversationApi::new().with_incremental(inc));
        let (syncer, mut rx) = make_syncer_with_hub(api, repositories);

        let result = syncer.sync_incremental().await.unwrap();
        assert!(result.is_empty());
        assert_eq!(syncer.get_sync_version().await, 7);
        assert_eq!(syncer.get_sync_version_id().await, "v7");
        assert!(rx.try_recv().is_err(), "空增量不应发布事件");
    }

    #[tokio::test]
    async fn test_sync_incremental_full_fallback_to_sync_full() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);

        let inc = GetIncrementalConversationResp { version: 99, version_id: "v99".to_string(), full: true, ..Default::default() };
        let api = Arc::new(
            MockConversationApi::new()
                .with_incremental(inc)
                .with_all(vec![make_server_conv("conv_a", false, 0), make_server_conv("conv_b", true, 0)]),
        );
        let (syncer, mut rx) = make_syncer_with_hub(api, repositories.clone());

        let result = syncer.sync_incremental().await.unwrap();
        assert_eq!(result.len(), 2);

        // full 回退全量后版本仍持久化，避免下次启动再次全量
        assert_eq!(syncer.get_sync_version().await, 99);
        assert_eq!(syncer.get_sync_version_id().await, "v99");

        // 全量同步结果入库
        assert!(repositories.conversation_repo.get_by_id("conv_a").await.unwrap().is_some());
        assert!(repositories.conversation_repo.get_by_id("conv_b").await.unwrap().is_some());

        // 全量同步发布 Changed 事件
        match rx.try_recv().unwrap() {
            ConversationEvent::Changed(convs) => assert_eq!(convs.len(), 2),
            other => panic!("期望 Changed 事件，实际 {:?}", other.as_str()),
        }
    }

    #[tokio::test]
    async fn test_sync_incremental_preserves_local_fields() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);

        // 本地已有会话：latest_msg/unread_count/draft 为本地维护值
        repositories
            .conversation_repo
            .upsert(&LocalConversation {
                conversation_id: "conv_a".to_string(),
                latest_msg: "本地最新消息".to_string(),
                latest_msg_send_time: 5000,
                unread_count: 3,
                draft_text: "本地草稿".to_string(),
                draft_text_time: 6000,
                is_pinned: false,
                ..Default::default()
            })
            .await
            .unwrap();

        // 服务端返回的 update 不含本地字段（user_id 有值，is_pinned 变化）
        let mut server_conv = make_server_conv("conv_a", true, 0);
        server_conv.user_id = "服务端用户".to_string();
        let inc = GetIncrementalConversationResp {
            version: 9,
            version_id: "v9".to_string(),
            full: false,
            delete: vec![],
            insert: vec![],
            update: vec![server_conv],
        };
        let api = Arc::new(MockConversationApi::new().with_incremental(inc));
        let (syncer, _rx) = make_syncer_with_hub(api, repositories.clone());

        syncer.sync_incremental().await.unwrap();

        let conv = repositories.conversation_repo.get_by_id("conv_a").await.unwrap().unwrap();
        // 服务端字段已更新
        assert!(conv.is_pinned);
        assert_eq!(conv.user_id, "服务端用户");
        // 本地字段被保留
        assert_eq!(conv.latest_msg, "本地最新消息");
        assert_eq!(conv.latest_msg_send_time, 5000);
        assert_eq!(conv.unread_count, 3);
        assert_eq!(conv.draft_text, "本地草稿");
    }

    #[tokio::test]
    async fn test_sync_full_insert_and_delete_absent() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);

        // 本地存在 conv_a（服务端也有）和 conv_b（服务端已删除）
        repositories
            .conversation_repo
            .upsert(&LocalConversation {
                conversation_id: "conv_a".to_string(),
                ..Default::default()
            })
            .await
            .unwrap();
        repositories
            .conversation_repo
            .upsert(&LocalConversation {
                conversation_id: "conv_b".to_string(),
                ..Default::default()
            })
            .await
            .unwrap();

        let api = Arc::new(MockConversationApi::new().with_all(vec![make_server_conv("conv_a", false, 0), make_server_conv("conv_c", false, 0)]));
        let (syncer, mut rx) = make_syncer_with_hub(api, repositories.clone());

        let result = syncer.sync_full().await.unwrap();
        assert_eq!(result.len(), 2);

        // conv_c 已插入、conv_b 已删除、conv_a 保留
        assert!(repositories.conversation_repo.get_by_id("conv_c").await.unwrap().is_some());
        assert!(repositories.conversation_repo.get_by_id("conv_b").await.unwrap().is_none());
        assert!(repositories.conversation_repo.get_by_id("conv_a").await.unwrap().is_some());

        // Changed 事件携带全部同步结果
        match rx.try_recv().unwrap() {
            ConversationEvent::Changed(convs) => {
                assert_eq!(convs.len(), 2);
                assert_eq!(convs[0].conversation_id, "conv_a");
                assert_eq!(convs[1].conversation_id, "conv_c");
            }
            other => panic!("期望 Changed 事件，实际 {:?}", other.as_str()),
        }
    }

    #[tokio::test]
    async fn test_sync_hash_read_seqs_skips_without_connection() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let api = Arc::new(MockConversationApi::new());
        let (syncer, _rx) = make_syncer_with_hub(api, repositories);

        // connection 未设置时直接跳过，不报错
        let recorder = MaxSeqRecorder::new();
        syncer.sync_conversation_hash_read_seqs(&recorder).await.unwrap();
        assert_eq!(recorder.get("conv_any"), 0);
    }

    #[tokio::test]
    async fn test_get_all_conversation_ids() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let full_ids = GetFullConversationIDsResp {
            version: 3,
            version_id: "v3".to_string(),
            equal: false,
            conversation_ids: vec!["conv_1".to_string(), "conv_2".to_string()],
        };
        let api = Arc::new(MockConversationApi::new().with_full_ids(full_ids));
        let (syncer, _rx) = make_syncer_with_hub(api, repositories);

        let ids = syncer.get_all_conversation_ids().await.unwrap();
        assert_eq!(ids, vec!["conv_1", "conv_2"]);
    }
}
