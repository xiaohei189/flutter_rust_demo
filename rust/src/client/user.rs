//! UserApi — SDK 对外 API 契约（分域特征）
//!
//! 由 OpenIMClient 实现，pi/ 层依赖组合特征 SdkApi。

use crate::constant::GroupType;
use crate::error::{Result, SdkError};
use crate::model::friend::FriendInfo;
use crate::model::group::{GroupInfo, GroupMember};
use crate::model::local::{LocalChatLog, LocalConversation};
use crate::model::message::MessageInfo;
use crate::model::msg_struct::{AtInfo, MessageEntity, MsgStruct};
use crate::model::user::UserInfo;
use crate::http::friend::{CheckFriendResult, FriendApplyInfo, SearchFriendItem};
use crate::http::group::GroupApplyInfo;
use crate::http::message::{DeleteMessagesReq, MarkMessagesAsReadReq, RevokeMessageReq};
use crate::http::online::OnlineStatus;
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
pub trait UserApi : Send + Sync {
    fn take_user_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<UserEvent>, SdkError>;
    async fn get_user_status(&self, user_ids: &[String]) -> Result<Vec<OnlineStatus>>;
    async fn subscribe_users_status(&self, user_ids: Vec<String>) -> Result<Vec<OnlineStatus>>;
    async fn unsubscribe_users_status(&self, user_ids: Vec<String>) -> Result<()>;
    async fn get_users_info(&self, user_ids: &[String]) -> Result<Vec<UserInfo>>;
    async fn get_self_user_info(&self) -> Result<UserInfo>;
    async fn update_user_profile(&self, nickname: Option<&str>, face_url: Option<&str>, ex: Option<&str>,) -> Result<()>;
    async fn set_global_msg_recv_opt(&self, global_recv_opt: i32) -> Result<()>;
}
