//! 撤回通知处理（impl MessageProcessor）

use super::processor::MessageProcessor;
use crate::domain::constant::notification_type::REVOKE;
use crate::domain::error::{Result, SdkError};
use crate::event::events::conversation::ConversationEvent;
use crate::event::events::message::{MessageEvent, MessageListenerExt};
use openim_protocol::sdkws::RevokeMsgTips;
use tracing::{info, warn};

impl MessageProcessor {
    /// 从通知 JSON 中提取 revokerNickname（服务端下发的真实昵称）
    #[allow(dead_code)]
    pub(crate) fn extract_nickname_from_notification(content: &str) -> Option<String> {
        if content.is_empty() {
            return None;
        }
        let outer: serde_json::Value = serde_json::from_str(content).ok()?;
        let detail_str = outer.get("detail")?.as_str()?;
        let inner: serde_json::Value = serde_json::from_str(detail_str).ok()?;
        let name = inner.get("revokerNickname")?.as_str()?;
        if name.is_empty() {
            None
        } else {
            Some(name.to_string())
        }
    }

    /// 获取撤回者昵称（对齐 Go SDK getUserNameAndFaceURL + GetSpecifiedGroupMembersInfo）
    async fn get_revoker_nickname(&self, tips: &RevokeMsgTips) -> (String, i32) {
        let mut revoker_role = 0i32;
        let fallback = tips.revoker_user_id.clone();

        if tips.is_admin_revoke || tips.sesstion_type == crate::domain::constant::session_type::SINGLE_CHAT {
            if let Ok(Some(user)) = self.repositories.user_repo.get_by_id(&tips.revoker_user_id).await {
                if !user.name.is_empty() {
                    return (user.name, 0);
                }
            }
        } else if tips.sesstion_type == crate::domain::constant::session_type::WRITE_GROUP_CHAT || tips.sesstion_type == crate::domain::constant::session_type::READ_GROUP_CHAT {
            if let Ok(Some(conv)) = self.repositories.conversation_repo.get_by_id(&tips.conversation_id).await {
                if let Ok(members) = self.repositories.group_repo.get_members(&conv.group_id).await {
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
    pub(crate) async fn handle_revoke_notification(&self, tips: &RevokeMsgTips, server_revoker_nickname: &str, server_revoker_role: i32) -> Result<()> {
        // 1. 获取被撤回的消息
        let revoked_msg = self.repositories.message_repo.get_by_conversation_and_seq(&tips.conversation_id, tips.seq).await?.ok_or_else(|| {
            let err_msg = format!("被撤回的消息不存在: conversation_id={}, seq={}", tips.conversation_id, tips.seq);
            warn!("[REVOKE] {}", err_msg);
            SdkError::InvalidArgument { message: err_msg }
        })?;

        // 2. 获取撤回者昵称
        info!(
            "[REVOKE-DEBUG] server_revoker_nickname='{}', server_revoker_role={}, revoker_user_id={}",
            server_revoker_nickname, server_revoker_role, tips.revoker_user_id
        );
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
        if revoker_nickname == tips.revoker_user_id && !revoked_msg.sender_nick_name.is_empty() {
            info!("[REVOKE-DEBUG] 使用被撤回消息的sender_nick_name: '{}'", revoked_msg.sender_nick_name);
            revoker_nickname = revoked_msg.sender_nick_name.clone();
        }
        info!("[REVOKE-DEBUG] 最终昵称: '{}', user_id: '{}'", revoker_nickname, tips.revoker_user_id);
        if revoker_nickname == tips.revoker_user_id && tips.sesstion_type == crate::domain::constant::session_type::WRITE_GROUP_CHAT || tips.sesstion_type == crate::domain::constant::session_type::READ_GROUP_CHAT {
            if let Ok(Some(conv)) = self.repositories.conversation_repo.get_by_id(&tips.conversation_id).await {
                if let Ok(members) = self.repositories.group_repo.get_members(&conv.group_id).await {
                    if let Some(member) = members.iter().find(|m| m.user_id == tips.revoker_user_id) {
                        revoker_role = member.role_level;
                    }
                }
            }
        }

        // 3. 构建并发布 MessageRevoked 事件
        let revoked_event = MessageEvent::Revoked {
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
        self.message_listener.emit(revoked_event);

        // 4. 更新 DB：替换消息内容为 RevokeNotification
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

        self.repositories
            .message_repo
            .update_message_content_and_type(&tips.conversation_id, &revoked_msg.client_msg_id, &notification_content.to_string(), REVOKE)
            .await?;

        info!("[REVOKE] 更新消息内容类型和内容: content_type={}, content={}", REVOKE, notification_content);

        // 5. 如果撤回的是最新消息 → 刷新会话 LatestMsg
        if let Ok(Some(conv)) = self.repositories.conversation_repo.get_by_id(&tips.conversation_id).await {
            let latest_seq: i64 = serde_json::from_str::<serde_json::Value>(&conv.latest_msg)
                .ok()
                .and_then(|v| v.get("seq").and_then(|s| s.as_i64()))
                .unwrap_or(0);
            if latest_seq <= tips.seq {
                if let Ok(latest_msgs) = self.repositories.message_repo.get_by_conversation(&tips.conversation_id, 0, 1).await {
                    if let Some(latest_msg) = latest_msgs.first() {
                        let mut updated_conv = conv.clone();
                        updated_conv.latest_msg = latest_msg.content.clone();
                        updated_conv.latest_msg_send_time = latest_msg.send_time;
                        updated_conv.max_seq = latest_msg.seq;
                        self.send(ConversationEvent::Changed(vec![updated_conv.clone()]));
                        info!("[REVOKE] 刷新会话 LatestMsg: latest_msg_send_time={}", latest_msg.send_time);
                    }
                }
            }
        }

        // 6. 触发 OnNewRecvMessageRevoked 回调

        // 7. 搜索所有引用该消息的 Quote 消息并更新
        if let Err(e) = self.handle_quote_msg_revoke(&tips.conversation_id, &revoked_msg.client_msg_id, &notification_content.to_string()).await {
            warn!("[REVOKE] 处理引用消息撤回失败: {}", e);
        }

        info!("[REVOKE] handle_revoke_notification done");
        Ok(())
    }

    /// 处理引用消息的撤回（对齐官方实现 quoteMsgRevokeHandle）
    async fn handle_quote_msg_revoke(&self, conversation_id: &str, revoked_client_msg_id: &str, revoke_notification_content: &str) -> Result<()> {
        let quote_msgs = self.repositories.message_repo.search_by_content_type(conversation_id, 104).await?;

        if quote_msgs.is_empty() {
            info!("[REVOKE] 没有找到引用消息");
            return Ok(());
        }

        info!("[REVOKE] 找到 {} 条引用消息", quote_msgs.len());

        for quote_msg in quote_msgs {
            if let Ok(quote_elem) = serde_json::from_str::<serde_json::Value>(&quote_msg.content) {
                if let Some(quote_message) = quote_elem.get("quoteMessage") {
                    if let Some(client_msg_id) = quote_message.get("clientMsgID").and_then(|v| v.as_str()) {
                        if client_msg_id == revoked_client_msg_id {
                            self.repositories
                                .message_repo
                                .update_message_content_and_type(conversation_id, &quote_msg.client_msg_id, revoke_notification_content, REVOKE)
                                .await?;

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
    use crate::domain::model::revoke::parse_revoke_tips_from_json;
    use openim_protocol::sdkws::MsgData;

    // ========================================================================
    // parse_revoke_tips_from_json 纯解析测试
    // ========================================================================

    #[test]
    fn test_parse_revoke_tips_valid() {
        let inner = serde_json::json!({
            "revokerUserID": "user_123",
            "clientMsgID": "msg_456",
            "revokeTime": 1700000000i64,
            "sesstionType": 1,
            "seq": 42,
            "conversationID": "conv_789",
            "isAdminRevoke": false,
            "revokerNickname": "Alice",
            "revokerRole": 60
        });
        let outer = serde_json::json!({ "detail": inner.to_string() });
        let content = outer.to_string();

        let result = parse_revoke_tips_from_json(&content).unwrap();
        assert_eq!(result.tips.revoker_user_id, "user_123");
        assert_eq!(result.tips.client_msg_id, "msg_456");
        assert_eq!(result.tips.revoke_time, 1700000000);
        assert_eq!(result.tips.sesstion_type, 1);
        assert_eq!(result.tips.seq, 42);
        assert_eq!(result.tips.conversation_id, "conv_789");
        assert!(!result.tips.is_admin_revoke);
        assert_eq!(result.revoker_nickname, "Alice");
        assert_eq!(result.revoker_role, 60);
    }

    #[test]
    fn test_parse_revoke_tips_admin_revoke() {
        let inner = serde_json::json!({
            "revokerUserID": "admin_1",
            "clientMsgID": "msg_001",
            "revokeTime": 1700000001i64,
            "sesstionType": 2,
            "seq": 10,
            "conversationID": "group_conv",
            "isAdminRevoke": true,
            "revokerNickname": "GroupAdmin",
            "revokerRole": 100
        });
        let outer = serde_json::json!({ "detail": inner.to_string() });

        let result = parse_revoke_tips_from_json(&outer.to_string()).unwrap();
        assert!(result.tips.is_admin_revoke);
        assert_eq!(result.revoker_role, 100);
        assert_eq!(result.tips.sesstion_type, 2);
    }

    #[test]
    fn test_parse_revoke_tips_missing_optional_fields() {
        let inner = serde_json::json!({
            "revokerUserID": "user_x",
            "clientMsgID": "msg_y",
            "revokeTime": 0i64,
            "sesstionType": 1,
            "seq": 1,
            "conversationID": "conv_z",
            "isAdminRevoke": false
        });
        let outer = serde_json::json!({ "detail": inner.to_string() });

        let result = parse_revoke_tips_from_json(&outer.to_string()).unwrap();
        assert_eq!(result.revoker_nickname, "");
        assert_eq!(result.revoker_role, 0);
    }

    #[test]
    fn test_parse_revoke_tips_invalid_outer_json() {
        let result = parse_revoke_tips_from_json("not valid json");
        assert!(result.is_err());
    }

    #[test]
    fn test_parse_revoke_tips_invalid_inner_json() {
        let outer = serde_json::json!({ "detail": "not{valid" });
        let result = parse_revoke_tips_from_json(&outer.to_string());
        assert!(result.is_err());
    }

    #[test]
    fn test_parse_revoke_tips_empty_detail() {
        let outer = serde_json::json!({ "detail": "" });
        let result = parse_revoke_tips_from_json(&outer.to_string());
        assert!(result.is_err());
    }

    // ========================================================================
    // extract_nickname_from_notification 测试
    // ========================================================================

    #[test]
    fn test_extract_nickname_valid() {
        let inner = serde_json::json!({"revokerNickname": "Bob"});
        let outer = serde_json::json!({"detail": inner.to_string()});
        let result = MessageProcessor::extract_nickname_from_notification(&outer.to_string());
        assert_eq!(result, Some("Bob".to_string()));
    }

    #[test]
    fn test_extract_nickname_empty() {
        let inner = serde_json::json!({"revokerNickname": ""});
        let outer = serde_json::json!({"detail": inner.to_string()});
        let result = MessageProcessor::extract_nickname_from_notification(&outer.to_string());
        assert_eq!(result, None);
    }

    #[test]
    fn test_extract_nickname_missing_field() {
        let inner = serde_json::json!({"other": "value"});
        let outer = serde_json::json!({"detail": inner.to_string()});
        let result = MessageProcessor::extract_nickname_from_notification(&outer.to_string());
        assert_eq!(result, None);
    }

    #[test]
    fn test_extract_nickname_invalid_json() {
        assert_eq!(MessageProcessor::extract_nickname_from_notification(""), None);
        assert_eq!(MessageProcessor::extract_nickname_from_notification("not json"), None);
        assert_eq!(MessageProcessor::extract_nickname_from_notification("{\"detail\": 123}"), None);
    }

    // ========================================================================
    // 撤回通知集成测试（内存 DB）
    // ========================================================================

    use crate::client::context::Repositories;
    use crate::domain::constant::notification_type::REVOKE as REVOKE_CT;
    use crate::infra::db::pool::create_pool_memory;
    use crate::infra::db::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};
    use crate::domain::model::local::{LocalChatLog, LocalConversation};
    use crate::domain::model::UserId;
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

    fn make_revoke_notification(conv_id: &str, target_seq: i64, target_client_msg_id: &str, revoker: &str) -> MsgData {
        let detail = serde_json::json!({
            "revokerUserID": revoker,
            "clientMsgID": target_client_msg_id,
            "revokeTime": 9999,
            "sesstionType": 1,
            "seq": target_seq,
            "conversationID": conv_id,
            "isAdminRevoke": false,
            "revokerNickname": "Alice",
            "revokerRole": 0
        });
        let outer = serde_json::json!({ "detail": detail.to_string() });
        MsgData {
            client_msg_id: format!("revoke_notif_{}", target_seq),
            content_type: REVOKE_CT,
            content: outer.to_string().into_bytes(),
            send_id: revoker.to_string(),
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
            sender_nick_name: "Bob".to_string(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: "{\"text\":\"original message\"}".to_string(),
            is_read: 0,
            status: 1,
            seq,
            send_time: 1000,
            create_time: 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        }
    }

    #[tokio::test]
    async fn test_revoke_notification_updates_message() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_repo = repositories.message_repo.clone();
        let conversation_repo = repositories.conversation_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new("user_1"),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

        message_repo.batch_insert(&[make_local_msg("conv_revoke", "msg_target", 5, "user_1")]).await.unwrap();
        let conv = LocalConversation {
            conversation_id: "conv_revoke".to_string(),
            conversation_type: 1,
            user_id: String::new(),
            group_id: String::new(),
            show_name: String::new(),
            face_url: String::new(),
            latest_msg: String::new(),
            latest_msg_send_time: 0,
            unread_count: 0,
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
            max_seq: 5,
            min_seq: 0,
            is_msg_destruct: false,
            msg_destruct_time: 0,
        };
        conversation_repo.upsert(&conv).await.unwrap();

        let notif = make_revoke_notification("conv_revoke", 5, "msg_target", "user_1");
        handler.handle_messages("conv_revoke", vec![notif]).await.unwrap();

        let msg = message_repo.get_by_conversation_and_seq("conv_revoke", 5).await.unwrap().unwrap();
        assert_eq!(msg.content_type, REVOKE_CT, "content_type should be REVOKE");
        assert!(msg.content.contains("revokerNickname"), "content should contain revoke info");
        assert!(msg.content.contains("Alice"), "content should contain revoker nickname");
    }

    #[tokio::test]
    async fn test_revoke_quote_message_updated() {
        let pool = create_pool_memory().await.unwrap();
        let repositories = make_test_repositories(pool);
        let message_repo = repositories.message_repo.clone();
        let conversation_repo = repositories.conversation_repo.clone();
        let handler = MessageProcessor::new(
            repositories,
            UserId::new("user_1"),
            crate::event::test_util::noop_conversation_listener(),
            crate::event::test_util::noop_message_listener(),
        );

        let mut quote_msg = make_local_msg("conv_quote", "quote_msg", 6, "user_2");
        quote_msg.content_type = 104;
        quote_msg.content = serde_json::json!({
            "text": "my reply",
            "quoteMessage": {
                "clientMsgID": "msg_origin",
                "content": "{\"text\":\"original\"}"
            }
        })
        .to_string();

        message_repo.batch_insert(&[make_local_msg("conv_quote", "msg_origin", 3, "user_1"), quote_msg]).await.unwrap();
        let conv = LocalConversation {
            conversation_id: "conv_quote".to_string(),
            conversation_type: 1,
            user_id: String::new(),
            group_id: String::new(),
            show_name: String::new(),
            face_url: String::new(),
            latest_msg: String::new(),
            latest_msg_send_time: 0,
            unread_count: 0,
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
            max_seq: 6,
            min_seq: 0,
            is_msg_destruct: false,
            msg_destruct_time: 0,
        };
        conversation_repo.upsert(&conv).await.unwrap();

        let notif = make_revoke_notification("conv_quote", 3, "msg_origin", "user_1");
        handler.handle_messages("conv_quote", vec![notif]).await.unwrap();

        let origin = message_repo.get_by_conversation_and_seq("conv_quote", 3).await.unwrap().unwrap();
        assert_eq!(origin.content_type, REVOKE_CT);

        let quote = message_repo.get_by_conversation_and_seq("conv_quote", 6).await.unwrap().unwrap();
        assert_eq!(quote.content_type, REVOKE_CT, "quote message should also be revoked");
    }
}
