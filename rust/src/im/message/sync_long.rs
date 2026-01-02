use std::collections::HashMap;
use std::sync::Arc;

use anyhow::Result;

use crate::im::message::dao::MessageStore;
use crate::im::message::longconn::LongConnRpc;
use crate::im::message::models::{PullMessageBySeqsResp, SeqRange};
use crate::im::message::types::MsgStruct;
use crate::im::message::models::LocalChatLog;

/// 长连接驱动的消息同步器
///
/// - 依赖长连接事件触发（连接成功、唤醒、推送）。
/// - 缺口拉取通过 LongConnRpc，可用 HTTP 回退或真实长连 RPC。
/// - TODO: 接入长连推送的真实解析与事件派发，加入同步状态事件。
pub struct LongConnMessageSyncer {
    rpc: Arc<dyn LongConnRpc>,
    store: Arc<MessageStore>,
    user_id: String,
    /// 本地已同步的最大 seq（每会话）
    synced_max_seqs: HashMap<String, i64>,
}

/// 推送批次，用于从长连接接收消息后驱动同步。
pub struct PushBatch {
    pub conversation_id: String,
    pub msgs: Vec<MsgStruct>,
}

impl LongConnMessageSyncer {
    pub fn new(rpc: Arc<dyn LongConnRpc>, store: Arc<MessageStore>, user_id: String) -> Self {
        Self {
            rpc,
            store,
            user_id,
            synced_max_seqs: HashMap::new(),
        }
    }

    /// 使用 HTTP 回退 RPC 创建，便于过渡
    pub fn with_http_fallback(api: crate::im::message::api::MessageApi, store: Arc<MessageStore>, user_id: String) -> Self {
        let rpc = Arc::new(crate::im::message::longconn::HttpFallbackLongConn::new(api, user_id.clone()));
        Self::new(rpc, store, user_id)
    }

    /// 连接成功 / 唤醒 时调用：从服务器获取最新 max seq，对比补拉。
    pub async fn on_connected_or_wakeup(&mut self) -> Result<()> {
        self.sync_from_server().await
    }

    /// 手动同步指定会话（若为空则全量比对）。
    pub async fn on_manual_sync(&mut self, filter_convs: Option<Vec<String>>) -> Result<()> {
        self.sync_from_server_filtered(filter_convs).await
    }

    /// 处理推送消息：写库并检查缺口，缺口通过拉取补齐。
    pub async fn on_push(&mut self, batches: Vec<PushBatch>) -> Result<()> {
        let mut need_pull: Vec<SeqRange> = Vec::new();

        for batch in batches {
            let conv_id = batch.conversation_id;
            let mut msgs = batch.msgs;
            if msgs.is_empty() {
                continue;
            }
            msgs.sort_by_key(|m| m.seq);

            // 持久化推送消息
            let locals = msgs
                .iter()
                .map(|m| Self::msg_to_local(&conv_id, m))
                .collect::<Vec<_>>();
            self.store.batch_insert_message_list(&conv_id, &locals).await?;

            // 更新本地 max seq，检测是否连续
            let prev = *self.synced_max_seqs.get(&conv_id).unwrap_or(&0);
            let last_seq = msgs.last().map(|m| m.seq).unwrap_or(prev);
            let first_seq = msgs.first().map(|m| m.seq).unwrap_or(prev + 1);
            if prev + 1 < first_seq {
                // 发现缺口，按缺口拉取
                need_pull.push(SeqRange {
                    conversation_id: conv_id.clone(),
                    begin: prev + 1,
                    end: first_seq - 1,
                    num: (first_seq - 1) - (prev + 1) + 1,
                });
            }
            self.synced_max_seqs.insert(conv_id, last_seq);
        }

        if !need_pull.is_empty() {
            self.pull_and_persist(need_pull).await?;
        }
        Ok(())
    }

    async fn sync_from_server(&mut self) -> Result<()> {
        self.sync_from_server_filtered(None).await
    }

    async fn sync_from_server_filtered(&mut self, filter: Option<Vec<String>>) -> Result<()> {
        let newest = self.rpc.get_newest_seq().await?;
        let mut ranges = Vec::new();

        // for (conv_id, remote_max) in newest.max_seqs.iter() {
        //     if let Some(list) = filter.as_ref() {
        //         if !list.contains(conv_id) {
        //             continue;
        //         }
        //     }
        //     let mut local_max = *self.synced_max_seqs.get(conv_id).unwrap_or(&0);
        //     if local_max == 0 {
        //         // 尝试从本地消息表读取
        //         local_max = self.store.max_seq(conv_id).await.unwrap_or(0);
        //     }
        //     if *remote_max > local_max {
        //         ranges.push(SeqRange {
        //             conversation_id: conv_id.clone(),
        //             begin: local_max + 1,
        //             end: *remote_max,
        //             num: *remote_max - local_max,
        //         });
        //     }
        // }

        if ranges.is_empty() {
            return Ok(());
        }

        self.pull_and_persist(ranges).await
    }

    async fn pull_and_persist(&mut self, ranges: Vec<SeqRange>) -> Result<()> {
        if ranges.is_empty() {
            return Ok(());
        }
        let resp = self.rpc.pull_msg_by_ranges(ranges).await?;
        self.persist_pull_resp(resp).await
    }

    async fn persist_pull_resp(&mut self, resp: PullMessageBySeqsResp) -> Result<()> {
        for (conv_id, pull) in resp.msgs.into_iter() {
            let locals = pull.msgs.iter().map(|m| Self::msg_to_local(&conv_id, m)).collect::<Vec<_>>();
            self.store.batch_insert_message_list(&conv_id, &locals).await?;
            if let Some(last) = pull.msgs.iter().map(|m| m.seq).max() {
                self.synced_max_seqs.insert(conv_id.clone(), last);
            }
        }
        for (conv_id, pull) in resp.notification_msgs.into_iter() {
            let locals = pull.msgs.iter().map(|m| Self::msg_to_local(&conv_id, m)).collect::<Vec<_>>();
            self.store.batch_insert_message_list(&conv_id, &locals).await?;
            if let Some(last) = pull.msgs.iter().map(|m| m.seq).max() {
                self.synced_max_seqs.insert(conv_id.clone(), last);
            }
        }
        Ok(())
    }

    fn msg_to_local(conversation_id: &str, m: &MsgStruct) -> LocalChatLog {
        LocalChatLog {
            conversation_id: conversation_id.to_string(),
            client_msg_id: m.client_msg_id.clone().unwrap_or_default(),
            server_msg_id: m.server_msg_id.clone().unwrap_or_default(),
            send_id: m.send_id.clone().unwrap_or_default(),
            recv_id: m.recv_id.clone().unwrap_or_default(),
            sender_platform_id: m.sender_platform_id,
            sender_nickname: m.sender_nickname.clone().unwrap_or_default(),
            sender_face_url: m.sender_face_url.clone().unwrap_or_default(),
            session_type: m.session_type,
            msg_from: m.msg_from,
            content_type: m.content_type,
            content: m.content.clone().unwrap_or_default(),
            is_read: m.is_read,
            status: m.status,
            seq: m.seq,
            send_time: m.send_time,
            create_time: m.create_time,
            attached_info: m.attached_info.clone().unwrap_or_default(),
            ex: m.ex.clone().unwrap_or_default(),
            local_ex: m.local_ex.clone().unwrap_or_default(),
            group_id: m.group_id.clone().unwrap_or_default(),
        }
    }
}


