use std::collections::HashMap;

use anyhow::Result;
use futures_util::StreamExt;
use log::info;
use openim_protocol::{constant, sdkws, Message as ProtobufMessage};
use serde_json;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tracing::{debug, error, warn};

use crate::im::model::{msg_type, OpenIMResp};
use crate::im::serialization::decompress_gzip;
use crate::im::LocalChatLog;
use crate::LocalConversation;

use super::OpenIMClient;
use crate::im::client::client::WsReader;

/// 消息处理结果集合
struct MessageProcessingResult {
    insert_msg: HashMap<String, Vec<LocalChatLog>>,
    update_msg: HashMap<String, Vec<LocalChatLog>>,
    new_messages: Vec<sdkws::MsgData>,
    conversation_set: HashMap<String, LocalConversation>,
}

impl MessageProcessingResult {
    fn new() -> Self {
        Self {
            insert_msg: HashMap::new(),
            update_msg: HashMap::new(),
            new_messages: Vec::new(),
            conversation_set: HashMap::new(),
        }
    }
}

struct ConversationProcessingResult {
    insert_msg: Vec<LocalChatLog>,
    update_msg: Vec<LocalChatLog>,
    new_messages: Vec<sdkws::MsgData>,
    conversation: LocalConversation,
}

impl ConversationProcessingResult {
    fn new() -> Self {
        Self {
            insert_msg: Vec::new(),
            update_msg: Vec::new(),
            new_messages: Vec::new(),
            conversation: LocalConversation::default(),
        }
    }
}

/// 消息选项
struct MessageOptions {
    is_history: bool,
    is_unread_count: bool,
    is_conversation_update: bool,
    is_sender_conversation_update: bool,
}

impl MessageOptions {
    fn from_msg(msg: &sdkws::MsgData) -> Self {
        Self {
            is_history: Self::get_switch_from_options(&msg.options, "history"),
            is_unread_count: Self::get_switch_from_options(&msg.options, "unreadCount"),
            is_conversation_update: Self::get_switch_from_options(
                &msg.options,
                "conversationUpdate",
            ),
            is_sender_conversation_update: Self::get_switch_from_options(
                &msg.options,
                "senderConversationUpdate",
            ),
        }
    }

    fn get_switch_from_options(options: &HashMap<String, bool>, key: &str) -> bool {
        options.get(key).copied().unwrap_or(false)
    }
}

impl OpenIMClient {
    /// 处理接收消息（事件循环）
    pub(crate) async fn handle_messages(&self, mut read: WsReader) -> Result<()> {
        while let Some(msg_result) = read.next().await {
            match msg_result {
                Ok(WsMessage::Text(text)) => {
                    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text) {
                        if let Some(req_id) = json.get("reqIdentifier") {
                            debug!("[Client] 文本响应: reqId={}", req_id);
                        }
                    }
                }
                Ok(WsMessage::Binary(data)) => {
                    if let Err(e) = self.handle_binary_message(data).await {
                        error!("[Client] handle_binary_message 处理二进制消息失败: {}", e);
                    }
                }
                Ok(WsMessage::Ping(_)) | Ok(WsMessage::Pong(_)) => {}
                Ok(WsMessage::Close(frame)) => {
                    warn!("[Client] 👋 连接关闭: {:?}", frame);
                    break;
                }
                Err(e) => {
                    error!("[Client] WebSocket 错误: {}", e);
                    break;
                }
                _ => {}
            }
        }
        Ok(())
    }

    async fn handle_binary_message(&self, data: Vec<u8>) -> Result<()> {
        let decompressed = if data.len() >= 2 && data[0] == 0x1f && data[1] == 0x8b {
            match decompress_gzip(&data) {
                Ok(d) => d,
                Err(e) => {
                    return Err(anyhow::anyhow!("解压失败: {}", e));
                }
            }
        } else {
            data
        };

        let resp = serde_json::from_slice::<OpenIMResp>(&decompressed)?;

        match resp.req_identifier {
            crate::im::model::msg_type::WS_GET_NEWEST_SEQ
            | crate::im::model::msg_type::WS_PULL_MSG_BY_RANGE
            | crate::im::model::msg_type::WS_PULL_MSG_BY_SEQ_LIST
            | crate::im::model::msg_type::WS_SEND_MSG
            | crate::im::model::msg_type::WS_SEND_MSG_NOT_OSS => {
                self.handle_rpc_response(resp).await?
            }

            msg_type::WS_PUSH_MSG => self.handle_push_message(&resp.data).await?,
            msg_type::WS_KICK_ONLINE_MSG => {
                warn!("[Client] ⚠️ 被踢下线");
                let listener = self.advanced_msg_listener.clone();
                tokio::spawn(async move {
                    if let Some(listener) = &listener {
                        listener.on_kicked_offline().await;
                    }
                });
            }
            _ => {
                debug!("[Client] 未知消息类型: {}", resp.req_identifier);
            }
        }
        Ok(())
    }

    async fn handle_push_message(&self, data: &[u8]) -> Result<()> {
        if data.is_empty() {
            return Err(anyhow::anyhow!("推送消息为空"));
        }

        let push_msg = match sdkws::PushMessages::decode(data) {
            Ok(pm) => pm,
            Err(e) => {
                return Err(anyhow::anyhow!("Protobuf 解析失败: {}", e));
            }
        };

        let mut all_msgs: HashMap<String, Vec<&sdkws::MsgData>> = HashMap::new();

        for (conv_id, pull_msgs) in &push_msg.msgs {
            for msg in &pull_msgs.msgs {
                if self.is_duplicate_message(&msg.client_msg_id) {
                    continue;
                }
                all_msgs.entry(conv_id.clone()).or_default().push(msg);
            }
        }

        for (conv_id, pull_msgs) in &push_msg.notification_msgs {
            for msg in &pull_msgs.msgs {
                if self.is_duplicate_message(&msg.client_msg_id) {
                    continue;
                }
                all_msgs.entry(conv_id.clone()).or_default().push(msg);
            }
        }

        if !all_msgs.is_empty() {
            self.handle_new_message(all_msgs).await?;
        }
        Ok(())
    }

    /// 处理推送消息，分类决定插入/更新/会话更新/回调
    pub(crate) async fn handle_new_message(
        &self,
        all_msgs: HashMap<String, Vec<&sdkws::MsgData>>,
    ) -> Result<()> {
        let mut processing_result = MessageProcessingResult::new();

        for (conversation_id, msgs) in all_msgs {
            if conversation_id.is_empty() {
                warn!("[Client] conversationID 为空，跳过消息");
                continue;
            }
            let conversation_result = self
                .process_conversation_messages(&conversation_id, msgs)
                .await?;
            processing_result.conversation_set.insert(
                conversation_id.to_string(),
                conversation_result.conversation,
            );
            processing_result
                .insert_msg
                .entry(conversation_id.to_string())
                .or_default()
                .extend(conversation_result.insert_msg);
            processing_result
                .update_msg
                .entry(conversation_id.to_string())
                .or_default()
                .extend(conversation_result.update_msg);
            processing_result
                .new_messages
                .extend(conversation_result.new_messages);
        }
        self.persist_and_notify(processing_result).await?;
        Ok(())
    }
    /// 处理单个会话的所有消息
    async fn process_conversation_messages(
        &self,
        conversation_id: &str,
        msgs: Vec<&sdkws::MsgData>,
    ) -> Result<ConversationProcessingResult> {
        let mut result = ConversationProcessingResult::new();

        for msg in msgs {
            let options = MessageOptions::from_msg(msg);
            // 处理删除消息
            if msg.status == constant::MSG_STATUS_HAS_DELETED {
                let db_message = Self::msg_data_to_local_chat_log(msg, conversation_id);
                result.insert_msg.push(db_message.clone());
                result.insert_msg.push(db_message);
                continue;
            }
            let conversation_result = self.process_message(conversation_id, msg, &options).await?;
            result.insert_msg.extend(conversation_result.insert_msg);
            result.update_msg.extend(conversation_result.update_msg);
            result.new_messages.extend(conversation_result.new_messages);
            result.conversation = conversation_result.conversation;
        }

        Ok(result)
    }

    /// 处理消息（统一处理自己发送和他人发送的消息）
    async fn process_message(
        &self,
        conversation_id: &str,
        msg: &sdkws::MsgData,
        options: &MessageOptions,
    ) -> Result<ConversationProcessingResult> {
        let mut result = ConversationProcessingResult::new();
        let is_from_me = msg.send_id == self.config.user_id;
        if let Ok(Some(existing_msg)) = self
            .message_store
            .as_ref()
            .unwrap()
            .get_by_client_msg_id(conversation_id, &msg.client_msg_id)
            .await
        {
            // 已存在的消息处理
            if msg.send_id == self.config.user_id {
                // 自己发送的消息：seq==0 需要更新，否则插入
                if existing_msg.seq == 0 {
                    result
                        .update_msg
                        .push(Self::msg_data_to_local_chat_log(msg, conversation_id));
                } else {
                    result
                        .insert_msg
                        .push(Self::msg_data_to_local_chat_log(msg, conversation_id));
                }
            } else {
                // 他人发送的消息：直接覆盖插入
                result
                    .insert_msg
                    .push(Self::msg_data_to_local_chat_log(msg, conversation_id));
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
                if is_from_me {
                    &mut result
                        .insert_msg
                        .push(Self::msg_data_to_local_chat_log(msg, conversation_id));
                } else {
                    &mut result
                        .insert_msg
                        .push(Self::msg_data_to_local_chat_log(msg, conversation_id));
                };
            }
        }

        Ok(result)
    }

    /// 为自己发送的消息创建会话对象
    fn create_conversation_for_self(
        msg: &sdkws::MsgData,
        conversation_id: &str,
    ) -> LocalConversation {
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
    fn create_conversation_for_others(
        msg: &sdkws::MsgData,
        conversation_id: &str,
    ) -> LocalConversation {
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
        let store = self.message_store.clone().unwrap();
        // 批量更新消息
        for (conversation_id, messages) in result.update_msg {
            for msg in messages {
                if let Err(e) = store.update_message(&conversation_id, &msg).await {
                    error!(
                        "[Client] 更新消息失败 conversationID={} clientMsgID={}: {}",
                        conversation_id, msg.client_msg_id, e
                    );
                }
            }
        }

        // 批量插入消息
        for (conversation_id, messages) in result.insert_msg {
            if let Err(e) = store
                .batch_insert_message_list(&conversation_id, &messages)
                .await
            {
                error!(
                    "[Client] 批量插入消息失败 conversationID={}: {}",
                    conversation_id, e
                );
            }
        }

        // 触发新消息回调
        for msg in result.new_messages {
            let msg_json = serde_json::to_string(&msg).unwrap_or_default();
            let listener = self.advanced_msg_listener.clone();
            tokio::spawn(async move {
                if let Some(listener) = &listener {
                    listener.on_recv_new_message(msg_json).await;
                }
            });
        }

        Ok(())
    }

    pub(crate) fn is_duplicate_message(&self, msg_id: &str) -> bool {
        let mut set = self.received_msg_ids.lock().unwrap();
        !set.insert(msg_id.to_string())
    }

    fn msg_data_to_local_chat_log(msg: &sdkws::MsgData, conversation_id: &str) -> LocalChatLog {
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

    pub(crate) fn msg_data_to_json(&self, msg: &sdkws::MsgData) -> String {
        serde_json::to_string(msg).unwrap_or_else(|_| "{}".to_string())
    }
}
