use super::models::LocalConversation;
use crate::domain::error::types::{Result, SdkError};
use sqlx::SqlitePool;

pub struct ConversationDao {
    pool: SqlitePool,
}

impl ConversationDao {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub async fn upsert(&self, conv: &LocalConversation) -> Result<()> {
        sqlx::query(
            "INSERT INTO local_conversations (conversation_id, conversation_type, user_id, group_id, show_name, face_url, latest_msg, latest_msg_send_time, unread_count, recv_msg_opt, is_pinned, is_private_chat, burn_duration, group_at_type, is_not_in_group, update_unread_count_time, attached_info, ex, draft_text, draft_text_time, max_seq, min_seq, is_msg_destruct, msg_destruct_time) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(conversation_id) DO UPDATE SET conversation_type=excluded.conversation_type, user_id=excluded.user_id, group_id=excluded.group_id, show_name=excluded.show_name, face_url=excluded.face_url, latest_msg=excluded.latest_msg, latest_msg_send_time=excluded.latest_msg_send_time, recv_msg_opt=excluded.recv_msg_opt, is_pinned=excluded.is_pinned, is_private_chat=excluded.is_private_chat, burn_duration=excluded.burn_duration, group_at_type=excluded.group_at_type, is_not_in_group=excluded.is_not_in_group, update_unread_count_time=excluded.update_unread_count_time, attached_info=excluded.attached_info, ex=excluded.ex, draft_text=excluded.draft_text, draft_text_time=excluded.draft_text_time, max_seq=excluded.max_seq, min_seq=excluded.min_seq, is_msg_destruct=excluded.is_msg_destruct, msg_destruct_time=excluded.msg_destruct_time",
        )
        .bind(&conv.conversation_id)
        .bind(conv.conversation_type)
        .bind(&conv.user_id)
        .bind(&conv.group_id)
        .bind(&conv.show_name)
        .bind(&conv.face_url)
        .bind(&conv.latest_msg)
        .bind(conv.latest_msg_send_time)
        .bind(conv.unread_count)
        .bind(conv.recv_msg_opt)
        .bind(conv.is_pinned)
        .bind(conv.is_private_chat)
        .bind(conv.burn_duration)
        .bind(conv.group_at_type)
        .bind(conv.is_not_in_group)
        .bind(conv.update_unread_count_time)
        .bind(&conv.attached_info)
        .bind(&conv.ex)
        .bind(&conv.draft_text)
        .bind(conv.draft_text_time)
        .bind(conv.max_seq)
        .bind(conv.min_seq)
        .bind(conv.is_msg_destruct)
        .bind(conv.msg_destruct_time)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("upsert conversation: {}", e)))?;
        Ok(())
    }

    pub async fn get_all(&self) -> Result<Vec<LocalConversation>> {
        let rows = sqlx::query_as::<_, LocalConversation>(
            "SELECT * FROM local_conversations ORDER BY is_pinned DESC, latest_msg_send_time DESC",
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query conversations: {}", e)))?;
        Ok(rows)
    }

    pub async fn get_by_id(&self, conversation_id: &str) -> Result<Option<LocalConversation>> {
        let row = sqlx::query_as::<_, LocalConversation>(
            "SELECT * FROM local_conversations WHERE conversation_id = ?",
        )
        .bind(conversation_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query conversation: {}", e)))?;
        Ok(row)
    }

    pub async fn update_max_seq(&self, conversation_id: &str, seq: i64) -> Result<()> {
        sqlx::query(
            "UPDATE local_conversations SET max_seq = MAX(max_seq, ?) WHERE conversation_id = ?",
        )
        .bind(seq)
        .bind(conversation_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("update max seq: {}", e)))?;
        Ok(())
    }

    pub async fn update_after_new_message(
        &self,
        conversation_id: &str,
        latest_msg: &str,
        latest_msg_send_time: i64,
        seq: i64,
    ) -> Result<()> {
        sqlx::query(
            "UPDATE local_conversations SET latest_msg = ?, latest_msg_send_time = ?, max_seq = MAX(max_seq, ?), unread_count = unread_count + 1 WHERE conversation_id = ?",
        )
        .bind(latest_msg)
        .bind(latest_msg_send_time)
        .bind(seq)
        .bind(conversation_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("update conversation: {}", e)))?;
        Ok(())
    }

    pub async fn update_after_sent_message(
        &self,
        conversation_id: &str,
        latest_msg: &str,
        latest_msg_send_time: i64,
    ) -> Result<()> {
        sqlx::query(
            "UPDATE local_conversations SET latest_msg = ?, latest_msg_send_time = ? WHERE conversation_id = ? AND latest_msg_send_time < ?",
        )
        .bind(latest_msg)
        .bind(latest_msg_send_time)
        .bind(conversation_id)
        .bind(latest_msg_send_time)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("update conversation after sent: {}", e)))?;
        Ok(())
    }

    pub async fn delete(&self, conversation_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_conversations WHERE conversation_id = ?")
            .bind(conversation_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("delete conversation: {}", e)))?;
        Ok(())
    }

    pub async fn get_max_seq(&self, conversation_id: &str) -> Result<i64> {
        let row: (Option<i64>,) =
            sqlx::query_as("SELECT max_seq FROM local_conversations WHERE conversation_id = ?")
                .bind(conversation_id)
                .fetch_one(&self.pool)
                .await
                .map_err(|e| SdkError::database(format!("query max seq: {}", e)))?;
        Ok(row.0.unwrap_or(0))
    }

    pub async fn get_all_seq_pairs(&self) -> Result<Vec<(String, i64)>> {
        let rows: Vec<(String, i64)> = sqlx::query_as(
            "SELECT conversation_id, max_seq FROM local_conversations",
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query seq pairs: {}", e)))?;
        Ok(rows)
    }

    pub async fn set_pinned(&self, conversation_id: &str, is_pinned: bool) -> Result<()> {
        sqlx::query(
            "UPDATE local_conversations SET is_pinned = ? WHERE conversation_id = ?",
        )
        .bind(if is_pinned { 1 } else { 0 })
        .bind(conversation_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("set pinned: {}", e)))?;
        Ok(())
    }

    pub async fn set_private_chat(&self, conversation_id: &str, is_private: bool) -> Result<()> {
        sqlx::query(
            "UPDATE local_conversations SET is_private_chat = ? WHERE conversation_id = ?",
        )
        .bind(if is_private { 1 } else { 0 })
        .bind(conversation_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("set private chat: {}", e)))?;
        Ok(())
    }

    pub async fn update_unread_count(&self, conversation_id: &str, unread_count: i32) -> Result<()> {
        sqlx::query(
            "UPDATE local_conversations SET unread_count = ? WHERE conversation_id = ?",
        )
        .bind(unread_count)
        .bind(conversation_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("update unread count: {}", e)))?;
        Ok(())
    }

    pub async fn get_unread_count(&self, conversation_id: &str) -> Result<i32> {
        let row: (Option<i32>,) = sqlx::query_as(
            "SELECT unread_count FROM local_conversations WHERE conversation_id = ?",
        )
        .bind(conversation_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query unread count: {}", e)))?;
        Ok(row.0.unwrap_or(0))
    }

    pub async fn get_total_unread_count(&self) -> Result<i64> {
        let row: (Option<i64>,) = sqlx::query_as(
            "SELECT COALESCE(SUM(unread_count), 0) FROM local_conversations",
        )
        .fetch_one(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query total unread count: {}", e)))?;
        Ok(row.0.unwrap_or(0))
    }

    pub async fn set_draft(&self, conversation_id: &str, draft_text: &str, draft_time: i64) -> Result<()> {
        sqlx::query(
            "UPDATE local_conversations SET draft_text = ?, draft_text_time = ? WHERE conversation_id = ?",
        )
        .bind(draft_text)
        .bind(draft_time)
        .bind(conversation_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("set draft: {}", e)))?;
        Ok(())
    }

    pub async fn get_pinned(&self) -> Result<Vec<LocalConversation>> {
        let rows = sqlx::query_as::<_, LocalConversation>(
            "SELECT * FROM local_conversations WHERE is_pinned = 1 ORDER BY latest_msg_send_time DESC",
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query pinned: {}", e)))?;
        Ok(rows)
    }

    pub async fn count(&self) -> Result<usize> {
        let row: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM local_conversations")
            .fetch_one(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("count conversations: {}", e)))?;
        Ok(row.0 as usize)
    }

    /// 获取会话的 min_seq（对齐 Go SDK `getConversationMinSeq`）
    pub async fn get_min_seq(&self, conversation_id: &str) -> Result<i64> {
        let row: (Option<i64>,) = sqlx::query_as(
            "SELECT min_seq FROM local_conversations WHERE conversation_id = ?",
        )
        .bind(conversation_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query min_seq: {}", e)))?;
        Ok(row.0.unwrap_or(0))
    }

    /// 更新会话的 min_seq（对齐 Go SDK `setConversationMinSeq`）
    pub async fn update_min_seq(&self, conversation_id: &str, seq: i64) -> Result<()> {
        sqlx::query(
            "UPDATE local_conversations SET min_seq = ? WHERE conversation_id = ? AND min_seq < ?",
        )
        .bind(seq)
        .bind(conversation_id)
        .bind(seq)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("update min_seq: {}", e)))?;
        Ok(())
    }

    pub async fn clear_all(&self) -> Result<()> {
        sqlx::query("DELETE FROM local_conversations")
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("clear all: {}", e)))?;
        Ok(())
    }

    /// 分页获取会话列表（对齐 Go SDK `GetConversationListSplitDB`）
    ///
    /// 过滤 latest_msg_send_time > 0 的会话，置顶优先，按时间降序。
    pub async fn get_split(&self, offset: i64, count: i64) -> Result<Vec<LocalConversation>> {
        let rows = sqlx::query_as::<_, LocalConversation>(
            "SELECT * FROM local_conversations \
             WHERE latest_msg_send_time > 0 \
             ORDER BY CASE WHEN is_pinned = 1 THEN 0 ELSE 1 END, \
                      MAX(latest_msg_send_time, draft_text_time) DESC \
             LIMIT ? OFFSET ?"
        )
        .bind(count)
        .bind(offset)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("get_split: {}", e)))?;
        Ok(rows)
    }

    /// 按 ID 列表批量获取会话（对齐 Go SDK `GetMultipleConversationDB`）
    pub async fn get_multiple(&self, conversation_ids: &[String]) -> Result<Vec<LocalConversation>> {
        if conversation_ids.is_empty() {
            return Ok(Vec::new());
        }
        let mut query = String::from("SELECT * FROM local_conversations WHERE conversation_id IN (");
        for (i, id) in conversation_ids.iter().enumerate() {
            if i > 0 { query.push(','); }
            query.push_str(&format!("'{}'", id.replace('\'', "''")));
        }
        query.push(')');
        let rows = sqlx::query_as::<_, LocalConversation>(&query)
            .fetch_all(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("get_multiple: {}", e)))?;
        Ok(rows)
    }

    /// 按名称搜索会话（对齐 Go SDK `SearchConversations`）
    ///
    /// 模糊匹配 show_name，按 latest_msg_send_time 降序。
    pub async fn search(&self, keyword: &str) -> Result<Vec<LocalConversation>> {
        let pattern = format!("%{}%", keyword);
        let rows = sqlx::query_as::<_, LocalConversation>(
            "SELECT * FROM local_conversations \
             WHERE show_name LIKE ? \
             ORDER BY latest_msg_send_time DESC"
        )
        .bind(&pattern)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("search: {}", e)))?;
        Ok(rows)
    }

    /// 重置/隐藏会话（对齐 Go SDK `ResetConversation`）
    ///
    /// 将 unread_count、latest_msg、latest_msg_send_time、draft_text、draft_text_time 清零。
    /// 因为 get_split 过滤 latest_msg_send_time > 0，清零后该会话不再出现在列表中。
    pub async fn reset(&self, conversation_id: &str) -> Result<()> {
        let rows_affected = sqlx::query(
            "UPDATE local_conversations \
             SET unread_count = 0, latest_msg = '', latest_msg_send_time = 0, \
                 draft_text = '', draft_text_time = 0 \
             WHERE conversation_id = ?"
        )
        .bind(conversation_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("reset: {}", e)))?
        .rows_affected();

        if rows_affected == 0 {
            return Err(SdkError::database(format!("reset: 会话 {} 不存在", conversation_id)));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

    fn make_conv(id: &str) -> LocalConversation {
        LocalConversation {
            conversation_id: id.into(),
            conversation_type: 1,
            user_id: "user_1".into(),
            group_id: String::new(),
            show_name: "test".into(),
            face_url: String::new(),
            latest_msg: String::new(),
            latest_msg_send_time: 0,
            unread_count: 0,
            recv_msg_opt: 0,
            is_pinned: 0,
            is_private_chat: 0,
            burn_duration: 0,
            group_at_type: 0,
            is_not_in_group: 0,
            update_unread_count_time: 0,
            attached_info: String::new(),
            ex: String::new(),
            draft_text: String::new(),
            draft_text_time: 0,
            max_seq: 0,
            min_seq: 0,
            is_msg_destruct: 0,
            msg_destruct_time: 0,
        }
    }

    #[tokio::test]
    async fn test_upsert_and_get() {
        let pool = create_pool_memory().await.unwrap();
        let dao = ConversationDao::new(pool);

        dao.upsert(&make_conv("conv_1")).await.unwrap();
        let all = dao.get_all().await.unwrap();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].conversation_id, "conv_1");
    }

    #[tokio::test]
    async fn test_update_max_seq() {
        let pool = create_pool_memory().await.unwrap();
        let dao = ConversationDao::new(pool);

        dao.upsert(&make_conv("conv_1")).await.unwrap();
        dao.update_max_seq("conv_1", 42).await.unwrap();
        let seq = dao.get_max_seq("conv_1").await.unwrap();
        assert_eq!(seq, 42);
    }

    #[tokio::test]
    async fn test_update_after_sent_message() {
        let pool = create_pool_memory().await.unwrap();
        let dao = ConversationDao::new(pool);

        dao.upsert(&make_conv("conv_1")).await.unwrap();
        dao.update_after_sent_message("conv_1", "{\"text\":\"hello\"}", 3000)
            .await
            .unwrap();

        let conv = dao.get_by_id("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.latest_msg_send_time, 3000);
        assert_eq!(conv.unread_count, 0);
        assert_eq!(conv.latest_msg, "{\"text\":\"hello\"}");
    }

    #[tokio::test]
    async fn test_update_after_new_message() {
        let pool = create_pool_memory().await.unwrap();
        let dao = ConversationDao::new(pool);

        dao.upsert(&make_conv("conv_1")).await.unwrap();
        dao.update_after_new_message("conv_1", "{\"text\":\"hello\"}", 2000, 2)
            .await
            .unwrap();

        let conv = dao.get_by_id("conv_1").await.unwrap().unwrap();
        assert_eq!(conv.max_seq, 2);
        assert_eq!(conv.unread_count, 1);
        assert_eq!(conv.latest_msg_send_time, 2000);
    }

    #[tokio::test]
    async fn test_update_unread_count() {
        let pool = create_pool_memory().await.unwrap();
        let dao = ConversationDao::new(pool);

        let mut conv = make_conv("conv_1");
        conv.unread_count = 5;
        dao.upsert(&conv).await.unwrap();

        dao.update_unread_count("conv_1", 10).await.unwrap();

        let result = dao.get_by_id("conv_1").await.unwrap().unwrap();
        assert_eq!(result.unread_count, 10);
    }
}
