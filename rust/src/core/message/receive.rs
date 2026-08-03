//! ① 接收管道: Server → [Syncer] → [Handler] → DB + Events
//!
//! 数据流方向：服务端推送/拉取 → 同步器 → 处理器 → 入库 + 事件分发

pub(crate) mod checker;
mod syncer;
mod max_seq_recorder;
pub(crate) mod processor;
mod receipt;
pub(crate) mod revoke;

pub use syncer::{MessageSyncer, is_notification};
pub use max_seq_recorder::MaxSeqRecorder;
pub use processor::MessageProcessor;
pub(crate) use crate::domain::model::revoke::{RevokeTipsWithNickname, parse_revoke_tips_from_json};

