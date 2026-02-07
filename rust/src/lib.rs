pub mod api;
pub mod im;

// 重新导出常用类型和函数，方便外部使用
pub use im::{
    client::OpenIMClient,
    login_async,
    AllConversationsResp, ConversationSyncer, ConversationSyncerConfig, IncrementalConversationResp,
    LocalConversation,
};

// 重新导出 OfflinePushInfo，以便生成的代码可以访问
pub use api::OfflinePushInfo;
pub use im::client::client::ClientConfig;
mod frb_generated;
