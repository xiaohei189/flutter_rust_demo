use crate::core::connection::manager::ConnectionManager;
use crate::core::message::handler::MessageHandler;
use crate::domain::model::message::ReceivedMessage;
use crate::domain::constant::types::ws_req_identifier;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::infra::database::{ConversationDao, MessageDao, SyncVersionDao};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock, Semaphore};
use tracing::{debug, error, info, warn};

// 直接使用 openim-protocol crate 中的 pb 生成类型
use openim_protocol::sdkws::{
    MsgData, PullMsgs, PullMessageBySeqsResp, SeqRange, PullMessageBySeqsReq, PullOrder,
};

pub struct MessageSyncer {
    connection: Arc<ConnectionManager>,
    conversation_dao: Arc<ConversationDao>,
    message_dao: Arc<MessageDao>,
    sync_version_dao: Arc<SyncVersionDao>,
    message_handler: Arc<MessageHandler>,
    event_bus: Arc<EventBus>,
    max_concurrent_pulls: usize,
    pull_msg_num: i64,
    user_id: String,
    /// 已同步的最大 seq（conversation_id -> max_seq），用于推送消息 seq 连续性校验
    synced_max_seqs: Arc<RwLock<HashMap<String, i64>>>,
    /// 防止重复同步的锁（参考 Go SDK 的 startSync 加锁机制）
    sync_lock: Arc<Mutex<()>>,
}

impl MessageSyncer {
    pub fn new(
        connection: Arc<ConnectionManager>,
        conversation_dao: Arc<ConversationDao>,
        message_dao: Arc<MessageDao>,
        sync_version_dao: Arc<SyncVersionDao>,
        message_handler: Arc<MessageHandler>,
        event_bus: Arc<EventBus>,
        user_id: String,
    ) -> Self {
        Self {
            connection,
            conversation_dao,
            message_dao,
            sync_version_dao,
            message_handler,
            event_bus,
            max_concurrent_pulls: 5,
            pull_msg_num: 50,
            user_id,
            synced_max_seqs: Arc::new(RwLock::new(HashMap::new())),
            sync_lock: Arc::new(Mutex::new(())),
        }
    }

    /// 从服务端获取所有会话的最新 maxSeq
    pub async fn get_server_max_seqs(&self) -> Result<HashMap<String, i64>> {
        use openim_protocol::sdkws::{GetMaxSeqReq, GetMaxSeqResp};
        info!(">>> 开始获取服务端 max seqs");

        let req = GetMaxSeqReq {
            user_id: self.user_id.clone(),
        };
        let resp: GetMaxSeqResp = self.connection
            .send_rpc(ws_req_identifier::GET_NEWEST_SEQ, &req)
            .await
            .map_err(|e| {
                error!("获取服务端 max seqs 失败: {}", e);
                SdkError::network(format!("get server max seqs failed: {}", e))
            })?;

        info!("<<< 获取到服务端 max seqs 数量: {}", resp.max_seqs.len());
        Ok(resp.max_seqs)
    }

    /// 重连后增量同步：先从服务端获取 maxSeq，再与本地对比拉取消息
    pub async fn sync_after_reconnect(&self) -> Result<()> {
        let _guard = self.sync_lock.try_lock();
        if _guard.is_err() {
            info!("消息同步已在进行中，跳过");
            return Ok(());
        }

        info!("重连后开始增量同步消息");
        self.event_bus.publish(SdkEvent::SyncStarted);

        let server_max_seqs = self.get_server_max_seqs().await?;
        if server_max_seqs.is_empty() {
            info!("服务端无会话 seq，跳过同步");
            self.event_bus.publish(SdkEvent::SyncFinished);
            return Ok(());
        }

        for (conv_id, max_seq) in &server_max_seqs {
            let _ = self.conversation_dao.update_max_seq(conv_id, *max_seq).await;
        }

        self.sync_incremental_messages(&server_max_seqs).await?;

        self.event_bus.publish(SdkEvent::SyncFinished);
        info!("重连后增量同步完成");
        Ok(())
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

        match self.sync_all_conversations(reinstalled).await {
            Ok(()) => {
                info!("=== 消息同步成功: sync_on_login ===");
                Ok(())
            }
            Err(e) => {
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
    pub async fn load_synced_max_seqs(&self) -> Result<()> {
        let conv_seqs = self.conversation_dao.get_all_seq_pairs().await?;
        let mut map = self.synced_max_seqs.write().await;
        for (conv_id, seq) in conv_seqs {
            let local_max = self.message_dao.get_max_seq(&conv_id).await.unwrap_or(0);
            map.insert(conv_id, local_max);
        }
        info!("已加载 {} 个会话的 synced_max_seqs", map.len());
        Ok(())
    }

    pub async fn sync_all_conversations(&self, reinstalled: bool) -> Result<()> {
        info!("开始同步全部会话消息, reinstalled={}", reinstalled);

        self.event_bus.publish(SdkEvent::SyncStarted);

        // 先从服务端获取最新 maxSeq
        let server_max_seqs = self.get_server_max_seqs().await?;

        if server_max_seqs.is_empty() {
            info!("服务端无会话记录，跳过同步");
            self.event_bus.publish(SdkEvent::SyncFinished);
            return Ok(());
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

        self.event_bus.publish(SdkEvent::SyncFinished);
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

    async fn sync_all_messages_reinstall(&self, max_seq_to_sync: &HashMap<String, i64>) -> Result<()> {
        let mut need_sync_seq_map: HashMap<String, (i64, i64)> = HashMap::new();

        for (conversation_id, server_max_seq) in max_seq_to_sync {
            let local_max_seq = self.message_dao.get_max_seq(conversation_id).await.unwrap_or(0);

            if *server_max_seq > local_max_seq {
                let begin = local_max_seq + 1;
                info!("会话 {} 重装同步: local_max_seq={}, server_max_seq={}, begin={}, end={}",
                    conversation_id, local_max_seq, server_max_seq, begin, server_max_seq);
                need_sync_seq_map.insert(conversation_id.clone(), (begin, *server_max_seq));
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

        for (conv_id, (_, end_seq)) in seq_map {
            self.event_bus.publish(SdkEvent::SyncProgress {
                progress: 0,
                message: format!("同步完成 {}: seq={}", conv_id, end_seq),
            });
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

        self.event_bus.publish(SdkEvent::SyncProgress {
            progress: 0,
            message: format!("重装同步完成，共 {} 条消息", total),
        });

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
            self.message_handler.handle_messages(all_messages).await?;
        }

        Ok(())
    }

    fn clone_for_task(&self) -> Arc<Self> {
        Arc::new(Self {
            connection: self.connection.clone(),
            conversation_dao: self.conversation_dao.clone(),
            message_dao: self.message_dao.clone(),
            sync_version_dao: self.sync_version_dao.clone(),
            message_handler: self.message_handler.clone(),
            event_bus: self.event_bus.clone(),
            max_concurrent_pulls: self.max_concurrent_pulls,
            pull_msg_num: self.pull_msg_num,
            user_id: self.user_id.clone(),
            synced_max_seqs: self.synced_max_seqs.clone(),
            sync_lock: self.sync_lock.clone(),
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
