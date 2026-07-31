use crate::domain::error::types::Result;
use crate::infra::database::models::LocalFriend;
use async_trait::async_trait;

#[async_trait]
pub trait FriendRepository: Send + Sync {
    async fn upsert(&self, friend: &LocalFriend) -> Result<()>;
    async fn batch_upsert(&self, friends: &[LocalFriend]) -> Result<()>;
    async fn get_all(&self, owner_user_id: &str) -> Result<Vec<LocalFriend>>;
    async fn get_by_id(&self, owner_user_id: &str, friend_user_id: &str) -> Result<Option<LocalFriend>>;
    async fn delete(&self, owner_user_id: &str, friend_user_id: &str) -> Result<()>;
    async fn batch_delete(&self, owner_user_id: &str, friend_user_ids: &[String]) -> Result<()>;
    async fn search_friends(&self, owner_user_id: &str, keyword: &str) -> Result<Vec<LocalFriend>>;
}
