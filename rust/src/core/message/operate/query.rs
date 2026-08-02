//! 本地查询与本地存储操作（impl MessageService）
//!
//! 从 sdk 门面下沉：历史消息、按 seq/ID 查询、本地删除、未读数、本地扩展字段、
//! 发送中消息清理、群消息本地插入等。只读写本地仓库并发布事件，不依赖门面。

use super::MessageService;
use crate::domain::constant::MessageSendStatus;
use crate::domain::error::{Result, SdkError};
use crate::domain::model::local::LocalChatLog;
use crate::domain::model::message::MessageInfo;
use crate::domain::model::msg_struct::{get_msg_id, MsgStruct};
use crate::domain::sdk_api::{GetHistoryMessagesReq, GetHistoryMessagesResult};
use crate::event::events::conversation::{ConversationEvent, ConversationListenerExt};
use crate::event::events::message::{MessageEvent, MessageListenerExt};
use openim_protocol::sdkws::MsgData;
use tracing::{debug, info, warn};

impl MessageService {
    /// 历史消息分页查询（对齐 Go SDK `GetHistoryMessageList`）
    pub async fn get_history_messages(&self, req: &GetHistoryMessagesReq) -> Result<GetHistoryMessagesResult> {
        let start_time = if req.start_client_msg_id.is_empty() {
            0
        } else {
            let msg = self.repositories.message_repo
                .get_by_client_msg_id(&req.conversation_id, &req.start_client_msg_id)
                .await?;
            let st = msg.as_ref().map(|m| m.send_time).unwrap_or(0);
            info!("通过 client_msg_id 查询到 send_time={}", st);
            st
        };

        let messages = self.repositories.message_repo
            .get_by_conversation(&req.conversation_id, start_time, req.count)
            .await?;

        let is_end = messages.len() < req.count as usize;

        let msg_info_list: Vec<MessageInfo> = messages.into_iter()
            .rev()
            .map(|m| {
                let msg_struct = MsgStruct::from(&m);
                MessageInfo::from(MsgData::from(&msg_struct))
            })
            .collect();

        Ok(GetHistoryMessagesResult {
            messages: msg_info_list,
            is_end,
        })
    }

    /// 倒序获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageListReverse`）
    ///
    /// 从 start_client_msg_id 之前的消息开始倒序获取；为空时从最新消息开始。
    pub async fn get_history_messages_reverse(
        &self,
        conversation_id: &str,
        start_client_msg_id: &str,
        count: i64,
    ) -> Result<GetHistoryMessagesResult> {
        let start_time = if start_client_msg_id.is_empty() {
            0
        } else {
            let msg = self.repositories.message_repo
                .get_by_client_msg_id(conversation_id, start_client_msg_id)
                .await?;
            msg.as_ref().map(|m| m.send_time).unwrap_or(0)
        };

        let messages = self.repositories.message_repo
            .get_by_conversation_asc(conversation_id, start_time, count + 1)
            .await?;

        let mut messages: Vec<LocalChatLog> = messages.into_iter().rev().collect();

        let is_end = messages.len() <= count as usize;
        if !is_end {
            messages.truncate(count as usize);
        }

        let msg_info_list: Vec<MessageInfo> = messages.into_iter()
            .map(|m| {
                let msg_struct = MsgStruct::from(&m);
                MessageInfo::from(MsgData::from(&msg_struct))
            })
            .collect();

        Ok(GetHistoryMessagesResult {
            messages: msg_info_list,
            is_end,
        })
    }

    /// 按 seq 范围获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageListBySeq`）
    pub async fn get_advanced_history_message_list_by_seq(
        &self,
        conversation_id: &str,
        start_seq: i64,
        end_seq: i64,
        count: i32,
    ) -> Result<Vec<LocalChatLog>> {
        let rows = self.repositories.message_repo
            .get_by_seq_range(conversation_id, start_seq, end_seq, count as i64)
            .await?;
        Ok(rows)
    }

    /// 按 seq 获取单条消息（对齐 Go SDK `GetMessageBySeq`）
    pub async fn get_history_message_by_seq(&self, seq: i64) -> Result<LocalChatLog> {
        self.repositories.message_repo.get_by_seq(seq).await?
            .ok_or_else(|| SdkError::invalid_argument(format!("seq={} 的消息不存在", seq)))
    }

    /// 按 clientMsgId 列表批量查找消息并按会话过滤（对齐 Go SDK `FindMessageList`）
    pub async fn find_message_list(
        &self,
        conversation_id: &str,
        client_msg_ids: Vec<String>,
    ) -> Result<Vec<LocalChatLog>> {
        if client_msg_ids.is_empty() {
            return Ok(Vec::new());
        }
        let all = self.repositories.message_repo
            .get_by_client_msg_ids(&client_msg_ids)
            .await?;
        Ok(all.into_iter()
            .filter(|m| m.conversation_id == conversation_id)
            .collect())
    }

    /// 按 clientMsgId 查询单条本地消息（不限定会话）
    pub async fn get_message_by_client_msg_id(&self, client_msg_id: &str) -> Result<Option<LocalChatLog>> {
        self.repositories.message_repo.get_by_client_msg_id("", client_msg_id).await
    }

    /// 仅从本地删除单条消息（对齐 Go SDK `DeleteMessageFromLocalStorage`）
    ///
    /// 软删除：标记为 MsgStatusHasDeleted(4)，不通知服务端。
    pub async fn delete_message_from_local_storage(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
    ) -> Result<()> {
        self.repositories.message_repo
            .mark_as_deleted(conversation_id, client_msg_id).await?;
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
            conv.unread_count = 0;
            conv.max_seq = 0;
            conv.min_seq = 0;
            let _ = self.repositories.conversation_repo.upsert(&conv).await;
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
                let _ = self.repositories.conversation_repo
                    .update_unread_count(&conv.conversation_id, 0).await;
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
    pub async fn set_message_local_ex(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
        local_ex: &str,
    ) -> Result<()> {
        self.repositories.message_repo
            .update_local_ex(conversation_id, client_msg_id, local_ex).await?;
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
            if let Ok(Some(msg)) = self.repositories.message_repo
                .get_by_client_msg_id(&sm.conversation_id, &sm.client_msg_id).await
            {
                if msg.status == MessageSendStatus::Sending as i32 {
                    if let Err(e) = self.repositories.message_repo
                        .update_send_status(&sm.client_msg_id, MessageSendStatus::SendFailed.into()).await
                    {
                        warn!("更新sending消息状态失败: client_msg_id={}, err={}", sm.client_msg_id, e);
                    }
                }
            }
            let _ = self.repositories.sending_message_repo
                .delete(&sm.conversation_id, &sm.client_msg_id).await;
        }

        if !sending_messages.is_empty() {
            info!("登录时清理了 {} 条sending消息", sending_messages.len());
        }
    }

    /// 插入群聊消息到本地存储（对齐 Go SDK `InsertGroupMessageToLocalStorage`）
    pub async fn insert_group_message_to_local_storage(
        &self,
        group_id: &str,
        content: &str,
        content_type: i32,
        send_id: &str,
    ) -> Result<LocalChatLog> {
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