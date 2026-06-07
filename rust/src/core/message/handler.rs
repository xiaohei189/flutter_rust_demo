use crate::domain::constant::types::content_type;
use crate::domain::constant::types::msg_status;
use crate::domain::constant::types::notification_type::HAS_READ_RECEIPT;
use crate::domain::constant::types::session_type;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::{GroupReadReceipt, MessageReceipt, SdkEvent};
use crate::domain::model::message::ReceivedMessage;
use crate::domain::model::msg_struct::TypingElem;
use crate::infra::database::{ConversationDao, MessageDao};
use crate::infra::database::models::{LocalChatLog, LocalConversation};
use crate::protocol::sdkws::MarkAsReadTips;
use prost::Message as ProstMessage;
use std::collections::HashMap;
use std::sync::Arc;
use tracing::{debug, info, warn, error};
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

pub struct MessageHandler {
    message_dao: Arc<MessageDao>,
    conversation_dao: Arc<ConversationDao>,
    event_bus: Arc<EventBus>,
    user_id: std::sync::Mutex<String>,
    /// 内存 seq 记录器，用于准确判断未读数（对齐 Go SDK MaxSeqRecorder）
    pub max_seq_recorder: Arc<MaxSeqRecorder>,
}

impl MessageHandler {
    pub fn new(
        message_dao: Arc<MessageDao>,
        conversation_dao: Arc<ConversationDao>,
        event_bus: Arc<EventBus>,
    ) -> Self {
        Self {
            message_dao,
            conversation_dao,
            event_bus,
            user_id: std::sync::Mutex::new(String::new()),
            max_seq_recorder: Arc::new(MaxSeqRecorder::new()),
        }
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

    pub async fn handle_messages(&self, messages: Vec<ReceivedMessage>) -> Result<()> {
        self.handle_messages_internal(messages, false).await
    }

    /// 处理消息列表（标记为同步来源，会触发 RecvOfflineNewMessage 事件）
    ///
    /// 对齐 Go SDK `OnRecvOfflineNewMessage`：在同步过程中收到的消息
    /// 需要额外通知上层 UI 这些是离线期间积累的消息。
    pub async fn handle_sync_messages(&self, messages: Vec<ReceivedMessage>) -> Result<()> {
        self.handle_messages_internal(messages, true).await
    }

    async fn handle_messages_internal(&self, messages: Vec<ReceivedMessage>, is_from_sync: bool) -> Result<()> {
        if messages.is_empty() {
            return Ok(());
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

        // 过滤掉已读回执，只处理普通消息
        let normal_messages: Vec<ReceivedMessage> = messages.into_iter()
            .filter(|m| m.content_type != HAS_READ_RECEIPT)
            .collect();

        if normal_messages.is_empty() {
            return Ok(());
        }

        // 处理 Typing 消息：发布输入状态变化事件（对齐 Go SDK OnConversationUserInputStatusChanged）
        for msg in &normal_messages {
            if msg.content_type == content_type::TYPING {
                if let Ok(typing_elem) = serde_json::from_str::<TypingElem>(&msg.content) {
                    let platform_id = msg.sender_platform_id;
                    let is_typing = typing_elem.msg_tips == "yes";
                    self.event_bus.publish(SdkEvent::ConversationUserInputStatusChanged {
                        data: crate::domain::event::types::InputStatusChangedData {
                            conversation_id: msg.conversation_id.clone(),
                            user_id: msg.send_id.clone(),
                            platform_ids: if is_typing { vec![platform_id] } else { vec![] },
                        },
                    });
                }
            }
        }

        // typing 消息已处理完事件，从 normal_messages 中移除，避免入库和触发 NewMessage 事件
        let normal_messages: Vec<ReceivedMessage> = normal_messages.into_iter()
            .filter(|m| m.content_type != content_type::TYPING)
            .collect();

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
                    } else {
                        // CLIENT_DUP: client_msg_id 重复
                        if is_store {
                            let mut local_msg: LocalChatLog = self.received_to_local(msg);
                            self.handle_exception_messages(Some(existing), &mut local_msg);
                            insert_list.push(local_msg);
                        }
                    }
                } else {
                    // 本端同步自己发的消息
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
                    // CLIENT_DUP: 重复消息
                    if is_store {
                        let existing_ref = exists.unwrap();
                        let mut local_msg: LocalChatLog = self.received_to_local(msg);
                        self.handle_exception_messages(Some(existing_ref), &mut local_msg);
                        insert_list.push(local_msg);
                    }
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
        for msg in &to_notify {
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

            // 每条新消息都增加未读数（对齐 Go SDK：每条消息独立计数）
            // online_only 消息不增加未读数（对齐 Go SDK：RecvOnlineOnlyMessage）
            if is_conversation_update && !is_self && !msg.is_online_only {
                debug!("[UNREAD_DIAG] 增加未读: conv={}, seq={}, send_id={}", msg.conversation_id, msg.seq, msg.send_id);
                self.conversation_dao
                    .update_after_new_message(
                        &msg.conversation_id,
                        &msg.content,
                        msg.send_time,
                        msg.seq,
                    )
                    .await?;
            }

            if msg.content_type != content_type::TYPING {
                self.event_bus.publish(SdkEvent::NewMessage {
                    message: msg.clone(),
                });
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
        // 同步过程中收到的消息需要额外通知上层 UI
        if is_from_sync && !to_notify.is_empty() {
            let offline_msgs: Vec<ReceivedMessage> = to_notify.into_iter()
                .filter(|m| m.send_id != login_user_id && m.content_type != content_type::TYPING)
                .collect();
            if !offline_msgs.is_empty() {
                self.event_bus.publish(SdkEvent::RecvOfflineNewMessage {
                    messages: offline_msgs,
                });
            }
        }

        Ok(())
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
                        if m.is_read == 0 && m.send_id != login_user_id {
                            m.is_read = 1;
                            // 更新本地 DB（设置 is_read = 1）
                            self.message_dao.mark_as_read_by_seqs(
                                &tips.conversation_id,
                                &[m.seq],
                                &login_user_id,
                            ).await?;
                            updated_client_msg_ids.push(m.client_msg_id.clone());
                        }
                    }

                    // 发布 C2C 已读回执事件（对齐 Go SDK OnRecvC2CReadReceipt）
                    if !updated_client_msg_ids.is_empty() {
                        self.event_bus.publish(SdkEvent::C2CReadReceipt {
                            receipts: vec![MessageReceipt {
                                user_id: tips.mark_as_read_user_id.clone(),
                                msg_ids: updated_client_msg_ids,
                                read_time: tips.has_read_seq, // 使用 hasReadSeq 作为 read_time
                                session_type: session_type_val,
                            }],
                        });
                    }
                }
            } else if session_type_val == session_type::WRITE_GROUP_CHAT
                || session_type_val == session_type::READ_GROUP_CHAT
            {
                // 群聊：发布群已读回执事件（对齐 Go SDK OnRecvGroupReadReceipt）
                self.event_bus.publish(SdkEvent::GroupReadReceipt {
                    receipts: vec![GroupReadReceipt {
                        group_id: tips.conversation_id.clone(),
                        msg_id: tips.seqs.first().map(|s| s.to_string()).unwrap_or_default(),
                        has_read_user_id_list: vec![tips.mark_as_read_user_id.clone()],
                        has_read_count: tips.seqs.len() as i32,
                        group_member_count: 0, // 服务端未提供，需上层查询
                        read_time: tips.has_read_seq,
                    }],
                });
            }

            // 重算未读数（对齐 Go SDK doUnreadCount）
            self.do_unread_count(
                &tips.conversation_id,
                session_type_val,
                tips.has_read_seq,
                &tips.seqs,
            ).await?;

        } else {
            // 自己的已读回执（其他设备同步过来的，对齐 Go SDK L282-284）
            // 直接将会话未读数清零
            self.conversation_dao.update_unread_count(&tips.conversation_id, 0).await?;

            // 发布事件
            let _ = self.event_bus.publish(SdkEvent::ConversationChanged {
                conversations: Vec::new(),
            });
            if let Ok(total) = self.conversation_dao.get_total_unread_count().await {
                let _ = self.event_bus.publish(SdkEvent::TotalUnreadCountChanged { count: total });
            }
        }

        debug!("处理已读回执: conversation_id={}, seqs={}, has_read_seq={}",
            tips.conversation_id, tips.seqs.len(), tips.has_read_seq);
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

        // 发布会话变更 + 全局未读数变更事件（对齐 Go SDK L215-223）
        if let Ok(Some(conv)) = self.conversation_dao.get_by_id(conversation_id).await {
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
            let _ = self.event_bus.publish(SdkEvent::ConversationChanged {
                conversations: vec![conversation],
            });
        }

        if let Ok(total) = self.conversation_dao.get_total_unread_count().await {
            let _ = self.event_bus.publish(SdkEvent::TotalUnreadCountChanged { count: total });
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

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
        let conversation_dao = Arc::new(ConversationDao::new(pool));
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(message_dao, conversation_dao, event_bus);

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
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(message_dao, conversation_dao, event_bus);

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
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(message_dao.clone(), conversation_dao.clone(), event_bus);

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
        let event_bus = Arc::new(EventBus::new());
        let mut sub = event_bus.subscribe();
        let handler = MessageHandler::new(message_dao.clone(), conversation_dao.clone(), event_bus);

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
        let event_bus = Arc::new(EventBus::new());
        let handler = MessageHandler::new(message_dao.clone(), conversation_dao.clone(), event_bus);

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

    #[tokio::test]
    async fn test_no_trigger_conv_stored_but_no_conv_update() {
        let pool = create_pool_memory().await.unwrap();
        let message_dao = Arc::new(MessageDao::new(pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(pool.clone()));
        let event_bus = Arc::new(EventBus::new());
        let mut sub = event_bus.subscribe();
        let handler = MessageHandler::new(message_dao.clone(), conversation_dao.clone(), event_bus);

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
