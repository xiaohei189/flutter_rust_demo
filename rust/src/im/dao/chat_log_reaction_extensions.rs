//! local_chat_log_reaction_extensions DAO（与 Go LocalChatLogReactionExtensions 一致）

use anyhow::Result;
use sqlx::{FromRow, Pool, Sqlite};

#[derive(Debug, Clone, FromRow)]
pub struct LocalChatLogReactionExtensions {
    pub client_msg_id: String,
    /// BLOB，可为 NULL
    pub local_reaction_extensions: Option<Vec<u8>>,
}

const TABLE: &str = "local_chat_log_reaction_extensions";

#[derive(Clone)]
pub struct ChatLogReactionExtensionsDao {
    pool: Pool<Sqlite>,
}

impl ChatLogReactionExtensionsDao {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self { pool }
    }

    pub async fn get(&self, client_msg_id: &str) -> Result<Option<LocalChatLogReactionExtensions>> {
        let row = sqlx::query_as::<_, LocalChatLogReactionExtensions>(&format!(
            "SELECT client_msg_id, local_reaction_extensions FROM {} WHERE client_msg_id = ? LIMIT 1",
            TABLE
        ))
        .bind(client_msg_id)
        .fetch_optional(&self.pool)
        .await?;
        Ok(row)
    }

    pub async fn insert(&self, row: &LocalChatLogReactionExtensions) -> Result<()> {
        sqlx::query(&format!(
            "INSERT OR REPLACE INTO {} (client_msg_id, local_reaction_extensions) VALUES (?, ?)",
            TABLE
        ))
        .bind(&row.client_msg_id)
        .bind(row.local_reaction_extensions.as_deref())
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn update(&self, row: &LocalChatLogReactionExtensions) -> Result<()> {
        let n = sqlx::query(&format!(
            "UPDATE {} SET local_reaction_extensions = ? WHERE client_msg_id = ?",
            TABLE
        ))
        .bind(row.local_reaction_extensions.as_deref())
        .bind(&row.client_msg_id)
        .execute(&self.pool)
        .await?
        .rows_affected();
        if n == 0 {
            anyhow::bail!("Update reaction extensions: no row updated");
        }
        Ok(())
    }

    pub async fn delete(&self, client_msg_id: &str) -> Result<()> {
        sqlx::query(&format!("DELETE FROM {} WHERE client_msg_id = ?", TABLE))
            .bind(client_msg_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }
}
