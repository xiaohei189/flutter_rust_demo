use crate::domain::constant::enums::SessionType;
use crate::domain::error::types::Result;
use crate::domain::error::types::SdkError;
use crate::domain::model::conversation::Conversation;
use crate::infra::database::models::LocalConversation;
use crate::sdk::client::OpenIMClient;

impl OpenIMClient {
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

    pub async fn mark_conversation_as_read(&self, conversation_id: String, session_type: i32) -> Result<()> {
        self.message_service.mark_conversation_as_read(conversation_id, session_type).await
    }
}