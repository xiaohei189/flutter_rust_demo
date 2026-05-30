//! IM 客户端 Flutter 桥接层
//!
//! 按 flutter_rust_bridge_codegen 要求将 IMClient 暴露为 Flutter API。
//! 使用 RustOpaque 包装 IMClient，通过 #[frb] 注解暴露方法。
//!
//! 热重启：Flutter 在 initialize 前调用 close_current_client_if_any() 关闭旧连接，
//! 避免同 token 重复连接导致 TokenKickedError(1506)。
//!
//! 消息流程：先通过 create_* 创建消息（得到 MsgData），设置 recv_id/group_id/session_type 后，
//! 再调用 send_message(msg) 发送已创建的消息。
//!
//! 状态/会话/消息订阅：conn_stream、conversation_stream、advanced_msg_stream 需在 connect 前调用；
//! 修改本文件后请执行 `dart run flutter_rust_bridge_codegen generate` 以生成 ConnEvent 等类型的 SseEncode。

use crate::im::client::client::{ClientConfig, IMClient};
use crate::im::client::listeners::{AdvancedMsgEvent, ConnEvent, ConversationEvent};
use crate::im::http_client::auth::LoginData;
use crate::im::model::conversation::LocalConversation;
use crate::im::model::message::{
    GetAdvancedHistoryMessageListCallback, GetAdvancedHistoryMessageListParams,
};
use anyhow::Result;
use crate::frb_generated::StreamSink;
use openim_protocol::sdkws::MsgData;
use std::sync::Arc;
use std::sync::Mutex;
pub use tokio::sync::RwLock;
use tokio_stream::StreamExt;
use tracing;
use serde::{Deserialize, Serialize};

/// 热重启时由 Flutter 在创建新 client 前调用，关闭上一次的 client，避免 token 重复使用
static CURRENT_CLIENT_INNER: Mutex<Option<Arc<RwLock<IMClient>>>> = Mutex::new(None);

/// 获取当前客户端实例（供其他模块使用）
pub async fn get_current_client() -> Result<Arc<RwLock<IMClient>>> {
    let guard = CURRENT_CLIENT_INNER.lock().map_err(|e| anyhow::anyhow!("lock error: {}", e))?;
    guard.as_ref().cloned().ok_or_else(|| anyhow::anyhow!("client not initialized"))
}

/// 关闭当前保存的 client（若有）。Flutter 热重启后、再次 initialize 前调用。
#[flutter_rust_bridge::frb]
pub async fn close_current_client_if_any() -> Result<()> {
    let prev = CURRENT_CLIENT_INNER.lock().unwrap().take();
    if let Some(inner) = prev {
        inner.read().await.stop();
    }
    Ok(())
}

/// 登录接口
///
/// 参考 openim-cli 的实现，先登录获取 token 信息
#[flutter_rust_bridge::frb]
pub async fn login_async(
    area_code: String,
    phone_number: String,
    password: String,
    platform: i32,
) -> Result<LoginData> {
    crate::im::http_client::auth::login_async(area_code, phone_number, password, platform).await
}

/// 用户资料（Bridge 暴露给 Dart 的统一结构）
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserProfile {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    #[serde(default)]
    pub ex: String,
    #[serde(default)]
    pub attached_info: String,
    #[serde(default)]
    pub global_recv_msg_opt: i32,
    #[serde(default)]
    pub create_time: i64,
    #[serde(default)]
    pub app_manger_level: i32,
}

/// 用户资料更新补丁（仅更新传入字段）
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserProfilePatch {
    pub nickname: Option<String>,
    #[serde(rename = "faceURL")]
    pub face_url: Option<String>,
    pub ex: Option<String>,
    pub global_recv_msg_opt: Option<i32>,
}

impl From<crate::im::http_client::user::UserInfoItem> for UserProfile {
    fn from(v: crate::im::http_client::user::UserInfoItem) -> Self {
        Self {
            user_id: v.user_id,
            nickname: v.nickname,
            face_url: v.face_url,
            ex: v.ex,
            attached_info: v.attached_info,
            global_recv_msg_opt: v.global_recv_msg_opt,
            create_time: v.create_time,
            app_manger_level: v.app_manger_level,
        }
    }
}

/// OpenIM 桥接客户端，包装 IMClient 供 Flutter 使用
///
/// 使用 #[frb(opaque)] 使该结构体在 Dart 端为不透明句柄，
/// 仅能通过暴露的方法进行操作。
#[flutter_rust_bridge::frb(opaque)]
pub struct OpenIMBridgeClient {
    inner: Arc<RwLock<IMClient>>,
}

impl OpenIMBridgeClient {
    /// 创建新的客户端实例
    ///
    /// # 参数
    /// - `user_id`: 用户 ID
    /// - `token`: 认证 token（从登录接口获取）
    /// - `platform_id`: 平台 ID（例如：5 表示 Web）
    /// - `ws_url`: WebSocket 服务器 URL（可选，默认使用 localhost:10001）
    /// - `api_base_url`: HTTP API 基础地址（可选，默认 localhost:10002；Android 等可传单独地址）
    #[flutter_rust_bridge::frb]
    pub async fn new(
        user_id: String,
        token: String,
        platform_id: i32,
        ws_url: Option<String>,
        api_base_url: Option<String>,
    ) -> Result<Self> {
        let config = ClientConfig::new(user_id, token, platform_id, ws_url, api_base_url, None);
        // TODO: 旧代码待删除，重构后使用新的 SDK 初始化逻辑
        // config.conversation_db_url = format!(
        //     "sqlite://{}/conversations_{}.db?mode=rwc",
        //     std::env::temp_dir().as_path().to_string_lossy(),
        //     config.user_id
        // );
        // let client = IMClient::new(config).await?;
        // let inner = Arc::new(RwLock::new(client));
        // *CURRENT_CLIENT_INNER.lock().unwrap() = Some(inner.clone());
        unimplemented!("旧 FFI 桥接代码待重构")
    }

    /// 关闭当前实例（停止 WebSocket 与同步任务），由 Flutter 在断开/重启前调用
    #[flutter_rust_bridge::frb]
    pub async fn close(&self) -> Result<()> {
        self.inner.read().await.stop();
        Ok(())
    }

    /// 连接状态事件流。需在 connect() 之前调用；Dart 端得到 Stream<ConnEvent> 并 listen。
    #[flutter_rust_bridge::frb]
    pub async fn conn_stream(&self, sink: StreamSink<ConnEvent>) -> Result<()> {
        let stream = self.inner.write().await.subscribe_conn_events();
        tokio::spawn(async move {
            let mut stream = stream;
            while let Some(ev) = stream.next().await {
                let _ = sink.add(ev);
            }
        });
        Ok(())
    }

    /// 会话变动事件流。需在 connect() 之前调用；Dart 端得到 Stream<ConversationEvent> 并 listen。
    #[flutter_rust_bridge::frb]
    pub async fn conversation_stream(&self, sink: StreamSink<ConversationEvent>) -> Result<()> {
        let stream = self.inner.write().await.subscribe_conversation_events();
        tokio::spawn(async move {
            let mut stream = stream;
            while let Some(ev) = stream.next().await {
                let _ = sink.add(ev);
            }
        });
        Ok(())
    }

    /// 消息变动事件流。需在 connect() 之前调用；Dart 端得到 Stream<AdvancedMsgEvent> 并 listen。
    #[flutter_rust_bridge::frb]
    pub async fn advanced_msg_stream(&self, sink: StreamSink<AdvancedMsgEvent>) -> Result<()> {
        let stream = self.inner.write().await.subscribe_advanced_msg_events();
        tokio::spawn(async move {
            let mut stream = stream;
            while let Some(ev) = stream.next().await {
                if let Err(e) = sink.add(ev) {
                    tracing::error!("[bridge] advanced_msg_stream sink.add 失败: {:?}", e);
                }
            }
            tracing::warn!("[bridge] advanced_msg_stream 循环退出（rx 已关闭）");
        });
        Ok(())
    }

    /// 连接到服务器
    ///
    /// 建立 WebSocket 连接并启动消息监听。
    #[flutter_rust_bridge::frb]
    pub async fn connect(&self) -> Result<()> {
        self.inner.write().await.start().await
    }

    /// 获取所有会话列表
    #[flutter_rust_bridge::frb]
    pub async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        self.inner.read().await.get_all_conversations().await
    }

    /// 获取高级历史消息列表（完全参考 Go SDK 的 GetAdvancedHistoryMessageList）
    #[flutter_rust_bridge::frb]
    pub async fn get_advanced_history_message_list(
        &self,
        req: GetAdvancedHistoryMessageListParams,
    ) -> Result<GetAdvancedHistoryMessageListCallback> {
        self.inner
            .read()
            .await
            .get_advanced_history_message_list(req)
            .await
    }

    /// 获取高级历史消息列表（反向，完全参考 Go SDK 的 GetAdvancedHistoryMessageListReverse）
    #[flutter_rust_bridge::frb]
    pub async fn get_advanced_history_message_list_reverse(
        &self,
        req: GetAdvancedHistoryMessageListParams,
    ) -> Result<GetAdvancedHistoryMessageListCallback> {
        self.inner
            .read()
            .await
            .get_advanced_history_message_list_reverse(req)
            .await
    }

    // ---------- 创建消息（仅组包，不发送；发送前需设置 recv_id/group_id、session_type 后调用 send_message） ----------

    /// 创建文本消息（已填入 recv_id/group_id/session_type），返回 MsgData 可直接送 send_message 发送。
    #[flutter_rust_bridge::frb]
    pub async fn create_text_message(
        &self,
        text: String,
        recv_id: String,
        group_id: String,
        session_type: i32,
    ) -> Result<MsgData> {
        let client = self.inner.read().await;
        Ok(client.create_text_message(&text, &recv_id, &group_id, session_type))
    }

    /// 创建自定义消息。
    #[flutter_rust_bridge::frb]
    pub async fn create_custom_message(
        &self,
        data: String,
        extension: String,
        description: String,
    ) -> Result<MsgData> {
        let client = self.inner.read().await;
        Ok(client.create_custom_message(&data, &extension, &description))
    }

    /// 创建图片消息（简化：仅 URL + 宽高）。
    #[flutter_rust_bridge::frb]
    pub async fn create_image_message(&self, url: String, width: i32, height: i32) -> Result<MsgData> {
        let client = self.inner.read().await;
        Ok(client.create_image_message(&url, width, height))
    }

    /// 创建视频消息。
    #[flutter_rust_bridge::frb]
    pub async fn create_video_message(
        &self,
        video_path: String,
        video_uuid: String,
        video_url: String,
        video_type: String,
        video_size: i64,
        duration: i64,
        snapshot_path: String,
        snapshot_uuid: String,
        snapshot_size: i64,
        snapshot_url: String,
        snapshot_width: i32,
        snapshot_height: i32,
    ) -> Result<MsgData> {
        let client = self.inner.read().await;
        Ok(client.create_video_message(
            &video_path,
            &video_uuid,
            &video_url,
            &video_type,
            video_size,
            duration,
            &snapshot_path,
            &snapshot_uuid,
            snapshot_size,
            &snapshot_url,
            snapshot_width,
            snapshot_height,
        ))
    }

    /// 创建语音消息。
    #[flutter_rust_bridge::frb]
    pub async fn create_sound_message(
        &self,
        uuid: String,
        sound_path: String,
        source_url: String,
        data_size: i64,
        duration: i64,
    ) -> Result<MsgData> {
        let client = self.inner.read().await;
        Ok(client.create_sound_message(&uuid, &sound_path, &source_url, data_size, duration))
    }

    /// 创建文件消息。
    #[flutter_rust_bridge::frb]
    pub async fn create_file_message(
        &self,
        file_path: String,
        uuid: String,
        source_url: String,
        file_name: String,
        file_size: i64,
    ) -> Result<MsgData> {
        let client = self.inner.read().await;
        Ok(client.create_file_message(
            &file_path,
            &uuid,
            &source_url,
            &file_name,
            file_size,
        ))
    }

    /// 创建位置消息。
    #[flutter_rust_bridge::frb]
    pub async fn create_location_message(
        &self,
        description: String,
        longitude: f64,
        latitude: f64,
    ) -> Result<MsgData> {
        let client = self.inner.read().await;
        Ok(client.create_location_message(&description, longitude, latitude))
    }

    /// 发送已创建的消息。入参为 create_* 返回的 MsgData（如 create_text_message 已填 recv_id/group_id/session_type）。
    ///
    /// **参数**
    /// - `msg`: 已组装的 MsgData。
    /// - `is_online_only`: 是否仅在线投递（不落库、不更新会话）；传 `false` 表示持久化，与 Go SDK 默认行为一致。
    #[flutter_rust_bridge::frb]
    pub async fn send_message(&self, msg: MsgData, is_online_only: bool) -> Result<()> {
        self.inner.read().await.send_message(msg, is_online_only).await?;
        Ok(())
    }

    /// 批量获取用户资料（优先内存缓存，缺失则拉服务端，与 Go GetUsersInfo 对齐）
    #[flutter_rust_bridge::frb]
    pub async fn get_users_info(&self, user_ids: Vec<String>) -> Result<Vec<UserProfile>> {
        let list = self.inner.read().await.get_users_info(user_ids).await?;
        Ok(list.into_iter().map(UserProfile::from).collect())
    }

    /// 更新当前登录用户资料（仅更新 patch 中传入字段），返回最新资料
    /// 同时会同步更新会话中的消息发送者头像
    #[flutter_rust_bridge::frb]
    pub async fn update_login_user_profile(&self, patch: UserProfilePatch) -> Result<UserProfile> {
        let profile = self
            .inner
            .read()
            .await
            .update_login_user_profile(
                patch.nickname,
                patch.face_url,
                patch.ex,
                patch.global_recv_msg_opt,
            )
            .await?;
        
        // 更新成功后，同步更新所有会话中的消息发送者头像
        let _ = self.inner.read().await.sync_login_user_info().await;
        
        Ok(profile.into())
    }

    /// 上传文件到对象存储
    ///
    /// # 参数
    /// - `file_path`: 本地文件路径
    /// - `file_name`: 文件名（会自动添加用户ID前缀）
    ///
    /// # 返回值
    /// - 成功：返回文件的 URL
    /// - 失败：返回错误
    #[flutter_rust_bridge::frb]
    pub async fn upload_file(&self, file_path: String, file_name: String) -> Result<String> {
        self.inner.read().await.upload_file(&file_path, &file_name).await
    }
}
