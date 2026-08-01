//! 已读回执处理（impl MessageHandler）

use super::handler::MessageHandler;
use crate::domain::constant::session_type;
use crate::domain::error::{Result, SdkError};
use crate::event::listener::conversation::ConversationEvent;
use openim_protocol::sdkws::{MarkAsReadTips, MsgData};
use prost::Message as ProstMessage;
use tracing::info;

impl MessageHandler {
    /// 发布 TotalUnreadCountChanged 事件（由调用方在批量处理完成后统一调用）
    pub async fn publish_total_unread_count_changed(&self) {
        if let Ok(total) = self.stores.conversation_repo.get_total_unread_count().await {
            self.send(ConversationEvent::TotalUnreadCountChanged(total as i64));
        }
    }

    /// 已读回执处理（对齐 Go SDK read_drawing.go doReadDrawing L227-284）
    ///
    /// 两条路径：
    /// 1. 别人发来的已读回执（对方标记我的消息已读）：
    ///    - 单聊：标记消息 is_read + 发布 C2CReadReceipt 事件 + 重算未读数
    ///    - 群聊/通知：仅重算未读数（doUnreadCount）
    /// 2. 自己的已读回执（其他设备同步）：更新未读数
    pub(crate) async fn handle_read_receipt(&self, msg: &MsgData) -> Result<()> {
        let tips = MarkAsReadTips::decode(msg.content.as_slice())
            .map_err(|e| SdkError::invalid_argument(format!("解析 MarkAsReadTips 失败: {}", e)))?;

        let login_user_id = self.user_id.get().await;

        if tips.mark_as_read_user_id != login_user_id {
            // 别人发来的已读回执：对方标记我的消息为已读
            let conversation = self.stores.conversation_repo.get_by_id(&tips.conversation_id).await?;
            let session_type_val = conversation.as_ref()
                .map(|c| c.conversation_type)
                .unwrap_or(msg.session_type);

            if session_type_val == session_type::SINGLE_CHAT {
                // 单聊已读回执：由 do_unread_count 统一标记已读 + 重算未读数
            } else if session_type_val == session_type::WRITE_GROUP_CHAT
                || session_type_val == session_type::READ_GROUP_CHAT
            {
                // 群聊：发布群已读回执事件
            }

            // 重算未读数
            self.do_unread_count(
                &tips.conversation_id,
                session_type_val,
                tips.has_read_seq,
                &tips.seqs,
            ).await?;

            info!("[RECEIPT] conv={} mark_user={} seqs={}", tips.conversation_id, tips.mark_as_read_user_id, tips.seqs.len());

        } else {
            // 自己的已读回执（其他设备同步过来的）
            self.stores.conversation_repo.update_unread_count(&tips.conversation_id, 0).await?;

            if let Ok(total) = self.stores.conversation_repo.get_total_unread_count().await {
                self.send(ConversationEvent::TotalUnreadCountChanged(total as i64));
            }

            info!("[RECEIPT] self sync conv={}", tips.conversation_id);
        }

        Ok(())
    }

    /// 处理来自 NotificationHandler 的已读回执（MsgData 格式，content_type=2200）
    pub async fn handle_read_receipt_from_msg_data(&self, msg: &openim_protocol::sdkws::MsgData) -> Result<()> {
        let content_str = std::str::from_utf8(&msg.content)
            .map_err(|e| SdkError::invalid_argument(format!("content 不是有效 UTF-8: {}", e)))?;
        let outer: serde_json::Value = serde_json::from_str(content_str)
            .map_err(|e| SdkError::invalid_argument(format!("解析外层 JSON 失败: {}", e)))?;
        let detail_str = outer.get("detail")
            .and_then(|v| v.as_str())
            .ok_or_else(|| SdkError::invalid_argument("JSON 缺少 detail 字段".to_string()))?;

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

        let login_user_id = self.user_id.get().await;

        if tips_json.mark_as_read_user_id != login_user_id {
            let conversation = self.stores.conversation_repo.get_by_id(&tips_json.conversation_id).await?;
            let session_type_val = conversation.as_ref()
                .map(|c| c.conversation_type)
                .unwrap_or(msg.session_type);

            if session_type_val == session_type::SINGLE_CHAT {
                if !seqs.is_empty() {
                    let messages = self.stores.message_repo.get_by_seqs(&tips_json.conversation_id, &seqs).await?;
                    let mut updated_client_msg_ids: Vec<String> = Vec::new();

                    for mut m in messages {
                        if m.is_read == 0 {
                            m.is_read = 1;
                            self.stores.message_repo.mark_as_read_by_seqs_all(
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
            self.stores.conversation_repo.update_unread_count(&tips_json.conversation_id, 0).await?;
            if let Ok(total) = self.stores.conversation_repo.get_total_unread_count().await {
                self.send(ConversationEvent::TotalUnreadCountChanged(total as i64));
            }

            info!("[RECEIPT] notif self sync conv={}", tips_json.conversation_id);
        }

        Ok(())
    }

    /// 重算会话未读数（对齐 Go SDK `doUnreadCount` read_drawing.go L173-225）
    async fn do_unread_count(
        &self,
        conversation_id: &str,
        session_type_val: i32,
        has_read_seq: i64,
        seqs: &[i64],
    ) -> Result<()> {
        if session_type_val == session_type::SINGLE_CHAT {
            // 幂等性检查：如果 has_read_seq 对应的消息已读，说明已处理过此回执
            if !seqs.is_empty() {
                if let Ok(Some(msg)) = self.stores.message_repo.get_by_seq(has_read_seq).await {
                    if msg.is_read != 0 {
                        return Ok(());
                    }
                }
            }

            // 标记消息已读（排除自己发的）
            if !seqs.is_empty() {
                let login_user_id = self.user_id.get().await;
                self.stores.message_repo.mark_as_read_by_seqs(conversation_id, seqs, &login_user_id).await?;
            }

            // 计算未读数 = max_seq - has_read_seq
            let current_max_seq = self.max_seq_recorder.get(conversation_id);
            let unread_count = if current_max_seq > has_read_seq {
                (current_max_seq - has_read_seq) as i32
            } else {
                0
            };

            self.stores.conversation_repo.update_unread_count(conversation_id, unread_count).await?;

        } else {
            self.stores.conversation_repo.update_unread_count(conversation_id, 0).await?;
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::constant::notification_type::HAS_READ_RECEIPT;
    use crate::domain::model::UserId;
    use crate::infra::database::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};
    use crate::domain::model::local::{LocalChatLog, LocalConversation};
    use crate::infra::database::pool::create_pool_memory;
    use openim_protocol::sdkws::MarkAsReadTips;
    use crate::sdk::context::Stores;
    use prost::Message as ProstMessage;
    use std::sync::Arc;

    fn make_test_stores(pool: sqlx::SqlitePool) -> Arc<Stores> {
        Arc::new(Stores {
            message_repo: Arc::new(MessageDao::new(pool.clone())),
            conversation_repo: Arc::new(ConversationDao::new(pool.clone())),
            friend_repo: Arc::new(FriendDao::new(pool.clone())),
            user_repo: Arc::new(UserDao::new(pool.clone())),
            group_repo: Arc::new(GroupDao::new(pool.clone())),
            sync_version_repo: Arc::new(SyncVersionDao::new(pool.clone())),
            notification_seq_dao: Arc::new(NotificationSeqDao::new(pool.clone())),
            sending_message_dao: Arc::new(SendingMessageDao::new(pool)),
        })
    }

    fn make_receipt_msg(conv_id: &str, mark_user: &str, seqs: Vec<i64>, has_read_seq: i64) -> MsgData {
        let tips = MarkAsReadTips {
            mark_as_read_user_id: mark_user.to_string(),
            conversation_id: conv_id.to_string(),
            seqs,
            has_read_seq,
        };
        let mut buf = Vec::new();
        tips.encode(&mut buf).unwrap();
        MsgData {
            client_msg_id: format!("receipt_{}", conv_id),
            content_type: HAS_READ_RECEIPT,
            content: buf,
            session_type: 1,
            send_id: mark_user.to_string(),
            ..Default::default()
        }
    }

    fn make_local_msg(conv_id: &str, client_msg_id: &str, seq: i64, send_id: &str) -> LocalChatLog {
        LocalChatLog {
            conversation_id: conv_id.to_string(),
            client_msg_id: client_msg_id.to_string(),
            server_msg_id: format!("srv_{}", client_msg_id),
            send_id: send_id.to_string(),
            recv_id: "user_2".to_string(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: "{\"text\":\"hello\"}".to_string(),
            is_read: 0,
            status: 1,
            seq,
            send_time: seq * 1000,
            create_time: seq * 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        }
    }

    fn make_conv(conv_id: &str, unread: i32) -> LocalConversation {
        LocalConversation {
            conversation_id: conv_id.to_string(),
            conversation_type: 1,
            user_id: String::new(),
            group_id: String::new(),
            show_name: String::new(),
            face_url: String::new(),
            latest_msg: String::new(),
            latest_msg_send_time: 0,
            unread_count: unread,
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
            max_seq: 10,
            min_seq: 0,
            is_msg_destruct: false,
            msg_destruct_time: 0,
        }
    }

    #[tokio::test]
    async fn test_read_receipt_single_chat_marks_messages_read() {
        let pool = create_pool_memory().await.unwrap();
        let stores = make_test_stores(pool);
        let message_dao = stores.message_repo.clone();
        let conversation_dao = stores.conversation_repo.clone();
        let handler = MessageHandler::new(stores, UserId::new("user_1"));

        let msgs = vec![
            make_local_msg("conv_read", "msg_1", 1, "user_2"),
            make_local_msg("conv_read", "msg_2", 2, "user_2"),
            make_local_msg("conv_read", "msg_3", 3, "user_2"),
        ];
        message_dao.batch_insert(&msgs).await.unwrap();
        conversation_dao.upsert(&make_conv("conv_read", 3)).await.unwrap();
        handler.max_seq_recorder.set("conv_read", 3);

        let receipt = make_receipt_msg("conv_read", "user_2", vec![1, 2, 3], 3);
        handler.handle_messages("conv_read", vec![receipt]).await.unwrap();

        let logs = message_dao.get_by_conversation("conv_read", 0, 100).await.unwrap();
        assert!(logs.iter().all(|m| m.is_read == 1), "all messages should be marked as read");

        let conv = conversation_dao.get_by_id("conv_read").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 0, "unread should be 0 after read receipt");
    }

    #[tokio::test]
    async fn test_read_receipt_self_sync_clears_unread() {
        let pool = create_pool_memory().await.unwrap();
        let stores = make_test_stores(pool);
        let conversation_dao = stores.conversation_repo.clone();
        let handler = MessageHandler::new(stores, UserId::new("user_1"));

        conversation_dao.upsert(&make_conv("conv_self_read", 5)).await.unwrap();

        let receipt = make_receipt_msg("conv_self_read", "user_1", vec![], 5);
        handler.handle_messages("conv_self_read", vec![receipt]).await.unwrap();

        let conv = conversation_dao.get_by_id("conv_self_read").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 0, "self sync should clear unread to 0");
    }

    #[tokio::test]
    async fn test_read_receipt_publishes_total_unread_changed() {
        let pool = create_pool_memory().await.unwrap();
        let stores = make_test_stores(pool);
        let conversation_dao = stores.conversation_repo.clone();
        let handler = MessageHandler::new(stores, UserId::new("user_1"));

        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        handler.set_event_sender(tx);

        conversation_dao.upsert(&make_conv("conv_ev", 3)).await.unwrap();

        let receipt = make_receipt_msg("conv_ev", "user_1", vec![], 3);
        handler.handle_messages("conv_ev", vec![receipt]).await.unwrap();

        let event = rx.try_recv();
        assert!(event.is_ok(), "should publish TotalUnreadCountChanged");
        match event.unwrap() {
            ConversationEvent::TotalUnreadCountChanged(0) => {}
            other => panic!("expected TotalUnreadCountChanged, got {:?}", other),
        }
    }

    #[tokio::test]
    async fn test_read_receipt_partial_seqs() {
        let pool = create_pool_memory().await.unwrap();
        let stores = make_test_stores(pool);
        let message_dao = stores.message_repo.clone();
        let conversation_dao = stores.conversation_repo.clone();
        let handler = MessageHandler::new(stores, UserId::new("user_1"));

        let msgs = vec![
            make_local_msg("conv_partial", "msg_1", 1, "user_2"),
            make_local_msg("conv_partial", "msg_2", 2, "user_2"),
            make_local_msg("conv_partial", "msg_3", 3, "user_2"),
        ];
        message_dao.batch_insert(&msgs).await.unwrap();
        conversation_dao.upsert(&make_conv("conv_partial", 3)).await.unwrap();
        handler.max_seq_recorder.set("conv_partial", 3);

        let receipt = make_receipt_msg("conv_partial", "user_2", vec![1, 2], 2);
        handler.handle_messages("conv_partial", vec![receipt]).await.unwrap();

        let logs = message_dao.get_by_conversation("conv_partial", 0, 100).await.unwrap();
        let read_count = logs.iter().filter(|m| m.is_read == 1).count();
        assert_eq!(read_count, 2, "only seq 1,2 should be marked read");

        let conv = conversation_dao.get_by_id("conv_partial").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 1, "unread should be 1 (3-2)");
    }

    #[tokio::test]
    async fn test_read_receipt_group_chat_clears_unread() {
        let pool = create_pool_memory().await.unwrap();
        let stores = make_test_stores(pool);
        let message_dao = stores.message_repo.clone();
        let conversation_dao = stores.conversation_repo.clone();
        let handler = MessageHandler::new(stores, UserId::new("user_1"));

        let mut group_conv = make_conv("conv_group", 5);
        group_conv.conversation_type = 3;
        conversation_dao.upsert(&group_conv).await.unwrap();

        message_dao.batch_insert(&[
            make_local_msg("conv_group", "g1", 1, "user_2"),
            make_local_msg("conv_group", "g2", 2, "user_3"),
        ]).await.unwrap();

        let receipt = make_receipt_msg("conv_group", "user_2", vec![1, 2], 2);
        handler.handle_messages("conv_group", vec![receipt]).await.unwrap();

        let conv = conversation_dao.get_by_id("conv_group").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 0, "group chat unread should be 0 after receipt");
    }
}

