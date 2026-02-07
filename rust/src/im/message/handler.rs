//! 消息处理器模块
//!
//! 负责处理接收到的消息，包括消息分类、存储、会话更新和回调触发

use std::collections::HashMap;

use anyhow::Result;
use openim_protocol::{constant, sdkws};
use serde_json;
use tracing::{error, warn};

use crate::im::dao::MessageRepo;
use crate::im::listener::AdvancedMsgListener;
use crate::im::LocalChatLog;
use crate::LocalConversation;
use std::sync::Arc;

/// 消息处理结果集合
#[derive(Clone)]
pub struct MessageProcessingResult {
    pub insert_msg: HashMap<String, Vec<LocalChatLog>>,
    pub update_msg: HashMap<String, Vec<LocalChatLog>>,
    pub new_messages: Vec<sdkws::MsgData>,
    pub conversation_set: HashMap<String, LocalConversation>,
}

impl Default for MessageProcessingResult {
    fn default() -> Self {
        Self::new()
    }
}

impl MessageProcessingResult {
    pub fn new() -> Self {
        Self {
            insert_msg: HashMap::new(),
            update_msg: HashMap::new(),
            new_messages: Vec::new(),
            conversation_set: HashMap::new(),
        }
    }
}

/// 会话处理结果
pub struct ConversationProcessingResult {
    pub insert_msg: Vec<LocalChatLog>,
    pub update_msg: Vec<LocalChatLog>,
    pub new_messages: Vec<sdkws::MsgData>,
    pub conversation: LocalConversation,
}

impl Default for ConversationProcessingResult {
    fn default() -> Self {
        Self::new()
    }
}

impl ConversationProcessingResult {
    pub fn new() -> Self {
        Self {
            insert_msg: Vec::new(),
            update_msg: Vec::new(),
            new_messages: Vec::new(),
            conversation: LocalConversation::default(),
        }
    }
}

/// 消息选项
pub struct MessageOptions {
    pub is_history: bool,
    pub is_unread_count: bool,
    pub is_conversation_update: bool,
    pub is_sender_conversation_update: bool,
}

impl MessageOptions {
    pub fn from_msg(msg: &sdkws::MsgData) -> Self {
        Self {
            is_history: Self::get_switch_from_options(&msg.options, "history"),
            is_unread_count: Self::get_switch_from_options(&msg.options, "unreadCount"),
            is_conversation_update: Self::get_switch_from_options(&msg.options, "conversationUpdate"),
            is_sender_conversation_update: Self::get_switch_from_options(&msg.options, "senderConversationUpdate"),
        }
    }

    fn get_switch_from_options(options: &HashMap<String, bool>, key: &str) -> bool {
        options.get(key).copied().unwrap_or(false)
    }
}

/// 消息处理器上下文
pub struct MessageHandlerContext {
    pub user_id: String,
    pub message_store: Arc<MessageRepo>,
    pub advanced_msg_listener: Option<Arc<dyn AdvancedMsgListener>>,
}

impl MessageHandlerContext {
    pub fn new(user_id: String, message_store: Arc<MessageRepo>, advanced_msg_listener: Option<Arc<dyn AdvancedMsgListener>>) -> Self {
        Self {
            user_id,
            message_store,
            advanced_msg_listener,
        }
    }
}

/// 消息处理器
pub struct MessageHandler {
    ctx: MessageHandlerContext,
}

impl MessageHandler {
    pub fn new(ctx: MessageHandlerContext) -> Self {
        Self { ctx }
    }

    /// 处理推送消息，分类决定插入/更新/会话更新/回调
    pub async fn handle_new_message(&self, all_msgs: HashMap<String, Vec<sdkws::MsgData>>) -> Result<MessageProcessingResult> {
        let mut processing_result = MessageProcessingResult::new();

        for (conversation_id, msgs) in all_msgs {
            if conversation_id.is_empty() {
                warn!("[MessageHandler] conversationID 为空，跳过消息");
                continue;
            }
            let conversation_result = self.process_conversation_messages(&conversation_id, msgs).await?;
            processing_result.conversation_set.insert(conversation_id.to_string(), conversation_result.conversation);
            processing_result.insert_msg.entry(conversation_id.to_string()).or_default().extend(conversation_result.insert_msg);
            processing_result.update_msg.entry(conversation_id.to_string()).or_default().extend(conversation_result.update_msg);
            processing_result.new_messages.extend(conversation_result.new_messages);
        }
        let result = processing_result.clone();
        self.persist_and_notify(processing_result).await?;
        Ok(result)
    }

    /// 处理单个会话的所有消息
    async fn process_conversation_messages(&self, conversation_id: &str, msgs: Vec<sdkws::MsgData>) -> Result<ConversationProcessingResult> {
        let mut result = ConversationProcessingResult::new();

        for msg in msgs {
            let options = MessageOptions::from_msg(&msg);
            // 处理删除消息
            if msg.status == constant::MSG_STATUS_HAS_DELETED {
                let db_message = Self::msg_data_to_local_chat_log(&msg, conversation_id);
                result.insert_msg.push(db_message.clone());
                result.insert_msg.push(db_message);
                continue;
            }
            let conversation_result = self.process_message(conversation_id, &msg, &options).await?;
            result.insert_msg.extend(conversation_result.insert_msg);
            result.update_msg.extend(conversation_result.update_msg);
            result.new_messages.extend(conversation_result.new_messages);
            result.conversation = conversation_result.conversation;
        }

        Ok(result)
    }

    /// 处理消息（统一处理自己发送和他人发送的消息）
    async fn process_message(&self, conversation_id: &str, msg: &sdkws::MsgData, options: &MessageOptions) -> Result<ConversationProcessingResult> {
        let mut result = ConversationProcessingResult::new();
        let is_from_me = msg.send_id == self.ctx.user_id;

        if let Ok(Some(existing_msg)) = self.ctx.message_store.get_by_client_msg_id(conversation_id, &msg.client_msg_id).await {
            // 已存在的消息处理
            if is_from_me {
                // 自己发送的消息：seq==0 需要更新，否则插入
                if existing_msg.seq == 0 {
                    result.update_msg.push(Self::msg_data_to_local_chat_log(msg, conversation_id));
                } else {
                    result.insert_msg.push(Self::msg_data_to_local_chat_log(msg, conversation_id));
                }
            } else {
                // 他人发送的消息：直接覆盖插入
                result.insert_msg.push(Self::msg_data_to_local_chat_log(msg, conversation_id));
            }
        } else {
            // 新消息：创建会话并处理回调
            let mut lc = if is_from_me {
                Self::create_conversation_for_self(msg, conversation_id)
            } else {
                Self::create_conversation_for_others(msg, conversation_id)
            };

            // 设置会话类型相关字段
            match msg.session_type {
                constant::SINGLE_CHAT_TYPE => {
                    if is_from_me {
                        lc.user_id = msg.recv_id.clone();
                    } else {
                        lc.user_id = msg.send_id.clone();
                        lc.show_name = msg.sender_nickname.clone();
                        lc.face_url = msg.sender_face_url.clone();
                    }
                }
                constant::WRITE_GROUP_CHAT_TYPE | constant::READ_GROUP_CHAT_TYPE => {
                    lc.group_id = msg.group_id.clone();
                }
                constant::NOTIFICATION_CHAT_TYPE => {
                    if !is_from_me {
                        lc.user_id = msg.send_id.clone();
                    }
                }
                _ => {}
            }

            // 未读计数（仅他人发送的消息）
            if !is_from_me && options.is_unread_count {
                lc.unread_count = lc.unread_count.saturating_add(1);
            }

            // 会话更新
            let should_update_conversation = if is_from_me {
                options.is_conversation_update && options.is_sender_conversation_update
            } else {
                options.is_conversation_update
            };

            if should_update_conversation {
                result.conversation = lc.clone();
            }

            // 实时消息回调（非历史消息）
            if !options.is_history {
                result.new_messages.push(msg.clone());
            }

            // 历史消息单独存储
            if options.is_history {
                result.insert_msg.push(Self::msg_data_to_local_chat_log(msg, conversation_id));
            }
        }

        Ok(result)
    }

    /// 为自己发送的消息创建会话对象
    fn create_conversation_for_self(msg: &sdkws::MsgData, conversation_id: &str) -> LocalConversation {
        LocalConversation {
            conversation_type: msg.session_type,
            latest_msg: serde_json::to_string(msg).unwrap_or_default(),
            latest_msg_send_time: msg.send_time,
            conversation_id: conversation_id.to_string(),
            user_id: String::new(),
            group_id: String::new(),
            show_name: String::new(),
            face_url: String::new(),
            recv_msg_opt: 0,
            unread_count: 0,
            draft_text: String::new(),
            draft_text_time: 0,
            is_pinned: false,
            is_private_chat: false,
            burn_duration: 0,
            is_not_in_group: false,
            update_unread_count_time: 0,
            attached_info: String::new(),
            ex: String::new(),
            group_at_type: 0,
            max_seq: 0,
            min_seq: 0,
            is_msg_destruct: false,
            msg_destruct_time: 0,
        }
    }

    /// 为他人发送的消息创建会话对象
    fn create_conversation_for_others(msg: &sdkws::MsgData, conversation_id: &str) -> LocalConversation {
        LocalConversation {
            conversation_type: msg.session_type,
            latest_msg: serde_json::to_string(msg).unwrap_or_default(),
            latest_msg_send_time: msg.send_time,
            conversation_id: conversation_id.to_string(),
            user_id: String::new(),
            group_id: String::new(),
            show_name: String::new(),
            face_url: String::new(),
            recv_msg_opt: 0,
            unread_count: 0,
            draft_text: String::new(),
            draft_text_time: 0,
            is_pinned: false,
            is_private_chat: false,
            burn_duration: 0,
            is_not_in_group: false,
            update_unread_count_time: 0,
            attached_info: String::new(),
            ex: String::new(),
            group_at_type: 0,
            max_seq: 0,
            min_seq: 0,
            is_msg_destruct: false,
            msg_destruct_time: 0,
        }
    }

    /// 持久化消息并触发回调
    async fn persist_and_notify(&self, result: MessageProcessingResult) -> Result<()> {
        // 批量更新消息
        for (conversation_id, messages) in result.update_msg {
            for msg in messages {
                if let Err(e) = self.ctx.message_store.update_message(&conversation_id, &msg).await {
                    error!("[MessageHandler] 更新消息失败 conversationID={} clientMsgID={}: {}", conversation_id, msg.client_msg_id, e);
                }
            }
        }

        // 批量插入消息
        for (conversation_id, messages) in result.insert_msg {
            if let Err(e) = self.ctx.message_store.batch_insert_message_list(&conversation_id, &messages).await {
                error!("[MessageHandler] 批量插入消息失败 conversationID={}: {}", conversation_id, e);
            }
        }

        // 触发新消息回调
        for msg in result.new_messages {
            let msg_json = serde_json::to_string(&msg).unwrap_or_default();
            let listener = self.ctx.advanced_msg_listener.clone();
            tokio::spawn(async move {
                if let Some(listener) = &listener {
                    listener.on_recv_new_message(msg_json).await;
                }
            });
        }

        Ok(())
    }

    /// 检查是否为会话相关通知
    pub fn is_conversation_notification(msg: &sdkws::MsgData) -> bool {
        matches!(
            msg.content_type,
            constant::CONVERSATION_CHANGE_NOTIFICATION
                | constant::CONVERSATION_PRIVATE_CHAT_NOTIFICATION
                | constant::CLEAR_CONVERSATION_NOTIFICATION
                | constant::CONVERSATION_UNREAD_NOTIFICATION
                | constant::CONVERSATION_DELETE_NOTIFICATION
                | constant::HAS_READ_RECEIPT
        )
    }

    /// 将 MsgData 转换为 LocalChatLog
    pub fn msg_data_to_local_chat_log(msg: &sdkws::MsgData, conversation_id: &str) -> LocalChatLog {
        LocalChatLog {
            conversation_id: conversation_id.to_string(),
            client_msg_id: msg.client_msg_id.clone(),
            server_msg_id: msg.server_msg_id.clone(),
            send_id: msg.send_id.clone(),
            recv_id: msg.recv_id.clone(),
            sender_platform_id: msg.sender_platform_id,
            sender_nickname: msg.sender_nickname.clone(),
            sender_face_url: msg.sender_face_url.clone(),
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: String::from_utf8_lossy(&msg.content).to_string(),
            is_read: msg.is_read,
            status: msg.status,
            seq: msg.seq,
            send_time: msg.send_time,
            create_time: msg.create_time,
            attached_info: msg.attached_info.clone(),
            ex: msg.ex.clone(),
            local_ex: String::new(),
            group_id: msg.group_id.clone(),
        }
    }

    /// 将 MsgData 转换为 JSON 字符串
    pub fn msg_data_to_json(msg: &sdkws::MsgData) -> String {
        serde_json::to_string(msg).unwrap_or_else(|_| "{}".to_string())
    }

    /// 处理推送消息（WebSocket 层：解析 protobuf，收集消息并去重，委派给消息处理器）
    ///
    /// - `data`: protobuf 编码的 PushMessages 数据
    /// - `is_duplicate_message`: 消息去重检查函数
    /// - 返回: 是否需要触发会话增量同步
    pub async fn handle_push_message(&self, data: &[u8], is_duplicate_message: impl Fn(&str) -> bool) -> Result<bool> {
        use openim_protocol::Message as ProtobufMessage;

        if data.is_empty() {
            return Err(anyhow::anyhow!("推送消息为空"));
        }

        // 解析 protobuf PushMessages
        let push_msg = match sdkws::PushMessages::decode(data) {
            Ok(pm) => pm,
            Err(e) => {
                return Err(anyhow::anyhow!("Protobuf 解析失败: {}", e));
            }
        };

        // 收集消息并去重
        let mut all_msgs: HashMap<String, Vec<sdkws::MsgData>> = HashMap::new();
        let mut need_conv_sync = false;

        // 处理普通消息
        for (conv_id, pull_msgs) in &push_msg.msgs {
            for msg in &pull_msgs.msgs {
                if is_duplicate_message(&msg.client_msg_id) {
                    continue;
                }
                if Self::is_conversation_notification(msg) {
                    need_conv_sync = true;
                }
                all_msgs.entry(conv_id.clone()).or_default().push(msg.clone());
            }
        }

        // 处理通知消息
        for (conv_id, pull_msgs) in &push_msg.notification_msgs {
            for msg in &pull_msgs.msgs {
                if is_duplicate_message(&msg.client_msg_id) {
                    continue;
                }
                if Self::is_conversation_notification(msg) {
                    need_conv_sync = true;
                }
                all_msgs.entry(conv_id.clone()).or_default().push(msg.clone());
            }
        }

        // 委派给消息处理器处理业务逻辑
        if !all_msgs.is_empty() {
            self.handle_new_message(all_msgs).await?;
        }

        // 返回是否需要触发会话增量同步
        Ok(need_conv_sync)
    }
}
