pub mod conversation_dao;
pub mod friend_dao;
pub mod group_dao;
pub mod message_dao;
pub mod misc_dao;
pub mod pool;
pub mod sync_version_dao;
pub mod user_dao;

// Repository trait 定义（由 DAO 实现）
pub mod conversation;
pub mod friend;
pub mod group;
pub mod message;
pub mod notification_seq;
pub mod sending_message;
pub mod sync_version;
pub mod user;

pub use conversation_dao::ConversationDao;
pub use friend_dao::FriendDao;
pub use group_dao::GroupDao;
pub use message_dao::MessageDao;
pub use misc_dao::{NotificationSeqDao, SendingMessageDao, UploadDao};
pub use pool::{create_pool, create_pool_memory};
pub use sync_version_dao::SyncVersionDao;
pub use user_dao::{BlackDao, UserDao};

// 重新导出 repository trait
pub use conversation::ConversationRepository;
pub use friend::FriendRepository;
pub use group::GroupRepository;
pub use message::MessageRepository;
pub use notification_seq::NotificationSeqRepository;
pub use sending_message::SendingMessageRepository;
pub use sync_version::SyncVersionRepository;
pub use user::UserRepository;
