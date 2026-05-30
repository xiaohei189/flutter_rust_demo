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
            "INSERT INTO local_conversations (conversation_id, conversation_type, user_id, group_id, show_name, face_url, latest_msg, latest_msg_send_time, unread_count, recv_msg_opt, is_pinned, is_private_chat, burn_duration, group_at_type, is_not_in_group, update_unread_count_time, attached_info, ex, draft_text, draft_text_time, max_seq, min_seq, is_msg_destruct, msg_destruct_time) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(conversation_id) DO UPDATE SET conversation_type=excluded.conversation_type, user_id=excluded.user_id, group_id=excluded.group_id, show_name=excluded.show_name, face_url=excluded.face_url, latest_msg=excluded.latest_msg, latest_msg_send_time=excluded.latest_msg_send_time, unread_count=excluded.unread_count, recv_msg_opt=excluded.recv_msg_opt, is_pinned=excluded.is_pinned, is_private_chat=excluded.is_private_chat, burn_duration=excluded.burn_duration, group_at_type=excluded.group_at_type, is_not_in_group=excluded.is_not_in_group, update_unread_count_time=excluded.update_unread_count_time, attached_info=excluded.attached_info, ex=excluded.ex, draft_text=excluded.draft_text, draft_text_time=excluded.draft_text_time, max_seq=excluded.max_seq, min_seq=excluded.min_seq, is_msg_destruct=excluded.is_msg_destruct, msg_destruct_time=excluded.msg_destruct_time",
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
}
