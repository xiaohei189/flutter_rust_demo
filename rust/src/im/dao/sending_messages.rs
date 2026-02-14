//! local_sending_messages DAO (Go: sending_messages_model.go)

use anyhow::Result;
use sqlx::{FromRow, Pool, Sqlite};

#[derive(Debug, Clone, FromRow)]
pub struct LocalSendingMessage {
    pub conversation_id: String,
    pub client_msg_id: String,
    pub ex: String,
}

const TABLE: &str = "local_sending_messages";

#[derive(Clone)]
pub struct SendingMessagesDao {
    pool: Pool<Sqlite>,
}

impl SendingMessagesDao {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self { pool }
    }

    pub async fn insert(&self, row: &LocalSendingMessage) -> Result<()> {
        sqlx::query("INSERT OR REPLACE INTO local_sending_messages (conversation_id, client_msg_id, ex) VALUES (?, ?, ?)")
            .bind(&row.conversation_id)
            .bind(&row.client_msg_id)
            .bind(&row.ex)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn delete(&self, conversation_id: &str, client_msg_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_sending_messages WHERE conversation_id = ? AND client_msg_id = ?")
            .bind(conversation_id)
            .bind(client_msg_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn get_all(&self) -> Result<Vec<LocalSendingMessage>> {
        let rows = sqlx::query_as::<_, LocalSendingMessage>("SELECT conversation_id, client_msg_id, ex FROM local_sending_messages")
            .fetch_all(&self.pool)
            .await?;
        Ok(rows)
    }
}
