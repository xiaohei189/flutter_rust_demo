//! SDK 对外 API 契约（特征）
//!
//! 领域层定义 SDK 的公开 API 特征与契约类型；`OpenIMClient` 实现各分域特征，
//! `api/`（FFI 桥接层）与外部调用方都依赖 `SdkApi`，而非具体实现结构体。
//!
//! 分层说明：本模块是 SDK 对外（Dart / 外部集成）的出向契约，与 `domain/ports`（SDK 依赖外部服务的入向契约）方向相反。

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

// ============================================================================
// SDK 对外契约类型
// ============================================================================

/// 历史消息分页查询参数
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetHistoryMessagesReq {
    pub conversation_id: String,
    pub start_client_msg_id: String,
    pub count: i64,
}

/// 历史消息分页结果
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetHistoryMessagesResult {
    pub messages: Vec<MessageInfo>,
    pub is_end: bool,
}

/// 本地消息搜索参数
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SearchMessagesReq {
    pub conversation_id: String,
    pub keyword: String,
}

// ============================================================================
// ConnectionApi
// ============================================================================

#[async_trait]
pub trait ConnectionApi: Send + Sync {
    fn take_conn_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<ConnectionEvent>, SdkError>;
    async fn connect(&self, ws_url: &str, token: &str, user_id: &str) -> Result<()>;
    async fn disconnect(&self);
    async fn login(&self, user_id: &str, token: &str) -> Result<()>;
    async fn logout(&self) -> Result<()>;
    fn login_user_id(&self) -> String;
    async fn get_connection_state(&self) -> crate::core::connection::manager::ConnectionState;
    async fn is_connected(&self) -> bool;
}

// ============================================================================
// ConversationApi
// ============================================================================

#[async_trait]
pub trait ConversationApi: Send + Sync {
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

// ============================================================================
// FriendApi
// ============================================================================

#[async_trait]
pub trait FriendApi: Send + Sync {
    fn take_friend_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<FriendEvent>, SdkError>;
    async fn get_friend_list(&self) -> Vec<FriendInfo>;
    async fn sync_friends(&self) -> Result<()>;
    async fn add_friend(&self, user_id: &str, req_msg: Option<&str>) -> Result<()>;
    async fn delete_friend(&self, user_id: &str) -> Result<()>;
    async fn get_black_list(&self) -> Vec<String>;
    async fn is_friend(&self, user_id: &str) -> bool;
    async fn check_friend(&self, user_ids: Vec<String>) -> std::result::Result<Vec<crate::domain::ports::friend::CheckFriendResult>, SdkError>;
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

// ============================================================================
// GroupApi
// ============================================================================

#[async_trait]
pub trait GroupApi: Send + Sync {
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

// ============================================================================
// MessageApi
// ============================================================================

#[async_trait]
pub trait MessageApi: Send + Sync {
    fn take_message_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<MessageEvent>, SdkError>;
    async fn send_msg(&self, mut msg: MsgStruct, source_id: &str, offline_push_info: Option<OfflinePushInfo>) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_msg_online_only(&self, mut msg: MsgStruct, source_id: &str) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_text_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_markdown_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_advanced_text_message(&self, text: &str, entities: Vec<crate::domain::model::msg_struct::MessageEntity>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_image_message(&self, file_path: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_image_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, progress: &Arc<dyn Fn(u8) + Send + Sync>) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_file_message(&self, file_path: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_file_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, progress: &Arc<dyn Fn(u8) + Send + Sync>) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_sound_message(&self, file_path: &str, source_id: &str, session_type: i32, duration: i64) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_sound_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, duration: i64, progress: &Arc<dyn Fn(u8) + Send + Sync>) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_video_message(&self, video_path: &str, snapshot_path: &str, source_id: &str, session_type: i32, duration: i64) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_video_message_with_progress(&self, video_path: &str, snapshot_path: &str, source_id: &str, session_type: i32, duration: i64, progress: &Arc<dyn Fn(u8) + Send + Sync>) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_at_text_message(&self, text: &str, at_user_ids: Vec<String>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_custom_message(&self, data: &str, desc: &str, extension: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_quote_message(&self, text: &str, quote: crate::domain::model::msg_struct::MsgStruct, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_merger_message(&self, title: &str, summary_list: Vec<String>, context_list: Vec<MsgStruct>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_card_message(&self, user_id: &str, nickname: &str, face_url: &str, ex: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_location_message(&self, description: &str, longitude: f64, latitude: f64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_face_message(&self, index: i32, data: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn forward_message(&self, mut msg_struct: MsgStruct, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_image_message_from_url(&self, source_url: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_sound_message_from_url(&self, source_url: &str, duration: i64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_video_message_from_url(&self, source_url: &str, duration: i64, snapshot_url: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_file_message_from_url(&self, source_url: &str, file_name: &str, file_size: i64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_at_text_message_with_quote(&self, text: &str, at_user_list: Vec<String>, at_users_info: Vec<crate::domain::model::msg_struct::AtInfo>, quote_msg: Option<Box<MsgStruct>>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn get_history_messages(&self, req: GetHistoryMessagesReq) -> std::result::Result<GetHistoryMessagesResult, SdkError>;
    async fn revoke_message(&self, req: RevokeMessageReq) -> Result<()>;
    async fn delete_messages(&self, req: DeleteMessagesReq) -> Result<()>;
    async fn mark_messages_as_read(&self, req: MarkMessagesAsReadReq) -> Result<()>;
    async fn search_local_messages(&self, req: SearchMessagesReq) -> std::result::Result<Vec<LocalChatLog>, SdkError>;
    async fn send_typing(&self, source_id: &str, session_type: i32, focus: bool) -> std::result::Result<UserSendMsgResp, SdkError>;
    async fn get_history_messages_reverse(&self, conversation_id: &str, start_client_msg_id: &str, count: i64,) -> std::result::Result<GetHistoryMessagesResult, SdkError>;
    async fn get_advanced_history_message_list_by_seq(&self, conversation_id: &str, start_seq: i64, end_seq: i64, count: i32,) -> std::result::Result<Vec<LocalChatLog>, SdkError>;
    async fn get_history_message_by_seq(&self, seq: i64,) -> std::result::Result<LocalChatLog, SdkError>;
    async fn find_message_list(&self, conversation_id: &str, client_msg_ids: Vec<String>,) -> std::result::Result<Vec<LocalChatLog>, SdkError>;
    async fn delete_message_from_local_storage(&self, conversation_id: &str, client_msg_id: &str,) -> std::result::Result<(), SdkError>;
    async fn clear_conversation_and_delete_all_msg(&self, conversation_id: &str,) -> std::result::Result<(), SdkError>;
    async fn delete_conversation_and_delete_all_msg(&self, conversation_id: &str,) -> std::result::Result<(), SdkError>;
    async fn delete_all_msg_from_local_and_svr(&self,) -> std::result::Result<(), SdkError>;
    async fn delete_all_msg_from_local(&self,) -> std::result::Result<(), SdkError>;
    async fn get_total_unread_msg_count(&self,) -> std::result::Result<i64, SdkError>;
    async fn set_message_local_ex(&self, conversation_id: &str, client_msg_id: &str, local_ex: &str,) -> std::result::Result<(), SdkError>;
    async fn cleanup_sending_messages(&self);
    async fn send_advanced_quote_message(&self, text: &str, quote: crate::domain::model::msg_struct::MsgStruct, message_entities: Vec<crate::domain::model::msg_struct::MessageEntity>, source_id: &str, session_type: i32,) -> std::result::Result<MsgStruct, SdkError>;
    async fn edit_message(&self, conversation_id: &str, client_msg_id: &str, content: &str, content_type: i32,) -> std::result::Result<MsgStruct, SdkError>;

    /// 按 clientMsgID 查找单条本地消息
    async fn get_message_by_client_msg_id(&self, client_msg_id: &str) -> std::result::Result<Option<LocalChatLog>, SdkError>;
    /// 插入群聊消息到本地存储
    async fn insert_group_message_to_local_storage(&self, group_id: &str, content: &str, content_type: i32, send_id: &str) -> std::result::Result<LocalChatLog, SdkError>;
    /// 上传文件，返回 URL
    async fn upload_file(&self, file_path: &str, file_name: &str) -> std::result::Result<String, SdkError>;
    /// 上传文件并回调进度，返回 URL
    async fn upload_file_with_progress(&self, file_path: &str, file_name: &str, progress: &Arc<dyn Fn(u8) + Send + Sync>) -> std::result::Result<String, SdkError>;}

// ============================================================================
// UserApi
// ============================================================================

#[async_trait]
pub trait UserApi: Send + Sync {
    fn take_user_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<UserEvent>, SdkError>;
    async fn get_user_status(&self, user_ids: &[String]) -> Result<Vec<OnlineStatus>>;
    async fn get_users_info(&self, user_ids: &[String]) -> Result<Vec<UserInfo>>;
    async fn get_self_user_info(&self) -> Result<UserInfo>;
    async fn update_user_profile(&self, nickname: Option<&str>, face_url: Option<&str>, ex: Option<&str>,) -> Result<()>;
    async fn set_global_msg_recv_opt(&self, global_recv_opt: i32) -> Result<()>;
}

// ============================================================================
// 组合特征：api / 外部调用方只需依赖这一个对象
// ============================================================================

pub trait SdkApi: ConnectionApi + ConversationApi + FriendApi + GroupApi + MessageApi + UserApi + Send + Sync {}
impl<T: ConnectionApi + ConversationApi + FriendApi + GroupApi + MessageApi + UserApi + Send + Sync> SdkApi for T {}

