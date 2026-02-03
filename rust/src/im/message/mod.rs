//! 消息模块
//!
//! 实现 OpenIM SDK 的消息处理功能

pub mod binary_handler;
pub mod handler;
pub mod longconn;
pub mod models;
pub mod sync;
pub mod sync_long;
pub mod types;
pub mod ws_rpc;

pub use crate::im::model::message::*;
pub use crate::im::api::message::MessageApi;
// pub use binary_handler::{BinaryMessageHandler, BinaryMessageHandlerCallbacks};
pub use handler::{MessageHandler, MessageHandlerContext, MessageOptions};
pub use longconn::{HttpFallbackLongConn, LongConnRpc};
pub use sync::MessageSyncer;
pub use sync_long::{LongConnMessageSyncer, PushBatch};
pub use ws_rpc::{WsMessageRpc, WsRpcClient};
