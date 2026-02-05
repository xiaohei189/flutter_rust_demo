//! 会话模块
//!
//! 实现 OpenIM SDK 的会话同步功能

pub mod models;
pub mod service;
pub mod types;

// 重新导出主要类型和函数
pub use crate::im::model::conversation::{AllConversationsResp, IncrementalConversationResp};
pub use crate::im::model::conversation::{
    ConversationElem, ConversationIDsResp, ConversationSyncerConfig, EmptyResp, GetConversationReq, GetConversationResp, GetConversationsReq, GetConversationsResp, GetSortedConversationListReq,
    GetSortedConversationListResp, LocalVersionSync, OwnerConversationReq, RequestPagination,
};
pub use api::ConversationApi;
pub use service::ConversationSyncer;
