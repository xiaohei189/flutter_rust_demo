use crate::core::connection::manager::ConnectionManager;
use crate::core::file::uploader::{FileUploader, ProgressCallback};
use crate::core::message::content_type::ContentTypeUtils;
use crate::domain::constant::enums::MessageSendStatus;
use crate::domain::error::types::Result;
use crate::domain::error::types::SdkError;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::message::MessageInfo;
use crate::domain::model::msg_struct::{get_msg_id, MsgStruct};
use crate::domain::model::msg_struct::MSG_STATUS_SENDING;
use crate::infra::database::models::{LocalChatLog, LocalSendingMessage};
use crate::protocol::sdkws::{MsgData, OfflinePushInfo, UserSendMsgResp};
use crate::sdk::client::types::{
    DeleteMessagesReq, GetHistoryMessagesReq, GetHistoryMessagesResult, MarkMessagesAsReadReq, RevokeMessageReq,
    SearchMessagesReq,
};
use crate::sdk::client::OpenIMClient;
use crate::sdk::context::RuntimeContext;
use std::path::Path;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tracing::{info, error, debug, warn};
use serde_json::{json, Value};

// ============================================================================
// 独立函数：消息发送核心逻辑
// ============================================================================

/// 计算消息的 conversation_id
fn conversation_id_for_msg(msg: &MsgStruct) -> String {
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
fn content_type_name(ct: i32) -> &'static str {
    ContentTypeUtils::display_name_zh(ct)
}

/// 处理媒体内容上传（独立函数版本）
async fn process_media_content_impl(
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
async fn insert_message_before_send_impl(
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

    context.message_dao.batch_insert(&[local_log]).await?;
    context.sending_message_dao.insert(&LocalSendingMessage {
        conversation_id: conversation_id.clone(),
        client_msg_id: msg.client_msg_id.clone(),
        ex: String::new(),
    }).await?;
    context.conversation_dao.update_after_sent_message(
        &conversation_id,
        &msg.content,
        send_time,
    ).await?;

    // 会话乐观更新（对齐 Go SDK api.go L322-324）
    if let Ok(Some(conv)) = context.conversation_dao.get_by_id(&conversation_id).await {
        let conversation = crate::domain::model::conversation::Conversation {
            conversation_id: conv.conversation_id,
            conversation_type: conv.conversation_type,
            user_id: conv.user_id,
            group_id: conv.group_id,
            show_name: conv.show_name,
            face_url: conv.face_url,
            latest_msg: conv.latest_msg,
            latest_msg_send_time: conv.latest_msg_send_time,
            unread_count: conv.unread_count,
            recv_msg_opt: conv.recv_msg_opt,
            is_pinned: conv.is_pinned != 0,
            is_private_chat: conv.is_private_chat != 0,
            burn_duration: conv.burn_duration as i32,
            group_at_type: conv.group_at_type,
            is_not_in_group: conv.is_not_in_group != 0,
            update_unread_count_time: conv.update_unread_count_time,
            latest_msg_seq: conv.max_seq,
            max_seq: conv.max_seq,
            min_seq: conv.min_seq,
            is_msg_destruct: conv.is_msg_destruct != 0,
            msg_destruct_time: conv.msg_destruct_time,
            draft_text: conv.draft_text,
            draft_text_time: conv.draft_text_time,
            update_flag: 0,
            sync_action: None,
            is_private: conv.is_private_chat != 0,
            ex: conv.ex,
        };
        context.event_bus.publish(SdkEvent::ConversationChanged {
            conversations: vec![conversation],
        });
    }

    Ok(())
}

/// 执行消息发送的核心逻辑（独立函数版本，供队列调用）
#[tracing::instrument(skip_all)]
async fn do_send_message_impl(
    context: Arc<RuntimeContext>,
    connection: Arc<ConnectionManager>,
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

    let resp: UserSendMsgResp = match connection.send_rpc::<MsgData, UserSendMsgResp>(1003, &msg_data).await {
        Ok(r) => {
            info!("[SendMsg] 完成: client_msg_id={}, server_msg_id={}, elapsed={}ms",
                r.client_msg_id, r.server_msg_id, start.elapsed().as_millis());
            r
        }
        Err(e) => {
            if !online_only {
                // 网络超时二次确认（对齐 Go SDK api.go L682-698）
                if let SdkError::Timeout { .. } = &e {
                    if let Ok(Some(old_msg)) = context.message_dao
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
                context.message_dao.update_send_status(&msg.client_msg_id, MessageSendStatus::SendFailed).await?;
                context.event_bus.publish(SdkEvent::MessageSendFailed {
                    client_msg_id: msg.client_msg_id.clone(),
                    error: format!("{}", e),
                });
            }
            return Err(SdkError::message_send(format!("send message via ws failed: {}", e)));
        }
    };

    // isOnlineOnly: 跳过本地状态更新和会话触发（对齐 Go SDK api.go L154-157）
    if !online_only {
        if let Err(e) = context.message_dao.update_after_send_success(&msg.client_msg_id, &resp.server_msg_id, resp.send_time).await {
            error!("更新发送结果失败: {}", e);
        }

        // 发送成功，从 sending_messages 中移除（对齐 Go SDK api.go L167）
        if let Err(e) = context.sending_message_dao.delete(&conversation_id, &msg.client_msg_id).await {
            debug!("删除sending_message失败: {}", e);
        }

        // 对齐 Go SDK：消息发送结果仅通过返回值（Message）传递，不发布事件
    }

    Ok(resp)
}

impl OpenIMClient {
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

    async fn send_msg_inner(&self, mut msg: MsgStruct, source_id: &str, offline_push_info: Option<OfflinePushInfo>, online_only: bool) -> std::result::Result<MsgStruct, SdkError> {
        let send_id = self.context.user_id.lock().unwrap().clone();
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
            if let Ok(Some(old_msg)) = self.context.message_dao.get_by_client_msg_id(&conversation_id, &msg.client_msg_id).await {
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

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_text_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_text_message(text);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_markdown_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_markdown_message(text);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_advanced_text_message(&self, text: &str, entities: Vec<crate::domain::model::msg_struct::MessageEntity>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_advanced_text_message(text, entities);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_image_message(&self, file_path: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let upload_result = self.file_uploader.upload_image(file_path, None).await
            .map_err(|e| SdkError::message_send(format!("upload image failed: {}", e)))?;
        let source = crate::domain::model::msg_struct::PictureBaseInfo {
            width: 0, height: 0, picture_type: String::new(),
            size: upload_result.size as i64, url: upload_result.url, uuid: String::new(),
        };
        let mut msg = MsgStruct::create_image_message(
            file_path, source,
            crate::domain::model::msg_struct::PictureBaseInfo::default(),
            crate::domain::model::msg_struct::PictureBaseInfo::default(),
        );
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_image_message_with_progress(&self, file_path: &str, source_id: &str, session_type: i32, progress: &ProgressCallback) -> std::result::Result<MsgStruct, SdkError> {
        let upload_result = self.file_uploader.upload_image(file_path, Some(progress.clone())).await
            .map_err(|e| SdkError::message_send(format!("upload image failed: {}", e)))?;
        let source = crate::domain::model::msg_struct::PictureBaseInfo {
            width: 0, height: 0, picture_type: String::new(),
            size: upload_result.size as i64, url: upload_result.url, uuid: String::new(),
        };
        let mut msg = MsgStruct::create_image_message(
            file_path, source,
            crate::domain::model::msg_struct::PictureBaseInfo::default(),
            crate::domain::model::msg_struct::PictureBaseInfo::default(),
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
        let file_elem = crate::domain::model::msg_struct::FileElem {
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
        let file_elem = crate::domain::model::msg_struct::FileElem {
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
        let sound_elem = crate::domain::model::msg_struct::SoundElem {
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
        let sound_elem = crate::domain::model::msg_struct::SoundElem {
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

        let video_elem = crate::domain::model::msg_struct::VideoElem {
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

        let video_elem = crate::domain::model::msg_struct::VideoElem {
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

    /// 发送 @ 消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_at_text_message(&self, text: &str, at_user_ids: Vec<String>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let at_users_info: Vec<crate::domain::model::msg_struct::AtInfo> = at_user_ids.iter().map(|uid| {
            crate::domain::model::msg_struct::AtInfo {
                at_user_id: uid.clone(),
                group_nickname: String::new(),
            }
        }).collect();
        let mut msg = MsgStruct::create_at_text_message(text, at_user_ids, at_users_info, None);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 发送自定义消息
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_custom_message(&self, data: &str, desc: &str, extension: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_custom_message(data, desc, extension);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 发送引用消息（对齐 Go SDK `CreateQuoteMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_quote_message(&self, text: &str, quote: crate::domain::model::msg_struct::MsgStruct, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_quote_message(text, Box::new(quote));
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 发送合并转发消息（对齐 Go SDK `CreateMergerMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_merger_message(&self, title: &str, summary_list: Vec<String>, context_list: Vec<MsgStruct>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_merger_message(context_list, title, summary_list);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 发送名片消息（对齐 Go SDK `CreateCardMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_card_message(&self, user_id: &str, nickname: &str, face_url: &str, ex: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let elem = crate::domain::model::msg_struct::CardElem {
            user_id: user_id.to_string(),
            nickname: nickname.to_string(),
            face_url: face_url.to_string(),
            ex: ex.to_string(),
        };
        let mut msg = MsgStruct::create_card_message(elem);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 发送位置消息（对齐 Go SDK `CreateLocationMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_location_message(&self, description: &str, longitude: f64, latitude: f64, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_location_message(description, longitude, latitude);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 发送表情消息（对齐 Go SDK `CreateFaceMessage` + `SendMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_face_message(&self, index: i32, data: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_face_message(index, data);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 转发消息（对齐 Go SDK `ForwardMessage`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn forward_message(&self, mut msg_struct: MsgStruct, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        msg_struct.session_type = session_type;
        self.send_msg(msg_struct, source_id, None).await
    }

    /// 从 URL 创建图片消息（对齐 Go SDK `CreateImageMessage(sourcePath="")`）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_image_message_from_url(&self, source_url: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let picture = crate::domain::model::msg_struct::PictureBaseInfo {
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
        let elem = crate::domain::model::msg_struct::SoundElem {
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
        let elem = crate::domain::model::msg_struct::VideoElem {
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
        let elem = crate::domain::model::msg_struct::FileElem {
            source_url: source_url.to_string(),
            file_name: file_name.to_string(),
            file_size,
            ..Default::default()
        };
        let mut msg = MsgStruct::create_file_message(elem);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    /// 发送分段 @ 消息（对齐 Go SDK `CreateAtTextMessage` 带 quote_msg）
    #[tracing::instrument(skip_all, fields(source_id = %source_id, session_type = %session_type))]
    pub async fn send_at_text_message_with_quote(&self, text: &str, at_user_list: Vec<String>, at_users_info: Vec<crate::domain::model::msg_struct::AtInfo>, quote_msg: Option<Box<MsgStruct>>, source_id: &str, session_type: i32) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_at_text_message(text, at_user_list, at_users_info, quote_msg);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %req.conversation_id, count = %req.count))]
    pub async fn get_history_messages(&self, req: GetHistoryMessagesReq) -> std::result::Result<GetHistoryMessagesResult, SdkError> {

        let start_time = if req.start_client_msg_id.is_empty() {
            0
        } else {
            let msg = self.message_handler.message_dao()
                .get_by_client_msg_id(&req.conversation_id, &req.start_client_msg_id)
                .await?;
            let st = msg.as_ref().map(|m| m.send_time).unwrap_or(0);
            info!("通过 client_msg_id 查询到 send_time={}", st);
            st
        };

        let messages = self.message_handler.message_dao()
            .get_by_conversation(&req.conversation_id, start_time, req.count)
            .await?;

        let is_end = messages.len() < req.count as usize;

        let msg_info_list: Vec<MessageInfo> = messages.into_iter()
            .rev()
            .map(|m| {
                let msg_struct = MsgStruct::from(&m);
                MessageInfo::from(MsgData::from(&msg_struct))
            })
            .collect();

        Ok(GetHistoryMessagesResult {
            messages: msg_info_list,
            is_end,
        })
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %req.conversation_id, seq = %req.seq))]
    pub async fn revoke_message(&self, req: RevokeMessageReq) -> Result<()> {
        self.message_service.revoke_message(
            req.conversation_id,
            req.seq,
            req.client_msg_id,
            req.session_type,
        ).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %req.conversation_id))]
    pub async fn delete_messages(&self, req: DeleteMessagesReq) -> Result<()> {
        self.message_service.delete_messages(
            req.conversation_id,
            req.client_msg_ids,
        ).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %req.conversation_id))]
    pub async fn mark_messages_as_read(&self, req: MarkMessagesAsReadReq) -> Result<()> {
        self.message_service.mark_messages_as_read(
            req.conversation_id,
            req.session_type,
            req.has_read_seq,
            req.seqs,
        ).await
    }

    #[tracing::instrument(skip_all, fields(conversation_id = %req.conversation_id, keyword = %req.keyword))]
    pub async fn search_local_messages(&self, req: SearchMessagesReq) -> std::result::Result<Vec<LocalChatLog>, SdkError> {
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
    pub async fn send_typing(&self, source_id: &str, session_type: i32, focus: bool) -> std::result::Result<UserSendMsgResp, SdkError> {
        let send_id = self.context.user_id.lock().unwrap().clone();
        let platform_id = self.context.config.platform_id;
        let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as i64;

        let msg_tips = if focus { "yes" } else { "no" };
        let mut msg = MsgStruct::create_typing_message(msg_tips);
        msg.send_id = send_id;
        msg.sender_platform_id = platform_id;
        msg.client_msg_id = crate::domain::model::msg_struct::get_msg_id(&msg.send_id);
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
            crate::domain::constant::types::ws_req_identifier::SEND_MSG,
            &msg_data,
        ).await?;

        info!("[Typing] 响应: client_msg_id={}, server_msg_id={}, send_time={}",
            resp.client_msg_id, resp.server_msg_id, resp.send_time);
        Ok(resp)
    }

    // ========== 第一批测试所需的查询/删除方法 ==========

    /// 倒序获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageListReverse`）
    ///
    /// 从 start_client_msg_id 之前的消息开始，倒序获取 count 条。
    /// start_client_msg_id 为空时从最新消息开始。
    pub async fn get_history_messages_reverse(
        &self,
        conversation_id: &str,
        start_client_msg_id: &str,
        count: i64,
    ) -> std::result::Result<GetHistoryMessagesResult, SdkError> {
        let start_time = if start_client_msg_id.is_empty() {
            0
        } else {
            let msg = self.context.message_dao
                .get_by_client_msg_id(conversation_id, start_client_msg_id)
                .await?;
            msg.as_ref().map(|m| m.send_time).unwrap_or(0)
        };

        let messages = self.context.message_dao
            .get_by_conversation_asc(conversation_id, start_time, count + 1)
            .await?;

        // 倒序排列
        let mut messages: Vec<LocalChatLog> = messages.into_iter().rev().collect();

        let is_end = messages.len() <= count as usize;
        if !is_end {
            messages.truncate(count as usize);
        }

        let msg_info_list: Vec<MessageInfo> = messages.into_iter()
            .map(|m| {
                let msg_struct = MsgStruct::from(&m);
                MessageInfo::from(MsgData::from(&msg_struct))
            })
            .collect();

        let result = GetHistoryMessagesResult {
            messages: msg_info_list,
            is_end,
        };
        Ok(result)
    }

    /// 按 seq 范围获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageList` 中的 seq 范围查询）
    pub async fn get_advanced_history_message_list_by_seq(
        &self,
        conversation_id: &str,
        start_seq: i64,
        end_seq: i64,
        count: i32,
    ) -> std::result::Result<Vec<LocalChatLog>, SdkError> {
        let rows = self.context.message_dao
            .get_by_seq_range(conversation_id, start_seq, end_seq, count as i64)
            .await?;
        Ok(rows)
    }

    /// 按 seq 获取单条消息（对齐 Go SDK `GetMessageBySeq`）
    pub async fn get_history_message_by_seq(
        &self,
        seq: i64,
    ) -> std::result::Result<LocalChatLog, SdkError> {
        self.context.message_dao.get_by_seq(seq).await?
            .ok_or_else(|| SdkError::invalid_argument(format!("seq={} 的消息不存在", seq)))
    }

    /// 按 clientMsgId 列表批量查找消息（对齐 Go SDK `FindMessageList`）
    pub async fn find_message_list(
        &self,
        conversation_id: &str,
        client_msg_ids: Vec<String>,
    ) -> std::result::Result<Vec<LocalChatLog>, SdkError> {
        if client_msg_ids.is_empty() {
            return Ok(Vec::new());
        }
        // 按 conversation_id 过滤
        let all = self.context.message_dao
            .get_by_client_msg_ids(&client_msg_ids)
            .await?;
        Ok(all.into_iter()
            .filter(|m| m.conversation_id == conversation_id)
            .collect())
    }

    /// 仅从本地删除单条消息（对齐 Go SDK `DeleteMessageFromLocalStorage`）
    ///
    /// 软删除：将消息状态标记为 MsgStatusHasDeleted(4)，不通知服务端。
    pub async fn delete_message_from_local_storage(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
    ) -> std::result::Result<(), SdkError> {
        self.context.message_dao
            .mark_as_deleted(conversation_id, client_msg_id).await?;
        debug!("本地删除消息: conversation_id={}, client_msg_id={}", conversation_id, client_msg_id);
        Ok(())
    }

    /// 清空会话并删除所有消息（对齐 Go SDK `ClearConversationAndDeleteAllMsg`）
    ///
    /// 删除服务端+本地该会话的所有消息，会话本身保留。
    pub async fn clear_conversation_and_delete_all_msg(
        &self,
        conversation_id: &str,
    ) -> std::result::Result<(), SdkError> {
        // TODO: 调用服务端删除 API（delete_msg）

        // 删除本地消息
        self.context.message_dao.delete_by_conversation(conversation_id).await?;

        // 重置会话的最新消息和未读数
        if let Ok(Some(mut conv)) = self.context.conversation_dao.get_by_id(conversation_id).await {
            conv.latest_msg = String::new();
            conv.latest_msg_send_time = 0;
            conv.unread_count = 0;
            conv.max_seq = 0;
            conv.min_seq = 0;
            let _ = self.context.conversation_dao.upsert(&conv).await;
        }

        info!("清空会话消息: conversation_id={}", conversation_id);
        Ok(())
    }

    /// 删除会话并删除所有消息（对齐 Go SDK `DeleteConversationAndDeleteAllMsg`）
    ///
    /// 删除服务端+本地该会话的所有消息，并删除会话本身。
    pub async fn delete_conversation_and_delete_all_msg(
        &self,
        conversation_id: &str,
    ) -> std::result::Result<(), SdkError> {
        // 先清空消息
        self.clear_conversation_and_delete_all_msg(conversation_id).await?;

        // 删除会话
        self.context.conversation_dao.delete(conversation_id).await?;
        self.conversation.delete_conversation(conversation_id).await?;

        info!("删除会话及所有消息: conversation_id={}", conversation_id);
        Ok(())
    }

    /// 删除所有消息（本地+服务端）（对齐 Go SDK `DeleteAllMsgFromLocalAndSvr`）
    pub async fn delete_all_msg_from_local_and_svr(
        &self,
    ) -> std::result::Result<(), SdkError> {
        // TODO: 调用服务端删除 API（delete_all_msg）

        // 删除本地所有消息
        self.context.message_dao.delete_all().await?;

        info!("删除所有消息（本地+服务端）");
        Ok(())
    }

    /// 仅从本地删除所有消息（对齐 Go SDK `DeleteAllMsgFromLocal`）
    pub async fn delete_all_msg_from_local(
        &self,
    ) -> std::result::Result<(), SdkError> {
        self.context.message_dao.mark_all_as_deleted().await?;
        info!("本地软删除所有消息");
        Ok(())
    }

    /// 获取所有会话的总未读消息数（对齐 Go SDK `GetTotalUnreadMsgCount`）
    pub async fn get_total_unread_msg_count(
        &self,
    ) -> std::result::Result<i64, SdkError> {
        let convs = self.context.conversation_dao.get_all().await?;
        let total: i64 = convs.iter().map(|c| c.unread_count as i64).sum();
        Ok(total)
    }

    /// 设置消息本地扩展字段（对齐 Go SDK `SetMessageLocalEx`）
    pub async fn set_message_local_ex(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
        local_ex: &str,
    ) -> std::result::Result<(), SdkError> {
        self.context.message_dao
            .update_local_ex(conversation_id, client_msg_id, local_ex).await?;
        Ok(())
    }

    /// 登录时清理发送中的消息（对齐 Go SDK userRelated.go L332-375）
    pub async fn cleanup_sending_messages(&self) {
        let sending_messages = match self.context.sending_message_dao.get_all().await {
            Ok(msgs) => msgs,
            Err(e) => {
                warn!("获取sending_messages失败: {}", e);
                return;
            }
        };

        for sm in &sending_messages {
            // 查询消息当前状态
            if let Ok(Some(msg)) = self.context.message_dao
                .get_by_client_msg_id(&sm.conversation_id, &sm.client_msg_id).await
            {
                if msg.status == MessageSendStatus::Sending as i32 {
                    // 状态仍为 Sending → 标记为 SendFailed
                    if let Err(e) = self.context.message_dao
                        .update_send_status(&sm.client_msg_id, MessageSendStatus::SendFailed).await
                    {
                        warn!("更新sending消息状态失败: client_msg_id={}, err={}", sm.client_msg_id, e);
                    }
                }
            }
            // 删除 sending_message 记录
            let _ = self.context.sending_message_dao
                .delete(&sm.conversation_id, &sm.client_msg_id).await;
        }

        if !sending_messages.is_empty() {
            info!("登录时清理了 {} 条sending消息", sending_messages.len());
        }
    }

    /// 发送高级引用消息（对齐 Go SDK `CreateAdvancedQuoteMessage` + `SendMessage`）
    ///
    /// 与 `send_quote_message` 的区别：额外支持 `message_entities` 参数，
    /// 可以为引用消息的文本添加实体（如 @提及、链接等富文本）。
    pub async fn send_advanced_quote_message(
        &self,
        text: &str,
        quote: crate::domain::model::msg_struct::MsgStruct,
        message_entities: Vec<crate::domain::model::msg_struct::MessageEntity>,
        source_id: &str,
        session_type: i32,
    ) -> std::result::Result<MsgStruct, SdkError> {
        let mut msg = MsgStruct::create_advanced_quote_message(
            text,
            Box::new(quote),
            message_entities,
        );
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
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
        let original = self.context.message_dao
            .get_by_client_msg_id(conversation_id, client_msg_id)
            .await?
            .ok_or_else(|| SdkError::invalid_argument(format!("消息不存在: client_msg_id={}", client_msg_id)))?;

        // 构造编辑后的消息结构
        let mut msg = MsgStruct::new();
        msg.content_type = content_type;
        msg.content = content.to_string();
        msg.msg_from = crate::domain::model::msg_struct::MSG_FROM_USER;

        // 从 content 恢复 typed elem
        match content_type {
            101 => {
                if let Ok(elem) = serde_json::from_str::<crate::domain::model::msg_struct::TextElem>(content) {
                    msg.text_elem = Some(elem);
                }
            }
            117 => {
                if let Ok(elem) = serde_json::from_str::<crate::domain::model::msg_struct::AdvancedTextElem>(content) {
                    msg.advanced_text_elem = Some(elem);
                }
            }
            118 => {
                if let Ok(elem) = serde_json::from_str::<crate::domain::model::msg_struct::MarkdownTextElem>(content) {
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
            if original.recv_id == self.context.user_id.lock().unwrap().clone() {
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
}
