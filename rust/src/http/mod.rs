pub mod client;
pub mod conversation_api;
pub mod friend_api;
pub mod group_api;
pub mod message_api;
pub mod online_api;
pub mod routes;
pub mod user_api;

// Port trait 定义与请求/响应 DTO（由 HTTP API 实现）
pub mod conversation;
pub mod friend;
pub mod group;
pub mod message;
pub mod online;
pub mod types;
pub mod user;

pub use types::Pagination;
// 重新导出 port trait（供 core/ 层使用）
pub use conversation::ConversationServerApi;
pub use friend::FriendServerApi;
pub use group::GroupServerApi;
pub use message::MessageServerApi;
pub use online::OnlineStatusServerApi;
pub use user::UserServerApi;
