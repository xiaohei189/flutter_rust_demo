use crate::im::dao::migration;
use crate::im::dao::notification::NotificationDao;
use crate::im::{
    AppVersionDao, BlackDao, ChatLogReactionExtensionsDao, ConversationDao, FriendDao, GroupDao,
    GroupMemberDao, MessageRepo, SendingMessagesDao, StrangerDao, UploadDao, UserDao, VersionSyncDao,
};
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
    pub app_version: AppVersionDao,
    pub user: UserDao,
    pub sending_messages: SendingMessagesDao,
    pub group: GroupDao,
    pub group_member: GroupMemberDao,
    pub stranger: StrangerDao,
    pub upload: UploadDao,
    pub black: BlackDao,
    pub chat_log_reaction_extensions: ChatLogReactionExtensionsDao,
}

impl Repository {
    /// 从数据库 URL 创建：先建连接池并**立即执行迁移**，再构造 Repository。
    /// 使用默认 login_user_id（空串），若需指定请先 create_pool_and_migrate 再 `Repository::new(pool, user_id)`。
    pub async fn create(db_url: &str) -> Result<Self> {
        let pool = migration::create_pool_and_migrate(db_url).await?;
        Ok(Self::new(pool, ""))
    }

    /// 从已有连接池构造（调用方需已执行迁移，或使用 `Repository::create` 自动迁移）。
    /// login_user_id 用于 friend / message / black 等需要“当前用户”的 DAO。
    pub fn new(db: Pool<Sqlite>, login_user_id: &str) -> Self {
        let uid = login_user_id.to_string();
        Self {
            pool: db.clone(),
            conversation: ConversationDao::new(db.clone()),
            version_sync: VersionSyncDao::new(db.clone(), uid.clone()),
            notification_dao: NotificationDao::new(db.clone()),
            message: MessageRepo::new(db.clone(), uid.clone()),
            friend: FriendDao::new(db.clone(), uid.clone()),
            app_version: AppVersionDao::new(db.clone()),
            user: UserDao::new(db.clone()),
            sending_messages: SendingMessagesDao::new(db.clone()),
            group: GroupDao::new(db.clone()),
            group_member: GroupMemberDao::new(db.clone()),
            stranger: StrangerDao::new(db.clone()),
            upload: UploadDao::new(db.clone()),
            black: BlackDao::new(db.clone(), uid),
            chat_log_reaction_extensions: ChatLogReactionExtensionsDao::new(db.clone()),
        }
    }
}