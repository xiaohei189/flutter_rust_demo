//! MessageApi — SDK 对外 API 契约（分域特征）
//!
//! 由 OpenIMClient 实现，pi/ 层依赖组合特征 SdkApi。

use crate::client::OpenIMClient;
use crate::client::{GetHistoryMessagesReq, GetHistoryMessagesResult, SearchMessagesReq};
use crate::error::{Result, SdkError};
use crate::event::events::message::MessageEvent;
use crate::file::upload::ProgressCallback;
use crate::http::message::{DeleteMessagesReq, MarkMessagesAsReadReq, RevokeMessageReq};
use crate::model::local::LocalChatLog;
use crate::model::msg_struct::MsgStruct;
use async_trait::async_trait;
use openim_protocol::sdkws::{OfflinePushInfo, UserSendMsgResp};
use std::sync::Arc;

#[async_trait]
pub trait MessageApi: Send + Sync {
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
    async fn send_sound_message_with_progress(
        &self,
        file_path: &str,
        source_id: &str,
        session_type: i32,
        duration: i64,
        progress: &Arc<dyn Fn(u8) + Send + Sync>,
    ) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_video_message(&self, video_path: &str, snapshot_path: &str, source_id: &str, session_type: i32, duration: i64) -> std::result::Result<MsgStruct, SdkError>;
    async fn send_video_message_with_progress(
        &self,
        video_path: &str,
        snapshot_path: &str,
        source_id: &str,
        session_type: i32,
        duration: i64,
        progress: &Arc<dyn Fn(u8) + Send + Sync>,
    ) -> std::result::Result<MsgStruct, SdkError>;
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
    async fn send_at_text_message_with_quote(
        &self,
        text: &str,
        at_user_list: Vec<String>,
        at_users_info: Vec<crate::model::msg_struct::AtInfo>,
        quote_msg: Option<Box<MsgStruct>>,
        source_id: &str,
        session_type: i32,
    ) -> std::result::Result<MsgStruct, SdkError>;
    async fn get_history_messages(&self, req: GetHistoryMessagesReq) -> std::result::Result<GetHistoryMessagesResult, SdkError>;
    async fn revoke_message(&self, req: RevokeMessageReq) -> Result<()>;
    async fn delete_messages(&self, req: DeleteMessagesReq) -> Result<()>;
    async fn mark_messages_as_read(&self, req: MarkMessagesAsReadReq) -> Result<()>;
    async fn search_local_messages(&self, req: SearchMessagesReq) -> std::result::Result<Vec<LocalChatLog>, SdkError>;
    async fn send_typing(&self, source_id: &str, session_type: i32, focus: bool) -> std::result::Result<UserSendMsgResp, SdkError>;
    async fn get_history_messages_reverse(&self, conversation_id: &str, start_client_msg_id: &str, count: i64) -> std::result::Result<GetHistoryMessagesResult, SdkError>;
    async fn get_advanced_history_message_list_by_seq(&self, conversation_id: &str, start_seq: i64, end_seq: i64, count: i32) -> std::result::Result<Vec<LocalChatLog>, SdkError>;
    async fn get_history_message_by_seq(&self, seq: i64) -> std::result::Result<LocalChatLog, SdkError>;
    async fn find_message_list(&self, conversation_id: &str, client_msg_ids: Vec<String>) -> std::result::Result<Vec<LocalChatLog>, SdkError>;
    async fn delete_message_from_local_storage(&self, conversation_id: &str, client_msg_id: &str) -> std::result::Result<(), SdkError>;
    async fn clear_conversation_and_delete_all_msg(&self, conversation_id: &str) -> std::result::Result<(), SdkError>;
    async fn delete_conversation_and_delete_all_msg(&self, conversation_id: &str) -> std::result::Result<(), SdkError>;
    async fn delete_all_msg_from_local_and_svr(&self) -> std::result::Result<(), SdkError>;
    async fn delete_all_msg_from_local(&self) -> std::result::Result<(), SdkError>;
    async fn get_total_unread_msg_count(&self) -> std::result::Result<i64, SdkError>;
    async fn get_server_time(&self) -> std::result::Result<i64, SdkError>;
    async fn set_message_local_ex(&self, conversation_id: &str, client_msg_id: &str, local_ex: &str) -> std::result::Result<(), SdkError>;
    async fn cleanup_sending_messages(&self);
    async fn send_advanced_quote_message(
        &self,
        text: &str,
        quote: crate::model::msg_struct::MsgStruct,
        message_entities: Vec<crate::model::msg_struct::MessageEntity>,
        source_id: &str,
        session_type: i32,
    ) -> std::result::Result<MsgStruct, SdkError>;
    async fn edit_message(&self, conversation_id: &str, client_msg_id: &str, content: &str, content_type: i32) -> std::result::Result<MsgStruct, SdkError>;

    /// 按 clientMsgID 查找单条本地消息
    async fn get_message_by_client_msg_id(&self, client_msg_id: &str) -> std::result::Result<Option<LocalChatLog>, SdkError>;
    /// 插入群聊消息到本地存储
    async fn insert_group_message_to_local_storage(&self, group_id: &str, content: &str, content_type: i32, send_id: &str) -> std::result::Result<LocalChatLog, SdkError>;
    async fn insert_single_message_to_local_storage(&self, recv_id: &str, content: &str, content_type: i32, send_id: &str) -> std::result::Result<LocalChatLog, SdkError>;
    /// 上传文件，返回 URL
    async fn upload_file(&self, file_path: &str, file_name: &str) -> std::result::Result<String, SdkError>;
    /// 上传文件并回调进度，返回 URL
    async fn upload_file_with_progress(&self, file_path: &str, file_name: &str, progress: &Arc<dyn Fn(u8) + Send + Sync>) -> std::result::Result<String, SdkError>;
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
    async fn send_msg(&self, mut msg: MsgStruct, source_id: &str, offline_push_info: Option<OfflinePushInfo>) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_msg(msg, source_id, offline_push_info).await
    }

    /// 发送仅在线消息（isOnlineOnly）：不持久化、不同步、不更新会话
    /// 对齐 Go SDK SendMessage 的 isOnlineOnly=true 分支
    #[tracing::instrument(skip_all, fields(source_id = %source_id))]
    async fn send_msg_online_only(&self, mut msg: MsgStruct, source_id: &str) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_msg_online_only(msg, source_id).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_text_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_text_message(text, source_id, session_type).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_markdown_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_markdown_message(text, source_id, session_type).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_advanced_text_message(&self, text: &str, entities: Vec<crate::model::msg_struct::MessageEntity>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_advanced_text_message(text, entities, source_id, session_type).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_image_message(&self, file_path: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_image_message(file_path, source_id, session_type).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_image_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, progress: &ProgressCallback) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_image_message_with_progress(file_path, source_id, session_type, progress).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_file_message(&self, file_path: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_file_message(file_path, source_id, session_type).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_file_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, progress: &ProgressCallback) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_file_message_with_progress(file_path, source_id, session_type, progress).await
    }

    /// 发送语音消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_sound_message(&self, file_path: &str, source_id: &str, session_type: i32, duration: i64) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_sound_message(file_path, source_id, session_type, duration).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_sound_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, duration: i64, progress: &ProgressCallback) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_sound_message_with_progress(file_path, source_id, session_type, duration, progress).await
    }

    /// 发送视频消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_video_message(&self, video_path: &str, snapshot_path: &str, source_id: &str, session_type: i32, duration: i64) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_video_message(video_path, snapshot_path, source_id, session_type, duration).await
    }

    /// 发送视频消息（带上传进度回调，进度跟踪主视频文件）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_video_message_with_progress(
        &self,
        video_path: &str,
        snapshot_path: &str,
        source_id: &str,
        session_type: i32,
        duration: i64,
        progress: &ProgressCallback,
    ) -> std::result::Result<MsgStruct, SdkError> {
        self.sender
            .send_video_message_with_progress(video_path, snapshot_path, source_id, session_type, duration, progress)
            .await
    }

    /// 发送 @ 消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_at_text_message(&self, text: &str, at_user_ids: Vec<String>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_at_text_message(text, at_user_ids, source_id, session_type).await
    }

    /// 发送自定义消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_custom_message(&self, data: &str, desc: &str, extension: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_custom_message(data, desc, extension, source_id, session_type).await
    }

    /// 发送引用消息（对齐 Go SDK `CreateQuoteMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_quote_message(&self, text: &str, quote: crate::model::msg_struct::MsgStruct, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_quote_message(text, quote, source_id, session_type).await
    }

    /// 发送合并转发消息（对齐 Go SDK `CreateMergerMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_merger_message(&self, title: &str, summary_list: Vec<String>, context_list: Vec<MsgStruct>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_merger_message(title, summary_list, context_list, source_id, session_type).await
    }

    /// 发送名片消息（对齐 Go SDK `CreateCardMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_card_message(&self, user_id: &str, nickname: &str, face_url: &str, ex: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_card_message(user_id, nickname, face_url, ex, source_id, session_type).await
    }

    /// 发送位置消息（对齐 Go SDK `CreateLocationMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_location_message(&self, description: &str, longitude: f64, latitude: f64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_location_message(description, longitude, latitude, source_id, session_type).await
    }

    /// 发送表情消息（对齐 Go SDK `CreateFaceMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_face_message(&self, index: i32, data: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_face_message(index, data, source_id, session_type).await
    }

    /// 转发消息（对齐 Go SDK `ForwardMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn forward_message(&self, msg_struct: MsgStruct, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.forward_message(msg_struct, source_id, session_type).await
    }

    /// 从 URL 创建图片消息（对齐 Go SDK `CreateImageMessage(sourcePath="")`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_image_message_from_url(&self, source_url: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_image_message_from_url(source_url, source_id, session_type).await
    }

    /// 从 URL 创建语音消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_sound_message_from_url(&self, source_url: &str, duration: i64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_sound_message_from_url(source_url, duration, source_id, session_type).await
    }

    /// 从 URL 创建视频消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_video_message_from_url(&self, source_url: &str, duration: i64, snapshot_url: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_video_message_from_url(source_url, duration, snapshot_url, source_id, session_type).await
    }

    /// 从 URL 创建文件消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_file_message_from_url(&self, source_url: &str, file_name: &str, file_size: i64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_file_message_from_url(source_url, file_name, file_size, source_id, session_type).await
    }

    /// 发送分段 @ 消息（对齐 Go SDK `CreateAtTextMessage` 带 quote_msg）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    async fn send_at_text_message_with_quote(
        &self,
        text: &str,
        at_user_list: Vec<String>,
        at_users_info: Vec<crate::model::msg_struct::AtInfo>,
        quote_msg: Option<Box<MsgStruct>>,
        source_id: &str,
        session_type: i32,
    ) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.send_at_text_message_with_quote(text, at_user_list, at_users_info, quote_msg, source_id, session_type).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %req.conversation_id, count = %req.count))]
    async fn get_history_messages(&self, req: GetHistoryMessagesReq) -> std::result::Result<GetHistoryMessagesResult, SdkError> {
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
        self.message_service.search_local_messages(req).await
    }

    /// 发送正在输入通知（对齐 Go SDK `TypingStatusUpdate` / `ChangeInputStates`）
    ///
    /// Typing 消息不入库、不更新会话、不计未读、不触发离线推送。
    /// 通过 WS RPC 直接发送，设置 options 全部为 false。
    #[tracing::instrument(skip_all)]
    async fn send_typing(&self, source_id: &str, session_type: i32, focus: bool) -> std::result::Result<UserSendMsgResp, SdkError> {
        self.sender.send_typing(source_id, session_type, focus).await
    }

    // ========== 第一批测试所需的查询/删除方法 ==========

    /// 倒序获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageListReverse`）
    ///
    /// 从 start_client_msg_id 之前的消息开始，倒序获取 count 条。
    /// start_client_msg_id 为空时从最新消息开始。
    async fn get_history_messages_reverse(&self, conversation_id: &str, start_client_msg_id: &str, count: i64) -> std::result::Result<GetHistoryMessagesResult, SdkError> {
        self.message_service.get_history_messages_reverse(conversation_id, start_client_msg_id, count).await
    }

    /// 按 seq 范围获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageList` 中的 seq 范围查询）
    async fn get_advanced_history_message_list_by_seq(&self, conversation_id: &str, start_seq: i64, end_seq: i64, count: i32) -> std::result::Result<Vec<LocalChatLog>, SdkError> {
        self.message_service.get_advanced_history_message_list_by_seq(conversation_id, start_seq, end_seq, count).await
    }

    /// 按 seq 获取单条消息（对齐 Go SDK `GetMessageBySeq`）
    async fn get_history_message_by_seq(&self, seq: i64) -> std::result::Result<LocalChatLog, SdkError> {
        self.message_service.get_history_message_by_seq(seq).await
    }

    /// 按 clientMsgId 列表批量查找消息（对齐 Go SDK `FindMessageList`）
    async fn find_message_list(&self, conversation_id: &str, client_msg_ids: Vec<String>) -> std::result::Result<Vec<LocalChatLog>, SdkError> {
        self.message_service.find_message_list(conversation_id, client_msg_ids).await
    }

    /// 仅从本地删除单条消息（对齐 Go SDK `DeleteMessageFromLocalStorage`）
    ///
    /// 软删除：将消息状态标记为 MsgStatusHasDeleted(4)，不通知服务端。
    async fn delete_message_from_local_storage(&self, conversation_id: &str, client_msg_id: &str) -> std::result::Result<(), SdkError> {
        self.message_service.delete_message_from_local_storage(conversation_id, client_msg_id).await
    }

    /// 清空会话并删除所有消息（对齐 Go SDK `ClearConversationAndDeleteAllMsg`）
    ///
    /// 删除服务端+本地该会话的所有消息，会话本身保留。
    async fn clear_conversation_and_delete_all_msg(&self, conversation_id: &str) -> std::result::Result<(), SdkError> {
        self.message_service.clear_conversation_and_delete_all_msg(conversation_id).await
    }

    /// 删除会话并删除所有消息（对齐 Go SDK `DeleteConversationAndDeleteAllMsg`）
    ///
    /// 删除服务端+本地该会话的所有消息，并删除会话本身。
    async fn delete_conversation_and_delete_all_msg(&self, conversation_id: &str) -> std::result::Result<(), SdkError> {
        self.message_service.delete_conversation_and_delete_all_msg(conversation_id).await
    }

    /// 删除所有消息（本地+服务端）（对齐 Go SDK `DeleteAllMsgFromLocalAndSvr`）
    async fn delete_all_msg_from_local_and_svr(&self) -> std::result::Result<(), SdkError> {
        self.message_service.delete_all_msg_from_local_and_svr().await
    }

    /// 仅从本地删除所有消息（对齐 Go SDK `DeleteAllMsgFromLocal`）
    async fn delete_all_msg_from_local(&self) -> std::result::Result<(), SdkError> {
        self.message_service.delete_all_msg_from_local().await
    }

    /// 获取所有会话的总未读消息数（对齐 Go SDK `GetTotalUnreadMsgCount`）
    async fn get_total_unread_msg_count(&self) -> std::result::Result<i64, SdkError> {
        self.message_service.get_total_unread_msg_count().await
    }

    async fn get_server_time(&self) -> std::result::Result<i64, SdkError> {
        self.message_service.get_server_time().await
    }

    /// 设置消息本地扩展字段（对齐 Go SDK `SetMessageLocalEx`）
    async fn set_message_local_ex(&self, conversation_id: &str, client_msg_id: &str, local_ex: &str) -> std::result::Result<(), SdkError> {
        self.message_service.set_message_local_ex(conversation_id, client_msg_id, local_ex).await
    }

    /// 登录时清理发送中的消息（对齐 Go SDK userRelated.go L332-375）
    async fn cleanup_sending_messages(&self) {
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
        self.sender.send_advanced_quote_message(text, quote, message_entities, source_id, session_type).await
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
    async fn edit_message(&self, conversation_id: &str, client_msg_id: &str, content: &str, content_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        self.sender.edit_message(conversation_id, client_msg_id, content, content_type).await
    }

    fn take_message_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<MessageEvent>, SdkError> {
        self.listeners.take_message_rx().ok_or_else(|| SdkError::unknown("message receiver already taken"))
    }
    async fn get_message_by_client_msg_id(&self, client_msg_id: &str) -> std::result::Result<Option<LocalChatLog>, SdkError> {
        self.message_service.get_message_by_client_msg_id(client_msg_id).await
    }

    async fn insert_group_message_to_local_storage(&self, group_id: &str, content: &str, content_type: i32, send_id: &str) -> std::result::Result<LocalChatLog, SdkError> {
        self.message_service.insert_group_message_to_local_storage(group_id, content, content_type, send_id).await
    }

    async fn insert_single_message_to_local_storage(&self, recv_id: &str, content: &str, content_type: i32, send_id: &str) -> std::result::Result<LocalChatLog, SdkError> {
        self.message_service.insert_single_message_to_local_storage(recv_id, content, content_type, send_id).await
    }

    async fn upload_file(&self, file_path: &str, file_name: &str) -> std::result::Result<String, SdkError> {
        self.sender.upload_file(file_path, file_name).await
    }

    async fn upload_file_with_progress(&self, file_path: &str, file_name: &str, progress: &Arc<dyn Fn(u8) + Send + Sync>) -> std::result::Result<String, SdkError> {
        self.sender.upload_file_with_progress(file_path, file_name, progress).await
    }
}
