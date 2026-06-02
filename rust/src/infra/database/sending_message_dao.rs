use super::models::LocalSendingMessage;
use crate::domain::error::types::{Result, SdkError};
use sqlx::SqlitePool;

pub struct SendingMessageDao {
    pool: SqlitePool,
}

impl SendingMessageDao {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub async fn insert(&self, msg: &LocalSendingMessage) -> Result<()> {
        sqlx::query(
            "INSERT OR IGNORE INTO local_sending_messages (conversation_id, client_msg_id, ex) VALUES (?, ?, ?)",
        )
        .bind(&msg.conversation_id)
        .bind(&msg.client_msg_id)
        .bind(&msg.ex)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("insert sending message: {}", e)))?;
        Ok(())
    }

    pub async fn delete(&self, conversation_id: &str, client_msg_id: &str) -> Result<()> {
        sqlx::query(
            "DELETE FROM local_sending_messages WHERE conversation_id = ? AND client_msg_id = ?",
        )
        .bind(conversation_id)
        .bind(client_msg_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("delete sending message: {}", e)))?;
        Ok(())
    }

    pub async fn get_all(&self) -> Result<Vec<LocalSendingMessage>> {
        let rows = sqlx::query_as::<_, LocalSendingMessage>(
            "SELECT conversation_id, client_msg_id, ex FROM local_sending_messages",
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("get all sending messages: {}", e)))?;
        Ok(rows)
    }
}
