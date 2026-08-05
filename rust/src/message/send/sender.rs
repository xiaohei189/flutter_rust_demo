//! 消息发送器 — 发送编排与媒体消息构造
//!
//! 从 sdk 门面下沉：`MessageSendTransport` 传输抽象、`MessageSender` 发送编排、
//! 媒体上传+消息构造、发送中消息清理所需的自由函数。
//! 门面层只保留 `MessageApi` 的薄委托。

use crate::connection::manager::ConnectionManager;
use crate::file::uploader::{FileUploader, ProgressCallback};
use crate::message::send::queue::MessageSendQueue;
use crate::message::ContentTypeUtils;
use crate::user::service::UserService;
use crate::constant::MessageSendStatus;
use crate::error::{Result, SdkError};
use crate::model::local::{LocalChatLog, LocalSendingMessage};
use crate::model::msg_struct::{get_msg_id, AtInfo, MessageEntity, MsgStruct, MSG_STATUS_SENDING};
use crate::event::events::conversation::{ConversationEvent, ConversationListenerExt};
use crate::event::events::message::{MessageEvent, MessageListenerExt};
use crate::client::context::RuntimeContext;
use async_trait::async_trait;
use openim_protocol::sdkws::{MsgData, OfflinePushInfo, UserSendMsgResp};
use serde_json::{json, Value};
use std::path::Path;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tracing::{debug, error, info, warn};

#[async_trait]
pub trait MessageSendTransport: Send + Sync {
    /// 发送消息 RPC（对应 req_identifier=1003）
    async fn send_msg_rpc(&self, msg_data: &MsgData) -> std::result::Result<UserSendMsgResp, SdkError>;
}
/// ConnectionManager 实现消息发送传输（WebSocket RPC）
#[async_trait]
impl MessageSendTransport for ConnectionManager {
    async fn send_msg_rpc(&self, msg_data: &MsgData) -> std::result::Result<UserSendMsgResp, SdkError> {
        self.send_rpc::<MsgData, UserSendMsgResp>(1003, msg_data).await
    }
}

/// 计算消息的 conversation_id
pub(crate) fn conversation_id_for_msg(msg: &MsgStruct) -> String {
    if msg.session_type == 1 {
        let mut ids = vec![msg.send_id.clone(), msg.recv_id.clone()];
        ids.sort();
        format!("si_{}_{}", ids[0], ids[1])
    } else if msg.session_type == 3 {
        // ReadGroupChat: sg_{group_id}
        format!("sg_{}", msg.group_id)
    } else {
        // WriteGroupChat(2) or fallback: g_{group_id}
        format!("g_{}", msg.group_id)
    }
}

/// 获取 content_type 的中文描述
pub(crate) fn content_type_name(ct: i32) -> &'static str {
    ContentTypeUtils::display_name_zh(ct)
}

/// 处理媒体内容上传（独立函数版本）
pub(crate) async fn process_media_content_impl(
    file_uploader: &FileUploader,
    msg: &MsgStruct,
) -> std::result::Result<String, SdkError> {
    if !ContentTypeUtils::is_media(msg.content_type) {
        return Ok(msg.content.clone());
    }

    let mut value: Value = match serde_json::from_str(&msg.content) {
        Ok(v) => v,
        Err(_) => return Ok(msg.content.clone()),
    };

    // 如果是图片消息且没有 sourcePath 但有 sourceUrl，说明已上传过
    let source_path = match value.get("sourcePath").and_then(|v| v.as_str()) {
        Some(p) if !p.is_empty() => p.to_string(),
        _ => return Ok(msg.content.clone()),
    };

    let path = Path::new(&source_path);
    if !path.exists() {
        info!("sourcePath 文件不存在，跳过上传: {}", source_path);
        return Ok(msg.content.clone());
    }

    let file_name = path.file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown")
        .to_string();

    info!("开始上传媒体文件: content_type={}, path={}", msg.content_type, source_path);

    let upload_result = file_uploader.upload_file(&source_path, &file_name, None).await?;
    let url = upload_result.url;

    // 临时文件清理（对齐 Go SDK 上传后删除本地临时文件）
    if let Err(e) = std::fs::remove_file(&source_path) {
        debug!("删除临时文件失败: path={}, err={}", source_path, e);
    }

    info!("媒体文件上传成功: url={}", url);

    if msg.content_type == 102 {
        // 图片消息：设置 SourcePicture + BigPicture + SnapshotPicture（对齐 Go SDK api.go L356-374）
        let source_picture = json!({ "url": url });
        value["sourcePicture"] = source_picture.clone();
        value["bigPicture"] = source_picture;

        // 生成快照URL：追加 ?type=image&width=640&height=640
        let snapshot_url = if url.contains('?') {
            format!("{}&type=image&width=640&height=640", url)
        } else {
            format!("{}?type=image&width=640&height=640", url)
        };
        value["snapshotPicture"] = json!({
            "width": 640,
            "height": 640,
            "url": snapshot_url,
        });
    } else {
        value["sourceUrl"] = json!(url);
    }

    value.as_object_mut()
        .and_then(|map| map.remove("sourcePath"));

    let new_content = serde_json::to_string(&value)
        .unwrap_or_else(|_| msg.content.clone());

    Ok(new_content)
}

/// 发送前插入消息到 DB（独立函数版本）
pub(crate) async fn insert_message_before_send_impl(
    context: &RuntimeContext,
    msg: &MsgStruct,
    send_time: i64,
) -> Result<()> {
    let conversation_id = conversation_id_for_msg(msg);

    let mut local_log = LocalChatLog::from(msg);
    local_log.conversation_id = conversation_id.clone();
    local_log.send_time = send_time;
    local_log.create_time = send_time;
    local_log.status = MessageSendStatus::Sending as i32;

    context.repositories.message_repo.batch_insert(&[local_log]).await?;
    context.repositories.sending_message_repo.insert(&LocalSendingMessage {
        conversation_id: conversation_id.clone(),
        client_msg_id: msg.client_msg_id.clone(),
        ex: String::new(),
    }).await?;
    context.repositories.conversation_repo.update_after_sent_message(
        &conversation_id,
        &msg.content,
        send_time,
    ).await?;

    // 会话乐观更新（对齐 Go SDK api.go L322-324）
    if let Ok(Some(conv)) = context.repositories.conversation_repo.get_by_id(&conversation_id).await {
        ConversationListenerExt::emit(&*context.listeners, ConversationEvent::Changed(vec![conv]));
    }

    Ok(())
}

/// 执行消息发送的核心逻辑（独立函数版本，供队列调用）
#[tracing::instrument(skip_all)]
pub(crate) async fn do_send_message_impl(
    context: Arc<RuntimeContext>,
    transport: Arc<dyn MessageSendTransport>,
    file_uploader: Arc<FileUploader>,
    msg: MsgStruct,
    offline_push_info: Option<OfflinePushInfo>,
    online_only: bool,
) -> std::result::Result<UserSendMsgResp, SdkError> {
    let start = std::time::Instant::now();
    let conversation_id = conversation_id_for_msg(&msg);
    info!("[SendMsg] 开始: conv={}, content_type={}({}), online_only={}",
        conversation_id, msg.content_type, content_type_name(msg.content_type), online_only);

    let send_time = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);

    let content = process_media_content_impl(&file_uploader, &msg).await?;

    // isOnlineOnly: 跳过本地持久化（对齐 Go SDK api.go L154-157, L657-664）
    if !online_only {
        insert_message_before_send_impl(&context, &msg, send_time).await?;
        debug!("[SendMsg] 本地写入完成: client_msg_id={}", msg.client_msg_id);
    }

    let mut msg_data = MsgData::from(&msg);
    msg_data.content = content.into_bytes();
    msg_data.send_time = send_time;
    msg_data.create_time = send_time;
    msg_data.offline_push_info = offline_push_info;

    // isOnlineOnly: 设置 options 全部为 false（对齐 Go SDK api.go L657-664）
    if online_only {
        msg_data.options.insert("isOnlineOnly".to_string(), true);
        msg_data.options.insert("history".to_string(), false);
        msg_data.options.insert("persistent".to_string(), false);
        msg_data.options.insert("senderSync".to_string(), false);
        msg_data.options.insert("conversationUpdate".to_string(), false);
        msg_data.options.insert("senderConversationUpdate".to_string(), false);
        msg_data.options.insert("unreadCount".to_string(), false);
        msg_data.options.insert("offlinePush".to_string(), false);
    }

    let resp: UserSendMsgResp = match transport.send_msg_rpc(&msg_data).await {
        Ok(r) => {
            info!("[SendMsg] 完成: client_msg_id={}, server_msg_id={}, elapsed={}ms",
                r.client_msg_id, r.server_msg_id, start.elapsed().as_millis());
            r
        }
        Err(e) => {
            if !online_only {
                // 网络超时二次确认（对齐 Go SDK api.go L682-698）
                if let SdkError::Timeout { .. } = &e {
                    if let Ok(Some(old_msg)) = context.repositories.message_repo
                        .get_by_client_msg_id(&conversation_id, &msg.client_msg_id).await
                    {
                        if old_msg.status == MessageSendStatus::SendSuccess as i32 {
                            info!("消息超时但DB已标记成功: client_msg_id={}", msg.client_msg_id);
                            return Ok(UserSendMsgResp {
                                server_msg_id: old_msg.server_msg_id,
                                client_msg_id: old_msg.client_msg_id,
                                send_time: old_msg.send_time,
                            });
                        }
                    }
                }
                context.repositories.message_repo.update_send_status(&msg.client_msg_id, MessageSendStatus::SendFailed.into()).await?;
                MessageListenerExt::emit(&*context.listeners, MessageEvent::SendFailed {
                    client_msg_id: msg.client_msg_id.clone(),
                    error: format!("{}", e),
                });

            }
            return Err(SdkError::message_send(format!("send message via ws failed: {}", e)));
        }
    };

    // isOnlineOnly: 跳过本地状态更新和会话触发（对齐 Go SDK api.go L154-157）
    if !online_only {
        if let Err(e) = context.repositories.message_repo.update_after_send_success(&msg.client_msg_id, &resp.server_msg_id, resp.send_time).await {
            error!("更新发送结果失败: {}", e);
        }

        // 发送成功，从 sending_messages 中移除（对齐 Go SDK api.go L167）
        if let Err(e) = context.repositories.sending_message_repo.delete(&conversation_id, &msg.client_msg_id).await {
            debug!("删除sending_message失败: {}", e);
        }

        // 对齐 Go SDK：消息发送结果仅通过返回值（Message）传递，不发布事件
    }

    Ok(resp)
}

/// 消息发送器 — 持有发送编排所需依赖，被 OpenIMClient 门面调用
pub struct MessageSender {
    context: Arc<RuntimeContext>,
    connection: Arc<ConnectionManager>,
    file_uploader: Arc<FileUploader>,
    send_queue: Arc<MessageSendQueue>,
    user: Arc<UserService>,
}

impl MessageSender {
    pub fn new(
        context: Arc<RuntimeContext>,
        connection: Arc<ConnectionManager>,
        file_uploader: Arc<FileUploader>,
        send_queue: Arc<MessageSendQueue>,
        user: Arc<UserService>,
    ) -> Self {
        Self { context, connection, file_uploader, send_queue, user }
    }

    /// 登录时设置上传器登录用户
    pub fn set_login_user_id(&self, user_id: String) {
        self.file_uploader.set_login_user_id(user_id);
    }

    #[tracing::instrument(skip_all)]
    pub async fn send_msg(&self, mut msg: MsgStruct, source_id: &str, offline_push_info: Option<OfflinePushInfo>) -> std::result::Result<MsgStruct, SdkError> {
        self.send_msg_inner(msg, source_id, offline_push_info, false).await
    }

    /// 发送仅在线消息（isOnlineOnly）：不持久化、不同步、不更新会话
    /// 对齐 Go SDK SendMessage 的 isOnlineOnly=true 分支
    #[tracing::instrument(skip_all, fields(source_id = %source_id))]
    pub async fn send_msg_online_only(&self, mut msg: MsgStruct, source_id: &str) -> std::result::Result<MsgStruct, SdkError> {
        self.send_msg_inner(msg, source_id, None, true).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_image_message(&self, file_path: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let upload_result = self.file_uploader.upload_image(file_path, None).await
            .map_err(|e| SdkError::message_send(format!("upload image failed: {}", e)))?;
        let source = crate::model::msg_struct::PictureBaseInfo {
            width: 0, height: 0, picture_type: String::new(),
            size: upload_result.size as i64, url: upload_result.url, uuid: String::new(),
        };
        let mut msg = MsgStruct::create_image_message(
            file_path, source,
            crate::model::msg_struct::PictureBaseInfo::default(),
            crate::model::msg_struct::PictureBaseInfo::default(),
        );
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_image_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, progress: &ProgressCallback) -> std::result::Result<MsgStruct, SdkError> {
        let upload_result = self.file_uploader.upload_image(file_path, Some(progress.clone())).await
            .map_err(|e| SdkError::message_send(format!("upload image failed: {}", e)))?;
        let source = crate::model::msg_struct::PictureBaseInfo {
            width: 0, height: 0, picture_type: String::new(),
            size: upload_result.size as i64, url: upload_result.url, uuid: String::new(),
        };
        let mut msg = MsgStruct::create_image_message(
            file_path, source,
            crate::model::msg_struct::PictureBaseInfo::default(),
            crate::model::msg_struct::PictureBaseInfo::default(),
        );
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_file_message(&self, file_path: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let path = std::path::Path::new(file_path);
        let file_name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();
        let upload_result = self.file_uploader.upload_file(file_path, &file_name, None).await
            .map_err(|e| SdkError::message_send(format!("upload file failed: {}", e)))?;
        let file_elem = crate::model::msg_struct::FileElem {
            file_path: file_path.to_string(),
            uuid: upload_result.file_id.clone(),
            source_url: upload_result.url,
            file_name,
            file_size: upload_result.size as i64,
            file_type: upload_result.content_type,
        };
        let mut msg = MsgStruct::create_file_message(file_elem);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_file_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, progress: &ProgressCallback) -> std::result::Result<MsgStruct, SdkError> {
        let path = std::path::Path::new(file_path);
        let file_name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();
        let upload_result = self.file_uploader.upload_file_with_progress(file_path, &file_name, None, Some(progress.clone())).await
            .map_err(|e| SdkError::message_send(format!("upload file failed: {}", e)))?;
        let file_elem = crate::model::msg_struct::FileElem {
            file_path: file_path.to_string(),
            uuid: upload_result.file_id.clone(),
            source_url: upload_result.url,
            file_name,
            file_size: upload_result.size as i64,
            file_type: upload_result.content_type,
        };
        let mut msg = MsgStruct::create_file_message(file_elem);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 发送语音消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_sound_message(&self, file_path: &str, source_id: &str, session_type: i32, duration: i64) -> std::result::Result<MsgStruct, SdkError> {
        let path = std::path::Path::new(file_path);
        let file_name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("audio")
            .to_string();
        let upload_result = self.file_uploader.upload_file(file_path, &file_name, None).await
            .map_err(|e| SdkError::message_send(format!("upload sound failed: {}", e)))?;
        let sound_elem = crate::model::msg_struct::SoundElem {
            uuid: upload_result.file_id.clone(),
            sound_path: file_path.to_string(),
            source_url: upload_result.url,
            data_size: upload_result.size as i64,
            duration,
            sound_type: upload_result.content_type,
        };
        let mut msg = MsgStruct::create_sound_message(sound_elem);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_sound_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, duration: i64, progress: &ProgressCallback) -> std::result::Result<MsgStruct, SdkError> {
        let path = std::path::Path::new(file_path);
        let file_name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("audio")
            .to_string();
        let upload_result = self.file_uploader.upload_file_with_progress(file_path, &file_name, None, Some(progress.clone())).await
            .map_err(|e| SdkError::message_send(format!("upload sound failed: {}", e)))?;
        let sound_elem = crate::model::msg_struct::SoundElem {
            uuid: upload_result.file_id.clone(),
            sound_path: file_path.to_string(),
            source_url: upload_result.url,
            data_size: upload_result.size as i64,
            duration,
            sound_type: upload_result.content_type,
        };
        let mut msg = MsgStruct::create_sound_message(sound_elem);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 发送视频消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_video_message(&self, video_path: &str, snapshot_path: &str, source_id: &str, session_type: i32, duration: i64) -> std::result::Result<MsgStruct, SdkError> {
        // 上传视频文件
        let v_path = std::path::Path::new(video_path);
        let v_name = v_path.file_name().and_then(|n| n.to_str()).unwrap_or("video").to_string();
        let v_upload = self.file_uploader.upload_file(video_path, &v_name, None).await
            .map_err(|e| SdkError::message_send(format!("upload video failed: {}", e)))?;

        // 上传封面图
        let s_path = std::path::Path::new(snapshot_path);
        let s_name = s_path.file_name().and_then(|n| n.to_str()).unwrap_or("snapshot").to_string();
        let s_upload = self.file_uploader.upload_file(snapshot_path, &s_name, None).await
            .map_err(|e| SdkError::message_send(format!("upload snapshot failed: {}", e)))?;

        let video_elem = crate::model::msg_struct::VideoElem {
            video_path: video_path.to_string(),
            video_uuid: v_upload.file_id.clone(),
            video_url: v_upload.url,
            video_type: v_upload.content_type,
            video_size: v_upload.size as i64,
            duration,
            snapshot_path: snapshot_path.to_string(),
            snapshot_uuid: s_upload.file_id,
            snapshot_size: s_upload.size as i64,
            snapshot_url: s_upload.url,
            snapshot_width: 0,
            snapshot_height: 0,
            snapshot_type: String::new(),
        };
        let mut msg = MsgStruct::create_video_message(video_elem);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 发送视频消息（带上传进度回调，进度跟踪主视频文件）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_video_message_with_progress(&self, video_path: &str, snapshot_path: &str, source_id: &str, session_type: i32, duration: i64, progress: &ProgressCallback) -> std::result::Result<MsgStruct, SdkError> {
        // 上传视频文件（带进度回调）
        let v_path = std::path::Path::new(video_path);
        let v_name = v_path.file_name().and_then(|n| n.to_str()).unwrap_or("video").to_string();
        let v_upload = self.file_uploader.upload_file_with_progress(video_path, &v_name, None, Some(progress.clone())).await
            .map_err(|e| SdkError::message_send(format!("upload video failed: {}", e)))?;

        // 上传封面图（无进度回调）
        let s_path = std::path::Path::new(snapshot_path);
        let s_name = s_path.file_name().and_then(|n| n.to_str()).unwrap_or("snapshot").to_string();
        let s_upload = self.file_uploader.upload_file(snapshot_path, &s_name, None).await
            .map_err(|e| SdkError::message_send(format!("upload snapshot failed: {}", e)))?;

        let video_elem = crate::model::msg_struct::VideoElem {
            video_path: video_path.to_string(),
            video_uuid: v_upload.file_id.clone(),
            video_url: v_upload.url,
            video_type: v_upload.content_type,
            video_size: v_upload.size as i64,
            duration,
            snapshot_path: snapshot_path.to_string(),
            snapshot_uuid: s_upload.file_id,
            snapshot_size: s_upload.size as i64,
            snapshot_url: s_upload.url,
            snapshot_width: 0,
            snapshot_height: 0,
            snapshot_type: String::new(),
        };
        let mut msg = MsgStruct::create_video_message(video_elem);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 从 URL 创建图片消息（对齐 Go SDK `CreateImageMessage(sourcePath="")`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_image_message_from_url(&self, source_url: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let picture = crate::model::msg_struct::PictureBaseInfo {
            url: source_url.to_string(),
            ..Default::default()
        };
        let mut msg = MsgStruct::create_image_message("", picture.clone(), picture.clone(), picture);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 从 URL 创建语音消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_sound_message_from_url(&self, source_url: &str, duration: i64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let elem = crate::model::msg_struct::SoundElem {
            source_url: source_url.to_string(),
            duration,
            ..Default::default()
        };
        let mut msg = MsgStruct::create_sound_message(elem);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 从 URL 创建视频消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_video_message_from_url(&self, source_url: &str, duration: i64, snapshot_url: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let elem = crate::model::msg_struct::VideoElem {
            video_url: source_url.to_string(),
            duration,
            snapshot_url: snapshot_url.to_string(),
            ..Default::default()
        };
        let mut msg = MsgStruct::create_video_message(elem);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 从 URL 创建文件消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_file_message_from_url(&self, source_url: &str, file_name: &str, file_size: i64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let elem = crate::model::msg_struct::FileElem {
            source_url: source_url.to_string(),
            file_name: file_name.to_string(),
            file_size,
            ..Default::default()
        };
        let mut msg = MsgStruct::create_file_message(elem);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 发送正在输入通知（对齐 Go SDK `TypingStatusUpdate` / `ChangeInputStates`）
    ///
    /// Typing 消息不入库、不更新会话、不计未读、不触发离线推送。
    /// 通过 WS RPC 直接发送，设置 options 全部为 false。
    #[tracing::instrument(skip_all)]
    pub async fn send_typing(&self, source_id: &str, session_type: i32, focus: bool) -> std::result::Result<UserSendMsgResp, SdkError> {
        let send_id = self.context.user_id.get().await;
        let platform_id = self.context.config.platform_id;
        let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as i64;

        let msg_tips = if focus { "yes" } else { "no" };
        let mut msg = MsgStruct::create_typing_message(msg_tips);
        msg.send_id = send_id;
        msg.sender_platform_id = platform_id;
        msg.client_msg_id = crate::model::msg_struct::get_msg_id(&msg.send_id);
        msg.create_time = now;
        msg.send_time = now;
        msg.session_type = session_type;

        if session_type == 1 {
            msg.recv_id = source_id.to_string();
        } else {
            msg.group_id = source_id.to_string();
        }

        // 注入发送者信息
        if let Ok(user_info) = self.user.get_self_user_info().await {
            msg.sender_nickname = user_info.nickname;
            msg.sender_face_url = user_info.face_url;
        }

        let mut msg_data = MsgData::from(&msg);
        // 设置 options：全部关闭（对齐 Go SDK entering.go）
        let mut options = std::collections::HashMap::new();
        options.insert("history".to_string(), false);
        options.insert("persistent".to_string(), false);
        options.insert("senderSync".to_string(), false);
        options.insert("conversationUpdate".to_string(), false);
        options.insert("senderConversationUpdate".to_string(), false);
        options.insert("unreadCount".to_string(), false);
        options.insert("offlinePush".to_string(), false);
        msg_data.options = options;

        // 直接通过 WS RPC 发送，不走 send_msg（不入库、不更新会话）
        info!("[Typing] 请求: source_id={}, session_type={}, focus={}",
            source_id, session_type, focus);
        let resp: UserSendMsgResp = self.connection.send_rpc(
            crate::constant::ws_req_identifier::SEND_MSG,
            &msg_data,
        ).await?;

        info!("[Typing] 响应: client_msg_id={}, server_msg_id={}, send_time={}",
            resp.client_msg_id, resp.server_msg_id, resp.send_time);
        Ok(resp)
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
    pub async fn edit_message(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
        content: &str,
        content_type: i32,
    ) -> std::result::Result<MsgStruct, SdkError> {
        // 查找原始消息以获取会话信息
        let original = self.context.repositories.message_repo
            .get_by_client_msg_id(conversation_id, client_msg_id)
            .await?
            .ok_or_else(|| SdkError::invalid_argument(format!("消息不存在: client_msg_id={}", client_msg_id)))?;

        // 构造编辑后的消息结构
        let mut msg = MsgStruct::new();
        msg.content_type = content_type;
        msg.content = content.to_string();
        msg.msg_from = crate::model::msg_struct::MSG_FROM_USER;

        // 从 content 恢复 typed elem
        match content_type {
            101 => {
                if let Ok(elem) = serde_json::from_str::<crate::model::msg_struct::TextElem>(content) {
                    msg.text_elem = Some(elem);
                }
            }
            117 => {
                if let Ok(elem) = serde_json::from_str::<crate::model::msg_struct::AdvancedTextElem>(content) {
                    msg.advanced_text_elem = Some(elem);
                }
            }
            118 => {
                if let Ok(elem) = serde_json::from_str::<crate::model::msg_struct::MarkdownTextElem>(content) {
                    msg.markdown_text_elem = Some(elem);
                }
            }
            _ => {}
        }

        // 设置会话类型
        msg.session_type = if conversation_id.starts_with("si_") {
            1 // SINGLE_CHAT
        } else {
            2 // WRITE_GROUP_CHAT
        };

        // source_id: 单聊用 recv_id，群聊用 group_id
        let source_id = if msg.session_type == 1 {
            if original.recv_id == self.context.user_id.get().await {
                original.send_id.clone()
            } else {
                original.recv_id.clone()
            }
        } else {
            original.group_id.clone()
        };

        // 发送消息（服务端通过 MsgDataToModifyByMQ 广播修改通知给其他设备）
        self.send_msg(msg, &source_id, None).await
    }

    pub async fn upload_file(&self, file_path: &str, file_name: &str) -> std::result::Result<String, SdkError> {
        let result = self.file_uploader.upload_file(file_path, file_name, None).await?;
        Ok(result.url)
    }

    pub async fn upload_file_with_progress(&self, file_path: &str, file_name: &str, progress: &Arc<dyn Fn(u8) + Send + Sync>) -> std::result::Result<String, SdkError> {
        let result = self.file_uploader.upload_file_with_progress(file_path, file_name, None, Some(progress.clone())).await?;
        Ok(result.url)
    }

}

impl MessageSender {
    async fn send_msg_inner(&self, mut msg: MsgStruct, source_id: &str, offline_push_info: Option<OfflinePushInfo>, online_only: bool) -> std::result::Result<MsgStruct, SdkError> {
        let send_id = self.context.user_id.get().await;
        let platform_id = self.context.config.platform_id;
        let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as i64;

        msg.send_id = send_id;
        msg.sender_platform_id = platform_id;
        msg.client_msg_id = get_msg_id(&msg.send_id);
        msg.create_time = now;
        msg.send_time = now;
        msg.status = MSG_STATUS_SENDING;
        msg.is_read = false;

        // 发送者昵称/头像注入（对齐 Go SDK initBasicInfo api.go L985-1003）
        if let Ok(user_info) = self.user.get_self_user_info().await {
            msg.sender_nickname = user_info.nickname;
            msg.sender_face_url = user_info.face_url;
        }

        // WriteGroupChatType(2) 已被服务端废弃，自动映射为 ReadGroupChatType(3)
        // 对齐 Go SDK: WriteGroupChatType 注释 "Not enabled temporarily"
        if msg.session_type == 2 {
            msg.session_type = 3;
        }

        if msg.session_type == 1 {
            msg.recv_id = source_id.to_string();
        } else {
            msg.group_id = source_id.to_string();
        }

        // 发送前去重（对齐 Go SDK api.go L293-321）
        // isOnlineOnly 消息不入库，无需去重检查
        if !online_only {
            let conversation_id = conversation_id_for_msg(&msg);
            if let Ok(Some(old_msg)) = self.context.repositories.message_repo.get_by_client_msg_id(&conversation_id, &msg.client_msg_id).await {
                if old_msg.status != MessageSendStatus::SendFailed as i32 {
                    return Err(SdkError::msg_repeated("Only failed messages can be resent"));
                }
                // 失败重试：允许继续发送
            }
        }

        // 通过双 Lane 发送队列提交消息
        let context = self.context.clone();
        let connection = self.connection.clone();
        let file_uploader = self.file_uploader.clone();
        let msg_clone = msg.clone();

        let resp = self.send_queue.submit(msg.content_type, move || {
            Box::pin(async move {
                do_send_message_impl(context, connection, file_uploader, msg_clone, offline_push_info, online_only).await
            })
        }).await?;

        // 回填服务端返回字段（对齐 Go SDK api.go sendMsg L730-732）
        msg.server_msg_id = resp.server_msg_id;
        msg.send_time = resp.send_time;
        msg.status = 2; // MsgStatusSendSuccess

        // 输入：完整构造的发送消息
        if let Ok(json) = serde_json::to_string(&msg) {
            tracing::info!("[SEND] 发送消息: {}", json);
        }

        // 输出：服务端返回
        let resp_json = serde_json::json!({
            "client_msg_id": msg.client_msg_id,
            "server_msg_id": msg.server_msg_id,
            "send_time": msg.send_time,
            "status": msg.status,
            "send_id": msg.send_id,
            "recv_id": msg.recv_id,
            "group_id": msg.group_id,
            "session_type": msg.session_type,
            "content_type": msg.content_type,
        });
        tracing::info!("[SEND] 发送结果: {}", resp_json);

        Ok(msg)
    }
}


#[cfg(test)]
mod tests {
    use super::*;
    use crate::http::client::HttpApiClient;
    use crate::model::msg_struct::MsgStruct;

    /// 创建测试用 FileUploader（不会实际触发上传）
    fn make_uploader() -> Arc<FileUploader> {
        let http = Arc::new(HttpApiClient::new(
            "http://localhost:10002".to_string(),
            "test_token".to_string(),
            "test_op".to_string(),
        ));
        Arc::new(FileUploader::new(http))
    }

    // ========================================================================
    // process_media_content_impl 测试
    // ========================================================================

    #[tokio::test]
    async fn test_process_media_non_media_passthrough() {
        let uploader = make_uploader();
        let mut msg = MsgStruct::default();
        msg.content_type = 101; // 文本消息，非媒体
        msg.content = r#"{"content":"hello"}"#.to_string();

        let result = process_media_content_impl(&uploader, &msg).await.unwrap();
        assert_eq!(result, msg.content, "非媒体消息应原样返回");
    }

    #[tokio::test]
    async fn test_process_media_invalid_content_json() {
        let uploader = make_uploader();
        let mut msg = MsgStruct::default();
        msg.content_type = 102; // 图片
        msg.content = "not-json".to_string();

        let result = process_media_content_impl(&uploader, &msg).await.unwrap();
        assert_eq!(result, msg.content, "非法 JSON 应原样返回");
    }

    #[tokio::test]
    async fn test_process_media_no_source_path() {
        let uploader = make_uploader();
        let mut msg = MsgStruct::default();
        msg.content_type = 102;
        msg.content = r#"{"uuid":"test","type":"jpg"}"#.to_string();

        let result = process_media_content_impl(&uploader, &msg).await.unwrap();
        assert_eq!(result, msg.content, "无 sourcePath 应原样返回");
    }

    #[tokio::test]
    async fn test_process_media_empty_source_path() {
        let uploader = make_uploader();
        let mut msg = MsgStruct::default();
        msg.content_type = 102;
        msg.content = r#"{"sourcePath":""}"#.to_string();

        let result = process_media_content_impl(&uploader, &msg).await.unwrap();
        assert_eq!(result, msg.content, "空 sourcePath 应原样返回");
    }

    #[tokio::test]
    async fn test_process_media_file_not_exists() {
        let uploader = make_uploader();
        let mut msg = MsgStruct::default();
        msg.content_type = 102;
        msg.content = r#"{"sourcePath":"/tmp/nonexistent_file_xyz.jpg"}"#.to_string();

        let result = process_media_content_impl(&uploader, &msg).await.unwrap();
        assert_eq!(result, msg.content, "文件不存在应原样返回");
    }

    #[tokio::test]
    async fn test_process_media_sound_type_no_source_path() {
        let uploader = make_uploader();
        let mut msg = MsgStruct::default();
        msg.content_type = 103; // 语音
        msg.content = r#"{"uuid":"test","duration":5}"#.to_string();

        let result = process_media_content_impl(&uploader, &msg).await.unwrap();
        assert_eq!(result, msg.content, "语音无 sourcePath 应原样返回");
    }

    #[tokio::test]
    async fn test_process_media_video_type_no_source_path() {
        let uploader = make_uploader();
        let mut msg = MsgStruct::default();
        msg.content_type = 104; // 视频
        msg.content = r#"{"videoPath":"/tmp/video.mp4"}"#.to_string();

        let result = process_media_content_impl(&uploader, &msg).await.unwrap();
        assert_eq!(result, msg.content, "视频无 sourcePath 应原样返回");
    }

    #[tokio::test]
    async fn test_process_media_unknown_type_no_source_path() {
        let uploader = make_uploader();
        let mut msg = MsgStruct::default();
        msg.content_type = 105; // 文件
        msg.content = r#"{"fileName":"test.pdf"}"#.to_string();

        let result = process_media_content_impl(&uploader, &msg).await.unwrap();
        assert_eq!(result, msg.content, "文件无 sourcePath 应原样返回");
    }

    // ========================================================================
    // conversation_id_for_msg 测试
    // ========================================================================

    #[test]
    fn test_conversation_id_single_chat_sorted() {
        let mut msg = MsgStruct::default();
        msg.session_type = 1;
        msg.send_id = "user_b".to_string();
        msg.recv_id = "user_a".to_string();
        assert_eq!(conversation_id_for_msg(&msg), "si_user_a_user_b");
    }

    #[test]
    fn test_conversation_id_group_chat() {
        let mut msg = MsgStruct::default();
        msg.session_type = 3;
        msg.group_id = "group_123".to_string();
        assert_eq!(conversation_id_for_msg(&msg), "sg_group_123");
    }

    // ========================================================================
    // content_type_name 测试
    // ========================================================================

    #[test]
    fn test_content_type_name_text() {
        assert_eq!(content_type_name(101), "文本");
    }

    #[test]
    fn test_content_type_name_unknown() {
        assert_eq!(content_type_name(9999), "未知");
    }
}
