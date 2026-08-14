use crate::constant::sync_flag;
use crate::error::Result;
use crate::error::SdkError;
use sqlx::{Pool, Sqlite};
use tracing::info;

pub struct SyncVersionDao {
    pool: Pool<Sqlite>,
}

impl SyncVersionDao {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self { pool }
    }

    /// 检查本地是否已安装过 SDK（数据库非空）
    pub async fn is_conversation_id_list_empty(&self) -> Result<bool> {
        let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM local_conversations")
            .fetch_one(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("query conversation count: {}", e)))?;
        Ok(count == 0)
    }

    /// 获取 SDK 版本记录
    pub async fn get_sdk_version(&self) -> Result<Option<(String, bool)>> {
        let row = sqlx::query_as::<_, (String, i64)>("SELECT version, installed FROM local_app_sdk_version LIMIT 1")
            .fetch_optional(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("query sdk version: {}", e)))?;

        Ok(row.map(|(v, i)| (v, i != 0)))
    }

    /// 判断是否为重新安装（参考 Go SDK 的 reinstalled 逻辑）
    pub async fn is_reinstalled(&self) -> Result<bool> {
        // 检查 sync_flag：如果为 SYNC_START（1），说明上次同步被中断，视为重新安装
        let current_flag = self.get_sync_flag().await.unwrap_or(0);
        let is_incomplete_stage = current_flag == sync_flag::SYNC_START || (sync_flag::SYNC_STAGE_FRIENDS..sync_flag::SYNC_STAGE_DONE).contains(&current_flag);
        if is_incomplete_stage {
            info!("sync_flag={}，上次同步被中断，视为重新安装", current_flag);
            return Ok(true);
        }
        let version_record = self.get_sdk_version().await?;
        match version_record {
            Some((_, installed)) => Ok(!installed),
            None => {
                let is_empty = self.is_conversation_id_list_empty().await?;
                Ok(is_empty)
            }
        }
    }

    /// 获取指定表+实体的同步版本信息（对齐 Go SDK `GetVersionSync`）
    pub async fn get_version_sync(&self, table_name: &str, entity_id: &str) -> Result<Option<(String, u64)>> {
        let row = sqlx::query_as::<_, (String, i64)>("SELECT version_id, version FROM local_sync_version WHERE table_name = ? AND entity_id = ?")
            .bind(table_name)
            .bind(entity_id)
            .fetch_optional(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("get version sync: {}", e)))?;

        Ok(row.map(|(vid, v)| (vid, v as u64)))
    }

    /// 设置指定表+实体的同步版本信息（对齐 Go SDK `SetVersionSync`）
    pub async fn set_version_sync(&self, table_name: &str, entity_id: &str, version_id: &str, version: u64) -> Result<()> {
        sqlx::query(
            "INSERT INTO local_sync_version (table_name, entity_id, version_id, version) VALUES (?1, ?2, ?3, ?4) \
             ON CONFLICT(table_name, entity_id) DO UPDATE SET version_id = excluded.version_id, version = excluded.version",
        )
        .bind(table_name)
        .bind(entity_id)
        .bind(version_id)
        .bind(version as i64)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("set version sync: {}", e)))?;
        Ok(())
    }

    /// 删除指定表+实体的同步版本记录
    pub async fn delete_version_sync(&self, table_name: &str, entity_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_sync_version WHERE table_name = ? AND entity_id = ?")
            .bind(table_name)
            .bind(entity_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("delete version sync: {}", e)))?;
        Ok(())
    }

    /// 获取同步标志
    pub async fn get_sync_flag(&self) -> Result<i32> {
        let row = sqlx::query_scalar::<_, i64>("SELECT sync_flag FROM local_app_sdk_version LIMIT 1")
            .fetch_optional(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("get sync_flag: {}", e)))?;
        Ok(row.unwrap_or(0) as i32)
    }

    /// 设置同步标志
    ///
    /// 首次运行时 local_app_sdk_version 尚无行（mark_reinstall_complete 才会插行），
    /// 纯 UPDATE 会静默影响 0 行导致阶段标志丢失；这里用 SDK_LOCAL_VERSION 锚定行做 UPSERT，
    /// 保证与 mark_reinstall_complete 始终操作同一行。
    pub async fn set_sync_flag(&self, flag: i32) -> Result<()> {
        sqlx::query(
            "INSERT INTO local_app_sdk_version (version, sync_flag) VALUES (?1, ?2) \
             ON CONFLICT(version) DO UPDATE SET sync_flag = excluded.sync_flag",
        )
        .bind(crate::constant::SDK_LOCAL_VERSION)
        .bind(flag as i64)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("set sync_flag: {}", e)))?;
        info!("sync_flag set to {}", flag);
        Ok(())
    }

    /// 标记重装同步完成（设置 installed=1）
    pub async fn mark_reinstall_complete(&self, version: &str) -> Result<()> {
        sqlx::query(
            "INSERT INTO local_app_sdk_version (version, installed) VALUES (?1, 1) \
             ON CONFLICT(version) DO UPDATE SET installed = 1",
        )
        .bind(version)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("mark install complete: {}", e)))?;

        info!("SDK 重装同步完成，version={}, installed=1", version);
        Ok(())
    }
}

// ====================================================================
// Repository trait 实现
// ====================================================================

use crate::db::sync_version::SyncVersionRepository;

#[async_trait::async_trait]
impl SyncVersionRepository for SyncVersionDao {
    async fn is_conversation_id_list_empty(&self) -> Result<bool> {
        SyncVersionDao::is_conversation_id_list_empty(self).await
    }
    async fn get_sdk_version(&self) -> Result<Option<(String, bool)>> {
        self.get_sdk_version().await
    }
    async fn is_reinstalled(&self) -> Result<bool> {
        self.is_reinstalled().await
    }
    async fn get_version_sync(&self, table_name: &str, entity_id: &str) -> Result<Option<(String, u64)>> {
        self.get_version_sync(table_name, entity_id).await
    }
    async fn set_version_sync(&self, table_name: &str, entity_id: &str, version_id: &str, version: u64) -> Result<()> {
        self.set_version_sync(table_name, entity_id, version_id, version).await
    }
    async fn delete_version_sync(&self, table_name: &str, entity_id: &str) -> Result<()> {
        self.delete_version_sync(table_name, entity_id).await
    }
    async fn get_sync_flag(&self) -> Result<i32> {
        self.get_sync_flag().await
    }
    async fn set_sync_flag(&self, flag: i32) -> Result<()> {
        self.set_sync_flag(flag).await
    }
    async fn mark_reinstall_complete(&self, version: &str) -> Result<()> {
        self.mark_reinstall_complete(version).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::pool::create_pool_memory;

    #[tokio::test]
    async fn test_is_reinstalled_on_empty_db() {
        let pool = create_pool_memory().await.unwrap();
        let dao = SyncVersionDao::new(pool);

        assert!(dao.is_reinstalled().await.unwrap());
    }

    #[tokio::test]
    async fn test_is_not_reinstalled_after_mark() {
        let pool = create_pool_memory().await.unwrap();
        let dao = SyncVersionDao::new(pool.clone());

        dao.mark_reinstall_complete("1.0.0").await.unwrap();
        assert!(!dao.is_reinstalled().await.unwrap());
    }

    #[tokio::test]
    async fn test_set_sync_flag_creates_anchor_row() {
        let pool = create_pool_memory().await.unwrap();
        let dao = SyncVersionDao::new(pool);

        // 无行时首次调用应插入锚定行而不是静默空操作
        dao.set_sync_flag(sync_flag::SYNC_STAGE_FRIENDS).await.unwrap();
        assert_eq!(dao.get_sync_flag().await.unwrap(), sync_flag::SYNC_STAGE_FRIENDS);

        // 再次调用更新同一行
        dao.set_sync_flag(sync_flag::SYNC_STAGE_DONE).await.unwrap();
        assert_eq!(dao.get_sync_flag().await.unwrap(), sync_flag::SYNC_STAGE_DONE);

        // 与 mark_reinstall_complete 共用锚定行，表内不应出现多行导致读取错乱
        dao.mark_reinstall_complete(crate::constant::SDK_LOCAL_VERSION).await.unwrap();
        assert_eq!(dao.get_sync_flag().await.unwrap(), sync_flag::SYNC_STAGE_DONE);
        assert!(!dao.is_reinstalled().await.unwrap());
    }
}
