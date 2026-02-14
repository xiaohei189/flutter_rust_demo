//! 黑名单表 DAO（与 Go pkg/db/black_model.go 对齐）
//! 表名：local_blacks；主键 (owner_user_id, block_user_id)。需当前登录用户 id 作为 owner。

use anyhow::Result;
use sqlx::{FromRow, Pool, Sqlite};

#[derive(Debug, Clone, FromRow)]
pub struct LocalBlack {
    pub owner_user_id: String,
    pub block_user_id: String,
    pub nickname: String,
    pub face_url: String,
    pub create_time: i64,
    pub add_source: i32,
    pub operator_user_id: String,
    pub ex: String,
    pub attached_info: String,
}

const TABLE: &str = "local_blacks";

#[derive(Clone)]
pub struct BlackDao {
    pool: Pool<Sqlite>,
    login_user_id: String,
}

impl BlackDao {
    pub fn new(pool: Pool<Sqlite>, login_user_id: String) -> Self {
        Self {
            pool,
            login_user_id,
        }
    }

    pub async fn get_black_list(&self) -> Result<Vec<LocalBlack>> {
        let rows = sqlx::query_as::<_, LocalBlack>(&format!(
            "SELECT owner_user_id, block_user_id, nickname, face_url, create_time, add_source, operator_user_id, ex, attached_info FROM {} WHERE owner_user_id = ?",
            TABLE
        ))
        .bind(&self.login_user_id)
        .fetch_all(&self.pool)
        .await?;
        Ok(rows)
    }

    pub async fn get_black_info_by_block_user_id(
        &self,
        block_user_id: &str,
    ) -> Result<Option<LocalBlack>> {
        let row = sqlx::query_as::<_, LocalBlack>(&format!(
            "SELECT owner_user_id, block_user_id, nickname, face_url, create_time, add_source, operator_user_id, ex, attached_info FROM {} WHERE owner_user_id = ? AND block_user_id = ? LIMIT 1",
            TABLE
        ))
        .bind(&self.login_user_id)
        .bind(block_user_id)
        .fetch_optional(&self.pool)
        .await?;
        Ok(row)
    }

    pub async fn insert(&self, row: &LocalBlack) -> Result<()> {
        sqlx::query(&format!(
            "INSERT INTO {} (owner_user_id, block_user_id, nickname, face_url, create_time, add_source, operator_user_id, ex, attached_info) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            TABLE
        ))
        .bind(&row.owner_user_id)
        .bind(&row.block_user_id)
        .bind(&row.nickname)
        .bind(&row.face_url)
        .bind(row.create_time)
        .bind(row.add_source)
        .bind(&row.operator_user_id)
        .bind(&row.ex)
        .bind(&row.attached_info)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn update(&self, row: &LocalBlack) -> Result<()> {
        let affected = sqlx::query(&format!(
            "UPDATE {} SET nickname = ?, face_url = ?, create_time = ?, add_source = ?, operator_user_id = ?, ex = ?, attached_info = ? WHERE owner_user_id = ? AND block_user_id = ?",
            TABLE
        ))
        .bind(&row.nickname)
        .bind(&row.face_url)
        .bind(row.create_time)
        .bind(row.add_source)
        .bind(&row.operator_user_id)
        .bind(&row.ex)
        .bind(&row.attached_info)
        .bind(&row.owner_user_id)
        .bind(&row.block_user_id)
        .execute(&self.pool)
        .await?
        .rows_affected();
        if affected == 0 {
            anyhow::bail!("UpdateBlack: no row updated");
        }
        Ok(())
    }

    pub async fn delete(&self, block_user_id: &str) -> Result<()> {
        sqlx::query(&format!(
            "DELETE FROM {} WHERE owner_user_id = ? AND block_user_id = ?",
            TABLE
        ))
        .bind(&self.login_user_id)
        .bind(block_user_id)
        .execute(&self.pool)
        .await?;
        Ok(())
    }
}
