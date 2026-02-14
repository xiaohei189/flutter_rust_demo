//! local_groups DAO (Go: group_model.go)

use anyhow::Result;
use sqlx::{FromRow, Pool, Sqlite};

#[derive(Debug, Clone, FromRow)]
pub struct LocalGroup {
    pub group_id: String,
    #[sqlx(rename = "name")]
    pub group_name: String,
    pub notification: String,
    pub introduction: String,
    pub face_url: String,
    pub create_time: i64,
    pub status: i32,
    pub creator_user_id: String,
    pub group_type: i32,
    pub owner_user_id: String,
    pub member_count: i32,
    pub ex: String,
    pub attached_info: String,
    pub need_verification: i32,
    pub look_member_info: i32,
    pub apply_member_friend: i32,
    pub notification_update_time: i64,
    pub notification_user_id: String,
}

#[derive(Clone)]
pub struct GroupDao {
    pool: Pool<Sqlite>,
}

impl GroupDao {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self { pool }
    }

    pub async fn insert(&self, row: &LocalGroup) -> Result<()> {
        sqlx::query("INSERT INTO local_groups (group_id, name, notification, introduction, face_url, create_time, status, creator_user_id, group_type, owner_user_id, member_count, ex, attached_info, need_verification, look_member_info, apply_member_friend, notification_update_time, notification_user_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
            .bind(&row.group_id)
            .bind(&row.group_name)
            .bind(&row.notification)
            .bind(&row.introduction)
            .bind(&row.face_url)
            .bind(row.create_time)
            .bind(row.status)
            .bind(&row.creator_user_id)
            .bind(row.group_type)
            .bind(&row.owner_user_id)
            .bind(row.member_count)
            .bind(&row.ex)
            .bind(&row.attached_info)
            .bind(row.need_verification)
            .bind(row.look_member_info)
            .bind(row.apply_member_friend)
            .bind(row.notification_update_time)
            .bind(&row.notification_user_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn delete(&self, group_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_groups WHERE group_id = ?")
            .bind(group_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn update(&self, row: &LocalGroup) -> Result<()> {
        let n = sqlx::query("UPDATE local_groups SET name=?, notification=?, introduction=?, face_url=?, create_time=?, status=?, creator_user_id=?, group_type=?, owner_user_id=?, member_count=?, ex=?, attached_info=?, need_verification=?, look_member_info=?, apply_member_friend=?, notification_update_time=?, notification_user_id=? WHERE group_id=?")
            .bind(&row.group_name)
            .bind(&row.notification)
            .bind(&row.introduction)
            .bind(&row.face_url)
            .bind(row.create_time)
            .bind(row.status)
            .bind(&row.creator_user_id)
            .bind(row.group_type)
            .bind(&row.owner_user_id)
            .bind(row.member_count)
            .bind(&row.ex)
            .bind(&row.attached_info)
            .bind(row.need_verification)
            .bind(row.look_member_info)
            .bind(row.apply_member_friend)
            .bind(row.notification_update_time)
            .bind(&row.notification_user_id)
            .bind(&row.group_id)
            .execute(&self.pool)
            .await?
            .rows_affected();
        if n == 0 {
            anyhow::bail!("UpdateGroup: no row updated");
        }
        Ok(())
    }

    pub async fn batch_insert(&self, rows: &[LocalGroup]) -> Result<()> {
        for row in rows {
            self.insert(row).await?;
        }
        Ok(())
    }

    pub async fn delete_all(&self) -> Result<()> {
        sqlx::query("DELETE FROM local_groups").execute(&self.pool).await?;
        Ok(())
    }

    pub async fn get_joined_group_list(&self) -> Result<Vec<LocalGroup>> {
        let rows = sqlx::query_as::<_, LocalGroup>("SELECT * FROM local_groups")
            .fetch_all(&self.pool)
            .await?;
        Ok(rows)
    }

    pub async fn get_groups(&self, group_ids: &[String]) -> Result<Vec<LocalGroup>> {
        if group_ids.is_empty() {
            return Ok(Vec::new());
        }
        let ph: String = group_ids.iter().map(|_| "?").collect::<Vec<_>>().join(", ");
        let sql = format!("SELECT * FROM local_groups WHERE group_id IN ({})", ph);
        let mut q = sqlx::query_as::<_, LocalGroup>(&sql);
        for id in group_ids {
            q = q.bind(id);
        }
        Ok(q.fetch_all(&self.pool).await?)
    }

    pub async fn get_group_info_by_group_id(&self, group_id: &str) -> Result<Option<LocalGroup>> {
        Ok(sqlx::query_as::<_, LocalGroup>("SELECT * FROM local_groups WHERE group_id = ? LIMIT 1")
            .bind(group_id)
            .fetch_optional(&self.pool)
            .await?)
    }

    pub async fn get_all_group_info_by_group_id_or_group_name(
        &self,
        keyword: &str,
        is_search_group_id: bool,
        is_search_group_name: bool,
    ) -> Result<Vec<LocalGroup>> {
        let pattern = format!("%{}%", keyword);
        if is_search_group_id && is_search_group_name {
            Ok(sqlx::query_as::<_, LocalGroup>("SELECT * FROM local_groups WHERE group_id LIKE ? OR name LIKE ? ORDER BY create_time DESC")
                .bind(&pattern)
                .bind(&pattern)
                .fetch_all(&self.pool)
                .await?)
        } else if is_search_group_id {
            Ok(sqlx::query_as::<_, LocalGroup>("SELECT * FROM local_groups WHERE group_id LIKE ? ORDER BY create_time DESC")
                .bind(&pattern)
                .fetch_all(&self.pool)
                .await?)
        } else {
            Ok(sqlx::query_as::<_, LocalGroup>("SELECT * FROM local_groups WHERE name LIKE ? ORDER BY create_time DESC")
                .bind(&pattern)
                .fetch_all(&self.pool)
                .await?)
        }
    }
}
