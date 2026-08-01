mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

// 模块按依赖方向从底层到上层排列
pub mod domain;     // 0 依赖
pub mod infra;      // 依赖 domain
pub mod protocol;   // 依赖 domain
pub mod event;      // 依赖 domain + protocol
pub mod core;       // 依赖 domain + infra + event
pub mod listener;   // 依赖 core + event
pub mod sdk;        // 依赖 core
pub mod api;        // 依赖 sdk（最上层，供 frb_generated 使用）

// 重新导出消息类型，供桥接与生成的代码使用（protocol 的 build 已为 MsgData 添加 serde）
pub use openim_protocol::sdkws::{MsgData, OfflinePushInfo, PullMsgs};