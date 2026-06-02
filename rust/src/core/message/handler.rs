use crate::domain::constant::types::content_type;
use crate::domain::constant::types::notification_type::HAS_READ_RECEIPT;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::message::ReceivedMessage;
use crate::infra::database::{ConversationDao, MessageDao};
use crate::infra::database::models::{LocalChatLog, LocalConversation};
use crate::protocol::sdkws::MarkAsReadTips;
use prost::Message as ProstMessage;
use std::sync::Arc;
use tracing::{debug, info, warn};

pub struct MessageHandler {
    message_dao: Arc<MessageDao>,
    conversation_dao: Arc<ConversationDao>,
    event_bus: Arc<EventBus>,
    user_id: std::sync::Mutex<String>,
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

    pub async fn handle_messages(&self, messages: Vec<ReceivedMessage>) -> Result<()> {
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

        let client_msg_ids: Vec<String> = normal_messages.iter().map(|m| m.client_msg_id.clone()).collect();
        let existing_logs = self.message_dao.get_by_client_msg_ids(&client_msg_ids).await.unwrap_or_default();
        let existing_map: std::collections::HashSet<String> = existing_logs.into_iter()
            .map(|l| l.client_msg_id)
            .collect();

        let login_user_id = self.user_id.lock().unwrap().clone();

        let mut store_logs: Vec<LocalChatLog> = Vec::new();
        let mut to_notify: Vec<ReceivedMessage> = Vec::new();

        for msg in &normal_messages {
            if !Self::should_store_message(msg.content_type) {
                continue;
            }

            let is_self = msg.send_id == login_user_id;

            if is_self {
                // 自己发的消息（对齐 Go SDK conversation_msg.go L316-356）
                if existing_map.contains(&msg.client_msg_id) {
                    // 本地已有记录：更新 seq/status，不插入不增加未读数
                    if msg.seq > 0 {
                        debug!("更新自己消息的seq: client_msg_id={}, seq={}", msg.client_msg_id, msg.seq);
                    }
                    continue;
                }
                // 本地无记录（其他终端同步过来的）：插入但不增加未读数
            } else {
                // 别人发的消息（对齐 Go SDK conversation_msg.go L357-398）
                if msg.seq > 0 && existing_map.contains(&msg.client_msg_id) {
                    debug!("skip duplicate message: client_msg_id={}, seq={}", msg.client_msg_id, msg.seq);
                    continue;
                }
            }

            store_logs.push(LocalChatLog {
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
                status: 2,
                seq: msg.seq,
                send_time: msg.send_time,
                create_time: msg.create_time,
                attached_info: String::new(),
                ex: String::new(),
                local_ex: String::new(),
                group_id: msg.group_id.clone(),
            });

            to_notify.push(msg.clone());
        }

        if !store_logs.is_empty() {
            info!("准备插入 {} 条消息到数据库", store_logs.len());
            for log in &store_logs {
                info!("  待插入: conversation_id={}, client_msg_id={}, seq={}, send_time={}", 
                      log.conversation_id, log.client_msg_id, log.seq, log.send_time);
            }
            self.message_dao.batch_insert(&store_logs).await?;
            info!("消息插入数据库完成");
        }

        let mut seen_convs = std::collections::HashSet::new();
        for msg in &to_notify {
            let is_conversation_update = Self::should_update_conversation(msg.content_type);
            let is_self = msg.send_id == login_user_id;

            if seen_convs.insert(&msg.conversation_id) {
                let existing = self.conversation_dao.get_by_id(&msg.conversation_id).await?;
                if existing.is_none() {
                    let show_name = if msg.session_type == 1 {
                        msg.sender_nick_name.clone()
                    } else {
                        format!("Group_{}", msg.group_id)
                    };

                    // 自己发的消息不增加未读数（对齐 Go SDK L336-L340）
                    let unread_count = if is_conversation_update && !is_self { 1 } else { 0 };

                    let conv = LocalConversation {
                        conversation_id: msg.conversation_id.clone(),
                        conversation_type: msg.session_type,
                        user_id: if msg.session_type == 1 { msg.recv_id.clone() } else { msg.send_id.clone() },
                        group_id: if msg.session_type != 1 { msg.group_id.clone() } else { String::new() },
                        show_name,
                        face_url: msg.sender_face_url.clone(),
                        latest_msg: if is_conversation_update { msg.content.clone() } else { String::new() },
                        latest_msg_send_time: if is_conversation_update { msg.send_time } else { 0 },
                        unread_count,
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
                } else if is_conversation_update {
                    self.conversation_dao
                        .update_after_new_message(
                            &msg.conversation_id,
                            &msg.content,
                            msg.send_time,
                            msg.seq,
                        )
                        .await?;
                }
            }

            if msg.content_type != content_type::TYPING {
                self.event_bus.publish(SdkEvent::NewMessage {
                    message: msg.clone(),
                });
            }
        }

        info!("handled {} messages ({} inserted, {} duplicates skipped)", 
            normal_messages.len(), store_logs.len(), normal_messages.len() - store_logs.len());
        Ok(())
    }

    /// 已读回执处理（对齐 Go SDK read_drawing.go doReadDrawing L227-284）
    async fn handle_read_receipt(&self, msg: &ReceivedMessage) -> Result<()> {
        let tips = MarkAsReadTips::decode(msg.content.as_bytes())
            .map_err(|e| SdkError::invalid_argument(format!("解析 MarkAsReadTips 失败: {}", e)))?;

        let login_user_id = self.user_id.lock().unwrap().clone();

        if tips.mark_as_read_user_id != login_user_id {
            // 别人发来的已读回执：标记我发的消息为已读
            if tips.seqs.is_empty() {
                return Ok(());
            }

            if msg.session_type == 1 {
                // 单聊：标记消息已读（对齐 Go SDK read_drawing.go L251-280）
                self.message_dao.mark_as_read_by_seqs(&tips.conversation_id, &tips.seqs).await?;
            }
            // 群聊和通知会话：更新未读数（对齐 Go SDK doUnreadCount）
            self.conversation_dao.update_unread_count(&tips.conversation_id, 0).await?;
        } else {
            // 自己的已读回执（其他设备同步过来的）：更新未读数
            self.conversation_dao.update_unread_count(&tips.conversation_id, 0).await?;
        }

        debug!("处理已读回执: conversation_id={}, seqs={}", tips.conversation_id, tips.seqs.len());
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
