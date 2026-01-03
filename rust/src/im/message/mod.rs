//! 消息模块
//!
//! 实现 OpenIM SDK 的消息处理功能

pub mod models;
pub mod types;
pub mod api;
pub mod sync;
pub mod sync_long;
pub mod longconn;

pub use crate::im::model::message::*;
pub use sync::MessageSyncer;
pub use sync_long::{LongConnMessageSyncer, PushBatch};
pub use longconn::{LongConnRpc, HttpFallbackLongConn};

