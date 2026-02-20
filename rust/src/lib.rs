mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
pub mod api;
pub mod im;

// 重新导出常用类型和函数，方便外部使用
pub use im::{
    client::IMClient, login_async, ConversationSyncerConfig, IncrementalConversationResp, LocalConversation, LocalGroup, LocalGroupMember,
};

// 重新导出 OfflinePushInfo，以便生成的代码可以访问
pub use openim_protocol::sdkws::OfflinePushInfo;
