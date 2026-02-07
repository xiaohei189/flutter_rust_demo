use crate::im::dao::migration;
use crate::im::{ConversationDao, FriendDao, MessageRepo, VersionSyncDao, dao::notification::NotificationDao};
use anyhow::Result;
use sqlx::{Pool, Sqlite};

#[derive(Clone)]
pub struct Repository {
    pub pool: Pool<Sqlite>,
    pub conversation: ConversationDao,
    pub version_sync: VersionSyncDao,
    pub friend: FriendDao,
    pub notification_dao: NotificationDao,
    pub message: MessageRepo,
}

impl Repository {
    /// 从数据库 URL 创建：先建连接池并**立即执行迁移**，再构造 Repository。
    pub async fn create(db_url: &str) -> Result<Self> {
        let pool = migration::create_pool_and_migrate(db_url).await?;
        Ok(Self::new(pool))
    }

    /// 从已有连接池构造（调用方需已执行迁移，或使用 `Repository::create` 自动迁移）。
    pub fn new(db: Pool<Sqlite>) -> Self {
        Self {
            pool: db.clone(),
            conversation: ConversationDao::new(db.clone()),
            version_sync: VersionSyncDao::new(db.clone(), "test_user_id".to_string()),
            notification_dao: NotificationDao::new(db.clone()),
            message: MessageRepo::new(db.clone(), "test_user_id".to_string()),
            friend: FriendDao::new(db.clone(), "test_user_id".to_string()),
        }
    }
}