//! 已读回执处理（impl MessageProcessor）

use super::processor::MessageProcessor;
use crate::constant::session_type;
use crate::error::{Result, SdkError};
use crate::event::events::conversation::ConversationEvent;
use crate::event::events::message::{MessageEvent, MessageListenerExt, MessageReceipt};
use openim_protocol::sdkws::{MarkAsReadTips, MsgData};
use prost::Message as ProstMessage;
use tracing::info;

impl MessageProcessor {
    /// 发布 TotalUnreadCountChanged 事件（由调用方在批量处理完成后统一调用）
    pub async fn publish_total_unread_count_changed(&self) {
        if let Ok(total) = self.repositories.conversation_repo.get_total_unread_count().await {
            self.send(ConversationEvent::TotalUnreadCountChanged(total as i64));
        }
    }

    /// 已读回执处理（对齐 Go SDK read_drawing.go doReadDrawing L227-284）
    ///
    /// 两条路径：
    /// 1. 别人发来的已读回执（对方标记我的消息已读）：
    ///    - 单聊：标记消息 is_read + 发布 C2CReadReceipt 事件 + 重算未读数
    ///    - 群聊/通知：仅重算未读数（doUnreadCount）
    /// 2. 自己的已读回执（其他设备同步）：走统一的 doUnreadCount（含幂等检查）
    pub(crate) async fn handle_read_receipt(&self, msg: &MsgData) -> Result<()> {
        let tips = MarkAsReadTips::decode(msg.content.as_slice()).map_err(|e| SdkError::invalid_argument(format!("解析 MarkAsReadTips 失败: {}", e)))?;

        let login_user_id = self.user_id.get().await;

        if tips.mark_as_read_user_id != login_user_id {
            // 对齐 Go SDK doReadDrawing L241-280：别人发来的已读回执只标记消息已读 + C2CReadReceipt，
            // 不重算会话未读数（别人已读不影响"我未读"的计数）
            let conversation = self.repositories.conversation_repo.get_by_id(&tips.conversation_id).await?;
            let session_type_val = conversation.as_ref().map(|c| c.conversation_type).unwrap_or(msg.session_type);

            // L245-275: 单聊逐条标记消息 IsRead（不过滤 send_id）
            if session_type_val == session_type::SINGLE_CHAT && !tips.seqs.is_empty() {
                self.repositories.message_repo.mark_as_read_by_seqs_all(&tips.conversation_id, &tips.seqs).await?;
            }

            // L277-279: 单聊发布 C2CReadReceipt 事件
            if session_type_val == session_type::SINGLE_CHAT && !tips.seqs.is_empty() {
                self.message_listener.emit(MessageEvent::C2CReadReceipt {
                    receipts: vec![MessageReceipt {
                        user_id: tips.mark_as_read_user_id.clone(),
                        msg_ids: tips.seqs.iter().map(|s| s.to_string()).collect(),
                        read_time: 0,
                        session_type: session_type_val,
                    }],
                });
            }

            info!("[RECEIPT] conv={} mark_user={} seqs={}", tips.conversation_id, tips.mark_as_read_user_id, tips.seqs.len());
        } else {
            // 自己的已读回执（其他设备同步过来的）：对齐 Go SDK doReadDrawing L281-282
            // 走统一的 doUnreadCount（含幂等检查），已处理过的回执不再重复发布事件
            let conversation = self.repositories.conversation_repo.get_by_id(&tips.conversation_id).await?;
            let session_type_val = conversation.as_ref().map(|c| c.conversation_type).unwrap_or(msg.session_type);
            if self.do_unread_count(&tips.conversation_id, session_type_val, tips.has_read_seq, &tips.seqs).await? {
                if let Ok(total) = self.repositories.conversation_repo.get_total_unread_count().await {
                    self.send(ConversationEvent::TotalUnreadCountChanged(total as i64));
                }
            }

            info!("[RECEIPT] self sync conv={}", tips.conversation_id);
        }

        Ok(())
    }

    /// 处理来自 NotificationHandler 的已读回执（MsgData 格式，content_type=2200）
    pub async fn handle_read_receipt_from_msg_data(&self, msg: &openim_protocol::sdkws::MsgData) -> Result<()> {
        let content_str = std::str::from_utf8(&msg.content).map_err(|e| SdkError::invalid_argument(format!("content 不是有效 UTF-8: {}", e)))?;
        let outer: serde_json::Value = serde_json::from_str(content_str).map_err(|e| SdkError::invalid_argument(format!("解析外层 JSON 失败: {}", e)))?;
        let detail_str = outer
            .get("detail")
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
        let tips_json: MarkAsReadTipsJson = serde_json::from_str(detail_str).map_err(|e| SdkError::invalid_argument(format!("解析 detail JSON 失败: {}", e)))?;
        let seqs = tips_json.seqs.unwrap_or_default();

        let login_user_id = self.user_id.get().await;

        if tips_json.mark_as_read_user_id != login_user_id {
            let conversation = self.repositories.conversation_repo.get_by_id(&tips_json.conversation_id).await?;
            let session_type_val = conversation.as_ref().map(|c| c.conversation_type).unwrap_or(msg.session_type);

            if session_type_val == session_type::SINGLE_CHAT {
                if !seqs.is_empty() {
                    let messages = self.repositories.message_repo.get_by_seqs(&tips_json.conversation_id, &seqs).await?;
                    let mut updated_client_msg_ids: Vec<String> = Vec::new();

                    for mut m in messages {
                        if m.is_read == 0 {
                            m.is_read = 1;
                            self.repositories.message_repo.mark_as_read_by_seqs_all(&tips_json.conversation_id, &[m.seq]).await?;
                            updated_client_msg_ids.push(m.client_msg_id.clone());
                        }
                    }

                    if !updated_client_msg_ids.is_empty() {
                        self.message_listener.emit(MessageEvent::C2CReadReceipt {
                            receipts: vec![MessageReceipt {
                                user_id: tips_json.mark_as_read_user_id.clone(),
                                msg_ids: updated_client_msg_ids,
                                read_time: 0,
                                session_type: session_type_val,
                            }],
                        });
                    }
                }
            } else if session_type_val == session_type::WRITE_GROUP_CHAT || session_type_val == session_type::READ_GROUP_CHAT {
            }

            // 对齐 Go SDK doReadDrawing L241-280：别人已读回执不重算会话未读数

            info!("[RECEIPT] notif conv={} mark_user={} seqs={}", tips_json.conversation_id, tips_json.mark_as_read_user_id, seqs.len());
        } else {
            // 对齐 Go SDK doReadDrawing L281-282：自己的回执（其他设备同步）走统一的
            // doUnreadCount（含幂等检查），已处理过的回执不再重复发布事件
            let conversation = self.repositories.conversation_repo.get_by_id(&tips_json.conversation_id).await?;
            let session_type_val = conversation.as_ref().map(|c| c.conversation_type).unwrap_or(msg.session_type);
            if self.do_unread_count(&tips_json.conversation_id, session_type_val, tips_json.has_read_seq, &seqs).await? {
                if let Ok(total) = self.repositories.conversation_repo.get_total_unread_count().await {
                    self.send(ConversationEvent::TotalUnreadCountChanged(total as i64));
                }
            }

            info!("[RECEIPT] notif self sync conv={}", tips_json.conversation_id);
        }

        Ok(())
    }

    /// 重算会话未读数（对齐 Go SDK `doUnreadCount` read_drawing.go L173-225）
    ///
    /// 返回 true 表示实际处理（更新了未读数）；false 表示回执可忽略（幂等跳过/无有效信息），
    /// 调用方不应发布 TotalUnreadCountChanged 事件。
    async fn do_unread_count(&self, conversation_id: &str, session_type_val: i32, has_read_seq: i64, seqs: &[i64]) -> Result<bool> {
        if session_type_val == session_type::SINGLE_CHAT {
            // 对齐 Go L175-192：seqs 为空视为无有效已读信息，直接忽略
            if seqs.is_empty() {
                return Ok(false);
            }

            // 幂等性检查（对齐 Go L176-182）：has_read_seq 消息缺失或已读，说明已处理过此回执
            match self.repositories.message_repo.get_by_conversation_and_seq(conversation_id, has_read_seq).await {
                Ok(Some(msg)) if msg.is_read != 0 => return Ok(false),
                Ok(None) => return Ok(false),
                Err(e) => return Err(e),
                _ => {}
            }

            // 标记消息已读（排除自己发的）
            let login_user_id = self.user_id.get().await;
            self.repositories.message_repo.mark_as_read_by_seqs(conversation_id, seqs, &login_user_id).await?;

            // 对齐 Go L193-195：内存中未记录当前 max_seq 时忽略
            let current_max_seq = self.max_seq_recorder.get(conversation_id);
            if current_max_seq == 0 {
                return Ok(false);
            }

            // 计算未读数 = max_seq - has_read_seq（对齐 Go L196-201，负数取 0）
            let unread_count = if current_max_seq > has_read_seq { (current_max_seq - has_read_seq) as i32 } else { 0 };
            self.repositories.conversation_repo.update_unread_count(conversation_id, unread_count).await?;
        } else {
            self.repositories.conversation_repo.update_unread_count(conversation_id, 0).await?;
        }

        Ok(true)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::client::context::Repositories;
    use crate::constant::notification_type::HAS_READ_RECEIPT;
    use crate::db::pool::create_pool_memory;
    use crate::db::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};
    use crate::model::local::{LocalChatLog, LocalConversation};
    use crate::model::UserId;
    use openim_protocol::sdkws::MarkAsReadTips;
    use prost::Message as ProstMessage;
    use std::sync::Arc;

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
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new("user_1"),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

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
        assert_eq!(conv.unread_count, 3, "别人已读回执不重算未读数（对齐 Go doReadDrawing）");
    }

    #[tokio::test]
    async fn test_read_receipt_self_sync_clears_unread() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new("user_1"),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

        conversation_dao.upsert(&make_conv("conv_self_read", 5)).await.unwrap();
        message_dao
            .batch_insert(&[
                make_local_msg("conv_self_read", "s1", 1, "user_2"),
                make_local_msg("conv_self_read", "s2", 2, "user_2"),
                make_local_msg("conv_self_read", "s3", 3, "user_2"),
                make_local_msg("conv_self_read", "s4", 4, "user_2"),
                make_local_msg("conv_self_read", "s5", 5, "user_2"),
            ])
            .await
            .unwrap();
        handler.max_seq_recorder.set("conv_self_read", 5);

        // 自己的回执带已读消息列表（对齐 Go doReadDrawing：self 回执走 doUnreadCount）
        let receipt = make_receipt_msg("conv_self_read", "user_1", vec![1, 2, 3, 4, 5], 5);
        handler.handle_messages("conv_self_read", vec![receipt]).await.unwrap();

        let conv = conversation_dao.get_by_id("conv_self_read").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 0, "self sync should clear unread to 0");
    }

    #[tokio::test]
    async fn test_read_receipt_self_sync_idempotent_skips_second_event() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let hub = crate::event::hub::EventHub::new();
        let handler = MessageProcessor::new(repositories, UserId::new("user_1"), hub.clone(), crate::event::test_util::noop_message_listener());
        let mut rx = hub.take_conv_rx().unwrap();

        conversation_dao.upsert(&make_conv("conv_idem", 3)).await.unwrap();
        message_dao
            .batch_insert(&[
                make_local_msg("conv_idem", "i1", 1, "user_2"),
                make_local_msg("conv_idem", "i2", 2, "user_2"),
                make_local_msg("conv_idem", "i3", 3, "user_2"),
            ])
            .await
            .unwrap();
        handler.max_seq_recorder.set("conv_idem", 3);

        let receipt = make_receipt_msg("conv_idem", "user_1", vec![1, 2, 3], 3);
        // 第一次处理：应更新未读数并发布事件
        handler.handle_messages("conv_idem", vec![receipt.clone()]).await.unwrap();
        assert!(rx.try_recv().is_ok(), "first processing should publish TotalUnreadCountChanged");

        // 重放同一条回执：has_read_seq 消息已读 → 幂等跳过，不再发布事件
        handler.handle_messages("conv_idem", vec![receipt]).await.unwrap();
        let event = rx.try_recv();
        assert!(event.is_err(), "replayed receipt should be idempotently skipped");
    }

    #[tokio::test]
    async fn test_read_receipt_publishes_total_unread_changed() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let hub = crate::event::hub::EventHub::new();
        let handler = MessageProcessor::new(repositories, UserId::new("user_1"), hub.clone(), crate::event::test_util::noop_message_listener());
        let mut rx = hub.take_conv_rx().unwrap();

        conversation_dao.upsert(&make_conv("conv_ev", 3)).await.unwrap();
        message_dao
            .batch_insert(&[
                make_local_msg("conv_ev", "e1", 1, "user_2"),
                make_local_msg("conv_ev", "e2", 2, "user_2"),
                make_local_msg("conv_ev", "e3", 3, "user_2"),
            ])
            .await
            .unwrap();
        handler.max_seq_recorder.set("conv_ev", 3);

        // 自己的回执带已读消息列表才会触发事件（对齐 Go：seqs 为空直接忽略）
        let receipt = make_receipt_msg("conv_ev", "user_1", vec![1, 2, 3], 3);
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
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new("user_1"),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

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
        assert_eq!(conv.unread_count, 3, "别人已读回执不重算未读数（对齐 Go doReadDrawing）");
    }

    #[tokio::test]
    async fn test_read_receipt_group_chat_keeps_unread() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_dao = repositories.message_repo.clone();
        let conversation_dao = repositories.conversation_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new("user_1"),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

        let mut group_conv = make_conv("conv_group", 5);
        group_conv.conversation_type = 3;
        conversation_dao.upsert(&group_conv).await.unwrap();

        message_dao
            .batch_insert(&[make_local_msg("conv_group", "g1", 1, "user_2"), make_local_msg("conv_group", "g2", 2, "user_3")])
            .await
            .unwrap();

        let receipt = make_receipt_msg("conv_group", "user_2", vec![1, 2], 2);
        handler.handle_messages("conv_group", vec![receipt]).await.unwrap();

        let conv = conversation_dao.get_by_id("conv_group").await.unwrap().unwrap();
        assert_eq!(conv.unread_count, 5, "别人已读回执不重算群聊未读数（对齐 Go doReadDrawing）");
    }
}
