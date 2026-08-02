//! 外部服务契约（Ports）
//!
//! 领域层定义的「外界需要提供的能力」接口，由 core/infra 中的适配器实现：
//! - [`sync::SyncServerApi`] — 消息同步的远程数据源（生产：`core::connection::manager::ConnectionManager`）
//! - [`message::MessageServerApi`] — 消息操作的服务端 API（生产：`infra::http::message_api::HttpMessageApi`）
//! - [`conversation::ConversationServerApi`] — 会话同步的服务端 API（生产：`infra::http::conversation_api::HttpConversationApi`）

pub mod sync;
pub mod message;
pub mod conversation;
pub mod friend;
pub mod group;
pub mod online;
pub mod types;
pub mod user;

pub use types::Pagination;

pub use sync::SyncServerApi;
pub use message::{
    DeleteMessagesReq, MarkAllConversationAsReadReq, MarkConversationAsReadReq,
    MarkMessagesAsReadReq, MessageServerApi, RevokeMessageReq,
};
pub use friend::FriendServerApi;
pub use group::GroupServerApi;
pub use online::OnlineStatusServerApi;
pub use user::UserServerApi;
pub use conversation::{
    ConversationServerApi, GetAllConversationsReq, GetAllConversationsResp,
    GetConversationsByIDsReq, GetConversationsByIDsResp, GetFullConversationIDsReq,
    GetFullConversationIDsResp, GetIncrementalConversationReq, GetIncrementalConversationResp,
    ServerConversation,
};