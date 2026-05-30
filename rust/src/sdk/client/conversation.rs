use crate::domain::error::types::Result;
use crate::domain::error::types::SdkError;
use crate::domain::model::conversation::Conversation;
use crate::infra::database::models::LocalConversation;
use crate::sdk::client::OpenIMClient;

impl OpenIMClient {
    /// 获取所有会话列表
    pub async fn get_conversations(&self) -> std::result::Result<Vec<LocalConversation>, SdkError> {
        let dao = self.conversation.dao();
        dao.get_all().await
    }

    /// 获取单个会话
    pub async fn get_conversation(&self, conversation_id: String) -> std::result::Result<Option<LocalConversation>, SdkError> {
        let dao = self.conversation.dao();
        dao.get_by_id(&conversation_id).await
    }

    /// 更新会话未读数
    pub async fn update_conversation_unread_count(&self, conversation_id: String, unread_count: i64) -> Result<()> {
        self.conversation.update_unread_count(&conversation_id, unread_count as i32).await
    }

    /// 设置会话置顶
    pub async fn set_conversation_pinned(&self, conversation_id: String, is_pinned: bool) -> Result<()> {
        self.conversation.set_pinned(&conversation_id, is_pinned).await
    }

    /// 删除会话
    pub async fn delete_conversation(&self, conversation_id: String) -> Result<()> {
        self.conversation.delete_conversation(&conversation_id).await
    }

    /// 设置会话草稿
    pub async fn set_conversation_draft(&self, conversation_id: String, draft_text: String) -> Result<()> {
        self.conversation.set_draft(&conversation_id, &draft_text).await
    }

    /// 设置会话私聊模式
    pub async fn set_conversation_private(&self, conversation_id: String, is_private: bool) -> Result<()> {
        self.conversation.set_private_chat(&conversation_id, is_private).await
    }

    /// 获取置顶会话
    pub async fn get_pinned_conversations(&self) -> std::result::Result<Vec<Conversation>, SdkError> {
        self.conversation.get_pinned_conversations().await
    }

    /// 清除会话草稿
    pub async fn clear_conversation_draft(&self, conversation_id: String) -> Result<()> {
        self.conversation.clear_draft(&conversation_id).await
    }
}
