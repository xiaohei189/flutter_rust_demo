//! # 消息子系统
//!
//! ## 核心数据流（按此顺序阅读）
//!
//! ```text
//! ① receive/  Server → Syncer → Handler → DB + Events
//! ② send/     Client → Queue → Connection → Server
//! ③ operate/  Client → Service → HTTP API + DB + Events
//! ```
//!
//! ## 快速定位
//!
//! | 我想看... | 打开 |
//! |-----------|------|
//! | 消息怎么从服务端拉下来 | `receive/syncer.rs` → `sync_on_login` |
//! | 消息怎么分类入库 | `receive/handler.rs` → `handle_messages_internal` |
//! | 消息怎么发出去 | `send/queue.rs` → `submit` |
//! | 撤回/删除/已读怎么做 | `operate/` 各文件 |
//! | 模块依赖哪些外部接口 | `domain::ports` |
//!
//! ## 支撑设施
//! - `shared/content_type.rs` — content_type 分类工具
//! - `checker.rs` — [WIP] seq gap 检查，未接入

pub mod receive;
pub mod send;
pub mod operate;
pub mod shared;
pub mod checker;
pub mod notification;

// Facade re-exports: 外部引用路径兼容
pub use receive::{MessageHandler, MessageSyncer, MaxSeqRecorder};
pub use send::MessageSendQueue;
pub use operate::{MessageService, MessageServerApi};
pub use crate::domain::ports::SyncerRemoteApi;
pub use shared::content_type::ContentTypeUtils;
