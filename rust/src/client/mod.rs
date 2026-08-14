//! SDK 门面层 — OpenIMClient + 构建器 + 配置 + 运行时上下文
//!
//! 合并了原 sdk/ 和 domain/sdk_api/ 模块

pub mod builder;
pub mod config;
pub mod context;

// SDK 公开 API 特征（由 OpenIMClient 实现）
pub mod connection;
pub mod conversation;
pub mod friend;
pub mod group;
pub mod message;
pub mod third;
pub mod user;

pub use connection::ConnectionApi;
pub use conversation::ConversationApi;
pub use friend::FriendApi;
pub use group::GroupApi;
pub use message::MessageApi;
pub use third::ThirdApi;
pub use user::UserApi;

// SDK 组合特征
pub trait SdkApi: ConnectionApi + ConversationApi + FriendApi + GroupApi + MessageApi + ThirdApi + UserApi + Send + Sync {}
impl<T: ConnectionApi + ConversationApi + FriendApi + GroupApi + MessageApi + ThirdApi + UserApi + Send + Sync> SdkApi for T {}

// SDK 客户端实现（OpenIMClient）
pub mod core;
pub use core::OpenIMClient;
// SDK 客户端实现（由 OpenIMClient 实现各特征）
// SDK 对外契约类型
/// 历史消息分页查询参数
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetHistoryMessagesReq {
    pub conversation_id: String,
    pub start_client_msg_id: String,
    pub count: i64,
}

/// 历史消息分页结果
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetHistoryMessagesResult {
    pub messages: Vec<crate::model::message::MessageInfo>,
    pub is_end: bool,
}

/// 本地消息搜索参数
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SearchMessagesReq {
    pub conversation_id: String,
    pub keyword: String,
    pub sender_user_ids: Vec<String>,
    pub message_types: Vec<i32>,
    pub start_time: i64,
    pub end_time: i64,
    pub offset: i64,
    pub count: i64,
}
