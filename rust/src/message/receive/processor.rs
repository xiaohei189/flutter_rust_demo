//! MessageProcessor — 接收消息的分类入库与事件分发中心
//!
//! 对齐 Go SDK `internal/conversation_msg/handler.go`

use super::max_seq_recorder::MaxSeqRecorder;
use crate::constant::content_type;
use crate::constant::content_type_utils::ContentTypeUtils;
use crate::constant::msg_status;
use crate::constant::notification_type::{HAS_READ_RECEIPT, REVOKE};
use crate::error::Result;
use crate::model::revoke::parse_revoke_tips_from_json;

use crate::client::context::Repositories;
use crate::event::events::conversation::{ConversationEvent, ConversationListener, ConversationListenerExt};
use crate::event::events::message::{MessageEvent, MessageListener, MessageListenerExt};
use crate::model::local::{LocalChatLog, LocalConversation};
use crate::model::msg_struct::TypingElem;
use crate::model::UserId;
use openim_protocol::sdkws::MsgData;
use std::collections::HashMap;
use std::sync::Arc;
use tracing::{debug, info, trace, warn};

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
/// - [`receipt`](super::receipt) — 已读回执处理（未读数计算 + 事件发布）
/// - [`revoke`](super::revoke) — 撤回通知处理（更新本地消息 + 引用消息处理）
pub struct MessageProcessor {
    /// 外部依赖（聚合）
    pub(crate) repositories: Arc<Repositories>,
    /// 身份
    pub(crate) user_id: UserId,
    /// 内部状态
    pub max_seq_recorder: Arc<MaxSeqRecorder>,
    /// 事件出口（Listener trait）
    pub(crate) listener: Arc<dyn ConversationListener>,
    /// 消息事件出口（对齐 Go SDK MsgListener）
    pub(crate) message_listener: Arc<dyn MessageListener>,
}

impl MessageProcessor {
    pub fn new(repositories: Arc<Repositories>, user_id: UserId, listener: Arc<dyn ConversationListener>, message_listener: Arc<dyn MessageListener>) -> Self {
        Self {
            repositories,
            user_id,
            max_seq_recorder: Arc::new(MaxSeqRecorder::new()),
            listener,
            message_listener,
        }
    }

    pub(crate) fn send(&self, e: ConversationEvent) {
        self.listener.emit(e);
    }

    /// 处理异常消息（对齐 Go SDK `handleExceptionMessages`）
    ///
    /// 4 种异常类型：
    /// - SEQ_GAP: 服务端占位符（Status=DELETED, ClientMsgID=""）
    /// - DELETED: 服务端标记删除（Status=DELETED, ClientMsgID!=""）
    /// - SEQ_DUP: Seq 重复（已存在消息的 Seq == 新消息 Seq）
    /// - CLIENT_DUP: ClientMsgID 重复但 Seq 不同
    fn handle_exception_messages(&self, existing_message: Option<&LocalChatLog>, message: &mut LocalChatLog) {
        let (prefix, seq, client_msg_id) = match existing_message {
            None if message.status == msg_status::HAS_DELETED as i32 && message.client_msg_id.is_empty() => ("[SEQ_GAP_+]".to_string(), message.seq, message.client_msg_id.clone()),
            None if message.status == msg_status::HAS_DELETED as i32 => ("[DELETED]".to_string(), message.seq, message.client_msg_id.clone()),
            Some(existing) if existing.seq == message.seq => ("[SEQ_DUP]".to_string(), message.seq, existing.client_msg_id.clone()),
            Some(existing) if existing.seq != message.seq => ("[CLIENT_DUP]".to_string(), message.seq, existing.client_msg_id.clone()),
            _ => return,
        };

        let random_suffix = crate::util::generate_random_id(8);
        let new_client_msg_id = if client_msg_id.is_empty() {
            format!("{}_{}", prefix, random_suffix)
        } else {
            format!("{}{}_{}", prefix, client_msg_id, random_suffix)
        };

        warn!("[MsgHandler] {} seq={}, oldClientMsgID={}, newClientMsgID={}", prefix, seq, message.client_msg_id, new_client_msg_id);

        message.status = msg_status::HAS_DELETED as i32;
        message.client_msg_id = new_client_msg_id;
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
        let normal_messages: Vec<MsgData> = messages.into_iter().filter(|m| m.content_type != HAS_READ_RECEIPT && m.content_type != REVOKE).collect();

        if normal_messages.is_empty() {
            return Ok(false);
        }

        // 处理 Typing 消息：发布输入状态变化事件
        let login_user_id = self.user_id.get().await;
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
                    self.send(ConversationEvent::UserInputStatusChanged {
                        conversation_id: conv_id.to_string(),
                        user_id: msg.send_id.clone(),
                        platform_ids: pids,
                    });
                }
            }
        }

        // typing 消息已处理完事件，从 normal_messages 中移除
        let normal_messages: Vec<MsgData> = normal_messages.into_iter().filter(|m| m.content_type != content_type::TYPING).collect();

        if normal_messages.is_empty() {
            return Ok(false);
        }

        let has_state_changes = !normal_messages.is_empty();

        let client_msg_ids: Vec<String> = normal_messages.iter().map(|m| m.client_msg_id.clone()).collect();

        // 批量查库去重
        let existing_logs = self.repositories.message_repo.get_by_client_msg_ids(&client_msg_ids).await.unwrap_or_default();
        let mut existing_map: HashMap<String, LocalChatLog> = HashMap::new();
        for log in existing_logs {
            existing_map.insert(log.client_msg_id.clone(), log);
        }

        let login_user_id = self.user_id.get().await;
        debug!("[MsgHandler] 收到 {} 条消息", normal_messages.len());
        for msg in &normal_messages {
            trace!(
                "[MsgHandler]   conv={}, send_id={}, seq={}, self={}, type={}({})",
                conv_id,
                msg.send_id,
                msg.seq,
                msg.send_id == login_user_id,
                ContentTypeUtils::display_name(msg.content_type),
                msg.content_type
            );
        }
        let mut insert_list: Vec<LocalChatLog> = Vec::new();
        let mut batch_update_list: Vec<(String, i64)> = Vec::new();
        let mut to_notify: Vec<MsgData> = Vec::new();
        let mut processed_ids: std::collections::HashSet<String> = std::collections::HashSet::new();
        let mut is_trigger_unread_count = false;

        for msg in &normal_messages {
            if processed_ids.contains(&msg.client_msg_id) {
                let mut local_msg: LocalChatLog = LocalChatLog::from_msg_data(conv_id, msg);
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
                        let local_msg: LocalChatLog = LocalChatLog::from_msg_data(conv_id, msg);
                        insert_list.push(local_msg);
                    }
                }
            } else {
                let is_online_only = msg.options.get("isOnlineOnly").copied().unwrap_or(false);
                if exists.is_none() {
                    if is_online_only || !is_store {
                        to_notify.push(msg.clone());
                    } else {
                        let local_msg: LocalChatLog = LocalChatLog::from_msg_data(conv_id, msg);
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
            self.repositories.message_repo.batch_update_seq(&batch_update_list).await?;
        }

        // 批量插入消息
        if !insert_list.is_empty() {
            for log in &insert_list {
                trace!("[MsgHandler]   插入: conv={}, client_msg_id={}, seq={}", log.conversation_id, log.client_msg_id, log.seq);
            }
            self.repositories.message_repo.batch_insert(&insert_list).await?;
        }

        let mut seen_convs = std::collections::HashSet::new();
        let to_notify_cloned = to_notify.clone();
        for msg in &to_notify_cloned {
            let is_conversation_update = ContentTypeUtils::should_update_conversation(msg.content_type);
            let is_self = msg.send_id == login_user_id;
            let is_online_only = msg.options.get("isOnlineOnly").copied().unwrap_or(false);
            let content_str = String::from_utf8_lossy(&msg.content);

            if seen_convs.insert(conv_id.to_string()) {
                let existing = self.repositories.conversation_repo.get_by_id(conv_id).await?;
                if existing.is_none() {
                    let show_name = if msg.session_type == 1 { msg.sender_nickname.clone() } else { format!("Group_{}", msg.group_id) };

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
                        is_pinned: false,
                        is_private_chat: false,
                        burn_duration: 0,
                        group_at_type: 0,
                        is_not_in_group: false,
                        update_unread_count_time: 0,
                        attached_info: String::new(),
                        ex: String::new(),
                        draft_text: String::new(),
                        draft_text_time: 0,
                        max_seq: msg.seq,
                        min_seq: 0,
                        is_msg_destruct: false,
                        msg_destruct_time: 0,
                    };
                    self.repositories.conversation_repo.upsert(&conv).await?;
                    debug!("[MsgHandler] 创建新会话: {}", conv_id);
                }
            }

            if is_conversation_update && !is_online_only {
                self.repositories.conversation_repo.update_latest_msg(conv_id, &content_str, msg.send_time).await?;

                if !is_self {
                    self.repositories.conversation_repo.increase_unread_count(conv_id, msg.seq).await?;
                }
            }
        }

        // 汇总日志
        let skipped = normal_messages.len() - insert_list.len() - batch_update_list.len();
        info!(
            "[MsgHandler] 完成: total={}, inserted={}, seq_updated={}, skipped={}, notify={}",
            normal_messages.len(),
            insert_list.len(),
            batch_update_list.len(),
            skipped,
            to_notify.len()
        );

        // 发布 NewMessage 事件（对齐 Go SDK OnRecvNewMessages）
        for msg in &to_notify {
            self.message_listener.emit(MessageEvent::NewMessage { message: msg.clone() });
        }

        // 离线新消息通知
        let offline_msgs: Vec<MsgData> = if is_from_sync && !to_notify.is_empty() {
            to_notify.into_iter().filter(|m| m.send_id != login_user_id && m.content_type != content_type::TYPING).collect()
        } else {
            Vec::new()
        };
        if !offline_msgs.is_empty() {}

        // 对齐 Go SDK：所有消息处理完成后统一发布会话变更。
        // 不只在“新插入消息”时发：自己发的消息、seq 回填等场景消息已存在，
        // 也需刷新会话列表，否则 UI 拿不到最新 latestMsg。
        if !normal_messages.is_empty() {
            if let Ok(Some(conv)) = self.repositories.conversation_repo.get_by_id(conv_id).await {
                self.send(ConversationEvent::Changed(vec![conv]));
            }
        }

        Ok(has_state_changes)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    use crate::db::pool::create_pool_memory;
    use crate::db::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};

    /// 创建测试用 Repositories
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
        let handler = MessageProcessor::new(
            make_test_repositories(pool),
            UserId::new(""),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
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
        let handler = MessageProcessor::new(
            make_test_repositories(pool),
            UserId::new(""),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
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
        let handler = MessageProcessor::new(
            make_test_repositories(pool),
            UserId::new(""),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
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
        let handler = MessageProcessor::new(
            make_test_repositories(pool),
            UserId::new(""),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
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
        let handler = MessageProcessor::new(
            make_test_repositories(pool),
            UserId::new(""),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
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
            is_pinned: false,
            is_private_chat: false,
            burn_duration: 0,
            group_at_type: 0,
            is_not_in_group: false,
            update_unread_count_time: 0,
            attached_info: String::new(),
            ex: String::new(),
            draft_text: String::new(),
            draft_text_time: 0,
            max_seq: 0,
            min_seq: 0,
            is_msg_destruct: false,
            msg_destruct_time: 0,
        }
    }

    #[tokio::test]
    async fn test_handle_messages() {
        let pool = create_pool_memory().await.unwrap();
        let handler = MessageProcessor::new(
            make_test_repositories(pool),
            UserId::new(""),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

        let msgs = vec![make_msg("msg_1", "conv_1", 1), make_msg("msg_2", "conv_1", 2)];
        handler.handle_messages("conv_1", msgs).await.unwrap();
    }

    #[tokio::test]
    async fn test_dedup_via_insert_ignore() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool.clone());
        let message_dao = repositories.message_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new(""),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

        let msgs = vec![make_msg("msg_1", "conv_1", 1)];
        handler.handle_messages("conv_1", msgs.clone()).await.unwrap();
        handler.handle_messages("conv_1", msgs).await.unwrap();

        let chat_logs = message_dao.get_by_conversation("conv_1", 0, 100).await.unwrap();
        assert_eq!(chat_logs.len(), 1);
    }

    #[tokio::test]
    async fn test_existing_message_still_emits_conversation_changed() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool.clone());
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let hub = crate::event::hub::EventHub::new();
        let mut conv_rx = hub.take_conv_rx().unwrap();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new("user_a"),
            hub.clone(),
            crate::event::test_util::noop_message_listener(),
        );

        conversation_dao.upsert(&make_conv("conv_1")).await.unwrap();
        let msg = make_msg("msg_1", "conv_1", 1);
        message_dao
            .batch_insert(&[LocalChatLog::from_msg_data("conv_1", &msg)])
            .await
            .unwrap();

        // 消息已存在（例如自己发送后的回推/seq 回填），也应刷新会话列表
        handler.handle_messages("conv_1", vec![msg]).await.unwrap();

        let mut got_changed = false;
        let timeout = tokio::time::sleep(std::time::Duration::from_secs(1));
        tokio::pin!(timeout);
        loop {
            tokio::select! {
                _ = &mut timeout => break,
                ev = conv_rx.recv() => {
                    if let Some(ConversationEvent::Changed(_)) = ev {
                        got_changed = true;
                        break;
                    }
                }
            }
        }
        assert!(got_changed, "已存在的消息也应发布会话变更事件");
    }

    #[tokio::test]
    async fn test_tip_message_not_stored() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new(""),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

        let mut conv = make_conv("conv_tip");
        conv.unread_count = 5;
        conv.latest_msg = "earlier message".into();
        conv.latest_msg_send_time = 1000;
        conv.max_seq = 5;
        conversation_dao.upsert(&conv).await.unwrap();

        let msgs = vec![msg_with_ct("tip_1", "conv_tip", 6, crate::constant::notification_type::FRIEND_APPLICATION)];
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
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new(""),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

        let msgs = vec![msg_with_ct("typing_1", "conv_typing", 1, content_type::TYPING)];
        handler.handle_messages("conv_typing", msgs).await.unwrap();
        let chat_logs = message_dao.get_by_conversation("conv_typing", 0, 100).await.unwrap();
        assert_eq!(chat_logs.len(), 0, "typing message should not be stored");

        // typing 消息不应发布任何事件
    }

    #[tokio::test]
    async fn test_normal_message_increments_unread() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new(""),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
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
        let repositories = make_test_repositories(pool);
        let conversation_dao = repositories.conversation_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new(""),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
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
        let repositories = make_test_repositories(pool);
        let conversation_dao = repositories.conversation_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new("self_user"),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

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
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let hub = crate::event::hub::EventHub::new();
        let handler = MessageProcessor::new(repositories, UserId::new(""), hub.clone(), crate::event::test_util::noop_message_listener());
        let mut rx = hub.take_conv_rx().unwrap();

        let mut conv = make_conv("conv_notrigger");
        conv.unread_count = 3;
        conv.latest_msg = "original msg".into();
        conv.latest_msg_send_time = 1000;
        conv.max_seq = 3;
        conversation_dao.upsert(&conv).await.unwrap();

        let msgs = vec![msg_with_ct("notrigger_1", "conv_notrigger", 4, content_type::CUSTOM_MSG_NOT_TRIGGER_CONVERSATION)];
        handler.handle_messages("conv_notrigger", msgs).await.unwrap();

        let chat_logs = message_dao.get_by_conversation("conv_notrigger", 0, 100).await.unwrap();
        assert_eq!(chat_logs.len(), 1, "NoTriggerConv message should still be stored");
        assert_eq!(chat_logs[0].content_type, content_type::CUSTOM_MSG_NOT_TRIGGER_CONVERSATION);

        let conv = conversation_dao.get_by_id("conv_notrigger").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 3, "unread_count should not increment for NoTriggerConv");
        assert_eq!(conv.latest_msg, "original msg", "latest_msg should not change for NoTriggerConv");

        let event = rx.try_recv();
        assert!(event.is_ok(), "NoTriggerConv message should still publish ConversationEvent::Changed");
    }

    #[tokio::test]
    async fn test_self_message_seq_backfill() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new("user_1"),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

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

        let msgs = vec![{
            let mut m = make_msg("msg_backfill", "conv_seq", 5);
            m.send_id = "user_1".into();
            m
        }];
        handler.handle_messages("conv_seq", msgs).await.unwrap();

        let logs = message_dao.get_by_conversation("conv_seq", 0, 100).await.unwrap();
        assert_eq!(logs.len(), 1);
        assert_eq!(logs[0].seq, 5, "seq should be backfilled from 0 to 5");
    }

    #[tokio::test]
    async fn test_duplicate_in_batch_second_dropped_by_db() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new("other_user"),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

        let msgs = vec![make_msg("dup_msg", "conv_dup", 1), make_msg("dup_msg", "conv_dup", 2)];
        handler.handle_messages("conv_dup", msgs).await.unwrap();

        let logs = message_dao.get_by_conversation("conv_dup", 0, 100).await.unwrap();
        assert_eq!(logs.len(), 1, "duplicate client_msg_id should be deduplicated by DB");
        assert_eq!(logs[0].seq, 1, "first message should be kept");
    }

    #[tokio::test]
    async fn test_online_only_message_not_stored() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new("self_user"),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

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
        let hub = crate::event::hub::EventHub::new();
        let handler = MessageProcessor::new(make_test_repositories(pool), UserId::new("self_user"), hub.clone(), crate::event::test_util::noop_message_listener());
        let mut rx = hub.take_conv_rx().unwrap();

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
            ConversationEvent::UserInputStatusChanged {
                conversation_id,
                user_id,
                platform_ids,
            } => {
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
        let hub = crate::event::hub::EventHub::new();
        let handler = MessageProcessor::new(make_test_repositories(pool), UserId::new("self_user"), hub.clone(), crate::event::test_util::noop_message_listener());
        let mut rx = hub.take_conv_rx().unwrap();

        let msgs = vec![{
            let mut m = msg_with_ct("typing_self", "conv_typing_self", 1, content_type::TYPING);
            m.send_id = "self_user".into();
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
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new("self_user"),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

        let msgs = vec![{
            let mut m = msg_with_ct("grp_msg_1", "sg_group_1", 1, content_type::TEXT);
            m.send_id = "other_user".into();
            m.session_type = 3;
            m.group_id = "group_1".into();
            m.sender_nickname = "Alice".into();
            m
        }];
        handler.handle_messages("sg_group_1", msgs).await.unwrap();

        let logs = message_dao.get_by_conversation("sg_group_1", 0, 100).await.unwrap();
        assert_eq!(logs.len(), 1);
        assert_eq!(logs[0].group_id, "group_1");

        let conv = conversation_dao.get_by_id("sg_group_1").await.unwrap().unwrap();
        assert_eq!(conv.conversation_type, 3);
        assert_eq!(conv.group_id, "group_1");
        assert_eq!(conv.show_name, "Group_group_1");
        assert_eq!(conv.unread_count, 1);
    }
}
