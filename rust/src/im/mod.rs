pub mod auth;
pub mod api;
pub mod client;
pub mod conversation;
pub mod dao;
pub mod db;
pub mod friend;
pub mod http;
pub mod listener;
pub mod logger;
pub mod message;
pub mod model;
pub mod serialization;
pub mod util;

// 重新导出认证相关函数
pub use auth::login_async;

// 重新导出会话同步相关类型和函数
pub use conversation::{ConversationSyncer, ConversationSyncerConfig, LocalVersionSync};

// 重新导出好友相关类型和函数
pub use friend::{FriendSyncer, FriendSyncerConfig};

// 重新导出消息相关类型和函数
pub use listener::{AdvancedMsgListener, EmptyAdvancedMsgListener};
pub use message::{AtElem, AtInfo, CustomElem, FileElem, LocalChatLog, LocationElem, MarkdownEntityElem, MarkdownTextElem, MsgStruct, PictureBaseInfo, PictureElem, QuoteElem, SoundElem, VideoElem};
// DAO 统一出口
pub use dao::{ConversationDao, FriendDao, MessageRepo, VersionSyncDao};

// 重新导出模型相关结构体和函数
pub use model::{AllConversationsResp, ApiResponse, IncrementalConversationResp, LocalConversation, WebSocketConnectResp};
// 重新导出客户端接口与类型
