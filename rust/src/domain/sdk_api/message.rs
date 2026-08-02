//! MessageApi — SDK 对外 API 契约（分域特征）
//!
//! 由 OpenIMClient 实现，pi/ 层依赖组合特征 SdkApi。

use crate::domain::constant::GroupType;
use crate::domain::error::{Result, SdkError};
use crate::domain::model::friend::FriendInfo;
use crate::domain::model::group::{GroupInfo, GroupMember};
use crate::domain::model::local::{LocalChatLog, LocalConversation};
use crate::domain::model::message::MessageInfo;
use crate::domain::sdk_api::{GetHistoryMessagesReq, GetHistoryMessagesResult, SearchMessagesReq};
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
pub trait MessageApi : Send + Sync {
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
