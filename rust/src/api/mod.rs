pub mod bridge_client;
pub mod simple;

// 重新导出主要类型（桥接客户端对外暴露）
pub use bridge_client::OpenIMBridgeClient;
// 重新导出认证函数（从 im 模块）
pub use crate::im::{login, login_async};
