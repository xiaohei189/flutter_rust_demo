//! MessageApi — SDK 对外 API 契约（分域特征）
//!
//! 由 OpenIMClient 实现，pi/ 层依赖组合特征 SdkApi。

use crate::client::OpenIMClient;
use crate::file::uploader::ProgressCallback;

use crate::constant::GroupType;
use crate::error::{Result, SdkError};
use crate::model::friend::FriendInfo;
use crate::model::group::{GroupInfo, GroupMember};
use crate::model::local::{LocalChatLog, LocalConversation};
use crate::model::message::MessageInfo;
use crate::client::{GetHistoryMessagesReq, GetHistoryMessagesResult, SearchMessagesReq};
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
pub trait MessageApi : Send + Sync {
    fn take_message_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<MessageEvent>, SdkError>;
    async fn send_msg(&self, mut msg: MsgStruct, source_id: &str, offline_push_info: Option<OfflinePushInfo>) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_msg_online_only(&self, mut msg: MsgStruct, source_id: &str) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_text_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_markdown_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_advanced_text_message(&self, text: &str, entities: Vec<crate::model::msg_struct::MessageEntity>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
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
    async fn send_quote_message(&self, text: &str, quote: crate::model::msg_struct::MsgStruct, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_merger_message(&self, title: &str, summary_list: Vec<String>, context_list: Vec<MsgStruct>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_card_message(&self, user_id: &str, nickname: &str, face_url: &str, ex: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_location_message(&self, description: &str, longitude: f64, latitude: f64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_face_message(&self, index: i32, data: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn forward_message(&self, mut msg_struct: MsgStruct, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_image_message_from_url(&self, source_url: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_sound_message_from_url(&self, source_url: &str, duration: i64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_video_message_from_url(&self, source_url: &str, duration: i64, snapshot_url: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_file_message_from_url(&self, source_url: &str, file_name: &str, file_size: i64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_at_text_message_with_quote(&self, text: &str, at_user_list: Vec<String>, at_users_info: Vec<crate::model::msg_struct::AtInfo>, quote_msg: Option<Box<MsgStruct>>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>;
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
    async fn send_advanced_quote_message(&self, text: &str, quote: crate::model::msg_struct::MsgStruct, message_entities: Vec<crate::model::msg_struct::MessageEntity>, source_id: &str, session_type: i32,) -> std::result::Result<MsgStruct, SdkError>;
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
// 消息发送传输层抽象（依赖倒置，便于测试）
// ============================================================================

/// 消息发送传输层 trait：抽象 WebSocket RPC 发送能力
///
/// 生产环境由 ConnectionManager 实现；测试中由 MockTransport 替代
#[async_trait]
impl MessageApi for OpenIMClient {
    #[tracing::instrument(skip_all)]
    async fn send_msg(&self, mut msg: MsgStruct, source_id: &str, offline_push_info: Option<OfflinePushInfo>) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_msg(msg, source_id, offline_push_info).await
    }

    /// 发送仅在线消息（isOnlineOnly）：不持久化、不同步、不更新会话
    /// 对齐 Go SDK SendMessage 的 isOnlineOnly=true 分支
    #[tracing::instrument(skip_all, fields(source_id = %source_id))]
    async fn send_msg_online_only(&self, mut msg: MsgStruct, source_id: &str) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_msg_online_only(msg, source_id).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_text_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_text_message(text);
        msg.session_type = session_type;
        self.sender.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_markdown_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_markdown_message(text);
        msg.session_type = session_type;
        self.sender.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_advanced_text_message(&self, text: &str, entities: Vec<crate::model::msg_struct::MessageEntity>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_advanced_text_message(text, entities);
        msg.session_type = session_type;
        self.sender.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_image_message(&self, file_path: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_image_message(file_path, source_id, session_type).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_image_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, progress: &ProgressCallback) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_image_message_with_progress(file_path, source_id, session_type, progress).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_file_message(&self, file_path: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_file_message(file_path, source_id, session_type).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_file_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, progress: &ProgressCallback) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_file_message_with_progress(file_path, source_id, session_type, progress).await
    }

    /// 发送语音消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_sound_message(&self, file_path: &str, source_id: &str, session_type: i32, duration: i64) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_sound_message(file_path, source_id, session_type, duration).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_sound_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, duration: i64, progress: &ProgressCallback) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_sound_message_with_progress(file_path, source_id, session_type, duration, progress).await
    }

    /// 发送视频消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_video_message(&self, video_path: &str, snapshot_path: &str, source_id: &str, session_type: i32, duration: i64) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_video_message(video_path, snapshot_path, source_id, session_type, duration).await
    }

    /// 发送视频消息（带上传进度回调，进度跟踪主视频文件）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_video_message_with_progress(&self, video_path: &str, snapshot_path: &str, source_id: &str, session_type: i32, duration: i64, progress: &ProgressCallback) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_video_message_with_progress(video_path, snapshot_path, source_id, session_type, duration, progress).await
    }

    /// 发送 @ 消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_at_text_message(&self, text: &str, at_user_ids: Vec<String>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let at_users_info: Vec<crate::model::msg_struct::AtInfo> = at_user_ids.iter().map(|uid| {
            crate::model::msg_struct::AtInfo {
                at_user_id: uid.clone(),
                group_nickname: String::new(),
            }
        }).collect();
        let mut msg = MsgStruct::create_at_text_message(text, at_user_ids, at_users_info, None);
        msg.session_type = session_type;
        self.sender.send_msg(msg, source_id, None).await
    }

    /// 发送自定义消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_custom_message(&self, data: &str, desc: &str, extension: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_custom_message(data, desc, extension);
        msg.session_type = session_type;
        self.sender.send_msg(msg, source_id, None).await
    }

    /// 发送引用消息（对齐 Go SDK `CreateQuoteMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_quote_message(&self, text: &str, quote: crate::model::msg_struct::MsgStruct, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_quote_message(text, Box::new(quote));
        msg.session_type = session_type;
        self.sender.send_msg(msg, source_id, None).await
    }

    /// 发送合并转发消息（对齐 Go SDK `CreateMergerMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_merger_message(&self, title: &str, summary_list: Vec<String>, context_list: Vec<MsgStruct>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_merger_message(context_list, title, summary_list);
        msg.session_type = session_type;
        self.sender.send_msg(msg, source_id, None).await
    }

    /// 发送名片消息（对齐 Go SDK `CreateCardMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_card_message(&self, user_id: &str, nickname: &str, face_url: &str, ex: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let elem = crate::model::msg_struct::CardElem {
            user_id: user_id.to_string(),
            nickname: nickname.to_string(),
            face_url: face_url.to_string(),
            ex: ex.to_string(),
        };
        let mut msg = MsgStruct::create_card_message(elem);
        msg.session_type = session_type;
        self.sender.send_msg(msg, source_id, None).await
    }

    /// 发送位置消息（对齐 Go SDK `CreateLocationMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_location_message(&self, description: &str, longitude: f64, latitude: f64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_location_message(description, longitude, latitude);
        msg.session_type = session_type;
        self.sender.send_msg(msg, source_id, None).await
    }

    /// 发送表情消息（对齐 Go SDK `CreateFaceMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_face_message(&self, index: i32, data: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_face_message(index, data);
        msg.session_type = session_type;
        self.sender.send_msg(msg, source_id, None).await
    }

    /// 转发消息（对齐 Go SDK `ForwardMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn forward_message(&self, mut msg_struct: MsgStruct, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        msg_struct.session_type = session_type;
        self.sender.send_msg(msg_struct, source_id, None).await
    }

    /// 从 URL 创建图片消息（对齐 Go SDK `CreateImageMessage(sourcePath="")`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_image_message_from_url(&self, source_url: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_image_message_from_url(source_url, source_id, session_type).await
    }

    /// 从 URL 创建语音消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_sound_message_from_url(&self, source_url: &str, duration: i64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_sound_message_from_url(source_url, duration, source_id, session_type).await
    }

    /// 从 URL 创建视频消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_video_message_from_url(&self, source_url: &str, duration: i64, snapshot_url: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_video_message_from_url(source_url, duration, snapshot_url, source_id, session_type).await
    }

    /// 从 URL 创建文件消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_file_message_from_url(&self, source_url: &str, file_name: &str, file_size: i64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.send_file_message_from_url(source_url, file_name, file_size, source_id, session_type).await
    }

    /// 发送分段 @ 消息（对齐 Go SDK `CreateAtTextMessage` 带 quote_msg）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_at_text_message_with_quote(&self, text: &str, at_user_list: Vec<String>, at_users_info: Vec<crate::model::msg_struct::AtInfo>, quote_msg: Option<Box<MsgStruct>>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_at_text_message(text, at_user_list, at_users_info, quote_msg);
        msg.session_type = session_type;
        self.sender.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %req.conversation_id, count = %req.count))]
    async fn get_history_messages(&self, req: GetHistoryMessagesReq) -> std::result::Result<GetHistoryMessagesResult, SdkError>  {
        self.message_service.get_history_messages(&req).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %req.conversation_id, seq = %req.seq))]
    async fn revoke_message(&self, req: RevokeMessageReq) -> Result<()> {
        self.message_service.revoke_message(req).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %req.conversation_id))]
    async fn delete_messages(&self, req: DeleteMessagesReq) -> Result<()> {
        self.message_service.delete_messages(req).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %req.conversation_id))]
    async fn mark_messages_as_read(&self, req: MarkMessagesAsReadReq) -> Result<()> {
        self.message_service.mark_messages_as_read(req).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %req.conversation_id, keyword = %req.keyword))]
    async fn search_local_messages(&self, req: SearchMessagesReq) -> std::result::Result<Vec<LocalChatLog>, SdkError> {
        self.message_service.search_local_messages(
            req.conversation_id,
            req.keyword,
            100,
        ).await
    }

    /// 发送正在输入通知（对齐 Go SDK `TypingStatusUpdate` / `ChangeInputStates`）
    ///
    /// Typing 消息不入库、不更新会话、不计未读、不触发离线推送。
    /// 通过 WS RPC 直接发送，设置 options 全部为 false。
    #[tracing::instrument(skip_all)]
    async fn send_typing(&self, source_id: &str, session_type: i32, focus: bool) -> std::result::Result<UserSendMsgResp, SdkError>  {
        self.sender.send_typing(source_id, session_type, focus).await
    }

    // ========== 第一批测试所需的查询/删除方法 ==========

    /// 倒序获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageListReverse`）
    ///
    /// 从 start_client_msg_id 之前的消息开始，倒序获取 count 条。
    /// start_client_msg_id 为空时从最新消息开始。
    async fn get_history_messages_reverse(
        &self,
        conversation_id: &str,
        start_client_msg_id: &str,
        count: i64,
    ) -> std::result::Result<GetHistoryMessagesResult, SdkError>  {
        self.message_service.get_history_messages_reverse(conversation_id, start_client_msg_id, count).await
    }

    /// 按 seq 范围获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageList` 中的 seq 范围查询）
    async fn get_advanced_history_message_list_by_seq(
        &self,
        conversation_id: &str,
        start_seq: i64,
        end_seq: i64,
        count: i32,
    ) -> std::result::Result<Vec<LocalChatLog>, SdkError>  {
        self.message_service.get_advanced_history_message_list_by_seq(conversation_id, start_seq, end_seq, count).await
    }

    /// 按 seq 获取单条消息（对齐 Go SDK `GetMessageBySeq`）
    async fn get_history_message_by_seq(
        &self,
        seq: i64,
    ) -> std::result::Result<LocalChatLog, SdkError>  {
        self.message_service.get_history_message_by_seq(seq).await
    }

    /// 按 clientMsgId 列表批量查找消息（对齐 Go SDK `FindMessageList`）
    async fn find_message_list(
        &self,
        conversation_id: &str,
        client_msg_ids: Vec<String>,
    ) -> std::result::Result<Vec<LocalChatLog>, SdkError>  {
        self.message_service.find_message_list(conversation_id, client_msg_ids).await
    }

    /// 仅从本地删除单条消息（对齐 Go SDK `DeleteMessageFromLocalStorage`）
    ///
    /// 软删除：将消息状态标记为 MsgStatusHasDeleted(4)，不通知服务端。
    async fn delete_message_from_local_storage(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
    ) -> std::result::Result<(), SdkError>  {
        self.message_service.delete_message_from_local_storage(conversation_id, client_msg_id).await
    }

    /// 清空会话并删除所有消息（对齐 Go SDK `ClearConversationAndDeleteAllMsg`）
    ///
    /// 删除服务端+本地该会话的所有消息，会话本身保留。
    async fn clear_conversation_and_delete_all_msg(
        &self,
        conversation_id: &str,
    ) -> std::result::Result<(), SdkError>  {
        self.message_service.clear_conversation_and_delete_all_msg(conversation_id).await
    }

    /// 删除会话并删除所有消息（对齐 Go SDK `DeleteConversationAndDeleteAllMsg`）
    ///
    /// 删除服务端+本地该会话的所有消息，并删除会话本身。
    async fn delete_conversation_and_delete_all_msg(
        &self,
        conversation_id: &str,
    ) -> std::result::Result<(), SdkError>  {
        self.message_service.delete_conversation_and_delete_all_msg(conversation_id).await
    }

    /// 删除所有消息（本地+服务端）（对齐 Go SDK `DeleteAllMsgFromLocalAndSvr`）
    async fn delete_all_msg_from_local_and_svr(
        &self,
    ) -> std::result::Result<(), SdkError>  {
        self.message_service.delete_all_msg_from_local_and_svr().await
    }

    /// 仅从本地删除所有消息（对齐 Go SDK `DeleteAllMsgFromLocal`）
    async fn delete_all_msg_from_local(
        &self,
    ) -> std::result::Result<(), SdkError>  {
        self.message_service.delete_all_msg_from_local().await
    }

    /// 获取所有会话的总未读消息数（对齐 Go SDK `GetTotalUnreadMsgCount`）
    async fn get_total_unread_msg_count(
        &self,
    ) -> std::result::Result<i64, SdkError>  {
        self.message_service.get_total_unread_msg_count().await
    }

    /// 设置消息本地扩展字段（对齐 Go SDK `SetMessageLocalEx`）
    async fn set_message_local_ex(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
        local_ex: &str,
    ) -> std::result::Result<(), SdkError>  {
        self.message_service.set_message_local_ex(conversation_id, client_msg_id, local_ex).await
    }

    /// 登录时清理发送中的消息（对齐 Go SDK userRelated.go L332-375）
    async fn cleanup_sending_messages(&self)  {
        self.message_service.cleanup_sending_messages().await
    }

    /// 发送高级引用消息（对齐 Go SDK `CreateAdvancedQuoteMessage` + `SendMessage`）
    ///
    /// 与 `send_quote_message` 的区别：额外支持 `message_entities` 参数，
    /// 可以为引用消息的文本添加实体（如 @提及、链接等富文本）。
    async fn send_advanced_quote_message(
        &self,
        text: &str,
        quote: crate::model::msg_struct::MsgStruct,
        message_entities: Vec<crate::model::msg_struct::MessageEntity>,
        source_id: &str,
        session_type: i32,
    ) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_advanced_quote_message(
            text,
            Box::new(quote),
            message_entities,
        );
        msg.session_type = session_type;
        self.sender.send_msg(msg, source_id, None).await
    }

    /// 编辑消息（对齐 Go SDK 消息修改功能）
    ///
    /// 当前实现：构造一条新的文本消息发送，服务端通过 MsgDataToModifyByMQ 广播修改通知。
    /// 后续可对接服务端 HTTP 编辑 API（EditMsg）实现原子编辑。
    ///
    /// - `conversation_id`: 消息所属会话 ID
    /// - `client_msg_id`: 要编辑的消息的 clientMsgId
    /// - `content`: 编辑后的新内容（JSON 字符串）
    /// - `content_type`: 消息内容类型（如 101=文本）
    async fn edit_message(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
        content: &str,
        content_type: i32,
    ) -> std::result::Result<MsgStruct, SdkError>  {
        self.sender.edit_message(conversation_id, client_msg_id, content, content_type).await
    }

    fn take_message_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<MessageEvent>, SdkError> {
        self.listeners.take_message_rx().ok_or_else(|| SdkError::unknown("message receiver already taken"))
    }
    async fn get_message_by_client_msg_id(&self, client_msg_id: &str) -> std::result::Result<Option<LocalChatLog>, SdkError>  {
        self.message_service.get_message_by_client_msg_id(client_msg_id).await
    }

    async fn insert_group_message_to_local_storage(&self, group_id: &str, content: &str, content_type: i32, send_id: &str) -> std::result::Result<LocalChatLog, SdkError>  {
        self.message_service.insert_group_message_to_local_storage(group_id, content, content_type, send_id).await
    }

    async fn upload_file(&self, file_path: &str, file_name: &str) -> std::result::Result<String, SdkError>  {
        self.sender.upload_file(file_path, file_name).await
    }

    async fn upload_file_with_progress(&self, file_path: &str, file_name: &str, progress: &Arc<dyn Fn(u8) + Send + Sync>) -> std::result::Result<String, SdkError>  {
        self.sender.upload_file_with_progress(file_path, file_name, progress).await
    }}

// ============================================================================
// 测试
// ============================================================================



mod tests {
    use crate::constant::MessageSendStatus;
    use crate::client::context::RuntimeContext;
    use crate::file::uploader::FileUploader;
    use openim_protocol::sdkws::MsgData;
    use super::*;
    use crate::message::send::sender::{
        conversation_id_for_msg, content_type_name, do_send_message_impl, insert_message_before_send_impl, MessageSendTransport,
    };
    use crate::model::msg_struct::MsgStruct;

    // ========================================================================
    // conversation_id_for_msg 测试
    // ========================================================================

    /// 验证单聊消息的 conversation_id 生成规则：si_{sorted_user_ids}
    ///
    /// 单聊 ID 格式：si_{小user_id}_{大user_id}（按字典序排列）
    #[test]
    fn test_conversation_id_single_chat_sorted() {
        let mut msg = MsgStruct::default();
        msg.session_type = 1; // 单聊
        msg.send_id = "user_b".to_string();
        msg.recv_id = "user_a".to_string();

        // send_id > recv_id，应排序为 si_user_a_user_b
        let conv_id = conversation_id_for_msg(&msg);
        assert_eq!(conv_id, "si_user_a_user_b", "单聊 ID 应按字典序排列");
    }

    /// 验证单聊消息 send_id < recv_id 时的 conversation_id
    #[test]
    fn test_conversation_id_single_chat_already_sorted() {
        let mut msg = MsgStruct::default();
        msg.session_type = 1;
        msg.send_id = "alice".to_string();
        msg.recv_id = "bob".to_string();

        let conv_id = conversation_id_for_msg(&msg);
        assert_eq!(conv_id, "si_alice_bob", "已排序时不应改变顺序");
    }

    /// 验证群聊消息（session_type=3）的 conversation_id 生成规则：sg_{group_id}
    #[test]
    fn test_conversation_id_group_chat_read_type() {
        let mut msg = MsgStruct::default();
        msg.session_type = 3; // ReadGroupChat
        msg.group_id = "group_123".to_string();

        let conv_id = conversation_id_for_msg(&msg);
        assert_eq!(conv_id, "sg_group_123", "ReadGroupChat 应使用 sg_ 前缀");
    }

    /// 验证群聊消息（session_type=2）的 conversation_id 生成规则：g_{group_id}
    ///
    /// 注：session_type=2 (WriteGroupChat) 已被服务端废弃，但 ID 生成逻辑保留
    #[test]
    fn test_conversation_id_group_chat_write_type() {
        let mut msg = MsgStruct::default();
        msg.session_type = 2; // WriteGroupChat（已废弃）
        msg.group_id = "group_456".to_string();

        let conv_id = conversation_id_for_msg(&msg);
        assert_eq!(conv_id, "g_group_456", "WriteGroupChat 应使用 g_ 前缀");
    }

    /// 验证未知 session_type 回退到 g_{group_id} 格式
    #[test]
    fn test_conversation_id_unknown_session_type_fallback() {
        let mut msg = MsgStruct::default();
        msg.session_type = 99; // 未知类型
        msg.group_id = "group_789".to_string();

        let conv_id = conversation_id_for_msg(&msg);
        assert_eq!(conv_id, "g_group_789", "未知类型应回退到 g_ 前缀");
    }

    // ========================================================================
    // content_type_name 测试
    // ========================================================================

    /// 验证常见消息类型的中文名称映射
    #[test]
    fn test_content_type_name_common_types() {
        // 文本消息
        assert_eq!(content_type_name(101), "文本");
        // 图片消息
        assert_eq!(content_type_name(102), "图片");
        // 语音消息
        assert_eq!(content_type_name(103), "语音");
        // 视频消息
        assert_eq!(content_type_name(104), "视频");
        // 文件消息
        assert_eq!(content_type_name(105), "文件");
    }

    /// 验证未知消息类型返回默认名称
    #[test]
    fn test_content_type_name_unknown_type() {
        let name = content_type_name(9999);
        // 未知类型返回 "未知"
        assert_eq!(name, "未知", "未知类型应返回 '未知'");
    }

    // ========================================================================
    // do_send_message_impl 测试（依赖倒置 + MockTransport）
    // ========================================================================

    use crate::db::pool::create_pool_memory;
    use crate::db::{ConversationDao, MessageDao, SendingMessageDao};
    use crate::db::{FriendDao, GroupDao, NotificationSeqDao, SyncVersionDao, UserDao};
    use crate::http::client::HttpApiClient;
        use crate::client::config::ClientConfig;
    use tokio_util::sync::CancellationToken;
    use std::sync::atomic::{AtomicUsize, Ordering};

    /// Mock 传输层：模拟 WebSocket RPC 发送
    ///
    /// 支持三种模式：成功、失败、超时
    struct MockTransport {
        /// 预设响应模式
        mode: MockMode,
        /// 记录调用次数
        call_count: AtomicUsize,
    }

    #[derive(Clone)]
    enum MockMode {
        /// 返回成功响应
        Success(UserSendMsgResp),
        /// 返回普通错误
        Fail(String),
        /// 返回超时错误
        Timeout,
    }

    impl MockTransport {
        fn success(server_msg_id: &str) -> Self {
            Self {
                mode: MockMode::Success(UserSendMsgResp {
                    server_msg_id: server_msg_id.to_string(),
                    client_msg_id: String::new(),
                    send_time: 1000,
                }),
                call_count: AtomicUsize::new(0),
            }
        }

        fn fail(err_msg: &str) -> Self {
            Self {
                mode: MockMode::Fail(err_msg.to_string()),
                call_count: AtomicUsize::new(0),
            }
        }

        fn timeout() -> Self {
            Self {
                mode: MockMode::Timeout,
                call_count: AtomicUsize::new(0),
            }
        }
    }

    #[async_trait]
    impl MessageSendTransport for MockTransport {
        async fn send_msg_rpc(&self, msg_data: &MsgData) -> std::result::Result<UserSendMsgResp, SdkError> {
            self.call_count.fetch_add(1, Ordering::SeqCst);
            match &self.mode {
                MockMode::Success(resp) => Ok(UserSendMsgResp {
                    server_msg_id: resp.server_msg_id.clone(),
                    client_msg_id: msg_data.client_msg_id.clone(),
                    send_time: resp.send_time,
                }),
                MockMode::Fail(msg) => Err(SdkError::message_send(msg.clone())),
                MockMode::Timeout => Err(SdkError::timeout("ws rpc timeout")),
            }
        }
    }

    /// 创建测试用 RuntimeContext（内存数据库）
    async fn make_test_context() -> Arc<RuntimeContext> {
        let pool = create_pool_memory().await.unwrap();
        let listeners = crate::event::hub::EventHub::new();
        let http_client = Arc::new(HttpApiClient::new(
            "http://localhost:19999".to_string(),
            "test_token".to_string(),
            "test_op".to_string(),
        ));

        Arc::new(RuntimeContext {
            config: ClientConfig {
                user_id: "test_user".to_string(),
                token: "test_token".to_string(),
                platform_id: 1,
                ws_url: None,
                api_base_url: "http://localhost:19999".to_string(),
                upload_url: None,
                data_dir: std::env::temp_dir().to_string_lossy().to_string(),
            },
            listeners,
            cancel_token: CancellationToken::new(),
            user_id: crate::model::UserId::new("test_user"),
            operation_id: "test_op".to_string(),
            repositories: Arc::new(crate::client::context::Repositories {
                message_repo: Arc::new(MessageDao::new(pool.clone())),
                conversation_repo: Arc::new(ConversationDao::new(pool.clone())),
                friend_repo: Arc::new(FriendDao::new(pool.clone())),
                user_repo: Arc::new(UserDao::new(pool.clone())),
                group_repo: Arc::new(GroupDao::new(pool.clone())),
                sync_version_repo: Arc::new(SyncVersionDao::new(pool.clone())),
                notification_seq_repo: Arc::new(NotificationSeqDao::new(pool.clone())),
                sending_message_repo: Arc::new(SendingMessageDao::new(pool.clone())),
            }),
            infra: crate::client::context::Infra {
                http_client,
                db_pool: pool.clone(),
            },
        })
    }

    /// 创建测试用 FileUploader（文本消息不会触发实际上传）
    fn make_test_uploader() -> Arc<FileUploader> {
        let http_client = Arc::new(HttpApiClient::new(
            "http://localhost:19999".to_string(),
            "test_token".to_string(),
            "test_op".to_string(),
        ));
        Arc::new(FileUploader::new(http_client))
    }

    /// 构造测试用文本消息
    fn make_test_msg(client_msg_id: &str) -> MsgStruct {
        let mut msg = MsgStruct::default();
        msg.client_msg_id = client_msg_id.to_string();
        msg.session_type = 1; // 单聊
        msg.send_id = "user_a".to_string();
        msg.recv_id = "user_b".to_string();
        msg.content_type = 101; // 文本消息
        msg.content = "{\"content\":\"hello\"}".to_string();
        msg.status = 1; // Sending
        msg
    }

    /// 测试：发送成功 → DB 状态更新为 SendSuccess + server_msg_id 回填
    ///
    /// 验证核心流程：消息入库 → 发送 → 更新状态 → 清理 sending_messages
    #[tokio::test]
    async fn test_send_message_success_updates_db() {
        let context = make_test_context().await;
        let transport = Arc::new(MockTransport::success("server_msg_001"));
        let uploader = make_test_uploader();
        let msg = make_test_msg("client_msg_success");

        let result = do_send_message_impl(
            context.clone(),
            transport.clone(),
            uploader,
            msg,
            None,
            false,
        ).await;

        // 发送应成功
        assert!(result.is_ok(), "发送应成功: {:?}", result.err());
        let resp = result.unwrap();
        assert_eq!(resp.server_msg_id, "server_msg_001");

        // DB 中消息状态应为 SendSuccess(2)
        let db_msg = context.repositories.message_repo
            .get_by_client_msg_id("si_user_a_user_b", "client_msg_success")
            .await.unwrap().unwrap();
        assert_eq!(db_msg.status, MessageSendStatus::SendSuccess as i32, "DB 状态应为 SendSuccess");
        assert_eq!(db_msg.server_msg_id, "server_msg_001", "server_msg_id 应回填");

        // sending_messages 应被清理
        let sending = context.repositories.sending_message_repo
            .get_by_client_msg_id("si_user_a_user_b", "client_msg_success")
            .await.unwrap();
        assert!(sending.is_none(), "发送成功后 sending_message 应被删除");
    }

    /// 测试：发送失败 → DB 标记 SendFailed + 发布 MessageSendFailed 事件
    ///
    /// 验证错误路径：消息入库 → 发送失败 → 更新状态为失败 → 发布事件
    #[tokio::test]
    async fn test_send_message_failure_marks_send_failed() {
        let context = make_test_context().await;
        let transport = Arc::new(MockTransport::fail("network error"));
        let uploader = make_test_uploader();
        let msg = make_test_msg("client_msg_fail");

        let result = do_send_message_impl(
            context.clone(),
            transport,
            uploader,
            msg,
            None,
            false,
        ).await;

        // 应返回错误
        assert!(result.is_err(), "发送应失败");

        // DB 中消息状态应为 SendFailed(3)
        let db_msg = context.repositories.message_repo
            .get_by_client_msg_id("si_user_a_user_b", "client_msg_fail")
            .await.unwrap().unwrap();
        assert_eq!(db_msg.status, MessageSendStatus::SendFailed as i32, "DB 状态应为 SendFailed");


    }

    /// 测试：超时但 DB 已标记成功 → 返回 Ok（二次确认逻辑）
    ///
    /// 场景：网络超时但服务端实际已成功处理，DB 通过其他设备同步已标记成功
    /// 对齐 Go SDK api.go L682-698 的超时二次确认逻辑
    #[tokio::test]
    async fn test_send_message_timeout_db_already_success() {
        let context = make_test_context().await;
        let transport = Arc::new(MockTransport::timeout());
        let uploader = make_test_uploader();
        let msg = make_test_msg("client_msg_timeout");

        // 先手动插入一条已成功的消息（模拟其他设备同步写入）
        let mut local_log = LocalChatLog::from(&msg);
        local_log.conversation_id = "si_user_a_user_b".to_string();
        local_log.status = MessageSendStatus::SendSuccess as i32;
        local_log.server_msg_id = "server_already_done".to_string();
        local_log.send_time = 999;
        context.repositories.message_repo.batch_insert(&[local_log]).await.unwrap();

        let result = do_send_message_impl(
            context.clone(),
            transport,
            uploader,
            msg,
            None,
            false,
        ).await;

        // 超时时 DB 已成功 → 应返回 Ok
        assert!(result.is_ok(), "超时但 DB 已成功应返回 Ok: {:?}", result.err());
        let resp = result.unwrap();
        assert_eq!(resp.server_msg_id, "server_already_done", "应返回 DB 中的 server_msg_id");
    }

    /// 测试：超时且 DB 未成功 → 标记 SendFailed
    ///
    /// 场景：真正的发送失败（超时且服务端未处理）
    #[tokio::test]
    async fn test_send_message_timeout_db_not_success() {
        let context = make_test_context().await;
        let transport = Arc::new(MockTransport::timeout());
        let uploader = make_test_uploader();
        let msg = make_test_msg("client_msg_real_timeout");

        let result = do_send_message_impl(
            context.clone(),
            transport,
            uploader,
            msg,
            None,
            false,
        ).await;

        // 应返回错误
        assert!(result.is_err(), "超时且 DB 未成功应返回 Err");

        // DB 状态应为 SendFailed
        let db_msg = context.repositories.message_repo
            .get_by_client_msg_id("si_user_a_user_b", "client_msg_real_timeout")
            .await.unwrap().unwrap();
        assert_eq!(db_msg.status, MessageSendStatus::SendFailed as i32);
    }

    /// 测试：online_only 模式 → 跳过本地持久化
    ///
    /// 验证 isOnlineOnly 消息不写入 DB、不更新会话、不同步
    /// 对齐 Go SDK api.go L154-157, L657-664
    #[tokio::test]
    async fn test_send_message_online_only_skips_persistence() {
        let context = make_test_context().await;
        let transport = Arc::new(MockTransport::success("server_online"));
        let uploader = make_test_uploader();
        let msg = make_test_msg("client_msg_online");

        let result = do_send_message_impl(
            context.clone(),
            transport.clone(),
            uploader,
            msg,
            None,
            true, // online_only = true
        ).await;

        // 发送应成功
        assert!(result.is_ok(), "online_only 发送应成功");

        // DB 中不应有消息记录（跳过持久化）
        let db_msg = context.repositories.message_repo
            .get_by_client_msg_id("si_user_a_user_b", "client_msg_online")
            .await.unwrap();
        assert!(db_msg.is_none(), "online_only 不应写入 DB");

        // transport 应被调用一次
        assert_eq!(transport.call_count.load(Ordering::SeqCst), 1);
    }

    /// 测试：online_only 模式发送失败 → 不更新 DB 状态
    ///
    /// online_only 消息未入库，失败时无需更新 DB
    #[tokio::test]
    async fn test_send_message_online_only_failure_no_db_update() {
        let context = make_test_context().await;
        let transport = Arc::new(MockTransport::fail("connection lost"));
        let uploader = make_test_uploader();
        let msg = make_test_msg("client_msg_online_fail");

        let result = do_send_message_impl(
            context.clone(),
            transport,
            uploader,
            msg,
            None,
            true, // online_only
        ).await;

        // 应返回错误
        assert!(result.is_err());

        // DB 中不应有任何记录
        let db_msg = context.repositories.message_repo
            .get_by_client_msg_id("si_user_a_user_b", "client_msg_online_fail")
            .await.unwrap();
        assert!(db_msg.is_none(), "online_only 失败不应有 DB 记录");
    }

    // ========================================================================
    // insert_message_before_send_impl 测试
    // ========================================================================

    /// 测试：发送前消息入库 → 状态为 Sending + sending_message 记录 + 会话更新
    ///
    /// 验证 insert_message_before_send_impl 的完整写入链路
    #[tokio::test]
    async fn test_insert_message_before_send_creates_records() {
        let context = make_test_context().await;
        let msg = make_test_msg("client_msg_insert");
        let send_time = 1700000000000i64;

        // 先创建会话（update_after_sent_message 需要已存在的会话）
        let conv = crate::model::local::LocalConversation {
            conversation_id: "si_user_a_user_b".to_string(),
            conversation_type: 1,
            user_id: "user_a".to_string(),
            group_id: String::new(),
            show_name: String::new(),
            face_url: String::new(),
            recv_msg_opt: 0,
            unread_count: 0,
            latest_msg: String::new(),
            latest_msg_send_time: 0,
            is_pinned: false,
            is_private_chat: false,
            burn_duration: 0,
            group_at_type: 0,
            is_not_in_group: false,
            update_unread_count_time: 0,
            attached_info: String::new(),
            ex: String::new(),
            draft_text: String::new(),
            draft_text_time: 0,
            max_seq: 0,
            min_seq: 0,
            is_msg_destruct: false,
            msg_destruct_time: 0,
        };
        context.repositories.conversation_repo.upsert(&conv).await.unwrap();

        let result = insert_message_before_send_impl(&context, &msg, send_time).await;
        assert!(result.is_ok(), "入库应成功: {:?}", result.err());

        // 验证 local_chat_logs 写入
        let db_msg = context.repositories.message_repo
            .get_by_client_msg_id("si_user_a_user_b", "client_msg_insert")
            .await.unwrap().unwrap();
        assert_eq!(db_msg.status, MessageSendStatus::Sending as i32, "状态应为 Sending");
        assert_eq!(db_msg.send_time, send_time, "send_time 应正确");

        // 验证 sending_messages 写入
        let sending = context.repositories.sending_message_repo
            .get_by_client_msg_id("si_user_a_user_b", "client_msg_insert")
            .await.unwrap();
        assert!(sending.is_some(), "sending_message 应存在");
    }
}


