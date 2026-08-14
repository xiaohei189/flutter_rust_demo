//! ConversationApi — SDK 对外 API 契约（分域特征）
//!
//! 由 OpenIMClient 实现，pi/ 层依赖组合特征 SdkApi。

use crate::client::OpenIMClient;
use crate::constant::SessionType;

use crate::error::{Result, SdkError};
use crate::event::events::conversation::ConversationEvent;
use crate::model::local::LocalConversation;
use async_trait::async_trait;

#[async_trait]
pub trait ConversationApi: Send + Sync {
    fn take_conv_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<ConversationEvent>, SdkError>;
    async fn sync_all_conversation_hash_read_seqs(&self) -> Result<()>;
    async fn incr_sync_conversations(&self) -> Result<()>;
    fn get_conversation_id_by_session_type(&self, source_id: &str, session_type: i32) -> String;
    async fn get_conversations(&self) -> std::result::Result<Vec<LocalConversation>, SdkError>;
    async fn get_conversation(&self, conversation_id: &str) -> std::result::Result<Option<LocalConversation>, SdkError>;
    async fn update_conversation_unread_count(&self, conversation_id: &str, unread_count: i64) -> Result<()>;
    async fn set_conversation_pinned(&self, conversation_id: &str, is_pinned: bool) -> Result<()>;
    async fn delete_conversation(&self, conversation_id: &str) -> Result<()>;
    async fn set_conversation_draft(&self, conversation_id: &str, draft_text: &str) -> Result<()>;
    async fn set_conversation_private(&self, conversation_id: &str, is_private: bool) -> Result<()>;
    async fn get_pinned_conversations(&self) -> std::result::Result<Vec<LocalConversation>, SdkError>;
    async fn clear_conversation_draft(&self, conversation_id: &str) -> Result<()>;
    async fn mark_conversation_message_as_read(&self, conversation_id: String, session_type: i32) -> Result<()>;
    async fn mark_all_conversation_as_read(&self) -> Result<()>;
    async fn get_conversation_list_split(&self, offset: i64, count: i64) -> std::result::Result<Vec<LocalConversation>, SdkError>;
    async fn get_multiple_conversations(&self, conversation_ids: Vec<String>) -> std::result::Result<Vec<LocalConversation>, SdkError>;
    async fn get_conversation_ids(&self) -> std::result::Result<Vec<String>, SdkError>;
    async fn search_conversations(&self, keyword: &str) -> std::result::Result<Vec<LocalConversation>, SdkError>;
    async fn hide_conversation(&self, conversation_id: &str) -> std::result::Result<(), SdkError>;
    async fn set_conversation(
        &self,
        conversation_id: &str,
        recv_msg_opt: Option<i32>,
        is_pinned: Option<bool>,
        is_private_chat: Option<bool>,
        group_at_type: Option<i32>,
        ex: Option<&str>,
    ) -> Result<()>;
}

#[async_trait]
impl ConversationApi for OpenIMClient {
    /// 根据会话类型和 sourceID 生成 conversationID（对齐 Go SDK `GetConversationIDBySessionType`）
    ///
    /// - 单聊 (1): `si_{sorted(userID, sourceID)}`
    /// - 普通群聊 (2): `g_{groupID}`
    /// - 超级群聊 (3): `sg_{groupID}`
    /// - 服务端通知会话 (4): `sn_{sorted(userID, sourceID)}`
    fn get_conversation_id_by_session_type(&self, source_id: &str, session_type: i32) -> String {
        let user_id = self.context.get_user_id();
        match SessionType::from_i32(session_type) {
            SessionType::SingleChat => {
                let mut ids = [user_id.as_str(), source_id];
                ids.sort();
                format!("si_{}_{}", ids[0], ids[1])
            }
            SessionType::WriteGroupChat => {
                format!("g_{}", source_id)
            }
            SessionType::ReadGroupChat => {
                format!("sg_{}", source_id)
            }
            SessionType::NotificationChat => {
                let mut ids = [user_id.as_str(), source_id];
                ids.sort();
                format!("sn_{}_{}", ids[0], ids[1])
            }
        }
    }

    #[tracing::instrument(skip_all)]
    async fn get_conversations(&self) -> std::result::Result<Vec<LocalConversation>, SdkError> {
        let conversations = self.conversation.get_all().await?;

        tracing::info!("[SDK] DB: loaded={}", conversations.len());

        Ok(conversations)
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %conversation_id))]
    async fn get_conversation(&self, conversation_id: &str) -> std::result::Result<Option<LocalConversation>, SdkError> {
        self.conversation.get_conversation(conversation_id).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %conversation_id, unread_count = %unread_count))]
    async fn update_conversation_unread_count(&self, conversation_id: &str, unread_count: i64) -> Result<()> {
        self.conversation.update_unread_count(conversation_id, unread_count as i32).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %conversation_id, is_pinned = %is_pinned))]
    async fn set_conversation_pinned(&self, conversation_id: &str, is_pinned: bool) -> Result<()> {
        self.conversation.set_pinned(conversation_id, is_pinned).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %conversation_id))]
    async fn delete_conversation(&self, conversation_id: &str) -> Result<()> {
        self.conversation.delete_conversation(conversation_id).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %conversation_id))]
    async fn set_conversation_draft(&self, conversation_id: &str, draft_text: &str) -> Result<()> {
        self.conversation.set_draft(conversation_id, draft_text).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %conversation_id, is_private = %is_private))]
    async fn set_conversation_private(&self, conversation_id: &str, is_private: bool) -> Result<()> {
        self.conversation.set_private_chat(conversation_id, is_private).await
    }

    async fn get_pinned_conversations(&self) -> std::result::Result<Vec<LocalConversation>, SdkError> {
        self.conversation.get_pinned_conversations().await
    }

    async fn clear_conversation_draft(&self, conversation_id: &str) -> Result<()> {
        self.conversation.clear_draft(conversation_id).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %conversation_id, session_type = %session_type))]
    async fn mark_conversation_message_as_read(&self, conversation_id: String, session_type: i32) -> Result<()> {
        self.message_service.mark_conversation_message_as_read(conversation_id, session_type).await
    }

    /// 标记所有会话消息已读（对齐 Go SDK `MarkAllConversationMessageAsRead`）
    #[tracing::instrument(skip_all)]
    async fn mark_all_conversation_as_read(&self) -> Result<()> {
        self.message_service.mark_all_conversation_as_read().await
    }

    /// 分页获取会话列表（对齐 Go SDK `GetConversationListSplit`）
    ///
    /// 过滤有消息的会话，置顶优先，按时间降序分页。
    async fn get_conversation_list_split(&self, offset: i64, count: i64) -> std::result::Result<Vec<LocalConversation>, SdkError> {
        self.conversation.get_split(offset, count).await
    }

    /// 按 ID 列表批量获取会话（对齐 Go SDK `GetMultipleConversation`）
    async fn get_multiple_conversations(&self, conversation_ids: Vec<String>) -> std::result::Result<Vec<LocalConversation>, SdkError> {
        self.conversation.get_multiple(&conversation_ids).await
    }

    /// 搜索会话（对齐 Go SDK `SearchConversation`）
    ///
    /// 按 show_name 模糊匹配。
    async fn get_conversation_ids(&self) -> std::result::Result<Vec<String>, SdkError> {
        self.conversation_syncer.get_all_conversation_ids().await
    }

    async fn search_conversations(&self, keyword: &str) -> std::result::Result<Vec<LocalConversation>, SdkError> {
        if keyword.is_empty() {
            return Err(SdkError::invalid_argument("搜索关键词不能为空"));
        }
        self.conversation.search(keyword).await
    }

    /// 隐藏会话（对齐 Go SDK `HideConversation`）
    ///
    /// 重置会话的未读数、最新消息、草稿等，使其不出现在会话列表中。
    #[tracing::instrument(skip_all, fields(conversation_id = %conversation_id))]
    async fn hide_conversation(&self, conversation_id: &str) -> std::result::Result<(), SdkError> {
        self.conversation.reset(conversation_id).await
    }

    /// 通用会话信息设置（对齐 Go SDK `SetConversation`）
    ///
    /// 根据 conversation_id 查找已有会话，更新传入的字段，然后 upsert。
    /// 只更新非空/非默认的字段。
    #[tracing::instrument(skip_all, fields(conversation_id = %conversation_id))]
    async fn set_conversation(
        &self,
        conversation_id: &str,
        recv_msg_opt: Option<i32>,
        is_pinned: Option<bool>,
        is_private_chat: Option<bool>,
        group_at_type: Option<i32>,
        ex: Option<&str>,
    ) -> Result<()> {
        self.conversation.set_conversation(conversation_id, recv_msg_opt, is_pinned, is_private_chat, group_at_type, ex).await
    }

    /// 获取会话事件接收器（只能调用一次，重复调用返回错误）
    fn take_conv_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<ConversationEvent>, SdkError> {
        self.listeners.take_conv_rx().ok_or_else(|| SdkError::unknown("conversation receiver already taken"))
    }

    async fn sync_all_conversation_hash_read_seqs(&self) -> Result<()> {
        self.conversation_syncer.sync_conversation_hash_read_seqs(&self.message_processor.max_seq_recorder).await
    }

    async fn incr_sync_conversations(&self) -> Result<()> {
        self.conversation_syncer.sync_incremental_with_lock().await?;
        Ok(())
    }
}
