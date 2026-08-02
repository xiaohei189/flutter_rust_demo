//! SDK 对外 API 契约（特征）
//!
//! 领域层定义 SDK 的公开 API 特征与契约类型；`OpenIMClient` 实现各分域特征，
//! `api/`（FFI 桥接层）与外部调用方都依赖 `SdkApi`，而非具体实现结构体。
//!
//! 分层说明：本模块是 SDK 对外（Dart / 外部集成）的出向契约，与 `domain/ports`（SDK 依赖外部服务的入向契约）方向相反。
//! 分域特征拆分为 `connection.rs` / `conversation.rs` / `friend.rs` / `group.rs` / `message.rs` / `user.rs`。

use crate::domain::model::message::MessageInfo;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

pub mod connection;
pub mod conversation;
pub mod friend;
pub mod group;
pub mod message;
pub mod user;

pub use connection::ConnectionApi;
pub use conversation::ConversationApi;
pub use friend::FriendApi;
pub use group::GroupApi;
pub use message::MessageApi;
pub use user::UserApi;

// ============================================================================
// SDK 对外契约类型
// ============================================================================

/// 历史消息分页查询参数
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetHistoryMessagesReq {
    pub conversation_id: String,
    pub start_client_msg_id: String,
    pub count: i64,
}

/// 历史消息分页结果
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetHistoryMessagesResult {
    pub messages: Vec<MessageInfo>,
    pub is_end: bool,
}

/// 本地消息搜索参数
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SearchMessagesReq {
    pub conversation_id: String,
    pub keyword: String,
}

// ============================================================================
// 组合特征：api / 外部调用方只需依赖这一个对象
// ============================================================================

pub trait SdkApi: ConnectionApi + ConversationApi + FriendApi + GroupApi + MessageApi + UserApi + Send + Sync {}
impl<T: ConnectionApi + ConversationApi + FriendApi + GroupApi + MessageApi + UserApi + Send + Sync> SdkApi for T {}