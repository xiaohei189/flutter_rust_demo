use super::models::LocalChatLog;
use crate::domain::error::types::{Result, SdkError};
use sqlx::SqlitePool;

pub struct MessageDao {
    pool: SqlitePool,
}

impl MessageDao {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub async fn batch_insert(&self, logs: &[LocalChatLog]) -> Result<()> {
        for log in logs {
            sqlx::query(
                "INSERT OR IGNORE INTO local_chat_logs (conversation_id, client_msg_id, server_msg_id, send_id, recv_id, sender_platform_id, sender_nick_name, sender_face_url, session_type, msg_from, content_type, content, is_read, status, seq, send_time, create_time, attached_info, ex, local_ex, group_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            )
            .bind(&log.conversation_id)
            .bind(&log.client_msg_id)
            .bind(&log.server_msg_id)
            .bind(&log.send_id)
            .bind(&log.recv_id)
            .bind(log.sender_platform_id)
            .bind(&log.sender_nick_name)
            .bind(&log.sender_face_url)
            .bind(log.session_type)
            .bind(log.msg_from)
            .bind(log.content_type)
            .bind(&log.content)
            .bind(log.is_read)
            .bind(log.status)
            .bind(log.seq)
            .bind(log.send_time)
            .bind(log.create_time)
            .bind(&log.attached_info)
            .bind(&log.ex)
            .bind(&log.local_ex)
            .bind(&log.group_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("insert message: {}", e)))?;
        }
        Ok(())
    }

    pub async fn get_by_conversation(
        &self,
        conversation_id: &str,
        start_seq: i64,
        count: i64,
    ) -> Result<Vec<LocalChatLog>> {
        let rows = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? AND (seq < ? OR ? = 0) ORDER BY seq DESC LIMIT ?",
        )
        .bind(conversation_id)
        .bind(start_seq)
        .bind(start_seq)
        .bind(count)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query messages: {}", e)))?;
        Ok(rows)
    }

    pub async fn get_max_seq(&self, conversation_id: &str) -> Result<i64> {
        let row: (Option<i64>,) = sqlx::query_as(
            "SELECT MAX(seq) FROM local_chat_logs WHERE conversation_id = ?",
        )
        .bind(conversation_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query max seq: {}", e)))?;
        Ok(row.0.unwrap_or(0))
    }

    pub async fn get_by_client_msg_ids(&self, client_msg_ids: &[String]) -> Result<Vec<LocalChatLog>> {
        if client_msg_ids.is_empty() {
            return Ok(Vec::new());
        }
        let placeholders = client_msg_ids.iter().map(|_| "?").collect::<Vec<_>>().join(", ");
        let query = format!(
            "SELECT * FROM local_chat_logs WHERE client_msg_id IN ({})",
            placeholders
        );
        let mut builder = sqlx::query_as::<_, LocalChatLog>(&query);
        for id in client_msg_ids {
            builder = builder.bind(id);
        }
        let rows = builder.fetch_all(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("query by client_msg_ids: {}", e)))?;
        Ok(rows)
    }

    pub async fn get_latest(
        &self,
        conversation_id: &str,
        limit: i64,
    ) -> Result<Vec<LocalChatLog>> {
        let rows = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? ORDER BY send_time DESC LIMIT ?",
        )
        .bind(conversation_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query latest: {}", e)))?;
        Ok(rows)
    }

    pub async fn delete_by_conversation(&self, conversation_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_chat_logs WHERE conversation_id = ?")
            .bind(conversation_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("delete by conversation: {}", e)))?;

        Ok(())
    }

    pub async fn update_send_status(&self, client_msg_id: &str, status: i32) -> Result<()> {
        sqlx::query("UPDATE local_chat_logs SET status = ? WHERE client_msg_id = ?")
            .bind(status)
            .bind(client_msg_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("update send status: {}", e)))?;
        Ok(())
    }

    pub async fn mark_as_read_by_max_seq(&self, conversation_id: &str, max_seq: i64) -> Result<()> {
        sqlx::query(
            "UPDATE local_chat_logs SET is_read = 1 WHERE conversation_id = ? AND seq <= ? AND seq > 0 AND send_id != ?",
        )
            .bind(conversation_id)
            .bind(max_seq)
            .bind(conversation_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("mark as read by max seq: {}", e)))?;
        Ok(())
    }

    pub async fn delete_by_client_msg_id(&self, conversation_id: &str, client_msg_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_chat_logs WHERE conversation_id = ? AND client_msg_id = ?")
            .bind(conversation_id)
            .bind(client_msg_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("delete message by client_msg_id: {}", e)))?;
        Ok(())
    }

    pub async fn update_content_type(&self, conversation_id: &str, client_msg_id: &str, content_type: i32) -> Result<()> {
        sqlx::query("UPDATE local_chat_logs SET content_type = ? WHERE conversation_id = ? AND client_msg_id = ?")
            .bind(content_type)
            .bind(conversation_id)
            .bind(client_msg_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("update content_type: {}", e)))?;
        Ok(())
    }

    pub async fn search_by_keyword(&self, conversation_id: &str, keyword: &str, max_count: i64) -> Result<Vec<LocalChatLog>> {
        let pattern = format!("%{}%", keyword);
        let rows = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? AND content LIKE ? ORDER BY send_time DESC LIMIT ?",
        )
        .bind(conversation_id)
        .bind(&pattern)
        .bind(max_count)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("search messages: {}", e)))?;
        Ok(rows)
    }

    pub async fn mark_as_read_by_seqs(&self, conversation_id: &str, seqs: &[i64]) -> Result<()> {
        if seqs.is_empty() {
            return Ok(());
        }
        let placeholders = seqs.iter().map(|_| "?").collect::<Vec<_>>().join(",");
        let sql = format!(
            "UPDATE local_chat_logs SET is_read = 1 WHERE conversation_id = ? AND seq IN ({})",
            placeholders
        );
        let mut query = sqlx::query(&sql).bind(conversation_id);
        for seq in seqs {
            query = query.bind(seq);
        }
        query.execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("mark as read: {}", e)))?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

    #[tokio::test]
    async fn test_message_dao_batch_insert() {
        let pool = create_pool_memory().await.unwrap();
        let dao = MessageDao::new(pool);

        let msg = LocalChatLog {
            conversation_id: "conv_1".into(),
            client_msg_id: "msg_1".into(),
            server_msg_id: String::new(),
            send_id: "user_1".into(),
            recv_id: "user_2".into(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: r#"{"text":"hello"}"#.into(),
            is_read: 0,
            status: 2,
            seq: 1,
            send_time: 1000,
            create_time: 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        };

        dao.batch_insert(&[msg]).await.unwrap();
        let seq = dao.get_max_seq("conv_1").await.unwrap();
        assert_eq!(seq, 1);
    }

    #[tokio::test]
    async fn test_message_dao_dedup() {
        let pool = create_pool_memory().await.unwrap();
        let dao = MessageDao::new(pool);

        let msg = LocalChatLog {
            conversation_id: "conv_1".into(),
            client_msg_id: "msg_1".into(),
            server_msg_id: String::new(),
            send_id: "user_1".into(),
            recv_id: "user_2".into(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: String::new(),
            is_read: 0,
            status: 2,
            seq: 1,
            send_time: 1000,
            create_time: 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        };

        dao.batch_insert(&[msg.clone()]).await.unwrap();
        dao.batch_insert(&[msg]).await.unwrap();
        let msgs = dao.get_by_conversation("conv_1", 0, 100).await.unwrap();
        assert_eq!(msgs.len(), 1);    }

    #[tokio::test]
    async fn test_mark_as_read_by_seqs() {
        let pool = create_pool_memory().await.unwrap();
        let dao = MessageDao::new(pool);

        let mut msg = LocalChatLog {
            conversation_id: "conv_1".into(),
            client_msg_id: "msg_1".into(),
            server_msg_id: String::new(),
            send_id: "user_1".into(),
            recv_id: "user_2".into(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: String::new(),
            is_read: 0,
            status: 2,
            seq: 1,
            send_time: 1000,
            create_time: 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        };

        dao.batch_insert(&[msg]).await.unwrap();
        dao.mark_as_read_by_seqs("conv_1", &[1]).await.unwrap();

        let msgs = dao.get_by_conversation("conv_1", 0, 100).await.unwrap();
        assert_eq!(msgs.len(), 1);
        assert_eq!(msgs[0].is_read, 1);
    }
}
