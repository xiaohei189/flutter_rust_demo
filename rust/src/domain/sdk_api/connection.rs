//! ConnectionApi — SDK 对外 API 契约（分域特征）
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
pub trait ConnectionApi : Send + Sync {
    fn take_conn_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<ConnectionEvent>, SdkError>;
    async fn connect(&self, ws_url: &str, token: &str, user_id: &str) -> Result<()>;
    async fn disconnect(&self);
    async fn login(&self, user_id: &str, token: &str) -> Result<()>;
    async fn logout(&self) -> Result<()>;
    fn login_user_id(&self) -> String;
    async fn get_connection_state(&self) -> crate::core::connection::manager::ConnectionState;
    async fn is_connected(&self) -> bool;
}
