//! local_stranger DAO (Go: data_model_struct.LocalStranger). 列 name 表示昵称。

use anyhow::Result;
use sqlx::{FromRow, Pool, Sqlite};

#[derive(Debug, Clone, FromRow)]
pub struct LocalStranger {
    pub user_id: String,
    #[sqlx(rename = "name")]
    pub nickname: String,
    pub face_url: String,
    pub create_time: i64,
    pub app_manger_level: i32,
    pub ex: String,
    pub attached_info: String,
    pub global_recv_msg_opt: i32,
}

const TABLE: &str = "local_stranger";

#[derive(Clone)]
pub struct StrangerDao {
    pool: Pool<Sqlite>,
}

impl StrangerDao {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self { pool }
    }

    pub async fn get(&self, user_id: &str) -> Result<Option<LocalStranger>> {
        let row = sqlx::query_as::<_, LocalStranger>(&format!(
            "SELECT user_id, name, face_url, create_time, app_manger_level, ex, attached_info, global_recv_msg_opt FROM {} WHERE user_id = ? LIMIT 1",
            TABLE
        ))
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?;
        Ok(row)
    }

    pub async fn insert(&self, row: &LocalStranger) -> Result<()> {
        sqlx::query(&format!(
            "INSERT OR REPLACE INTO {} (user_id, name, face_url, create_time, app_manger_level, ex, attached_info, global_recv_msg_opt) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            TABLE
        ))
        .bind(&row.user_id)
        .bind(&row.nickname)
        .bind(&row.face_url)
        .bind(row.create_time)
        .bind(row.app_manger_level)
        .bind(&row.ex)
        .bind(&row.attached_info)
        .bind(row.global_recv_msg_opt)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn update(&self, row: &LocalStranger) -> Result<()> {
        let affected = sqlx::query(&format!(
            "UPDATE {} SET name = ?, face_url = ?, create_time = ?, app_manger_level = ?, ex = ?, attached_info = ?, global_recv_msg_opt = ? WHERE user_id = ?",
            TABLE
        ))
        .bind(&row.nickname)
        .bind(&row.face_url)
        .bind(row.create_time)
        .bind(row.app_manger_level)
        .bind(&row.ex)
        .bind(&row.attached_info)
        .bind(row.global_recv_msg_opt)
        .bind(&row.user_id)
        .execute(&self.pool)
        .await?
        .rows_affected();
        if affected == 0 {
            anyhow::bail!("UpdateStranger: no row updated");
        }
        Ok(())
    }

    pub async fn delete(&self, user_id: &str) -> Result<()> {
        sqlx::query(&format!("DELETE FROM {} WHERE user_id = ?", TABLE))
            .bind(user_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }
}
