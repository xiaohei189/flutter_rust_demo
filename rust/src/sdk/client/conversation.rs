use crate::domain::constant::enums::SessionType;
use crate::domain::error::types::Result;
use crate::domain::error::types::SdkError;
use crate::domain::model::conversation::Conversation;
use crate::infra::database::models::LocalConversation;
use crate::sdk::client::OpenIMClient;

impl OpenIMClient {
    /// 根据会话类型和 sourceID 生成 conversationID（对齐 Go SDK `GetConversationIDBySessionType`）
    ///
    /// - 单聊 (1): `si_{sorted(userID, sourceID)}`
    /// - 普通群聊 (2): `g_{groupID}`
    /// - 超级群聊 (3): `sg_{groupID}`
    /// - 服务端通知会话 (4): `sn_{sorted(userID, sourceID)}`
    pub fn get_conversation_id_by_session_type(&self, source_id: &str, session_type: i32) -> String {
        let user_id = self.context.get_user_id();
        match SessionType::from_i32(session_type) {
            SessionType::SingleChat => {
                let mut ids = vec![user_id.as_str(), source_id];
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
                let mut ids = vec![user_id.as_str(), source_id];
                ids.sort();
                format!("sn_{}_{}", ids[0], ids[1])
            }
        }
    }

    pub async fn get_conversations(&self) -> std::result::Result<Vec<LocalConversation>, SdkError> {
        let dao = self.conversation.dao();
        dao.get_all().await
    }

    pub async fn get_conversation(&self, conversation_id: &str) -> std::result::Result<Option<LocalConversation>, SdkError> {
        let dao = self.conversation.dao();
        dao.get_by_id(conversation_id).await
    }

    pub async fn update_conversation_unread_count(&self, conversation_id: &str, unread_count: i64) -> Result<()> {
        self.conversation.update_unread_count(conversation_id, unread_count as i32).await
    }

    pub async fn set_conversation_pinned(&self, conversation_id: &str, is_pinned: bool) -> Result<()> {
        self.conversation.set_pinned(conversation_id, is_pinned).await
    }

    pub async fn delete_conversation(&self, conversation_id: &str) -> Result<()> {
        self.conversation.delete_conversation(conversation_id).await
    }

    pub async fn set_conversation_draft(&self, conversation_id: &str, draft_text: &str) -> Result<()> {
        self.conversation.set_draft(conversation_id, draft_text).await
    }

    pub async fn set_conversation_private(&self, conversation_id: &str, is_private: bool) -> Result<()> {
        self.conversation.set_private_chat(conversation_id, is_private).await
    }

    pub async fn get_pinned_conversations(&self) -> std::result::Result<Vec<Conversation>, SdkError> {
        self.conversation.get_pinned_conversations().await
    }

    pub async fn clear_conversation_draft(&self, conversation_id: &str) -> Result<()> {
        self.conversation.clear_draft(conversation_id).await
    }

    pub async fn mark_conversation_message_as_read(&self, conversation_id: String, session_type: i32) -> Result<()> {
        self.message_service.mark_conversation_message_as_read(conversation_id, session_type).await
    }

    /// 标记所有会话消息已读（对齐 Go SDK `MarkAllConversationMessageAsRead`）
    pub async fn mark_all_conversation_as_read(&self) -> Result<()> {
        self.message_service.mark_all_conversation_as_read().await
    }

    /// 分页获取会话列表（对齐 Go SDK `GetConversationListSplit`）
    ///
    /// 过滤有消息的会话，置顶优先，按时间降序分页。
    pub async fn get_conversation_list_split(
        &self,
        offset: i64,
        count: i64,
    ) -> std::result::Result<Vec<LocalConversation>, SdkError> {
        self.conversation.dao().get_split(offset, count).await
    }

    /// 按 ID 列表批量获取会话（对齐 Go SDK `GetMultipleConversation`）
    pub async fn get_multiple_conversations(
        &self,
        conversation_ids: Vec<String>,
    ) -> std::result::Result<Vec<LocalConversation>, SdkError> {
        self.conversation.dao().get_multiple(&conversation_ids).await
    }

    /// 搜索会话（对齐 Go SDK `SearchConversation`）
    ///
    /// 按 show_name 模糊匹配。
    pub async fn search_conversations(
        &self,
        keyword: &str,
    ) -> std::result::Result<Vec<LocalConversation>, SdkError> {
        if keyword.is_empty() {
            return Err(SdkError::invalid_argument("搜索关键词不能为空"));
        }
        self.conversation.dao().search(keyword).await
    }

    /// 隐藏会话（对齐 Go SDK `HideConversation`）
    ///
    /// 重置会话的未读数、最新消息、草稿等，使其不出现在会话列表中。
    pub async fn hide_conversation(
        &self,
        conversation_id: &str,
    ) -> std::result::Result<(), SdkError> {
        self.conversation.dao().reset(conversation_id).await
    }

    /// 通用会话信息设置（对齐 Go SDK `SetConversation`）
    ///
    /// 根据 conversation_id 查找已有会话，更新传入的字段，然后 upsert。
    /// 只更新非空/非默认的字段。
    pub async fn set_conversation(
        &self,
        conversation_id: &str,
        recv_msg_opt: Option<i32>,
        is_pinned: Option<bool>,
        is_private_chat: Option<bool>,
        group_at_type: Option<i32>,
        ex: Option<&str>,
    ) -> Result<()> {
        let existing = self.conversation.get_conversation(conversation_id).await?;
        let mut conv = existing.unwrap_or_else(|| {
            crate::domain::model::conversation::Conversation {
                conversation_id: conversation_id.to_string(),
                ..Default::default()
            }
        });

        if let Some(opt) = recv_msg_opt {
            conv.recv_msg_opt = opt;
        }
        if let Some(pinned) = is_pinned {
            conv.is_pinned = pinned;
        }
        if let Some(private) = is_private_chat {
            conv.is_private_chat = private;
            conv.is_private = private;
        }
        if let Some(at_type) = group_at_type {
            conv.group_at_type = at_type;
        }
        if let Some(ex_val) = ex {
            conv.ex = ex_val.to_string();
        }

        self.conversation.upsert_conversation(conv).await
    }
}