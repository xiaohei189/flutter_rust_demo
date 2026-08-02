//! ConversationApi — SDK 对外 API 契约（分域特征）
//!
//! 由 OpenIMClient 实现，pi/ 层依赖组合特征 SdkApi。

use crate::domain::constant::GroupType;
use crate::domain::error::{Result, SdkError};
use crate::domain::model::friend::FriendInfo;
use crate::domain::model::group::{GroupInfo, GroupMember};
use crate::domain::model::local::{LocalChatLog, LocalConversation};
use crate::domain::model::message::MessageInfo;
use crate::domain::model::msg_struct::{AtInfo, MessageEntity, MsgStruct};
use crate::domain::model::user::UserInfo;
use crate::domain::ports::friend::{CheckFriendResult, FriendApplyInfo, SearchFriendItem};
use crate::domain::ports::group::GroupApplyInfo;
use crate::domain::ports::message::{DeleteMessagesReq, MarkMessagesAsReadReq, RevokeMessageReq};
use crate::domain::ports::online::OnlineStatus;
use crate::event::events::connection::ConnectionEvent;
use crate::event::events::conversation::ConversationEvent;
use crate::event::events::friend::FriendEvent;
use crate::event::events::group::GroupEvent;
use crate::event::events::message::MessageEvent;
use crate::event::events::user::UserEvent;
use async_trait::async_trait;
use openim_protocol::sdkws::{OfflinePushInfo, UserSendMsgResp};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

#[async_trait]
pub trait ConversationApi : Send + Sync {
    fn take_conv_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<ConversationEvent>, SdkError>;
    async fn sync_all_conversation_hash_read_seqs(&self) -> Result<()>;
    async fn incr_sync_conversations(&self) -> Result<()>;
    fn get_conversation_id_by_session_type(&self, source_id: &str, session_type: i32) -> String;
    async fn get_conversations(&self) -> std::result::Result<Vec<LocalConversation>, SdkError>;
    async fn get_conversation(&self, conversation_id: &str) -> std::result::Result<Option<LocalConversation>, SdkError>;
    async fn update_conversation_unread_count(&self, conversation_id: &str, unread_count: i64) -> Result<()>;
    async fn set_conversation_pinned(&self, conversation_id: &str, is_pinned: bool) -> Result<()>;
    async fn delete_conversation(&self, conversation_id: &str) -> Result<()>;
    async fn set_conversation_draft(&self, conversation_id: &str, draft_text: &str) -> Result<()>;
    async fn set_conversation_private(&self, conversation_id: &str, is_private: bool) -> Result<()>;
    async fn get_pinned_conversations(&self) -> std::result::Result<Vec<LocalConversation>, SdkError>;
    async fn clear_conversation_draft(&self, conversation_id: &str) -> Result<()>;
    async fn mark_conversation_message_as_read(&self, conversation_id: String, session_type: i32) -> Result<()>;
    async fn mark_all_conversation_as_read(&self) -> Result<()>;
    async fn get_conversation_list_split(&self, offset: i64, count: i64,) -> std::result::Result<Vec<LocalConversation>, SdkError>;
    async fn get_multiple_conversations(&self, conversation_ids: Vec<String>,) -> std::result::Result<Vec<LocalConversation>, SdkError>;
    async fn search_conversations(&self, keyword: &str,) -> std::result::Result<Vec<LocalConversation>, SdkError>;
    async fn hide_conversation(&self, conversation_id: &str,) -> std::result::Result<(), SdkError>;
    async fn set_conversation(&self, conversation_id: &str, recv_msg_opt: Option<i32>, is_pinned: Option<bool>, is_private_chat: Option<bool>, group_at_type: Option<i32>, ex: Option<&str>,) -> Result<()>;
}
