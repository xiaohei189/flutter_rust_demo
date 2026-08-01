use crate::domain::error::Result;
use crate::infra::database::models::LocalUser;
use async_trait::async_trait;

#[async_trait]
pub trait UserRepository: Send + Sync {
    async fn upsert(&self, user: &LocalUser) -> Result<()>;
    async fn batch_upsert(&self, users: &[LocalUser]) -> Result<()>;
    async fn get_by_id(&self, user_id: &str) -> Result<Option<LocalUser>>;
    async fn delete(&self, user_id: &str) -> Result<()>;
}
