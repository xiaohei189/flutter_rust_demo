pub mod client;
pub mod dao;
pub mod http_client;

pub mod logger;
pub mod model;
pub mod serialization;
pub mod trace_context;
pub mod util;
pub mod ws_rpc;

// 重新导出认证相关函数（从 http_client 模块）
pub use http_client::login_async;

// 重新导出会话相关类型（ConversationSyncer 已移除，逻辑并入 ConversationHandle）
pub use client::conversation_handle::ConversationHandle;
pub use model::{ConversationSyncerConfig, LocalVersionSync};

// 重新导出好友同步（FriendSyncer 在 client，FriendSyncerConfig 在 model::friend）
pub use client::FriendSyncer;
pub use model::friend::FriendSyncerConfig;

// 重新导出监听器（已迁入 client）
pub use client::{
    AdvancedMsgListener, ConnListener, ConversationListener, EmptyAdvancedMsgListener, EmptyConversationListener, EmptyUserListener, UserListener,
};
pub use model::message::{
    AtElem, AtInfo, ConversationArgs, CustomElem, FileElem, FindMessageListCallback, GetAdvancedHistoryMessageListCallback, GetAdvancedHistoryMessageListParams, LocalChatLog, LocationElem,
    MarkdownEntityElem, MarkdownTextElem, MsgStruct, PictureBaseInfo, PictureElem, QuoteElem, SearchByConversationResult, SearchLocalMessagesCallback, SearchLocalMessagesParams, SoundElem,
    VideoElem,
};
// 消息构建（仅组 MsgData，不发送；与 Go CreateXxxMessage 对齐）
pub use model::{
    create_custom_message, create_file_message, create_image_message_by_url, create_image_message_simple,
    create_location_message, create_quote_message, create_sound_message, create_text_message, create_video_message,
    PictureBaseInfoInput,
};
// DAO 统一出口
pub use dao::{
    AppVersionDao, BlackDao, ChatLogReactionExtensionsDao, ConversationDao, FriendDao, GroupDao, GroupMemberDao, LocalAppSDKVersion, LocalBlack, LocalChatLogReactionExtensions, LocalGroup,
    LocalGroupMember, LocalSendingMessage, LocalStranger, LocalUpload, LocalUser, MessageRepo, SendingMessagesDao, StrangerDao, UploadDao, UserDao, VersionSyncDao,
};

// 重新导出模型相关结构体和函数
pub use model::{AllConversationsResp, ApiResponse, IncrementalConversationResp, LocalConversation, WebSocketConnectResp};
// 重新导出客户端接口与类型
