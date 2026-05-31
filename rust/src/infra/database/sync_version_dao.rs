use crate::domain::error::types::SdkError;
use crate::domain::error::types::Result;
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
        let count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM local_conversations",
        )
        .fetch_one(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query conversation count: {}", e)))?;
        Ok(count == 0)
    }

    /// 获取 SDK 版本记录
    pub async fn get_sdk_version(&self) -> Result<Option<(String, bool)>> {
        let row = sqlx::query_as::<_, (String, i64)>(
            "SELECT version, installed FROM local_app_sdk_version LIMIT 1",
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query sdk version: {}", e)))?;

        Ok(row.map(|(v, i)| (v, i != 0)))
    }

    /// 判断是否为重新安装（参考 Go SDK 的 reinstalled 逻辑）
    pub async fn is_reinstalled(&self) -> Result<bool> {
        let is_empty = self.is_conversation_id_list_empty().await?;
        if is_empty {
            return Ok(true);
        }

        let version_record = self.get_sdk_version().await?;
        match version_record {
            Some((_, installed)) => Ok(!installed),
            None => Ok(true),
        }
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

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
}
