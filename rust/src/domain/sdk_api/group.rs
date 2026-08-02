//! GroupApi — SDK 对外 API 契约（分域特征）
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
pub trait GroupApi : Send + Sync {
    fn take_group_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<GroupEvent>, SdkError>;
    async fn get_group_list(&self) -> Vec<GroupInfo>;
    async fn create_group(&self, group_name: &str, group_type: GroupType, member_ids: &[String],) -> Result<GroupInfo>;
    async fn join_group(&self, group_id: &str, req_msg: Option<&str>) -> Result<()>;
    async fn quit_group(&self, group_id: &str) -> Result<()>;
    async fn get_group_members(&self, group_id: &str) -> Result<Vec<GroupMember>>;
    async fn invite_group_members(&self, group_id: &str, member_ids: &[String], reason: Option<&str>) -> Result<()>;
    async fn kick_group_members(&self, group_id: &str, member_ids: &[String], reason: Option<&str>) -> Result<()>;
    async fn get_groups_info(&self, group_ids: &[String]) -> std::result::Result<Vec<GroupInfo>, SdkError>;
    async fn set_group_info(&self, group_id: &str, group_name: Option<&str>, face_url: Option<&str>,) -> Result<()>;
    async fn get_group_members_info(&self, group_id: &str, user_ids: &[String]) -> Result<Vec<GroupMember>>;
    async fn dismiss_group(&self, group_id: &str) -> Result<()>;
    async fn get_group_application_list(&self) -> std::result::Result<Vec<GroupApplyInfo>, SdkError>;
    async fn get_group_application_list_as_recipient(&self) -> std::result::Result<Vec<GroupApplyInfo>, SdkError>;
    async fn get_group_application_list_as_applicant(&self) -> std::result::Result<Vec<GroupApplyInfo>, SdkError>;
    async fn get_group_application_unhandled_count(&self) -> Result<i32>;
    async fn accept_group_application(&self, group_id: &str, user_id: &str, handle_msg: Option<&str>) -> Result<()>;
    async fn refuse_group_application(&self, group_id: &str, user_id: &str, handle_msg: Option<&str>) -> Result<()>;
    async fn is_in_group(&self, group_id: &str) -> bool;
    async fn transfer_group_owner(&self, group_id: &str, new_owner_user_id: &str) -> Result<()>;
    async fn mute_group(&self, group_id: &str, is_mute: bool) -> Result<()>;
    async fn mute_group_member(&self, group_id: &str, user_id: &str, muted_seconds: i64) -> Result<()>;
    async fn sync_groups_incremental(&self) -> Result<()>;
    async fn set_group_member_info(&self, group_id: &str, user_id: &str, nickname: Option<&str>, face_url: Option<&str>, role_level: Option<i32>, ex: Option<&str>,) -> Result<()>;
    async fn get_joined_group_list_page(&self, offset: i32, count: i32) -> Result<Vec<GroupInfo>>;
    async fn search_groups(&self, keyword: &str) -> Vec<GroupInfo>;
    async fn get_group_member_owner_and_admin(&self, group_id: &str) -> Result<Vec<GroupMember>>;
    async fn get_group_member_list_by_join_time_filter(&self, group_id: &str, offset: i32, count: i32, join_time_begin: i64, join_time_end: i64, filter_user_ids: Vec<String>,) -> Result<Vec<GroupMember>>;
    async fn search_group_members(&self, group_id: &str, keyword: &str) -> Vec<GroupMember>;
    async fn get_users_in_group(&self, group_id: &str, user_ids: Vec<String>) -> Vec<String>;
    async fn check_local_group_full_sync(&self) -> bool;
    async fn check_group_member_full_sync(&self, group_id: &str) -> bool;
}
