use crate::im::{ConversationDao, FriendDao, MessageRepo, dao::notification::NotificationDao};

use sqlx::{Pool, Sqlite};

pub struct Repository  {
    pub conversation_dao: ConversationDao,
    pub notification_dao: NotificationDao,
    pub message_repo: MessageRepo,
}

impl Repository {
    pub fn new(db: Pool<Sqlite>) -> Self {
        Self {
            conversation_dao: ConversationDao::new(db.clone()),
            notification_dao: NotificationDao::new(db.clone()),
            message_repo: MessageRepo::new(db.clone(), "test_user_id".to_string()),
        }
    }
}