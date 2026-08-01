//! MessageSyncer — 负责从服务端拉取缺失消息并交给 handler 入库
//!
//! 对齐 Go SDK `internal/conversation_msg/msg_sync.go`

use crate::core::connection::manager::ConnectionManager;
use super::handler::MessageHandler;
use crate::domain::ports::SyncerRemoteApi;
use crate::domain::constant::ws_req_identifier;
use crate::domain::error::{Result, SdkError};
use crate::event::publisher::EventPublisher;
use crate::event::listener::conversation::{ConversationListener, ConversationEvent};
use crate::domain::model::UserId;
use crate::infra::database::models::LocalNotificationSeq;
use crate::sdk::context::Stores;
use async_trait::async_trait;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock, Semaphore};
use tracing::{debug, error, info, warn};

// 直接使用 openim-protocol crate 中的 pb 生成类型
use openim_protocol::sdkws::{
    MsgData, PullMsgs, PullMessageBySeqsResp, SeqRange, PullMessageBySeqsReq, PullOrder,
};

/// ConnectionManager 的 SyncerRemoteApi 实现
#[async_trait]
impl SyncerRemoteApi for ConnectionManager {
    async fn fetch_server_max_seqs(&self, user_id: &str) -> Result<HashMap<String, i64>> {
        use openim_protocol::sdkws::{GetMaxSeqReq, GetMaxSeqResp};

        let max_retries = 3u32;
        let mut retry_interval = std::time::Duration::from_secs(2);

        for retry in 0..max_retries {
            if retry > 0 {
                warn!("[MsgSync] getServerMaxSeq 第 {} 次重试，等待 {:?}", retry + 1, retry_interval);
                tokio::time::sleep(retry_interval).await;
                retry_interval *= 2;
            }

            let req = GetMaxSeqReq { user_id: user_id.to_string() };
            info!("[MsgSync] getServerMaxSeq 请求: user_id={}", req.user_id);
            match self.send_rpc::<GetMaxSeqReq, GetMaxSeqResp>(ws_req_identifier::GET_NEWEST_SEQ, &req).await {
                Ok(resp) => {
                    info!("[MsgSync] getServerMaxSeq 成功 (retry={}, count={})", retry, resp.max_seqs.len());
                    return Ok(resp.max_seqs);
                }
                Err(e) => {
                    warn!("[MsgSync] getServerMaxSeq 失败 (retry={}): {:?}", retry + 1, e);
                    if retry == max_retries - 1 {
                        return Err(SdkError::network(format!("getServerMaxSeq {} 次重试均失败: {}", max_retries, e)));
                    }
                }
            }
        }
        unreachable!()
    }

    async fn pull_messages_by_seqs(&self, req: &PullMessageBySeqsReq) -> Result<PullMessageBySeqsResp> {
        self.send_rpc(1002, req).await
    }

    async fn is_kicked(&self) -> bool {
        self.get_state().await == crate::core::connection::manager::ConnectionState::Kicked
    }
}

/// 判断会话是否为通知类型（对齐 Go SDK `msg_sync.go:503-505` IsNotification）
///
/// 通知类型会话的 conversationID 以 `n_` 前缀开头，如好友申请通知、群组变更通知等。
/// 这类会话的消息不需要拉取和存储，只需跟踪其 seq 以避免重复同步。
pub fn is_notification(conversation_id: &str) -> bool {
    conversation_id.starts_with("n_")
}

/// 同步器配置参数
#[derive(Clone, Debug)]
pub struct SyncConfig {
    pub max_concurrent_pulls: usize,
    pub pull_msg_num: i64,
}

impl Default for SyncConfig {
    fn default() -> Self {
        Self { max_concurrent_pulls: 5, pull_msg_num: 50 }
    }
}

/// 消息同步器 — 负责从服务端拉取缺失消息并交给 handler 入库
///
/// 对齐 Go SDK `internal/conversation_msg/msg_sync.go`
///
/// # 核心流程
///
/// 1. 收到推送通知（或登录/重连）后触发同步
/// 2. 比较本地 max_seq 与服务端 max_seq，计算差量
/// 3. 通过 WebSocket RPC 分批拉取缺失消息（并发控制）
/// 4. 将拉取结果交给 `MessageHandler` 分类入库 + 触发事件
///
/// # 并发安全
///
/// - 全局 `sync_lock` 防止重复触发同步
/// - 每会话 `per_conv_sync_locks` 防止同一会话并发 pull
/// - `Semaphore` 控制最大并发拉取数
pub struct MessageSyncer {
    /// 外部依赖
    remote: Arc<dyn SyncerRemoteApi>,
    stores: Arc<Stores>,
    message_handler: Arc<MessageHandler>,
    /// 身份
    user_id: UserId,
    /// 配置
    config: SyncConfig,
    /// 事件
    pub(crate) events: EventPublisher<ConversationEvent>,
    /// 内部状态
    synced_max_seqs: Arc<RwLock<HashMap<String, i64>>>,
    sync_lock: Arc<Mutex<()>>,
    per_conv_sync_locks: Arc<RwLock<HashMap<String, Arc<tokio::sync::Mutex<()>>>>>,
}

impl MessageSyncer {
    pub fn new(
        remote: Arc<dyn SyncerRemoteApi>,
        stores: Arc<Stores>,
        message_handler: Arc<MessageHandler>,
        user_id: UserId,
    ) -> Self {
        Self {
            remote,
            stores,
            message_handler,
            user_id,
            config: SyncConfig::default(),
            events: EventPublisher::new(),
            synced_max_seqs: Arc::new(RwLock::new(HashMap::new())),
            sync_lock: Arc::new(Mutex::new(())),
            per_conv_sync_locks: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub fn set_event_sender(&self, tx: tokio::sync::mpsc::UnboundedSender<ConversationEvent>) {
        self.events.set_sender(tx);
    }

    pub(crate) fn send(&self, e: ConversationEvent) {
        tracing::info!("[SEND] {:?}, has_subscriber={}", &e, self.events.has_subscriber());
        self.events.publish(e);
    }

    fn notify_conv(&self, f: impl FnOnce(&dyn ConversationListener)) {
    }

    fn on_sync_started(&self) { self.notify_conv(|l| l.on_sync_started()); }
    fn on_sync_finished(&self) { self.notify_conv(|l| l.on_sync_finished()); }
    fn on_sync_failed(&self, e: &str) { self.notify_conv(|l| l.on_sync_failed(e)); }
    fn on_sync_progress(&self, p: i32, m: &str) { self.notify_conv(|l| l.on_sync_progress(p, m)); }

    /// 从服务端获取所有会话的最新 maxSeq
    pub async fn get_server_max_seqs(&self) -> Result<HashMap<String, i64>> {
        self.remote.fetch_server_max_seqs(&self.user_id.get().await).await
    }

    /// 检查连接是否已被踢下线
    pub async fn is_connection_kicked(&self) -> bool {
        self.remote.is_kicked().await
    }

    pub async fn sync_after_reconnect(&self) -> Result<()> {
        let _guard = self.sync_lock.try_lock();
        if _guard.is_err() {
            info!("消息同步已在进行中，跳过");
            return Ok(());
        }

        info!("重连后开始增量同步消息");
        self.send(ConversationEvent::SyncStarted);
        self.send(ConversationEvent::SyncProgress { progress: 1, message: "重连后开始同步".into() });

        let server_max_seqs = match self.get_server_max_seqs().await {
            Ok(seqs) => seqs,
            Err(e) => {
                let error_msg = format!("{}", e);
                self.send(ConversationEvent::SyncFailed(error_msg.to_string()));
                return Err(e);
            }
        };

        if server_max_seqs.is_empty() {
            info!("服务端无会话 seq，跳过同步");
            self.send(ConversationEvent::SyncProgress { progress: 100, message: "同步完成（无需同步）".into() });
            self.send(ConversationEvent::SyncFinished);
            return Ok(());
        }

        for (conv_id, max_seq) in &server_max_seqs {
            let _ = self.stores.conversation_repo.update_max_seq(conv_id, *max_seq).await;
        }

        match self.sync_incremental_messages(&server_max_seqs).await {
            Ok(()) => {
                self.send(ConversationEvent::SyncProgress { progress: 100, message: "重连后同步完成".into() });
                self.send(ConversationEvent::SyncFinished);
                info!("重连后增量同步完成");
                Ok(())
            }
            Err(e) => {
                let error_msg = format!("{}", e);
                self.send(ConversationEvent::SyncFailed(error_msg.to_string()));
                Err(e)
            }
        }
    }

    /// 登录后的全量同步（区分重装和普通模式）
    pub async fn sync_on_login(&self) -> Result<()> {
        info!("=== 消息同步开始: sync_on_login ===");
        let _guard = self.sync_lock.try_lock();
        if _guard.is_err() {
            info!("消息同步已在进行中，跳过");
            return Ok(());
        }

        let reinstalled = self.stores.sync_version_repo.is_reinstalled().await?;
        info!("登录后开始同步全部消息，reinstalled={}", reinstalled);

        self.send(ConversationEvent::SyncStarted);
        self.send(ConversationEvent::SyncProgress { progress: 1, message: "同步开始".into() });

        match self.sync_all_conversations(reinstalled).await {
            Ok(()) => {
                self.send(ConversationEvent::SyncProgress { progress: 100, message: "同步完成".into() });
                self.send(ConversationEvent::SyncFinished);
                info!("=== 消息同步成功: sync_on_login ===");
                Ok(())
            }
            Err(e) => {
                let error_msg = format!("{}", e);
                self.send(ConversationEvent::SyncFailed(error_msg.to_string()));
                error!("=== 消息同步失败: sync_on_login, error={} ===", e);
                Err(e)
            }
        }
    }

    /// 推送消息触发同步：检测 seq 连续性，不连续时自动补拉
    pub async fn push_trigger_and_sync(
        &self,
        conv_id: &str,
        pushed_seqs: &[i64],
    ) -> Result<()> {
        if pushed_seqs.is_empty() {
            return Ok(());
        }

        let conv_lock = {
            let mut locks = self.per_conv_sync_locks.write().await;
            locks
                .entry(conv_id.to_string())
                .or_insert_with(|| Arc::new(tokio::sync::Mutex::new(())))
                .clone()
        };
        let _guard = conv_lock.lock().await;

        let min_seq = *pushed_seqs.iter().min().unwrap_or(&0);
        let max_seq = *pushed_seqs.iter().max().unwrap_or(&0);

        let expected_last = {
            let synced = self.synced_max_seqs.read().await;
            synced.get(conv_id).copied().unwrap_or(0)
        } + pushed_seqs.len() as i64;

        if max_seq == expected_last || max_seq <= expected_last {
            self.synced_max_seqs.write().await.insert(conv_id.to_string(), max_seq);
            return Ok(());
        }

        info!(
            "推送消息 seq 不连续: conv={}, expected_last={}, actual_max={}, min={}",
            conv_id, expected_last, max_seq, min_seq
        );

        let begin = expected_last + 1;
        if begin <= max_seq {
            let mut seq_map = HashMap::new();
            seq_map.insert(conv_id.to_string(), (begin, max_seq));
            self.batch_pull_messages(&seq_map).await?;
        }

        self.synced_max_seqs.write().await.insert(conv_id.to_string(), max_seq);
        Ok(())
    }

    /// 从本地 DB 加载已同步的 max_seq 到内存
    pub async fn load_synced_max_seqs(&self) -> Result<()> {
        let conv_seqs = self.stores.conversation_repo.get_all_seq_pairs().await?;
        let mut map = self.synced_max_seqs.write().await;
        for (conv_id, seq) in conv_seqs {
            let local_max = self.stores.message_repo.get_max_seq(&conv_id).await.unwrap_or(0);
            map.insert(conv_id, local_max);
        }

        match self.stores.notification_seq_dao.get_all().await {
            Ok(notification_seqs) => {
                let count = notification_seqs.len();
                for ns in &notification_seqs {
                    map.insert(ns.conversation_id.clone(), ns.seq);
                }
                info!("已加载 {} 个通知会话的 seq 到 synced_max_seqs", count);
            }
            Err(e) => {
                warn!("加载通知 seq 失败（忽略）: {}", e);
            }
        }

        info!("已加载 {} 个会话的 synced_max_seqs", map.len());
        Ok(())
    }

    /// 设置通知会话的 seq
    pub async fn set_notification_seq(&self, conversation_id: &str, seq: i64) -> Result<()> {
        self.stores.notification_seq_dao.set_notification_seq(conversation_id, seq).await
    }

    pub async fn sync_all_conversations(&self, reinstalled: bool) -> Result<()> {
        info!("开始同步全部会话消息, reinstalled={}", reinstalled);

        let server_max_seqs = self.get_server_max_seqs().await?;

        if server_max_seqs.is_empty() {
            info!("服务端无会话记录，跳过同步");
            self.send(ConversationEvent::SyncFinished);
            return Ok(());
        }

        for (conv_id, max_seq) in &server_max_seqs {
            debug!("[SYNC_DIAG] 服务端会话: conv={}, max_seq={}, is_notification={}",
                conv_id, max_seq, is_notification(conv_id));
        }

        for (conv_id, max_seq) in &server_max_seqs {
            let _ = self.stores.conversation_repo.update_max_seq(conv_id, *max_seq).await;
        }

        self.load_synced_max_seqs().await?;

        if reinstalled {
            self.sync_all_messages_reinstall(&server_max_seqs).await?;
            self.stores.sync_version_repo.mark_reinstall_complete("1.0.0").await?;
        } else {
            self.sync_incremental_messages(&server_max_seqs).await?;
        }

        info!("全部会话消息同步完成");
        Ok(())
    }

    async fn sync_incremental_messages(&self, max_seq_to_sync: &HashMap<String, i64>) -> Result<()> {
        let mut need_sync_seq_map: HashMap<String, (i64, i64)> = HashMap::new();

        for (conversation_id, server_max_seq) in max_seq_to_sync {
            let local_max_seq = self.stores.message_repo.get_max_seq(conversation_id).await.unwrap_or(0);

            if *server_max_seq > local_max_seq {
                let begin = local_max_seq + 1;
                info!("会话 {} 需要同步: local_max_seq={}, server_max_seq={}, begin={}, end={}",
                    conversation_id, local_max_seq, server_max_seq, begin, server_max_seq);
                need_sync_seq_map.insert(conversation_id.clone(), (begin, *server_max_seq));
            }
        }

        if need_sync_seq_map.is_empty() {
            info!("无需要同步的消息");
            return Ok(());
        }

        info!("需要同步 {} 个会话的消息", need_sync_seq_map.len());
        self.batch_pull_messages(&need_sync_seq_map).await
    }

    /// 重装模式同步：跳过通知会话，只同步普通消息
    async fn sync_all_messages_reinstall(&self, max_seq_to_sync: &HashMap<String, i64>) -> Result<()> {
        let mut need_sync_seq_map: HashMap<String, (i64, i64)> = HashMap::new();
        let mut notification_seq_records: Vec<LocalNotificationSeq> = Vec::new();

        for (conversation_id, server_max_seq) in max_seq_to_sync {
            if is_notification(conversation_id) {
                if *server_max_seq != 0 {
                    notification_seq_records.push(LocalNotificationSeq {
                        conversation_id: conversation_id.clone(),
                        seq: *server_max_seq,
                    });
                    self.synced_max_seqs.write().await.insert(conversation_id.clone(), *server_max_seq);
                    info!("重装模式: 通知会话 {} 跳过拉取，直接持久化 seq={}", conversation_id, server_max_seq);
                }
                continue;
            }

            let local_max_seq = self.stores.message_repo.get_max_seq(conversation_id).await.unwrap_or(0);

            if *server_max_seq > local_max_seq {
                let begin = local_max_seq + 1;
                info!("会话 {} 重装同步: local_max_seq={}, server_max_seq={}, begin={}, end={}",
                    conversation_id, local_max_seq, server_max_seq, begin, server_max_seq);
                need_sync_seq_map.insert(conversation_id.clone(), (begin, *server_max_seq));
            }
        }

        if !notification_seq_records.is_empty() {
            info!("重装模式: 持久化 {} 个通知会话的 seq", notification_seq_records.len());
            if let Err(e) = self.stores.notification_seq_dao.batch_insert(&notification_seq_records).await {
                warn!("持久化通知 seq 失败: {}", e);
            }
        }

        if need_sync_seq_map.is_empty() {
            return Ok(());
        }

        let total = need_sync_seq_map.values().map(|(_, end)| end).sum::<i64>();
        info!("重装模式，同步全部 {} 条消息", total);

        self.batch_pull_messages_reinstall(&need_sync_seq_map, total).await
    }

    async fn batch_pull_messages(&self, seq_map: &HashMap<String, (i64, i64)>) -> Result<()> {
        let semaphore = Arc::new(Semaphore::new(self.config.max_concurrent_pulls));
        let mut tasks = Vec::new();

        let batch_size = 50;
        let mut batches: Vec<HashMap<String, (i64, i64)>> = Vec::new();
        let mut current_batch = HashMap::new();
        let mut msg_count = 0i64;

        for (conv_id, (begin, end)) in seq_map {
            let range_size = end - begin + 1;
            if msg_count + range_size > batch_size && !current_batch.is_empty() {
                batches.push(current_batch);
                current_batch = HashMap::new();
                msg_count = 0;
            }
            current_batch.insert(conv_id.clone(), (*begin, *end));
            msg_count += range_size;
        }
        if !current_batch.is_empty() {
            batches.push(current_batch);
        }

        for batch in batches {
            let permit = semaphore.clone().acquire_owned().await
                .map_err(|e| SdkError::database(format!("acquire semaphore failed: {}", e)))?;

            let syncer_clone = self.clone_for_task();
            tasks.push(tokio::spawn(async move {
                let _permit = permit;
                syncer_clone.pull_and_handle_messages(&batch).await
            }));
        }

        for task in tasks {
            task.await
                .map_err(|e| SdkError::unknown(format!("task join failed: {}", e)))??;
        }

        Ok(())
    }

    async fn batch_pull_messages_reinstall(&self, seq_map: &HashMap<String, (i64, i64)>, total: i64) -> Result<()> {
        let semaphore = Arc::new(Semaphore::new(self.config.max_concurrent_pulls));
        let mut tasks = Vec::new();

        let batch_size = 50;
        let mut batches: Vec<HashMap<String, (i64, i64)>> = Vec::new();
        let mut current_batch = HashMap::new();
        let mut msg_count = 0i64;

        for (conv_id, (begin, end)) in seq_map {
            let range_size = end - begin + 1;
            if msg_count + range_size > batch_size && !current_batch.is_empty() {
                batches.push(current_batch);
                current_batch = HashMap::new();
                msg_count = 0;
            }
            current_batch.insert(conv_id.clone(), (*begin, *end));
            msg_count += range_size;
        }
        if !current_batch.is_empty() {
            batches.push(current_batch);
        }

        for batch in batches {
            let permit = semaphore.clone().acquire_owned().await
                .map_err(|e| SdkError::database(format!("acquire semaphore failed: {}", e)))?;

            let syncer_clone = self.clone_for_task();
            let total_clone = total;
            tasks.push(tokio::spawn(async move {
                let _permit = permit;
                syncer_clone.pull_and_handle_messages_reinstall(&batch, total_clone).await
            }));
        }

        for task in tasks {
            task.await
                .map_err(|e| SdkError::unknown(format!("task join failed: {}", e)))??;
        }

        Ok(())
    }

    #[tracing::instrument(skip_all, fields(conv_count = %seq_map.len()))]
    async fn pull_and_handle_messages(&self, seq_map: &HashMap<String, (i64, i64)>) -> Result<()> {
        let req = PullMessageBySeqsReq {
            user_id: self.user_id.get().await,
            seq_ranges: seq_map
                .iter()
                .map(|(conv_id, (begin, end))| SeqRange {
                    conversation_id: conv_id.clone(),
                    begin: *begin,
                    end: *end,
                    num: self.config.pull_msg_num,
                })
                .collect(),
            order: 0,
        };

        info!("[MsgSync] pull_and_handle_messages 请求: user_id={}, conv_count={}, seq_ranges={:?}",
            req.user_id, req.seq_ranges.len(),
            req.seq_ranges.iter().map(|r| format!("{}:[{},{}]", r.conversation_id, r.begin, r.end)).collect::<Vec<_>>());

        let resp: PullMessageBySeqsResp = self.remote
            .pull_messages_by_seqs(&req)
            .await
            .map_err(|e| SdkError::network(format!("pull messages failed: {}", e)))?;

        info!("[MsgSync] pull_and_handle_messages: {} conversations, msgs_count={}",
            resp.msgs.len(),
            resp.msgs.values().map(|m| m.msgs.len()).sum::<usize>());

        self.handle_pulled_messages(&resp.msgs).await?;

        let total_convs = seq_map.len() as u8;
        for (idx, (conv_id, (_, end_seq))) in seq_map.iter().enumerate() {
            let progress = 10 + ((idx as u8 + 1) * 90 / total_convs.max(1));
            self.on_sync_progress(progress as i32, & format!("同步完成 {}: seq={}", conv_id, end_seq));
        }

        Ok(())
    }

    async fn pull_and_handle_messages_reinstall(&self, seq_map: &HashMap<String, (i64, i64)>, total: i64) -> Result<()> {
        let req = PullMessageBySeqsReq {
            user_id: self.user_id.get().await,
            seq_ranges: seq_map
                .iter()
                .map(|(conv_id, (begin, end))| SeqRange {
                    conversation_id: conv_id.clone(),
                    begin: *begin,
                    end: *end,
                    num: self.config.pull_msg_num,
                })
                .collect(),
            order: 0,
        };

        info!("[MsgSync] pull_and_handle_messages_reinstall 请求: user_id={}, conv_count={}, total={}",
            req.user_id, req.seq_ranges.len(), total);

        let resp: PullMessageBySeqsResp = self.remote
            .pull_messages_by_seqs(&req)
            .await
            .map_err(|e| SdkError::network(format!("pull messages failed: {}", e)))?;

        info!("[MsgSync] pull_and_handle_messages_reinstall: {} conversations, msgs_count={}",
            resp.msgs.len(),
            resp.msgs.values().map(|m| m.msgs.len()).sum::<usize>());

        self.handle_pulled_messages(&resp.msgs).await?;

        let total_convs = seq_map.len() as u8;
        for (idx, (conv_id, (_, _))) in seq_map.iter().enumerate() {
            let progress = 10 + ((idx as u8 + 1) * 90 / total_convs.max(1));
            self.on_sync_progress(progress as i32, & format!("重装同步完成 {}: 共 {} 条消息", conv_id, total));
        }

        Ok(())
    }

    async fn handle_pulled_messages(&self, msgs: &HashMap<String, PullMsgs>) -> Result<()> {
        for (conv_id, pull_msgs) in msgs {
            if pull_msgs.msgs.is_empty() {
                continue;
            }

            if let Some(max_seq_in_batch) = pull_msgs.msgs.iter().map(|m| m.seq).max() {
                let mut synced = self.synced_max_seqs.write().await;
                let current = synced.get(conv_id).copied().unwrap_or(0);
                if max_seq_in_batch > current {
                    synced.insert(conv_id.clone(), max_seq_in_batch);
                }
            }

            let messages = pull_msgs.msgs.clone();
            self.message_handler.handle_sync_messages(conv_id, messages).await?;
        }

        Ok(())
    }

    fn clone_for_task(&self) -> Arc<Self> {
        Arc::new(Self {
            remote: self.remote.clone(),
            stores: self.stores.clone(),
            message_handler: self.message_handler.clone(),
            user_id: self.user_id.clone(),
            config: self.config.clone(),
            events: self.events.clone(),
            synced_max_seqs: self.synced_max_seqs.clone(),
            sync_lock: self.sync_lock.clone(),
            per_conv_sync_locks: self.per_conv_sync_locks.clone(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::model::UserId;
    use crate::infra::database::pool::create_pool_memory;
    use crate::infra::database::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};
    use crate::sdk::context::Stores;
    use prost::Message;
    use std::sync::atomic::{AtomicUsize, Ordering};

    struct MockSyncerApi {
        max_seqs: HashMap<String, i64>,
        pull_msgs: HashMap<String, PullMsgs>,
        kicked: bool,
        pull_count: AtomicUsize,
    }

    impl MockSyncerApi {
        fn new() -> Self {
            Self { max_seqs: HashMap::new(), pull_msgs: HashMap::new(), kicked: false, pull_count: AtomicUsize::new(0) }
        }
        fn with_max_seqs(mut self, seqs: HashMap<String, i64>) -> Self { self.max_seqs = seqs; self }
        fn with_pull_msgs(mut self, msgs: HashMap<String, PullMsgs>) -> Self { self.pull_msgs = msgs; self }
        fn with_kicked(mut self, kicked: bool) -> Self { self.kicked = kicked; self }
    }

    #[async_trait]
    impl SyncerRemoteApi for MockSyncerApi {
        async fn fetch_server_max_seqs(&self, _user_id: &str) -> Result<HashMap<String, i64>> { Ok(self.max_seqs.clone()) }
        async fn pull_messages_by_seqs(&self, _req: &PullMessageBySeqsReq) -> Result<PullMessageBySeqsResp> {
            self.pull_count.fetch_add(1, Ordering::SeqCst);
            Ok(PullMessageBySeqsResp { msgs: self.pull_msgs.clone(), ..Default::default() })
        }
        async fn is_kicked(&self) -> bool { self.kicked }
    }

    async fn setup_db() -> (Arc<Stores>, Arc<MessageHandler>) {
        let pool = create_pool_memory().await.unwrap();
        let stores = Arc::new(Stores {
            message_repo: Arc::new(MessageDao::new(pool.clone())),
            conversation_repo: Arc::new(ConversationDao::new(pool.clone())),
            friend_repo: Arc::new(FriendDao::new(pool.clone())),
            user_repo: Arc::new(UserDao::new(pool.clone())),
            group_repo: Arc::new(GroupDao::new(pool.clone())),
            sync_version_repo: Arc::new(SyncVersionDao::new(pool.clone())),
            notification_seq_dao: Arc::new(NotificationSeqDao::new(pool.clone())),
            sending_message_dao: Arc::new(SendingMessageDao::new(pool)),
        });
        let handler = Arc::new(MessageHandler::new(stores.clone(), UserId::new("test_user")));
        (stores, handler)
    }

    fn make_local_msg(conv_id: &str, client_msg_id: &str, seq: i64) -> crate::infra::database::models::LocalChatLog {
        crate::infra::database::models::LocalChatLog {
            conversation_id: conv_id.to_string(), client_msg_id: client_msg_id.to_string(),
            server_msg_id: format!("srv_{}", client_msg_id), send_id: "u1".to_string(),
            recv_id: "u2".to_string(), sender_platform_id: 1, sender_nick_name: "N".to_string(),
            sender_face_url: String::new(), session_type: 1, msg_from: 100, content_type: 101,
            content: format!("msg_{}", seq), is_read: 0, status: 2, seq,
            send_time: seq * 1000, create_time: seq * 1000,
            attached_info: String::new(), ex: String::new(), local_ex: String::new(), group_id: String::new(),
        }
    }

    fn make_msg_data(conv_id: &str, seq: i64, content: &str) -> MsgData {
        MsgData {
            send_id: "sender_1".to_string(), recv_id: "receiver_1".to_string(),
            group_id: String::new(), client_msg_id: format!("msg_{}_{}", conv_id, seq),
            server_msg_id: format!("server_{}_{}", conv_id, seq), sender_platform_id: 1,
            sender_nickname: "TestSender".to_string(), sender_face_url: String::new(),
            session_type: 1, msg_from: 100, content_type: 101,
            content: content.as_bytes().to_vec(), seq, send_time: 1000000 + seq,
            create_time: 1000000 + seq, status: 2, is_read: false, options: HashMap::new(),
            ..Default::default()
        }
    }

    fn make_syncer(remote: Arc<dyn SyncerRemoteApi>, stores: Arc<Stores>, handler: Arc<MessageHandler>) -> MessageSyncer {
        MessageSyncer::new(remote, stores, handler, UserId::new("test_user"))
    }

    #[test]
    fn test_is_notification_with_n_prefix() {
        assert!(is_notification("n_friend_apply"));
        assert!(is_notification("n_group_change"));
        assert!(is_notification("n_"));
    }

    #[test]
    fn test_is_notification_normal_conversations() {
        assert!(!is_notification("conv_123"));
        assert!(!is_notification("si_user1_user2"));
        assert!(!is_notification(""));
    }

    #[tokio::test]
    async fn test_handle_pulled_messages_stores_and_updates_seq() {
        let (stores, handler) = setup_db().await;
        let message_dao = stores.message_repo.clone();
        let remote = Arc::new(MockSyncerApi::new());
        let syncer = make_syncer(remote, stores, handler);
        let mut msgs_map = HashMap::new();
        msgs_map.insert("conv_a".to_string(), PullMsgs { msgs: vec![make_msg_data("conv_a", 1, "hello"), make_msg_data("conv_a", 2, "world")], ..Default::default() });
        syncer.handle_pulled_messages(&msgs_map).await.unwrap();
        let stored = message_dao.get_by_client_msg_id("conv_a", "msg_conv_a_1").await.unwrap();
        assert!(stored.is_some());
        let synced = syncer.synced_max_seqs.read().await;
        assert_eq!(synced.get("conv_a"), Some(&2));
    }

    #[tokio::test]
    async fn test_sync_incremental_only_pulls_gap() {
        let (stores, handler) = setup_db().await;
        let message_dao = stores.message_repo.clone();
        message_dao.batch_insert(&[make_local_msg("conv_a", "a1", 1), make_local_msg("conv_a", "a2", 2), make_local_msg("conv_a", "a3", 3)]).await.unwrap();
        let mut pull_msgs = HashMap::new();
        pull_msgs.insert("conv_a".to_string(), PullMsgs { msgs: vec![make_msg_data("conv_a", 4, "msg4"), make_msg_data("conv_a", 5, "msg5")], ..Default::default() });
        let remote = Arc::new(MockSyncerApi::new().with_pull_msgs(pull_msgs));
        let syncer = make_syncer(remote.clone(), stores, handler);
        let mut server_seqs = HashMap::new();
        server_seqs.insert("conv_a".to_string(), 5i64);
        server_seqs.insert("conv_b".to_string(), 5i64);
        syncer.sync_incremental_messages(&server_seqs).await.unwrap();
        let msg4 = message_dao.get_by_client_msg_id("conv_a", "msg_conv_a_4").await.unwrap();
        assert!(msg4.is_some());
        assert_eq!(remote.pull_count.load(Ordering::SeqCst), 1);
    }

    #[tokio::test]
    async fn test_push_trigger_continuous_seq_no_pull() {
        let (stores, handler) = setup_db().await;
        let remote = Arc::new(MockSyncerApi::new());
        let syncer = make_syncer(remote.clone(), stores, handler);
        syncer.synced_max_seqs.write().await.insert("conv_x".to_string(), 5);
        syncer.push_trigger_and_sync("conv_x", &[6, 7, 8]).await.unwrap();
        assert_eq!(remote.pull_count.load(Ordering::SeqCst), 0);
        let synced = syncer.synced_max_seqs.read().await;
        assert_eq!(synced.get("conv_x"), Some(&8));
    }

    #[tokio::test]
    async fn test_push_trigger_gap_triggers_pull() {
        let (stores, handler) = setup_db().await;
        let mut pull_msgs = HashMap::new();
        pull_msgs.insert("conv_y".to_string(), PullMsgs { msgs: vec![make_msg_data("conv_y", 6, "gap6"), make_msg_data("conv_y", 7, "gap7")], ..Default::default() });
        let remote = Arc::new(MockSyncerApi::new().with_pull_msgs(pull_msgs));
        let syncer = make_syncer(remote.clone(), stores, handler);
        syncer.synced_max_seqs.write().await.insert("conv_y".to_string(), 5);
        syncer.push_trigger_and_sync("conv_y", &[8, 9, 10]).await.unwrap();
        assert_eq!(remote.pull_count.load(Ordering::SeqCst), 1);
        let synced = syncer.synced_max_seqs.read().await;
        assert_eq!(synced.get("conv_y"), Some(&10));
    }

    #[tokio::test]
    async fn test_sync_on_login_full_flow() {
        let (stores, handler) = setup_db().await;
        let message_dao = stores.message_repo.clone();
        let mut server_seqs = HashMap::new();
        server_seqs.insert("conv_login".to_string(), 2i64);
        let mut pull_msgs = HashMap::new();
        pull_msgs.insert("conv_login".to_string(), PullMsgs { msgs: vec![make_msg_data("conv_login", 1, "m1"), make_msg_data("conv_login", 2, "m2")], ..Default::default() });
        let remote = Arc::new(MockSyncerApi::new().with_max_seqs(server_seqs).with_pull_msgs(pull_msgs));
        let syncer = make_syncer(remote, stores, handler);
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        syncer.set_event_sender(tx);
        syncer.sync_on_login().await.unwrap();
        let msg1 = message_dao.get_by_client_msg_id("conv_login", "msg_conv_login_1").await.unwrap();
        assert!(msg1.is_some());
        let mut events = Vec::new();
        while let Ok(e) = rx.try_recv() { events.push(e); }
        assert!(events.iter().any(|e| matches!(e, ConversationEvent::SyncStarted)));
        assert!(events.iter().any(|e| matches!(e, ConversationEvent::SyncFinished)));
    }

    #[tokio::test]
    async fn test_is_connection_kicked() {
        let (stores, handler) = setup_db().await;
        let remote = Arc::new(MockSyncerApi::new().with_kicked(false));
        let syncer = make_syncer(remote, stores.clone(), handler.clone());
        assert!(!syncer.is_connection_kicked().await);
        let remote2 = Arc::new(MockSyncerApi::new().with_kicked(true));
        let syncer2 = make_syncer(remote2, stores, handler);
        assert!(syncer2.is_connection_kicked().await);
    }
}

