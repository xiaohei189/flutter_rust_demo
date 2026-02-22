mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
pub mod api;
pub mod im;

// 重新导出常用类型和函数，方便外部使用
pub use im::{
    client::IMClient, login_async, ConversationSyncerConfig, IncrementalConversationResp, LocalConversation, LocalGroup, LocalGroupMember,
};

// 重新导出消息类型，供桥接与生成的代码使用（protocol 的 build 已为 MsgData 添加 serde）
pub use openim_protocol::sdkws::{MsgData, OfflinePushInfo};
