// 新架构模块（渐进式迁移）
pub mod sdk;
pub mod core;
pub mod domain;
pub mod infra;
pub mod protocol;

// 重新导出消息类型，供桥接与生成的代码使用（protocol 的 build 已为 MsgData 添加 serde）
pub use openim_protocol::sdkws::{MsgData, OfflinePushInfo};
