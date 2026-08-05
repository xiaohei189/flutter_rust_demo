use crate::error::Result;
use async_trait::async_trait;

#[async_trait]
pub trait SyncVersionRepository: Send + Sync {
    async fn is_conversation_id_list_empty(&self) -> Result<bool>;
    async fn get_sdk_version(&self) -> Result<Option<(String, bool)>>;
    async fn is_reinstalled(&self) -> Result<bool>;
    /// 获取同步标志（0=NO_SYNC, 1=SYNC_START, 2=SYNC_END）
    async fn get_sync_flag(&self) -> Result<i32>;
    /// 设置同步标志
    async fn set_sync_flag(&self, flag: i32) -> Result<()>;
    async fn get_version_sync(&self, table_name: &str, entity_id: &str) -> Result<Option<(String, u64)>>;
    async fn set_version_sync(&self, table_name: &str, entity_id: &str, version_id: &str, version: u64) -> Result<()>;
    async fn delete_version_sync(&self, table_name: &str, entity_id: &str) -> Result<()>;
    async fn mark_reinstall_complete(&self, version: &str) -> Result<()>;
}
