use crate::domain::constant::types::{notification_type, session_type};
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::{MessageReceipt, SdkEvent};
use crate::domain::model::conversation::Conversation;
use crate::domain::listener::conversation::ConversationListener;
use crate::infra::database::{ConversationDao, MessageDao};
use crate::infra::database::models::LocalChatLog;
use crate::infra::http::routes::{DELETE_MSGS, MARK_CONVERSATION_AS_READ, MARK_MSGS_AS_READ, REVOKE_MSG};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tracing::{error, info, warn};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RevokeMessageReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "seq")]
    pub seq: i64,
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "clientMsgID")]
    pub client_msg_id: String,
    #[serde(rename = "sessionType")]
    pub session_type: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DeleteMessagesReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "clientMsgIDs")]
    pub client_msg_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MarkMessagesAsReadReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "sessionType")]
    pub session_type: i32,
    #[serde(rename = "hasReadSeq")]
    pub has_read_seq: i64,
    #[serde(rename = "seqs")]
    pub seqs: Vec<i64>,
}

/// 标记整个会话为已读的请求（对齐 Go SDK `MarkConversationAsReadReq`）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MarkConversationAsReadReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "hasReadSeq")]
    pub has_read_seq: i64,
    #[serde(rename = "seqs")]
    pub seqs: Vec<i64>,
}

/// 批量标记所有会话为已读的请求
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MarkAllConversationAsReadReq {
    #[serde(rename = "conversationIDs")]
    pub conversation_ids: Vec<String>,
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "hasReadSeqs")]
    pub has_read_seqs: Vec<i64>,
}

pub struct MessageService {
    message_dao: Arc<MessageDao>,
    conversation_dao: Arc<ConversationDao>,
    event_bus: Arc<EventBus>,
    conversation_listener: Arc<ConversationListener>,
    http_client: Arc<crate::infra::http::client::HttpApiClient>,
    user_id: Arc<std::sync::Mutex<String>>,
}

impl MessageService {
    pub fn new(
        message_dao: Arc<MessageDao>,
        conversation_dao: Arc<ConversationDao>,
        event_bus: Arc<EventBus>,
        conversation_listener: Arc<ConversationListener>,
        http_client: Arc<crate::infra::http::client::HttpApiClient>,
        user_id: String,
    ) -> Self {
        Self {
            message_dao,
            conversation_dao,
            event_bus,
            conversation_listener,
            http_client,
            user_id: Arc::new(std::sync::Mutex::new(user_id)),
        }
    }

    pub fn set_user_id(&self, user_id: String) {
        let mut uid = self.user_id.lock().unwrap();
        *uid = user_id;
    }

    /// 撤回消息（对齐 Go SDK revoke.go waitForMessageSyncSeq + revokeOneMessage）
    ///
    /// 如果 seq 为 0，从本地数据库查找；若仍未同步，等待并重试（最多 5 次，每次 2 秒）。
    pub async fn revoke_message(
        &self,
        conversation_id: String,
        seq: i64,
        client_msg_id: String,
        session_type: i32,
    ) -> Result<()> {
        let user_id = self.user_id.lock().unwrap().clone();

        // 如果 seq 为 0，从本地数据库查找（对齐 Go SDK waitForMessageSyncSeq）
        let final_seq = if seq == 0 {
            self.wait_for_message_sync_seq(&conversation_id, &client_msg_id).await?
        } else {
            seq
        };

        let req = RevokeMessageReq {
            conversation_id: conversation_id.clone(),
            seq: final_seq,
            user_id: user_id.clone(),
            client_msg_id: client_msg_id.clone(),
            session_type,
        };

        let _resp: serde_json::Value = self.http_client.post(REVOKE_MSG, &req).await?;

        // 获取原消息信息用于构建事件
        let original_msg = self.message_dao.get_by_client_msg_id(&conversation_id, &client_msg_id).await?;
        
        // 更新本地数据库：标记消息为已撤回
        self.message_dao
            .update_content_type(&conversation_id, &client_msg_id, notification_type::REVOKE)
            .await?;

        // 构建完整的 MessageRevoked 事件
        let revoke_time = chrono::Utc::now().timestamp_millis();
        let (source_message_send_time, source_message_send_id, source_message_sender_nickname) = 
            if let Some(msg) = original_msg {
                (msg.send_time, msg.send_id.clone(), msg.sender_nick_name.clone())
            } else {
                (0, String::new(), String::new())
            };

        self.event_bus.publish(SdkEvent::MessageRevoked {
            conversation_id: conversation_id.clone(),
            seq: final_seq,
            client_msg_id: client_msg_id.clone(),
            revoker_id: user_id.clone(),
            revoker_role: 0,
            revoker_nickname: String::new(),
            revoke_time,
            source_message_send_time,
            source_message_send_id,
            source_message_sender_nickname,
            session_type,
            is_admin_revoke: false,
        });

        info!("消息已撤回: conversation_id={}, seq={}", conversation_id, final_seq);
        Ok(())
    }

    /// 等待消息 seq 同步到本地数据库（对齐 Go SDK waitForMessageSyncSeq）
    ///
    /// 消息发送后 seq 可能尚未同步到本地，需要等待 sync 完成。
    /// 最多重试 5 次，每次等待 2 秒。
    async fn wait_for_message_sync_seq(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
    ) -> Result<i64> {
        for attempt in 0..5 {
            if let Ok(Some(msg)) = self.message_dao.get_by_client_msg_id(conversation_id, client_msg_id).await {
                if msg.seq > 0 {
                    return Ok(msg.seq);
                }
            }
            if attempt < 4 {
                warn!(
                    "消息 seq 尚未同步 (attempt={}), 等待重试: client_msg_id={}",
                    attempt + 1, client_msg_id
                );
                tokio::time::sleep(std::time::Duration::from_secs(2)).await;
            }
        }
        Err(SdkError::invalid_argument(format!(
            "消息 seq 未同步，无法撤回: client_msg_id={}", client_msg_id
        )))
    }

    /// 删除消息（对齐 Go SDK deleteMessage）
    ///
    /// 服务端 API 需要 seqs，从本地数据库查找。
    pub async fn delete_messages(
        &self,
        conversation_id: String,
        client_msg_ids: Vec<String>,
    ) -> Result<()> {
        // 从本地数据库查找每条消息的 seq
        let mut seqs = Vec::new();
        for client_msg_id in &client_msg_ids {
            if let Ok(Some(msg)) = self.message_dao.get_by_client_msg_id(&conversation_id, client_msg_id).await {
                if msg.seq > 0 {
                    seqs.push(msg.seq);
                }
            }
        }

        // 调用服务端 API（需要 seqs）
        use crate::infra::http::routes::DELETE_MSGS;
        #[derive(serde::Serialize)]
        struct ServerDeleteReq {
            #[serde(rename = "conversationID")]
            conversation_id: String,
            seqs: Vec<i64>,
            #[serde(rename = "userID")]
            user_id: String,
        }
        let user_id = self.user_id.lock().unwrap().clone();
        let req = ServerDeleteReq {
            conversation_id: conversation_id.clone(),
            seqs,
            user_id,
        };
        let _resp: serde_json::Value = self.http_client.post(DELETE_MSGS, &req).await?;

        // 删除本地数据库中的消息
        for client_msg_id in &client_msg_ids {
            self.message_dao.delete_by_client_msg_id(&conversation_id, client_msg_id).await?;
        }

        self.event_bus.publish(SdkEvent::MessagesDeleted {
            conversation_id: conversation_id.clone(),
            client_msg_ids: client_msg_ids.clone(),
        });

        info!("消息已删除: conversation_id={}, count={}", conversation_id, client_msg_ids.len());
        Ok(())
    }

    /// 标记会话消息已读（严格对齐 Go SDK `markConversationMessageAsRead` read_drawing.go L46-104）
    ///
    /// 流程（逐行对齐 Go SDK）：
    /// L49-56: GetConversation → UnreadCount == 0 提前返回
    /// L58-66: GetConversationPeerNormalMsgSeq + GetConversationNormalMsgSeq
    /// L67-96: switch conversation.ConversationType
    ///   SingleChat: GetUnreadMessage → getAsReadMsgMapAndList → markConversationAsReadServer → MarkConversationMessageAsReadDB
    ///   Group/Notification: markConversationAsReadServer(hasReadSeq, nil)
    /// L98-100: UpdateColumnsConversation(unread_count=0)
    /// L102: unreadChangeTrigger(peerUserMaxSeq == maxSeq)
    pub async fn mark_conversation_message_as_read(&self, conversation_id: String, _session_type: i32) -> Result<()> {
        let user_id = self.user_id.lock().unwrap().clone();

        // L49: GetConversation
        let conv = self.conversation_dao.get_by_id(&conversation_id).await?;
        let conv = conv.ok_or_else(|| SdkError::invalid_argument(format!("conversation not found: {}", conversation_id)))?;

        // L53-56: UnreadCount == 0 → 提前返回
        if conv.unread_count == 0 {
            return Ok(());
        }

        // L58: GetConversationPeerNormalMsgSeq
        let peer_user_max_seq = self.message_dao.get_peer_normal_msg_seq(&conversation_id, &user_id).await?;
        // L63: GetConversationNormalMsgSeq
        let mut max_seq = self.message_dao.get_max_seq(&conversation_id).await?;
        if max_seq == 0 {
            max_seq = self.conversation_dao.get_max_seq(&conversation_id).await?;
        }

        // L67-96: switch conversation.ConversationType（用 DB 中的会话类型，不依赖传入参数）
        match conv.conversation_type {
            st if st == session_type::SINGLE_CHAT => {
                // L69: GetUnreadMessage
                let unread_msgs = self.message_dao.get_unread_messages(&conversation_id, &user_id).await?;

                // L74/L145-160: getAsReadMsgMapAndList
                let mut msg_ids: Vec<String> = Vec::new();
                let mut seqs: Vec<i64> = Vec::new();
                for msg in &unread_msgs {
                    // 防御性二次校验（对齐 Go SDK getAsReadMsgMapAndList）
                    if msg.is_read == 0 && msg.send_id != user_id {
                        if msg.seq == 0 {
                            warn!("[READ] seq=0, skip msg={}", msg.client_msg_id);
                        } else {
                            msg_ids.push(msg.client_msg_id.clone());
                            seqs.push(msg.seq);
                        }
                    }
                }

                // L75-89: 通知服务端
                if let Err(e) = self.mark_conversation_as_read_server(&conversation_id, max_seq, &seqs).await {
                    error!("[READ] markAsReadServer FAILED: conv={} err={}", conversation_id, e);
                }

                // L86: MarkConversationMessageAsReadDB（通过 client_msg_id 逐条标记）
                if !msg_ids.is_empty() {
                    if let Err(e) = self.message_dao
                        .mark_as_read_by_client_msg_ids(&conversation_id, &msg_ids, &user_id)
                        .await
                    {
                        error!("[READ] markAsReadDB FAILED: conv={} err={}", conversation_id, e);
                    }
                }
            }
            // L91-95: ReadGroupChatType / NotificationChatType
            _ => {
                if let Err(e) = self.mark_conversation_as_read_server(&conversation_id, max_seq, &[]).await {
                    error!("[READ] markAsReadServer FAILED: conv={} err={}", conversation_id, e);
                }
            }
        }

        // L98-100: UpdateColumnsConversation(unread_count=0)
        if let Err(e) = self.conversation_dao.update_unread_count(&conversation_id, 0).await {
            error!("[READ] updateUnreadCount FAILED: conv={} err={}", conversation_id, e);
        }

        // L102: unreadChangeTrigger(peerUserMaxSeq == maxSeq)
        let latest_msg_is_read = peer_user_max_seq == max_seq;
        self.unread_change_trigger(&conversation_id, latest_msg_is_read).await;

        info!("[READ] ok conv={} max_seq={}", conversation_id, max_seq);
        Ok(())
    }

    /// 对齐 Go SDK `unreadChangeTrigger` (read_drawing.go L162-171)
    /// UpdateLatestMessageReadState（条件）+ ConChange + TotalUnreadMessageChanged
    async fn unread_change_trigger(&self, conversation_id: &str, latest_msg_is_read: bool) {
        // L163-166: latestMsgIsRead 时触发 UpdateLatestMessageReadState
        if latest_msg_is_read {
            self.event_bus.publish(SdkEvent::UpdateLatestMessageReadState {
                conversation_id: conversation_id.to_string(),
            });
        }

        // L167-168: ConChange
        let updated_conv = self.conversation_dao.get_by_id(conversation_id).await;
        if let Ok(Some(conv)) = updated_conv {
            let conversation = Conversation {
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
            self.conversation_listener.on_changed.notify(&vec![conversation]);
        }

        // L169-170: TotalUnreadMessageChanged
        let total_unread = self.conversation_dao.get_total_unread_count().await.unwrap_or(0);
        self.conversation_listener.on_total_unread_count_changed.notify(&total_unread);
        self.event_bus.publish(SdkEvent::TotalUnreadCountChanged {
            count: total_unread,
        });
    }

    /// 调用服务端 `markConversationAsRead` API（对齐 Go SDK `server_api.go` L17-22）
    async fn mark_conversation_as_read_server(
        &self,
        conversation_id: &str,
        has_read_seq: i64,
        seqs: &[i64],
    ) -> Result<()> {
        let user_id = self.user_id.lock().unwrap().clone();
        let req = MarkConversationAsReadReq {
            user_id,
            conversation_id: conversation_id.to_string(),
            has_read_seq,
            seqs: seqs.to_vec(),
        };
        let _resp: serde_json::Value = self.http_client.post(MARK_CONVERSATION_AS_READ, &req).await?;
        Ok(())
    }

    /// 标记消息已读（按 seq 列表，对齐 Go SDK `markMsgAsRead2Server`）
    pub async fn mark_messages_as_read(
        &self,
        conversation_id: String,
        session_type: i32,
        has_read_seq: i64,
        seqs: Vec<i64>,
    ) -> Result<()> {
        let user_id = self.user_id.lock().unwrap().clone();
        
        let req = MarkMessagesAsReadReq {
            conversation_id: conversation_id.clone(),
            user_id: user_id.clone(),
            session_type,
            has_read_seq,
            seqs: seqs.clone(),
        };

        let _resp: serde_json::Value = self.http_client.post(MARK_MSGS_AS_READ, &req).await?;

        // 更新本地数据库：标记消息为已读（排除自己发的）
        if !seqs.is_empty() {
            self.message_dao.mark_as_read_by_seqs(&conversation_id, &seqs, &user_id).await?;
        }

        info!("消息已标记为已读: conversation_id={}, seq_count={}", conversation_id, seqs.len());
        Ok(())
    }

    /// 标记所有会话消息已读（对齐 Go SDK `MarkAllConversationMessageAsRead`）
    ///
    /// 遍历所有未读会话，逐个调用 `mark_conversation_message_as_read` 标记已读
    pub async fn mark_all_conversation_as_read(&self) -> Result<()> {
        let conversations = self.conversation_dao.get_all().await?;
        let user_id = self.user_id.lock().unwrap().clone();

        for conv in &conversations {
            if conv.unread_count > 0 {
                // 为每个未读会话获取 maxSeq 并通知服务端
                let max_seq = self.message_dao.get_max_seq(&conv.conversation_id).await.unwrap_or(0);
                if max_seq > 0 {
                    let _ = self.mark_conversation_as_read_server(&conv.conversation_id, max_seq, &[]).await;
                }
                // 标记本地消息已读 + 清零未读数
                self.message_dao.mark_as_read_by_max_seq(&conv.conversation_id, max_seq, &user_id).await?;
                self.conversation_dao.update_unread_count(&conv.conversation_id, 0).await?;
            }
        }

        self.conversation_listener.on_total_unread_count_changed.notify(&0);
        info!("已标记所有会话消息已读");
        Ok(())
    }

    /// 本地搜索消息
    pub async fn search_local_messages(
        &self,
        conversation_id: String,
        keyword: String,
        max_count: i64,
    ) -> Result<Vec<LocalChatLog>> {
        let results = self.message_dao.search_by_keyword(&conversation_id, &keyword, max_count).await?;
        info!("本地搜索消息: conv={}, keyword={}, count={}", conversation_id, keyword, results.len());
        Ok(results)
    }
}
