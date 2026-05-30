use super::models::LocalUser;
use crate::domain::error::types::{Result, SdkError};
use sqlx::SqlitePool;

pub struct UserDao {
    pool: SqlitePool,
}

impl UserDao {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub async fn upsert(&self, user: &LocalUser) -> Result<()> {
        sqlx::query(
            "INSERT INTO local_users (user_id, name, face_url, create_time, app_manger_level, ex, attached_info, global_recv_msg_opt) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(user_id) DO UPDATE SET name=excluded.name, face_url=excluded.face_url, create_time=excluded.create_time, app_manger_level=excluded.app_manger_level, ex=excluded.ex, attached_info=excluded.attached_info, global_recv_msg_opt=excluded.global_recv_msg_opt",
        )
        .bind(&user.user_id)
        .bind(&user.name)
        .bind(&user.face_url)
        .bind(user.create_time)
        .bind(user.app_manger_level)
        .bind(&user.ex)
        .bind(&user.attached_info)
        .bind(user.global_recv_msg_opt)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("upsert user: {}", e)))?;
        Ok(())
    }

    pub async fn batch_upsert(&self, users: &[LocalUser]) -> Result<()> {
        for user in users {
            self.upsert(user).await?;
        }
        Ok(())
    }

    pub async fn get_by_id(&self, user_id: &str) -> Result<Option<LocalUser>> {
        let row = sqlx::query_as::<_, LocalUser>(
            "SELECT * FROM local_users WHERE user_id = ?",
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query user: {}", e)))?;
        Ok(row)
    }

    pub async fn delete(&self, user_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_users WHERE user_id = ?")
            .bind(user_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("delete user: {}", e)))?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

    #[tokio::test]
    async fn test_upsert_and_get() {
        let pool = create_pool_memory().await.unwrap();
        let dao = UserDao::new(pool);

        let user = LocalUser {
            user_id: "user_1".into(),
            name: "Alice".into(),
            face_url: "https://example.com/face.png".into(),
            create_time: 1000,
            app_manger_level: 0,
            ex: String::new(),
            attached_info: String::new(),
            global_recv_msg_opt: 0,
        };

        dao.upsert(&user).await.unwrap();
        let found = dao.get_by_id("user_1").await.unwrap();
        assert!(found.is_some());
        assert_eq!(found.unwrap().name, "Alice");
    }
}
