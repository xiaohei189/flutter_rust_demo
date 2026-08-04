mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

// 模块按依赖方向从底层到上层排列
pub mod model;
pub mod error;
pub mod constant;
pub mod cache;
pub mod logger;
pub mod file;
pub mod db;
pub mod http;
pub mod util;

pub mod event;
pub mod connection;
pub mod message;
pub mod conversation;
pub mod friend;
pub mod group;
pub mod user;
pub mod client;
pub mod ffi;

// 重新导出消息类型，供桥接与生成的代码使用（openim-protocol 的 build 已为 MsgData 添加 serde）
pub use openim_protocol::sdkws::{MsgData, OfflinePushInfo, PullMsgs};