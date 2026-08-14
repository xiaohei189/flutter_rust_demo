//! Seq gap 异常消息处理 — 消息列表连续性检查与缺失补拉
//!
//! 对齐 Go SDK internal/conversation_msg/message_check.go
//!
//! 三层连续性验证管道：
//! 1. alidate_and_fill_internal_gaps — 块内连续性检查
//! 2. alidate_and_fill_inter_block_gaps — 块间连续性检查
//! 3. alidate_and_fill_end_block_continuity — 末尾连续性检查
//!
//! 由 MessageSyncer 在拉取消息后调用，确保消息 seq 连续性。
//! 消息翻页加载场景也可直接使用。

use crate::connection::sync_server::SyncServerApi;
use crate::constant::{msg_status, pull_msg_num};
use crate::db::{ConversationRepository, MessageRepository};
use crate::error::{Result, SdkError};
use crate::model::local::LocalChatLog;
use openim_protocol::msg::{ConversationSeqs, GetSeqMessageReq, GetSeqMessageResp};
use openim_protocol::sdkws::PullOrder;
use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use tracing::{debug, info, warn};

/// 消息连续性检查器
///
/// 对齐 Go SDK conversation_msg.go 中的 getMessages 方法所调用的三层检查管道。
/// 负责在消息翻页/同步时检测 seq 间隙并从服务端补拉缺失消息。
pub struct MessageChecker {
    remote: Arc<dyn SyncServerApi>,
    message_repo: Arc<dyn MessageRepository>,
    conversation_repo: Arc<dyn ConversationRepository>,
    user_id: String,
}

/// 翻页拉取的 seq 缓存上下文
///
/// 对齐 Go SDK conversation_seq_cache.go 中的 ConversationSeqContextCache。
/// 记录每次拉取的结束 seq，用于块间连续性检查。
#[derive(Default, Clone, Debug)]
pub struct SeqPullContext {
    /// 正向拉取的结束 seq 缓存（conversation_id -> end_seq）
    pub forward_end_seq_map: HashMap<String, i64>,
    /// 反向拉取的结束 seq 缓存（conversation_id -> end_seq）
    pub reverse_end_seq_map: HashMap<String, i64>,
}

impl SeqPullContext {
    /// 更新结束 seq 缓存（对齐 Go `StoreWithFunc` 的 min/max 语义）。
    ///
    /// 正向翻页：只保留更小的 end_seq；反向翻页：只保留更大的 end_seq。
    pub fn update_end_seq(&mut self, conversation_id: &str, this_end_seq: i64, is_reverse: bool) -> i64 {
        let map = if is_reverse { &mut self.reverse_end_seq_map } else { &mut self.forward_end_seq_map };
        let last_end_seq = map.get(conversation_id).copied().unwrap_or(0);
        let should_store = if is_reverse {
            this_end_seq > last_end_seq || last_end_seq == 0
        } else {
            this_end_seq < last_end_seq || last_end_seq == 0
        };
        if should_store && this_end_seq != 0 {
            map.insert(conversation_id.to_string(), this_end_seq);
            this_end_seq
        } else {
            last_end_seq
        }
    }

    /// 计算本批消息的边界 seq（对齐 Go `shouldFetchMoreMessagesNum` 中的 thisEndSeq）。
    ///
    /// 正向翻页取最小 seq（最旧边界），反向翻页取最大 seq（最新边界）。
    pub fn batch_end_seq(messages: &[LocalChatLog], is_reverse: bool) -> i64 {
        let mut end_seq = 0i64;
        for msg in messages {
            if msg.seq == 0 {
                continue;
            }
            if end_seq == 0 {
                end_seq = msg.seq;
            } else if (is_reverse && msg.seq > end_seq) || (!is_reverse && msg.seq < end_seq) {
                end_seq = msg.seq;
            }
        }
        end_seq
    }
}

impl MessageChecker {
    pub fn new(remote: Arc<dyn SyncServerApi>, message_repo: Arc<dyn MessageRepository>, conversation_repo: Arc<dyn ConversationRepository>, user_id: String) -> Self {
        Self {
            remote,
            message_repo,
            conversation_repo,
            user_id,
        }
    }

    /// 第 1 层：块内连续性检查（对齐 Go SDK alidateAndFillInternalGaps）
    ///
    /// 检查一批消息内部是否存在 seq 间隙，发现缺口后通过 1005 RPC 补拉。
    /// 返回本批消息的边界 seq（反序返回 minSeq，正序返回 maxSeq）。
    pub async fn validate_and_fill_internal_gaps(&self, messages: &mut Vec<LocalChatLog>, is_reverse: bool) -> Result<i64> {
        let (max_seq, min_seq, have_seq_list) = get_max_and_min_have_seq_list(messages);

        let lost_seqs = get_lost_seq_list_with_limit_length(min_seq, max_seq, &have_seq_list, is_reverse);

        if !lost_seqs.is_empty() {
            debug!(target: "im::sync", "[Sync] 块内间隙: min={}, max={}, lost_count={}", min_seq, max_seq, lost_seqs.len());
            if let Some(fetched) = self.fetch_and_merge_missing_messages(&first_conversation_id(messages), &lost_seqs, is_reverse).await? {
                messages.extend(fetched);
            }
        }

        Ok(if is_reverse { min_seq } else { max_seq })
    }

    /// 第 2 层：块间连续性检查（对齐 Go SDK alidateAndFillInterBlockGaps）
    ///
    /// 检查当前批次与上一批次之间是否存在 seq 间隙。
    pub async fn validate_and_fill_inter_block_gaps(&self, conversation_id: &str, messages: &mut Vec<LocalChatLog>, last_end_seq: i64, is_reverse: bool) -> Result<()> {
        if last_end_seq == 0 || messages.is_empty() {
            return Ok(());
        }

        let (max_seq, min_seq, have_seq_list) = get_max_and_min_have_seq_list(messages);

        let (gap_begin, gap_end) = if is_reverse {
            // 反向拉取：上一批的 lastEndSeq+1 到当前批次的 maxSeq
            if last_end_seq + 1 > max_seq || max_seq == 0 {
                return Ok(());
            }
            (last_end_seq + 1, max_seq - 1)
        } else {
            // 正向拉取：当前批次的 minSeq+1 到 lastEndSeq
            if min_seq == 0 || min_seq + 1 > last_end_seq {
                return Ok(());
            }
            (min_seq + 1, last_end_seq - 1)
        };

        if gap_begin > gap_end {
            return Ok(());
        }

        let lost_seqs = get_lost_seq_list_with_limit_length(gap_begin, gap_end, &have_seq_list, is_reverse);

        if !lost_seqs.is_empty() {
            info!(target: "im::sync", "[Sync] 块间间隙: conv={}, gap=[{}, {}], lost_count={}", conversation_id, gap_begin, gap_end, lost_seqs.len());
            if let Some(fetched) = self.fetch_and_merge_missing_messages(conversation_id, &lost_seqs, is_reverse).await? {
                messages.extend(fetched);
            }
        }

        Ok(())
    }

    /// 第 3 层：末尾连续性检查（对齐 Go SDK alidateAndFillEndBlockContinuity）
    ///
    /// 当拉取到的消息数量少于请求数量时，判断是否已到底。如果未到底则补拉缺失消息。
    pub async fn validate_and_fill_end_block_continuity(&self, conversation_id: &str, messages: &mut Vec<LocalChatLog>, request_count: i64, last_end_seq: i64, is_reverse: bool) -> Result<bool> {
        let (is_end, lost_seqs) = self.check_end_block(conversation_id, messages, request_count, last_end_seq, is_reverse).await?;

        if is_end {
            return Ok(true);
        }

        if !lost_seqs.is_empty() {
            info!(target: "im::sync", "[Sync] 末尾不连续: conv={}, lost_count={}", conversation_id, lost_seqs.len());
            if let Some(fetched) = self.fetch_and_merge_missing_messages(conversation_id, &lost_seqs, is_reverse).await? {
                messages.extend(fetched);
            }

            // 再次检查是否到底
            let (is_end_after, _) = self.check_end_block(conversation_id, messages, request_count, last_end_seq, is_reverse).await?;
            return Ok(is_end_after);
        }

        Ok(false)
    }

    /// alidate_and_fill_end_block_continuity 的核心逻辑（对齐 Go SDK checkEndBlock）
    async fn check_end_block(&self, conversation_id: &str, messages: &[LocalChatLog], request_count: i64, last_end_seq: i64, is_reverse: bool) -> Result<(bool, Vec<i64>)> {
        if messages.len() as i64 >= request_count {
            // 拉满说明可能还有更多，不算到底
            return Ok((false, Vec::new()));
        }

        let (max_seq, min_seq, have_seq_list) = get_max_and_min_have_seq_list(messages);

        if is_reverse {
            // 反向拉取：比较 maxSeq 与会话的 maxSeq（currentMaxSeq）
            let current_max_seq = self.get_conversation_max_seq(conversation_id).await;
            if max_seq >= current_max_seq || max_seq == 0 && last_end_seq >= current_max_seq {
                return Ok((true, Vec::new()));
            }
            // 需要拉取 [maxSeq+1, currentMaxSeq] 范围内的缺失消息
            if max_seq > 0 && max_seq < current_max_seq {
                let lost = get_lost_seq_list_with_limit_length(max_seq + 1, current_max_seq, &have_seq_list, true);
                return Ok((false, lost));
            }
            Ok((false, Vec::new()))
        } else {
            // 正向拉取：比较 minSeq 与会话的 minSeq（userCanPullMinSeq）
            let user_can_pull_min_seq = self.get_conversation_min_seq(conversation_id).await;
            if min_seq <= user_can_pull_min_seq || min_seq == 0 && last_end_seq <= user_can_pull_min_seq {
                return Ok((true, Vec::new()));
            }
            // 需要拉取 [userCanPullMinSeq, minSeq-1] 范围内的缺失消息
            if min_seq > user_can_pull_min_seq && min_seq > 0 {
                let lost = get_lost_seq_list_with_limit_length(user_can_pull_min_seq, min_seq - 1, &have_seq_list, false);
                return Ok((false, lost));
            }
            Ok((false, Vec::new()))
        }
    }

    /// 通过 seq 列表从服务端拉取缺失消息并合并（对齐 Go SDK etchAndMergeMissingMessages）
    ///
    /// 使用 1005 (PULL_MSG_BY_SEQ_LIST) RPC 调用。
    async fn fetch_and_merge_missing_messages(&self, conversation_id: &str, seq_list: &[i64], is_reverse: bool) -> Result<Option<Vec<LocalChatLog>>> {
        if seq_list.is_empty() {
            return Ok(None);
        }

        // 本地已软删（status>=4）的 seq 视为已存在，跳过补拉，避免服务端把已删消息复活
        let local_logs = self.message_repo.get_by_seqs(conversation_id, seq_list).await.unwrap_or_default();
        let deleted_seqs: HashSet<i64> = local_logs.iter().filter(|log| log.status >= msg_status::HAS_DELETED).map(|log| log.seq).collect();
        let pending_seqs: Vec<i64> = seq_list.iter().copied().filter(|seq| !deleted_seqs.contains(seq)).collect();
        if pending_seqs.is_empty() {
            return Ok(None);
        }

        let order = if is_reverse { PullOrder::Desc as i32 } else { PullOrder::Asc as i32 };

        let req = GetSeqMessageReq {
            user_id: self.user_id.clone(),
            conversations: vec![ConversationSeqs {
                conversation_id: conversation_id.to_string(),
                seqs: pending_seqs.clone(),
            }],
            order,
        };

        info!(
            target: "im::sync",
            "[Sync] fetch_missing_messages 请求: user_id={}, conv={}, seqs={:?}, order={}",
            req.user_id, conversation_id, pending_seqs, order
        );

        let resp: GetSeqMessageResp = self
            .remote
            .pull_messages_by_seq_list(&req)
            .await
            .map_err(|e| SdkError::network(format!("fetch missing messages by seq list failed: {}", e)))?;

        info!(
            target: "im::sync",
            "[Sync] fetch_missing_messages: conv={}, seqs_requested={}, msgs_fetched={}",
            conversation_id,
            pending_seqs.len(),
            resp.msgs.values().map(|m| m.msgs.len()).sum::<usize>()
        );

        // 入库拉取到的消息
        let mut fetched_logs: Vec<LocalChatLog> = Vec::new();
        for (conv_id, pull_msgs) in &resp.msgs {
            for msg_data in &pull_msgs.msgs {
                // 对齐 Go `MsgDataToLocalChatLog`：服务端已删除（status>=4）时保留删除状态，
                // 避免删除后 gap 补拉把已删消息复活。
                let local_log = LocalChatLog::from_msg_data(conv_id, msg_data);
                fetched_logs.push(local_log);
            }

            // 如果服务端标记 is_end=true，更新会话的 min_seq / max_seq
            if pull_msgs.is_end {
                let end_seq = pull_msgs.end_seq;
                if end_seq > 0 {
                    self.update_conversation_seq_boundary(conv_id, end_seq, is_reverse).await;
                }
            }
        }

        if !fetched_logs.is_empty() {
            // 入库
            if let Err(e) = self.message_repo.batch_insert(&fetched_logs).await {
                warn!(target: "im::sync", "[Sync] 缺失消息入库失败: {}", e);
            }

            info!(target: "im::sync", "[Sync] 补拉缺失消息: conv={}, count={}", conversation_id, fetched_logs.len());
            Ok(Some(fetched_logs))
        } else {
            Ok(None)
        }
    }

    /// 更新会话的 min_seq 或 max_seq（对齐 Go SDK setConversationMinSeq）
    async fn update_conversation_seq_boundary(&self, conversation_id: &str, end_seq: i64, is_reverse: bool) {
        if is_reverse {
            // 反向拉取：更新 max_seq（取较小值）
            if let Ok(current) = self.conversation_repo.get_max_seq(conversation_id).await {
                if end_seq < current || current == 0 {
                    let _ = self.conversation_repo.update_max_seq(conversation_id, end_seq).await;
                }
            }
        } else {
            // 正向拉取：更新 min_seq（取较大值）
            if let Ok(current) = self.conversation_repo.get_min_seq(conversation_id).await {
                if end_seq > current {
                    let _ = self.conversation_repo.update_min_seq(conversation_id, end_seq).await;
                }
            }
        }
    }

    /// 获取会话的 maxSeq（对齐 Go SDK getConversationMaxSeq）
    async fn get_conversation_max_seq(&self, conversation_id: &str) -> i64 {
        self.conversation_repo
            .get_max_seq(conversation_id)
            .await
            .unwrap_or(0)
            .max(self.message_repo.get_max_seq(conversation_id).await.unwrap_or(0))
    }

    /// 获取会话的 minSeq（对齐 Go SDK getConversationMinSeq）
    async fn get_conversation_min_seq(&self, conversation_id: &str) -> i64 {
        self.conversation_repo.get_min_seq(conversation_id).await.unwrap_or(0).max(1)
    }
}

// ============================================================================
// 辅助函数（对齐 Go SDK 各 helper）
// ============================================================================

/// 从消息列表中提取 maxSeq、minSeq 和已有的 seq 列表
/// 对齐 Go SDK getMaxAndMinHaveSeqList
fn get_max_and_min_have_seq_list(messages: &[LocalChatLog]) -> (i64, i64, Vec<i64>) {
    let mut max_seq = 0i64;
    let mut min_seq = i64::MAX;
    let mut have_seq_list = Vec::new();

    for msg in messages {
        if msg.seq > 0 {
            have_seq_list.push(msg.seq);
            if msg.seq > max_seq {
                max_seq = msg.seq;
            }
            if msg.seq < min_seq {
                min_seq = msg.seq;
            }
        }
    }

    if min_seq == i64::MAX {
        min_seq = 0;
    }

    (max_seq, min_seq, have_seq_list)
}

/// 计算 [min_seq, max_seq] 范围内缺失的 seq 列表（对齐 Go SDK getLostSeqListWithLimitLength）
///
/// 返回不在 have_seq_list 中的 seq，数量限制为 pull_msg_num::PULL_MSG_NUM_FOR_READ_DIFFUSION。
fn get_lost_seq_list_with_limit_length(min_seq: i64, max_seq: i64, have_seq_list: &[i64], is_reverse: bool) -> Vec<i64> {
    if min_seq > max_seq || min_seq <= 0 {
        return Vec::new();
    }

    let have_set: HashSet<i64> = have_seq_list.iter().copied().collect();
    let mut lost_seqs: Vec<i64> = (min_seq..=max_seq).filter(|seq| !have_set.contains(seq)).collect();

    let limit = pull_msg_num::PULL_MSG_NUM_FOR_READ_DIFFUSION as usize;
    if lost_seqs.len() > limit {
        if is_reverse {
            // 反向：取前 N 个（靠近 minSeq 端）
            lost_seqs.truncate(limit);
        } else {
            // 正向：取后 N 个（靠近 maxSeq 端）
            let start = lost_seqs.len() - limit;
            lost_seqs = lost_seqs[start..].to_vec();
        }
    }

    lost_seqs
}

/// 获取消息列表中的 conversation_id（取第一条的）
fn first_conversation_id(messages: &[LocalChatLog]) -> String {
    messages.first().map(|m| m.conversation_id.clone()).unwrap_or_default()
}

/// 归并两个已排序的 LocalChatLog 切片（对齐 Go SDK mergeSortedArrays）
///
/// - is_desc=true：按 send_time 降序，相同 send_time 按 seq 降序
/// - is_desc=false：按 send_time 升序，相同 send_time 按 seq 升序
fn merge_sorted_arrays(a: &[LocalChatLog], b: &[LocalChatLog], n: usize, is_desc: bool) -> Vec<LocalChatLog> {
    let mut result = Vec::with_capacity(a.len() + b.len());
    let mut i = 0;
    let mut j = 0;

    while i < a.len() && j < b.len() && result.len() < n {
        let should_pick_a = if is_desc {
            if a[i].send_time != b[j].send_time {
                a[i].send_time >= b[j].send_time
            } else {
                a[i].seq >= b[j].seq
            }
        } else {
            if a[i].send_time != b[j].send_time {
                a[i].send_time <= b[j].send_time
            } else {
                a[i].seq <= b[j].seq
            }
        };

        if should_pick_a {
            result.push(a[i].clone());
            i += 1;
        } else {
            result.push(b[j].clone());
            j += 1;
        }
    }

    while i < a.len() && result.len() < n {
        result.push(a[i].clone());
        i += 1;
    }
    while j < b.len() && result.len() < n {
        result.push(b[j].clone());
        j += 1;
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::local::LocalChatLog;

    fn make_log(client_msg_id: &str, seq: i64, send_time: i64) -> LocalChatLog {
        LocalChatLog {
            conversation_id: "conv_1".into(),
            client_msg_id: client_msg_id.into(),
            server_msg_id: String::new(),
            send_id: "user_1".into(),
            recv_id: "user_2".into(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: String::new(),
            is_read: 0,
            status: msg_status::SEND_SUCCESS,
            seq,
            send_time,
            create_time: send_time,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        }
    }

    #[test]
    fn test_get_max_and_min_have_seq_list() {
        let msgs = vec![
            make_log("a", 5, 5000),
            make_log("b", 3, 3000),
            make_log("c", 7, 7000),
            make_log("d", 0, 1000), // seq=0，不计入
        ];
        let (max, min, list) = get_max_and_min_have_seq_list(&msgs);
        assert_eq!(max, 7);
        assert_eq!(min, 3);
        assert_eq!(list.len(), 3);
        assert!(list.contains(&3));
        assert!(list.contains(&5));
        assert!(list.contains(&7));
    }

    #[test]
    fn test_get_lost_seq_list_forward() {
        let lost = get_lost_seq_list_with_limit_length(1, 6, &[1, 3, 5], false);
        assert_eq!(lost, vec![2, 4, 6]);
    }

    #[test]
    fn test_get_lost_seq_list_reverse() {
        let lost = get_lost_seq_list_with_limit_length(1, 6, &[1, 3, 5], true);
        assert_eq!(lost, vec![2, 4, 6]);
    }

    #[test]
    fn test_get_lost_seq_list_with_limit() {
        let have: Vec<i64> = vec![1, 10];
        let lost = get_lost_seq_list_with_limit_length(1, 20, &have, false);
        assert_eq!(lost.len(), 18);
    }

    #[test]
    fn test_get_lost_seq_list_empty_range() {
        let lost = get_lost_seq_list_with_limit_length(10, 5, &[], false);
        assert!(lost.is_empty());
    }

    #[test]
    fn test_merge_sorted_arrays_desc() {
        let a = vec![make_log("a1", 3, 3000), make_log("a2", 1, 1000)];
        let b = vec![make_log("b1", 4, 4000), make_log("b2", 2, 2000)];
        let merged = merge_sorted_arrays(&a, &b, 10, true);
        assert_eq!(merged.len(), 4);
        assert_eq!(merged[0].seq, 4);
        assert_eq!(merged[1].seq, 3);
        assert_eq!(merged[2].seq, 2);
        assert_eq!(merged[3].seq, 1);
    }

    #[test]
    fn test_merge_sorted_arrays_asc() {
        let a = vec![make_log("a1", 1, 1000), make_log("a2", 3, 3000)];
        let b = vec![make_log("b1", 2, 2000), make_log("b2", 4, 4000)];
        let merged = merge_sorted_arrays(&a, &b, 10, false);
        assert_eq!(merged.len(), 4);
        assert_eq!(merged[0].seq, 1);
        assert_eq!(merged[1].seq, 2);
        assert_eq!(merged[2].seq, 3);
        assert_eq!(merged[3].seq, 4);
    }

    #[test]
    fn test_merge_sorted_arrays_limit() {
        let a = vec![make_log("a2", 3, 3000), make_log("a1", 1, 1000)];
        let b = vec![make_log("b2", 4, 4000), make_log("b1", 2, 2000)];
        let merged = merge_sorted_arrays(&a, &b, 2, true);
        assert_eq!(merged.len(), 2);
        assert_eq!(merged[0].seq, 4);
        assert_eq!(merged[1].seq, 3);
    }

    // ========================================================================
    // 边界条件测试
    // ========================================================================

    #[test]
    fn test_get_max_min_empty_messages() {
        let msgs: Vec<LocalChatLog> = vec![];
        let (max, min, list) = get_max_and_min_have_seq_list(&msgs);
        assert_eq!(max, 0);
        assert_eq!(min, 0);
        assert!(list.is_empty());
    }

    #[test]
    fn test_get_max_min_all_zero_seq() {
        let msgs = vec![make_log("a", 0, 1000), make_log("b", 0, 2000)];
        let (max, min, list) = get_max_and_min_have_seq_list(&msgs);
        assert_eq!(max, 0);
        assert_eq!(min, 0);
        assert!(list.is_empty(), "seq=0 should not be included");
    }

    #[test]
    fn test_get_max_min_single_message() {
        let msgs = vec![make_log("a", 42, 1000)];
        let (max, min, list) = get_max_and_min_have_seq_list(&msgs);
        assert_eq!(max, 42);
        assert_eq!(min, 42);
        assert_eq!(list, vec![42]);
    }

    #[test]
    fn test_get_lost_seq_no_gaps() {
        let lost = get_lost_seq_list_with_limit_length(1, 5, &[1, 2, 3, 4, 5], false);
        assert!(lost.is_empty());
    }

    #[test]
    fn test_get_lost_seq_all_missing() {
        let lost = get_lost_seq_list_with_limit_length(1, 5, &[], false);
        assert_eq!(lost, vec![1, 2, 3, 4, 5]);
    }

    #[test]
    fn test_get_lost_seq_min_zero_returns_empty() {
        let lost = get_lost_seq_list_with_limit_length(0, 10, &[], false);
        assert!(lost.is_empty());
        let lost = get_lost_seq_list_with_limit_length(-1, 10, &[], false);
        assert!(lost.is_empty());
    }

    #[test]
    fn test_get_lost_seq_limit_forward_takes_tail() {
        let lost = get_lost_seq_list_with_limit_length(1, 100, &[], false);
        assert_eq!(lost.len(), 50);
        assert_eq!(*lost.first().unwrap(), 51);
        assert_eq!(*lost.last().unwrap(), 100);
    }

    #[test]
    fn test_get_lost_seq_limit_reverse_takes_head() {
        let lost = get_lost_seq_list_with_limit_length(1, 100, &[], true);
        assert_eq!(lost.len(), 50);
        assert_eq!(*lost.first().unwrap(), 1);
        assert_eq!(*lost.last().unwrap(), 50);
    }

    #[test]
    fn test_merge_sorted_arrays_empty_inputs() {
        let empty: Vec<LocalChatLog> = vec![];
        let a = vec![make_log("a1", 1, 1000)];

        let merged = merge_sorted_arrays(&a, &empty, 10, true);
        assert_eq!(merged.len(), 1);
        assert_eq!(merged[0].seq, 1);

        let merged = merge_sorted_arrays(&empty, &empty, 10, true);
        assert!(merged.is_empty());
    }

    #[test]
    fn test_merge_sorted_arrays_same_send_time() {
        let a = vec![make_log("a1", 3, 1000)];
        let b = vec![make_log("b1", 5, 1000)];

        let merged = merge_sorted_arrays(&a, &b, 10, true);
        assert_eq!(merged[0].seq, 5);
        assert_eq!(merged[1].seq, 3);

        let merged = merge_sorted_arrays(&a, &b, 10, false);
        assert_eq!(merged[0].seq, 3);
        assert_eq!(merged[1].seq, 5);
    }

    #[test]
    fn test_merge_sorted_arrays_limit_zero() {
        let a = vec![make_log("a1", 1, 1000)];
        let b = vec![make_log("b1", 2, 2000)];
        let merged = merge_sorted_arrays(&a, &b, 0, true);
        assert!(merged.is_empty(), "limit=0 should return empty");
    }

    #[tokio::test]
    async fn test_fetch_missing_preserves_deleted_status() {
        use crate::connection::sync_server::SyncServerApi;
        use crate::db::pool::create_pool_memory;
        use crate::db::{ConversationDao, MessageDao};
        use async_trait::async_trait;
        use openim_protocol::msg::{GetSeqMessageReq, GetSeqMessageResp};
        use openim_protocol::sdkws::{MsgData, PullMessageBySeqsReq, PullMessageBySeqsResp, PullMsgs};
        use std::collections::HashMap;

        struct DeletedMsgMock {
            msgs: HashMap<String, PullMsgs>,
        }

        #[async_trait]
        impl SyncServerApi for DeletedMsgMock {
            async fn fetch_server_max_seqs(&self, _user_id: &str) -> crate::error::Result<HashMap<String, i64>> {
                Ok(HashMap::new())
            }
            async fn pull_messages_by_seqs(&self, _req: &PullMessageBySeqsReq) -> crate::error::Result<PullMessageBySeqsResp> {
                Ok(PullMessageBySeqsResp {
                    msgs: HashMap::new(),
                    notification_msgs: HashMap::new(),
                })
            }
            async fn pull_messages_by_seq_list(&self, _req: &GetSeqMessageReq) -> crate::error::Result<GetSeqMessageResp> {
                Ok(GetSeqMessageResp {
                    msgs: self.msgs.clone(),
                    notification_msgs: HashMap::new(),
                })
            }
            async fn is_kicked(&self) -> bool {
                false
            }
        }

        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let msgs = HashMap::from([(
            "conv_1".to_string(),
            PullMsgs {
                msgs: vec![MsgData {
                    client_msg_id: "m1".into(),
                    send_id: "user_a".into(),
                    recv_id: "user_b".into(),
                    seq: 2,
                    send_time: 2000,
                    create_time: 2000,
                    content_type: 101,
                    content: r#"{"content":"deleted"}"#.as_bytes().to_vec(),
                    status: msg_status::HAS_DELETED,
                    ..Default::default()
                }],
                is_end: false,
                end_seq: 0,
            },
        )]);
        let checker = MessageChecker::new(Arc::new(DeletedMsgMock { msgs }), message_dao.clone(), conversation_dao.clone(), "test_user".to_string());

        let fetched = checker.fetch_and_merge_missing_messages("conv_1", &[2], false).await.unwrap().unwrap();
        assert_eq!(fetched.len(), 1);
        assert_eq!(fetched[0].status, msg_status::HAS_DELETED, "服务端已删除消息补拉后应保留删除状态");
        assert_eq!(fetched[0].client_msg_id, "m1");

        let from_db = message_dao.get_by_client_msg_id("conv_1", "m1").await.unwrap().unwrap();
        assert_eq!(from_db.status, msg_status::HAS_DELETED, "入库后仍应保留删除状态");
    }

    #[tokio::test]
    async fn test_fetch_missing_skips_locally_deleted_seq() {
        use crate::connection::sync_server::SyncServerApi;
        use crate::db::pool::create_pool_memory;
        use crate::db::{ConversationDao, MessageDao};
        use async_trait::async_trait;
        use openim_protocol::msg::{GetSeqMessageReq, GetSeqMessageResp};
        use openim_protocol::sdkws::{PullMessageBySeqsReq, PullMessageBySeqsResp};
        use std::collections::HashMap;
        use std::sync::atomic::{AtomicUsize, Ordering};

        struct EmptyMock {
            calls: AtomicUsize,
        }

        #[async_trait]
        impl SyncServerApi for EmptyMock {
            async fn fetch_server_max_seqs(&self, _user_id: &str) -> crate::error::Result<HashMap<String, i64>> {
                Ok(HashMap::new())
            }
            async fn pull_messages_by_seqs(&self, _req: &PullMessageBySeqsReq) -> crate::error::Result<PullMessageBySeqsResp> {
                Ok(PullMessageBySeqsResp {
                    msgs: HashMap::new(),
                    notification_msgs: HashMap::new(),
                })
            }
            async fn pull_messages_by_seq_list(&self, _req: &GetSeqMessageReq) -> crate::error::Result<GetSeqMessageResp> {
                self.calls.fetch_add(1, Ordering::SeqCst);
                Ok(GetSeqMessageResp {
                    msgs: HashMap::new(),
                    notification_msgs: HashMap::new(),
                })
            }
            async fn is_kicked(&self) -> bool {
                false
            }
        }

        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        // seq=2 已本地软删
        message_dao.batch_insert(&[make_log("m2", 2, 2000)]).await.unwrap();
        message_dao.mark_as_deleted("conv_1", "m2").await.unwrap();

        let mock = Arc::new(EmptyMock { calls: AtomicUsize::new(0) });
        let checker = MessageChecker::new(mock.clone(), message_dao.clone(), conversation_dao.clone(), "test_user".to_string());

        let fetched = checker.fetch_and_merge_missing_messages("conv_1", &[2], false).await.unwrap();
        assert!(fetched.is_none(), "本地已软删的 seq 不应触发服务端补拉");
        assert_eq!(mock.calls.load(Ordering::SeqCst), 0, "不应发起补拉请求");

        let local = message_dao.get_by_client_msg_id("conv_1", "m2").await.unwrap().unwrap();
        assert_eq!(local.status, msg_status::HAS_DELETED);
    }

    #[test]
    fn test_first_conversation_id_empty() {
        let msgs: Vec<LocalChatLog> = vec![];
        assert_eq!(first_conversation_id(&msgs), "");
    }

    #[test]
    fn test_first_conversation_id_takes_first() {
        let msgs = vec![make_log("a", 1, 1000), make_log("b", 2, 2000)];
        assert_eq!(first_conversation_id(&msgs), "conv_1");
    }
}
