//! # 消息子系统
//!
//! ## 核心数据流（按此顺序阅读）
//!
//! `	ext
//! 1. receive/  Server -> Syncer -> Handler -> DB + Events
//! 2. send/     Client -> Queue -> Connection -> Server
//! 3. operate/  Client -> Service -> HTTP API + DB + Events
//! `

pub mod operate;

pub mod notification;
// Facade re-exports: 外部引用路径兼容
pub use crate::connection::sync_server::SyncServerApi;
pub use crate::constant::content_type_utils::ContentTypeUtils;
pub use crate::http::message::MessageServerApi;
pub use operate::MessageService;
pub use receive::{MaxSeqRecorder, MessageProcessor, MessageSyncer};
pub use send::MessageSendQueue;

// 接收管道（内联自 receive.rs）
pub(crate) mod receive {
    pub(crate) mod checker;
    mod max_seq_recorder;
    pub(crate) mod processor;
    mod receipt;
    pub(crate) mod revoke;
    mod syncer;

    pub use max_seq_recorder::MaxSeqRecorder;
    pub use processor::MessageProcessor;
    pub use syncer::MessageSyncer;
}

// 发送管道（内联自 send.rs）
pub(crate) mod send {
    mod queue;
    pub(crate) mod sender;

    pub use queue::MessageSendQueue;
    pub use sender::MessageSender;
}
