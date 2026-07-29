mod receipt;
mod revoke;

pub use revoke::RevokeTipsWithNickname;
pub(crate) use revoke::parse_revoke_tips_from_json;

use crate::core::message::content_type::ContentTypeUtils;
use crate::domain::constant::types::content_type;
use crate::domain::constant::types::msg_status;
use crate::domain::constant::types::notification_type::{HAS_READ_RECEIPT, REVOKE};
use crate::domain::error::types::Result;
use crate::domain::listener::conversation::ConversationEvent;
use crate::domain::model::msg_struct::TypingElem;
use crate::infra::database::{ConversationDao, GroupDao, MessageDao, UserDao};
use crate::infra::database::models::{LocalChatLog, LocalConversation};
use crate::protocol::sdkws::MsgData;
use std::collections::HashMap;
use std::sync::Arc;
use tracing::{debug, info, warn, trace};
use rand::Rng;

/// MaxSeqRecorder — 内存中记录每个会话的最大 seq，用于判断消息是否为"新消息"
/// 对齐 Go SDK `max_seq_recorder.go` IsNewMsg/Incr/Set/Get
pub struct MaxSeqRecorder {
    seqs: std::sync::RwLock<HashMap<String, i64>>,
}

impl MaxSeqRecorder {
    pub fn new() -> Self {
        Self { seqs: std::sync::RwLock::new(HashMap::new()) }
    }

    /// 判断消息 seq 是否比当前记录更新（对齐 Go SDK IsNewMsg）
    pub fn is_new_msg(&self, conversation_id: &str, seq: i64) -> bool {
        let map = self.seqs.read().unwrap();
        let current = map.get(conversation_id).copied().unwrap_or(0);
        seq > current
    }

    /// 递增指定会话的 seq 记录（对齐 Go SDK Incr）
    pub fn incr(&self, conversation_id: &str, num: i64) {
        let mut map = self.seqs.write().unwrap();
        let entry = map.entry(conversation_id.to_string()).or_insert(0);
        *entry += num;
    }

    /// 直接设置会话的 seq 记录（对齐 Go SDK Set）
    pub fn set(&self, conversation_id: &str, seq: i64) {
        let mut map = self.seqs.write().unwrap();
        map.insert(conversation_id.to_string(), seq);
    }

    /// 获取会话当前记录的 seq（对齐 Go SDK Get）
    pub fn get(&self, conversation_id: &str) -> i64 {
        let map = self.seqs.read().unwrap();
        map.get(conversation_id).copied().unwrap_or(0)
    }
}

/// 消息处理器 — 接收消息的分类入库与事件分发中心
///
/// 对齐 Go SDK `internal/conversation_msg/handler.go`
///
/// # 核心职责
///
/// 1. 接收 `MessageSyncer` 拉取到的消息（或 WebSocket 推送）
/// 2. 按 content_type 分类处理：
///    - 撤回通知 → `revoke.rs`
///    - 已读回执 → `receipt.rs`
///    - Typing 事件 → 直接发布
///    - 普通消息 → 入库 + 更新会话
/// 3. 触发 UI 事件（NewMessage / ConversationChanged / TotalUnreadCountChanged）
///
/// # 子模块
///
/// - [`receipt`] — 已读回执处理（未读数计算 + 事件发布）
/// - [`revoke`] — 撤回通知处理（更新本地消息 + 引用消息处理）
pub struct MessageHandler {
    pub(crate) message_dao: Arc<MessageDao>,
    pub(crate) conversation_dao: Arc<ConversationDao>,
    pub(crate) user_dao: Arc<UserDao>,
    pub(crate) group_dao: Arc<GroupDao>,
    pub(crate) user_id: std::sync::Mutex<String>,
    pub max_seq_recorder: Arc<MaxSeqRecorder>,
    pub(crate) event_tx: Arc<std::sync::Mutex<Option<tokio::sync::mpsc::UnboundedSender<ConversationEvent>>>>,
}

impl MessageHandler {
    pub fn new(
        message_dao: Arc<MessageDao>,
        conversation_dao: Arc<ConversationDao>,
        user_dao: Arc<UserDao>,
        group_dao: Arc<GroupDao>,
    ) -> Self {
        Self {
            message_dao,
            conversation_dao,
            user_dao,
            group_dao,
            user_id: std::sync::Mutex::new(String::new()),
            max_seq_recorder: Arc::new(MaxSeqRecorder::new()),
            event_tx: Arc::new(std::sync::Mutex::new(None)),
        }
    }

    pub fn set_event_sender(&self, tx: tokio::sync::mpsc::UnboundedSender<ConversationEvent>) {
        *self.event_tx.lock().unwrap() = Some(tx);
    }

    pub(crate) fn send(&self, e: ConversationEvent) {
        let has_tx = self.event_tx.lock().unwrap().is_some();
        tracing::info!("[Event] {:?}, has_subscriber={}", &e, has_tx);
        if let Some(tx) = &*self.event_tx.lock().unwrap() { let _ = tx.send(e); }
    }

    pub fn set_user_id(&self, user_id: String) {
        *self.user_id.lock().unwrap() = user_id;
    }

    pub fn message_dao(&self) -> Arc<MessageDao> {
        self.message_dao.clone()
    }

    /// 处理异常消息（对齐 Go SDK `handleExceptionMessages`）
    ///
    /// 4 种异常类型：
    /// - SEQ_GAP: 服务端占位符（Status=DELETED, ClientMsgID=""）
    /// - DELETED: 服务端标记删除（Status=DELETED, ClientMsgID!=""）
    /// - SEQ_DUP: Seq 重复（已存在消息的 Seq == 新消息 Seq）
    /// - CLIENT_DUP: ClientMsgID 重复但 Seq 不同
    fn handle_exception_messages(
        &self,
        existing_message: Option<&LocalChatLog>,
        message: &mut LocalChatLog,
    ) {
        let (prefix, seq, client_msg_id) = match existing_message {
            None if message.status == msg_status::HAS_DELETED as i32
                && message.client_msg_id.is_empty() =>
            {
                ("[SEQ_GAP_+]".to_string(), message.seq, message.client_msg_id.clone())
            }
            None if message.status == msg_status::HAS_DELETED as i32 => {
                ("[DELETED]".to_string(), message.seq, message.client_msg_id.clone())
            }
            Some(existing) if existing.seq == message.seq => {
                ("[SEQ_DUP]".to_string(), message.seq, existing.client_msg_id.clone())
            }
            Some(existing) if existing.seq != message.seq => {
                ("[CLIENT_DUP]".to_string(), message.seq, existing.client_msg_id.clone())
            }
            _ => return,
        };

        let random_suffix = Self::generate_random_id(8);
        let new_client_msg_id = if client_msg_id.is_empty() {
            format!("{}_{}", prefix, random_suffix)
        } else {
            format!("{}{}_{}", prefix, client_msg_id, random_suffix)
        };

        warn!(
            "[MsgHandler] {} seq={}, oldClientMsgID={}, newClientMsgID={}",
            prefix, seq, message.client_msg_id, new_client_msg_id
        );

        message.status = msg_status::HAS_DELETED as i32;
        message.client_msg_id = new_client_msg_id;
    }

    /// 生成随机字符串（用于异常消息 ID 后缀）
    fn generate_random_id(len: usize) -> String {
        let mut rng = rand::thread_rng();
        (0..len)
            .map(|_| {
                let idx = rng.gen_range(0..36);
                if idx < 10 {
                    (b'0' + idx) as char
                } else {
                    (b'a' + idx - 10) as char
                }
            })
            .collect()
    }

    /// 将 MsgData 转为 LocalChatLog
    fn msg_data_to_local(&self, conv_id: &str, msg: &MsgData) -> LocalChatLog {
        LocalChatLog {
            conversation_id: conv_id.to_string(),
            client_msg_id: msg.client_msg_id.clone(),
            server_msg_id: msg.server_msg_id.clone(),
            send_id: msg.send_id.clone(),
            recv_id: msg.recv_id.clone(),
            sender_platform_id: msg.sender_platform_id,
            sender_nick_name: msg.sender_nickname.clone(),
            sender_face_url: msg.sender_face_url.clone(),
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: String::from_utf8_lossy(&msg.content).to_string(),
            is_read: 0,
            status: msg_status::SEND_SUCCESS as i32,
            seq: msg.seq,
            send_time: msg.send_time,
            create_time: msg.create_time,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: msg.group_id.clone(),
        }
    }

    /// 处理消息列表，返回 true 表示有非 typing 的状态变更
    #[tracing::instrument(skip_all, fields(msg_count = %messages.len()))]
    pub async fn handle_messages(&self, conv_id: &str, messages: Vec<MsgData>) -> Result<bool> {
        self.handle_messages_internal(conv_id, messages, false).await
    }

    /// 处理消息列表（标记为同步来源），返回 true 表示有非 typing 的状态变更
    #[tracing::instrument(skip_all, fields(msg_count = %messages.len()))]
    pub async fn handle_sync_messages(&self, conv_id: &str, messages: Vec<MsgData>) -> Result<bool> {
        self.handle_messages_internal(conv_id, messages, true).await
    }

    /// 返回 true 表示处理了非 typing 的状态变更消息
    async fn handle_messages_internal(&self, conv_id: &str, messages: Vec<MsgData>, is_from_sync: bool) -> Result<bool> {
        if messages.is_empty() {
            return Ok(false);
        }
        // 已读回执处理（对齐 Go SDK read_drawing.go L227-284）
        for msg in &messages {
            if msg.content_type == HAS_READ_RECEIPT {
                if let Err(e) = self.handle_read_receipt(msg).await {
                    warn!("处理已读回执失败: {}", e);
                }
                continue;
            }
        }

        // 撤回通知处理（对齐 Go SDK do_revoke_msg）
        for msg in &messages {
            if msg.content_type == REVOKE {
                let content_str = String::from_utf8_lossy(&msg.content);
                match parse_revoke_tips_from_json(&content_str) {
                    Ok(tips) => {
                        if let Err(e) = self.handle_revoke_notification(&tips.tips, &tips.revoker_nickname, tips.revoker_role).await {
                            warn!("处理撤回通知失败: {}", e);
                        }
                    }
                    Err(e) => {
                        warn!("解析 RevokeMsgTips 失败: {}", e);
                    }
                }
                continue;
            }
        }

        // 过滤掉已读回执和撤回通知，只处理普通消息
        let normal_messages: Vec<MsgData> = messages.into_iter()
            .filter(|m| m.content_type != HAS_READ_RECEIPT && m.content_type != REVOKE)
            .collect();

        if normal_messages.is_empty() {
            return Ok(false);
        }

        // 处理 Typing 消息：发布输入状态变化事件
        let login_user_id = self.user_id.lock().unwrap().clone();
        for msg in &normal_messages {
            if msg.content_type == content_type::TYPING {
                if msg.send_id == login_user_id {
                    trace!("[Typing] 忽略自身 typing 推送: conv={}", conv_id);
                    continue;
                }
                let content_str = String::from_utf8_lossy(&msg.content);
                if let Ok(typing_elem) = serde_json::from_str::<TypingElem>(&content_str) {
                    let platform_id = msg.sender_platform_id;
                    let is_typing = typing_elem.msg_tips == "yes";
                    let pids: Vec<i32> = if is_typing { vec![platform_id] } else { vec![] };
                    self.send(ConversationEvent::UserInputStatusChanged { conversation_id: conv_id.to_string(), user_id: msg.send_id.clone(), platform_ids: pids });
                }
            }
        }

        // typing 消息已处理完事件，从 normal_messages 中移除
        let normal_messages: Vec<MsgData> = normal_messages.into_iter()
            .filter(|m| m.content_type != content_type::TYPING)
            .collect();

        if normal_messages.is_empty() {
            return Ok(false);
        }

        let has_state_changes = !normal_messages.is_empty();

        let client_msg_ids: Vec<String> = normal_messages.iter().map(|m| m.client_msg_id.clone()).collect();

        // 批量查库去重
        let existing_logs = self.message_dao.get_by_client_msg_ids(&client_msg_ids).await.unwrap_or_default();
        let mut existing_map: HashMap<String, LocalChatLog> = HashMap::new();
        for log in existing_logs {
            existing_map.insert(log.client_msg_id.clone(), log);
        }

        let login_user_id = self.user_id.lock().unwrap().clone();
        debug!("[MsgHandler] 收到 {} 条消息", normal_messages.len());
        for msg in &normal_messages {
            trace!("[MsgHandler]   conv={}, send_id={}, seq={}, self={}, type={}({})",
                conv_id, msg.send_id, msg.seq,
                msg.send_id == login_user_id,
                ContentTypeUtils::display_name(msg.content_type), msg.content_type);
        }
        let mut insert_list: Vec<LocalChatLog> = Vec::new();
        let mut batch_update_list: Vec<(String, i64)> = Vec::new();
        let mut to_notify: Vec<MsgData> = Vec::new();
        let mut processed_ids: std::collections::HashSet<String> = std::collections::HashSet::new();
        let mut is_trigger_unread_count = false;

        for msg in &normal_messages {
            if processed_ids.contains(&msg.client_msg_id) {
                let mut local_msg: LocalChatLog = self.msg_data_to_local(conv_id, msg);
                self.handle_exception_messages(None, &mut local_msg);
                insert_list.push(local_msg);
                continue;
            }
            processed_ids.insert(msg.client_msg_id.clone());

            let exists = existing_map.get(&msg.client_msg_id);
            let is_self = msg.send_id == login_user_id;
            let is_store = ContentTypeUtils::should_store(msg.content_type);

            if is_self {
                if let Some(existing) = exists {
                    if existing.seq == 0 && msg.seq > 0 {
                        if is_store {
                            batch_update_list.push((existing.client_msg_id.clone(), msg.seq));
                        }
                    }
                } else {
                    if is_store {
                        let mut local_msg: LocalChatLog = self.msg_data_to_local(conv_id, msg);
                        local_msg.status = msg_status::SEND_SUCCESS as i32;
                        insert_list.push(local_msg);
                    }
                }
            } else {
                let is_online_only = msg.options.get("isOnlineOnly").copied().unwrap_or(false);
                if exists.is_none() {
                    if is_online_only || !is_store {
                        to_notify.push(msg.clone());
                    } else {
                        let mut local_msg: LocalChatLog = self.msg_data_to_local(conv_id, msg);
                        local_msg.status = msg_status::SEND_SUCCESS as i32;
                        let msg_seq = local_msg.seq;
                        insert_list.push(local_msg);
                        to_notify.push(msg.clone());
                        if self.max_seq_recorder.is_new_msg(conv_id, msg_seq) {
                            is_trigger_unread_count = true;
                            self.max_seq_recorder.incr(conv_id, 1);
                        }
                    }
                } else {
                    debug!("[MsgHandler] 跳过重复消息: client_msg_id={}, seq={}", msg.client_msg_id, msg.seq);
                }
            }
        }

        // 批量更新 seq
        if !batch_update_list.is_empty() {
            debug!("[MsgHandler] 更新 seq: {} 条", batch_update_list.len());
            self.message_dao.batch_update_seq(&batch_update_list).await?;
        }

        // 批量插入消息
        if !insert_list.is_empty() {
            for log in &insert_list {
                trace!("[MsgHandler]   插入: conv={}, client_msg_id={}, seq={}",
                      log.conversation_id, log.client_msg_id, log.seq);
            }
            self.message_dao.batch_insert(&insert_list).await?;
        }

        let mut seen_convs = std::collections::HashSet::new();
        let to_notify_cloned = to_notify.clone();
        for msg in &to_notify_cloned {
            let is_conversation_update = ContentTypeUtils::should_update_conversation(msg.content_type);
            let is_self = msg.send_id == login_user_id;
            let is_online_only = msg.options.get("isOnlineOnly").copied().unwrap_or(false);
            let content_str = String::from_utf8_lossy(&msg.content);

            if seen_convs.insert(conv_id.to_string()) {
                let existing = self.conversation_dao.get_by_id(conv_id).await?;
                if existing.is_none() {
                    let show_name = if msg.session_type == 1 {
                        msg.sender_nickname.clone()
                    } else {
                        format!("Group_{}", msg.group_id)
                    };

                    let conv = LocalConversation {
                        conversation_id: conv_id.to_string(),
                        conversation_type: msg.session_type,
                        user_id: if msg.session_type == 1 { msg.recv_id.clone() } else { msg.send_id.clone() },
                        group_id: if msg.session_type != 1 { msg.group_id.clone() } else { String::new() },
                        show_name,
                        face_url: msg.sender_face_url.clone(),
                        latest_msg: if is_conversation_update { content_str.to_string() } else { String::new() },
                        latest_msg_send_time: if is_conversation_update { msg.send_time } else { 0 },
                        unread_count: 0,
                        recv_msg_opt: 0,
                        is_pinned: 0,
                        is_private_chat: 0,
                        burn_duration: 0,
                        group_at_type: 0,
                        is_not_in_group: 0,
                        update_unread_count_time: 0,
                        attached_info: String::new(),
                        ex: String::new(),
                        draft_text: String::new(),
                        draft_text_time: 0,
                        max_seq: msg.seq,
                        min_seq: 0,
                        is_msg_destruct: 0,
                        msg_destruct_time: 0,
                    };
                    self.conversation_dao.upsert(&conv).await?;
                    debug!("[MsgHandler] 创建新会话: {}", conv_id);
                }
            }

            if is_conversation_update && !is_online_only {
                self.conversation_dao
                    .update_latest_msg(conv_id, &content_str, msg.send_time)
                    .await?;
                
                if !is_self {
                    self.conversation_dao
                        .increase_unread_count(conv_id, msg.seq)
                        .await?;
                }
            }
        }

        // 汇总日志
        let skipped = normal_messages.len() - insert_list.len() - batch_update_list.len();
        info!("[MsgHandler] 完成: total={}, inserted={}, seq_updated={}, skipped={}, notify={}",
            normal_messages.len(), insert_list.len(), batch_update_list.len(),
            skipped, to_notify.len());

        // 离线新消息通知
        let offline_msgs: Vec<MsgData> = if is_from_sync && !to_notify.is_empty() {
            to_notify.into_iter()
                .filter(|m| m.send_id != login_user_id && m.content_type != content_type::TYPING)
                .collect()
        } else {
            Vec::new()
        };
        if !offline_msgs.is_empty() {
        }

        // 对齐 Go SDK：所有消息处理完成后统一发布会话变更
        for conv_id in &seen_convs {
            if let Ok(Some(conv)) = self.conversation_dao.get_by_id(&conv_id).await {
                let conversation = crate::domain::model::conversation::Conversation {
                    conversation_id: conv.conversation_id,
                    conversation_type: conv.conversation_type,
                    user_id: conv.user_id,
                    group_id: conv.group_id,
                    show_name: conv.show_name,
                    face_url: conv.face_url,
                    latest_msg: conv.latest_msg,
                    latest_msg_send_time: conv.latest_msg_send_time,
                    unread_count: conv.unread_count,
                    recv_msg_opt: conv.recv_msg_opt,
                    is_pinned: conv.is_pinned != 0,
                    is_not_in_group: conv.is_not_in_group != 0,
                    draft_text: conv.draft_text,
                    draft_text_time: conv.draft_text_time,
                    is_private_chat: conv.is_private_chat != 0,
                    burn_duration: conv.burn_duration as i32,
                    group_at_type: conv.group_at_type,
                    update_unread_count_time: conv.update_unread_count_time,
                    latest_msg_seq: conv.max_seq,
                    max_seq: conv.max_seq,
                    min_seq: conv.min_seq,
                    is_msg_destruct: conv.is_msg_destruct != 0,
                    msg_destruct_time: conv.msg_destruct_time,
                    update_flag: 0,
                    sync_action: None,
                    is_private: conv.is_private_chat != 0,
                    ex: conv.ex,
                };
                self.send(ConversationEvent::Changed(vec![conversation.clone()]));
            }
        }

        Ok(has_state_changes)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::event::bus::EventBus;
    use crate::infra::database::pool::create_pool_memory;
    use crate::infra::database::{UserDao, GroupDao};

    // ========================================================================
    // MaxSeqRecorder 纯逻辑测试
    // ========================================================================

    #[test]
    fn test_max_seq_recorder_new_returns_zero() {
        let recorder = MaxSeqRecorder::new();
        assert_eq!(recorder.get("conv_1"), 0);
        assert_eq!(recorder.get("nonexistent"), 0);
    }

    #[test]
    fn test_max_seq_recorder_is_new_msg() {
        let recorder = MaxSeqRecorder::new();
        assert!(recorder.is_new_msg("conv_1", 1));
        assert!(recorder.is_new_msg("conv_1", 100));
        assert!(!recorder.is_new_msg("conv_1", 0));
        assert!(!recorder.is_new_msg("conv_1", -1));
    }

    #[test]
    fn test_max_seq_recorder_set_and_get() {
        let recorder = MaxSeqRecorder::new();
        recorder.set("conv_1", 10);
        assert_eq!(recorder.get("conv_1"), 10);
        assert_eq!(recorder.get("conv_2"), 0);
        recorder.set("conv_1", 20);
        assert_eq!(recorder.get("conv_1"), 20);
    }

    #[test]
    fn test_max_seq_recorder_incr() {
        let recorder = MaxSeqRecorder::new();
        recorder.incr("conv_1", 1);
        assert_eq!(recorder.get("conv_1"), 1);
        recorder.incr("conv_1", 5);
        assert_eq!(recorder.get("conv_1"), 6);
        recorder.incr("conv_1", -2);
        assert_eq!(recorder.get("conv_1"), 4);
    }

    #[test]
    fn test_max_seq_recorder_is_new_msg_after_set() {
        let recorder = MaxSeqRecorder::new();
        recorder.set("conv_1", 10);
        assert!(!recorder.is_new_msg("conv_1", 10));
        assert!(!recorder.is_new_msg("conv_1", 5));
        assert!(recorder.is_new_msg("conv_1", 11));
    }

    #[test]
    fn test_max_seq_recorder_multiple_conversations() {
        let recorder = MaxSeqRecorder::new();
        recorder.set("conv_a", 100);
        recorder.set("conv_b", 200);
        recorder.incr("conv_a", 3);
        assert_eq!(recorder.get("conv_a"), 103);
        assert_eq!(recorder.get("conv_b"), 200);
        assert!(recorder.is_new_msg("conv_a", 104));
        assert!(!recorder.is_new_msg("conv_b", 200));
        assert!(recorder.is_new_msg("conv_b", 201));
    }

    // ========================================================================
    // generate_random_id 测试
    // ========================================================================

    #[test]
    fn test_generate_random_id_length() {
        assert_eq!(MessageHandler::generate_random_id(8).len(), 8);
        assert_eq!(MessageHandler::generate_random_id(1).len(), 1);
        assert_eq!(MessageHandler::generate_random_id(32).len(), 32);
        assert_eq!(MessageHandler::generate_random_id(0).len(), 0);
    }

    #[test]
    fn test_generate_random_id_charset() {
        let id = MessageHandler::generate_random_id(100);
        for c in id.chars() {
            assert!(
                c.is_ascii_digit() || (c.is_ascii_lowercase() && c <= 'z'),
                "unexpected char: {}",
                c
            );
        }
    }

    #[test]
    fn test_generate_random_id_uniqueness() {
        let ids: Vec<String> = (0..100).map(|_| MessageHandler::generate_random_id(16)).collect();
        let unique: std::collections::HashSet<&String> = ids.iter().collect();
        assert_eq!(unique.len(), 100);
    }

    // ========================================================================
    // handle_exception_messages 测试
    // ========================================================================

    fn make_local_log(id: &str, seq: i64, status: i32) -> LocalChatLog {
        LocalChatLog {
            conversation_id: "conv_1".into(),
            client_msg_id: id.to_string(),
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
            status,
            seq,
            send_time: 1000,
            create_time: 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        }
    }

    #[test]
    fn test_exception_seq_gap() {
        let pool_rt = tokio::runtime::Runtime::new().unwrap();
        let pool = pool_rt.block_on(create_pool_memory()).unwrap();
        let handler = MessageHandler::new(
            Arc::new(MessageDao::new(pool.clone())),
            Arc::new(ConversationDao::new(pool.clone())),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );

        let mut msg = make_local_log("", 5, msg_status::HAS_DELETED);
        handler.handle_exception_messages(None, &mut msg);
        assert!(msg.client_msg_id.starts_with("[SEQ_GAP_+]"));
        assert_eq!(msg.status, msg_status::HAS_DELETED);
    }

    #[test]
    fn test_exception_deleted() {
        let pool_rt = tokio::runtime::Runtime::new().unwrap();
        let pool = pool_rt.block_on(create_pool_memory()).unwrap();
        let handler = MessageHandler::new(
            Arc::new(MessageDao::new(pool.clone())),
            Arc::new(ConversationDao::new(pool.clone())),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );

        let mut msg = make_local_log("msg_123", 5, msg_status::HAS_DELETED);
        handler.handle_exception_messages(None, &mut msg);
        assert!(msg.client_msg_id.starts_with("[DELETED]msg_123_"));
        assert_eq!(msg.status, msg_status::HAS_DELETED);
    }

    #[test]
    fn test_exception_seq_dup() {
        let pool_rt = tokio::runtime::Runtime::new().unwrap();
        let pool = pool_rt.block_on(create_pool_memory()).unwrap();
        let handler = MessageHandler::new(
            Arc::new(MessageDao::new(pool.clone())),
            Arc::new(ConversationDao::new(pool.clone())),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );

        let existing = make_local_log("existing_msg", 10, msg_status::SEND_SUCCESS);
        let mut msg = make_local_log("new_msg", 10, msg_status::SEND_SUCCESS);
        handler.handle_exception_messages(Some(&existing), &mut msg);
        assert!(msg.client_msg_id.starts_with("[SEQ_DUP]existing_msg_"));
        assert_eq!(msg.status, msg_status::HAS_DELETED);
    }

    #[test]
    fn test_exception_client_dup() {
        let pool_rt = tokio::runtime::Runtime::new().unwrap();
        let pool = pool_rt.block_on(create_pool_memory()).unwrap();
        let handler = MessageHandler::new(
            Arc::new(MessageDao::new(pool.clone())),
            Arc::new(ConversationDao::new(pool.clone())),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );

        let existing = make_local_log("msg_dup", 5, msg_status::SEND_SUCCESS);
        let mut msg = make_local_log("msg_dup", 8, msg_status::SEND_SUCCESS);
        handler.handle_exception_messages(Some(&existing), &mut msg);
        assert!(msg.client_msg_id.starts_with("[CLIENT_DUP]msg_dup_"));
        assert_eq!(msg.status, msg_status::HAS_DELETED);
    }

    #[test]
    fn test_exception_no_match_does_nothing() {
        let pool_rt = tokio::runtime::Runtime::new().unwrap();
        let pool = pool_rt.block_on(create_pool_memory()).unwrap();
        let handler = MessageHandler::new(
            Arc::new(MessageDao::new(pool.clone())),
            Arc::new(ConversationDao::new(pool.clone())),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );

        let mut msg = make_local_log("msg_ok", 5, msg_status::SEND_SUCCESS);
        let original_id = msg.client_msg_id.clone();
        handler.handle_exception_messages(None, &mut msg);
        assert_eq!(msg.client_msg_id, original_id, "should not modify client_msg_id");
        assert_eq!(msg.status, msg_status::SEND_SUCCESS, "should not modify status");
    }

    // ========================================================================
    // 集成测试（使用内存 DB）
    // ========================================================================

    fn make_msg(id: &str, _conv_id: &str, seq: i64) -> MsgData {
        MsgData {
            server_msg_id: format!("srv_{}", id),
            client_msg_id: id.to_string(),
            send_id: "user_1".into(),
            recv_id: "user_2".into(),
            sender_platform_id: 1,
            sender_nickname: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: format!("{{\"text\":\"hello {}\"}}", id).into_bytes(),
            seq,
            send_time: seq * 1000,
            create_time: seq * 1000,
            ..Default::default()
        }
    }

    fn msg_with_ct(id: &str, conv_id: &str, seq: i64, ct: i32) -> MsgData {
        let mut m = make_msg(id, conv_id, seq);
        m.content_type = ct;
        m
    }

    fn make_conv(id: &str) -> LocalConversation {
        LocalConversation {
            conversation_id: id.to_string(),
            conversation_type: 1,
            user_id: String::new(),
            group_id: String::new(),
            show_name: String::new(),
            face_url: String::new(),
            latest_msg: String::new(),
            latest_msg_send_time: 0,
            unread_count: 0,
            recv_msg_opt: 0,
            is_pinned: 0,
            is_private_chat: 0,
            burn_duration: 0,
            group_at_type: 0,
            is_not_in_group: 0,
            update_unread_count_time: 0,
            attached_info: String::new(),
            ex: String::new(),
            draft_text: String::new(),
            draft_text_time: 0,
            max_seq: 0,
            min_seq: 0,
            is_msg_destruct: 0,
            msg_destruct_time: 0,
        }
    }

    #[tokio::test]
    async fn test_handle_messages() {
        let pool = create_pool_memory().await.unwrap();
        let handler = MessageHandler::new(
            Arc::new(MessageDao::new(pool.clone())),
            Arc::new(ConversationDao::new(pool.clone())),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );

        let msgs = vec![
            make_msg("msg_1", "conv_1", 1),
            make_msg("msg_2", "conv_1", 2),
        ];
        handler.handle_messages("conv_1", msgs).await.unwrap();
    }

    #[tokio::test]
    async fn test_dedup_via_insert_ignore() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let handler = MessageHandler::new(
            message_dao.clone(),
            Arc::new(ConversationDao::new(pool.clone())),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool.clone())),
        );

        let msgs = vec![make_msg("msg_1", "conv_1", 1)];
        handler.handle_messages("conv_1", msgs.clone()).await.unwrap();
        handler.handle_messages("conv_1", msgs).await.unwrap();

        let chat_logs = MessageDao::new(pool)
            .get_by_conversation("conv_1", 0, 100)
            .await
            .unwrap();
        assert_eq!(chat_logs.len(), 1);
    }

    #[tokio::test]
    async fn test_tip_message_not_stored() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let handler = MessageHandler::new(
            message_dao.clone(),
            conversation_dao.clone(),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );

        let mut conv = make_conv("conv_tip");
        conv.unread_count = 5;
        conv.latest_msg = "earlier message".into();
        conv.latest_msg_send_time = 1000;
        conv.max_seq = 5;
        conversation_dao.upsert(&conv).await.unwrap();

        let msgs = vec![msg_with_ct("tip_1", "conv_tip", 6, crate::domain::constant::types::notification_type::FRIEND_APPLICATION)];
        handler.handle_messages("conv_tip", msgs).await.unwrap();
        let chat_logs = message_dao.get_by_conversation("conv_tip", 0, 100).await.unwrap();
        assert_eq!(chat_logs.len(), 0, "tip message should not be stored");

        let conv = conversation_dao.get_by_id("conv_tip").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 5, "unread_count should not increment for tip");
        assert_eq!(conv.latest_msg, "earlier message", "latest_msg should not change for tip");
    }

    #[tokio::test]
    async fn test_typing_message_not_stored_and_no_event() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let event_bus = Arc::new(EventBus::new());
        let mut sub = event_bus.subscribe();
        let handler = MessageHandler::new(
            message_dao.clone(),
            conversation_dao.clone(),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );

        let msgs = vec![msg_with_ct("typing_1", "conv_typing", 1, content_type::TYPING)];
        handler.handle_messages("conv_typing", msgs).await.unwrap();
        let chat_logs = message_dao.get_by_conversation("conv_typing", 0, 100).await.unwrap();
        assert_eq!(chat_logs.len(), 0, "typing message should not be stored");

        let event = sub.try_next();
        assert!(event.is_none(), "typing message should not publish NewMessage event");
    }

    #[tokio::test]
    async fn test_normal_message_increments_unread() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let handler = MessageHandler::new(
            message_dao.clone(),
            conversation_dao.clone(),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );

        let msgs1 = vec![msg_with_ct("msg_1", "conv_normal", 1, content_type::TEXT)];
        handler.handle_messages("conv_normal", msgs1).await.unwrap();

        let chat_logs = message_dao.get_by_conversation("conv_normal", 0, 100).await.unwrap();
        assert_eq!(chat_logs.len(), 1);

        let conv = conversation_dao.get_by_id("conv_normal").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 1);
        assert!(!conv.latest_msg.is_empty());

        let msgs2 = vec![msg_with_ct("msg_2", "conv_normal", 2, content_type::TEXT)];
        handler.handle_messages("conv_normal", msgs2).await.unwrap();

        let conv = conversation_dao.get_by_id("conv_normal").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 2);
    }

    #[tokio::test]
    async fn test_latest_msg_updated_correctly() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let handler = MessageHandler::new(
            message_dao.clone(),
            conversation_dao.clone(),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );

        let msg1_content = r#"{"text":"hello"}"#;
        let msgs1 = vec![{
            let mut m = msg_with_ct("msg_1", "conv_latest", 1, content_type::TEXT);
            m.content = msg1_content.as_bytes().to_vec();
            m.send_time = 1000;
            m
        }];
        handler.handle_messages("conv_latest", msgs1).await.unwrap();

        let conv = conversation_dao.get_by_id("conv_latest").await.unwrap().unwrap();
        assert_eq!(conv.latest_msg, msg1_content);
        assert_eq!(conv.latest_msg_send_time, 1000);
        assert_eq!(conv.unread_count, 1);

        let msg2_content = r#"{"text":"world"}"#;
        let msgs2 = vec![{
            let mut m = msg_with_ct("msg_2", "conv_latest", 2, content_type::TEXT);
            m.content = msg2_content.as_bytes().to_vec();
            m.send_time = 2000;
            m
        }];
        handler.handle_messages("conv_latest", msgs2).await.unwrap();

        let conv = conversation_dao.get_by_id("conv_latest").await.unwrap().unwrap();
        assert_eq!(conv.latest_msg, msg2_content);
        assert_eq!(conv.latest_msg_send_time, 2000);
        assert_eq!(conv.unread_count, 2);
    }

    #[tokio::test]
    async fn test_latest_msg_updated_for_other_user_message() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let handler = MessageHandler::new(
            message_dao.clone(),
            conversation_dao.clone(),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );
        handler.set_user_id("self_user".to_string());

        let msg_content = r#"{"text":"message from other"}"#;
        let msgs = vec![{
            let mut m = msg_with_ct("msg_1", "conv_other", 1, content_type::TEXT);
            m.content = msg_content.as_bytes().to_vec();
            m.send_time = 1000;
            m.send_id = "other_user".to_string();
            m
        }];
        handler.handle_messages("conv_other", msgs).await.unwrap();

        let conv = conversation_dao.get_by_id("conv_other").await.unwrap().unwrap();
        assert_eq!(conv.latest_msg, msg_content);
        assert_eq!(conv.latest_msg_send_time, 1000);
        assert_eq!(conv.unread_count, 1);
    }

    #[tokio::test]
    async fn test_no_trigger_conv_stored_but_no_conv_update() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let handler = MessageHandler::new(
            message_dao.clone(),
            conversation_dao.clone(),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );

        // 使用 mpsc channel 验证事件（handler 通过 event_tx 发布事件）
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        handler.set_event_sender(tx);

        let mut conv = make_conv("conv_notrigger");
        conv.unread_count = 3;
        conv.latest_msg = "original msg".into();
        conv.latest_msg_send_time = 1000;
        conv.max_seq = 3;
        conversation_dao.upsert(&conv).await.unwrap();

        let msgs = vec![msg_with_ct(
            "notrigger_1",
            "conv_notrigger",
            4,
            content_type::CUSTOM_MSG_NOT_TRIGGER_CONVERSATION,
        )];
        handler.handle_messages("conv_notrigger", msgs).await.unwrap();

        let chat_logs = message_dao.get_by_conversation("conv_notrigger", 0, 100).await.unwrap();
        assert_eq!(chat_logs.len(), 1, "NoTriggerConv message should still be stored");
        assert_eq!(
            chat_logs[0].content_type,
            content_type::CUSTOM_MSG_NOT_TRIGGER_CONVERSATION
        );

        let conv = conversation_dao.get_by_id("conv_notrigger").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 3, "unread_count should not increment for NoTriggerConv");
        assert_eq!(conv.latest_msg, "original msg", "latest_msg should not change for NoTriggerConv");

        // handler 通过 event_tx 发布 ConversationEvent::Changed
        let event = rx.try_recv();
        assert!(event.is_ok(), "NoTriggerConv message should still publish ConversationEvent::Changed");
    }

    // ========================================================================
    // 补充覆盖测试
    // ========================================================================

    #[tokio::test]
    async fn test_self_message_seq_backfill() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let handler = MessageHandler::new(
            message_dao.clone(),
            Arc::new(ConversationDao::new(pool.clone())),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );
        handler.set_user_id("user_1".to_string());

        // 预插入一条 seq=0 的消息（模拟发送后尚未同步）
        let local_msg = LocalChatLog {
            conversation_id: "conv_seq".to_string(),
            client_msg_id: "msg_backfill".to_string(),
            server_msg_id: String::new(),
            send_id: "user_1".to_string(),
            recv_id: "user_2".to_string(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: "{\"text\":\"hello\"}".to_string(),
            is_read: 0,
            status: msg_status::SEND_SUCCESS as i32,
            seq: 0,
            send_time: 1000,
            create_time: 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        };
        message_dao.batch_insert(&[local_msg]).await.unwrap();

        // 收到服务端推送，同一 client_msg_id 但 seq=5
        let msgs = vec![{
            let mut m = make_msg("msg_backfill", "conv_seq", 5);
            m.send_id = "user_1".into(); // 自己发的
            m
        }];
        handler.handle_messages("conv_seq", msgs).await.unwrap();

        // 验证 seq 已回填
        let logs = message_dao.get_by_conversation("conv_seq", 0, 100).await.unwrap();
        assert_eq!(logs.len(), 1);
        assert_eq!(logs[0].seq, 5, "seq should be backfilled from 0 to 5");
    }

    #[tokio::test]
    async fn test_duplicate_in_batch_second_dropped_by_db() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let handler = MessageHandler::new(
            message_dao.clone(),
            Arc::new(ConversationDao::new(pool.clone())),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );
        handler.set_user_id("other_user".to_string());

        // 同一批次中两条消息具有相同 client_msg_id
        let msgs = vec![
            make_msg("dup_msg", "conv_dup", 1),
            make_msg("dup_msg", "conv_dup", 2), // 重复 client_msg_id
        ];
        handler.handle_messages("conv_dup", msgs).await.unwrap();

        // DB INSERT IGNORE 去重，只保留第一条
        let logs = message_dao.get_by_conversation("conv_dup", 0, 100).await.unwrap();
        assert_eq!(logs.len(), 1, "duplicate client_msg_id should be deduplicated by DB");
        assert_eq!(logs[0].seq, 1, "first message should be kept");
    }

    #[tokio::test]
    async fn test_online_only_message_not_stored() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let handler = MessageHandler::new(
            message_dao.clone(),
            Arc::new(ConversationDao::new(pool.clone())),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );
        handler.set_user_id("self_user".to_string());

        let msgs = vec![{
            let mut m = msg_with_ct("online_1", "conv_online", 1, content_type::TEXT);
            m.send_id = "other_user".into();
            m.options = std::collections::HashMap::from([("isOnlineOnly".to_string(), true)]);
            m
        }];
        handler.handle_messages("conv_online", msgs).await.unwrap();

        let logs = message_dao.get_by_conversation("conv_online", 0, 100).await.unwrap();
        assert_eq!(logs.len(), 0, "online_only message should NOT be stored");
    }

    #[tokio::test]
    async fn test_typing_event_publishes_user_input_status() {
        let pool = create_pool_memory().await.unwrap();
        let handler = MessageHandler::new(
            Arc::new(MessageDao::new(pool.clone())),
            Arc::new(ConversationDao::new(pool.clone())),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );
        handler.set_user_id("self_user".to_string());

        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        handler.set_event_sender(tx);

        let msgs = vec![{
            let mut m = msg_with_ct("typing_1", "conv_typing_ev", 1, content_type::TYPING);
            m.send_id = "other_user".into();
            m.sender_platform_id = 2;
            m.content = r#"{"msgTips":"yes"}"#.as_bytes().to_vec();
            m
        }];
        handler.handle_messages("conv_typing_ev", msgs).await.unwrap();

        let event = rx.try_recv();
        assert!(event.is_ok(), "should publish UserInputStatusChanged");
        match event.unwrap() {
            ConversationEvent::UserInputStatusChanged { conversation_id, user_id, platform_ids } => {
                assert_eq!(conversation_id, "conv_typing_ev");
                assert_eq!(user_id, "other_user");
                assert_eq!(platform_ids, vec![2]);
            }
            other => panic!("expected UserInputStatusChanged, got {:?}", other),
        }
    }

    #[tokio::test]
    async fn test_self_typing_ignored() {
        let pool = create_pool_memory().await.unwrap();
        let handler = MessageHandler::new(
            Arc::new(MessageDao::new(pool.clone())),
            Arc::new(ConversationDao::new(pool.clone())),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );
        handler.set_user_id("self_user".to_string());

        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        handler.set_event_sender(tx);

        let msgs = vec![{
            let mut m = msg_with_ct("typing_self", "conv_typing_self", 1, content_type::TYPING);
            m.send_id = "self_user".into(); // 自己发的 typing
            m.content = r#"{"msgTips":"yes"}"#.as_bytes().to_vec();
            m
        }];
        let result = handler.handle_messages("conv_typing_self", msgs).await.unwrap();

        assert!(!result, "self typing should return false (no state changes)");
        let event = rx.try_recv();
        assert!(event.is_err(), "self typing should NOT publish any event");
    }

    #[tokio::test]
    async fn test_group_chat_message_creates_group_conversation() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let handler = MessageHandler::new(
            message_dao.clone(),
            conversation_dao.clone(),
            Arc::new(UserDao::new(pool.clone())),
            Arc::new(GroupDao::new(pool)),
        );
        handler.set_user_id("self_user".to_string());

        let msgs = vec![{
            let mut m = msg_with_ct("grp_msg_1", "sg_group_1", 1, content_type::TEXT);
            m.send_id = "other_user".into();
            m.session_type = 3; // WRITE_GROUP_CHAT
            m.group_id = "group_1".into();
            m.sender_nickname = "Alice".into();
            m
        }];
        handler.handle_messages("sg_group_1", msgs).await.unwrap();

        // 验证消息入库
        let logs = message_dao.get_by_conversation("sg_group_1", 0, 100).await.unwrap();
        assert_eq!(logs.len(), 1);
        assert_eq!(logs[0].group_id, "group_1");

        // 验证自动创建群聊会话
        let conv = conversation_dao.get_by_id("sg_group_1").await.unwrap().unwrap();
        assert_eq!(conv.conversation_type, 3);
        assert_eq!(conv.group_id, "group_1");
        assert_eq!(conv.show_name, "Group_group_1");
        assert_eq!(conv.unread_count, 1);
    }
}
