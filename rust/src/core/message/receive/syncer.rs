//! MessageSyncer — 负责从服务端拉取缺失消息并交给 handler 入库
//!
//! 对齐 Go SDK `internal/conversation_msg/msg_sync.go`

use super::processor::MessageProcessor;
use crate::core::context::Repositories;
use crate::core::connection::manager::ConnectionManager;
use crate::core::connection::sync_server::SyncServerApi;
use crate::domain::constant::{msg_status, pull_msg_num, sync_flag, ws_req_identifier};
use crate::domain::error::{Result, SdkError};
use crate::core::event::events::conversation::{ConversationEvent, ConversationListener, ConversationListenerExt};
use crate::core::message::notification::NotificationHandler;
use crate::core::message::receive::checker::MessageChecker;
use crate::domain::model::local::LocalNotificationSeq;
use crate::domain::model::UserId;
use async_trait::async_trait;
use openim_protocol::msg::{GetLastMessageReq, GetLastMessageResp, GetSeqMessageReq, GetSeqMessageResp};
use std::collections::{HashMap, HashSet};
use std::future::Future;
use std::sync::Arc;
use std::sync::OnceLock;
use tokio::sync::{Mutex, RwLock, Semaphore};
use tracing::{debug, error, info, warn};

// 直接使用 openim-protocol crate 中的 pb 生成类型
use openim_protocol::sdkws::{MsgData, PullMessageBySeqsReq, PullMessageBySeqsResp, PullMsgs, SeqRange};

/// 已同步最大 seq 的持久化记录表名（local_sync_version 内）
///
/// 已读回执/撤回等通知消息不落 local_chat_logs，消息表 MAX(seq) 无法代表拉取进度，
/// 否则重启后增量同步会重复拉取回执区间。此记录由拉取成功后写入，拉取判断以此为准。
const SYNCED_MAX_SEQ_TABLE: &str = "synced_max_seq";

/// ConnectionManager 的 SyncServerApi 实现
#[async_trait]
impl SyncServerApi for ConnectionManager {
    async fn fetch_server_max_seqs(&self, user_id: &str) -> Result<HashMap<String, i64>> {
        use openim_protocol::sdkws::{GetMaxSeqReq, GetMaxSeqResp};
        let req = GetMaxSeqReq { user_id: user_id.to_string() };
        fetch_server_max_seqs_with_retry(3, std::time::Duration::from_secs(2), || async {
            info!(target: "im::sync", "[Sync] getServerMaxSeq 请求: user_id={}", req.user_id);
            self.send_rpc::<GetMaxSeqReq, GetMaxSeqResp>(ws_req_identifier::GET_NEWEST_SEQ, &req).await.map(|resp| resp.max_seqs)
        })
        .await
    }

    async fn pull_messages_by_seqs(&self, req: &PullMessageBySeqsReq) -> Result<PullMessageBySeqsResp> {
        self.send_rpc(1002, req).await
    }

    async fn pull_messages_by_seq_list(&self, req: &GetSeqMessageReq) -> Result<GetSeqMessageResp> {
        self.send_rpc(ws_req_identifier::PULL_MSG_BY_SEQ_LIST, req).await
    }

    async fn pull_conv_last_message(&self, user_id: &str, conversation_ids: Vec<String>) -> Result<HashMap<String, MsgData>> {
        let req = GetLastMessageReq {
            user_id: user_id.to_string(),
            conversation_i_ds: conversation_ids,
        };
        let resp: GetLastMessageResp = self.send_rpc(ws_req_identifier::PULL_CONV_LAST_MESSAGE, &req).await?;
        Ok(resp.msgs)
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

async fn fetch_server_max_seqs_with_retry<F, Fut>(max_retries: u32, initial_interval: std::time::Duration, mut fetch: F) -> Result<HashMap<String, i64>>
where
    F: FnMut() -> Fut,
    Fut: Future<Output = Result<HashMap<String, i64>>>,
{
    let mut retry_interval = initial_interval;
    for retry in 0..max_retries {
        if retry > 0 {
            warn!(target: "im::sync", "[Sync] getServerMaxSeq 第 {} 次重试，等待 {:?}", retry + 1, retry_interval);
            tokio::time::sleep(retry_interval).await;
            retry_interval *= 2;
        }
        match fetch().await {
            Ok(seqs) => return Ok(seqs),
            Err(e) => {
                warn!(target: "im::sync", "[Sync] getServerMaxSeq 失败 (retry={}): {:?}", retry + 1, e);
                if retry == max_retries - 1 {
                    return Err(SdkError::network(format!("getServerMaxSeq {} 次重试均失败: {}", max_retries, e)));
                }
            }
        }
    }
    unreachable!()
}

/// 同步器配置参数
#[derive(Clone, Debug)]
pub struct SyncConfig {
    pub max_concurrent_pulls: usize,
}

impl Default for SyncConfig {
    fn default() -> Self {
        Self { max_concurrent_pulls: 5 }
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
/// 4. 将拉取结果交给 `MessageProcessor` 分类入库 + 触发事件
///
/// # 并发安全
///
/// - 全局 `sync_lock` 防止重复触发同步
/// - 每会话 `per_conv_sync_locks` 防止同一会话并发 pull
/// - `Semaphore` 控制最大并发拉取数
pub struct MessageSyncer {
    /// 外部依赖
    remote: Arc<dyn SyncServerApi>,
    repositories: Arc<Repositories>,
    message_processor: Arc<MessageProcessor>,
    /// 身份
    user_id: UserId,
    /// 配置
    config: SyncConfig,
    /// 事件出口（Listener trait）
    pub(crate) listener: Arc<dyn ConversationListener>,
    /// 内部状态
    synced_max_seqs: Arc<RwLock<HashMap<String, i64>>>,
    sync_lock: Arc<Mutex<()>>,
    per_conv_sync_locks: Arc<RwLock<HashMap<String, Arc<tokio::sync::Mutex<()>>>>>,
    /// 消息连续性检查器
    checker: Arc<MessageChecker>,
    /// 拉取通知消息时使用（重装/增量同步）
    notification_handler: OnceLock<Arc<NotificationHandler>>,
}

impl MessageSyncer {
    pub fn new(remote: Arc<dyn SyncServerApi>, repositories: Arc<Repositories>, message_processor: Arc<MessageProcessor>, user_id: UserId, listener: Arc<dyn ConversationListener>) -> Self {
        let checker = Arc::new(MessageChecker::new(
            remote.clone(),
            repositories.message_repo.clone(),
            repositories.conversation_repo.clone(),
            user_id.get_blocking(),
        ));
        Self {
            remote,
            repositories,
            message_processor,
            user_id,
            config: SyncConfig::default(),
            listener,
            checker,
            synced_max_seqs: Arc::new(RwLock::new(HashMap::new())),
            sync_lock: Arc::new(Mutex::new(())),
            per_conv_sync_locks: Arc::new(RwLock::new(HashMap::new())),
            notification_handler: OnceLock::new(),
        }
    }

    pub fn set_notification_handler(&self, handler: Arc<NotificationHandler>) {
        let _ = self.notification_handler.set(handler);
    }

    pub(crate) fn send(&self, e: ConversationEvent) {
        self.listener.emit(e);
    }

    /// 从服务端获取所有会话的最新 maxSeq
    pub async fn get_server_max_seqs(&self) -> Result<HashMap<String, i64>> {
        self.remote.fetch_server_max_seqs(&self.user_id.get().await).await
    }

    /// 检查连接是否已被踢下线
    pub async fn is_connection_kicked(&self) -> bool {
        self.remote.is_kicked().await
    }

    /// 当前是否处于重装模式（对齐 Go SDK 回调的 reinstalled 参数）
    async fn reinstalled_flag(&self) -> bool {
        self.repositories.sync_version_repo.is_reinstalled().await.unwrap_or(false)
    }

    pub async fn sync_after_reconnect(&self) -> Result<()> {
        let _guard = self.sync_lock.try_lock();
        if _guard.is_err() {
            info!(target: "im::sync", "[Sync] 消息同步已在进行中，跳过");
            return Ok(());
        }

        info!(target: "im::sync", "[Sync] 重连后开始增量同步消息");
        // 从 DB 加载已同步进度（synced_max_seq），否则内存为空会导致全量重拉
        self.load_synced_max_seqs().await?;
        self.send(ConversationEvent::SyncStarted(self.reinstalled_flag().await));
        self.send(ConversationEvent::SyncProgress {
            progress: 1,
            message: "重连后开始同步".into(),
        });

        let server_max_seqs = match self.get_server_max_seqs().await {
            Ok(seqs) => seqs,
            Err(e) => {
                let error_msg = format!("{}", e);
                self.send(ConversationEvent::SyncFailed {
                    reinstalled: self.reinstalled_flag().await,
                    error: error_msg.to_string(),
                });
                return Err(e);
            }
        };

        if server_max_seqs.is_empty() {
            info!(target: "im::sync", "[Sync] 服务端无会话 seq，跳过同步");
            self.send(ConversationEvent::SyncProgress {
                progress: 100,
                message: "同步完成（无需同步）".into(),
            });
            self.send(ConversationEvent::SyncFinished(self.reinstalled_flag().await));
            return Ok(());
        }

        for (conv_id, max_seq) in &server_max_seqs {
            if let Err(e) = self.repositories.conversation_repo.update_max_seq(conv_id, *max_seq).await {
                warn!(target: "im::sync", "[Sync] update_max_seq 失败 conv={}: {}", conv_id, e);
            }
        }

        match self.sync_incremental_messages(&server_max_seqs, pull_msg_num::CONNECT_PULL_NUMS).await {
            Ok(()) => {
                self.send(ConversationEvent::SyncProgress {
                    progress: 100,
                    message: "重连后同步完成".into(),
                });
                self.send(ConversationEvent::SyncFinished(self.reinstalled_flag().await));
                info!(target: "im::sync", "[Sync] 重连后增量同步完成");
                Ok(())
            }
            Err(e) => {
                let error_msg = format!("{}", e);
                self.send(ConversationEvent::SyncFailed {
                    reinstalled: self.reinstalled_flag().await,
                    error: error_msg.to_string(),
                });
                Err(e)
            }
        }
    }

    /// App 从后台回到前台时触发增量同步，单会话单次拉取数量为 10。
    pub async fn sync_on_wakeup(&self) -> Result<()> {
        let _guard = self.sync_lock.try_lock();
        if _guard.is_err() {
            info!(target: "im::sync", "[Sync] 消息同步已在进行中，跳过唤醒同步");
            return Ok(());
        }

        info!(target: "im::sync", "[Sync] 后台唤醒开始增量同步消息");
        // 从 DB 加载已同步进度（synced_max_seq），否则内存为空会导致全量重拉
        self.load_synced_max_seqs().await?;
        self.send(ConversationEvent::SyncStarted(self.reinstalled_flag().await));
        let server_max_seqs = match self.get_server_max_seqs().await {
            Ok(seqs) => seqs,
            Err(e) => {
                self.send(ConversationEvent::SyncFailed {
                    reinstalled: self.reinstalled_flag().await,
                    error: format!("{}", e),
                });
                return Err(e);
            }
        };
        if server_max_seqs.is_empty() {
            self.send(ConversationEvent::SyncFinished(self.reinstalled_flag().await));
            return Ok(());
        }
        for (conv_id, max_seq) in &server_max_seqs {
            if let Err(e) = self.repositories.conversation_repo.update_max_seq(conv_id, *max_seq).await {
                warn!(target: "im::sync", "[Sync] update_max_seq 失败 conv={}: {}", conv_id, e);
            }
        }
        self.sync_incremental_messages(&server_max_seqs, pull_msg_num::DEFAULT_PULL_NUMS).await?;
        self.send(ConversationEvent::SyncFinished(self.reinstalled_flag().await));
        info!(target: "im::sync", "[Sync] 后台唤醒增量同步完成");
        Ok(())
    }

    /// 登录后的全量同步（区分重装和普通模式）
    pub async fn sync_on_login(&self) -> Result<()> {
        info!(target: "im::sync", "[Sync] === 消息同步开始: sync_on_login ===");
        let _guard = self.sync_lock.try_lock();
        if _guard.is_err() {
            info!(target: "im::sync", "[Sync] 消息同步已在进行中，跳过");
            return Ok(());
        }

        let reinstalled = self.repositories.sync_version_repo.is_reinstalled().await?;
        info!(target: "im::sync", "[Sync] 登录后开始同步全部消息，reinstalled={}", reinstalled);

        self.send(ConversationEvent::SyncStarted(reinstalled));
        self.send(ConversationEvent::SyncProgress {
            progress: 1,
            message: "同步开始".into(),
        });

        match self.sync_all_conversations(reinstalled).await {
            Ok(()) => {
                self.send(ConversationEvent::SyncProgress {
                    progress: 100,
                    message: "同步完成".into(),
                });
                self.send(ConversationEvent::SyncFinished(reinstalled));
                info!(target: "im::sync", "[Sync] === 消息同步成功: sync_on_login ===");
                Ok(())
            }
            Err(e) => {
                let error_msg = format!("{}", e);
                self.send(ConversationEvent::SyncFailed {
                    reinstalled,
                    error: error_msg.to_string(),
                });
                error!(target: "im::sync", "[Sync] === 消息同步失败: sync_on_login, error={} ===", e);
                Err(e)
            }
        }
    }

    /// 推送消息触发同步：检测 seq 连续性，不连续时自动补拉
    pub async fn push_trigger_and_sync(&self, conv_id: &str, pushed_seqs: &[i64]) -> Result<()> {
        if pushed_seqs.is_empty() {
            return Ok(());
        }

        let conv_lock = {
            let mut locks = self.per_conv_sync_locks.write().await;
            locks.entry(conv_id.to_string()).or_insert_with(|| Arc::new(tokio::sync::Mutex::new(()))).clone()
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

        info!(target: "im::sync", "[Sync] 推送消息 seq 不连续: conv={}, expected_last={}, actual_max={}, min={}", conv_id, expected_last, max_seq, min_seq);

        let begin = expected_last + 1;
        if begin <= max_seq {
            let mut seq_map = HashMap::new();
            seq_map.insert(conv_id.to_string(), (begin, max_seq));
            self.batch_pull_messages(&seq_map, false, pull_msg_num::DEFAULT_PULL_NUMS).await?;
        }

        self.synced_max_seqs.write().await.insert(conv_id.to_string(), max_seq);
        Ok(())
    }

    /// 获取会话已同步最大 seq（对齐 Go SDK `GetSyncedMaxSeqs`：无记录即为 0，全量拉取）
    ///
    /// 不能依赖消息表 MAX(seq)：已读回执/撤回等不落库消息的 seq 不包含在内。
    async fn get_synced_max_seq(&self, conv_id: &str) -> i64 {
        match self.repositories.sync_version_repo.get_version_sync(SYNCED_MAX_SEQ_TABLE, conv_id).await {
            Ok(Some((_, v))) => v as i64,
            _ => 0,
        }
    }

    /// 持久化会话拉取进度（含回执/撤回等不落库消息的 seq），供下次启动的增量判断使用
    async fn persist_synced_max_seq(&self, conv_id: &str, seq: i64) {
        if let Err(e) = self.repositories.sync_version_repo.set_version_sync(SYNCED_MAX_SEQ_TABLE, conv_id, "", seq as u64).await {
            warn!(target: "im::sync", "[Sync] 持久化 synced_max_seq 失败 conv={}: {}", conv_id, e);
        }
    }

    /// 从本地 DB 加载已同步的 max_seq 到内存
    pub async fn load_synced_max_seqs(&self) -> Result<()> {
        let conv_seqs = self.repositories.conversation_repo.get_all_seq_pairs().await?;
        let mut map = self.synced_max_seqs.write().await;
        for (conv_id, _seq) in conv_seqs {
            let local_max = self.get_synced_max_seq(&conv_id).await;
            map.insert(conv_id, local_max);
        }

        match self.repositories.notification_seq_repo.get_all().await {
            Ok(notification_seqs) => {
                let count = notification_seqs.len();
                for ns in &notification_seqs {
                    map.insert(ns.conversation_id.clone(), ns.seq);
                }
                info!(target: "im::sync", "[Sync] 从 local_notification_seqs 加载 {} 个通知会话的进度 seq", count);
            }
            Err(e) => {
                warn!(target: "im::sync", "[Sync] 加载通知 seq 失败（忽略）: {}", e);
            }
        }

        info!(target: "im::sync", "[Sync] 拉取进度载入内存完成，共 {} 个会话（普通会话 + 通知会话）", map.len());
        Ok(())
    }

    /// 设置通知会话的 seq
    pub async fn set_notification_seq(&self, conversation_id: &str, seq: i64) -> Result<()> {
        self.repositories.notification_seq_repo.set_notification_seq(conversation_id, seq).await
    }

    pub async fn sync_all_conversations(&self, reinstalled: bool) -> Result<()> {
        info!(target: "im::sync", "[Sync] 开始同步全部会话消息, reinstalled={}", reinstalled);

        let server_max_seqs = self.get_server_max_seqs().await?;

        if server_max_seqs.is_empty() {
            info!(target: "im::sync", "[Sync] 服务端无会话记录，跳过同步");
            self.send(ConversationEvent::SyncFinished(reinstalled));
            return Ok(());
        }

        for (conv_id, max_seq) in &server_max_seqs {
            debug!(target: "im::sync", "[Sync] 服务端会话: conv={}, max_seq={}, is_notification={}", conv_id, max_seq, is_notification(conv_id));
        }

        for (conv_id, max_seq) in &server_max_seqs {
            if let Err(e) = self.repositories.conversation_repo.update_max_seq(conv_id, *max_seq).await {
                warn!(target: "im::sync", "[Sync] update_max_seq 失败 conv={}: {}", conv_id, e);
            }
        }

        self.load_synced_max_seqs().await?;

        if reinstalled {
            self.sync_all_messages_reinstall(&server_max_seqs, pull_msg_num::CONNECT_PULL_NUMS).await?;
            self.repositories.sync_version_repo.mark_reinstall_complete(crate::domain::constant::SDK_LOCAL_VERSION).await?;
            if let Err(e) = self.repositories.sync_version_repo.set_sync_flag(sync_flag::SYNC_END).await {
                warn!(target: "im::sync", "[Sync] 设置 SYNC_END 标志失败: {}", e);
            }
        } else {
            self.sync_incremental_messages(&server_max_seqs, pull_msg_num::CONNECT_PULL_NUMS).await?;
        }

        info!(target: "im::sync", "[Sync] 全部会话消息同步完成");
        Ok(())
    }

    async fn sync_incremental_messages(&self, max_seq_to_sync: &HashMap<String, i64>, pull_num: i64) -> Result<()> {
        let mut need_sync_seq_map: HashMap<String, (i64, i64)> = HashMap::new();

        // 对齐 Go SDK `compareSeqsAndBatchSync`：差量基于 synced_max_seq（DB 持久化进度，
        // 无记录时消息表 MAX(seq) 兜底）。不能依赖内存 synced_max_seqs——它由 load 填充、
        // 且 load 只遍历 local_conversations 已有会话，本地无会话记录时进度为 0 导致全量重拉
        for (conversation_id, server_max_seq) in max_seq_to_sync {
            let local_max_seq = self.get_synced_max_seq(conversation_id).await;

            if *server_max_seq > local_max_seq {
                let begin = local_max_seq + 1;
                info!(
                    target: "im::sync",
                    "[Sync] 会话 {} 需要同步: local_max_seq={}, server_max_seq={}, begin={}, end={}",
                    conversation_id, local_max_seq, server_max_seq, begin, server_max_seq
                );
                need_sync_seq_map.insert(conversation_id.clone(), (begin, *server_max_seq));
            }
        }

        if need_sync_seq_map.is_empty() {
            info!(target: "im::sync", "[Sync] 服务端 max_seq 均未超过本地进度，无需拉取");
            return Ok(());
        }

        info!(target: "im::sync", "[Sync] 需要同步 {} 个会话的消息", need_sync_seq_map.len());
        self.batch_pull_messages(&need_sync_seq_map, false, pull_num).await
    }

    /// 重装模式同步：跳过通知会话，只同步普通消息
    async fn sync_all_messages_reinstall(&self, max_seq_to_sync: &HashMap<String, i64>, pull_num: i64) -> Result<()> {
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
                    info!(target: "im::sync", "[Sync] 重装模式: 通知会话 {} 跳过拉取，直接持久化 seq={}", conversation_id, server_max_seq);
                }
                continue;
            }

            let local_max_seq = self.get_synced_max_seq(conversation_id).await;

            if *server_max_seq > local_max_seq {
                let begin = local_max_seq + 1;
                info!(
                    target: "im::sync",
                    "[Sync] 会话 {} 重装同步: local_max_seq={}, server_max_seq={}, begin={}, end={}",
                    conversation_id, local_max_seq, server_max_seq, begin, server_max_seq
                );
                need_sync_seq_map.insert(conversation_id.clone(), (begin, *server_max_seq));
            }
        }

        if !notification_seq_records.is_empty() {
            info!(target: "im::sync", "[Sync] 重装模式: 持久化 {} 个通知会话的 seq", notification_seq_records.len());
            if let Err(e) = self.repositories.notification_seq_repo.batch_insert(&notification_seq_records).await {
                warn!(target: "im::sync", "[Sync] 持久化通知 seq 失败: {}", e);
            }
        }

        if need_sync_seq_map.is_empty() {
            return Ok(());
        }

        let total = need_sync_seq_map.values().map(|(_, end)| end).sum::<i64>();
        info!(target: "im::sync", "[Sync] 重装模式，同步全部 {} 条消息", total);

        self.batch_pull_messages(&need_sync_seq_map, true, pull_num).await
    }

    async fn batch_pull_messages(&self, seq_map: &HashMap<String, (i64, i64)>, reinstall: bool, pull_num: i64) -> Result<()> {
        let semaphore = Arc::new(Semaphore::new(self.config.max_concurrent_pulls));
        let mut tasks = Vec::new();

        let batch_size = pull_msg_num::SPLIT_PULL_MSG_NUM as i64;
        let mut batches: Vec<Vec<(String, i64, i64)>> = Vec::new();
        let mut current_batch = Vec::new();
        let mut current_convs = HashSet::new();
        let mut msg_count = 0i64;

        for (conv_id, begin, end) in split_seq_ranges(seq_map, pull_num) {
            let range_size = end - begin + 1;
            // 服务端 PullMessageBySeqs 对同一会话的多个 SeqRange 会互相覆盖，
            // 因此同一请求内每个会话只能出现一个区间；需要继续拉同会话时另起一批。
            if !current_batch.is_empty() && (current_convs.contains(&conv_id) || msg_count + range_size > batch_size) {
                batches.push(std::mem::take(&mut current_batch));
                current_convs.clear();
                msg_count = 0;
            }
            current_convs.insert(conv_id.clone());
            current_batch.push((conv_id, begin, end));
            msg_count += range_size;
        }
        if !current_batch.is_empty() {
            batches.push(current_batch);
        }

        for batch in batches {
            let permit = semaphore.clone().acquire_owned().await.map_err(|e| SdkError::database(format!("acquire semaphore failed: {}", e)))?;

            let syncer_clone = self.clone_for_task();
            tasks.push(tokio::spawn(async move {
                let _permit = permit;
                syncer_clone.pull_and_handle_messages(&batch, reinstall, pull_num).await
            }));
        }

        for task in tasks {
            task.await.map_err(|e| SdkError::unknown(format!("task join failed: {}", e)))??;
        }

        Ok(())
    }

    async fn pull_and_handle_messages(&self, seq_ranges: &[(String, i64, i64)], reinstall: bool, pull_num: i64) -> Result<()> {
        let req = PullMessageBySeqsReq {
            user_id: self.user_id.get().await,
            seq_ranges: seq_ranges
                .iter()
                .map(|(conv_id, begin, end)| SeqRange {
                    conversation_id: conv_id.clone(),
                    begin: *begin,
                    end: *end,
                    num: pull_num,
                })
                .collect(),
            order: 0,
        };

        info!(
            target: "im::sync",
            "[Sync] pull_and_handle_messages 请求: user_id={}, conv_count={}, seq_ranges={:?}",
            req.user_id,
            req.seq_ranges.len(),
            req.seq_ranges.iter().map(|r| format!("{}:[{},{}]", r.conversation_id, r.begin, r.end)).collect::<Vec<_>>()
        );

        let mut resp: PullMessageBySeqsResp = self.remote.pull_messages_by_seqs(&req).await.map_err(|e| SdkError::network(format!("pull messages failed: {}", e)))?;

        if reinstall {
            self.check_messages_and_get_last_message(&mut resp.msgs).await?;
        }

        info!(
            target: "im::sync",
            "[Sync] pull_and_handle_messages: {} conversations, msgs_count={}",
            resp.msgs.len(),
            resp.msgs.values().map(|m| m.msgs.len()).sum::<usize>()
        );

        // 第 1 层：块内连续性检查
        for (_conv_id, pull_msgs) in &resp.msgs {
            let mut logs: Vec<_> = pull_msgs
                .msgs
                .iter()
                .map(|m| crate::domain::model::local::LocalChatLog {
                    conversation_id: _conv_id.clone(),
                    client_msg_id: m.client_msg_id.clone(),
                    server_msg_id: m.server_msg_id.clone(),
                    send_id: m.send_id.clone(),
                    recv_id: m.recv_id.clone(),
                    sender_platform_id: m.sender_platform_id,
                    sender_nick_name: m.sender_nickname.clone(),
                    sender_face_url: m.sender_face_url.clone(),
                    session_type: m.session_type,
                    msg_from: m.msg_from,
                    content_type: m.content_type,
                    content: String::from_utf8_lossy(&m.content).to_string(),
                    is_read: 0,
                    status: msg_status::SEND_SUCCESS,
                    seq: m.seq,
                    send_time: m.send_time,
                    create_time: m.create_time,
                    attached_info: String::new(),
                    ex: String::new(),
                    local_ex: String::new(),
                    group_id: m.group_id.clone(),
                })
                .collect();
            if let Err(e) = self.checker.validate_and_fill_internal_gaps(&mut logs, false).await {
                warn!(target: "im::sync", "[Sync] 块内连续性检查失败: conv={}, err={}", _conv_id, e);
            }
        }

        self.handle_pulled_messages(&resp.msgs).await?;

        if let Some(handler) = self.notification_handler.get() {
            for (conv_id, pull_msgs) in &resp.notification_msgs {
                handler.handle_notifications(&pull_msgs.msgs).await;
                // 对齐 Go SDK `doNotificationManager`：处理完通知批次后持久化通知进度，
                // 避免下次同步重复拉取历史通知（local_notification_seqs 表）
                if let Some(last_msg) = pull_msgs.msgs.iter().max_by_key(|m| m.seq) {
                    if last_msg.seq != 0 {
                        if let Err(e) = self.set_notification_seq(conv_id, last_msg.seq).await {
                            warn!(target: "im::sync", "[Sync] SetNotificationSeq 失败 conv={}: {}", conv_id, e);
                        }
                    }
                }
            }
        }

        // 对齐 Go SDK `syncAndTriggerMsgs`：拉取完成后按请求区间统一更新内存进度
        // （含通知会话；即使服务端返回空，也已同步到该 seq，下次不再全量重拉）
        for (conv_id, _, end_seq) in seq_ranges {
            let mut synced = self.synced_max_seqs.write().await;
            let current = synced.get(conv_id).copied().unwrap_or(0);
            if *end_seq > current {
                synced.insert(conv_id.clone(), *end_seq);
            }
        }

        // 持久化拉取进度：回执/撤回等不落库消息的 seq 也要消耗掉，避免重启后重复拉取
        for (conv_id, _, end_seq) in seq_ranges {
            self.persist_synced_max_seq(conv_id, *end_seq).await;
        }

        let total_convs = seq_ranges.len().max(1);
        for (idx, (conv_id, _, end_seq)) in seq_ranges.iter().enumerate() {
            let progress = 10 + ((idx + 1) * 90 / total_convs);
            let msg = if reinstall {
                format!("重装同步完成 {}: seq={}", conv_id, end_seq)
            } else {
                format!("同步完成 {}: seq={}", conv_id, end_seq)
            };
            self.send(ConversationEvent::SyncProgress {
                progress: progress as i32,
                message: msg,
            });
        }

        Ok(())
    }

    /// 重装模式下，如果某会话拉取到的消息全部已删除，则用会话最新有效消息替换。
    async fn check_messages_and_get_last_message(&self, msgs: &mut HashMap<String, PullMsgs>) -> Result<()> {
        let mut conversation_ids = Vec::new();
        for (conv_id, pull_msgs) in msgs.iter() {
            let all_deleted = !pull_msgs.msgs.is_empty() && pull_msgs.msgs.iter().all(|m| m.status >= msg_status::HAS_DELETED);
            if all_deleted {
                conversation_ids.push(conv_id.clone());
            }
        }
        if conversation_ids.is_empty() {
            return Ok(());
        }

        info!(target: "im::sync", "[Sync] 重装模式：{} 个会话拉取结果全部已删除，尝试拉取最新有效消息", conversation_ids.len());
        let last_messages = self.remote.pull_conv_last_message(&self.user_id.get().await, conversation_ids).await?;
        for (conv_id, message) in last_messages {
            msgs.entry(conv_id).or_default().msgs = vec![message];
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
            self.message_processor.handle_sync_messages(conv_id, messages).await?;
        }

        Ok(())
    }

    fn clone_for_task(&self) -> Arc<Self> {
        Arc::new(Self {
            remote: self.remote.clone(),
            repositories: self.repositories.clone(),
            message_processor: self.message_processor.clone(),
            user_id: self.user_id.clone(),
            config: self.config.clone(),
            listener: self.listener.clone(),
            checker: self.checker.clone(),
            synced_max_seqs: self.synced_max_seqs.clone(),
            sync_lock: self.sync_lock.clone(),
            per_conv_sync_locks: self.per_conv_sync_locks.clone(),
            notification_handler: self.notification_handler.clone(),
        })
    }
}

/// 将每个会话的拉取区间按 `pull_num` 切成多个小区间。
///
/// 服务端 `GetMsgBySeqsRange` 在 `end-begin+1 > num` 时只返回区间末尾 `num` 条，
/// 因此一次 `[begin,end]` 拉不全历史消息。按 `pull_num` 切成连续小区间后，
/// 每个小区间的条数不超过 `num`，服务端会完整返回；通知会话按 seq 列表全量返回，不拆分。
fn split_seq_ranges(seq_map: &HashMap<String, (i64, i64)>, pull_num: i64) -> Vec<(String, i64, i64)> {
    let chunk_size = pull_num.max(1);
    let mut ranges = Vec::new();
    for (conv_id, (begin, end)) in seq_map {
        if is_notification(conv_id) || chunk_size > *end - *begin {
            ranges.push((conv_id.clone(), *begin, *end));
            continue;
        }
        let mut start = *begin;
        while start <= *end {
            let chunk_end = (*end).min(start.saturating_add(chunk_size - 1));
            ranges.push((conv_id.clone(), start, chunk_end));
            start = chunk_end + 1;
        }
    }
    ranges
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::context::Repositories;
    use crate::infra::db::pool::create_pool_memory;
    use crate::infra::db::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};
    use crate::domain::model::UserId;
    use prost::Message;
    use std::sync::atomic::{AtomicUsize, Ordering};

    struct MockSyncerApi {
        max_seqs: HashMap<String, i64>,
        pull_msgs: HashMap<String, PullMsgs>,
        pull_nums: Arc<tokio::sync::Mutex<Vec<i64>>>,
        ranges: Arc<tokio::sync::Mutex<Vec<(String, i64, i64)>>>,
        kicked: bool,
        pull_count: AtomicUsize,
    }

    impl MockSyncerApi {
        fn new() -> Self {
            Self {
                max_seqs: HashMap::new(),
                pull_msgs: HashMap::new(),
                pull_nums: Arc::new(tokio::sync::Mutex::new(Vec::new())),
                ranges: Arc::new(tokio::sync::Mutex::new(Vec::new())),
                kicked: false,
                pull_count: AtomicUsize::new(0),
            }
        }
        fn with_max_seqs(mut self, seqs: HashMap<String, i64>) -> Self {
            self.max_seqs = seqs;
            self
        }
        fn with_pull_msgs(mut self, msgs: HashMap<String, PullMsgs>) -> Self {
            self.pull_msgs = msgs;
            self
        }
        fn with_kicked(mut self, kicked: bool) -> Self {
            self.kicked = kicked;
            self
        }
    }

    #[async_trait]
    impl SyncServerApi for MockSyncerApi {
        async fn fetch_server_max_seqs(&self, _user_id: &str) -> Result<HashMap<String, i64>> {
            Ok(self.max_seqs.clone())
        }
        async fn pull_messages_by_seqs(&self, _req: &PullMessageBySeqsReq) -> Result<PullMessageBySeqsResp> {
            self.pull_count.fetch_add(1, Ordering::SeqCst);
            self.pull_nums.lock().await.extend(_req.seq_ranges.iter().map(|r| r.num));
            self.ranges.lock().await.extend(_req.seq_ranges.iter().map(|r| (r.conversation_id.clone(), r.begin, r.end)));
            Ok(PullMessageBySeqsResp {
                msgs: self.pull_msgs.clone(),
                ..Default::default()
            })
        }
        async fn is_kicked(&self) -> bool {
            self.kicked
        }
        async fn pull_messages_by_seq_list(&self, _req: &GetSeqMessageReq) -> Result<GetSeqMessageResp> {
            Ok(GetSeqMessageResp {
                msgs: HashMap::new(),
                notification_msgs: HashMap::new(),
            })
        }
    }

    /// 按请求中的 SeqRange 返回对应区间消息，用于验证 `pull_num` 分页能拉全历史。
    struct PagedMockSyncerApi {
        max_seqs: HashMap<String, i64>,
        server_msgs: HashMap<String, Vec<MsgData>>,
        pull_count: AtomicUsize,
        ranges: Arc<tokio::sync::Mutex<Vec<(String, i64, i64)>>>,
    }

    impl PagedMockSyncerApi {
        fn new(max_seqs: HashMap<String, i64>, server_msgs: HashMap<String, Vec<MsgData>>) -> Self {
            Self {
                max_seqs,
                server_msgs,
                pull_count: AtomicUsize::new(0),
                ranges: Arc::new(tokio::sync::Mutex::new(Vec::new())),
            }
        }
    }

    #[async_trait]
    impl SyncServerApi for PagedMockSyncerApi {
        async fn fetch_server_max_seqs(&self, _user_id: &str) -> Result<HashMap<String, i64>> {
            Ok(self.max_seqs.clone())
        }

        async fn pull_messages_by_seqs(&self, req: &PullMessageBySeqsReq) -> Result<PullMessageBySeqsResp> {
            self.pull_count.fetch_add(1, Ordering::SeqCst);
            self.ranges.lock().await.extend(req.seq_ranges.iter().map(|r| (r.conversation_id.clone(), r.begin, r.end)));
            let mut resp = PullMessageBySeqsResp::default();
            for range in &req.seq_ranges {
                let matched: Vec<MsgData> = self
                    .server_msgs
                    .get(&range.conversation_id)
                    .map(|msgs| msgs.iter().filter(|m| m.seq >= range.begin && m.seq <= range.end).cloned().collect())
                    .unwrap_or_default();
                if matched.is_empty() {
                    continue;
                }
                // 对齐真实服务端：同一会话的多个 SeqRange 会覆盖前一次结果
                resp.msgs.insert(range.conversation_id.clone(), PullMsgs { msgs: matched, ..Default::default() });
            }
            Ok(resp)
        }

        async fn is_kicked(&self) -> bool {
            false
        }

        async fn pull_messages_by_seq_list(&self, _req: &GetSeqMessageReq) -> Result<GetSeqMessageResp> {
            Ok(GetSeqMessageResp {
                msgs: HashMap::new(),
                notification_msgs: HashMap::new(),
            })
        }
    }

    async fn setup_db() -> (Arc<Repositories>, Arc<MessageProcessor>) {
        let pool = create_pool_memory().await.unwrap();
        let repositories = Arc::new(Repositories {
            message_repo: Arc::new(MessageDao::new(pool.clone())),
            conversation_repo: Arc::new(ConversationDao::new(pool.clone())),
            friend_repo: Arc::new(FriendDao::new(pool.clone())),
            user_repo: Arc::new(UserDao::new(pool.clone())),
            group_repo: Arc::new(GroupDao::new(pool.clone())),
            sync_version_repo: Arc::new(SyncVersionDao::new(pool.clone())),
            notification_seq_repo: Arc::new(NotificationSeqDao::new(pool.clone())),
            sending_message_repo: Arc::new(SendingMessageDao::new(pool)),
        });
        let handler = Arc::new(MessageProcessor::new(
            repositories.clone(),
            UserId::new("test_user"),
            crate::core::event::test_util::noop_conversation_listener(),
            crate::core::event::test_util::noop_message_listener(),
        ));
        (repositories, handler)
    }

    fn make_local_msg(conv_id: &str, client_msg_id: &str, seq: i64) -> crate::domain::model::local::LocalChatLog {
        crate::domain::model::local::LocalChatLog {
            conversation_id: conv_id.to_string(),
            client_msg_id: client_msg_id.to_string(),
            server_msg_id: format!("srv_{}", client_msg_id),
            send_id: "u1".to_string(),
            recv_id: "u2".to_string(),
            sender_platform_id: 1,
            sender_nick_name: "N".to_string(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: format!("msg_{}", seq),
            is_read: 0,
            status: 2,
            seq,
            send_time: seq * 1000,
            create_time: seq * 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        }
    }

    /// 构造已读回执消息（content_type=2200，content 为 protobuf MarkAsReadTips）
    fn make_receipt_msg_data(conv_id: &str, seq: i64) -> MsgData {
        use crate::domain::constant::notification_type::HAS_READ_RECEIPT;
        use openim_protocol::sdkws::MarkAsReadTips;
        let tips = MarkAsReadTips {
            mark_as_read_user_id: "other_user".to_string(),
            conversation_id: conv_id.to_string(),
            seqs: vec![seq],
            has_read_seq: seq,
            ..Default::default()
        };
        let mut m = make_msg_data(conv_id, seq, "");
        m.content_type = HAS_READ_RECEIPT;
        m.content = tips.encode_to_vec();
        m.send_id = "other_user".to_string();
        m
    }

    fn make_msg_data(conv_id: &str, seq: i64, content: &str) -> MsgData {
        MsgData {
            send_id: "sender_1".to_string(),
            recv_id: "receiver_1".to_string(),
            group_id: String::new(),
            client_msg_id: format!("msg_{}_{}", conv_id, seq),
            server_msg_id: format!("server_{}_{}", conv_id, seq),
            sender_platform_id: 1,
            sender_nickname: "TestSender".to_string(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: content.as_bytes().to_vec(),
            seq,
            send_time: 1000000 + seq,
            create_time: 1000000 + seq,
            status: 2,
            is_read: false,
            options: HashMap::new(),
            ..Default::default()
        }
    }

    fn make_syncer(remote: Arc<dyn SyncServerApi>, repositories: Arc<Repositories>, handler: Arc<MessageProcessor>) -> MessageSyncer {
        MessageSyncer::new(remote, repositories, handler, UserId::new("test_user"), crate::core::event::test_util::noop_conversation_listener())
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

    #[test]
    fn test_split_seq_ranges_by_pull_num() {
        let mut seq_map = HashMap::new();
        seq_map.insert("si_a".to_string(), (1, 27));
        seq_map.insert("n_notice".to_string(), (1, 27));

        let ranges = split_seq_ranges(&seq_map, 1);
        let normal: Vec<_> = ranges.iter().filter(|(conv_id, _, _)| conv_id == "si_a").collect();
        assert_eq!(normal.len(), 27);
        assert_eq!(normal[0].1, 1);
        assert_eq!(normal[0].2, 1);
        assert_eq!(normal[26].1, 27);
        assert_eq!(normal[26].2, 27);

        // 通知会话服务端按 seq 列表全量返回，不参与分片
        assert_eq!(ranges.iter().filter(|(conv_id, _, _)| conv_id == "n_notice").count(), 1);
    }

    #[test]
    fn test_split_seq_ranges_keeps_small_ranges() {
        let mut seq_map = HashMap::new();
        seq_map.insert("si_a".to_string(), (4, 5));
        let ranges = split_seq_ranges(&seq_map, 10);
        assert_eq!(ranges, vec![("si_a".to_string(), 4, 5)]);
    }

    #[tokio::test]
    async fn test_handle_pulled_messages_stores_and_updates_seq() {
        let (repositories, handler) = setup_db().await;
        let message_dao = repositories.message_repo.clone();
        let remote = Arc::new(MockSyncerApi::new());
        let syncer = make_syncer(remote, repositories, handler);
        let mut msgs_map = HashMap::new();
        msgs_map.insert(
            "conv_a".to_string(),
            PullMsgs {
                msgs: vec![make_msg_data("conv_a", 1, "hello"), make_msg_data("conv_a", 2, "world")],
                ..Default::default()
            },
        );
        syncer.handle_pulled_messages(&msgs_map).await.unwrap();
        let stored = message_dao.get_by_client_msg_id("conv_a", "msg_conv_a_1").await.unwrap();
        assert!(stored.is_some());
        let synced = syncer.synced_max_seqs.read().await;
        assert_eq!(synced.get("conv_a"), Some(&2));
    }

    #[tokio::test]
    async fn test_sync_incremental_only_pulls_gap() {
        let (repositories, handler) = setup_db().await;
        let message_dao = repositories.message_repo.clone();
        message_dao
            .batch_insert(&[make_local_msg("conv_a", "a1", 1), make_local_msg("conv_a", "a2", 2), make_local_msg("conv_a", "a3", 3)])
            .await
            .unwrap();
        let mut pull_msgs = HashMap::new();
        pull_msgs.insert(
            "conv_a".to_string(),
            PullMsgs {
                msgs: vec![make_msg_data("conv_a", 4, "msg4"), make_msg_data("conv_a", 5, "msg5")],
                ..Default::default()
            },
        );
        let remote = Arc::new(MockSyncerApi::new().with_pull_msgs(pull_msgs));
        // 差量基于 DB synced_max_seq（对齐 Go GetSyncedMaxSeqs）：预置已同步到 seq=3，只应拉取 [4,5]
        repositories.sync_version_repo.set_version_sync("synced_max_seq", "conv_a", "", 3).await.unwrap();
        let syncer = make_syncer(remote.clone(), repositories.clone(), handler);
        let mut server_seqs = HashMap::new();
        server_seqs.insert("conv_a".to_string(), 5i64);
        syncer.sync_incremental_messages(&server_seqs, pull_msg_num::CONNECT_PULL_NUMS).await.unwrap();
        let msg4 = message_dao.get_by_client_msg_id("conv_a", "msg_conv_a_4").await.unwrap();
        assert!(msg4.is_some());
        let msg5 = message_dao.get_by_client_msg_id("conv_a", "msg_conv_a_5").await.unwrap();
        assert!(msg5.is_some());
        assert_eq!(remote.pull_count.load(Ordering::SeqCst), 2, "pull_num=1 时每个 seq 分片应独立请求");
        let ranges = remote.ranges.lock().await;
        assert_eq!(*ranges, vec![("conv_a".to_string(), 4, 4), ("conv_a".to_string(), 5, 5)]);
    }

    #[tokio::test]
    async fn test_sync_incremental_with_pull_num_one_pulls_full_history() {
        let (repositories, handler) = setup_db().await;
        let message_dao = repositories.message_repo.clone();

        let mut server_msgs = HashMap::new();
        server_msgs.insert("conv_page".to_string(), (1..=5).map(|seq| make_msg_data("conv_page", seq, &format!("page_msg_{}", seq))).collect());
        let mut max_seqs = HashMap::new();
        max_seqs.insert("conv_page".to_string(), 5);

        let remote = Arc::new(PagedMockSyncerApi::new(max_seqs.clone(), server_msgs));
        let syncer = make_syncer(remote.clone(), repositories.clone(), handler);
        syncer.sync_incremental_messages(&max_seqs, pull_msg_num::CONNECT_PULL_NUMS).await.unwrap();

        assert_eq!(remote.pull_count.load(Ordering::SeqCst), 5, "同一会话的分片必须拆成独立请求");
        let ranges = remote.ranges.lock().await;
        assert_eq!(ranges.len(), 5);
        for (idx, range) in ranges.iter().enumerate() {
            assert_eq!(range.0, "conv_page".to_string());
            assert_eq!(range.1, idx as i64 + 1);
            assert_eq!(range.2, idx as i64 + 1);
        }
        drop(ranges);

        for seq in 1..=5 {
            let stored = message_dao.get_by_client_msg_id("conv_page", &format!("msg_conv_page_{}", seq)).await.unwrap();
            assert!(stored.is_some(), "pull_num=1 时 seq={} 也应被完整拉取", seq);
        }
        let synced = repositories
            .sync_version_repo
            .get_version_sync("synced_max_seq", "conv_page")
            .await
            .unwrap()
            .map(|(_, v)| v)
            .unwrap_or(0);
        assert_eq!(synced, 5);
    }

    /// 验证：已读回执消息不落库，但拉取进度（synced_max_seq）包含回执 seq，
    /// 重启后不会重复拉取同一批回执。
    ///
    /// 场景：首次同步拉到 seq=4(普通消息)+ seq=5/6(已读回执)，回执只处理不落库，
    /// 消息表 max_seq 停在 4；拉取进度 synced_max_seq 应为 6，
    /// 重启后增量判断 local_max_seq=6 >= server_max_seq=6，不再发起拉取。
    #[tokio::test]
    async fn test_receipt_msgs_persist_sync_progress_no_repull_on_restart() {
        let (repositories, handler) = setup_db().await;
        let message_dao = repositories.message_repo.clone();

        // 首次同步后：本地已存普通消息 seq 1-3
        message_dao
            .batch_insert(&[make_local_msg("conv_a", "a1", 1), make_local_msg("conv_a", "a2", 2), make_local_msg("conv_a", "a3", 3)])
            .await
            .unwrap();

        // 服务端：seq=4 普通消息，seq=5/6 已读回执
        let mut pull_msgs = HashMap::new();
        pull_msgs.insert(
            "conv_a".to_string(),
            PullMsgs {
                msgs: vec![make_msg_data("conv_a", 4, "msg4"), make_receipt_msg_data("conv_a", 5), make_receipt_msg_data("conv_a", 6)],
                ..Default::default()
            },
        );
        let remote = Arc::new(MockSyncerApi::new().with_pull_msgs(pull_msgs));
        let mut server_seqs = HashMap::new();
        server_seqs.insert("conv_a".to_string(), 6i64);

        // 第一次同步：拉 4..6
        let syncer1 = make_syncer(remote.clone(), repositories.clone(), handler.clone());
        syncer1.sync_incremental_messages(&server_seqs, pull_msg_num::CONNECT_PULL_NUMS).await.unwrap();
        // 回执不落库：消息表 max_seq 只推进到 4
        assert_eq!(message_dao.get_max_seq("conv_a").await.unwrap(), 4, "回执 seq 不应推进消息表 max_seq");
        // 拉取进度包含回执 seq：synced_max_seq = 6
        let synced = repositories.sync_version_repo.get_version_sync("synced_max_seq", "conv_a").await.unwrap().map(|(_, v)| v).unwrap_or(0);
        assert_eq!(synced, 6, "拉取进度应包含回执 seq，避免重启后重复拉取");

        // 模拟重启（新 syncer，内存 synced_max_seqs 为空）：先按真实启动流程从 DB 加载进度，再增量同步
        let pull_before = remote.pull_count.load(Ordering::SeqCst);
        let syncer2 = make_syncer(remote.clone(), repositories, handler);
        syncer2.load_synced_max_seqs().await.unwrap();
        syncer2.sync_incremental_messages(&server_seqs, pull_msg_num::CONNECT_PULL_NUMS).await.unwrap();
        let pull_after = remote.pull_count.load(Ordering::SeqCst);

        // 修复验证：第二次同步不再发起拉取
        assert_eq!(pull_after - pull_before, 0, "重启后不应重复拉取已同步的回执区间");
    }

    #[tokio::test]
    async fn test_wakeup_sync_uses_default_pull_nums() {
        let (repositories, handler) = setup_db().await;
        let mut server_seqs = HashMap::new();
        server_seqs.insert("conv_wakeup".to_string(), 3i64);
        let remote = Arc::new(MockSyncerApi::new().with_max_seqs(server_seqs.clone()));
        let syncer = make_syncer(remote.clone(), repositories, handler);
        syncer.sync_incremental_messages(&server_seqs, pull_msg_num::DEFAULT_PULL_NUMS).await.unwrap();
        let nums = remote.pull_nums.lock().await;
        assert_eq!(nums.as_slice(), &[10]);
    }

    #[tokio::test]
    async fn test_push_trigger_continuous_seq_no_pull() {
        let (repositories, handler) = setup_db().await;
        let remote = Arc::new(MockSyncerApi::new());
        let syncer = make_syncer(remote.clone(), repositories, handler);
        syncer.synced_max_seqs.write().await.insert("conv_x".to_string(), 5);
        syncer.push_trigger_and_sync("conv_x", &[6, 7, 8]).await.unwrap();
        assert_eq!(remote.pull_count.load(Ordering::SeqCst), 0);
        let synced = syncer.synced_max_seqs.read().await;
        assert_eq!(synced.get("conv_x"), Some(&8));
    }

    #[tokio::test]
    async fn test_push_trigger_gap_triggers_pull() {
        let (repositories, handler) = setup_db().await;
        let mut pull_msgs = HashMap::new();
        pull_msgs.insert(
            "conv_y".to_string(),
            PullMsgs {
                msgs: vec![make_msg_data("conv_y", 6, "gap6"), make_msg_data("conv_y", 7, "gap7")],
                ..Default::default()
            },
        );
        let remote = Arc::new(MockSyncerApi::new().with_pull_msgs(pull_msgs));
        let syncer = make_syncer(remote.clone(), repositories, handler);
        syncer.synced_max_seqs.write().await.insert("conv_y".to_string(), 5);
        syncer.push_trigger_and_sync("conv_y", &[8, 9, 10]).await.unwrap();
        assert_eq!(remote.pull_count.load(Ordering::SeqCst), 1);
        let synced = syncer.synced_max_seqs.read().await;
        assert_eq!(synced.get("conv_y"), Some(&10));
    }

    #[tokio::test]
    async fn test_sync_on_login_full_flow() {
        let (repositories, handler) = setup_db().await;
        let message_dao = repositories.message_repo.clone();
        let mut server_seqs = HashMap::new();
        server_seqs.insert("conv_login".to_string(), 2i64);
        let mut pull_msgs = HashMap::new();
        pull_msgs.insert(
            "conv_login".to_string(),
            PullMsgs {
                msgs: vec![make_msg_data("conv_login", 1, "m1"), make_msg_data("conv_login", 2, "m2")],
                ..Default::default()
            },
        );
        let remote = Arc::new(MockSyncerApi::new().with_max_seqs(server_seqs).with_pull_msgs(pull_msgs));
        let hub = crate::core::event::hub::EventHub::new();
        let mut syncer = make_syncer(remote, repositories, handler);
        syncer.listener = hub.clone();
        let mut rx = hub.take_conv_rx().unwrap();
        syncer.sync_on_login().await.unwrap();
        let msg1 = message_dao.get_by_client_msg_id("conv_login", "msg_conv_login_1").await.unwrap();
        assert!(msg1.is_some());
        let mut events = Vec::new();
        while let Ok(e) = rx.try_recv() {
            events.push(e);
        }
        assert!(events.iter().any(|e| matches!(e, ConversationEvent::SyncStarted(_))));
        assert!(events.iter().any(|e| matches!(e, ConversationEvent::SyncFinished(_))));
    }

    #[tokio::test]
    async fn test_is_connection_kicked() {
        let (repositories, handler) = setup_db().await;
        let remote = Arc::new(MockSyncerApi::new().with_kicked(false));
        let syncer = make_syncer(remote, repositories.clone(), handler.clone());
        assert!(!syncer.is_connection_kicked().await);
        let remote2 = Arc::new(MockSyncerApi::new().with_kicked(true));
        let syncer2 = make_syncer(remote2, repositories, handler);
        assert!(syncer2.is_connection_kicked().await);
    }

    #[tokio::test]
    async fn test_fetch_server_max_seqs_retries_then_succeeds() {
        let calls = Arc::new(AtomicUsize::new(0));
        let calls_clone = calls.clone();
        let result = fetch_server_max_seqs_with_retry(3, std::time::Duration::from_millis(5), move || {
            let calls = calls_clone.clone();
            async move {
                if calls.fetch_add(1, Ordering::SeqCst) < 2 {
                    Err(SdkError::network("temporary failure"))
                } else {
                    let mut seqs = HashMap::new();
                    seqs.insert("conv_a".to_string(), 7);
                    Ok(seqs)
                }
            }
        })
        .await
        .unwrap();
        assert_eq!(calls.load(Ordering::SeqCst), 3);
        assert_eq!(result.get("conv_a"), Some(&7));
    }

    #[tokio::test]
    async fn test_fetch_server_max_seqs_gives_up_after_max_retries() {
        let calls = Arc::new(AtomicUsize::new(0));
        let calls_clone = calls.clone();
        let err = fetch_server_max_seqs_with_retry(3, std::time::Duration::from_millis(1), move || {
            let calls = calls_clone.clone();
            async move {
                calls.fetch_add(1, Ordering::SeqCst);
                Err(SdkError::network("always failing"))
            }
        })
        .await
        .unwrap_err();
        assert_eq!(calls.load(Ordering::SeqCst), 3);
        assert!(err.to_string().contains("3 次重试均失败"));
    }
}
