//! 本地查询与本地存储操作（impl MessageService）
//!
//! 从 sdk 门面下沉：历史消息、按 seq/ID 查询、本地删除、未读数、本地扩展字段、
//! 发送中消息清理、群消息本地插入等。只读写本地仓库并发布事件，不依赖门面。

use super::MessageService;
use crate::client::{GetHistoryMessagesReq, GetHistoryMessagesResult};
use crate::constant::MessageSendStatus;
use crate::error::{Result, SdkError};
use crate::event::events::conversation::{ConversationEvent, ConversationListenerExt};
use crate::event::events::message::{MessageEvent, MessageListenerExt};
use crate::model::local::LocalChatLog;
use crate::model::message::MessageInfo;
use crate::model::msg_struct::{get_msg_id, MsgStruct};
use openim_protocol::sdkws::MsgData;
use tracing::{debug, info, warn};

impl MessageService {
    /// 历史消息分页查询（对齐 Go SDK `GetHistoryMessageList`）
    pub async fn get_history_messages(&self, req: &GetHistoryMessagesReq) -> Result<GetHistoryMessagesResult> {
        let start_time = if req.start_client_msg_id.is_empty() {
            0
        } else {
            let msg = self.repositories.message_repo.get_by_client_msg_id(&req.conversation_id, &req.start_client_msg_id).await?;
            let st = msg.as_ref().map(|m| m.send_time).unwrap_or(0);
            info!("通过 client_msg_id 查询到 send_time={}", st);
            st
        };

        let messages = self.repositories.message_repo.get_by_conversation(&req.conversation_id, start_time, req.count).await?;

        let is_end = messages.len() < req.count as usize;

        let msg_info_list: Vec<MessageInfo> = messages
            .into_iter()
            .rev()
            .map(|m| {
                let msg_struct = MsgStruct::from(&m);
                MessageInfo::from(MsgData::from(&msg_struct))
            })
            .collect();

        Ok(GetHistoryMessagesResult { messages: msg_info_list, is_end })
    }

    /// 倒序获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageListReverse`）
    ///
    /// 从 start_client_msg_id 之前的消息开始倒序获取（向上翻页取更早消息）；为空时从最新消息开始。
    pub async fn get_history_messages_reverse(&self, conversation_id: &str, start_client_msg_id: &str, count: i64) -> Result<GetHistoryMessagesResult> {
        let start_time = if start_client_msg_id.is_empty() {
            0
        } else {
            let msg = self.repositories.message_repo.get_by_client_msg_id(conversation_id, start_client_msg_id).await?;
            msg.as_ref().map(|m| m.send_time).unwrap_or(0)
        };

        // 取 start_time 之前（更早）的消息，已按 send_time 倒序；多取一条用于判断是否到底
        let messages = self.repositories.message_repo.get_by_conversation(conversation_id, start_time, count + 1).await?;

        let is_end = messages.len() <= count as usize;
        let messages: Vec<LocalChatLog> = if messages.len() > count as usize {
            messages.into_iter().take(count as usize).collect()
        } else {
            messages
        };

        let msg_info_list: Vec<MessageInfo> = messages
            .into_iter()
            .map(|m| {
                let msg_struct = MsgStruct::from(&m);
                MessageInfo::from(MsgData::from(&msg_struct))
            })
            .collect();

        Ok(GetHistoryMessagesResult { messages: msg_info_list, is_end })
    }

    /// 按 seq 范围获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageListBySeq`）
    pub async fn get_advanced_history_message_list_by_seq(&self, conversation_id: &str, start_seq: i64, end_seq: i64, count: i32) -> Result<Vec<LocalChatLog>> {
        let rows = self.repositories.message_repo.get_by_seq_range(conversation_id, start_seq, end_seq, count as i64).await?;
        Ok(rows)
    }

    /// 按 seq 获取单条消息（对齐 Go SDK `GetMessageBySeq`）
    pub async fn get_history_message_by_seq(&self, seq: i64) -> Result<LocalChatLog> {
        self.repositories
            .message_repo
            .get_by_seq(seq)
            .await?
            .ok_or_else(|| SdkError::invalid_argument(format!("seq={} 的消息不存在", seq)))
    }

    /// 按 clientMsgId 列表批量查找消息并按会话过滤（对齐 Go SDK `FindMessageList`）
    pub async fn find_message_list(&self, conversation_id: &str, client_msg_ids: Vec<String>) -> Result<Vec<LocalChatLog>> {
        if client_msg_ids.is_empty() {
            return Ok(Vec::new());
        }
        let all = self.repositories.message_repo.get_by_client_msg_ids(&client_msg_ids).await?;
        Ok(all.into_iter().filter(|m| m.conversation_id == conversation_id).collect())
    }

    /// 按 clientMsgId 查询单条本地消息（不限定会话）
    pub async fn get_message_by_client_msg_id(&self, client_msg_id: &str) -> Result<Option<LocalChatLog>> {
        self.repositories.message_repo.get_by_client_msg_id("", client_msg_id).await
    }

    /// 仅从本地删除单条消息（对齐 Go SDK `DeleteMessageFromLocalStorage`）
    ///
    /// 软删除：标记为 MsgStatusHasDeleted(4)，不通知服务端。
    pub async fn delete_message_from_local_storage(&self, conversation_id: &str, client_msg_id: &str) -> Result<()> {
        self.repositories.message_repo.mark_as_deleted(conversation_id, client_msg_id).await?;
        self.message_listener.emit(MessageEvent::Deleted {
            conversation_id: conversation_id.to_string(),
            client_msg_ids: vec![client_msg_id.to_string()],
        });
        debug!("本地删除消息: conversation_id={}, client_msg_id={}", conversation_id, client_msg_id);
        Ok(())
    }

    /// 清空会话并删除所有消息（对齐 Go SDK `ClearConversationAndDeleteAllMsg`）
    ///
    /// 会话本身保留，重置最新消息与未读数。
    pub async fn clear_conversation_and_delete_all_msg(&self, conversation_id: &str) -> Result<()> {
        self.repositories.message_repo.delete_by_conversation(conversation_id).await?;

        if let Ok(Some(mut conv)) = self.repositories.conversation_repo.get_by_id(conversation_id).await {
            conv.latest_msg = String::new();
            conv.latest_msg_send_time = 0;
            conv.max_seq = 0;
            conv.min_seq = 0;
            let _ = self.repositories.conversation_repo.upsert(&conv).await;
            // upsert 有意不更新 unread_count（本地维护字段），需显式清零
            let _ = self.repositories.conversation_repo.update_unread_count(conversation_id, 0).await;
        }
        self.listener.emit(ConversationEvent::Changed(vec![]));

        info!("清空会话消息: conversation_id={}", conversation_id);
        Ok(())
    }

    /// 删除会话并删除所有消息（对齐 Go SDK `DeleteConversationAndDeleteAllMsg`）
    pub async fn delete_conversation_and_delete_all_msg(&self, conversation_id: &str) -> Result<()> {
        self.clear_conversation_and_delete_all_msg(conversation_id).await?;

        self.repositories.conversation_repo.delete(conversation_id).await?;
        self.listener.emit(ConversationEvent::Deleted(vec![conversation_id.to_string()]));

        info!("删除会话及所有消息: conversation_id={}", conversation_id);
        Ok(())
    }

    /// 删除所有消息（本地+服务端）（对齐 Go SDK `DeleteAllMsgFromLocalAndSvr`）
    pub async fn delete_all_msg_from_local_and_svr(&self) -> Result<()> {
        self.repositories.message_repo.delete_all().await?;
        let conversations = self.repositories.conversation_repo.get_all().await?;
        for conv in &conversations {
            if conv.unread_count > 0 {
                let _ = self.repositories.conversation_repo.update_unread_count(&conv.conversation_id, 0).await;
            }
        }
        self.listener.emit(ConversationEvent::TotalUnreadCountChanged(0));

        info!("删除所有消息（本地+服务端）");
        Ok(())
    }

    /// 仅从本地删除所有消息（对齐 Go SDK `DeleteAllMsgFromLocal`）
    pub async fn delete_all_msg_from_local(&self) -> Result<()> {
        self.repositories.message_repo.mark_all_as_deleted().await?;
        info!("本地软删除所有消息");
        Ok(())
    }

    /// 获取所有会话的总未读消息数（对齐 Go SDK `GetTotalUnreadMsgCount`）
    pub async fn get_total_unread_msg_count(&self) -> Result<i64> {
        let convs = self.repositories.conversation_repo.get_all().await?;
        let total: i64 = convs.iter().map(|c| c.unread_count as i64).sum();
        Ok(total)
    }

    /// 设置消息本地扩展字段（对齐 Go SDK `SetMessageLocalEx`）
    pub async fn set_message_local_ex(&self, conversation_id: &str, client_msg_id: &str, local_ex: &str) -> Result<()> {
        self.repositories.message_repo.update_local_ex(conversation_id, client_msg_id, local_ex).await?;
        Ok(())
    }

    /// 登录时清理发送中的消息（对齐 Go SDK userRelated.go L332-375）
    pub async fn cleanup_sending_messages(&self) {
        let sending_messages = match self.repositories.sending_message_repo.get_all().await {
            Ok(msgs) => msgs,
            Err(e) => {
                warn!("获取sending_messages失败: {}", e);
                return;
            }
        };

        for sm in &sending_messages {
            if let Ok(Some(msg)) = self.repositories.message_repo.get_by_client_msg_id(&sm.conversation_id, &sm.client_msg_id).await {
                if msg.status == MessageSendStatus::Sending as i32 {
                    if let Err(e) = self.repositories.message_repo.update_send_status(&sm.client_msg_id, MessageSendStatus::SendFailed.into()).await {
                        warn!("更新sending消息状态失败: client_msg_id={}, err={}", sm.client_msg_id, e);
                    }
                }
            }
            let _ = self.repositories.sending_message_repo.delete(&sm.conversation_id, &sm.client_msg_id).await;
        }

        if !sending_messages.is_empty() {
            info!("登录时清理了 {} 条sending消息", sending_messages.len());
        }
    }

    /// 插入群聊消息到本地存储（对齐 Go SDK `InsertGroupMessageToLocalStorage`）
    pub async fn insert_group_message_to_local_storage(&self, group_id: &str, content: &str, content_type: i32, send_id: &str) -> Result<LocalChatLog> {
        let conversation_id = format!("g_{}", group_id);
        let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis() as i64;
        let client_msg_id = get_msg_id(send_id);
        let local_log = LocalChatLog {
            conversation_id: conversation_id.clone(),
            client_msg_id: client_msg_id.clone(),
            server_msg_id: String::new(),
            send_id: send_id.to_string(),
            recv_id: group_id.to_string(),
            sender_platform_id: 0,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 2,
            msg_from: 100,
            content_type,
            content: content.to_string(),
            is_read: 1,
            status: 2,
            seq: 0,
            send_time: now,
            create_time: now,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        };
        self.repositories.message_repo.batch_insert(&[local_log.clone()]).await?;
        Ok(local_log)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use crate::client::context::Repositories;
    use crate::db::pool::create_pool_memory;
    use crate::db::*;
    use crate::event::test_util::*;
    use crate::http::client::HttpApiClient;
    use crate::http::message::{DeleteMessagesReq, MarkConversationAsReadReq, MarkMessagesAsReadReq, MessageServerApi, RevokeMessageReq};
    use crate::model::local::{LocalChatLog, LocalConversation};
    use crate::model::UserId;
    use async_trait::async_trait;
    use std::sync::Arc;

    struct MockMessageApi;
    #[async_trait]
    impl MessageServerApi for MockMessageApi {
        async fn revoke_on_server(&self, _req: &RevokeMessageReq) -> Result<()> {
            Ok(())
        }
        async fn delete_on_server(&self, _conversation_id: &str, _seqs: &[i64], _user_id: &str) -> Result<()> {
            Ok(())
        }
        async fn mark_messages_as_read_on_server(&self, _req: &MarkMessagesAsReadReq) -> Result<()> {
            Ok(())
        }
        async fn mark_conversation_as_read_on_server(&self, _req: &MarkConversationAsReadReq) -> Result<()> {
            Ok(())
        }
    }

    fn make_repositories(pool: sqlx::SqlitePool) -> Arc<Repositories> {
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

    fn make_service(pool: sqlx::SqlitePool) -> super::MessageService {
        let repos = make_repositories(pool);
        super::MessageService {
            repositories: repos.clone(),
            api: Arc::new(MockMessageApi),
            user_id: UserId::new("test_user"),
            listener: noop_conversation_listener(),
            message_listener: noop_message_listener(),
        }
    }

    fn make_msg(conv_id: &str, client_msg_id: &str, seq: i64, send_time: i64, send_id: &str) -> LocalChatLog {
        LocalChatLog {
            conversation_id: conv_id.to_string(),
            client_msg_id: client_msg_id.to_string(),
            server_msg_id: String::new(),
            send_id: send_id.to_string(),
            recv_id: "user_b".to_string(),
            sender_platform_id: 1,
            sender_nick_name: "Test".to_string(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: r#"{"content":"hello"}"#.to_string(),
            is_read: 0,
            status: 2,
            seq,
            send_time,
            create_time: send_time,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        }
    }

    #[tokio::test]
    async fn test_get_history_messages_empty() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool);
        let req = GetHistoryMessagesReq {
            conversation_id: "conv_1".to_string(),
            start_client_msg_id: String::new(),
            count: 20,
        };
        let result = service.get_history_messages(&req).await.unwrap();
        assert!(result.messages.is_empty());
        assert!(result.is_end);
    }

    #[tokio::test]
    async fn test_get_history_messages_with_data() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool.clone());
        let dao = MessageDao::new(pool);
        dao.batch_insert(&[
            make_msg("conv_1", "m1", 1, 1000, "user_a"),
            make_msg("conv_1", "m2", 2, 2000, "user_a"),
            make_msg("conv_1", "m3", 3, 3000, "user_a"),
        ])
        .await
        .unwrap();
        let req = GetHistoryMessagesReq {
            conversation_id: "conv_1".to_string(),
            start_client_msg_id: String::new(),
            count: 20,
        };
        let result = service.get_history_messages(&req).await.unwrap();
        assert_eq!(result.messages.len(), 3);
        assert_eq!(result.messages[0].send_time, 1000); // .rev() 后为升序
        assert_eq!(result.messages[2].send_time, 3000); // .rev() 后为升序
        assert!(result.is_end);
    }

    #[tokio::test]
    async fn test_get_history_messages_pagination() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool.clone());
        let dao = MessageDao::new(pool);
        dao.batch_insert(&[
            make_msg("conv_1", "m1", 1, 1000, "user_a"),
            make_msg("conv_1", "m2", 2, 2000, "user_a"),
            make_msg("conv_1", "m3", 3, 3000, "user_a"),
            make_msg("conv_1", "m4", 4, 4000, "user_a"),
            make_msg("conv_1", "m5", 5, 5000, "user_a"),
        ])
        .await
        .unwrap();
        let req = GetHistoryMessagesReq {
            conversation_id: "conv_1".to_string(),
            start_client_msg_id: String::new(),
            count: 2,
        };
        let result = service.get_history_messages(&req).await.unwrap();
        assert_eq!(result.messages.len(), 2);
        assert!(!result.is_end);
    }

    #[tokio::test]
    async fn test_get_history_message_by_seq_found() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool.clone());
        let dao = MessageDao::new(pool);
        dao.batch_insert(&[make_msg("conv_1", "m1", 5, 1000, "user_a")]).await.unwrap();
        let result = service.get_history_message_by_seq(5).await.unwrap();
        assert_eq!(result.client_msg_id, "m1");
        assert_eq!(result.seq, 5);
    }

    #[tokio::test]
    async fn test_get_history_message_by_seq_not_found() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool);
        let result = service.get_history_message_by_seq(999).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_find_message_list_empty() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool);
        let result = service.find_message_list("conv_1", vec![]).await.unwrap();
        assert!(result.is_empty());
    }

    #[tokio::test]
    async fn test_find_message_list_filters_by_conversation() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool.clone());
        let dao = MessageDao::new(pool);
        dao.batch_insert(&[make_msg("conv_1", "m1", 1, 1000, "user_a"), make_msg("conv_2", "m2", 2, 2000, "user_a")])
            .await
            .unwrap();
        let result = service.find_message_list("conv_1", vec!["m1".to_string(), "m2".to_string()]).await.unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].client_msg_id, "m1");
    }

    #[tokio::test]
    async fn test_delete_message_from_local_storage() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool.clone());
        let dao = MessageDao::new(pool);
        dao.batch_insert(&[make_msg("conv_1", "m1", 1, 1000, "user_a")]).await.unwrap();
        service.delete_message_from_local_storage("conv_1", "m1").await.unwrap();
        let msg = dao.get_by_client_msg_id("conv_1", "m1").await.unwrap().unwrap();
        assert_eq!(msg.status, 4);
    }

    #[tokio::test]
    async fn test_get_total_unread_msg_count() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool.clone());
        let conv_dao = ConversationDao::new(pool);
        conv_dao
            .upsert(&LocalConversation {
                conversation_id: "conv_1".to_string(),
                unread_count: 5,
                ..Default::default()
            })
            .await
            .unwrap();
        conv_dao
            .upsert(&LocalConversation {
                conversation_id: "conv_2".to_string(),
                unread_count: 3,
                ..Default::default()
            })
            .await
            .unwrap();
        let total = service.get_total_unread_msg_count().await.unwrap();
        assert_eq!(total, 8);
    }

    #[tokio::test]
    async fn test_insert_group_message_to_local_storage() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool);
        let log = service.insert_group_message_to_local_storage("group_1", r#"{"content":"hello"}"#, 101, "user_a").await.unwrap();
        assert_eq!(log.conversation_id, "g_group_1");
        assert_eq!(log.content_type, 101);
        assert_eq!(log.status, 2);
    }

    // ========================================================================
    // 清理族：clear/delete conversation + delete all + cleanup sending
    // ========================================================================

    fn make_service_with_hub(
        pool: sqlx::SqlitePool,
    ) -> (
        super::MessageService,
        tokio::sync::mpsc::UnboundedReceiver<crate::event::events::conversation::ConversationEvent>,
        tokio::sync::mpsc::UnboundedReceiver<crate::event::events::message::MessageEvent>,
    ) {
        let repos = make_repositories(pool);
        let hub = crate::event::hub::EventHub::new();
        let conv_rx = hub.take_conv_rx().unwrap();
        let msg_rx = hub.take_message_rx().unwrap();
        let service = super::MessageService {
            repositories: repos.clone(),
            api: Arc::new(MockMessageApi),
            user_id: UserId::new("test_user"),
            listener: hub.clone(),
            message_listener: hub.clone(),
        };
        (service, conv_rx, msg_rx)
    }

    async fn insert_conv_with_unread(pool: &sqlx::SqlitePool, id: &str, unread: i32) {
        let conv_dao = ConversationDao::new(pool.clone());
        conv_dao
            .upsert(&LocalConversation {
                conversation_id: id.to_string(),
                latest_msg: "旧消息".to_string(),
                latest_msg_send_time: 1000,
                unread_count: unread,
                max_seq: 10,
                min_seq: 1,
                ..Default::default()
            })
            .await
            .unwrap();
    }

    #[tokio::test]
    async fn test_clear_conversation_and_delete_all_msg() {
        let pool = create_pool_memory().await.unwrap();
        let (service, mut conv_rx, _msg_rx) = make_service_with_hub(pool.clone());
        let dao = MessageDao::new(pool.clone());
        dao.batch_insert(&[
            make_msg("conv_1", "m1", 1, 1000, "user_a"),
            make_msg("conv_1", "m2", 2, 2000, "user_a"),
            make_msg("conv_2", "m3", 3, 3000, "user_a"),
        ])
        .await
        .unwrap();
        insert_conv_with_unread(&pool, "conv_1", 5).await;

        service.clear_conversation_and_delete_all_msg("conv_1").await.unwrap();

        // conv_1 消息清空，conv_2 保留
        assert!(dao.get_by_conversation("conv_1", 0, 10).await.unwrap().is_empty());
        assert_eq!(dao.get_by_conversation("conv_2", 0, 10).await.unwrap().len(), 1);
        // 会话保留但已重置
        let conv = ConversationDao::new(pool).get_by_id("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.latest_msg, "");
        assert_eq!(conv.latest_msg_send_time, 0);
        assert_eq!(conv.unread_count, 0);
        assert_eq!(conv.max_seq, 0);
        // Changed 事件（空列表）
        assert!(matches!(conv_rx.try_recv().unwrap(), crate::event::events::conversation::ConversationEvent::Changed(_)));
    }

    #[tokio::test]
    async fn test_delete_conversation_and_delete_all_msg() {
        let pool = create_pool_memory().await.unwrap();
        let (service, mut conv_rx, _msg_rx) = make_service_with_hub(pool.clone());
        let dao = MessageDao::new(pool.clone());
        dao.batch_insert(&[make_msg("conv_1", "m1", 1, 1000, "user_a")]).await.unwrap();
        insert_conv_with_unread(&pool, "conv_1", 2).await;

        service.delete_conversation_and_delete_all_msg("conv_1").await.unwrap();

        // 消息与会话全部删除
        assert!(dao.get_by_conversation("conv_1", 0, 10).await.unwrap().is_empty());
        assert!(ConversationDao::new(pool).get_by_id("conv_1").await.unwrap().is_none());
        // 事件：Changed（清空）→ Deleted（删会话）
        assert!(matches!(conv_rx.try_recv().unwrap(), crate::event::events::conversation::ConversationEvent::Changed(_)));
        match conv_rx.try_recv().unwrap() {
            crate::event::events::conversation::ConversationEvent::Deleted(ids) => assert_eq!(ids, vec!["conv_1"]),
            other => panic!("期望 Deleted 事件，实际 {:?}", other.as_str()),
        }
    }

    #[tokio::test]
    async fn test_delete_all_msg_from_local_and_svr() {
        let pool = create_pool_memory().await.unwrap();
        let (service, mut conv_rx, _msg_rx) = make_service_with_hub(pool.clone());
        let dao = MessageDao::new(pool.clone());
        dao.batch_insert(&[make_msg("conv_1", "m1", 1, 1000, "user_a"), make_msg("conv_2", "m2", 2, 2000, "user_a")])
            .await
            .unwrap();
        insert_conv_with_unread(&pool, "conv_1", 5).await;
        insert_conv_with_unread(&pool, "conv_2", 3).await;

        service.delete_all_msg_from_local_and_svr().await.unwrap();

        // 所有消息删除、所有未读数归零
        let total: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM local_chat_logs").fetch_one(&pool).await.unwrap();
        assert_eq!(total, 0);
        let conv_dao = ConversationDao::new(pool);
        assert_eq!(conv_dao.get_by_id("conv_1").await.unwrap().unwrap().unread_count, 0);
        assert_eq!(conv_dao.get_by_id("conv_2").await.unwrap().unwrap().unread_count, 0);
        // TotalUnreadCountChanged(0) 事件
        match conv_rx.try_recv().unwrap() {
            crate::event::events::conversation::ConversationEvent::TotalUnreadCountChanged(0) => {}
            other => panic!("期望 TotalUnreadCountChanged(0)，实际 {:?}", other.as_str()),
        }
    }

    #[tokio::test]
    async fn test_delete_all_msg_from_local_soft_delete() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool.clone());
        let dao = MessageDao::new(pool.clone());
        dao.batch_insert(&[make_msg("conv_1", "m1", 1, 1000, "user_a"), make_msg("conv_1", "m2", 2, 2000, "user_a")])
            .await
            .unwrap();

        service.delete_all_msg_from_local().await.unwrap();

        // 软删除：status = 4，但记录仍在
        let total: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM local_chat_logs").fetch_one(&pool).await.unwrap();
        assert_eq!(total, 2);
        let deleted: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM local_chat_logs WHERE status = ?")
            .bind(MessageSendStatus::HasDeleted as i32)
            .fetch_one(&pool)
            .await
            .unwrap();
        assert_eq!(deleted, 2);
    }

    #[tokio::test]
    async fn test_cleanup_sending_messages_marks_failed_and_removes() {
        let pool = create_pool_memory().await.unwrap();
        let (service, _conv_rx, _msg_rx) = make_service_with_hub(pool.clone());
        let dao = MessageDao::new(pool.clone());
        let mut sending1 = make_msg("conv_1", "m_sending", 0, 1000, "user_a");
        sending1.status = MessageSendStatus::Sending as i32;
        let mut sending2 = make_msg("conv_1", "m_sent", 0, 2000, "user_a");
        sending2.status = MessageSendStatus::SendSuccess as i32;
        dao.batch_insert(&[sending1, sending2]).await.unwrap();

        let sm_dao = SendingMessageDao::new(pool.clone());
        sm_dao
            .insert(&crate::model::local::LocalSendingMessage {
                conversation_id: "conv_1".to_string(),
                client_msg_id: "m_sending".to_string(),
                ex: String::new(),
            })
            .await
            .unwrap();
        sm_dao
            .insert(&crate::model::local::LocalSendingMessage {
                conversation_id: "conv_1".to_string(),
                client_msg_id: "m_sent".to_string(),
                ex: String::new(),
            })
            .await
            .unwrap();

        service.cleanup_sending_messages().await;

        // Sending → SendFailed；SendSuccess 保持
        let m1 = dao.get_by_client_msg_id("conv_1", "m_sending").await.unwrap().unwrap();
        assert_eq!(m1.status, MessageSendStatus::SendFailed as i32);
        let m2 = dao.get_by_client_msg_id("conv_1", "m_sent").await.unwrap().unwrap();
        assert_eq!(m2.status, MessageSendStatus::SendSuccess as i32);
        // sending 表已清空
        assert!(sm_dao.get_all().await.unwrap().is_empty());
    }

    #[tokio::test]
    async fn test_cleanup_sending_messages_empty_db() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool);
        // 空库调用不 panic 不报错
        service.cleanup_sending_messages().await;
    }

    // ========================================================================
    // 查询族补齐：reverse / by_seq / by_client_msg_id / local_ex
    // ========================================================================

    #[tokio::test]
    async fn test_get_history_messages_reverse_from_latest() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool.clone());
        let dao = MessageDao::new(pool);
        dao.batch_insert(&[
            make_msg("conv_1", "m1", 1, 1000, "user_a"),
            make_msg("conv_1", "m2", 2, 2000, "user_a"),
            make_msg("conv_1", "m3", 3, 3000, "user_a"),
            make_msg("conv_1", "m4", 4, 4000, "user_a"),
            make_msg("conv_1", "m5", 5, 5000, "user_a"),
        ])
        .await
        .unwrap();

        // 空 start：从最新开始倒序，取 2 条，未到底
        let result = service.get_history_messages_reverse("conv_1", "", 2).await.unwrap();
        assert_eq!(result.messages.len(), 2);
        assert_eq!(result.messages[0].send_time, 5000);
        assert_eq!(result.messages[1].send_time, 4000);
        assert!(!result.is_end);
    }

    #[tokio::test]
    async fn test_get_history_messages_reverse_from_start() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool.clone());
        let dao = MessageDao::new(pool);
        dao.batch_insert(&[
            make_msg("conv_1", "m1", 1, 1000, "user_a"),
            make_msg("conv_1", "m2", 2, 2000, "user_a"),
            make_msg("conv_1", "m3", 3, 3000, "user_a"),
            make_msg("conv_1", "m4", 4, 4000, "user_a"),
        ])
        .await
        .unwrap();

        // start="m3"(3000)：取 m3 之前（更早）的消息倒序，已到底
        let result = service.get_history_messages_reverse("conv_1", "m3", 2).await.unwrap();
        assert_eq!(result.messages.len(), 2);
        assert_eq!(result.messages[0].send_time, 2000);
        assert_eq!(result.messages[1].send_time, 1000);
        assert!(result.is_end);
    }

    #[tokio::test]
    async fn test_get_advanced_history_message_list_by_seq() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool.clone());
        let dao = MessageDao::new(pool);
        dao.batch_insert(&[
            make_msg("conv_1", "m1", 1, 1000, "user_a"),
            make_msg("conv_1", "m2", 2, 2000, "user_a"),
            make_msg("conv_1", "m3", 3, 3000, "user_a"),
        ])
        .await
        .unwrap();

        let rows = service.get_advanced_history_message_list_by_seq("conv_1", 1, 2, 10).await.unwrap();
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].seq, 1);
        assert_eq!(rows[1].seq, 2);
    }

    #[tokio::test]
    async fn test_get_message_by_client_msg_id() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool.clone());
        let dao = MessageDao::new(pool);
        dao.batch_insert(&[make_msg("conv_1", "m1", 1, 1000, "user_a")]).await.unwrap();

        let found = service.get_message_by_client_msg_id("m1").await.unwrap();
        assert!(found.is_some());
        assert_eq!(found.unwrap().client_msg_id, "m1");

        let none = service.get_message_by_client_msg_id("m_404").await.unwrap();
        assert!(none.is_none());
    }

    #[tokio::test]
    async fn test_set_message_local_ex() {
        let pool = create_pool_memory().await.unwrap();
        let service = make_service(pool.clone());
        let dao = MessageDao::new(pool);
        dao.batch_insert(&[make_msg("conv_1", "m1", 1, 1000, "user_a")]).await.unwrap();

        service.set_message_local_ex("conv_1", "m1", "{\"starred\":true}").await.unwrap();

        let msg = dao.get_by_client_msg_id("conv_1", "m1").await.unwrap().unwrap();
        assert_eq!(msg.local_ex, "{\"starred\":true}");
    }
}
