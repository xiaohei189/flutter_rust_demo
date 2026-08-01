use crate::domain::error::Result;
use crate::infra::database::models::{LocalGroup, LocalGroupMember};
use async_trait::async_trait;

#[async_trait]
pub trait GroupRepository: Send + Sync {
    async fn upsert_group(&self, group: &LocalGroup) -> Result<()>;
    async fn get_all_groups(&self) -> Result<Vec<LocalGroup>>;
    async fn get_group(&self, group_id: &str) -> Result<Option<LocalGroup>>;
    async fn delete_group(&self, group_id: &str) -> Result<()>;
    async fn upsert_member(&self, member: &LocalGroupMember) -> Result<()>;
    async fn batch_upsert_members(&self, members: &[LocalGroupMember]) -> Result<()>;
    async fn get_members(&self, group_id: &str) -> Result<Vec<LocalGroupMember>>;
    async fn delete_member(&self, group_id: &str, user_id: &str) -> Result<()>;
    async fn delete_members_by_group(&self, group_id: &str) -> Result<()>;
}
