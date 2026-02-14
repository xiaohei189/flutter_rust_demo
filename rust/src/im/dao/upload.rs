//! 上传记录表 DAO（与 Go pkg/db/upload_model.go 对齐）
//! 表名：local_uploads；主键 part_hash。

use anyhow::Result;
use sqlx::{FromRow, Pool, Sqlite};

#[derive(Debug, Clone, FromRow)]
pub struct LocalUpload {
    pub part_hash: String,
    pub upload_id: String,
    pub upload_info: String,
    pub expire_time: i64,
    pub create_time: i64,
}

const TABLE: &str = "local_uploads";

#[derive(Clone)]
pub struct UploadDao {
    pool: Pool<Sqlite>,
}

impl UploadDao {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self { pool }
    }

    pub async fn get(&self, part_hash: &str) -> Result<Option<LocalUpload>> {
        let row = sqlx::query_as::<_, LocalUpload>(&format!(
            "SELECT part_hash, upload_id, upload_info, expire_time, create_time FROM {} WHERE part_hash = ? LIMIT 1",
            TABLE
        ))
        .bind(part_hash)
        .fetch_optional(&self.pool)
        .await?;
        Ok(row)
    }

    pub async fn insert(&self, row: &LocalUpload) -> Result<()> {
        sqlx::query(&format!(
            "INSERT INTO {} (part_hash, upload_id, upload_info, expire_time, create_time) VALUES (?, ?, ?, ?, ?)",
            TABLE
        ))
        .bind(&row.part_hash)
        .bind(&row.upload_id)
        .bind(&row.upload_info)
        .bind(row.expire_time)
        .bind(row.create_time)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn update(&self, row: &LocalUpload) -> Result<()> {
        let affected = sqlx::query(&format!(
            "UPDATE {} SET upload_id = ?, upload_info = ?, expire_time = ?, create_time = ? WHERE part_hash = ?",
            TABLE
        ))
        .bind(&row.upload_id)
        .bind(&row.upload_info)
        .bind(row.expire_time)
        .bind(row.create_time)
        .bind(&row.part_hash)
        .execute(&self.pool)
        .await?
        .rows_affected();
        if affected == 0 {
            anyhow::bail!("UpdateUpload: no row updated");
        }
        Ok(())
    }

    pub async fn delete(&self, part_hash: &str) -> Result<()> {
        sqlx::query(&format!("DELETE FROM {} WHERE part_hash = ?", TABLE))
            .bind(part_hash)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    /// 删除过期记录（expire_time <= 当前毫秒）
    pub async fn delete_expire(&self) -> Result<()> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64;
        sqlx::query(&format!("DELETE FROM {} WHERE expire_time <= ?", TABLE))
            .bind(now)
            .execute(&self.pool)
            .await?;
        Ok(())
    }
}
