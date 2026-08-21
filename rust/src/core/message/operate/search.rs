//! 本地消息搜索

use super::MessageService;
use crate::sdk::client::SearchMessagesReq;
use crate::domain::error::Result;
use crate::domain::model::local::LocalChatLog;
use tracing::info;

impl MessageService {
    /// 本地搜索消息
    pub async fn search_local_messages(&self, req: SearchMessagesReq) -> Result<Vec<LocalChatLog>> {
        let count = if req.count > 0 { req.count } else { 100 };
        let results = self
            .repositories
            .message_repo
            .search_messages(
                &req.conversation_id,
                &req.keyword,
                &req.sender_user_ids,
                &req.message_types,
                req.start_time,
                req.end_time,
                req.offset.max(0),
                count,
            )
            .await?;
        info!("本地搜索消息: conv={}, keyword={}, count={}", req.conversation_id, req.keyword, results.len());
        Ok(results)
    }
}
