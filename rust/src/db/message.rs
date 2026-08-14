use crate::error::Result;
use crate::model::local::LocalChatLog;
use async_trait::async_trait;

/// 消息仓库接口
#[async_trait]
pub trait MessageRepository: Send + Sync {
    async fn batch_insert(&self, logs: &[LocalChatLog]) -> Result<()>;
    async fn get_by_conversation(&self, conversation_id: &str, start_time: i64, count: i64) -> Result<Vec<LocalChatLog>>;
    /// 分页获取起始消息之前的历史消息（对齐 Go GetMessageList 非反向分支）
    async fn get_by_conversation_before(&self, conversation_id: &str, start_time: i64, start_seq: i64, start_client_msg_id: &str, count: i64) -> Result<Vec<LocalChatLog>>;
    /// 分页获取起始消息之后的历史消息（对齐 Go GetMessageList 反向分支）
    async fn get_by_conversation_after(&self, conversation_id: &str, start_time: i64, start_seq: i64, start_client_msg_id: &str, count: i64) -> Result<Vec<LocalChatLog>>;
    async fn get_max_seq(&self, conversation_id: &str) -> Result<i64>;
    async fn get_by_client_msg_id(&self, conversation_id: &str, client_msg_id: &str) -> Result<Option<LocalChatLog>>;
    async fn get_by_seq(&self, seq: i64) -> Result<Option<LocalChatLog>>;
    async fn get_by_conversation_and_seq(&self, conversation_id: &str, seq: i64) -> Result<Option<LocalChatLog>>;
    async fn get_by_client_msg_ids(&self, client_msg_ids: &[String]) -> Result<Vec<LocalChatLog>>;
    async fn mark_as_read_by_seqs(&self, conversation_id: &str, seqs: &[i64], user_id: &str) -> Result<()>;
    async fn delete_by_conversation(&self, conversation_id: &str) -> Result<()>;
    async fn delete_by_seqs(&self, conversation_id: &str, seqs: &[i64]) -> Result<()>;
    async fn search_by_content(&self, conversation_id: &str, keyword: &str) -> Result<Vec<LocalChatLog>>;
    async fn update_status(&self, client_msg_id: &str, status: i32) -> Result<()>;
    async fn update_to_sent(&self, client_msg_id: &str, server_msg_id: &str, seq: i64, send_time: i64) -> Result<()>;
    async fn get_seqs_in_range(&self, conversation_id: &str, min_seq: i64, max_seq: i64) -> Result<Vec<i64>>;
    async fn get_by_seq_range(&self, conversation_id: &str, start_seq: i64, end_seq: i64, count: i64) -> Result<Vec<LocalChatLog>>;
    /// 获取指定会话的最新 N 条消息
    async fn get_by_seqs(&self, conversation_id: &str, seqs: &[i64]) -> Result<Vec<LocalChatLog>>;
    async fn mark_as_read_by_seqs_all(&self, conversation_id: &str, seqs: &[i64]) -> Result<()>;
    async fn batch_update_seq(&self, updates: &[(String, i64)]) -> Result<()>;
    async fn update_content_type(&self, conversation_id: &str, client_msg_id: &str, content_type: i32) -> Result<()>;
    async fn update_message_content_and_type(&self, conversation_id: &str, client_msg_id: &str, content: &str, content_type: i32) -> Result<()>;
    async fn search_by_content_type(&self, conversation_id: &str, content_type: i32) -> Result<Vec<LocalChatLog>>;
    async fn update_send_status(&self, client_msg_id: &str, status: i32) -> Result<()>;
    async fn update_after_send_success(&self, client_msg_id: &str, server_msg_id: &str, send_time: i64) -> Result<()>;
    async fn get_peer_normal_msg_seq(&self, conversation_id: &str, user_id: &str) -> Result<i64>;
    async fn delete_by_client_msg_id(&self, conversation_id: &str, client_msg_id: &str) -> Result<()>;
    async fn get_latest(&self, conversation_id: &str, limit: i64) -> Result<Vec<LocalChatLog>>;
    async fn get_latest_for_conversations(&self, conversation_ids: &[String]) -> Result<Vec<LocalChatLog>>;
    async fn get_unread_messages(&self, conversation_id: &str, user_id: &str) -> Result<Vec<LocalChatLog>>;
    async fn mark_as_read_by_client_msg_ids(&self, conversation_id: &str, client_msg_ids: &[String], user_id: &str) -> Result<()>;
    async fn mark_as_read_by_max_seq(&self, conversation_id: &str, max_seq: i64, user_id: &str) -> Result<()>;
    async fn search_by_keyword(&self, conversation_id: &str, keyword: &str, max_count: i64) -> Result<Vec<LocalChatLog>>;
    async fn search_messages(
        &self,
        conversation_id: &str,
        keyword: &str,
        sender_user_ids: &[String],
        message_types: &[i32],
        start_time: i64,
        end_time: i64,
        offset: i64,
        count: i64,
    ) -> Result<Vec<LocalChatLog>>;
    async fn get_by_conversation_asc(&self, conversation_id: &str, start_time: i64, count: i64) -> Result<Vec<LocalChatLog>>;
    async fn mark_as_deleted(&self, conversation_id: &str, client_msg_id: &str) -> Result<()>;
    async fn delete_all(&self) -> Result<()>;
    async fn mark_all_as_deleted(&self) -> Result<()>;
    async fn update_local_ex(&self, conversation_id: &str, client_msg_id: &str, local_ex: &str) -> Result<()>;
}
