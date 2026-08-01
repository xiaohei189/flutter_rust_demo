//! 标记已读逻辑（单会话/批量/按 seq）

use super::MessageService;
use crate::domain::ports::message::{MarkConversationAsReadReq, MarkMessagesAsReadReq};
use crate::domain::constant::session_type;
use crate::domain::error::{Result, SdkError};
use crate::event::types::SdkEvent;
use crate::domain::model::local::LocalConversation;
use crate::event::listener::conversation::ConversationEvent;
use tracing::{error, info, warn};

impl MessageService {
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
        let user_id = self.user_id.get().await;

        // L49: GetConversation
        let conv = self.stores.conversation_repo.get_by_id(&conversation_id).await?;
        let conv = conv.ok_or_else(|| SdkError::invalid_argument(format!("conversation not found: {}", conversation_id)))?;

        // L53-56: UnreadCount == 0 → 提前返回
        if conv.unread_count == 0 {
            return Ok(());
        }

        // L58: GetConversationPeerNormalMsgSeq
        let peer_user_max_seq = self.stores.message_repo.get_peer_normal_msg_seq(&conversation_id, &user_id).await?;
        // L63: GetConversationNormalMsgSeq
        let mut max_seq = self.stores.message_repo.get_max_seq(&conversation_id).await?;
        if max_seq == 0 {
            max_seq = self.stores.conversation_repo.get_max_seq(&conversation_id).await?;
        }

        // L67-96: switch conversation.ConversationType（用 DB 中的会话类型，不依赖传入参数）
        match conv.conversation_type {
            st if st == session_type::SINGLE_CHAT => {
                // L69: GetUnreadMessage
                let unread_msgs = self.stores.message_repo.get_unread_messages(&conversation_id, &user_id).await?;

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
                    if let Err(e) = self.stores.message_repo
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
        if let Err(e) = self.stores.conversation_repo.update_unread_count(&conversation_id, 0).await {
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
        let updated_conv = self.stores.conversation_repo.get_by_id(conversation_id).await;
        if let Ok(Some(conv)) = updated_conv {
            self.send(ConversationEvent::Changed(vec![conv]));
        }

        // 总未读数由 handler.rs 统一发布，这里只发 ConversationChanged
    }

    /// 调用服务端 `markConversationAsRead` API（对齐 Go SDK `server_api.go` L17-22）
    pub(crate) async fn mark_conversation_as_read_server(
        &self,
        conversation_id: &str,
        has_read_seq: i64,
        seqs: &[i64],
    ) -> Result<()> {
        let user_id = self.user_id.get().await;
        let req = MarkConversationAsReadReq {
            user_id,
            conversation_id: conversation_id.to_string(),
            has_read_seq,
            seqs: seqs.to_vec(),
        };
        self.api.mark_conversation_as_read_on_server(&req).await
    }

    /// 标记消息已读（按 seq 列表，对齐 Go SDK `markMsgAsRead2Server`）
    pub async fn mark_messages_as_read(&self, mut req: MarkMessagesAsReadReq) -> Result<()> {
        // 外部传入的 user_id 可能为空，统一以当前登录用户覆盖（值一致）
        req.user_id = self.user_id.get().await;

        self.api.mark_messages_as_read_on_server(&req).await?;

        // 更新本地数据库：标记消息为已读（排除自己发的）
        if !req.seqs.is_empty() {
            self.stores.message_repo.mark_as_read_by_seqs(&req.conversation_id, &req.seqs, &req.user_id).await?;
        }

        info!("消息已标记为已读: conversation_id={}, seq_count={}", req.conversation_id, req.seqs.len());
        Ok(())
    }

    /// 标记所有会话消息已读（对齐 Go SDK `MarkAllConversationMessageAsRead`）
    ///
    /// 遍历所有未读会话，逐个调用 `mark_conversation_message_as_read` 标记已读
    pub async fn mark_all_conversation_as_read(&self) -> Result<()> {
        let conversations = self.stores.conversation_repo.get_all().await?;
        let user_id = self.user_id.get().await;

        for conv in &conversations {
            if conv.unread_count > 0 {
                // 为每个未读会话获取 maxSeq 并通知服务端
                let max_seq = self.stores.message_repo.get_max_seq(&conv.conversation_id).await.unwrap_or(0);
                if max_seq > 0 {
                    let _ = self.mark_conversation_as_read_server(&conv.conversation_id, max_seq, &[]).await;
                }
                // 标记本地消息已读 + 清零未读数
                self.stores.message_repo.mark_as_read_by_max_seq(&conv.conversation_id, max_seq, &user_id).await?;
                self.stores.conversation_repo.update_unread_count(&conv.conversation_id, 0).await?;
            }
        }

        // 总未读数由 handler.rs 统一发布
        info!("已标记所有会话消息已读");
        Ok(())
    }
}

