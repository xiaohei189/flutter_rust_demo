//! FriendApi — SDK 对外 API 契约（分域特征）
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
pub trait FriendApi : Send + Sync {
    fn take_friend_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<FriendEvent>, SdkError>;
    async fn get_friend_list(&self) -> Vec<FriendInfo>;
    async fn sync_friends(&self) -> Result<()>;
    async fn add_friend(&self, user_id: &str, req_msg: Option<&str>) -> Result<()>;
    async fn delete_friend(&self, user_id: &str) -> Result<()>;
    async fn get_black_list(&self) -> Vec<String>;
    async fn is_friend(&self, user_id: &str) -> bool;
    async fn check_friend(&self, user_ids: Vec<String>) -> std::result::Result<Vec<crate::http::friend::CheckFriendResult>, SdkError>;
    async fn add_black(&self, user_id: &str) -> Result<()>;
    async fn remove_black(&self, user_id: &str) -> Result<()>;
    async fn is_in_blacklist(&self, user_id: &str) -> bool;
    async fn get_friend_apply_list(&self) -> std::result::Result<Vec<FriendApplyInfo>, SdkError>;
    async fn get_friend_apply_list_as_applicant(&self) -> std::result::Result<Vec<FriendApplyInfo>, SdkError>;
    async fn get_friend_application_unhandled_count(&self) -> Result<i32>;
    async fn accept_friend_application(&self, user_id: &str, handle_msg: Option<&str>) -> Result<()>;
    async fn refuse_friend_application(&self, user_id: &str, handle_msg: Option<&str>) -> Result<()>;
    async fn get_friend_id_list(&self) -> Vec<String>;
    async fn sync_friends_incremental(&self) -> Result<()>;
    async fn search_friends(&self, keyword: &str) -> Result<Vec<SearchFriendItem>>;
    async fn get_specified_friends_info(&self, friend_user_ids: Vec<String>, filter_black: bool,) -> Result<Vec<FriendInfo>>;
    async fn get_friend_list_page(&self, offset: i32, count: i32, filter_black: bool,) -> Result<Vec<FriendInfo>>;
    async fn update_friends(&self, friend_user_ids: Vec<String>, is_pinned: Option<bool>, remark: Option<String>, ex: Option<String>,) -> Result<()>;
}
