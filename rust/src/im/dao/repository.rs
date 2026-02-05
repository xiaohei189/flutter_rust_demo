use crate::im::{ConversationDao, FriendDao, MessageRepo, VersionSyncDao, dao::notification::NotificationDao};

use sqlx::{Pool, Sqlite};

#[derive(Clone)]
pub struct Repository  {
    pub conversation: ConversationDao,
    pub version_sync: VersionSyncDao,
    pub friend: FriendDao,
    pub notification_dao: NotificationDao,
    pub message: MessageRepo,
}

impl Repository {
    pub fn new(db: Pool<Sqlite>) -> Self {
        Self {
            conversation: ConversationDao::new(db.clone()),
            version_sync: VersionSyncDao::new(db.clone(), "test_user_id".to_string()),
            notification_dao: NotificationDao::new(db.clone()),
            message: MessageRepo::new(db.clone(), "test_user_id".to_string()),
            friend: FriendDao::new(db.clone(), "test_user_id".to_string()),
        }
    }
}