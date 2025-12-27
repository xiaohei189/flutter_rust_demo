pub mod bridge_client;
pub mod listeners;
pub mod logger;
pub mod simple;

// 重新导出主要类型（桥接客户端对外暴露）
pub use bridge_client::{login_async, OpenIMBridgeClient};
pub use listeners::{ConnectionStatusEvent, ConversationChangedEvent, MessageEvent};
pub use logger::{init_logger, init_logger_simple, LoggerConfig};
// LoginResponse 和 LoginData 从 im::auth 模块导出
pub use crate::im::auth::{LoginResponse, LoginData};
