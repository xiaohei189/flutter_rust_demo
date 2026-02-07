//! 消息模块
//!
//! 实现 OpenIM SDK 的消息处理功能

pub mod binary_handler;
pub mod handler;
pub mod models;

pub mod types;

pub use crate::im::model::message::*;
pub use crate::im::api::message::MessageApi;
// pub use binary_handler::{BinaryMessageHandler, BinaryMessageHandlerCallbacks};
pub use handler::{MessageHandler, MessageHandlerContext, MessageOptions};
