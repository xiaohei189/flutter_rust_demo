use std::collections::HashMap;

use anyhow::Result;
use futures_util::StreamExt;
use log::info;
use openim_protocol::{Message as ProtobufMessage, constant, sdkws};
use serde_json;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tracing::{debug, error, warn};

use crate::LocalConversation;
use crate::im::model::{msg_type, OpenIMResp};
use crate::im::serialization::decompress_gzip;
use crate::im::{LocalChatLog, MsgStruct};

use super::OpenIMClient;
use crate::im::client::client::WsReader;

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
                    info!("handle_binary_message");
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

        info!("receive message: push_msg: {:?}", push_msg);
        let mut all_msgs: HashMap<String, Vec<&sdkws::MsgData>> = HashMap::new();

        for (conv_id, pull_msgs) in &push_msg.msgs {
            for msg in &pull_msgs.msgs {
                if self.is_duplicate_message(&msg.client_msg_id) {
                    continue;
                }
                all_msgs
                    .entry(conv_id.clone())
                    .or_insert_with(Vec::new)
                    .push(msg);
            }
        }

        for (conv_id, pull_msgs) in &push_msg.notification_msgs {
            for msg in &pull_msgs.msgs {
                if self.is_duplicate_message(&msg.client_msg_id) {
                    continue;
                }
                all_msgs
                    .entry(conv_id.clone())
                    .or_insert_with(Vec::new)
                    .push(msg);
            }
        }

        if !all_msgs.is_empty() {
            self.do_msg_new(all_msgs)
                .await
                .map_err(|e| anyhow::anyhow!("do_msg_new 处理消息失败: {}", e))?;
        }
        Ok(())
    }

    // do_msg_new 等实现留在 client.rs

    /// 处理推送消息，分类决定插入/更新/会话更新/回调
    ///
    /// 流程概览（与 Go SDK 对齐的分类逻辑）：
    /// 1) 按会话聚合 -> 每条消息读 `options`：`history`/`unreadCount`/`conversationUpdate`/`senderConversationUpdate`
    /// 2) 去重：`is_duplicate_message` 基于 `clientMsgID`
    /// 3) 删除：`status == MSG_STATUS_HAS_DELETED` 直接 INSERT OR REPLACE 写库，跳过后续分支
    /// 4) 自发：库里有且 `seq==0` → update（占位补全）；否则 insert。`history` 另存自发历史集合
    /// 5) 他发：库里有 → 覆盖插入；库里无 → 先建会话占位（单聊填 user_id，群聊填 group_id），`unreadCount` 决定未读=1，`history` 另存他发历史集合
    /// 6) 会话更新：`conversationUpdate` / `senderConversationUpdate` 为真时，将会话放入 `conversation_set`，并把对应 `msg_struct` 记录到 `new_messages`
    /// 7) 落库与回调：`update_message`（seq==0 补全）-> `batch_insert_message_list`（幂等插入）-> `new_messages` 异步回调 `on_recv_new_message`
    /// 
    
    pub(crate) async fn do_msg_new(
        &self,
        all_msgs: HashMap<String, Vec<&sdkws::MsgData>>,
    ) -> Result<()> {
        let store = self
            .message_store
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("消息存储未初始化"))?;

        let mut insert_msg: HashMap<String, Vec<LocalChatLog>> = HashMap::new();
        let mut update_msg: HashMap<String, Vec<LocalChatLog>> = HashMap::new();
        let mut new_messages: Vec<MsgStruct> = Vec::new();
        let mut conversation_set: HashMap<String, LocalConversation> = HashMap::new();

        for (conversation_id, msgs) in all_msgs {
            if conversation_id.is_empty() {
                warn!("[Client] conversationID 为空，跳过消息");
                continue;
            }

            let mut insert_message: Vec<LocalChatLog> = Vec::new();
            let mut self_insert_message: Vec<LocalChatLog> = Vec::new();
            let mut others_insert_message: Vec<LocalChatLog> = Vec::new();
            let mut update_message: Vec<LocalChatLog> = Vec::new();

            for msg in msgs {
                // 对齐 Go SDK 的 options 语义：
                // - history: 补拉/历史消息（不一定影响未读，主要用于落库，不走实时提示）
                // - unreadCount: 是否计入未读（实时推送通常为 true，历史补拉可能为 false）
                // - conversationUpdate: 推动会话摘要/最新消息/未读等更新
                // - senderConversationUpdate: 发送端是否也需要会话更新（自发消息时使用）
                let is_history = Self::get_switch_from_options(&msg.options, "history");
                let is_unread_count = Self::get_switch_from_options(&msg.options, "unreadCount");
                let is_conversation_update =
                    Self::get_switch_from_options(&msg.options, "conversationUpdate");
                let is_sender_conversation_update =
                    Self::get_switch_from_options(&msg.options, "senderConversationUpdate");

                if msg.status == constant::MSG_STATUS_HAS_DELETED {
                    let db_message = Self::msg_data_to_local_chat_log(msg, &conversation_id);
                    insert_message.push(db_message.clone());
                    insert_message.push(db_message);
                    continue;
                }

                if !self.handle_single_message(&conversation_id, msg, false).await {
                    continue;
                }

                let mut msg_struct = self.msg_data_to_msg_struct(msg);
                msg_struct.status = constant::MSG_STATUS_SEND_SUCCESS;

                let is_from_me = msg.send_id == self.config.user_id;

                if is_from_me {
                    if let Ok(Some(existing_msg)) = store
                        .get_by_client_msg_id(&conversation_id, &msg.client_msg_id)
                        .await
                    {
                        if existing_msg.seq == 0 {
                            if !is_conversation_update {
                                msg_struct.status = constant::MSG_STATUS_FILTERED;
                            }
                            update_message
                                .push(Self::msg_data_to_local_chat_log(msg, &conversation_id));
                        } else {
                            let db_message =
                                Self::msg_data_to_local_chat_log(msg, &conversation_id);
                            insert_message.push(db_message);
                        }
                    } else {
                        let mut lc = LocalConversation {
                            conversation_type: msg.session_type,
                            latest_msg: serde_json::to_string(&msg_struct).unwrap_or_default(),
                            latest_msg_send_time: msg.send_time,
                            conversation_id: conversation_id.clone(),
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
                        };

                        match msg.session_type {
                            constant::SINGLE_CHAT_TYPE => {
                                lc.user_id = msg.recv_id.clone();
                            }
                            constant::WRITE_GROUP_CHAT_TYPE | constant::READ_GROUP_CHAT_TYPE => {
                                lc.group_id = msg.group_id.clone();
                            }
                            _ => {}
                        }

                        if is_conversation_update && is_sender_conversation_update {
                            conversation_set.insert(conversation_id.clone(), lc.clone());
                        }

                        // 对齐 Go：自发实时消息（非 history）也推送回调
                        if !is_history {
                            new_messages.push(msg_struct.clone());
                        }

                        if is_history {
                            self_insert_message
                                .push(Self::msg_data_to_local_chat_log(msg, &conversation_id));
                        }
                    }
                } else {
                    if let Ok(Some(_existing_msg)) = store
                        .get_by_client_msg_id(&conversation_id, &msg.client_msg_id)
                        .await
                    {
                        let db_message = Self::msg_data_to_local_chat_log(msg, &conversation_id);
                        insert_message.push(db_message);
                    } else {
                        let mut lc = LocalConversation {
                            conversation_type: msg.session_type,
                            latest_msg: serde_json::to_string(&msg_struct).unwrap_or_default(),
                            latest_msg_send_time: msg.send_time,
                            conversation_id: conversation_id.clone(),
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
                        };

                        match msg.session_type {
                            constant::SINGLE_CHAT_TYPE => {
                                lc.user_id = msg.send_id.clone();
                                lc.show_name = msg.sender_nickname.clone();
                                lc.face_url = msg.sender_face_url.clone();
                            }
                            constant::WRITE_GROUP_CHAT_TYPE | constant::READ_GROUP_CHAT_TYPE => {
                                lc.group_id = msg.group_id.clone();
                            }
                            constant::NOTIFICATION_CHAT_TYPE => {
                                lc.user_id = msg.send_id.clone();
                            }
                            _ => {}
                        }

                        if is_unread_count {
                            // Go 版：未读计数按开关累加；这里最少保证新会话初始未读为 1
                            lc.unread_count = lc.unread_count.saturating_add(1);
                        }

                        if is_conversation_update {
                            conversation_set.insert(conversation_id.clone(), lc.clone());
                        }

                        // 对齐 Go：他发实时消息（非 history）推送回调
                        if !is_history {
                            new_messages.push(msg_struct.clone());
                        }

                        if is_history {
                            others_insert_message
                                .push(Self::msg_data_to_local_chat_log(msg, &conversation_id));
                        }
                    }
                }
            }

            let mut all_insert = insert_message;
            all_insert.extend(self_insert_message);
            all_insert.extend(others_insert_message);
            if !all_insert.is_empty() {
                insert_msg.insert(conversation_id.clone(), all_insert);
            }
            if !update_message.is_empty() {
                update_msg.insert(conversation_id, update_message);
            }
        }
        info!("receive message: update_msg: {:?}", update_msg);
        info!("receive message: insert_msg: {:?}", insert_msg);
        info!("receive message: new_messages: {:?}", new_messages);

        for (conversation_id, messages) in update_msg {
            for msg in messages {
                if let Err(e) = store.update_message(&conversation_id, &msg).await {
                    error!(
                        "[Client] 更新消息失败 conversationID={} clientMsgID={}: {}",
                        conversation_id, msg.client_msg_id, e
                    );
                }
            }
        }

        for (conversation_id, messages) in insert_msg {
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

        for msg_struct in new_messages {
            let msg_json = serde_json::to_string(&msg_struct).unwrap_or_default();
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

    fn get_switch_from_options(options: &HashMap<String, bool>, key: &str) -> bool {
        options.get(key).copied().unwrap_or(false)
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

    pub(crate) fn msg_data_to_msg_struct(&self, msg: &sdkws::MsgData) -> MsgStruct {
        MsgStruct {
            client_msg_id: Some(msg.client_msg_id.clone()),
            server_msg_id: Some(msg.server_msg_id.clone()),
            create_time: msg.create_time,
            send_time: msg.send_time,
            session_type: msg.session_type,
            send_id: Some(msg.send_id.clone()),
            recv_id: Some(msg.recv_id.clone()),
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            sender_platform_id: msg.sender_platform_id,
            sender_nickname: Some(msg.sender_nickname.clone()),
            sender_face_url: Some(msg.sender_face_url.clone()),
            group_id: if !msg.group_id.is_empty() {
                Some(msg.group_id.clone())
            } else {
                None
            },
            content: Some(String::from_utf8_lossy(&msg.content).to_string()),
            seq: msg.seq,
            is_read: msg.is_read,
            status: msg.status,
            is_react: None,
            is_external_extensions: None,
            offline_push: None,
            attached_info: Some(msg.attached_info.clone()),
            ex: Some(msg.ex.clone()),
            local_ex: None,
            text_elem: None,
            picture_elem: None,
            sound_elem: None,
            video_elem: None,
            file_elem: None,
            at_text_elem: None,
            location_elem: None,
            custom_elem: None,
            quote_elem: None,
        }
    }

    pub(crate) fn msg_data_to_json(&self, msg: &sdkws::MsgData) -> String {
        let msg_struct = self.msg_data_to_msg_struct(msg);
        serde_json::to_string(&msg_struct).unwrap_or_else(|_| "{}".to_string())
    }
}
