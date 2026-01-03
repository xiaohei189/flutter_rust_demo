pub mod auth;
pub mod client;
pub mod conversation;
pub mod friend;
pub mod message;
pub mod dao;
pub mod listener;
pub mod serialization;
pub mod model;
pub mod db;
pub mod http;
pub mod logger;

// 重新导出认证相关函数
pub use auth::login_async;

// 重新导出会话同步相关类型和函数
pub use conversation::{ConversationSyncer, ConversationSyncerConfig, LocalVersionSync};

// 重新导出好友相关类型和函数
pub use friend::{FriendSyncer, FriendSyncerConfig};

// 重新导出消息相关类型和函数
pub use listener::{AdvancedMsgListener, EmptyAdvancedMsgListener};
pub use message::{
    AtElem, AtInfo, CustomElem, FileElem, LocalChatLog, LocationElem, MarkdownEntityElem,
    MarkdownTextElem, MsgStruct, PictureBaseInfo, PictureElem, QuoteElem, SoundElem, VideoElem,
};
// DAO 统一出口
pub use dao::{MessageStore, FriendDao, ConversationDao, VersionSyncDao};

// 重新导出模型相关结构体和函数
pub use model::{
    AllConversationsResp, ApiResponse, IncrementalConversationResp, LocalConversation,
    WebSocketConnectResp,
};
// 重新导出客户端接口与类型
pub use client::{OpenIMClientApi, OpenIMClient, ClientConfig};
