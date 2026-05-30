use super::models::LocalBlack;
use crate::domain::error::types::{Result, SdkError};
use sqlx::SqlitePool;

pub struct BlackDao {
    pool: SqlitePool,
}

impl BlackDao {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub async fn upsert(&self, black: &LocalBlack) -> Result<()> {
        sqlx::query(
            "INSERT INTO local_blacks (owner_user_id, block_user_id, nickname, face_url, create_time, add_source, operator_user_id, ex, attached_info) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(owner_user_id, block_user_id) DO UPDATE SET nickname=excluded.nickname, face_url=excluded.face_url, create_time=excluded.create_time, add_source=excluded.add_source, operator_user_id=excluded.operator_user_id, ex=excluded.ex, attached_info=excluded.attached_info",
        )
        .bind(&black.owner_user_id)
        .bind(&black.block_user_id)
        .bind(&black.nickname)
        .bind(&black.face_url)
        .bind(black.create_time)
        .bind(black.add_source)
        .bind(&black.operator_user_id)
        .bind(&black.ex)
        .bind(&black.attached_info)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("upsert black: {}", e)))?;
        Ok(())
    }

    pub async fn batch_upsert(&self, blacks: &[LocalBlack]) -> Result<()> {
        for black in blacks {
            self.upsert(black).await?;
        }
        Ok(())
    }

    pub async fn get_all(&self, owner_user_id: &str) -> Result<Vec<LocalBlack>> {
        let rows = sqlx::query_as::<_, LocalBlack>(
            "SELECT * FROM local_blacks WHERE owner_user_id = ? ORDER BY create_time DESC",
        )
        .bind(owner_user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query blacks: {}", e)))?;
        Ok(rows)
    }

    pub async fn delete(&self, owner_user_id: &str, block_user_id: &str) -> Result<()> {
        sqlx::query(
            "DELETE FROM local_blacks WHERE owner_user_id = ? AND block_user_id = ?",
        )
        .bind(owner_user_id)
        .bind(block_user_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("delete black: {}", e)))?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

    #[tokio::test]
    async fn test_crud() {
        let pool = create_pool_memory().await.unwrap();
        let dao = BlackDao::new(pool);

        let black = LocalBlack {
            owner_user_id: "owner_1".into(),
            block_user_id: "blocked_1".into(),
            nickname: "Spammer".into(),
            face_url: String::new(),
            create_time: 1000,
            add_source: 1,
            operator_user_id: String::new(),
            ex: String::new(),
            attached_info: String::new(),
        };

        dao.upsert(&black).await.unwrap();
        let all = dao.get_all("owner_1").await.unwrap();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].nickname, "Spammer");
    }
}