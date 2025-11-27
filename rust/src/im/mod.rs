pub mod types;
pub mod serialization;
pub mod auth;
pub mod client;
pub mod msg;
pub mod conversation;
pub mod entities;

// 重新导出认证相关函数（供 api 模块使用）
pub use auth::login_async;

// 重新导出会话同步相关类型和函数
pub use conversation::{
    ConversationSyncer, ConversationSyncerConfig, LocalConversation, LocalVersionSync,
};

