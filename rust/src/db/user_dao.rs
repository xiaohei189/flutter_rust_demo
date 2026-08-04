use crate::model::local::LocalUser;
use crate::error::{Result, SdkError};
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
    use crate::db::pool::create_pool_memory;

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

// ====================================================================
// Repository trait 实现
// ====================================================================

use crate::db::user::UserRepository;

#[async_trait::async_trait]
impl UserRepository for UserDao {
    async fn upsert(&self, user: &LocalUser) -> Result<()> { UserDao::upsert(self, user).await }
    async fn batch_upsert(&self, users: &[LocalUser]) -> Result<()> { self.batch_upsert(users).await }
    async fn get_by_id(&self, user_id: &str) -> Result<Option<LocalUser>> { self.get_by_id(user_id).await }
    async fn delete(&self, user_id: &str) -> Result<()> { self.delete(user_id).await }
}

// ============================================================
// 黑名单 DAO（与用户同属关系域）
// ============================================================
use crate::model::local::LocalBlack;

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
mod black_dao_tests {
    use super::*;
    use crate::db::pool::create_pool_memory;

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