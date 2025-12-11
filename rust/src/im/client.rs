//! OpenIM 客户端核心实现模块（内部使用）
//!
//! 此模块包含 OpenIM 客户端的核心逻辑实现。
//! **重要：此模块中的所有类型和方法都不会被 flutter_rust_bridge 识别，不会生成 Dart 桥接代码。**
//!
//! 对外暴露的接口请使用 `bridge_client.rs` 中的 `OpenIMBridgeClient`。

use crate::im::advanced_msg_listener::{AdvancedMsgListener, EmptyAdvancedMsgListener};
use crate::im::conversation::{
    ConversationListener, ConversationSyncer, ConversationSyncerConfig, EmptyConversationListener,
    LocalConversation,
};
use crate::im::friend::{FriendListener, FriendSyncer, FriendSyncerConfig, LocalFriend};
use crate::im::message_store::MessageStore;
use crate::im::msg::{
    AtElem, CustomElem, FileElem, LocationElem, MarkdownTextElem, MsgStruct, PictureElem,
    QuoteElem, SoundElem, VideoElem,
};
use crate::im::serialization::{compress_gzip, decompress_gzip, generate_msg_id};
use crate::im::types::{msg_type, OpenIMResp, ServerResponse};
use anyhow::Result;
use futures_util::stream::{SplitSink, SplitStream};
use futures_util::{SinkExt, StreamExt};
use openim_protocol::constant;
use openim_protocol::Message as ProtobufMessage;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::sync::Mutex;
use tokio::time::interval;
use tokio_tungstenite::MaybeTlsStream;
use tokio_tungstenite::WebSocketStream;
use tokio_tungstenite::{connect_async, tungstenite::Message as WsMessage};
use tracing::{debug, error, info, warn};

/// WebSocket 写入端类型别名
pub type WsWriter = SplitSink<WebSocketStream<MaybeTlsStream<TcpStream>>, WsMessage>;

/// WebSocket 读取端类型别名
pub type WsReader = SplitStream<WebSocketStream<MaybeTlsStream<TcpStream>>>;

/// 客户端配置（内部使用，不对外暴露）
///
/// 此类型不会被 flutter_rust_bridge 识别，不会生成 Dart 桥接代码
#[derive(Clone, Debug)]
pub struct ClientConfig {
    /// 用户 ID
    pub user_id: String,
    /// 认证 token
    pub token: String,
    /// 平台 ID
    pub platform_id: i32,
    /// WebSocket 服务器 URL
    pub ws_url: String,
    /// 压缩方式，例如 "gzip" 或空字符串表示不压缩
    pub compression: String,
    /// 是否为后台模式
    pub is_background: bool,
    /// 是否需要消息响应
    pub is_msg_resp: bool,
    /// SDK 类型，例如 "js" 或 "go"
    pub sdk_type: String,
    /// HTTP API 基础地址（用于会话同步）
    pub api_base_url: String,
    /// 会话同步使用的本地 SQLite 数据库 URL
    ///
    /// 例如：`sqlite://conversations.db?mode=rwc`
    pub conversation_db_url: String,
}

impl ClientConfig {
    /// 创建默认配置
    pub fn new(user_id: String, token: String, platform_id: i32) -> Self {
        Self {
            user_id,
            token,
            platform_id,
            ws_url: "ws://localhost:10001".to_string(),
            compression: "gzip".to_string(),
            is_background: false,
            is_msg_resp: true,
            sdk_type: "js".to_string(),
            api_base_url: "http://localhost:10002".to_string(),
            conversation_db_url: "sqlite://conversations.db?mode=rwc".to_string(),
        }
    }
}

/// OpenIM 客户端（内部使用，不对外暴露）
///
/// 核心 IM 逻辑实现，通过 OpenIMBridgeClient 对外暴露。
/// 此类型及其所有方法都不会被 flutter_rust_bridge 识别，不会生成 Dart 桥接代码。
#[derive(Clone)]
pub struct OpenIMClient {
    pub(crate) config: ClientConfig,
    writer: Option<Arc<Mutex<WsWriter>>>,
    received_msg_ids: Arc<std::sync::Mutex<std::collections::HashSet<String>>>,
    // 会话同步器（用于基于消息通知实时更新会话）
    pub(crate) conversation_syncer: Option<Arc<ConversationSyncer>>,
    // 好友同步器（用于联系人列表增量同步）
    pub(crate) friend_syncer: Option<Arc<FriendSyncer>>,
    // 会话监听器（可由调用方注册）
    conversation_listener: Arc<dyn ConversationListener>,
    // 好友监听器（可由调用方注册）
    friend_listener: Arc<dyn FriendListener>,
    // 高级消息监听器（可由调用方注册，参考 Go 版本的 OnAdvancedMsgListener）
    advanced_msg_listener: Arc<dyn AdvancedMsgListener>,
    // 消息存储（本地 SQLite，sqlx 驱动）
    pub(crate) message_store: Option<Arc<MessageStore>>,
}

impl OpenIMClient {
    /// 注册会话监听器
    pub fn set_conversation_listener(&mut self, listener: Arc<dyn ConversationListener>) {
        self.conversation_listener = listener.clone();

        // 若同步器已存在，则用新的监听器重建同步器，保持回调一致
        if self.conversation_syncer.is_some() {
            if let Ok(handle) = tokio::runtime::Handle::try_current() {
                let cfg = ConversationSyncerConfig {
                    user_id: self.config.user_id.clone(),
                    api_base_url: self.config.api_base_url.clone(),
                    token: self.config.token.clone(),
                    db_path: self.config.conversation_db_url.clone(),
                };
                let listener = listener.clone();
                let syncer_slot = &mut self.conversation_syncer;
                handle.block_on(async {
                    if let Ok(syncer) =
                        ConversationSyncer::with_listener(cfg, listener.clone()).await
                    {
                        *syncer_slot = Some(Arc::new(syncer));
                    } else {
                        // 保持原同步器，出现错误仅记录日志
                        tracing::error!("[Client/Conv] 重建会话同步器失败，保持原同步器");
                    }
                });
            }
        }
    }

    /// 注册好友监听器
    pub fn set_friend_listener(&mut self, listener: Arc<dyn FriendListener>) {
        self.friend_listener = listener.clone();

        // 若同步器已存在，则用新的监听器重建同步器，保持回调一致
        if self.friend_syncer.is_some() {
            if let Ok(handle) = tokio::runtime::Handle::try_current() {
                let cfg = FriendSyncerConfig {
                    user_id: self.config.user_id.clone(),
                    api_base_url: self.config.api_base_url.clone(),
                    token: self.config.token.clone(),
                    db_path: self.config.conversation_db_url.clone(),
                };
                let listener = listener.clone();
                let syncer_slot = &mut self.friend_syncer;
                handle.block_on(async {
                    if let Ok(syncer) = FriendSyncer::with_listener(cfg, listener.clone()).await {
                        *syncer_slot = Some(Arc::new(syncer));
                    } else {
                        tracing::error!("[Client/Friend] 重建好友同步器失败，保持原同步器");
                    }
                });
            }
        }
    }

    /// 注册高级消息监听器（参考 Go 版本的 SetAdvancedMsgListener）
    pub fn set_advanced_msg_listener(&mut self, listener: Arc<dyn AdvancedMsgListener>) {
        self.advanced_msg_listener = listener;
    }

    /// 创建新的客户端
    /// - `config`: 客户端配置
    pub fn new(config: ClientConfig) -> Self {
        Self {
            config,
            writer: None,
            received_msg_ids: Arc::new(std::sync::Mutex::new(std::collections::HashSet::new())),
            conversation_syncer: None,
            friend_syncer: None,
            conversation_listener: Arc::new(EmptyConversationListener),
            friend_listener: Arc::new(crate::im::friend::EmptyFriendListener),
            advanced_msg_listener: Arc::new(EmptyAdvancedMsgListener),
            message_store: None,
        }
    }
    /// 构建 WebSocket 连接 URL
    fn build_url(&self, operation_id: &str) -> String {
        let compression_param = if self.config.compression.is_empty() {
            String::new()
        } else {
            format!("&compression={}", self.config.compression)
        };

        format!(
            "{}/?token={}&sendID={}&platformID={}&operationID={}{}&isBackground={}&isMsgResp={}&sdkType={}",
            self.config.ws_url,
            self.config.token,
            self.config.user_id,
            self.config.platform_id,
            operation_id,
            compression_param,
            self.config.is_background,
            self.config.is_msg_resp,
            self.config.sdk_type
        )
    }

    /// 连接到服务器并在内部启动消息处理
    pub async fn connect(&mut self) -> Result<()> {
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let url = self.build_url(&operation_id);

        info!(
            "[Client/WS] 🔗 连接到 OpenIM Server (user={}, platform={})",
            self.config.user_id, self.config.platform_id
        );

        let (ws_stream, response) = connect_async(&url).await?;
        info!(
            "[Client/WS] ✅ WebSocket 连接成功, 状态: {}",
            response.status()
        );

        let (write, mut read) = ws_stream.split();
        let writer = Arc::new(Mutex::new(write));
        self.writer = Some(writer.clone());

        // 等待连接成功响应
        if let Some(Ok(WsMessage::Text(text))) = read.next().await {
            if let Ok(resp) = serde_json::from_str::<ServerResponse>(&text) {
                if resp.err_code == 0 {
                    info!("[Client/WS] ✅ 服务器连接鉴权成功");
                    let listener = self.advanced_msg_listener.clone();
                    tokio::spawn(async move {
                        listener
                            .on_connection_status_changed(true, "连接成功".to_string())
                            .await;
                    });
                } else {
                    return Err(anyhow::anyhow!("服务器错误: {}", resp.err_msg));
                }
            }
        }

        info!("[Client/WS] 💓 启动心跳");
        info!("[Client/WS] 📥 开始监听服务器消息");

        // 启动会话同步（HTTP + 本地 SQLite），并保存同步器用于后续基于消息通知的实时更新
        let cfg = ConversationSyncerConfig {
            user_id: self.config.user_id.clone(),
            api_base_url: self.config.api_base_url.clone(),
            token: self.config.token.clone(),
            db_path: self.config.conversation_db_url.clone(),
        };
        let syncer = Arc::new(
            ConversationSyncer::with_listener(cfg, self.conversation_listener.clone()).await?,
        );
        self.conversation_syncer = Some(syncer.clone());

        tokio::spawn(async move {
            info!("[Client/Conv] 🔄 启动会话增量同步任务");
            let result = syncer.incr_sync_conversations().await;
            match result {
                Ok(_) => info!("[Client/Conv] ✅ 会话同步完成"),
                Err(e) => error!("[Client/Conv] ❌ 会话同步失败: {e}"),
            }
        });

        // 启动好友同步（HTTP + 本地 SQLite）
        let friend_cfg = FriendSyncerConfig {
            user_id: self.config.user_id.clone(),
            api_base_url: self.config.api_base_url.clone(),
            token: self.config.token.clone(),
            db_path: self.config.conversation_db_url.clone(),
        };
        let friend_syncer =
            Arc::new(FriendSyncer::with_listener(friend_cfg, self.friend_listener.clone()).await?);
        self.friend_syncer = Some(friend_syncer.clone());

        tokio::spawn(async move {
            info!("[Client/Friend] 🔄 启动好友增量同步任务");
            let result = friend_syncer.incr_sync_friends().await;
            match result {
                Ok(_) => info!("[Client/Friend] ✅ 好友同步完成"),
                Err(e) => error!("[Client/Friend] ❌ 好友同步失败: {e}"),
            }
        });

        // 初始化消息存储（单表，使用 sqlx）
        let store = Arc::new(
            MessageStore::new(
                &self.config.conversation_db_url,
                self.config.user_id.clone(),
            )
            .await?,
        );
        self.message_store = Some(store);

        // 启动心跳
        let writer_for_heartbeat = writer.clone();
        tokio::spawn(async move {
            let mut ticker = interval(Duration::from_secs(25));
            loop {
                ticker.tick().await;
                let mut w = writer_for_heartbeat.lock().await;
                if w.send(WsMessage::Ping(vec![])).await.is_err() {
                    break;
                }
            }
        });

        // 在内部启动消息处理任务
        let client = self.clone();
        tokio::spawn(async move {
            if let Err(e) = client.handle_messages(read).await {
                error!("消息处理错误: {}", e);
            }
        });

        Ok(())
    }

    /// 发送文本消息
    pub async fn send_text_message(
        &self,
        recv_id: String,
        text: String,
        session_type: i32, // 1=单聊, 2=群聊
    ) -> Result<()> {
        debug!("[Client/Msg] 🔧 构造文本消息");

        let content_json = serde_json::json!({ "content": text });
        let content_str = serde_json::to_string(&content_json)?;

        self.send_rich_message(
            recv_id,
            session_type,
            openim_protocol::constant::TEXT,
            content_str.into_bytes(),
            None,
            false,
            None,
        )
        .await
    }

    /// 发送图片消息
    pub async fn send_picture_message(
        &self,
        recv_id: String,
        picture: PictureElem,
        session_type: i32,
    ) -> Result<()> {
        debug!("[Client/Msg] 🔧 构造图片消息");
        let content_str = serde_json::to_string(&picture)?;
        self.send_rich_message(
            recv_id,
            session_type,
            openim_protocol::constant::PICTURE,
            content_str.into_bytes(),
            None,
            false,
            None,
        )
        .await
    }

    /// 发送语音消息
    pub async fn send_sound_message(
        &self,
        recv_id: String,
        sound: SoundElem,
        session_type: i32,
    ) -> Result<()> {
        debug!("[Client/Msg] 🔧 构造语音消息");
        let content_str = serde_json::to_string(&sound)?;
        self.send_rich_message(
            recv_id,
            session_type,
            openim_protocol::constant::VOICE,
            content_str.into_bytes(),
            None,
            false,
            None,
        )
        .await
    }

    /// 发送视频消息
    pub async fn send_video_message(
        &self,
        recv_id: String,
        video: VideoElem,
        session_type: i32,
    ) -> Result<()> {
        debug!("[Client/Msg] 🔧 构造视频消息");
        let content_str = serde_json::to_string(&video)?;
        self.send_rich_message(
            recv_id,
            session_type,
            openim_protocol::constant::VIDEO,
            content_str.into_bytes(),
            None,
            false,
            None,
        )
        .await
    }

    /// 发送文件消息
    pub async fn send_file_message(
        &self,
        recv_id: String,
        file: FileElem,
        session_type: i32,
    ) -> Result<()> {
        debug!("[Client/Msg] 🔧 构造文件消息");
        let content_str = serde_json::to_string(&file)?;
        self.send_rich_message(
            recv_id,
            session_type,
            openim_protocol::constant::FILE,
            content_str.into_bytes(),
            None,
            false,
            None,
        )
        .await
    }

    /// SendMessage NotOss
    pub async fn send_message_not_oss(
        &self,
        recv_id: String,
        group_id: String,
        message: MsgStruct,
        offline_push_info: Option<openim_protocol::sdkws::OfflinePushInfo>,
        is_online_only: bool,
    ) -> Result<()> {
        self.send_message_internal(
            recv_id,
            group_id,
            message,
            offline_push_info,
            is_online_only,
            true,
            None,
        )
        .await
    }

    /// SendMessage（默认支持 oss）
    pub async fn send_message(
        &self,
        recv_id: String,
        group_id: String,
        message: MsgStruct,
        offline_push_info: Option<openim_protocol::sdkws::OfflinePushInfo>,
        is_online_only: bool,
    ) -> Result<()> {
        self.send_message_internal(
            recv_id,
            group_id,
            message,
            offline_push_info,
            is_online_only,
            false,
            None,
        )
        .await
    }

    /// SendMessage（允许自定义 options 覆盖）
    pub async fn send_message_with_options(
        &self,
        recv_id: String,
        group_id: String,
        message: MsgStruct,
        offline_push_info: Option<openim_protocol::sdkws::OfflinePushInfo>,
        is_online_only: bool,
        options_override: Option<HashMap<String, bool>>,
    ) -> Result<()> {
        self.send_message_internal(
            recv_id,
            group_id,
            message,
            offline_push_info,
            is_online_only,
            false,
            options_override,
        )
        .await
    }

    /// 通用发送（content_type + content bytes + offlinePush/options）
    #[allow(clippy::too_many_arguments)]
    async fn send_rich_message(
        &self,
        recv_id: String,
        session_type: i32,
        content_type: i32,
        content: Vec<u8>,
        offline_push_info: Option<openim_protocol::sdkws::OfflinePushInfo>,
        is_online_only: bool,
        options_override: Option<HashMap<String, bool>>,
    ) -> Result<()> {
        use openim_protocol::sdkws;

        let now = chrono::Utc::now().timestamp_millis();
        let client_msg_id = generate_msg_id(&self.config.user_id);

        // 构造 options
        let options = self.build_options(is_online_only, options_override);

        // 构造 MsgData
        let msg_data = sdkws::MsgData {
            send_id: self.config.user_id.clone(),
            recv_id: recv_id.clone(),
            group_id: if session_type == 2 {
                recv_id.clone()
            } else {
                String::new()
            },
            client_msg_id: client_msg_id.clone(),
            server_msg_id: String::new(),
            sender_platform_id: self.config.platform_id,
            sender_nickname: String::new(),
            sender_face_url: String::new(),
            session_type,
            msg_from: 100, // UserMsgType
            content_type,
            content,
            seq: 0,
            send_time: 0,
            create_time: now,
            status: 1,
            is_read: false,
            options,
            offline_push_info,
            at_user_id_list: vec![],
            attached_info: String::new(),
            ex: String::new(),
        };

        // 序列化为 protobuf
        let mut pb_data = Vec::new();
        msg_data.encode(&mut pb_data)?;

        // 发送请求
        self.send_request(
            if is_online_only {
                msg_type::WS_SEND_MSG_NOT_OSS
            } else {
                msg_type::WS_SEND_MSG
            },
            pb_data,
        )
        .await?;

        info!("✅ 消息已发送，等待响应");
        Ok(())
    }

    /// 高级发送封装：MsgStruct -> protobuf MsgData
    #[allow(clippy::too_many_arguments)]
    async fn send_message_internal(
        &self,
        recv_id: String,
        group_id: String,
        message: MsgStruct,
        offline_push_info: Option<openim_protocol::sdkws::OfflinePushInfo>,
        is_online_only: bool,
        not_oss: bool,
        options_override: Option<HashMap<String, bool>>,
    ) -> Result<()> {
        let content = message
            .content
            .clone()
            .map(|s| s.into_bytes())
            .unwrap_or_default();
        let session_type = if !group_id.is_empty() { 2 } else { 1 };

        // options（按 openim-core 默认，结合 onlineOnly，可覆盖）
        let options = self.build_options(is_online_only, options_override);

        let now = chrono::Utc::now().timestamp_millis();
        let msg_data = openim_protocol::sdkws::MsgData {
            send_id: self.config.user_id.clone(),
            recv_id: recv_id.clone(),
            group_id: group_id.clone(),
            client_msg_id: message
                .client_msg_id
                .clone()
                .unwrap_or_else(|| generate_msg_id(&self.config.user_id)),
            server_msg_id: message.server_msg_id.clone().unwrap_or_default(),
            sender_platform_id: self.config.platform_id,
            sender_nickname: message.sender_nickname.clone().unwrap_or_default(),
            sender_face_url: message.sender_face_url.clone().unwrap_or_default(),
            session_type,
            msg_from: message.msg_from,
            content_type: message.content_type,
            content,
            seq: message.seq,
            send_time: if message.send_time > 0 {
                message.send_time
            } else {
                now
            },
            create_time: if message.create_time > 0 {
                message.create_time
            } else {
                now
            },
            status: message.status,
            is_read: message.is_read,
            options,
            offline_push_info,
            at_user_id_list: vec![],
            attached_info: message.attached_info.clone().unwrap_or_default(),
            ex: message.ex.clone().unwrap_or_default(),
        };

        let mut pb_data = Vec::new();
        msg_data.encode(&mut pb_data)?;

        self.send_request(
            if not_oss {
                msg_type::WS_SEND_MSG_NOT_OSS
            } else {
                msg_type::WS_SEND_MSG
            },
            pb_data,
        )
        .await?;
        Ok(())
    }

    /// 发送请求
    async fn send_request(&self, req_identifier: i32, data: Vec<u8>) -> Result<()> {
        let writer = self
            .writer
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("未连接"))?;

        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        let req = crate::im::types::OpenIMReq {
            req_identifier,
            token: self.config.token.clone(),
            send_id: self.config.user_id.clone(),
            operation_id: operation_id.clone(),
            msg_incr: String::new(),
            data,
        };

        let json = serde_json::to_vec(&req)?;

        // 压缩 JSON
        let compressed = compress_gzip(&json)?;

        let mut w = writer.lock().await;
        w.send(WsMessage::Binary(compressed)).await?;
        Ok(())
    }

    /// 构造默认 options，并允许外部覆盖
    fn build_options(
        &self,
        is_online_only: bool,
        override_map: Option<HashMap<String, bool>>,
    ) -> HashMap<String, bool> {
        let mut options = HashMap::new();
        options.insert("history".to_string(), true);
        options.insert("persistent".to_string(), true);
        options.insert("senderSync".to_string(), true);
        options.insert("conversationUpdate".to_string(), true);
        options.insert("senderConversationUpdate".to_string(), true);
        options.insert("unreadCount".to_string(), !is_online_only);
        options.insert("offlinePush".to_string(), !is_online_only);
        if let Some(extra) = override_map {
            for (k, v) in extra {
                options.insert(k, v);
            }
        }
        options
    }

    /// 处理接收消息（事件循环）
    async fn handle_messages(&self, mut read: WsReader) -> Result<()> {
        while let Some(msg_result) = read.next().await {
            match msg_result {
                Ok(WsMessage::Text(text)) => {
                    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text) {
                        if let Some(req_id) = json.get("reqIdentifier") {
                            debug!("[Client/WS] 文本响应: reqId={}", req_id);
                        }
                    }
                }
                Ok(WsMessage::Binary(data)) => {
                    self.handle_binary_message(data).await;
                }
                Ok(WsMessage::Ping(_)) | Ok(WsMessage::Pong(_)) => {}
                Ok(WsMessage::Close(frame)) => {
                    warn!("[Client/WS] 👋 连接关闭: {:?}", frame);
                    break;
                }
                Err(e) => {
                    error!("[Client/WS] WebSocket 错误: {}", e);
                    break;
                }
                _ => {}
            }
        }
        Ok(())
    }

    async fn handle_binary_message(&self, data: Vec<u8>) {
        // 解压
        let decompressed = if data.len() >= 2 && data[0] == 0x1f && data[1] == 0x8b {
            match decompress_gzip(&data) {
                Ok(d) => d,
                Err(e) => {
                    error!("[Client/WS] 解压失败: {}", e);
                    return;
                }
            }
        } else {
            data
        };

        // 解析 JSON
        let resp = match serde_json::from_slice::<OpenIMResp>(&decompressed) {
            Ok(r) => r,
            Err(e) => {
                error!(
                    "[Client/WS] JSON 解析失败: {}, 原始数据: {:?}",
                    e,
                    String::from_utf8_lossy(&decompressed)
                );
                return;
            }
        };

        // 处理不同类型
        match resp.req_identifier {
            msg_type::WS_PUSH_MSG => {
                self.handle_push_message(&resp.data).await;
            }
            msg_type::WS_SEND_MSG => {
                // 消息发送响应：不通过回调处理（发送方可通过返回值获取）
                if resp.err_code == 0 {
                    if let Ok(send_resp) = openim_protocol::msg::SendMsgResp::decode(&resp.data[..])
                    {
                        debug!(
                            "[Client/Msg] 消息发送成功: serverMsgID={}, clientMsgID={}",
                            send_resp.server_msg_id, send_resp.client_msg_id
                        );
                    } else {
                        debug!("[Client/Msg] 消息发送成功（解析响应失败）");
                    }
                } else {
                    error!("[Client/Msg] 消息发送失败: {:?}", resp);
                }
            }
            msg_type::WS_KICK_ONLINE_MSG => {
                warn!("[Client/WS] ⚠️ 被踢下线");
                let listener = self.advanced_msg_listener.clone();
                tokio::spawn(async move {
                    listener.on_kicked_offline().await;
                });
            }
            _ => {
                debug!("[Client/WS] 未知消息类型: {}", resp.req_identifier);
            }
        }
    }

    async fn handle_push_message(&self, data: &[u8]) {
        use openim_protocol::sdkws;

        if data.is_empty() {
            return;
        }

        let push_msg = match sdkws::PushMessages::decode(data) {
            Ok(pm) => pm,
            Err(e) => {
                error!("[Client/WS] Protobuf 解析失败: {}", e);
                return;
            }
        };

        // 处理消息
        for (conv_id, pull_msgs) in &push_msg.msgs {
            for msg in &pull_msgs.msgs {
                if self.is_duplicate_message(&msg.client_msg_id) {
                    continue;
                }

                let handled = self.handle_single_message(conv_id, msg, false).await;
                if !handled {
                    warn!(
                        "[Client/Msg] ⚠️ 未处理的消息类型: contentType={} ({}) conversationID={} clientMsgID={}",
                        msg.content_type,
                        Self::get_content_type_name(msg.content_type),
                        conv_id,
                        msg.client_msg_id
                    );
                }

                // 基于消息通知实时更新会话（未读数、最新消息等）
                // 注意：typing 消息不计入未读数，也不更新会话（参考 Go 版本的 IsUnreadCount: false）
                if msg.content_type != constant::TYPING {
                    if let Some(syncer) = &self.conversation_syncer {
                        if let Err(e) = syncer.on_new_message(conv_id, msg, false).await {
                            error!("[Client/Conv] on_new_message 更新会话失败: {}", e);
                        }
                    }
                }
            }
        }

        // 处理通知（会话 / 好友 / 其他系统通知）
        for (conv_id, pull_msgs) in &push_msg.notification_msgs {
            for msg in &pull_msgs.msgs {
                if self.is_duplicate_message(&msg.client_msg_id) {
                    continue;
                }

                let handled = self.handle_single_message(conv_id, msg, true).await;
                if !handled {
                    warn!(
                        "[Client/Msg] ⚠️ 未处理的通知消息类型: contentType={} ({}) conversationID={} clientMsgID={}",
                        msg.content_type,
                        Self::get_content_type_name(msg.content_type),
                        conv_id,
                        msg.client_msg_id
                    );
                }

                // 好友 / 关系相关通知：触发好友同步
                if let Some(friend_syncer) = &self.friend_syncer {
                    // 好友相关通知（1201~1210），包括好友申请、添加/删除、备注修改、黑名单变更、好友信息更新等
                    if msg.content_type >= constant::FRIEND_APPLICATION_APPROVED_NOTIFICATION
                        && msg.content_type <= constant::FRIENDS_INFO_UPDATE_NOTIFICATION
                    {
                        info!(
                            "[Client/Friend] 收到好友相关通知 contentType={}，触发好友增量同步",
                            msg.content_type
                        );
                        let syncer = friend_syncer.clone();
                        tokio::spawn(async move {
                            if let Err(e) = syncer.incr_sync_friends().await {
                                error!("[Client/Friend] 好友通知触发同步失败: {}", e);
                            }
                        });
                    }
                }

                // 基于消息通知实时更新会话（未读数、最新消息等）
                // 注意：typing 消息不计入未读数，也不更新会话（参考 Go 版本的 IsUnreadCount: false）
                if msg.content_type != constant::TYPING {
                    if let Some(syncer) = &self.conversation_syncer {
                        if let Err(e) = syncer.on_new_message(conv_id, msg, true).await {
                            error!("[Client/Conv] on_new_message 更新通知会话失败: {}", e);
                        }
                    }
                }
            }
        }
    }

    fn is_duplicate_message(&self, msg_id: &str) -> bool {
        let mut set = self.received_msg_ids.lock().unwrap();
        !set.insert(msg_id.to_string())
    }

    /// 处理单个消息，返回是否已处理
    ///
    /// - `conv_id`: 会话 ID
    /// - `msg`: 消息数据
    /// - `_is_notification`: 是否为通知消息（保留用于后续扩展）
    /// - 返回: `true` 表示已处理，`false` 表示未处理（需要 warn）
    async fn handle_single_message(
        &self,
        conv_id: &str,
        msg: &openim_protocol::sdkws::MsgData,
        _is_notification: bool,
    ) -> bool {
        // 撤回消息
        if msg.content_type == constant::REVOKE {
            let revoked_json = serde_json::json!({
                "clientMsgID": msg.client_msg_id,
                "revokerID": msg.send_id,
                "revokeTime": msg.send_time,
                "seq": msg.seq,
                "conversationID": conv_id,
            });
            let revoked_json_str = serde_json::to_string(&revoked_json).unwrap_or_default();
            let listener = self.advanced_msg_listener.clone();
            tokio::spawn(async move {
                listener.on_new_recv_message_revoked(revoked_json_str).await;
            });
            return true;
        }

        // 已读回执
        if msg.content_type == constant::HAS_READ_RECEIPT {
            let mut seqs: Vec<i64> = Vec::new();
            let mut receipt_list = Vec::new();
            if let Ok(json) = serde_json::from_slice::<serde_json::Value>(&msg.content) {
                if let Some(detail) = json.get("detail") {
                    if let Some(list) = detail.get("seqList").and_then(|v| v.as_array()) {
                        seqs = list.iter().filter_map(|x| x.as_i64()).collect();
                    }
                }
                receipt_list.push(serde_json::json!({
                    "userID": msg.send_id,
                    "msgIDList": seqs.iter().map(|s| format!("seq_{}", s)).collect::<Vec<_>>(),
                    "sessionType": msg.session_type,
                    "readTime": msg.send_time,
                }));
            }
            let receipt_json_str = serde_json::to_string(&receipt_list).unwrap_or_default();
            let listener = self.advanced_msg_listener.clone();
            tokio::spawn(async move {
                listener.on_recv_c2c_read_receipt(receipt_json_str).await;
            });
            return true;
        }

        // Reaction 事件（已处理，但暂不通过回调）
        if msg.content_type == constant::REACTION_MESSAGE_MODIFIER
            || msg.content_type == constant::REACTION_MESSAGE_DELETER
        {
            // Reaction 事件：目前不通过回调处理（可后续扩展）
            return true;
        }

        // 输入提示（typing）
        if msg.content_type == constant::TYPING {
            let mut msg_tip = String::new();
            if let Ok(json) = serde_json::from_slice::<serde_json::Value>(&msg.content) {
                if let Some(v) = json.get("msgTip").and_then(|v| v.as_str()) {
                    msg_tip = v.to_string();
                }
            }
            let typing_json = serde_json::json!({
                "conversationID": conv_id,
                "sendID": msg.send_id,
                "msgTip": msg_tip,
            });
            let typing_json_str = serde_json::to_string(&typing_json).unwrap_or_default();
            let listener = self.advanced_msg_listener.clone();
            tokio::spawn(async move {
                listener.on_recv_typing_status(typing_json_str).await;
            });
            return true;
        }

        // 普通消息类型（CONTENT_TYPE_BEGIN 到 NOTIFICATION_BEGIN 之间的所有类型）
        // 包括：TEXT, PICTURE, VOICE, VIDEO, FILE, AT_TEXT, MERGER, CARD, LOCATION, CUSTOM,
        // REVOKE, TYPING, QUOTE, ADVANCED_TEXT, MARKDOWN_TEXT, CUSTOM_NOT_TRIGGER_CONVERSATION,
        // CUSTOM_ONLINE_ONLY, REACTION_MESSAGE_MODIFIER, REACTION_MESSAGE_DELETER 等
        // 注意：REVOKE, HAS_READ_RECEIPT, REACTION, TYPING 已在上面处理，这里处理其他普通消息
        if msg.content_type >= constant::CONTENT_TYPE_BEGIN
            && msg.content_type < constant::NOTIFICATION_BEGIN
        {
            // 排除已特殊处理的消息类型
            if msg.content_type != constant::REVOKE
                && msg.content_type != constant::HAS_READ_RECEIPT
                && msg.content_type != constant::REACTION_MESSAGE_MODIFIER
                && msg.content_type != constant::REACTION_MESSAGE_DELETER
                && msg.content_type != constant::TYPING
            {
                let msg_json = self.msg_data_to_json(msg);
                let listener = self.advanced_msg_listener.clone();
                tokio::spawn(async move {
                    listener.on_recv_new_message(msg_json).await;
                });
                return true;
            }
        }

        // 通用消息类型（COMMON, GROUP_MSG, SIGNAL_MSG, CUSTOM_NOTIFICATION）
        if msg.content_type == constant::COMMON
            || msg.content_type == constant::GROUP_MSG
            || msg.content_type == constant::SIGNAL_MSG
            || msg.content_type == constant::CUSTOM_NOTIFICATION
        {
            let msg_json = self.msg_data_to_json(msg);
            let listener = self.advanced_msg_listener.clone();
            tokio::spawn(async move {
                listener.on_recv_new_message(msg_json).await;
            });
            return true;
        }

        // 通知消息类型（NOTIFICATION_BEGIN 到 NOTIFICATION_END 之间的所有类型）
        // 包括：好友通知、用户通知、群组通知、会话通知等
        if msg.content_type >= constant::NOTIFICATION_BEGIN
            && msg.content_type <= constant::NOTIFICATION_END
        {
            // 排除已特殊处理的通知类型（HAS_READ_RECEIPT）
            if msg.content_type != constant::HAS_READ_RECEIPT {
                let msg_json = self.msg_data_to_json(msg);
                let listener = self.advanced_msg_listener.clone();
                tokio::spawn(async move {
                    listener.on_recv_new_message(msg_json).await;
                });
                return true;
            }
        }

        // 未处理的消息类型（会触发 warn 日志）
        false
    }

    /// 获取会话列表（分页）
    pub async fn get_conversation_list(
        &self,
        offset: usize,
        count: usize,
    ) -> Result<Vec<LocalConversation>> {
        let syncer = self
            .conversation_syncer
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("会话同步器未初始化"))?;
        syncer.get_conversation_list_split(offset, count).await
    }

    /// 获取所有会话列表
    pub async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        let syncer = self
            .conversation_syncer
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("会话同步器未初始化"))?;
        syncer.get_all_conversation_list().await
    }

    /// 获取所有好友列表
    pub async fn get_all_friends(&self) -> Result<Vec<LocalFriend>> {
        let syncer = self
            .friend_syncer
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("好友同步器未初始化"))?;
        syncer.get_all_friends().await
    }

    /// 获取总未读消息数（来自会话同步器的本地聚合）
    pub async fn get_total_unread_count(&self) -> Result<i32> {
        let syncer = self
            .conversation_syncer
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("会话同步器未初始化"))?;
        syncer.get_total_unread_count().await
    }

    /// 标记所有会话为已读
    pub async fn mark_all_conversation_message_as_read(&self) -> Result<()> {
        let url = format!(
            "{}/msg/mark_all_conversation_as_read",
            self.config.api_base_url
        );
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        info!("[Client/Msg] 📡 标记所有会话已读");

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&serde_json::json!({
                "userID": self.config.user_id,
            }))
            .send()
            .await?;

        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            error!(
                "[Client/Msg] 标记所有会话已读请求失败，HTTP状态: {}, 响应: {}",
                status, text
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }

        let json_value: serde_json::Value = serde_json::from_str(&text)?;
        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value
                    .get("errMsg")
                    .and_then(|v| v.as_str())
                    .unwrap_or("未知错误");
                error!(
                    "[Client/Msg] 标记所有会话已读服务器错误，错误码: {}, 错误信息: {}",
                    err_code, err_msg
                );
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client/Msg] ✅ 标记所有会话已读成功");
        Ok(())
    }

    // ===================== 消息管理相关 HTTP 能力 =====================

    /// 撤回消息（按会话 ID + clientMsgID，参考 Go 版本的 RevokeMessage）
    pub async fn revoke_message(
        &self,
        conversation_id: String,
        client_msg_id: String,
    ) -> Result<()> {
        // 1. 从本地数据库获取消息的 seq（参考 Go 版本的 waitForMessageSyncSeq）
        let store = self
            .message_store
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("消息存储未初始化"))?;

        let msg = store
            .get_by_client_msg_id(&conversation_id, &client_msg_id)
            .await?
            .ok_or_else(|| anyhow::anyhow!("消息不存在或未同步: clientMsgID={}", client_msg_id))?;

        if msg.seq == 0 {
            return Err(anyhow::anyhow!(
                "消息尚未同步到服务器，无法撤回: clientMsgID={}",
                client_msg_id
            ));
        }

        // 2. 检查消息状态（只有发送成功的消息才能撤回）
        if msg.status != openim_protocol::constant::MSG_STATUS_SEND_SUCCESS {
            return Err(anyhow::anyhow!(
                "只有发送成功的消息才能撤回: status={}",
                msg.status
            ));
        }

        // 3. 调用服务端 API（服务端需要 seq）
        let url = format!("{}/msg/revoke_msg", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "seq": msg.seq,
            "userID": self.config.user_id,
        });

        info!(
            "[Client/Msg] 📡 撤回消息: conversationID={}, clientMsgID={}, seq={}",
            conversation_id, client_msg_id, msg.seq
        );

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;

        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            error!(
                "[Client/Msg] 撤回消息请求失败，HTTP状态: {}, 响应: {}",
                status, text
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }

        let json_value: serde_json::Value = serde_json::from_str(&text)?;
        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value
                    .get("errMsg")
                    .and_then(|v| v.as_str())
                    .unwrap_or("未知错误");
                error!(
                    "[Client/Msg] 撤回消息服务器错误，错误码: {}, 错误信息: {}",
                    err_code, err_msg
                );
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client/Msg] ✅ 撤回消息成功");
        Ok(())
    }

    /// 删除消息（按会话 ID + 多个 seq）
    pub async fn delete_messages(&self, conversation_id: String, seqs: Vec<i64>) -> Result<()> {
        let url = format!("{}/msg/delete_msgs", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "seqs": seqs,
            "userID": self.config.user_id,
        });

        info!(
            "[Client/Msg] 📡 删除消息: conversationID={}",
            conversation_id
        );

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;

        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            error!(
                "[Client/Msg] 删除消息请求失败，HTTP状态: {}, 响应: {}",
                status, text
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }

        let json_value: serde_json::Value = serde_json::from_str(&text)?;
        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value
                    .get("errMsg")
                    .and_then(|v| v.as_str())
                    .unwrap_or("未知错误");
                error!(
                    "[Client/Msg] 删除消息服务器错误，错误码: {}, 错误信息: {}",
                    err_code, err_msg
                );
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client/Msg] ✅ 删除消息成功");
        Ok(())
    }

    /// 删除本地消息（按 clientMsgID）
    pub async fn delete_message_from_local_storage(
        &self,
        conversation_id: String,
        client_msg_id: String,
    ) -> Result<()> {
        let store = self
            .message_store
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("消息存储未初始化"))?;
        store
            .delete_by_client_msg_id(&conversation_id, &client_msg_id)
            .await?;
        info!(
            "[Client/Msg] 🗑️ 删除本地消息: conversationID={}, clientMsgID={}",
            conversation_id, client_msg_id
        );
        Ok(())
    }

    /// 删除会话本地消息并清理服务器（占位：本地清理 + HTTP 调用）
    pub async fn delete_message(
        &self,
        conversation_id: String,
        client_msg_id: String,
    ) -> Result<()> {
        // 本地
        if let Some(store) = &self.message_store {
            let _ = store
                .delete_by_client_msg_id(&conversation_id, &client_msg_id)
                .await;
        }

        // 服务器
        let url = format!("{}/msg/delete_msg", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "clientMsgID": client_msg_id,
            "userID": self.config.user_id,
        });

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        if let Some(err_code) = serde_json::from_str::<serde_json::Value>(&text)?
            .get("errCode")
            .and_then(|v| v.as_i64())
        {
            if err_code != 0 {
                let err_msg = serde_json::from_str::<serde_json::Value>(&text)
                    .ok()
                    .and_then(|v| {
                        v.get("errMsg")
                            .and_then(|s| s.as_str())
                            .map(|s| s.to_string())
                    })
                    .unwrap_or_else(|| "未知错误".to_string());
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client/Msg] ✅ 删除消息（本地+服务端）成功");
        Ok(())
    }

    /// 删除指定会话的全部本地消息
    pub async fn delete_all_msg_from_local(&self, conversation_id: String) -> Result<()> {
        if let Some(store) = &self.message_store {
            store.delete_conversation(&conversation_id).await?;
        }
        info!(
            "[Client/Msg] 🗑️ 已删除本地会话全部消息，conversationID={}",
            conversation_id
        );
        Ok(())
    }

    /// 插入单聊消息到本地存储（仿 openim-core InsertSingleMessageToLocalStorage）
    pub async fn insert_single_message_to_local_storage(
        &self,
        message_json: String,
        recv_id: String,
        send_id: String,
    ) -> Result<MsgStruct> {
        let mut msg: MsgStruct = serde_json::from_str(&message_json)?;
        msg.send_id = Some(send_id.clone());
        msg.recv_id = Some(recv_id.clone());
        if msg.client_msg_id.is_none() {
            msg.client_msg_id = Some(generate_msg_id(&send_id));
        }
        let conv_id = format!("si_{}_{}", send_id, recv_id); // 简化版本
        self.store_msg(conv_id, msg.clone()).await?;
        Ok(msg)
    }

    /// 插入群聊消息到本地存储（仿 openim-core InsertGroupMessageToLocalStorage）
    pub async fn insert_group_message_to_local_storage(
        &self,
        message_json: String,
        group_id: String,
        send_id: String,
    ) -> Result<MsgStruct> {
        let mut msg: MsgStruct = serde_json::from_str(&message_json)?;
        msg.send_id = Some(send_id.clone());
        msg.group_id = Some(group_id.clone());
        msg.recv_id = Some(group_id.clone());
        if msg.client_msg_id.is_none() {
            msg.client_msg_id = Some(generate_msg_id(&send_id));
        }
        let conv_id = format!("gi_{}", group_id); // 简化版本
        self.store_msg(conv_id, msg.clone()).await?;
        Ok(msg)
    }

    /// 按消息 ID 标记已读（本地）
    pub async fn mark_messages_as_read_by_msg_id_local(
        &self,
        conversation_id: String,
        client_msg_ids: Vec<String>,
    ) -> Result<i64> {
        let store = self
            .message_store
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("消息存储未初始化"))?;
        store
            .mark_as_read_by_msg_ids(&conversation_id, &client_msg_ids)
            .await
    }

    /// 按消息 ID 标记已读（本地 + 服务端）
    pub async fn mark_messages_as_read_by_msg_id(
        &self,
        conversation_id: String,
        client_msg_ids: Vec<String>,
    ) -> Result<()> {
        // 本地
        if let Some(store) = &self.message_store {
            let _ = store
                .mark_as_read_by_msg_ids(&conversation_id, &client_msg_ids)
                .await?;
        }

        // 服务端
        let url = format!(
            "{}/msg/mark_msgs_as_read_by_msg_id",
            self.config.api_base_url
        );
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "clientMsgIDs": client_msg_ids,
            "userID": self.config.user_id,
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        if let Some(err_code) = serde_json::from_str::<serde_json::Value>(&text)?
            .get("errCode")
            .and_then(|v| v.as_i64())
        {
            if err_code != 0 {
                let err_msg = serde_json::from_str::<serde_json::Value>(&text)
                    .ok()
                    .and_then(|v| {
                        v.get("errMsg")
                            .and_then(|s| s.as_str())
                            .map(|s| s.to_string())
                    })
                    .unwrap_or_else(|| "未知错误".to_string());
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }
        Ok(())
    }

    /// 按会话标记已读（本地 + 服务端）
    pub async fn mark_conversation_message_as_read_full(
        &self,
        conversation_id: String,
    ) -> Result<()> {
        // 本地：标记对端消息已读
        if let Some(store) = &self.message_store {
            // 读取未读消息的 seq 用于可能的 has_read_seq
            let unread = store.get_unread_by_conversation(&conversation_id).await?;
            let seqs: Vec<i64> = unread.iter().map(|m| m.seq).collect();
            let _ = store.mark_as_read_by_seqs(&conversation_id, &seqs).await?;
        }

        // 服务端：沿用现有 HTTP 端点 mark_conversation_as_read
        let url = format!("{}/msg/mark_conversation_as_read", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "userID": self.config.user_id,
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        if let Some(err_code) = serde_json::from_str::<serde_json::Value>(&text)?
            .get("errCode")
            .and_then(|v| v.as_i64())
        {
            if err_code != 0 {
                let err_msg = serde_json::from_str::<serde_json::Value>(&text)
                    .ok()
                    .and_then(|v| {
                        v.get("errMsg")
                            .and_then(|s| s.as_str())
                            .map(|s| s.to_string())
                    })
                    .unwrap_or_else(|| "未知错误".to_string());
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }
        Ok(())
    }

    /// 删除所有消息（本地 + 服务端）
    pub async fn delete_all_msg_from_local_and_server(&self) -> Result<()> {
        // 本地清空所有已知会话表（无法枚举表名，采取粗暴 drop 数据库时请谨慎）
        // 这里仅提示：需要调用方自行管理会话 ID 列表，逐个调用 delete_all_msg_from_local
        // 服务端
        let url = format!(
            "{}/msg/delete_all_msg_from_local_and_svr",
            self.config.api_base_url
        );
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "userID": self.config.user_id,
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        Ok(())
    }

    /// 清空会话消息（本地 + 服务端）
    pub async fn clear_conversation_and_delete_all_msg(
        &self,
        conversation_id: String,
    ) -> Result<()> {
        if let Some(store) = &self.message_store {
            let _ = store.delete_conversation(&conversation_id).await;
        }
        let url = format!(
            "{}/msg/clear_conversation_and_delete_all_msg",
            self.config.api_base_url
        );
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "userID": self.config.user_id,
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        Ok(())
    }

    /// 删除会话并删除全部消息（本地 + 服务端）
    pub async fn delete_conversation_and_delete_all_msg(
        &self,
        conversation_id: String,
    ) -> Result<()> {
        if let Some(store) = &self.message_store {
            let _ = store.delete_conversation(&conversation_id).await;
        }
        let url = format!(
            "{}/msg/delete_conversation_and_delete_all_msg",
            self.config.api_base_url
        );
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "userID": self.config.user_id,
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        Ok(())
    }

    /// Typing 状态更新（仿 openim-core TypingStatusUpdate）
    pub async fn typing_status_update(&self, recv_id: String, msg_tip: String) -> Result<()> {
        let url = format!("{}/msg/typing_status_update", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "recvID": recv_id,
            "msgTip": msg_tip,
            "sendID": self.config.user_id,
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        Ok(())
    }

    /// 消息构造器：文本
    pub fn create_text_message(&self, text: String) -> MsgStruct {
        self.build_msg(openim_protocol::constant::TEXT, Some(text), None, None)
    }

    /// 消息构造器：自定义
    pub fn create_custom_message(
        &self,
        data: String,
        extension: String,
        description: String,
    ) -> MsgStruct {
        let elem = CustomElem {
            data,
            description,
            extension,
        };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::CUSTOM, Some(content), None, None)
    }

    /// 消息构造器：位置
    pub fn create_location_message(
        &self,
        description: String,
        longitude: f64,
        latitude: f64,
    ) -> MsgStruct {
        let elem = LocationElem {
            description,
            longitude,
            latitude,
        };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(
            openim_protocol::constant::LOCATION,
            Some(content),
            None,
            None,
        )
    }

    /// 消息构造器：引用
    pub fn create_quote_message(&self, text: Option<String>, quote: MsgStruct) -> MsgStruct {
        let elem = QuoteElem {
            text,
            quote_message: Some(Box::new(quote)),
        };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::QUOTE, Some(content), None, None)
    }

    /// 消息构造器：图片
    pub fn create_image_message(&self, elem: PictureElem) -> MsgStruct {
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(
            openim_protocol::constant::PICTURE,
            Some(content),
            None,
            None,
        )
    }

    /// 消息构造器：语音
    pub fn create_sound_message(&self, elem: SoundElem) -> MsgStruct {
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::VOICE, Some(content), None, None)
    }

    /// 消息构造器：视频
    pub fn create_video_message(&self, elem: VideoElem) -> MsgStruct {
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::VIDEO, Some(content), None, None)
    }

    /// 消息构造器：文件
    pub fn create_file_message(&self, elem: FileElem) -> MsgStruct {
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::FILE, Some(content), None, None)
    }

    /// Typing 消息构造器（仅本地封装）
    pub fn create_typing_message(&self, msg_tip: String) -> MsgStruct {
        let content =
            serde_json::to_string(&serde_json::json!({ "msgTip": msg_tip })).unwrap_or_default();
        self.build_msg(openim_protocol::constant::TYPING, Some(content), None, None)
    }

    /// 消息构造器：文本@（带 atUserList / atUsersInfo）
    pub fn create_text_at_message(
        &self,
        text: String,
        at_user_list: Vec<String>,
        at_users_info: Option<Vec<crate::im::msg::AtInfo>>,
        quote_message: Option<MsgStruct>,
        is_at_self: bool,
    ) -> MsgStruct {
        let elem = AtElem {
            text,
            at_user_list,
            at_users_info,
            quote_message: quote_message.map(Box::new),
            is_at_self,
        };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(
            openim_protocol::constant::AT_TEXT,
            Some(content),
            None,
            None,
        )
    }

    /// 消息构造器：合并消息（Merger）
    pub fn create_merger_message(
        &self,
        message_list: Vec<MsgStruct>,
        title: String,
        summary_list: Vec<String>,
    ) -> MsgStruct {
        let content = serde_json::to_string(&serde_json::json!({
            "title": title,
            "summaryList": summary_list,
            "multiMessage": message_list,
        }))
        .unwrap_or_default();
        self.build_msg(openim_protocol::constant::MERGER, Some(content), None, None)
    }

    /// 消息构造器：卡片消息（Card）
    pub fn create_card_message(&self, card_info: String) -> MsgStruct {
        let content = serde_json::to_string(&serde_json::json!({
            "cardInfo": card_info
        }))
        .unwrap_or_default();
        self.build_msg(openim_protocol::constant::CARD, Some(content), None, None)
    }

    /// 消息构造器：Markdown 文本
    pub fn create_markdown_message(&self, content: String) -> MsgStruct {
        let elem = MarkdownTextElem { content };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(
            openim_protocol::constant::MARKDOWN_TEXT,
            Some(content),
            None,
            None,
        )
    }

    /// 消息构造器：Markdown 文本 + 实体列表
    pub fn create_markdown_with_entities_message(
        &self,
        content: String,
        message_entity_list: Option<String>,
    ) -> MsgStruct {
        let elem = crate::im::msg::MarkdownEntityElem {
            content,
            message_entity_list,
        };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(
            openim_protocol::constant::MARKDOWN_TEXT,
            Some(content),
            None,
            None,
        )
    }

    /// 消息构造器：混合消息（Merger 近似，使用 MERGER contentType）
    pub fn create_mixed_message(
        &self,
        title: String,
        summary_list: Vec<String>,
        message_list: Vec<MsgStruct>,
    ) -> MsgStruct {
        let content = serde_json::to_string(&serde_json::json!({
            "title": title,
            "summaryList": summary_list,
            "message": message_list,
        }))
        .unwrap_or_default();
        self.build_msg(openim_protocol::constant::MERGER, Some(content), None, None)
    }

    /// 消息构造器：AdvancedText（text + messageEntityList json）
    pub fn create_advanced_text_message(
        &self,
        text: String,
        message_entity_list: String,
    ) -> MsgStruct {
        let content = serde_json::to_string(&serde_json::json!({
            "text": text,
            "messageEntityList": message_entity_list,
        }))
        .unwrap_or_default();
        self.build_msg(
            openim_protocol::constant::ADVANCED_TEXT,
            Some(content),
            None,
            None,
        )
    }

    /// 消息构造器：AdvancedQuote（text + message + messageEntityList）
    pub fn create_advanced_quote_message(
        &self,
        text: String,
        message: MsgStruct,
        message_entity_list: String,
    ) -> MsgStruct {
        let content = serde_json::to_string(&serde_json::json!({
            "text": text,
            "message": message,
            "messageEntityList": message_entity_list,
        }))
        .unwrap_or_default();
        self.build_msg(
            openim_protocol::constant::ADVANCED_TEXT,
            Some(content),
            None,
            None,
        )
    }

    /// 消息构造器：Markdown + @（复用 AtElem，text 使用 markdown）
    pub fn create_markdown_at_message(
        &self,
        markdown_text: String,
        at_user_list: Vec<String>,
        at_users_info: Option<Vec<crate::im::msg::AtInfo>>,
        quote_message: Option<MsgStruct>,
        is_at_self: bool,
    ) -> MsgStruct {
        let elem = AtElem {
            text: markdown_text,
            at_user_list,
            at_users_info,
            quote_message: quote_message.map(Box::new),
            is_at_self,
        };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(
            openim_protocol::constant::MARKDOWN_TEXT,
            Some(content),
            None,
            None,
        )
    }

    /// 消息构造器：自定义 OnlineOnly
    pub fn create_custom_online_only_message(
        &self,
        data: String,
        extension: String,
        description: String,
    ) -> MsgStruct {
        let elem = CustomElem {
            data,
            description,
            extension,
        };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(
            openim_protocol::constant::CUSTOM_ONLINE_ONLY,
            Some(content),
            None,
            None,
        )
    }

    /// 消息构造器：自定义不触发会话
    pub fn create_custom_not_trigger_conversation_message(
        &self,
        data: String,
        extension: String,
        description: String,
    ) -> MsgStruct {
        let elem = CustomElem {
            data,
            description,
            extension,
        };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(
            openim_protocol::constant::CUSTOM_NOT_TRIGGER_CONVERSATION,
            Some(content),
            None,
            None,
        )
    }

    fn build_msg(
        &self,
        content_type: i32,
        content: Option<String>,
        recv_id: Option<String>,
        group_id: Option<String>,
    ) -> MsgStruct {
        let now = chrono::Utc::now().timestamp_millis();
        let mut msg = MsgStruct {
            client_msg_id: Some(generate_msg_id(&self.config.user_id)),
            server_msg_id: None,
            create_time: now,
            send_time: now,
            session_type: if group_id.is_some() {
                openim_protocol::constant::GROUP_MSG
            } else {
                openim_protocol::constant::SINGLE_CHAT_TYPE
            },
            send_id: Some(self.config.user_id.clone()),
            recv_id,
            msg_from: 100,
            content_type,
            sender_platform_id: self.config.platform_id,
            sender_nickname: None,
            sender_face_url: None,
            group_id,
            content: None,
            seq: 0,
            is_read: false,
            status: 1,
            is_react: None,
            is_external_extensions: None,
            offline_push: None,
            attached_info: None,
            ex: None,
            local_ex: None,
            text_elem: None,
            picture_elem: None,
            sound_elem: None,
            video_elem: None,
            file_elem: None,
            at_text_elem: None,
            location_elem: None,
            custom_elem: None,
            quote_elem: None,
        };
        msg.content = content;
        msg
    }

    /// 将 protobuf MsgData 转换为 MsgStruct 并序列化为 JSON（用于回调）
    fn msg_data_to_json(&self, msg: &openim_protocol::sdkws::MsgData) -> String {
        let msg_struct = MsgStruct {
            client_msg_id: Some(msg.client_msg_id.clone()),
            server_msg_id: Some(msg.server_msg_id.clone()),
            create_time: msg.create_time,
            send_time: msg.send_time,
            session_type: msg.session_type,
            send_id: Some(msg.send_id.clone()),
            recv_id: Some(msg.recv_id.clone()),
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            sender_platform_id: msg.sender_platform_id,
            sender_nickname: Some(msg.sender_nickname.clone()),
            sender_face_url: Some(msg.sender_face_url.clone()),
            group_id: if !msg.group_id.is_empty() {
                Some(msg.group_id.clone())
            } else {
                None
            },
            content: Some(String::from_utf8_lossy(&msg.content).to_string()),
            seq: msg.seq,
            is_read: msg.is_read,
            status: msg.status,
            is_react: None,
            is_external_extensions: None,
            offline_push: None,
            attached_info: Some(msg.attached_info.clone()),
            ex: Some(msg.ex.clone()),
            local_ex: None,
            text_elem: None,
            picture_elem: None,
            sound_elem: None,
            video_elem: None,
            file_elem: None,
            at_text_elem: None,
            location_elem: None,
            custom_elem: None,
            quote_elem: None,
        };
        serde_json::to_string(&msg_struct).unwrap_or_else(|_| "{}".to_string())
    }

    async fn store_msg(&self, conversation_id: String, msg: MsgStruct) -> Result<()> {
        let store = self
            .message_store
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("消息存储未初始化"))?;
        let now = chrono::Utc::now().timestamp_millis();
        let log = crate::im::message_store::LocalChatLog {
            conversation_id,
            client_msg_id: msg
                .client_msg_id
                .clone()
                .unwrap_or_else(|| generate_msg_id("unk")),
            server_msg_id: msg.server_msg_id.clone().unwrap_or_default(),
            send_id: msg.send_id.clone().unwrap_or_default(),
            recv_id: msg.recv_id.clone().unwrap_or_default(),
            sender_platform_id: msg.sender_platform_id,
            sender_nickname: msg.sender_nickname.clone().unwrap_or_default(),
            sender_face_url: msg.sender_face_url.clone().unwrap_or_default(),
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: msg.content.clone().unwrap_or_default(),
            is_read: msg.is_read,
            status: msg.status,
            seq: msg.seq,
            send_time: if msg.send_time > 0 {
                msg.send_time
            } else {
                now
            },
            create_time: if msg.create_time > 0 {
                msg.create_time
            } else {
                now
            },
            attached_info: msg.attached_info.clone().unwrap_or_default(),
            ex: msg.ex.clone().unwrap_or_default(),
            local_ex: msg.local_ex.clone().unwrap_or_default(),
            group_id: msg.group_id.clone().unwrap_or_default(),
        };
        store.insert_message(&log).await
    }

    /// 清空指定会话的所有消息
    pub async fn clear_conversation_msgs(&self, conversation_ids: Vec<String>) -> Result<()> {
        let url = format!("{}/msg/clear_conversation_msg", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        let req_json = serde_json::json!({
            "conversationIDs": conversation_ids,
            "userID": self.config.user_id,
        });

        info!("[Client/Msg] 📡 清空会话消息");

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;

        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            error!(
                "[Client/Msg] 清空会话消息请求失败，HTTP状态: {}, 响应: {}",
                status, text
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }

        let json_value: serde_json::Value = serde_json::from_str(&text)?;
        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value
                    .get("errMsg")
                    .and_then(|v| v.as_str())
                    .unwrap_or("未知错误");
                error!(
                    "[Client/Msg] 清空会话消息服务器错误，错误码: {}, 错误信息: {}",
                    err_code, err_msg
                );
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client/Msg] ✅ 清空会话消息成功");
        Ok(())
    }

    /// 标记会话为已读（设置 hasReadSeq，并可附带指定 seqs）
    pub async fn mark_conversation_as_read(
        &self,
        conversation_id: String,
        has_read_seq: i64,
        seqs: Vec<i64>,
    ) -> Result<()> {
        let url = format!("{}/msg/mark_conversation_as_read", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "userID": self.config.user_id,
            "hasReadSeq": has_read_seq,
            "seqs": seqs,
        });

        info!(
            "[Client/Msg] 📡 标记会话已读: conversationID={}, hasReadSeq={}",
            conversation_id, has_read_seq
        );

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;

        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            error!(
                "[Client/Msg] 标记会话已读请求失败，HTTP状态: {}, 响应: {}",
                status, text
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }

        let json_value: serde_json::Value = serde_json::from_str(&text)?;
        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value
                    .get("errMsg")
                    .and_then(|v| v.as_str())
                    .unwrap_or("未知错误");
                error!(
                    "[Client/Msg] 标记会话已读服务器错误，错误码: {}, 错误信息: {}",
                    err_code, err_msg
                );
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client/Msg] ✅ 标记会话已读成功");
        Ok(())
    }

    #[allow(
        dead_code,
        clippy::manual_range_contains,
        clippy::manual_range_contains
    )]
    fn get_content_type_name(content_type: i32) -> &'static str {
        use openim_protocol::constant;

        match content_type {
            // 普通消息
            constant::TEXT => "[TEXT]",
            constant::PICTURE => "[PICTURE]",
            constant::VOICE => "[VOICE]",
            constant::VIDEO => "[VIDEO]",
            constant::FILE => "[FILE]",
            constant::AT_TEXT => "[@TEXT]",
            constant::MERGER => "[MERGER]",
            constant::CARD => "[CARD]",
            constant::LOCATION => "[LOCATION]",
            constant::CUSTOM => "[CUSTOM]",
            constant::REVOKE => "[REVOKE]",
            constant::TYPING => "[TYPING]",
            constant::QUOTE => "[QUOTE]",
            constant::ADVANCED_TEXT => "[ADVANCED_TEXT]",
            constant::MARKDOWN_TEXT => "[MARKDOWN_TEXT]",
            constant::CUSTOM_NOT_TRIGGER_CONVERSATION => "[CUSTOM_NOT_TRIGGER_CONVERSATION]",
            constant::CUSTOM_ONLINE_ONLY => "[CUSTOM_ONLINE_ONLY]",
            constant::REACTION_MESSAGE_MODIFIER => "[REACTION_MODIFIER]",
            constant::REACTION_MESSAGE_DELETER => "[REACTION_DELETER]",

            // 通用消息类型
            constant::COMMON => "[COMMON]",
            constant::GROUP_MSG => "[GROUP_MSG]",
            constant::SIGNAL_MSG => "[SIGNAL_MSG]",
            constant::CUSTOM_NOTIFICATION => "[CUSTOM_NOTIFICATION]",

            // 好友相关通知
            constant::FRIEND_APPLICATION_APPROVED_NOTIFICATION => "[FRIEND_APPLICATION_APPROVED]",
            constant::FRIEND_APPLICATION_REJECTED_NOTIFICATION => "[FRIEND_APPLICATION_REJECTED]",
            constant::FRIEND_APPLICATION_NOTIFICATION => "[FRIEND_APPLICATION]",
            constant::FRIEND_ADDED_NOTIFICATION => "[FRIEND_ADDED]",
            constant::FRIEND_DELETED_NOTIFICATION => "[FRIEND_DELETED]",
            constant::FRIEND_REMARK_SET_NOTIFICATION => "[FRIEND_REMARK_SET]",
            constant::BLACK_ADDED_NOTIFICATION => "[BLACK_ADDED]",
            constant::BLACK_DELETED_NOTIFICATION => "[BLACK_DELETED]",
            constant::FRIEND_INFO_UPDATED_NOTIFICATION => "[FRIEND_INFO_UPDATED]",
            constant::FRIENDS_INFO_UPDATE_NOTIFICATION => "[FRIENDS_INFO_UPDATE]",

            // 会话 & 用户通知
            constant::CONVERSATION_CHANGE_NOTIFICATION => "[CONVERSATION_CHANGE]",
            constant::USER_INFO_UPDATED_NOTIFICATION => "[USER_INFO_UPDATED]",
            constant::USER_STATUS_CHANGE_NOTIFICATION => "[USER_STATUS_CHANGE]",

            // 群相关通知（只列常见的几种）
            constant::GROUP_CREATED_NOTIFICATION => "[GROUP_CREATED]",
            constant::GROUP_INFO_SET_NOTIFICATION => "[GROUP_INFO_SET]",
            constant::JOIN_GROUP_APPLICATION_NOTIFICATION => "[JOIN_GROUP_APPLICATION]",
            constant::MEMBER_QUIT_NOTIFICATION => "[MEMBER_QUIT]",
            constant::GROUP_APPLICATION_ACCEPTED_NOTIFICATION => "[GROUP_APPLICATION_ACCEPTED]",
            constant::GROUP_APPLICATION_REJECTED_NOTIFICATION => "[GROUP_APPLICATION_REJECTED]",
            constant::GROUP_OWNER_TRANSFERRED_NOTIFICATION => "[GROUP_OWNER_TRANSFERRED]",
            constant::MEMBER_KICKED_NOTIFICATION => "[MEMBER_KICKED]",
            constant::MEMBER_INVITED_NOTIFICATION => "[MEMBER_INVITED]",
            constant::MEMBER_ENTER_NOTIFICATION => "[MEMBER_ENTER]",
            constant::GROUP_DISMISSED_NOTIFICATION => "[GROUP_DISMISSED]",

            // 已读回执
            constant::HAS_READ_RECEIPT => "[HAS_READ_RECEIPT]",

            // 大类兜底：通知 / 普通消息
            _ if content_type >= constant::NOTIFICATION_BEGIN
                && content_type <= constant::NOTIFICATION_END =>
            {
                "[NOTIFICATION]"
            }
            _ if content_type >= constant::CONTENT_TYPE_BEGIN
                && content_type < constant::NOTIFICATION_BEGIN =>
            {
                "[MESSAGE]"
            }
            _ => "[UNKNOWN]",
        }
    }
}

// 允许未使用的辅助方法（日志解析/调试）
#[allow(dead_code, clippy::manual_range_contains, clippy::single_match)]
#[cfg(test)]
mod tests {
    use tracing::{error, info, warn};

    use super::{ClientConfig, OpenIMClient};
    use crate::im::advanced_msg_listener::AdvancedMsgListener;
    use crate::im::auth::login_async;
    use crate::im::conversation::ConversationListener;
    use crate::im::friend::FriendListener;
    use std::sync::{Arc, Once};

    static INIT_LOGGER: Once = Once::new();

    fn init_test_logger() {
        INIT_LOGGER.call_once(|| {
            use tracing_subscriber::prelude::*;
            use tracing_subscriber::EnvFilter;

            // 测试中默认打开当前 crate 和 sqlx 的 debug，关闭底层 HTTP 客户端的 debug 噪音
            let filter_layer = EnvFilter::new(
                "info,rust_lib_flutter_rust_demo=debug,sqlx=debug,hyper_util::client=info,reqwest=info",
            );

            let fmt_layer = tracing_subscriber::fmt::layer()
                .with_file(true)        // 包含文件名
                .with_line_number(true) // 包含行号
                .with_target(false)     // 不显示 target（可选，减少噪音）
                .with_test_writer();

            tracing_subscriber::registry()
                .with(filter_layer)
                .with(fmt_layer)
                .init();
        });
    }

    #[tokio::test]
    #[ignore]
    async fn run_openim_client() {
        // 配置测试环境下的 debug 日志（trace）
        init_test_logger();

        // 先登录获取 token
        info!("🔐 正在登录获取 token...");
        let token_info = match login_async(
            "+86".to_string(),
            "17764338283".to_string(),
            "284f3d09ea0695538e4ded1c1766d73a".to_string(),
            5,
        )
        .await
        {
            Ok(info) => {
                info!("✅ 登录成功！");
                info
            }
            Err(e) => {
                error!("登录失败: {}", e);
                return;
            }
        };

        // 解析 token（如果登录成功）
        let (user_id, im_token) = if let Some(data) = &token_info.data {
            (data.user_id.clone(), data.im_token.clone())
        } else {
            ("".to_string(), "".to_string())
        };

        let config = ClientConfig::new(user_id.clone(), im_token, 5);
        let mut client = OpenIMClient::new(config);

        // 设置会话监听器
        struct TestConversationListener;
        #[async_trait::async_trait]
        impl ConversationListener for TestConversationListener {
            async fn on_sync_server_start(&self, reinstalled: bool) {
                info!("[回调/会话] 🔄 同步服务器开始: reinstalled={}", reinstalled);
            }

            async fn on_sync_server_finish(&self, reinstalled: bool) {
                info!("[回调/会话] ✅ 同步服务器完成: reinstalled={}", reinstalled);
            }

            async fn on_sync_server_progress(&self, progress: i32) {
                info!("[回调/会话] 📊 同步服务器进度: {}%", progress);
            }

            async fn on_sync_server_failed(&self, reinstalled: bool) {
                error!("[回调/会话] ❌ 同步服务器失败: reinstalled={}", reinstalled);
            }

            async fn on_new_conversation(&self, conversation_list: String) {
                info!("[回调/会话] 🆕 新会话: {}", conversation_list);
            }

            async fn on_conversation_changed(&self, conversation_list: String) {
                info!("[回调/会话] 🔄 会话变更: {}", conversation_list);
            }

            async fn on_total_unread_message_count_changed(&self, total_unread_count: i32) {
                info!(
                    "[回调/会话] 📬 总未读消息数变更: {} (同步未读数成功)",
                    total_unread_count
                );
            }

            async fn on_conversation_user_input_status_changed(&self, change: String) {
                info!("[回调/会话] ⌨️ 会话用户输入状态变更: {}", change);
            }
        }
        client.set_conversation_listener(Arc::new(TestConversationListener));

        // 设置好友监听器
        struct TestFriendListener;
        #[async_trait::async_trait]
        impl FriendListener for TestFriendListener {
            async fn on_friend_list_changed(&self, friends_json: String) {
                info!("[回调/好友] 👥 好友列表变更: {}", friends_json);
            }

            async fn on_black_list_changed(&self, blacks_json: String) {
                info!("[回调/好友] 🚫 黑名单列表变更: {}", blacks_json);
            }

            async fn on_friend_request_list_changed(&self, requests_json: String) {
                info!("[回调/好友] 📝 好友申请列表变更: {}", requests_json);
            }
        }
        client.set_friend_listener(Arc::new(TestFriendListener));

        // 设置高级消息监听器
        struct TestAdvancedMsgListener;
        #[async_trait::async_trait]
        impl AdvancedMsgListener for TestAdvancedMsgListener {
            async fn on_recv_new_message(&self, message: String) {
                info!("[回调/消息] 📨 OnRecvNewMessage: {}", message);
            }

            async fn on_recv_c2c_read_receipt(&self, msg_receipt_list: String) {
                info!("[回调/消息] 📖 OnRecvC2CReadReceipt: {}", msg_receipt_list);
            }

            async fn on_new_recv_message_revoked(&self, message_revoked: String) {
                info!(
                    "[回调/消息] 🗑️ OnNewRecvMessageRevoked: {}",
                    message_revoked
                );
            }

            async fn on_recv_offline_new_message(&self, message: String) {
                info!("[回调/消息] 📬 OnRecvOfflineNewMessage: {}", message);
            }

            async fn on_msg_deleted(&self, message: String) {
                info!("[回调/消息] 🗑️ OnMsgDeleted: {}", message);
            }

            async fn on_recv_online_only_message(&self, message: String) {
                info!("[回调/消息] 💬 OnRecvOnlineOnlyMessage: {}", message);
            }

            async fn on_kicked_offline(&self) {
                warn!("[回调/消息] ⚠️ OnKickedOffline: 被踢下线");
            }

            async fn on_connection_status_changed(&self, connected: bool, message: String) {
                if connected {
                    info!(
                        "[回调/消息] 🔗 OnConnectionStatusChanged: 已连接 - {}",
                        message
                    );
                } else {
                    warn!(
                        "[回调/消息] 🔗 OnConnectionStatusChanged: 断开 - {}",
                        message
                    );
                }
            }

            async fn on_recv_typing_status(&self, typing_info: String) {
                info!("[回调/消息] ⌨️ OnRecvTypingStatus: {}", typing_info);
            }
        }
        client.set_advanced_msg_listener(Arc::new(TestAdvancedMsgListener));

        // 连接到服务器（内部会自动启动消息处理）
        match client.connect().await {
            Ok(_) => {
                info!("✅ WebSocket 连接成功！");
            }
            Err(e) => {
                error!("连接失败: {}", e);
                return;
            }
        }

        // 克隆 client 和 user_id 用于发送消息
        let client_for_send = client.clone();
        let recv_id = "7226915075".to_string();

        // 启动发送消息任务（延迟 3 秒后发送，确保连接稳定）
        tokio::spawn(async move {
            tokio::time::sleep(std::time::Duration::from_secs(3)).await;
            // 发送测试消息（单聊，发送给自己）
            info!("📤 准备发送测试消息...");
            match client_for_send
                .send_text_message(
                    recv_id.clone(), // 接收者 ID（发送给自己）
                    "Hello from Rust client!".to_string(),
                    1, // 单聊
                )
                .await
            {
                Ok(_) => {
                    info!("✅ 消息发送成功！");
                }
                Err(e) => {
                    error!("消息发送失败: {}", e);
                }
            }

            match client_for_send
                .send_text_message(
                    recv_id,
                    "这是第二条测试消息".to_string(),
                    1, // 单聊
                )
                .await
            {
                Ok(_) => {
                    info!("✅ 第二条消息发送成功！");
                }
                Err(e) => {
                    error!("第二条消息发送失败: {}", e);
                }
            }
        });

        // 保持主任务运行，让消息处理任务继续执行
        info!("📥 客户端运行中，等待消息推送...");

        // 所有消息事件已通过 AdvancedMsgListener 回调处理，无需订阅 channel
        // 保持主任务运行
        tokio::time::sleep(std::time::Duration::from_secs(3600)).await;
    }
}
