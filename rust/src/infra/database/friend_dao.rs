use super::models::LocalFriend;
use crate::domain::error::types::{Result, SdkError};
use sqlx::SqlitePool;

pub struct FriendDao {
    pool: SqlitePool,
}

impl FriendDao {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub async fn upsert(&self, friend: &LocalFriend) -> Result<()> {
        sqlx::query(
            "INSERT INTO local_friends (owner_user_id, friend_user_id, remark, create_time, add_source, operator_user_id, nickname, face_url, ex, attached_info, is_pinned) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(owner_user_id, friend_user_id) DO UPDATE SET remark=excluded.remark, create_time=excluded.create_time, add_source=excluded.add_source, operator_user_id=excluded.operator_user_id, nickname=excluded.nickname, face_url=excluded.face_url, ex=excluded.ex, attached_info=excluded.attached_info, is_pinned=excluded.is_pinned",
        )
        .bind(&friend.owner_user_id)
        .bind(&friend.friend_user_id)
        .bind(&friend.remark)
        .bind(friend.create_time)
        .bind(friend.add_source)
        .bind(&friend.operator_user_id)
        .bind(&friend.nickname)
        .bind(&friend.face_url)
        .bind(&friend.ex)
        .bind(&friend.attached_info)
        .bind(friend.is_pinned)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("upsert friend: {}", e)))?;
        Ok(())
    }

    pub async fn batch_upsert(&self, friends: &[LocalFriend]) -> Result<()> {
        for friend in friends {
            self.upsert(friend).await?;
        }
        Ok(())
    }

    pub async fn get_all(&self, owner_user_id: &str) -> Result<Vec<LocalFriend>> {
        let rows = sqlx::query_as::<_, LocalFriend>(
            "SELECT * FROM local_friends WHERE owner_user_id = ? ORDER BY is_pinned DESC, create_time DESC",
        )
        .bind(owner_user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query friends: {}", e)))?;
        Ok(rows)
    }

    pub async fn get_by_id(
        &self,
        owner_user_id: &str,
        friend_user_id: &str,
    ) -> Result<Option<LocalFriend>> {
        let row = sqlx::query_as::<_, LocalFriend>(
            "SELECT * FROM local_friends WHERE owner_user_id = ? AND friend_user_id = ?",
        )
        .bind(owner_user_id)
        .bind(friend_user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query friend: {}", e)))?;
        Ok(row)
    }

    pub async fn delete(&self, owner_user_id: &str, friend_user_id: &str) -> Result<()> {
        sqlx::query(
            "DELETE FROM local_friends WHERE owner_user_id = ? AND friend_user_id = ?",
        )
        .bind(owner_user_id)
        .bind(friend_user_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("delete friend: {}", e)))?;
        Ok(())
    }

    /// 批量删除好友记录
    pub async fn batch_delete(&self, owner_user_id: &str, friend_user_ids: &[String]) -> Result<()> {
        for fid in friend_user_ids {
            self.delete(owner_user_id, fid).await?;
        }
        Ok(())
    }

    /// 搜索好友（本地 SQLite 模糊查询，对齐 Go SDK SearchFriends）
    ///
    /// 按 nickname / friend_user_id / remark 进行 LIKE 模糊匹配
    pub async fn search_friends(&self, owner_user_id: &str, keyword: &str) -> Result<Vec<LocalFriend>> {
        let like_pattern = format!("%{}%", keyword);
        let rows = sqlx::query_as::<_, LocalFriend>(
            "SELECT * FROM local_friends WHERE owner_user_id = ? AND (nickname LIKE ? OR friend_user_id LIKE ? OR remark LIKE ?) ORDER BY is_pinned DESC, create_time DESC",
        )
        .bind(owner_user_id)
        .bind(&like_pattern)
        .bind(&like_pattern)
        .bind(&like_pattern)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("search friends: {}", e)))?;
        Ok(rows)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

    #[tokio::test]
    async fn test_crud() {
        let pool = create_pool_memory().await.unwrap();
        let dao = FriendDao::new(pool);

        let friend = LocalFriend {
            owner_user_id: "owner_1".into(),
            friend_user_id: "friend_1".into(),
            remark: "best friend".into(),
            create_time: 1000,
            add_source: 1,
            operator_user_id: String::new(),
            nickname: "Bob".into(),
            face_url: String::new(),
            ex: String::new(),
            attached_info: String::new(),
            is_pinned: 0,
        };

        dao.upsert(&friend).await.unwrap();
        let all = dao.get_all("owner_1").await.unwrap();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].nickname, "Bob");
    }
}
// ====================================================================
// Repository trait 实现
// ====================================================================

use crate::domain::repository::friend::FriendRepository;

#[async_trait::async_trait]
impl FriendRepository for FriendDao {
    async fn upsert(&self, friend: &LocalFriend) -> Result<()> { FriendDao::upsert(self, friend).await }
    async fn batch_upsert(&self, friends: &[LocalFriend]) -> Result<()> { self.batch_upsert(friends).await }
    async fn get_all(&self, owner_user_id: &str) -> Result<Vec<LocalFriend>> { self.get_all(owner_user_id).await }
    async fn get_by_id(&self, owner_user_id: &str, friend_user_id: &str) -> Result<Option<LocalFriend>> { self.get_by_id(owner_user_id, friend_user_id).await }
    async fn delete(&self, owner_user_id: &str, friend_user_id: &str) -> Result<()> { self.delete(owner_user_id, friend_user_id).await }
    async fn batch_delete(&self, owner_user_id: &str, friend_user_ids: &[String]) -> Result<()> { self.batch_delete(owner_user_id, friend_user_ids).await }
    async fn search_friends(&self, owner_user_id: &str, keyword: &str) -> Result<Vec<LocalFriend>> { self.search_friends(owner_user_id, keyword).await }
}
