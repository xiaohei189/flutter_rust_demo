use crate::domain::error::types::Result;
use crate::infra::database::models::LocalChatLog;
use async_trait::async_trait;

/// 消息仓库接口
#[async_trait]
pub trait MessageRepository: Send + Sync {
    async fn batch_insert(&self, logs: &[LocalChatLog]) -> Result<()>;
    async fn get_by_conversation(&self, conversation_id: &str, start_time: i64, count: i64) -> Result<Vec<LocalChatLog>>;
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
    async fn get_latest(&self, conversation_id: &str, limit: i32) -> Result<Vec<LocalChatLog>>;
}

