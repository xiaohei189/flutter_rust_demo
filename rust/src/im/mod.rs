pub mod api;
pub mod client;
pub mod dao;
pub mod friend;
pub mod http;

pub mod listener;
pub mod logger;
pub mod message;
pub mod model;
pub mod serialization;
pub mod trace_context;
pub mod util;

// 重新导出认证相关函数（从 http 模块）
pub use http::login_async;

// 重新导出会话相关类型（ConversationSyncer 已移除，逻辑并入 ConversationHandle）
pub use client::conversation_handle::ConversationHandle;
pub use model::{ConversationSyncerConfig, LocalVersionSync};

// 重新导出好友相关类型和函数
pub use friend::{FriendSyncer, FriendSyncerConfig};

// 重新导出消息相关类型和函数
pub use listener::{AdvancedMsgListener, EmptyAdvancedMsgListener};
pub use message::{AtElem, AtInfo, CustomElem, FileElem, LocalChatLog, LocationElem, MarkdownEntityElem, MarkdownTextElem, MsgStruct, PictureBaseInfo, PictureElem, QuoteElem, SoundElem, VideoElem};
// DAO 统一出口
pub use dao::{
    AppVersionDao, BlackDao, ChatLogReactionExtensionsDao, ConversationDao, FriendDao, GroupDao,
    GroupMemberDao, LocalAppSDKVersion, LocalBlack, LocalChatLogReactionExtensions, LocalGroup,
    LocalGroupMember, LocalSendingMessage, LocalStranger, LocalUpload, LocalUser, MessageRepo,
    SendingMessagesDao, StrangerDao, UploadDao, UserDao, VersionSyncDao,
};

// 重新导出模型相关结构体和函数
pub use model::{AllConversationsResp, ApiResponse, IncrementalConversationResp, LocalConversation, WebSocketConnectResp};
// 重新导出客户端接口与类型
