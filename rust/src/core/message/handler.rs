use crate::domain::constant::types::content_type;
use crate::domain::constant::types::msg_status;
use crate::domain::constant::types::notification_type::{HAS_READ_RECEIPT, REVOKE};
use crate::domain::constant::types::session_type;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::{GroupReadReceipt, MessageReceipt, SdkEvent};
use crate::domain::listener::conversation::ConversationListener;
use crate::domain::model::message::ReceivedMessage;
use crate::domain::model::msg_struct::TypingElem;
use crate::infra::database::{ConversationDao, GroupDao, MessageDao, UserDao};
use crate::infra::database::models::{LocalChatLog, LocalConversation};
use crate::protocol::sdkws::{MarkAsReadTips, RevokeMsgTips};
use prost::Message as ProstMessage;
use std::collections::HashMap;
use std::sync::Arc;
use tracing::{debug, info, warn, error};
use rand::Rng;

/// 从 JSON 内容解析 RevokeMsgTips（对齐 Go SDK UnmarshalNotificationElem）
/// 服务端将 protobuf 对象转为 JSON 后放入 MsgData.content，
/// 外层: {"detail": "..."}  内层: RevokeMsgTips 字段
/// 撤回通知扩展结构（protobuf RevokeMsgTips 不含 revokerNickname，此结构补充）
pub struct RevokeTipsWithNickname {
    pub tips: RevokeMsgTips,
    pub revoker_nickname: String,
    pub revoker_role: i32,
}

fn parse_revoke_tips_from_json(content: &str) -> anyhow::Result<RevokeTipsWithNickname> {
    let content_str = content;

    // 解析外层 NotificationElem
    #[derive(serde::Deserialize)]
    struct Outer {
        #[serde(default)]
        detail: String,
    }
    let outer: Outer = serde_json::from_str(content_str)
        .map_err(|e| anyhow::anyhow!("解析外层 NotificationElem 失败: {}", e))?;

    // 解析内层 RevokeMsgTips JSON
    #[derive(serde::Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct Inner {
        #[serde(rename = "revokerUserID", default)]
        revoker_user_id: String,
        #[serde(rename = "clientMsgID", default)]
        client_msg_id: String,
        #[serde(default)]
        revoke_time: i64,
        #[serde(rename = "sesstionType", default)]
        sesstion_type: i32,
        #[serde(default)]
        seq: i64,
        #[serde(rename = "conversationID", default)]
        conversation_id: String,
        #[serde(rename = "isAdminRevoke", default)]
        is_admin_revoke: bool,
        #[serde(rename = "revokerNickname", default)]
        revoker_nickname: String,
        #[serde(rename = "revokerRole", default)]
        revoker_role: i32,
    }
    let inner: Inner = serde_json::from_str(&outer.detail)
        .map_err(|e| anyhow::anyhow!("解析内层 RevokeMsgTips 失败: {}", e))?;

    info!("[REVOKE-DEBUG-PARSE] parsed revoker_nickname='{}', revoker_role={}, user_id='{}'",
        inner.revoker_nickname, inner.revoker_role, inner.revoker_user_id);
    Ok(RevokeTipsWithNickname {
        tips: RevokeMsgTips {
            revoker_user_id: inner.revoker_user_id,
            client_msg_id: inner.client_msg_id,
            revoke_time: inner.revoke_time,
            sesstion_type: inner.sesstion_type,
            seq: inner.seq,
            conversation_id: inner.conversation_id,
            is_admin_revoke: inner.is_admin_revoke,
        },
        revoker_nickname: inner.revoker_nickname,
        revoker_role: inner.revoker_role,
    })
}

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

pub struct MessageHandler {
    message_dao: Arc<MessageDao>,
    conversation_dao: Arc<ConversationDao>,
    user_dao: Arc<UserDao>,
    group_dao: Arc<GroupDao>,
    user_id: std::sync::Mutex<String>,
    pub max_seq_recorder: Arc<MaxSeqRecorder>,
    conversation_listener: Arc<ConversationListener>,
}

impl MessageHandler {
    pub fn new(
        message_dao: Arc<MessageDao>,
        conversation_dao: Arc<ConversationDao>,
        user_dao: Arc<UserDao>,
        group_dao: Arc<GroupDao>,
        conversation_listener: Arc<ConversationListener>,
    ) -> Self {
        Self {
            message_dao,
            conversation_dao,
            user_dao,
            group_dao,
            user_id: std::sync::Mutex::new(String::new()),
            max_seq_recorder: Arc::new(MaxSeqRecorder::new()),
            conversation_listener,
        }
    }

    pub fn conversation_listener(&self) -> &Arc<ConversationListener> {
        &self.conversation_listener
    }

    pub fn set_user_id(&self, user_id: String) {
        *self.user_id.lock().unwrap() = user_id;
    }

    pub fn message_dao(&self) -> Arc<MessageDao> {
        self.message_dao.clone()
    }

    fn is_tip_message(content_type_val: i32) -> bool {
        content_type_val >= content_type::NOTIFICATION_BEGIN && content_type_val <= content_type::NOTIFICATION_END
    }

    fn should_store_message(content_type_val: i32) -> bool {
        !Self::is_tip_message(content_type_val)
            && content_type_val != content_type::TYPING
            && content_type_val != content_type::CUSTOM_MSG_ONLINE_ONLY
    }

    fn should_update_conversation(content_type_val: i32) -> bool {
        Self::should_store_message(content_type_val)
            && content_type_val != content_type::CUSTOM_MSG_NOT_TRIGGER_CONVERSATION
    }

    /// 处理异常消息（对齐 Go SDK `handleExceptionMessages`）
    ///
    /// 4 种异常类型：
    /// - SEQ_GAP: 服务端占位符（Status=DELETED, ClientMsgID=""）
    /// - DELETED: 服务端标记删除（Status=DELETED, ClientMsgID!=""）
    /// - SEQ_DUP: Seq 重复（已存在消息的 Seq == 新消息 Seq）
    /// - CLIENT_DUP: ClientMsgID 重复但 Seq 不同
    ///
    /// 异常消息不是丢弃，而是修改 ClientMsgID 后插入本地数据库（带特殊标记前缀）
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

    /// 将 ReceivedMessage 转为 LocalChatLog
    fn received_to_local(&self, msg: &ReceivedMessage) -> LocalChatLog {
        LocalChatLog {
            conversation_id: msg.conversation_id.clone(),
            client_msg_id: msg.client_msg_id.clone(),
            server_msg_id: msg.server_msg_id.clone(),
            send_id: msg.send_id.clone(),
            recv_id: msg.recv_id.clone(),
            sender_platform_id: msg.sender_platform_id,
            sender_nick_name: msg.sender_nick_name.clone(),
            sender_face_url: msg.sender_face_url.clone(),
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: msg.content.clone(),
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
    pub async fn handle_messages(&self, messages: Vec<ReceivedMessage>) -> Result<bool> {
        self.handle_messages_internal(messages, false).await
    }

    /// 处理消息列表（标记为同步来源），返回 true 表示有非 typing 的状态变更
    pub async fn handle_sync_messages(&self, messages: Vec<ReceivedMessage>) -> Result<bool> {
        self.handle_messages_internal(messages, true).await
    }

    /// 返回 true 表示处理了非 typing 的状态变更消息（typing 消息触发 ConversationUserInputStatusChanged 但不计入）
    async fn handle_messages_internal(&self, messages: Vec<ReceivedMessage>, is_from_sync: bool) -> Result<bool> {
        if messages.is_empty() {
            return Ok(false);
        }

        info!("handling {} messages", messages.len());

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
        // 服务端推送的撤回通知 content 是 JSON（非 protobuf），与 notification handler 一致
        for msg in &messages {
            if msg.content_type == REVOKE {
                match parse_revoke_tips_from_json(&msg.content) {
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
        let normal_messages: Vec<ReceivedMessage> = messages.into_iter()
            .filter(|m| m.content_type != HAS_READ_RECEIPT && m.content_type != REVOKE)
            .collect();

        if normal_messages.is_empty() {
            return Ok(false);
        }

        // 处理 Typing 消息：发布输入状态变化事件（对齐 Go SDK OnConversationUserInputStatusChanged）
        for msg in &normal_messages {
            if msg.content_type == content_type::TYPING {
                if let Ok(typing_elem) = serde_json::from_str::<TypingElem>(&msg.content) {
                    let platform_id = msg.sender_platform_id;
                    let is_typing = typing_elem.msg_tips == "yes";
                    self.conversation_listener.on_user_input_status_changed.notify(&(msg.conversation_id.clone(), msg.send_id.clone(), if is_typing { vec![platform_id] } else { vec![] }));
                }
            }
        }

        // typing 消息已处理完事件，从 normal_messages 中移除，避免入库和触发 NewMessage 事件
        let normal_messages: Vec<ReceivedMessage> = normal_messages.into_iter()
            .filter(|m| m.content_type != content_type::TYPING)
            .collect();

        // typing 消息已处理（发布 ConversationUserInputStatusChanged），
        // 但只有非 typing 消息才需要触发 TotalUnreadCountChanged
        let has_state_changes = !normal_messages.is_empty();

        let client_msg_ids: Vec<String> = normal_messages.iter().map(|m| m.client_msg_id.clone()).collect();

        // 批量查库去重（对齐 Go SDK pullMessageIntoTable L53-70）
        let existing_logs = self.message_dao.get_by_client_msg_ids(&client_msg_ids).await.unwrap_or_default();
        let mut existing_map: HashMap<String, LocalChatLog> = HashMap::new();
        for log in existing_logs {
            existing_map.insert(log.client_msg_id.clone(), log);
        }

        let login_user_id = self.user_id.lock().unwrap().clone();
        debug!("[MSG_DIAG] handle_messages: login_user={}, msg_count={}", login_user_id, normal_messages.len());
        for msg in &normal_messages {
            info!("[MSG_DIAG]   msg: conv={}, send_id={}, seq={}, is_self={}, content_type={}",
                msg.conversation_id, msg.send_id, msg.seq,
                msg.send_id == login_user_id, msg.content_type);
        }
        let mut insert_list: Vec<LocalChatLog> = Vec::new();
        let mut batch_update_list: Vec<(String, i64)> = Vec::new(); // (client_msg_id, seq)
        let mut to_notify: Vec<ReceivedMessage> = Vec::new();
        let mut processed_ids: std::collections::HashSet<String> = std::collections::HashSet::new();
        let mut is_trigger_unread_count = false;

        for msg in &normal_messages {
            // 批次内重复 → 异常处理
            if processed_ids.contains(&msg.client_msg_id) {
                let mut local_msg: LocalChatLog = self.received_to_local(msg);
                self.handle_exception_messages(None, &mut local_msg);
                insert_list.push(local_msg);
                continue;
            }
            processed_ids.insert(msg.client_msg_id.clone());

            let exists = existing_map.get(&msg.client_msg_id);
            let is_self = msg.send_id == login_user_id;

            let is_store = Self::should_store_message(msg.content_type);

            if is_self {
                if let Some(existing) = exists {
                    if existing.seq == 0 && msg.seq > 0 {
                        // 本地发送消息尚未同步 seq → 更新
                        if is_store {
                            batch_update_list.push((existing.client_msg_id.clone(), msg.seq));
                        }
                    }
                    // CLIENT_DUP: 已同步过 seq 的消息再次到达（seq 间隙补偿拉取等），
                    // 跳过不插入重复消息，避免消息列表中多出一条
                } else {
                    // 本端同步自己发的消息（其他设备发送的）
                    if is_store {
                        let mut local_msg: LocalChatLog = self.received_to_local(msg);
                        local_msg.status = msg_status::SEND_SUCCESS as i32;
                        insert_list.push(local_msg);
                    }
                }
            } else {
                if exists.is_none() {
                    // 正常新消息：他人发送
                    // online_only 或不需要存储的消息不入库，但仍触发事件
                    if msg.is_online_only || !is_store {
                        to_notify.push(msg.clone());
                    } else {
                        let mut local_msg: LocalChatLog = self.received_to_local(msg);
                        local_msg.status = msg_status::SEND_SUCCESS as i32;
                        let conv_id = local_msg.conversation_id.clone();
                        let msg_seq = local_msg.seq;
                        insert_list.push(local_msg);
                        to_notify.push(msg.clone());
                        if self.max_seq_recorder.is_new_msg(&conv_id, msg_seq) {
                            is_trigger_unread_count = true;
                            self.max_seq_recorder.incr(&conv_id, 1);
                        }
                    }
                } else {
                    // CLIENT_DUP: 消息已存在（重复推送或 seq 间隙补偿拉取），跳过不插入
                    info!("[MSG] 跳过重复消息: client_msg_id={}, seq={}", msg.client_msg_id, msg.seq);
                }
            }
        }

        // 批量更新 seq（对齐 Go SDK batchUpdateMessageList）
        if !batch_update_list.is_empty() {
            info!("batch update seq for {} messages", batch_update_list.len());
            self.message_dao.batch_update_seq(&batch_update_list).await?;
        }

        // 批量插入消息（对齐 Go SDK batchInsertMessageList）
        if !insert_list.is_empty() {
            info!("准备插入 {} 条消息到数据库", insert_list.len());
            for log in &insert_list {
                debug!("  待插入: conv={}, client_msg_id={}, seq={}, status={}",
                      log.conversation_id, log.client_msg_id, log.seq, log.status);
            }
            self.message_dao.batch_insert(&insert_list).await?;
            info!("消息插入数据库完成");
        }

        let mut seen_convs = std::collections::HashSet::new();
        // clone to_notify 以避免 borrow 与后续消费冲突（async 循环延长 borrow 生命周期）
        let to_notify_cloned = to_notify.clone();
        for msg in &to_notify_cloned {
            let is_conversation_update = Self::should_update_conversation(msg.content_type);
            let is_self = msg.send_id == login_user_id;

            // 首次见到该会话时创建（unread_count=0）
            if seen_convs.insert(&msg.conversation_id) {
                let existing = self.conversation_dao.get_by_id(&msg.conversation_id).await?;
                if existing.is_none() {
                    let show_name = if msg.session_type == 1 {
                        msg.sender_nick_name.clone()
                    } else {
                        format!("Group_{}", msg.group_id)
                    };

                    let conv = LocalConversation {
                        conversation_id: msg.conversation_id.clone(),
                        conversation_type: msg.session_type,
                        user_id: if msg.session_type == 1 { msg.recv_id.clone() } else { msg.send_id.clone() },
                        group_id: if msg.session_type != 1 { msg.group_id.clone() } else { String::new() },
                        show_name,
                        face_url: msg.sender_face_url.clone(),
                        latest_msg: if is_conversation_update { msg.content.clone() } else { String::new() },
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
                    info!("创建新会话: {}", msg.conversation_id);
                }
            }

            // 每条新消息都更新 latestMsg（对齐 Go SDK：所有消息都更新会话预览）
            // online_only 消息不更新（对齐 Go SDK：RecvOnlineOnlyMessage）
            if is_conversation_update && !msg.is_online_only {
                // 更新 latestMsg（无论是否自己发的）
                self.conversation_dao
                    .update_latest_msg(
                        &msg.conversation_id,
                        &msg.content,
                        msg.send_time,
                    )
                    .await?;
                
                // 只有别人发的消息才增加未读数
                if !is_self {
                    debug!("[UNREAD_DIAG] 增加未读: conv={}, seq={}, send_id={}", msg.conversation_id, msg.seq, msg.send_id);
                    self.conversation_dao
                        .increase_unread_count(&msg.conversation_id, msg.seq)
                        .await?;
                }
            }

            if msg.content_type != content_type::TYPING {
            }
        }

        // 诊断：汇总未读数变化
        let unread_convs: Vec<String> = to_notify.iter()
            .filter(|m| m.send_id != login_user_id)
            .map(|m| m.conversation_id.clone())
            .collect();
        info!("[UNREAD_DIAG] to_notify 总数={}, 非自己消息数={}", to_notify.len(), unread_convs.len());
        for conv_id in &unread_convs {
            if let Ok(Some(c)) = self.conversation_dao.get_by_id(conv_id).await {
                debug!("[UNREAD_DIAG] 会话 {} 未读数={}", conv_id, c.unread_count);
            }
        }

        info!("handled {} messages ({} inserted, {} duplicates skipped)", 
            normal_messages.len(), insert_list.len(), normal_messages.len() - insert_list.len());

        // 离线新消息通知（对齐 Go SDK OnRecvOfflineNewMessage）
        // 同步过程中收到的消息需要额外通知上层 UI（必须在 for msg in &to_notify 之后消费）
        let offline_msgs: Vec<ReceivedMessage> = if is_from_sync && !to_notify.is_empty() {
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
                self.conversation_listener.on_changed.notify(&vec![conversation.clone()]);
            }
        }

        Ok(has_state_changes)
    }

    /// 发布 TotalUnreadCountChanged 事件（由调用方在批量处理完成后统一调用）
    pub async fn publish_total_unread_count_changed(&self) {
        if let Ok(total) = self.conversation_dao.get_total_unread_count().await {
            self.conversation_listener.on_total_unread_count_changed.notify(&total);
        }
    }

    /// 已读回执处理（对齐 Go SDK read_drawing.go doReadDrawing L227-284）
    ///
    /// 两条路径：
    /// 1. 别人发来的已读回执（对方标记我的消息已读）：
    ///    - 单聊：标记消息 is_read + 发布 C2CReadReceipt 事件 + 重算未读数
    ///    - 群聊/通知：仅重算未读数（doUnreadCount）
    /// 2. 自己的已读回执（其他设备同步）：更新未读数
    async fn handle_read_receipt(&self, msg: &ReceivedMessage) -> Result<()> {
        let tips = MarkAsReadTips::decode(msg.content.as_bytes())
            .map_err(|e| SdkError::invalid_argument(format!("解析 MarkAsReadTips 失败: {}", e)))?;

        let login_user_id = self.user_id.lock().unwrap().clone();

        if tips.mark_as_read_user_id != login_user_id {
            // 别人发来的已读回执：对方标记我的消息为已读（对齐 Go SDK L238-280）

            // 获取本地会话（对齐 Go SDK L244）
            let conversation = self.conversation_dao.get_by_id(&tips.conversation_id).await?;
            let session_type_val = conversation.as_ref()
                .map(|c| c.conversation_type)
                .unwrap_or(msg.session_type);

            if session_type_val == session_type::SINGLE_CHAT {
                // 单聊：标记消息已读（对齐 Go SDK L251-280）
                if !tips.seqs.is_empty() {
                    // 通过 seq 查询消息，逐条标记 is_read = true
                    let messages = self.message_dao.get_by_seqs(&tips.conversation_id, &tips.seqs).await?;
                    let mut updated_client_msg_ids: Vec<String> = Vec::new();

                    for mut m in messages {
                        if m.is_read == 0 {
                            m.is_read = 1;
                            // 更新本地 DB（设置 is_read = 1，不过滤 send_id）
                            self.message_dao.mark_as_read_by_seqs_all(
                                &tips.conversation_id,
                                &[m.seq],
                            ).await?;
                            updated_client_msg_ids.push(m.client_msg_id.clone());
                        }
                    }

                    // 发布 C2C 已读回执事件（对齐 Go SDK OnRecvC2CReadReceipt）
                    if !updated_client_msg_ids.is_empty() {
                    }
                }
            } else if session_type_val == session_type::WRITE_GROUP_CHAT
                || session_type_val == session_type::READ_GROUP_CHAT
            {
                // 群聊：发布群已读回执事件（对齐 Go SDK OnRecvGroupReadReceipt）
            }

            // 重算未读数（对齐 Go SDK doUnreadCount）
            self.do_unread_count(
                &tips.conversation_id,
                session_type_val,
                tips.has_read_seq,
                &tips.seqs,
            ).await?;

            info!("[RECEIPT] conv={} mark_user={} seqs={}", tips.conversation_id, tips.mark_as_read_user_id, tips.seqs.len());

        } else {
            // 自己的已读回执（其他设备同步过来的，对齐 Go SDK L282-284）
            // 直接将会话未读数清零
            self.conversation_dao.update_unread_count(&tips.conversation_id, 0).await?;

            // 发布事件
            if let Ok(total) = self.conversation_dao.get_total_unread_count().await {
                self.conversation_listener.on_total_unread_count_changed.notify(&total);
            }

            info!("[RECEIPT] self sync conv={}", tips.conversation_id);
        }

        Ok(())
    }

    /// 处理来自 NotificationHandler 的已读回执（MsgData 格式，content_type=2200）
    /// 通知消息的 content 是 JSON 格式：{"detail": "{\"markAsReadUserID\":...}"}
    /// 需要先解析外层 JSON 取 detail，再解析内层 JSON 取 MarkAsReadTips 字段
    pub async fn handle_read_receipt_from_msg_data(&self, msg: &crate::protocol::sdkws::MsgData) -> Result<()> {
        // 1. 解析外层 JSON 获取 detail 字段
        let content_str = std::str::from_utf8(&msg.content)
            .map_err(|e| SdkError::invalid_argument(format!("content 不是有效 UTF-8: {}", e)))?;
        let outer: serde_json::Value = serde_json::from_str(content_str)
            .map_err(|e| SdkError::invalid_argument(format!("解析外层 JSON 失败: {}", e)))?;
        let detail_str = outer.get("detail")
            .and_then(|v| v.as_str())
            .ok_or_else(|| SdkError::invalid_argument("JSON 缺少 detail 字段".to_string()))?;

        // 2. 解析内层 JSON 获取 MarkAsReadTips 字段
        #[derive(serde::Deserialize)]
        struct MarkAsReadTipsJson {
            #[serde(rename = "markAsReadUserID")]
            mark_as_read_user_id: String,
            #[serde(rename = "conversationID")]
            conversation_id: String,
            #[serde(default)]
            seqs: Option<Vec<i64>>,
            #[serde(rename = "hasReadSeq")]
            has_read_seq: i64,
        }
        let tips_json: MarkAsReadTipsJson = serde_json::from_str(detail_str)
            .map_err(|e| SdkError::invalid_argument(format!("解析 detail JSON 失败: {}", e)))?;
        let seqs = tips_json.seqs.unwrap_or_default();

        let login_user_id = self.user_id.lock().unwrap().clone();

        if tips_json.mark_as_read_user_id != login_user_id {
            let conversation = self.conversation_dao.get_by_id(&tips_json.conversation_id).await?;
            let session_type_val = conversation.as_ref()
                .map(|c| c.conversation_type)
                .unwrap_or(msg.session_type);

            if session_type_val == session_type::SINGLE_CHAT {
                if !seqs.is_empty() {
                    let messages = self.message_dao.get_by_seqs(&tips_json.conversation_id, &seqs).await?;
                    let mut updated_client_msg_ids: Vec<String> = Vec::new();

                    for mut m in messages {
                        if m.is_read == 0 {
                            m.is_read = 1;
                            self.message_dao.mark_as_read_by_seqs_all(
                                &tips_json.conversation_id,
                                &[m.seq],
                            ).await?;
                            updated_client_msg_ids.push(m.client_msg_id.clone());
                        }
                    }

                    if !updated_client_msg_ids.is_empty() {
                    }
                }
            } else if session_type_val == session_type::WRITE_GROUP_CHAT
                || session_type_val == session_type::READ_GROUP_CHAT
            {
            }

            self.do_unread_count(
                &tips_json.conversation_id,
                session_type_val,
                tips_json.has_read_seq,
                &seqs,
            ).await?;

            info!("[RECEIPT] notif conv={} mark_user={} seqs={}", tips_json.conversation_id, tips_json.mark_as_read_user_id, seqs.len());
        } else {
            self.conversation_dao.update_unread_count(&tips_json.conversation_id, 0).await?;
            if let Ok(total) = self.conversation_dao.get_total_unread_count().await {
                self.conversation_listener.on_total_unread_count_changed.notify(&total);
            }

            info!("[RECEIPT] notif self sync conv={}", tips_json.conversation_id);
        }

        Ok(())
    }

    /// 重算会话未读数（对齐 Go SDK `doUnreadCount` read_drawing.go L173-225）
    ///
    /// 单聊：使用 MaxSeqRecorder 获取 currentMaxSeq，计算 unread = currentMaxSeq - hasReadSeq
    /// 群聊/通知：直接将未读数清零
    async fn do_unread_count(
        &self,
        conversation_id: &str,
        session_type_val: i32,
        has_read_seq: i64,
        seqs: &[i64],
    ) -> Result<()> {
        if session_type_val == session_type::SINGLE_CHAT {
            // 单聊：通过 seq 标记消息已读（对齐 Go SDK L186-199）
            if !seqs.is_empty() {
                // 检查 hasReadSeq 对应的消息是否已读过
                if let Ok(Some(msg)) = self.message_dao.get_by_seq(has_read_seq).await {
                    if msg.is_read != 0 {
                        // 已读过，忽略（对齐 Go SDK L189-192）
                        return Ok(());
                    }
                }

                // 按 seq 批量标记已读（对齐 Go SDK L195-196）
                let login_user_id = self.user_id.lock().unwrap().clone();
                self.message_dao.mark_as_read_by_seqs(conversation_id, seqs, &login_user_id).await?;
            }

            // 使用 MaxSeqRecorder 计算未读数（对齐 Go SDK L200-206）
            let current_max_seq = self.max_seq_recorder.get(conversation_id);
            let unread_count = if current_max_seq > has_read_seq {
                (current_max_seq - has_read_seq) as i32
            } else {
                0
            };

            self.conversation_dao.update_unread_count(conversation_id, unread_count).await?;

        } else {
            // 群聊/通知会话：直接清零（对齐 Go SDK L208-213）
            self.conversation_dao.update_unread_count(conversation_id, 0).await?;
        }

        // 对齐 Go SDK：doUnreadCount 不单独发布 TotalUnreadCountChanged
        // TotalUnreadCountChanged 由 handle_messages_internal 末尾统一发布，避免中间态闪烁

        Ok(())
    }

    /// 从通知 JSON 中提取 revokerNickname（服务端下发的真实昵称）
    /// 通知格式: {"detail": "{\"revokerNickname\":\"xxx\",...}"}
    fn extract_nickname_from_notification(content: &str) -> Option<String> {
        if content.is_empty() { return None; }
        let outer: serde_json::Value = serde_json::from_str(content).ok()?;
        let detail_str = outer.get("detail")?.as_str()?;
        let inner: serde_json::Value = serde_json::from_str(detail_str).ok()?;
        let name = inner.get("revokerNickname")?.as_str()?;
        if name.is_empty() { None } else { Some(name.to_string()) }
    }

    /// 获取撤回者昵称（对齐 Go SDK getUserNameAndFaceURL + GetSpecifiedGroupMembersInfo）
    /// - 单聊 / 管理员撤回：从用户表查询昵称
    /// - 群聊：从群成员表查询昵称和角色
    async fn get_revoker_nickname(&self, tips: &RevokeMsgTips) -> (String, i32) {
        let mut revoker_role = 0i32;
        let fallback = tips.revoker_user_id.clone();

        if tips.is_admin_revoke || tips.sesstion_type == crate::domain::constant::types::session_type::SINGLE_CHAT {
            // 单聊或管理员撤回 -> 从用户表查询
            if let Ok(Some(user)) = self.user_dao.get_by_id(&tips.revoker_user_id).await {
                if !user.name.is_empty() {
                    return (user.name, 0);
                }
            }
        } else if tips.sesstion_type == crate::domain::constant::types::session_type::WRITE_GROUP_CHAT
            || tips.sesstion_type == crate::domain::constant::types::session_type::READ_GROUP_CHAT {
            // 群聊 -> 从群成员表查询
            if let Ok(Some(conv)) = self.conversation_dao.get_by_id(&tips.conversation_id).await {
                if let Ok(members) = self.group_dao.get_members(&conv.group_id).await {
                    if let Some(member) = members.iter().find(|m| m.user_id == tips.revoker_user_id) {
                        revoker_role = member.role_level;
                        if !member.nickname.is_empty() {
                            return (member.nickname.clone(), revoker_role);
                        }
                    }
                }
            }
        }
        (fallback, revoker_role)
    }

    /// 撤回通知处理（严格对齐 Go SDK revoke_message）
    ///
    /// 官方实现流程：
    /// 1. 获取被撤回的消息
    /// 2. 获取撤回者信息
    /// 3. 构建 MessageRevoked 结构
    /// 4. 更新 DB：替换消息内容为 RevokeNotification
    /// 5. 如果撤回的是最新消息 → 刷新会话 LatestMsg
    /// 6. 触发 OnNewRecvMessageRevoked 回调
    /// 7. 搜索所有引用该消息的 Quote 消息并更新
    pub async fn handle_revoke_notification(&self, tips: &RevokeMsgTips, server_revoker_nickname: &str, server_revoker_role: i32) -> Result<()> {
        // 1. 获取被撤回的消息（按 conversation_id 和 seq 查询，对齐官方实现）
        let revoked_msg = self.message_dao.get_by_conversation_and_seq(&tips.conversation_id, tips.seq).await?
            .ok_or_else(|| {
                let err_msg = format!("被撤回的消息不存在: conversation_id={}, seq={}", tips.conversation_id, tips.seq);
                warn!("[REVOKE] {}", err_msg);
                SdkError::InvalidArgument { message: err_msg }
            })?;

        // 2. 获取撤回者昵称（优先级: 服务端通知 > 本地用户表 > 本地群成员表 > user_id）
        info!("[REVOKE-DEBUG] server_revoker_nickname='{}', server_revoker_role={}, revoker_user_id={}", 
            server_revoker_nickname, server_revoker_role, tips.revoker_user_id);
        let mut revoker_role = server_revoker_role;
        let mut revoker_nickname = if !server_revoker_nickname.is_empty() {
            info!("[REVOKE-DEBUG] 使用服务端昵称: '{}'", server_revoker_nickname);
            server_revoker_nickname.to_string()
        } else {
            let (name, role) = self.get_revoker_nickname(tips).await;
            info!("[REVOKE-DEBUG] 服务端昵称为空，DB查询结果: nickname='{}', role={}", name, role);
            revoker_role = role;
            name
        };
        // 如果仍然是 user_id，尝试用被撤回消息的发送者昵称（单聊中撤回者=发送者）
        if revoker_nickname == tips.revoker_user_id && !revoked_msg.sender_nick_name.is_empty() {
            info!("[REVOKE-DEBUG] 使用被撤回消息的sender_nick_name: '{}'", revoked_msg.sender_nick_name);
            revoker_nickname = revoked_msg.sender_nick_name.clone();
        }
        info!("[REVOKE-DEBUG] 最终昵称: '{}', user_id: '{}'", revoker_nickname, tips.revoker_user_id);
        // 如果仍然是 user_id，尝试从群成员表获取角色
        if revoker_nickname == tips.revoker_user_id && tips.sesstion_type == crate::domain::constant::types::session_type::WRITE_GROUP_CHAT
            || tips.sesstion_type == crate::domain::constant::types::session_type::READ_GROUP_CHAT {
            if let Ok(Some(conv)) = self.conversation_dao.get_by_id(&tips.conversation_id).await {
                if let Ok(members) = self.group_dao.get_members(&conv.group_id).await {
                    if let Some(member) = members.iter().find(|m| m.user_id == tips.revoker_user_id) {
                        revoker_role = member.role_level;
                    }
                }
            }
        }

        // 3. 构建 MessageRevoked 结构（对齐官方实现）
        let revoked_event = SdkEvent::MessageRevoked {
            conversation_id: tips.conversation_id.clone(),
            seq: tips.seq,
            client_msg_id: revoked_msg.client_msg_id.clone(),
            revoker_id: tips.revoker_user_id.clone(),
            revoker_role,
            revoker_nickname: revoker_nickname.clone(),
            revoke_time: tips.revoke_time,
            source_message_send_time: revoked_msg.send_time,
            source_message_send_id: revoked_msg.send_id.clone(),
            source_message_sender_nickname: revoked_msg.sender_nick_name.clone(),
            session_type: tips.sesstion_type,
            is_admin_revoke: tips.is_admin_revoke,
        };

        // 4. 更新 DB：替换消息内容为 RevokeNotification
        // 构建 NotificationElem 内容（对齐官方实现）
        let notification_content = serde_json::json!({
            "revokerID": tips.revoker_user_id,
            "revokerRole": revoker_role,
            "clientMsgID": revoked_msg.client_msg_id,
            "revokerNickname": revoker_nickname,
            "revokeTime": tips.revoke_time,
            "sourceMessageSendTime": revoked_msg.send_time,
            "sourceMessageSendID": revoked_msg.send_id,
            "sourceMessageSenderNickname": revoked_msg.sender_nick_name,
            "sessionType": tips.sesstion_type,
            "seq": tips.seq,
            "isAdminRevoke": tips.is_admin_revoke,
        });
        info!("[REVOKE-DEBUG] 写入DB的notification_content: {}", notification_content);
        
        // 更新消息内容类型和内容（对齐官方实现）
        self.message_dao.update_message_content_and_type(
            &tips.conversation_id,
            &revoked_msg.client_msg_id,
            &notification_content.to_string(),
            REVOKE,
        ).await?;
        
        info!("[REVOKE] 更新消息内容类型和内容: content_type={}, content={}", REVOKE, notification_content);

        // 5. 如果撤回的是最新消息 → 刷新会话 LatestMsg（对齐 Go SDK: latestMsg.Seq <= tips.Seq）
        if let Ok(Some(conv)) = self.conversation_dao.get_by_id(&tips.conversation_id).await {
            // 从 latest_msg JSON 中解析 seq（对齐 Go SDK: utils.JsonStringToStruct）
            let latest_seq: i64 = serde_json::from_str::<serde_json::Value>(&conv.latest_msg)
                .ok()
                .and_then(|v| v.get("seq").and_then(|s| s.as_i64()))
                .unwrap_or(0);
            if latest_seq <= tips.seq {
                if let Ok(latest_msgs) = self.message_dao.get_by_conversation(&tips.conversation_id, 0, 1).await {
                    if let Some(latest_msg) = latest_msgs.first() {
                        // 更新会话的最新消息
                        let updated_conv = crate::domain::model::conversation::Conversation {
                            conversation_id: conv.conversation_id,
                            conversation_type: conv.conversation_type,
                            user_id: conv.user_id,
                            group_id: conv.group_id,
                            show_name: conv.show_name,
                            face_url: conv.face_url,
                            latest_msg: latest_msg.content.clone(),
                            latest_msg_send_time: latest_msg.send_time,
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
                            latest_msg_seq: latest_msg.seq,
                            max_seq: conv.max_seq,
                            min_seq: conv.min_seq,
                            is_msg_destruct: conv.is_msg_destruct != 0,
                            msg_destruct_time: conv.msg_destruct_time,
                            update_flag: 0,
                            sync_action: None,
                            is_private: conv.is_private_chat != 0,
                            ex: conv.ex,
                        };
                        self.conversation_listener.on_changed.notify(&vec![updated_conv.clone()]);
                        info!("[REVOKE] 刷新会话 LatestMsg: latest_msg_send_time={}", latest_msg.send_time);
                    }
                }
            }
        }

        // 6. 触发 OnNewRecvMessageRevoked 回调

        // 7. 搜索所有引用该消息的 Quote 消息并更新（对齐官方实现）
        if let Err(e) = self.handle_quote_msg_revoke(&tips.conversation_id, &revoked_msg.client_msg_id, &notification_content.to_string()).await {
            warn!("[REVOKE] 处理引用消息撤回失败: {}", e);
        }

        info!("[REVOKE] handle_revoke_notification done");
        Ok(())
    }

    /// 处理引用消息的撤回（对齐官方实现 quoteMsgRevokeHandle）
    ///
    /// 当引用的消息被撤回时：
    /// 1. 搜索所有引用类型消息
    /// 2. 解析引用消息的 QuoteElem
    /// 3. 检查 QuoteMessage.ClientMsgID 是否匹配被撤回消息
    /// 4. 替换引用消息的 Content 和 ContentType 为 RevokeNotification
    /// 5. 更新 DB
    async fn handle_quote_msg_revoke(
        &self,
        conversation_id: &str,
        revoked_client_msg_id: &str,
        revoke_notification_content: &str,
    ) -> Result<()> {
        // 搜索所有引用类型消息（contentType = 104）
        let quote_msgs = self.message_dao.search_by_content_type(conversation_id, 104).await?;
        
        if quote_msgs.is_empty() {
            info!("[REVOKE] 没有找到引用消息");
            return Ok(());
        }

        info!("[REVOKE] 找到 {} 条引用消息", quote_msgs.len());

        for quote_msg in quote_msgs {
            // 解析引用消息的 QuoteElem
            if let Ok(quote_elem) = serde_json::from_str::<serde_json::Value>(&quote_msg.content) {
                // 检查 QuoteMessage.ClientMsgID 是否匹配被撤回消息
                if let Some(quote_message) = quote_elem.get("quoteMessage") {
                    if let Some(client_msg_id) = quote_message.get("clientMsgID").and_then(|v| v.as_str()) {
                        if client_msg_id == revoked_client_msg_id {
                            // 替换引用消息的 Content 和 ContentType 为 RevokeNotification
                            self.message_dao.update_message_content_and_type(
                                conversation_id,
                                &quote_msg.client_msg_id,
                                revoke_notification_content,
                                REVOKE,
                            ).await?;
                            
                            info!("[REVOKE] 更新引用消息: client_msg_id={}", quote_msg.client_msg_id);
                        }
                    }
                }
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;
    use crate::infra::database::{UserDao, GroupDao};

    fn make_msg(id: &str, conv_id: &str, seq: i64) -> ReceivedMessage {
        ReceivedMessage {
            server_msg_id: format!("srv_{}", id),
            client_msg_id: id.to_string(),
            send_id: "user_1".into(),
            recv_id: "user_2".into(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: format!("{{\"text\":\"hello {}\"}}", id),
            seq,
            send_time: seq * 1000,
            create_time: seq * 1000,
            conversation_id: conv_id.to_string(),
            group_id: String::new(),
            is_online_only: false,
        }
    }

    fn msg_with_ct(id: &str, conv_id: &str, seq: i64, ct: i32) -> ReceivedMessage {
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
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let user_dao = Arc::new(UserDao::new(pool.clone()));
        let group_dao = Arc::new(GroupDao::new(pool.clone()));
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(message_dao, conversation_dao, user_dao, group_dao, event_bus);

        let msgs = vec![
            make_msg("msg_1", "conv_1", 1),
            make_msg("msg_2", "conv_1", 2),
        ];

        handler.handle_messages(msgs).await.unwrap();
    }

    #[tokio::test]
    async fn test_dedup_via_insert_ignore() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let user_dao = Arc::new(UserDao::new(pool.clone()));
        let group_dao = Arc::new(GroupDao::new(pool.clone()));
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(message_dao, conversation_dao, user_dao, group_dao, event_bus);

        let msgs = vec![make_msg("msg_1", "conv_1", 1)];
        handler.handle_messages(msgs.clone()).await.unwrap();
        handler.handle_messages(msgs).await.unwrap();

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
        let user_dao = Arc::new(UserDao::new(pool.clone()));
        let group_dao = Arc::new(GroupDao::new(pool.clone()));
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(message_dao.clone(), conversation_dao.clone(), user_dao.clone(), group_dao.clone(), event_bus);

        let mut conv = make_conv("conv_tip");
        conv.unread_count = 5;
        conv.latest_msg = "earlier message".into();
        conv.latest_msg_send_time = 1000;
        conv.max_seq = 5;
        conversation_dao.upsert(&conv).await.unwrap();

        let msgs = vec![msg_with_ct("tip_1", "conv_tip", 6, crate::domain::constant::types::notification_type::FRIEND_APPLICATION)];
        handler.handle_messages(msgs).await.unwrap();

        let chat_logs = message_dao.get_by_conversation("conv_tip", 0, 100).await.unwrap();
        assert_eq!(chat_logs.len(), 0, "tip message should not be stored in local_chat_logs");

        let conv = conversation_dao.get_by_id("conv_tip").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 5, "unread_count should not increment for tip message");
        assert_eq!(conv.latest_msg, "earlier message", "latest_msg should not change for tip message");
        assert_eq!(conv.max_seq, 5, "max_seq should not change for tip message");
    }

    #[tokio::test]
    async fn test_typing_message_not_stored_and_no_event() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let user_dao = Arc::new(UserDao::new(pool.clone()));
        let group_dao = Arc::new(GroupDao::new(pool.clone()));
        let event_bus = Arc::new(EventBus::new());
        let mut sub = event_bus.subscribe();
        let handler = MessageHandler::new(message_dao.clone(), conversation_dao.clone(), user_dao.clone(), group_dao.clone(), event_bus);

        let msgs = vec![msg_with_ct("typing_1", "conv_typing", 1, content_type::TYPING)];
        handler.handle_messages(msgs).await.unwrap();

        let chat_logs = message_dao.get_by_conversation("conv_typing", 0, 100).await.unwrap();
        assert_eq!(chat_logs.len(), 0, "typing message should not be stored");

        let event = sub.try_next();
        assert!(event.is_none(), "typing message should not publish NewMessage event");

        let conv = conversation_dao.get_by_id("conv_typing").await.unwrap();
        if let Some(conv) = conv {
            assert_eq!(conv.unread_count, 0, "typing message should not increment unread_count");
            assert_eq!(conv.latest_msg, "", "typing message should not set latest_msg");
        }
    }

    #[tokio::test]
    async fn test_normal_message_increments_unread() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let user_dao = Arc::new(UserDao::new(pool.clone()));
        let group_dao = Arc::new(GroupDao::new(pool.clone()));
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(message_dao.clone(), conversation_dao.clone(), user_dao.clone(), group_dao.clone(), event_bus);

        let msgs1 = vec![msg_with_ct("msg_1", "conv_normal", 1, content_type::TEXT)];
        handler.handle_messages(msgs1).await.unwrap();

        let chat_logs = message_dao.get_by_conversation("conv_normal", 0, 100).await.unwrap();
        assert_eq!(chat_logs.len(), 1, "normal message should be stored");
        assert_eq!(chat_logs[0].content_type, content_type::TEXT);

        let conv = conversation_dao.get_by_id("conv_normal").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 1, "first normal message should set unread_count to 1");
        assert!(!conv.latest_msg.is_empty(), "latest_msg should be set for normal message");

        let msgs2 = vec![msg_with_ct("msg_2", "conv_normal", 2, content_type::TEXT)];
        handler.handle_messages(msgs2).await.unwrap();

        let chat_logs = message_dao.get_by_conversation("conv_normal", 0, 100).await.unwrap();
        assert_eq!(chat_logs.len(), 2, "second normal message should also be stored");

        let conv = conversation_dao.get_by_id("conv_normal").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 2, "second normal message should increment unread_count to 2");
    }

    /// 测试最新消息（latestMsg）是否被正确更新
    /// 对齐 Go SDK 行为：新消息到达时更新会话的 latestMsg 和 latestMsgSendTime
    #[tokio::test]
    async fn test_latest_msg_updated_correctly() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let user_dao = Arc::new(UserDao::new(pool.clone()));
        let group_dao = Arc::new(GroupDao::new(pool.clone()));
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(message_dao.clone(), conversation_dao.clone(), user_dao.clone(), group_dao.clone(), event_bus);

        // 发送第一条消息，latestMsg 应被设置为该消息的内容
        let msg1_content = r#"{"text":"hello"}"#;
        let msgs1 = vec![{
            let mut m = msg_with_ct("msg_1", "conv_latest", 1, content_type::TEXT);
            m.content = msg1_content.to_string();
            m.send_time = 1000;
            m
        }];
        handler.handle_messages(msgs1).await.unwrap();

        let conv = conversation_dao.get_by_id("conv_latest").await.unwrap().unwrap();
        assert_eq!(conv.latest_msg, msg1_content, "latestMsg should be set to first message content");
        assert_eq!(conv.latest_msg_send_time, 1000, "latestMsgSendTime should be set to first message sendTime");
        assert_eq!(conv.unread_count, 1, "unreadCount should be 1");

        // 发送第二条消息，latestMsg 应更新为第二条消息的内容
        let msg2_content = r#"{"text":"world"}"#;
        let msgs2 = vec![{
            let mut m = msg_with_ct("msg_2", "conv_latest", 2, content_type::TEXT);
            m.content = msg2_content.to_string();
            m.send_time = 2000;
            m
        }];
        handler.handle_messages(msgs2).await.unwrap();

        let conv = conversation_dao.get_by_id("conv_latest").await.unwrap().unwrap();
        assert_eq!(conv.latest_msg, msg2_content, "latestMsg should be updated to second message content");
        assert_eq!(conv.latest_msg_send_time, 2000, "latestMsgSendTime should be updated to second message sendTime");
        assert_eq!(conv.unread_count, 2, "unreadCount should be 2");

        // 发送第三条消息（更晚的时间），latestMsg 应更新为第三条消息
        let msg3_content = r#"{"text":"final"}"#;
        let msgs3 = vec![{
            let mut m = msg_with_ct("msg_3", "conv_latest", 3, content_type::TEXT);
            m.content = msg3_content.to_string();
            m.send_time = 3000;
            m
        }];
        handler.handle_messages(msgs3).await.unwrap();

        let conv = conversation_dao.get_by_id("conv_latest").await.unwrap().unwrap();
        assert_eq!(conv.latest_msg, msg3_content, "latestMsg should be updated to third message content");
        assert_eq!(conv.latest_msg_send_time, 3000, "latestMsgSendTime should be updated to third message sendTime");
        assert_eq!(conv.unread_count, 3, "unreadCount should be 3");
    }

    /// 测试收到他人消息时 latestMsg 是否被正确更新（is_self=false 的情况）
    #[tokio::test]
    async fn test_latest_msg_updated_for_other_user_message() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let user_dao = Arc::new(UserDao::new(pool.clone()));
        let group_dao = Arc::new(GroupDao::new(pool.clone()));
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(message_dao.clone(), conversation_dao.clone(), user_dao.clone(), group_dao.clone(), event_bus);
        handler.set_user_id("self_user".to_string()); // 设置当前用户 ID

        // 收到其他用户发送的消息
        let msg_content = r#"{"text":"message from other"}"#;
        let msgs = vec![{
            let mut m = msg_with_ct("msg_1", "conv_other", 1, content_type::TEXT);
            m.content = msg_content.to_string();
            m.send_time = 1000;
            m.send_id = "other_user".to_string(); // 发送者不是当前用户
            m
        }];
        handler.handle_messages(msgs).await.unwrap();

        let conv = conversation_dao.get_by_id("conv_other").await.unwrap().unwrap();
        assert_eq!(conv.latest_msg, msg_content, "latestMsg should be set for other user's message");
        assert_eq!(conv.latest_msg_send_time, 1000, "latestMsgSendTime should be set");
        assert_eq!(conv.unread_count, 1, "unreadCount should be 1 for other user's message");
    }

    #[tokio::test]
    async fn test_no_trigger_conv_stored_but_no_conv_update() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let user_dao = Arc::new(UserDao::new(pool.clone()));
        let group_dao = Arc::new(GroupDao::new(pool.clone()));
        let event_bus = Arc::new(EventBus::new());
        let mut sub = event_bus.subscribe();
        let handler = MessageHandler::new(message_dao.clone(), conversation_dao.clone(), user_dao.clone(), group_dao.clone(), event_bus);

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
        )];
        handler.handle_messages(msgs).await.unwrap();

        let chat_logs = message_dao.get_by_conversation("conv_notrigger", 0, 100).await.unwrap();
        assert_eq!(chat_logs.len(), 1, "NoTriggerConv message should still be stored");
        assert_eq!(
            chat_logs[0].content_type,
            content_type::CUSTOM_MSG_NOT_TRIGGER_CONVERSATION
        );

        let conv = conversation_dao.get_by_id("conv_notrigger").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 3, "unread_count should not increment for NoTriggerConv");
        assert_eq!(conv.latest_msg, "original msg", "latest_msg should not change for NoTriggerConv");
        assert_eq!(conv.max_seq, 3, "max_seq should not change for NoTriggerConv");

        let event = sub.try_next();
        assert!(event.is_some(), "NoTriggerConv message should still publish NewMessage event");
    }
}
