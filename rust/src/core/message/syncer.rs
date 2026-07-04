use crate::core::connection::manager::ConnectionManager;
use crate::core::message::handler::MessageHandler;
use crate::domain::model::message::ReceivedMessage;
use crate::domain::constant::types::ws_req_identifier;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::listener::conversation::{ConversationListener, ConversationEvent};
use crate::infra::database::{ConversationDao, MessageDao, NotificationSeqDao, SyncVersionDao};
use crate::infra::database::models::LocalNotificationSeq;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock, Semaphore};
use tracing::{debug, error, info, warn};

// 直接使用 openim-protocol crate 中的 pb 生成类型
use openim_protocol::sdkws::{
    MsgData, PullMsgs, PullMessageBySeqsResp, SeqRange, PullMessageBySeqsReq, PullOrder,
};

/// 判断会话是否为通知类型（对齐 Go SDK `msg_sync.go:503-505` IsNotification）
///
/// 通知类型会话的 conversationID 以 `n_` 前缀开头，如好友申请通知、群组变更通知等。
/// 这类会话的消息不需要拉取和存储，只需跟踪其 seq 以避免重复同步。
pub fn is_notification(conversation_id: &str) -> bool {
    conversation_id.starts_with("n_")
}

pub struct MessageSyncer {
    connection: Arc<ConnectionManager>,
    conversation_dao: Arc<ConversationDao>,
    message_dao: Arc<MessageDao>,
    sync_version_dao: Arc<SyncVersionDao>,
    notification_seq_dao: Arc<NotificationSeqDao>,
    message_handler: Arc<MessageHandler>,
    pub(crate) event_tx: Arc<std::sync::Mutex<Option<tokio::sync::mpsc::UnboundedSender<ConversationEvent>>>>,
    max_concurrent_pulls: usize,
    pull_msg_num: i64,
    user_id: String,
    /// 已同步的最大 seq（conversation_id -> max_seq），用于推送消息 seq 连续性校验
    synced_max_seqs: Arc<RwLock<HashMap<String, i64>>>,
    /// 防止重复同步的锁（参考 Go SDK 的 startSync 加锁机制）
    sync_lock: Arc<Mutex<()>>,
    /// 每个会话的同步锁，防止重复推送导致并发 pull
    per_conv_sync_locks: Arc<RwLock<HashMap<String, Arc<tokio::sync::Mutex<()>>>>>,
}

impl MessageSyncer {
    pub fn new(
        connection: Arc<ConnectionManager>,
        conversation_dao: Arc<ConversationDao>,
        message_dao: Arc<MessageDao>,
        sync_version_dao: Arc<SyncVersionDao>,
        notification_seq_dao: Arc<NotificationSeqDao>,
        message_handler: Arc<MessageHandler>,
        user_id: String,
    ) -> Self {
        Self {
            connection,
            conversation_dao,
            message_dao,
            sync_version_dao,
            notification_seq_dao,
            message_handler,
            event_tx: Arc::new(std::sync::Mutex::new(None)),
            max_concurrent_pulls: 5,
            pull_msg_num: 50,
            user_id,
            synced_max_seqs: Arc::new(RwLock::new(HashMap::new())),
            sync_lock: Arc::new(Mutex::new(())),
            per_conv_sync_locks: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub fn set_event_sender(&self, tx: tokio::sync::mpsc::UnboundedSender<ConversationEvent>) {
        *self.event_tx.lock().unwrap() = Some(tx);
    }

    pub(crate) fn send(&self, e: ConversationEvent) {
        let has_tx = self.event_tx.lock().unwrap().is_some();
        tracing::info!("[SEND] {:?}, has_subscriber={}", std::mem::discriminant(&e), has_tx);
        if let Some(tx) = &*self.event_tx.lock().unwrap() { let _ = tx.send(e); }
    }

    fn notify_conv(&self, f: impl FnOnce(&dyn ConversationListener)) {
    }

    fn on_sync_started(&self) { self.notify_conv(|l| l.on_sync_started()); }
    fn on_sync_finished(&self) { self.notify_conv(|l| l.on_sync_finished()); }
    fn on_sync_failed(&self, e: &str) { self.notify_conv(|l| l.on_sync_failed(e)); }
    fn on_sync_progress(&self, p: i32, m: &str) { self.notify_conv(|l| l.on_sync_progress(p, m)); }

    /// 从服务端获取所有会话的最新 maxSeq
    ///
    /// 含 3 次重试 + 指数退避（2s → 4s），对齐 Go SDK `msg_sync.go:429-449`
    pub async fn get_server_max_seqs(&self) -> Result<HashMap<String, i64>> {
        use openim_protocol::sdkws::{GetMaxSeqReq, GetMaxSeqResp};

        let max_retries = 3u32;
        let mut retry_interval = std::time::Duration::from_secs(2);

        for retry in 0..max_retries {
            if retry > 0 {
                warn!(
                    "[MsgSync] getServerMaxSeq 第 {} 次重试，等待 {:?}",
                    retry + 1, retry_interval
                );
                tokio::time::sleep(retry_interval).await;
                retry_interval *= 2;
            }

            let req = GetMaxSeqReq {
                user_id: self.user_id.clone(),
            };
            match self.connection.send_rpc::<GetMaxSeqReq, GetMaxSeqResp>(
                ws_req_identifier::GET_NEWEST_SEQ,
                &req,
            ).await {
                Ok(resp) => {
                    info!(
                        "[MsgSync] getServerMaxSeq 成功 (retry={}, count={})",
                        retry, resp.max_seqs.len()
                    );
                    return Ok(resp.max_seqs);
                }
                Err(e) => {
                    warn!("[MsgSync] getServerMaxSeq 失败 (retry={}): {:?}", retry + 1, e);
                    if retry == max_retries - 1 {
                        return Err(SdkError::network(format!(
                            "getServerMaxSeq {} 次重试均失败: {}",
                            max_retries, e
                        )));
                    }
                }
            }
        }
        unreachable!()
    }

    /// 重连后增量同步：先从服务端获取 maxSeq，再与本地对比拉取消息
    /// 检查连接是否已被踢下线
    pub async fn is_connection_kicked(&self) -> bool {
        self.connection.get_state().await == crate::core::connection::manager::ConnectionState::Kicked
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
            let _ = self.conversation_dao.update_max_seq(conv_id, *max_seq).await;
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

        let reinstalled = self.sync_version_dao.is_reinstalled().await?;
        info!("登录后开始同步全部消息，reinstalled={}", reinstalled);

        // 通知同步开始（对齐 Go SDK OnSyncServerStart）
        self.send(ConversationEvent::SyncStarted);
        self.send(ConversationEvent::SyncProgress { progress: 1, message: "同步开始".into() });

        match self.sync_all_conversations(reinstalled).await {
            Ok(()) => {
                // 同步完成：进度 100（对齐 Go SDK OnSyncServerProgress(100) + OnSyncServerFinish）
                self.send(ConversationEvent::SyncProgress { progress: 100, message: "同步完成".into() });
                self.send(ConversationEvent::SyncFinished);
                info!("=== 消息同步成功: sync_on_login ===");
                Ok(())
            }
            Err(e) => {
                // 同步失败：发布 SyncFailed 事件（对齐 Go SDK OnSyncServerFailed）
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

        // 获取或创建该会话的同步锁，防止重复推送导致并发 pull
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
            // seq 连续，无需补拉
            self.synced_max_seqs.write().await.insert(conv_id.to_string(), max_seq);
            return Ok(());
        }

        // seq 不连续，需要补拉
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
    ///
    /// 包含两部分：
    /// 1. 普通会话：从 local_chat_logs 加载 max_seq
    /// 2. 通知会话：从 local_notification_seqs 加载（对齐 Go SDK `msg_sync.go:149-156`）
    pub async fn load_synced_max_seqs(&self) -> Result<()> {
        let conv_seqs = self.conversation_dao.get_all_seq_pairs().await?;
        let mut map = self.synced_max_seqs.write().await;
        for (conv_id, seq) in conv_seqs {
            let local_max = self.message_dao.get_max_seq(&conv_id).await.unwrap_or(0);
            map.insert(conv_id, local_max);
        }

        // 加载通知会话的 seq（对齐 Go SDK msg_sync.go LoadSeq 中 GetNotificationAllSeqs）
        match self.notification_seq_dao.get_all().await {
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

    /// 设置通知会话的 seq（对齐 Go SDK `notification_model.go` SetNotificationSeq）
    ///
    /// 在通知消息处理完成后调用，持久化该通知会话的最新 seq
    pub async fn set_notification_seq(&self, conversation_id: &str, seq: i64) -> Result<()> {
        self.notification_seq_dao.set_notification_seq(conversation_id, seq).await
    }

    pub async fn sync_all_conversations(&self, reinstalled: bool) -> Result<()> {
        info!("开始同步全部会话消息, reinstalled={}", reinstalled);

        // 注意：SyncStarted/SyncFinished 事件由调用方（sync_on_login/sync_after_reconnect）负责发布
        // 此方法仅执行实际同步逻辑

        // 先从服务端获取最新 maxSeq
        let server_max_seqs = self.get_server_max_seqs().await?;

        if server_max_seqs.is_empty() {
            info!("服务端无会话记录，跳过同步");
            self.send(ConversationEvent::SyncFinished);
            return Ok(());
        }

        // 诊断日志：列出所有服务端会话及其 seq
        for (conv_id, max_seq) in &server_max_seqs {
            debug!("[SYNC_DIAG] 服务端会话: conv={}, max_seq={}, is_notification={}",
                conv_id, max_seq, is_notification(conv_id));
        }

        // 更新本地 conversation 的 max_seq
        for (conv_id, max_seq) in &server_max_seqs {
            let _ = self.conversation_dao.update_max_seq(conv_id, *max_seq).await;
        }

        // 加载已同步 seq 到内存
        self.load_synced_max_seqs().await?;

        if reinstalled {
            self.sync_all_messages_reinstall(&server_max_seqs).await?;
            self.sync_version_dao.mark_reinstall_complete("1.0.0").await?;
        } else {
            self.sync_incremental_messages(&server_max_seqs).await?;
        }

        info!("全部会话消息同步完成");
        Ok(())
    }

    async fn sync_incremental_messages(&self, max_seq_to_sync: &HashMap<String, i64>) -> Result<()> {
        let mut need_sync_seq_map: HashMap<String, (i64, i64)> = HashMap::new();

        for (conversation_id, server_max_seq) in max_seq_to_sync {
            let local_max_seq = self.message_dao.get_max_seq(conversation_id).await.unwrap_or(0);

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
    ///
    /// 对齐 Go SDK `msg_sync.go:221-263` getNeedSyncConversations 中 reinstalled=true 分支：
    /// - 通知会话（conversationID 以 `n_` 开头）不拉取消息，直接将服务端 maxSeq 写入 local_notification_seqs
    /// - 普通会话正常拉取
    async fn sync_all_messages_reinstall(&self, max_seq_to_sync: &HashMap<String, i64>) -> Result<()> {
        let mut need_sync_seq_map: HashMap<String, (i64, i64)> = HashMap::new();
        let mut notification_seq_records: Vec<LocalNotificationSeq> = Vec::new();

        for (conversation_id, server_max_seq) in max_seq_to_sync {
            if is_notification(conversation_id) {
                // 通知会话：重装模式下不拉取消息，直接将 maxSeq 持久化
                // 对齐 Go SDK getNeedSyncConversations reinstalled=true 分支
                if *server_max_seq != 0 {
                    notification_seq_records.push(LocalNotificationSeq {
                        conversation_id: conversation_id.clone(),
                        seq: *server_max_seq,
                    });
                    // 同步更新内存中的 synced_max_seqs
                    self.synced_max_seqs.write().await.insert(conversation_id.clone(), *server_max_seq);
                    info!("重装模式: 通知会话 {} 跳过拉取，直接持久化 seq={}", conversation_id, server_max_seq);
                }
                continue;
            }

            let local_max_seq = self.message_dao.get_max_seq(conversation_id).await.unwrap_or(0);

            if *server_max_seq > local_max_seq {
                let begin = local_max_seq + 1;
                info!("会话 {} 重装同步: local_max_seq={}, server_max_seq={}, begin={}, end={}",
                    conversation_id, local_max_seq, server_max_seq, begin, server_max_seq);
                need_sync_seq_map.insert(conversation_id.clone(), (begin, *server_max_seq));
            }
        }

        // 批量持久化通知 seq（对齐 Go SDK BatchInsertNotificationSeq）
        if !notification_seq_records.is_empty() {
            info!("重装模式: 持久化 {} 个通知会话的 seq", notification_seq_records.len());
            if let Err(e) = self.notification_seq_dao.batch_insert(&notification_seq_records).await {
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
        let semaphore = Arc::new(Semaphore::new(self.max_concurrent_pulls));
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
        let semaphore = Arc::new(Semaphore::new(self.max_concurrent_pulls));
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

    async fn pull_and_handle_messages(&self, seq_map: &HashMap<String, (i64, i64)>) -> Result<()> {
        let req = PullMessageBySeqsReq {
            user_id: self.user_id.clone(),
            seq_ranges: seq_map
                .iter()
                .map(|(conv_id, (begin, end))| SeqRange {
                    conversation_id: conv_id.clone(),
                    begin: *begin,
                    end: *end,
                    num: self.pull_msg_num,
                })
                .collect(),
            order: 0,
        };

        let resp: PullMessageBySeqsResp = self.connection
            .send_rpc(1002, &req)
            .await
            .map_err(|e| SdkError::network(format!("pull messages failed: {}", e)))?;

        self.handle_pulled_messages(&resp.msgs).await?;

        // 计算同步进度（对齐 Go SDK OnSyncServerProgress）
        // 进度 = 10% + (已同步会话数 / 总会话数) * 90%
        // 使用 SyncProgress 事件报告
        let total_convs = seq_map.len() as u8;
        for (idx, (conv_id, (_, end_seq))) in seq_map.iter().enumerate() {
            let progress = 10 + ((idx as u8 + 1) * 90 / total_convs.max(1));
            self.on_sync_progress(progress as i32, & format!("同步完成 {}: seq={}", conv_id, end_seq));
        }

        Ok(())
    }

    async fn pull_and_handle_messages_reinstall(&self, seq_map: &HashMap<String, (i64, i64)>, total: i64) -> Result<()> {
        let req = PullMessageBySeqsReq {
            user_id: self.user_id.clone(),
            seq_ranges: seq_map
                .iter()
                .map(|(conv_id, (begin, end))| SeqRange {
                    conversation_id: conv_id.clone(),
                    begin: *begin,
                    end: *end,
                    num: self.pull_msg_num,
                })
                .collect(),
            order: 0,
        };

        let resp: PullMessageBySeqsResp = self.connection
            .send_rpc(1002, &req)
            .await
            .map_err(|e| SdkError::network(format!("pull messages failed: {}", e)))?;

        self.handle_pulled_messages(&resp.msgs).await?;

        // 计算重装同步进度（对齐 Go SDK OnSyncServerProgress）
        let total_convs = seq_map.len() as u8;
        for (idx, (conv_id, (_, _))) in seq_map.iter().enumerate() {
            let progress = 10 + ((idx as u8 + 1) * 90 / total_convs.max(1));
            self.on_sync_progress(progress as i32, & format!("重装同步完成 {}: 共 {} 条消息", conv_id, total));
        }

        Ok(())
    }

    async fn handle_pulled_messages(&self, msgs: &HashMap<String, PullMsgs>) -> Result<()> {
        let mut all_messages = Vec::new();

        for (conv_id, pull_msgs) in msgs {
            for msg_data in &pull_msgs.msgs {
                // MsgData.content 是 bytes (Vec<u8>)，需要转为 String
                let content = String::from_utf8_lossy(&msg_data.content).to_string();
                let received_msg = ReceivedMessage {
                    server_msg_id: msg_data.server_msg_id.clone(),
                    client_msg_id: msg_data.client_msg_id.clone(),
                    send_id: msg_data.send_id.clone(),
                    recv_id: msg_data.recv_id.clone(),
                    sender_platform_id: msg_data.sender_platform_id,
                    sender_nick_name: msg_data.sender_nickname.clone(),
                    sender_face_url: msg_data.sender_face_url.clone(),
                    session_type: msg_data.session_type,
                    msg_from: msg_data.msg_from,
                    content_type: msg_data.content_type,
                    content,
                    seq: msg_data.seq,
                    send_time: msg_data.send_time,
                    create_time: msg_data.create_time,
                    conversation_id: conv_id.clone(),
                    group_id: msg_data.group_id.clone(),
                    is_online_only: msg_data.options.get("isOnlineOnly").copied().unwrap_or(false),
                };
                all_messages.push(received_msg);
            }

            // 更新 synced_max_seqs：取当前批次消息的最大 seq
            if let Some(max_seq_in_batch) = pull_msgs.msgs.iter().map(|m| m.seq).max() {
                let mut synced = self.synced_max_seqs.write().await;
                let current = synced.get(conv_id).copied().unwrap_or(0);
                if max_seq_in_batch > current {
                    synced.insert(conv_id.clone(), max_seq_in_batch);
                }
            }
        }

        if !all_messages.is_empty() {
            // 使用 handle_sync_messages 标记为同步来源，触发 RecvOfflineNewMessage 事件
            self.message_handler.handle_sync_messages(all_messages).await?;
        }

        Ok(())
    }

    fn clone_for_task(&self) -> Arc<Self> {
        Arc::new(Self {
            connection: self.connection.clone(),
            conversation_dao: self.conversation_dao.clone(),
            message_dao: self.message_dao.clone(),
            sync_version_dao: self.sync_version_dao.clone(),
            notification_seq_dao: self.notification_seq_dao.clone(),
            message_handler: self.message_handler.clone(),
            event_tx: self.event_tx.clone(),
            max_concurrent_pulls: self.max_concurrent_pulls,
            pull_msg_num: self.pull_msg_num,
            user_id: self.user_id.clone(),
            synced_max_seqs: self.synced_max_seqs.clone(),
            sync_lock: self.sync_lock.clone(),
            per_conv_sync_locks: self.per_conv_sync_locks.clone(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use prost::Message;

    #[test]
    fn test_seq_range_protobuf_encode_decode() {
        let range = SeqRange {
            conversation_id: "conv_1".to_string(),
            begin: 1,
            end: 100,
            num: 50,
        };

        let mut buf = Vec::new();
        range.encode(&mut buf).unwrap();
        assert!(!buf.is_empty());

        let decoded = SeqRange::decode(&buf[..]).unwrap();
        assert_eq!(decoded.conversation_id, "conv_1");
        assert_eq!(decoded.begin, 1);
        assert_eq!(decoded.end, 100);
        assert_eq!(decoded.num, 50);
    }

    #[test]
    fn test_pull_request_protobuf_encode() {
        use openim_protocol::sdkws::PullOrder;
        let req = PullMessageBySeqsReq {
            user_id: "user_123".to_string(),
            seq_ranges: vec![SeqRange {
                conversation_id: "conv_1".to_string(),
                begin: 1,
                end: 100,
                num: 50,
            }],
            order: PullOrder::Asc as i32,
        };

        let mut buf = Vec::new();
        req.encode(&mut buf).unwrap();
        assert!(!buf.is_empty());

        let decoded = PullMessageBySeqsReq::decode(&buf[..]).unwrap();
        assert_eq!(decoded.user_id, "user_123");
        assert_eq!(decoded.seq_ranges.len(), 1);
        assert_eq!(decoded.seq_ranges[0].conversation_id, "conv_1");
    }
}
