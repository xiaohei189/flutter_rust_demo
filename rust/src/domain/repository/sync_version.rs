use crate::domain::error::Result;
use async_trait::async_trait;

#[async_trait]
pub trait SyncVersionRepository: Send + Sync {
    async fn is_conversation_id_list_empty(&self) -> Result<bool>;
    async fn get_sdk_version(&self) -> Result<Option<(String, bool)>>;
    async fn is_reinstalled(&self) -> Result<bool>;
    async fn get_version_sync(&self, table_name: &str, entity_id: &str) -> Result<Option<(String, u64)>>;
    async fn set_version_sync(&self, table_name: &str, entity_id: &str, version_id: &str, version: u64) -> Result<()>;
    async fn delete_version_sync(&self, table_name: &str, entity_id: &str) -> Result<()>;
    async fn mark_reinstall_complete(&self, version: &str) -> Result<()>;
}
