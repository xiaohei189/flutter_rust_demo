use crate::domain::error::types::{Result, SdkError};
use sqlx::SqlitePool;

use super::models::LocalUpload;

/// local_uploads 表 DAO — 断点续传状态持久化
/// 对齐 Go SDK `pkg/db/upload_model.go`
pub struct UploadDao {
    pool: SqlitePool,
}

impl UploadDao {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    /// 根据 part_hash 查询上传记录
    pub async fn get_upload(&self, part_hash: &str) -> Result<Option<LocalUpload>> {
        let row = sqlx::query_as::<_, LocalUpload>(
            "SELECT part_hash, upload_id, upload_info, expire_time, create_time FROM local_uploads WHERE part_hash = ?",
        )
        .bind(part_hash)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("查询上传记录失败: {}", e)))?;
        Ok(row)
    }

    /// 插入新的上传记录
    pub async fn insert_upload(&self, info: &LocalUpload) -> Result<()> {
        sqlx::query(
            "INSERT OR REPLACE INTO local_uploads (part_hash, upload_id, upload_info, expire_time, create_time) VALUES (?, ?, ?, ?, ?)",
        )
        .bind(&info.part_hash)
        .bind(&info.upload_id)
        .bind(&info.upload_info)
        .bind(info.expire_time)
        .bind(info.create_time)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("插入上传记录失败: {}", e)))?;
        Ok(())
    }

    /// 更新上传记录
    pub async fn update_upload(&self, info: &LocalUpload) -> Result<()> {
        sqlx::query(
            "UPDATE local_uploads SET upload_id = ?, upload_info = ?, expire_time = ? WHERE part_hash = ?",
        )
        .bind(&info.upload_id)
        .bind(&info.upload_info)
        .bind(info.expire_time)
        .bind(&info.part_hash)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("更新上传记录失败: {}", e)))?;
        Ok(())
    }

    /// 删除上传记录
    pub async fn delete_upload(&self, part_hash: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_uploads WHERE part_hash = ?")
            .bind(part_hash)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("删除上传记录失败: {}", e)))?;
        Ok(())
    }
}
