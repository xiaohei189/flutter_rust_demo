pub mod bridge_client;
pub mod listeners;
pub mod logger;
pub mod simple;

// 重新导出主要类型（桥接客户端对外暴露）
pub use bridge_client::{login_async, OpenIMBridgeClient};
pub use listeners::{ConnectionStatusEvent, ConversationEvent, MessageEvent};
pub use logger::{init_logger, init_logger_simple, LoggerConfig};
// LoginResponse 和 LoginData 从 im::auth 模块导出
pub use crate::im::auth::{LoginResponse, LoginData};
// 重新导出 AdvancedMsgListener，以便 flutter_rust_bridge 可以生成 Dart 代码
pub use crate::im::message::listener::AdvancedMsgListener;
// 重新导出 Arc 和 Mutex，以便生成的代码可以访问
pub use std::sync::{Arc, Mutex};
// 重新导出 OfflinePushInfo，以便生成的代码可以访问
pub use openim_protocol::sdkws::OfflinePushInfo;
