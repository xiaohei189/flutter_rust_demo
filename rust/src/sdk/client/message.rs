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
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};
use tracing::{info, error, debug, warn};
use serde_json::{json, Value};

impl OpenIMClient {
    pub async fn send_msg(&self, mut msg: MsgStruct, source_id: &str, offline_push_info: Option<OfflinePushInfo>) -> std::result::Result<MsgData, SdkError> {
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

        if msg.session_type == 1 {
            msg.recv_id = source_id.to_string();
        } else {
            msg.group_id = source_id.to_string();
        }

        // 发送前去重（对齐 Go SDK api.go L293-321）
        let conversation_id = self.conversation_id_for_msg(&msg);
        if let Ok(Some(old_msg)) = self.context.message_dao.get_by_client_msg_id(&conversation_id, &msg.client_msg_id).await {
            if old_msg.status != MessageSendStatus::SendFailed as i32 {
                return Err(SdkError::msg_repeated("Only failed messages can be resent"));
            }
            // 失败重试：允许继续发送
        }

        let resp = self.do_send_message(msg.clone(), offline_push_info).await?;

        let mut result = MsgData::from(&msg);
        result.server_msg_id = resp.server_msg_id;
        result.send_time = resp.send_time;
        result.status = 2;
        Ok(result)
    }

    async fn do_send_message(&self, msg: MsgStruct, offline_push_info: Option<OfflinePushInfo>) -> std::result::Result<UserSendMsgResp, SdkError> {
        let send_time = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        let content = self.process_media_content(&msg).await?;

        self.insert_message_before_send(&msg, send_time).await?;

        let mut msg_data = MsgData::from(&msg);
        msg_data.content = content.into_bytes();
        msg_data.send_time = send_time;
        msg_data.create_time = send_time;
        msg_data.offline_push_info = offline_push_info;

        let conversation_id = self.conversation_id_for_msg(&msg);

        let resp: UserSendMsgResp = match self.connection.send_rpc(1003, &msg_data).await {
            Ok(r) => r,
            Err(e) => {
                // 网络超时二次确认（对齐 Go SDK api.go L682-698）
                if let SdkError::Timeout { .. } = &e {
                    if let Ok(Some(old_msg)) = self.context.message_dao
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
                self.context.message_dao.update_send_status(&msg.client_msg_id, MessageSendStatus::SendFailed).await?;
                self.event_bus.publish(SdkEvent::MessageSendFailed {
                    client_msg_id: msg.client_msg_id.clone(),
                    error: format!("{}", e),
                });
                return Err(SdkError::message_send(format!("send message via ws failed: {}", e)));
            }
        };

        if let Err(e) = self.context.message_dao.update_after_send_success(&msg.client_msg_id, &resp.server_msg_id, resp.send_time).await {
            error!("更新发送结果失败: {}", e);
        }

        // 发送成功，从 sending_messages 中移除（对齐 Go SDK api.go L167）
        if let Err(e) = self.context.sending_message_dao.delete(&conversation_id, &msg.client_msg_id).await {
            debug!("删除sending_message失败: {}", e);
        }

        self.event_bus.publish(SdkEvent::MessageSent {
            client_msg_id: resp.client_msg_id.clone(),
            server_msg_id: resp.server_msg_id.clone(),
            send_time: resp.send_time,
            status: 2,
            conversation_id,
            send_id: msg.send_id.clone(),
            recv_id: msg.recv_id.clone(),
            group_id: msg.group_id.clone(),
            session_type: msg.session_type,
            content_type: msg.content_type,
            content: msg.content.clone(),
            sender_nickname: msg.sender_nickname.clone(),
            sender_face_url: msg.sender_face_url.clone(),
        });

        Ok(resp)
    }

    fn conversation_id_for_msg(&self, msg: &MsgStruct) -> String {
        if msg.session_type == 1 {
            let mut ids = vec![msg.send_id.clone(), msg.recv_id.clone()];
            ids.sort();
            format!("si_{}_{}", ids[0], ids[1])
        } else {
            format!("g_{}", msg.group_id)
        }
    }

    async fn insert_message_before_send(&self, msg: &MsgStruct, send_time: i64) -> Result<()> {
        let conversation_id = self.conversation_id_for_msg(msg);

        let mut local_log = LocalChatLog::from(msg);
        local_log.conversation_id = conversation_id.clone();
        local_log.send_time = send_time;
        local_log.create_time = send_time;
        local_log.status = MessageSendStatus::Sending as i32;

        self.context.message_dao.batch_insert(&[local_log]).await?;
        self.context.sending_message_dao.insert(&LocalSendingMessage {
            conversation_id: conversation_id.clone(),
            client_msg_id: msg.client_msg_id.clone(),
            ex: String::new(),
        }).await?;
        self.context.conversation_dao.update_after_sent_message(
            &conversation_id,
            &msg.content,
            send_time,
        ).await?;

        // 会话乐观更新（对齐 Go SDK api.go L322-324）
        if let Ok(Some(conv)) = self.context.conversation_dao.get_by_id(&conversation_id).await {
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
            self.event_bus.publish(SdkEvent::ConversationChanged {
                conversations: vec![conversation],
            });
        }

        debug!("发送前插入消息: client_msg_id={}, conv={}", msg.client_msg_id, conversation_id);
        Ok(())
    }

    async fn process_media_content(&self, msg: &MsgStruct) -> std::result::Result<String, SdkError> {
        let media_types = [102, 103, 104, 105];
        if !media_types.contains(&msg.content_type) {
            return Ok(msg.content.clone());
        }

        let mut value: Value = match serde_json::from_str(&msg.content) {
            Ok(v) => v,
            Err(_) => return Ok(msg.content.clone()),
        };

        let source_path = match value.get("sourcePath").and_then(|v| v.as_str()) {
            Some(p) => p.to_string(),
            None => return Ok(msg.content.clone()),
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

        let upload_result = self.file_uploader.upload_file(&source_path, &file_name, None).await?;
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

    pub async fn send_text_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
        let mut msg = MsgStruct::create_text_message(text);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    pub async fn send_markdown_message(&self, text: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
        let mut msg = MsgStruct::create_markdown_message(text);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    pub async fn send_advanced_text_message(&self, text: &str, entities: Vec<crate::domain::model::msg_struct::MessageEntity>, source_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
        let mut msg = MsgStruct::create_advanced_text_message(text, entities);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    pub async fn send_image_message(&self, file_path: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
        let upload_result = self.file_uploader.upload_image(file_path).await
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

    pub async fn send_file_message(&self, file_path: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
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

    /// 发送语音消息
    pub async fn send_sound_message(&self, file_path: &str, source_id: &str, session_type: i32, duration: i64) -> std::result::Result<MsgData, SdkError> {
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

    /// 发送视频消息
    pub async fn send_video_message(&self, video_path: &str, snapshot_path: &str, source_id: &str, session_type: i32, duration: i64) -> std::result::Result<MsgData, SdkError> {
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

    /// 发送 @ 消息
    pub async fn send_at_text_message(&self, text: &str, at_user_ids: Vec<String>, source_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
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
    pub async fn send_custom_message(&self, data: &str, desc: &str, extension: &str, source_id: &str, session_type: i32) -> std::result::Result<MsgData, SdkError> {
        let mut msg = MsgStruct::create_custom_message(data, desc, extension);
        msg.session_type = session_type;
        self.send_msg(msg, source_id, None).await
    }

    pub async fn get_history_messages(&self, req: GetHistoryMessagesReq) -> std::result::Result<GetHistoryMessagesResult, SdkError> {
        info!("get_history_messages: conversation_id={}, start_client_msg_id={}, count={}",
              req.conversation_id, req.start_client_msg_id, req.count);

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

        info!("数据库查询返回 {} 条消息", messages.len());

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

    pub async fn revoke_message(&self, req: RevokeMessageReq) -> Result<()> {
        self.message_service.revoke_message(
            req.conversation_id,
            req.seq,
            req.client_msg_id,
            req.session_type,
        ).await
    }

    pub async fn delete_messages(&self, req: DeleteMessagesReq) -> Result<()> {
        self.message_service.delete_messages(
            req.conversation_id,
            req.client_msg_ids,
        ).await
    }

    pub async fn mark_messages_as_read(&self, req: MarkMessagesAsReadReq) -> Result<()> {
        self.message_service.mark_messages_as_read(
            req.conversation_id,
            req.session_type,
            req.has_read_seq,
            req.seqs,
        ).await
    }

    pub async fn search_local_messages(&self, req: SearchMessagesReq) -> std::result::Result<Vec<LocalChatLog>, SdkError> {
        self.message_service.search_local_messages(
            req.conversation_id,
            req.keyword,
            100,
        ).await
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
}
