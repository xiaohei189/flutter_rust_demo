//! 消息模块
//!
//! 实现 OpenIM SDK 的消息处理功能

pub mod dao;
pub mod listener;
pub mod models;
pub mod types;
pub mod api;
pub mod sync;
pub mod sync_long;
pub mod longconn;

// 重新导出主要类型和函数
pub use dao::MessageStore;
pub use listener::{AdvancedMsgListener, EmptyAdvancedMsgListener};
pub use models::LocalChatLog;
pub use models::{
    SendMsgReq, RevokeMsgReq, MarkMsgsAsReadReq, MarkConversationAsReadReq,
    SetConversationHasReadSeqReq, ClearConversationsMsgReq, UserClearAllMsgReq, DeleteMsgsReq,
    DeleteMsgPhysicalReq, DeleteMsgPhysicalBySeqReq, PullMessageBySeqsReq, BatchSendMsgReq,
    SendSimpleMsgReq, DeleteSyncOpt, SeqRange, SearchMessageReq, PullMsgs, SendMsgResp,
    ServerTimeResp, PullMessageBySeqsResp, SearchMessageResp, EmptyResp, CheckMsgIsSendSuccessReq,
    CheckMsgIsSendSuccessResp, GetNewestSeqReq, GetNewestSeqResp, SendBusinessNotificationReq,
};
pub use types::{
    AtElem, AtInfo, CustomElem, FileElem, LocationElem, MarkdownEntityElem, MarkdownTextElem,
    MessageRevoked, MsgStruct, OANotificationElem, PictureElem, PictureBaseInfo, QuoteElem,
    RevokeElem, SoundElem, StreamMsgElem, TextElem, TypingStatus, VideoElem,
};
pub use sync::MessageSyncer;
pub use sync_long::{LongConnMessageSyncer, PushBatch};
pub use longconn::{LongConnRpc, HttpFallbackLongConn};

