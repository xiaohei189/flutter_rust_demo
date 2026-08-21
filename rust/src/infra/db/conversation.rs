use crate::domain::error::Result;
use crate::domain::model::local::LocalConversation;
use async_trait::async_trait;

/// 会话仓库接口
#[async_trait]
pub trait ConversationRepository: Send + Sync {
    async fn upsert(&self, conv: &LocalConversation) -> Result<()>;
    async fn upsert_preserving_local_fields(&self, conv: &LocalConversation) -> Result<()>;
    async fn get_by_id(&self, conversation_id: &str) -> Result<Option<LocalConversation>>;
    async fn get_all(&self) -> Result<Vec<LocalConversation>>;
    async fn update_unread_count(&self, conversation_id: &str, count: i32) -> Result<()>;
    async fn update_after_new_message(&self, conversation_id: &str, latest_msg: &str, send_time: i64, seq: i64) -> Result<()>;
    async fn delete(&self, conversation_id: &str) -> Result<()>;
    async fn batch_delete(&self, conversation_ids: &[String]) -> Result<()>;
    async fn get_all_ids(&self) -> Result<Vec<String>>;
    async fn update_draft(&self, conversation_id: &str, draft_text: &str, draft_time: i64) -> Result<()>;
    async fn reset_unread_count(&self, conversation_id: &str) -> Result<()>;
    async fn toggle_pin(&self, conversation_id: &str, is_pinned: bool) -> Result<()>;
    async fn get_total_unread_count(&self) -> Result<i32>;
    async fn get_total_count(&self) -> Result<i32>;
    // --- 以下为 manager 中使用的额外方法 ---
    async fn set_pinned(&self, conversation_id: &str, is_pinned: bool) -> Result<()>;
    async fn set_private_chat(&self, conversation_id: &str, is_private: bool) -> Result<()>;
    async fn update_partial(
        &self,
        conversation_id: &str,
        recv_msg_opt: Option<i32>,
        is_pinned: Option<bool>,
        is_private_chat: Option<bool>,
        group_at_type: Option<i32>,
        ex: Option<&str>,
    ) -> Result<()>;
    async fn set_draft(&self, conversation_id: &str, draft_text: &str, draft_time: i64) -> Result<()>;
    async fn get_pinned(&self) -> Result<Vec<LocalConversation>>;
    async fn count(&self) -> Result<i32>;
    async fn clear_all(&self) -> Result<()>;
    async fn update_latest_msg(&self, conversation_id: &str, latest_msg: &str, send_time: i64) -> Result<()>;
    async fn get_max_seq(&self, conversation_id: &str) -> Result<i64>;
    async fn update_after_sent_message(&self, conversation_id: &str, latest_msg: &str, send_time: i64) -> Result<()>;
    async fn get_all_seq_pairs(&self) -> Result<Vec<(String, i64)>>;
    async fn get_min_seq(&self, conversation_id: &str) -> Result<i64>;
    async fn update_min_seq(&self, conversation_id: &str, seq: i64) -> Result<()>;
    async fn update_max_seq(&self, conversation_id: &str, seq: i64) -> Result<()>;
    async fn get_split(&self, offset: i64, count: i64) -> Result<Vec<LocalConversation>>;
    async fn get_multiple(&self, conversation_ids: &[String]) -> Result<Vec<LocalConversation>>;
    async fn search(&self, keyword: &str) -> Result<Vec<LocalConversation>>;
    async fn reset(&self, conversation_id: &str) -> Result<()>;
    async fn increase_unread_count(&self, conversation_id: &str, seq: i64) -> Result<()>;
    async fn get_unread_count(&self, conversation_id: &str) -> Result<i32>;
    async fn get_by_multiple(&self, conversation_ids: &[String]) -> Result<Vec<LocalConversation>>;
}
