//! # 消息子系统
//!
//! ## 核心数据流（按此顺序阅读）
//!
//! `	ext
//! 1. receive/  Server -> Syncer -> Handler -> DB + Events
//! 2. send/     Client -> Queue -> Connection -> Server
//! 3. operate/  Client -> Service -> HTTP API + DB + Events
//! `

pub mod receive;
pub mod send;
pub mod operate;


pub mod notification;
// Facade re-exports: 外部引用路径兼容
pub use receive::{MessageProcessor, MessageSyncer, MaxSeqRecorder};
pub use send::MessageSendQueue;
pub use operate::MessageService;
pub use crate::http::message::MessageServerApi;
pub use crate::connection::sync_server::SyncServerApi;
pub use crate::constant::content_type_utils::ContentTypeUtils;

