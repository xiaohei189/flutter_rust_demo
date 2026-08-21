mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

// 五层骨架（目标分层，先 re-export 现有扁平模块）
pub mod api;
pub mod core;
pub mod domain;
pub mod infra;
pub mod sdk;

// 模块按依赖方向从底层到上层排列

pub mod client;
pub mod ffi;
pub mod friend;
pub mod group;

// 重新导出消息类型，供桥接与生成的代码使用（openim-protocol 的 build 已为 MsgData 添加 serde）
pub use openim_protocol::sdkws::{MsgData, OfflinePushInfo, PullMsgs};
