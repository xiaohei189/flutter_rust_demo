//! 核心业务层：连接、会话、消息、事件、用户在线。
//! 当前 re-export 扁平模块；逐步把对应模块迁移到本目录。

pub use crate::{connection, conversation, event, message, user};
