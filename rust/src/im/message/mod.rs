//! 消息模块
//!
//! 实现 OpenIM SDK 的消息处理功能

pub mod models;
pub mod types;
pub mod api;
pub mod sync;
pub mod sync_long;
pub mod longconn;
pub mod handler;
pub mod ws_rpc;
pub mod binary_handler;

pub use crate::im::model::message::*;
pub use sync::MessageSyncer;
pub use sync_long::{LongConnMessageSyncer, PushBatch};
pub use longconn::{LongConnRpc, HttpFallbackLongConn};
pub use handler::{MessageHandler, MessageHandlerContext, MessageOptions};
pub use ws_rpc::{WsMessageRpc, WsRpcClient};
pub use binary_handler::{BinaryMessageHandler, BinaryMessageHandlerCallbacks};

