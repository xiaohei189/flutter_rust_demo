//! local_group_members DAO (Go: group_member_model.go). 列 user_group_face_url。

use anyhow::Result;
use sqlx::{FromRow, Pool, Sqlite};

#[derive(Debug, Clone, FromRow)]
pub struct LocalGroupMember {
    pub group_id: String,
    pub user_id: String,
    pub nickname: String,
    #[sqlx(rename = "user_group_face_url")]
    pub face_url: String,
    pub role_level: i32,
    pub join_time: i64,
    pub join_source: i32,
    pub inviter_user_id: String,
    pub mute_end_time: i64,
    pub operator_user_id: String,
    pub ex: String,
    pub attached_info: String,
}

#[derive(Clone)]
pub struct GroupMemberDao {
    pool: Pool<Sqlite>,
}

impl GroupMemberDao {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self { pool }
    }

    pub async fn get_by_group_id_user_id(&self, group_id: &str, user_id: &str) -> Result<Option<LocalGroupMember>> {
        Ok(sqlx::query_as::<_, LocalGroupMember>("SELECT group_id, user_id, nickname, user_group_face_url, role_level, join_time, join_source, inviter_user_id, mute_end_time, operator_user_id, ex, attached_info FROM local_group_members WHERE group_id = ? AND user_id = ? LIMIT 1")
            .bind(group_id)
            .bind(user_id)
            .fetch_optional(&self.pool)
            .await?)
    }

    pub async fn get_member_count(&self, group_id: &str) -> Result<i32> {
        let (c,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM local_group_members WHERE group_id = ?")
            .bind(group_id)
            .fetch_one(&self.pool)
            .await?;
        Ok(c as i32)
    }

    pub async fn get_some_member_info(&self, group_id: &str, user_id_list: &[String]) -> Result<Vec<LocalGroupMember>> {
        if user_id_list.is_empty() {
            return Ok(Vec::new());
        }
        let ph: String = user_id_list.iter().map(|_| "?").collect::<Vec<_>>().join(", ");
        let sql = format!("SELECT group_id, user_id, nickname, user_group_face_url, role_level, join_time, join_source, inviter_user_id, mute_end_time, operator_user_id, ex, attached_info FROM local_group_members WHERE group_id = ? AND user_id IN ({})", ph);
        let mut q = sqlx::query_as::<_, LocalGroupMember>(&sql).bind(group_id);
        for id in user_id_list {
            q = q.bind(id);
        }
        Ok(q.fetch_all(&self.pool).await?)
    }

    pub async fn get_member_list_by_group_id(&self, group_id: &str) -> Result<Vec<LocalGroupMember>> {
        Ok(sqlx::query_as::<_, LocalGroupMember>("SELECT group_id, user_id, nickname, user_group_face_url, role_level, join_time, join_source, inviter_user_id, mute_end_time, operator_user_id, ex, attached_info FROM local_group_members WHERE group_id = ?")
            .bind(group_id)
            .fetch_all(&self.pool)
            .await?)
    }

    pub async fn insert(&self, row: &LocalGroupMember) -> Result<()> {
        sqlx::query("INSERT INTO local_group_members (group_id, user_id, nickname, user_group_face_url, role_level, join_time, join_source, inviter_user_id, mute_end_time, operator_user_id, ex, attached_info) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
            .bind(&row.group_id)
            .bind(&row.user_id)
            .bind(&row.nickname)
            .bind(&row.face_url)
            .bind(row.role_level)
            .bind(row.join_time)
            .bind(row.join_source)
            .bind(&row.inviter_user_id)
            .bind(row.mute_end_time)
            .bind(&row.operator_user_id)
            .bind(&row.ex)
            .bind(&row.attached_info)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn batch_insert(&self, rows: &[LocalGroupMember]) -> Result<()> {
        for row in rows {
            self.insert(row).await?;
        }
        Ok(())
    }

    pub async fn delete(&self, group_id: &str, user_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_group_members WHERE group_id = ? AND user_id = ?")
            .bind(group_id)
            .bind(user_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn delete_all_members(&self, group_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_group_members WHERE group_id = ?")
            .bind(group_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn update(&self, row: &LocalGroupMember) -> Result<()> {
        let n = sqlx::query("UPDATE local_group_members SET nickname=?, user_group_face_url=?, role_level=?, join_time=?, join_source=?, inviter_user_id=?, mute_end_time=?, operator_user_id=?, ex=?, attached_info=? WHERE group_id=? AND user_id=?")
            .bind(&row.nickname)
            .bind(&row.face_url)
            .bind(row.role_level)
            .bind(row.join_time)
            .bind(row.join_source)
            .bind(&row.inviter_user_id)
            .bind(row.mute_end_time)
            .bind(&row.operator_user_id)
            .bind(&row.ex)
            .bind(&row.attached_info)
            .bind(&row.group_id)
            .bind(&row.user_id)
            .execute(&self.pool)
            .await?
            .rows_affected();
        if n == 0 {
            anyhow::bail!("UpdateGroupMember: no row updated");
        }
        Ok(())
    }
}
