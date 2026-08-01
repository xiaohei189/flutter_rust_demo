//! Repository traits — 领域层定义的数据访问接口
//!
//! core/ 层通过 trait 依赖数据访问，infra/ 层提供具体实现。
//! 依赖方向: core → domain/repository ← infra

pub mod message;
pub mod conversation;
pub mod friend;
pub mod group;
pub mod user;
pub mod sync_version;
pub mod notification_seq;
pub mod sending_message;

pub use message::MessageRepository;
pub use conversation::ConversationRepository;
pub use friend::FriendRepository;
pub use group::GroupRepository;
pub use user::UserRepository;
pub use sync_version::SyncVersionRepository;
pub use notification_seq::NotificationSeqRepository;
pub use sending_message::SendingMessageRepository;
