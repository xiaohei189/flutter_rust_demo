//! 本地消息搜索

use super::MessageService;
use crate::domain::error::types::Result;
use crate::infra::database::models::LocalChatLog;
use tracing::info;

impl MessageService {
    /// 本地搜索消息
    pub async fn search_local_messages(
        &self,
        conversation_id: String,
        keyword: String,
        max_count: i64,
    ) -> Result<Vec<LocalChatLog>> {
        let results = self.stores.message_dao.search_by_keyword(&conversation_id, &keyword, max_count).await?;
        info!("本地搜索消息: conv={}, keyword={}, count={}", conversation_id, keyword, results.len());
        Ok(results)
    }
}
