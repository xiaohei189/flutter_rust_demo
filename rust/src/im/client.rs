//! OpenIM 客户端核心实现模块（内部使用）
//!
//! 此模块包含 OpenIM 客户端的核心逻辑实现。
//! **重要：此模块中的所有类型和方法都不会被 flutter_rust_bridge 识别，不会生成 Dart 桥接代码。**
//!
//! 对外暴露的接口请使用 `bridge_client.rs` 中的 `OpenIMBridgeClient`。

use crate::im::serialization::{compress_gzip, decompress_gzip, generate_msg_id};
use crate::im::types::{msg_type, MessageEvent, OpenIMResp, ServerResponse};
use crate::im::conversation::{
    ConversationSyncer, ConversationSyncerConfig, EmptyConversationListener, LocalConversation,
};
use crate::im::friend::{FriendSyncer, FriendSyncerConfig, LocalFriend};
use crate::im::msg::{PictureElem, SoundElem, VideoElem, FileElem};
use openim_protocol::constant;
use tracing::{debug, error, info, warn};
use anyhow::Result;
use futures_util::stream::{SplitSink, SplitStream};
use futures_util::{SinkExt, StreamExt};
use openim_protocol::Message as ProtobufMessage;
use std::sync::Arc;
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::sync::{mpsc, Mutex};
use tokio::time::interval;
use tokio_tungstenite::MaybeTlsStream;
use tokio_tungstenite::WebSocketStream;
use tokio_tungstenite::{connect_async, tungstenite::Message as WsMessage};

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
    // Rust 端订阅（通过 mpsc channel）
    rust_subscribers: Arc<std::sync::Mutex<Vec<mpsc::UnboundedSender<MessageEvent>>>>,
    // 会话同步器（用于基于消息通知实时更新会话）
    pub(crate) conversation_syncer: Option<Arc<ConversationSyncer>>,
    // 好友同步器（用于联系人列表增量同步）
    pub(crate) friend_syncer: Option<Arc<FriendSyncer>>,
}

impl OpenIMClient {
    /// 创建新的客户端
    /// - `config`: 客户端配置
    pub fn new(config: ClientConfig) -> Self {
        Self {
            config,
            writer: None,
            received_msg_ids: Arc::new(std::sync::Mutex::new(std::collections::HashSet::new())),
            rust_subscribers: Arc::new(std::sync::Mutex::new(Vec::new())),
            conversation_syncer: None,
            friend_syncer: None,
        }
    }

    /// 订阅消息事件（Rust 端使用）
    ///
    /// 使用 Rust 原生的 channel 方式订阅消息事件。
    /// 返回一个 `mpsc::UnboundedReceiver<MessageEvent>`，可以在 Rust 代码中接收事件。
    ///
    /// # 示例
    ///
    /// ```rust
    /// let mut receiver = client.subscribe_messages_rust();
    /// tokio::spawn(async move {
    ///     while let Some(event) = receiver.recv().await {
    ///         match event {
    ///             MessageEvent::NewMessage { conversation_id, message, .. } => {
    ///                 println!("收到消息: {} -> {}", message.send_id, message.recv_id);
    ///             }
    ///             _ => {}
    ///         }
    ///     }
    /// });
    /// ```
    pub fn subscribe_messages(&self) -> mpsc::UnboundedReceiver<MessageEvent> {
        let (tx, rx) = mpsc::unbounded_channel();
        let mut subscribers = self.rust_subscribers.lock().unwrap();
        subscribers.push(tx);
        debug!("📡 消息事件订阅已激活 (Rust)");
        rx
    }

    /// 发送事件到所有订阅者（仅 Rust 端）
    fn emit_event(&self, event: MessageEvent) {
        // 发送到 Rust 端订阅者（mpsc channel）
        let mut subscribers = self.rust_subscribers.lock().unwrap();
        subscribers.retain(|sender| sender.send(event.clone()).is_ok());
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
                    self.emit_event(MessageEvent::ConnectionStatus {
                        connected: true,
                        message: "连接成功".to_string(),
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
            ConversationSyncer::with_listener(cfg, Arc::new(EmptyConversationListener)).await?
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
        let friend_syncer = Arc::new(FriendSyncer::new(friend_cfg).await?);
        self.friend_syncer = Some(friend_syncer.clone());

        tokio::spawn(async move {
            info!("[Client/Friend] 🔄 启动好友增量同步任务");
            let result = friend_syncer.incr_sync_friends().await;
            match result {
                Ok(_) => info!("[Client/Friend] ✅ 好友同步完成"),
                Err(e) => error!("[Client/Friend] ❌ 好友同步失败: {e}"),
            }
        });

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
        )
        .await
    }

    /// 通用发送富媒体消息（按 content_type + content bytes）
    async fn send_rich_message(
        &self,
        recv_id: String,
        session_type: i32,
        content_type: i32,
        content: Vec<u8>,
    ) -> Result<()> {
        use openim_protocol::sdkws;
        use std::collections::HashMap;

        let now = chrono::Utc::now().timestamp_millis();
        let client_msg_id = generate_msg_id(&self.config.user_id);

        debug!("[Client/Msg]   消息 ID: {}", client_msg_id);
        debug!("[Client/Msg]   ContentType: {}", content_type);

        // 构造 options
        let mut options = HashMap::new();
        options.insert("history".to_string(), true);
        options.insert("persistent".to_string(), true);
        options.insert("senderSync".to_string(), true);
        options.insert("conversationUpdate".to_string(), true);
        options.insert("senderConversationUpdate".to_string(), true);
        options.insert("unreadCount".to_string(), true);
        options.insert("offlinePush".to_string(), true);

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
            msg_from: 100,     // UserMsgType
            content_type,
            content,
            seq: 0,
            send_time: 0,
            create_time: now,
            status: 1,
            is_read: false,
            options,
            offline_push_info: None,
            at_user_id_list: vec![],
            attached_info: String::new(),
            ex: String::new(),
        };

        // 序列化为 protobuf
        let mut pb_data = Vec::new();
        msg_data.encode(&mut pb_data)?;
        debug!("[Client/Msg]   Protobuf 大小: {} bytes", pb_data.len());

        // 发送请求
        self.send_request(msg_type::WS_SEND_MSG, pb_data).await?;

        info!("✅ 消息已发送，等待响应");
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

        debug!("[Client/WS]   请求结构:");
        debug!("[Client/WS]     reqIdentifier: {}", req.req_identifier);
        debug!("[Client/WS]     sendID: {}", req.send_id);
        debug!("[Client/WS]     operationID: {}", operation_id);
        debug!(
            "[Client/WS]     data 长度: {} bytes",
            req.data.len()
        );

        let json = serde_json::to_vec(&req)?;
        debug!("[Client/WS]   JSON 大小: {} bytes", json.len());

        // 压缩 JSON
        let compressed = compress_gzip(&json)?;
        debug!(
            "[Client/WS]   压缩后大小: {} bytes (压缩率: {:.1}%)",
            compressed.len(),
            (compressed.len() as f64 / json.len() as f64) * 100.0
        );

        let mut w = writer.lock().await;
        w.send(WsMessage::Binary(compressed)).await?;

        debug!("[Client/WS]   ✅ WebSocket 发送成功");
        Ok(())
    }

    /// 处理接收消息（事件循环）
    async fn handle_messages(&self, mut read: WsReader) -> Result<()> {
        while let Some(msg_result) = read.next().await {
            match msg_result {
                Ok(WsMessage::Text(text)) => {
                    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text) {
                        if let Some(req_id) = json.get("reqIdentifier") {
                            info!("[Client/WS] 📨 文本响应: reqId={}", req_id);
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
                error!("[Client/WS] JSON 解析失败: {}", e);
                return;
            }
        };

        // 处理不同类型
        match resp.req_identifier {
            msg_type::WS_PUSH_MSG => {
                self.handle_push_message(&resp.data).await;
            }
            msg_type::WS_SEND_MSG => {
                info!("[Client/Msg] ✅ 收到消息发送响应");
                let (success, server_msg_id, client_msg_id) = if resp.err_code == 0 {
                    info!("[Client/Msg]   发送成功");
                    if let Ok(send_resp) = openim_protocol::msg::SendMsgResp::decode(&resp.data[..])
                    {
                        info!(
                            "[Client/Msg]   服务器消息ID: {}",
                            send_resp.server_msg_id
                        );
                        info!(
                            "[Client/Msg]   客户端消息ID: {}",
                            send_resp.client_msg_id
                        );
                        (true, send_resp.server_msg_id, send_resp.client_msg_id)
                    } else {
                        (true, String::new(), String::new())
                    }
                } else {
                    error!("[Client/Msg]   发送失败: {}", resp.err_msg);
                    (false, String::new(), String::new())
                };

                self.emit_event(MessageEvent::SendMessageResponse {
                    success,
                    err_msg: resp.err_msg,
                    server_msg_id,
                    client_msg_id,
                });
            }
            msg_type::WS_KICK_ONLINE_MSG => {
                warn!("[Client/WS] ⚠️ 被踢下线");
                self.emit_event(MessageEvent::KickedOffline);
            }
            _ => {
                debug!(
                    "[Client/WS] 📨 未知消息类型: {}",
                    resp.req_identifier
                );
                self.emit_event(MessageEvent::Other {
                    req_identifier: resp.req_identifier,
                    message: format!("未知消息类型: {}", resp.req_identifier),
                });
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
                // 直接使用 MsgData 发送事件
                self.emit_event(MessageEvent::NewMessage {
                    conversation_id: conv_id.clone(),
                    message: msg.clone(),
                    is_notification: false,
                });

                // 基于消息通知实时更新会话（未读数、最新消息等）
                if let Some(syncer) = &self.conversation_syncer {
                    if let Err(e) = syncer
                        .on_new_message(conv_id, msg, false)
                        .await
                    {
                        error!("[Client/Conv] on_new_message 更新会话失败: {}", e);
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
                // 直接使用 MsgData 发送事件
                self.emit_event(MessageEvent::NewMessage {
                    conversation_id: conv_id.clone(),
                    message: msg.clone(),
                    is_notification: true,
                });

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

                if let Some(syncer) = &self.conversation_syncer {
                    if let Err(e) = syncer
                        .on_new_message(conv_id, msg, true)
                        .await
                    {
                        error!(
                            "[Client/Conv] on_new_message 更新通知会话失败: {}",
                            e
                        );
                    }
                }
            }
        }
    }

    fn is_duplicate_message(&self, msg_id: &str) -> bool {
        let mut set = self.received_msg_ids.lock().unwrap();
        !set.insert(msg_id.to_string())
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

    // ===================== 消息管理相关 HTTP 能力 =====================

    /// 撤回消息（按会话 ID + seq）
    pub async fn revoke_message(&self, conversation_id: String, seq: i64) -> Result<()> {
        let url = format!("{}/msg/revoke_msg", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "seq": seq,
            "userID": self.config.user_id,
        });

        info!("[Client/Msg] 📡 撤回消息: conversationID={}, seq={}", conversation_id, seq);

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

        info!("[Client/Msg] 📡 删除消息: conversationID={}", conversation_id);

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

    fn parse_content(msg: &openim_protocol::sdkws::MsgData) {
        if msg.content.is_empty() {
            debug!("[Client/Msg]  内容为空");
            return;
        }

        let content_str = match String::from_utf8(msg.content.clone()) {
            Ok(s) => s,
            Err(_) => {
                debug!(
                    "[Client/Msg]  [二进制 {} bytes]",
                    msg.content.len()
                );
                return;
            }
        };

        // 通知类型
        if msg.content_type >= 1000 {
            if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content_str) {
                if let Some(detail_str) = json.get("detail").and_then(|v| v.as_str()) {
                    if msg.content_type == 2200 {
                        // 已读回执
                        if let Ok(detail) =
                            serde_json::from_str::<serde_json::Value>(detail_str)
                        {
                            info!("[Client/Msg]  📖 已读回执:");
                            if let Some(seq) =
                                detail.get("hasReadSeq").and_then(|v| v.as_i64())
                            {
                                info!("[Client/Msg]     已读到: seq {}", seq);
                            }
                        }
                    } else {
                        // 其他通知
                        if let Ok(detail) =
                            serde_json::from_str::<serde_json::Value>(detail_str)
                        {
                            if let Ok(pretty) = serde_json::to_string_pretty(&detail) {
                                for line in pretty.lines() {
                                    info!("[Client/Msg]    {}", line);
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // 普通消息
            if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content_str) {
                if let Some(text) = json.get("content").and_then(|v| v.as_str()) {
                    info!("[Client/Msg]  💬 \"{}\"", text);
                }
            } else {
                info!("[Client/Msg]  {}", content_str);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use tracing::{error, info};

    use super::{ClientConfig, OpenIMClient};
    use crate::im::auth::login_async;
    use std::sync::Once;

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
            "17764008284".to_string(),
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

        // 订阅消息事件（Rust 端）
        let mut receiver = client.subscribe_messages();
        while let Some(event) = receiver.recv().await {
            match event {
                crate::im::types::MessageEvent::NewMessage {
                    conversation_id,
                    message,
                    ..
                } => {
                    info!("📨 收到消息:------------");
                    info!("   会话ID: {}", conversation_id);
                    info!(
                        "   发送者: {} -> 接收者: {}",
                        message.send_id, message.recv_id
                    );
                    info!(
                        "   内容类型: {}",
                        super::OpenIMClient::get_content_type_name(message.content_type)
                    );

                    use openim_protocol::constant;
                    if message.content_type == constant::TEXT {
                      let text_elem: crate::im::msg::TextElem = match serde_json::from_slice(&message.content) {
                            Ok(elem) => {
                                elem
                            },
                            Err(e) => {
                                error!("   解析 TextElem 失败: {}", e);
                                crate::im::msg::TextElem { content: String::new() }
                            }
                        };
                        info!("   内容: {}", text_elem.content);

                    }
                }
                _ => {}
            }
        }
    }
}
