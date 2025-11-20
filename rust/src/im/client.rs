//! OpenIM 客户端核心实现模块（内部使用）
//!
//! 此模块包含 OpenIM 客户端的核心逻辑实现。
//! **重要：此模块中的所有类型和方法都不会被 flutter_rust_bridge 识别，不会生成 Dart 桥接代码。**
//!
//! 对外暴露的接口请使用 `bridge_client.rs` 中的 `OpenIMBridgeClient`。

use crate::im::serialization::{compress_gzip, decompress_gzip, generate_msg_id};
use crate::im::types::{msg_type, MessageEvent, OpenIMResp, ServerResponse};
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
        }
    }
}

/// OpenIM 客户端（内部使用，不对外暴露）
///
/// 核心 IM 逻辑实现，通过 OpenIMBridgeClient 对外暴露。
/// 此类型及其所有方法都不会被 flutter_rust_bridge 识别，不会生成 Dart 桥接代码。
#[derive(Clone)]
pub struct OpenIMClient {
    config: ClientConfig,
    writer: Option<Arc<Mutex<WsWriter>>>,
    received_msg_ids: Arc<std::sync::Mutex<std::collections::HashSet<String>>>,
    // Rust 端订阅（通过 mpsc channel）
    rust_subscribers: Arc<std::sync::Mutex<Vec<mpsc::UnboundedSender<MessageEvent>>>>,
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
        println!("📡 消息事件订阅已激活 (Rust)");
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

        println!("🔗 连接到 OpenIM Server...");
        println!("   用户: {}", self.config.user_id);
        println!("   平台: {}", self.config.platform_id);

        let (ws_stream, response) = connect_async(&url).await?;
        println!("✅ WebSocket 连接成功! 状态: {}", response.status());

        let (write, mut read) = ws_stream.split();
        let writer = Arc::new(Mutex::new(write));
        self.writer = Some(writer.clone());

        // 等待连接成功响应
        if let Some(Ok(WsMessage::Text(text))) = read.next().await {
            if let Ok(resp) = serde_json::from_str::<ServerResponse>(&text) {
                if resp.err_code == 0 {
                    println!("✅ 服务器响应成功\n");
                    self.emit_event(MessageEvent::ConnectionStatus {
                        connected: true,
                        message: "连接成功".to_string(),
                    });
                } else {
                    return Err(anyhow::anyhow!("服务器错误: {}", resp.err_msg));
                }
            }
        }

        println!("💓 启动心跳...");
        println!("📥 开始监听...\n");

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
                println!("消息处理错误: {}", e);
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
        use openim_protocol::sdkws;
        use std::collections::HashMap;

        println!("🔧 构造消息...");

        let now = chrono::Utc::now().timestamp_millis();
        let client_msg_id = generate_msg_id(&self.config.user_id);

        // 构造消息内容
        let content_json = serde_json::json!({
            "content": text.clone()
        });
        let content_str = serde_json::to_string(&content_json)?;

        println!("   消息 ID: {}", client_msg_id);
        println!("   Content: {}", content_str);

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
            content_type: 101, // Text
            content: content_str.into_bytes(),
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
        println!("   Protobuf: {} bytes", pb_data.len());

        // 发送请求
        self.send_request(msg_type::WS_SEND_MSG, pb_data).await?;

        println!("✅ 消息已发送，等待响应...");
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

        println!("   请求结构:");
        println!("     reqIdentifier: {}", req.req_identifier);
        println!("     sendID: {}", req.send_id);
        println!("     operationID: {}", operation_id);
        println!("     data 长度: {} bytes", req.data.len());

        let json = serde_json::to_vec(&req)?;
        println!("   JSON 大小: {} bytes", json.len());

        // 压缩 JSON
        let compressed = compress_gzip(&json)?;
        println!(
            "   压缩后大小: {} bytes (压缩率: {:.1}%)",
            compressed.len(),
            (compressed.len() as f64 / json.len() as f64) * 100.0
        );

        let mut w = writer.lock().await;
        w.send(WsMessage::Binary(compressed)).await?;

        println!("   ✅ WebSocket 发送成功");
        Ok(())
    }

    /// 处理接收消息（事件循环）
    async fn handle_messages(&self, mut read: WsReader) -> Result<()> {
        while let Some(msg_result) = read.next().await {
            match msg_result {
                Ok(WsMessage::Text(text)) => {
                    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text) {
                        if let Some(req_id) = json.get("reqIdentifier") {
                            println!("\n📨 文本响应: reqId={}", req_id);
                        }
                    }
                }
                Ok(WsMessage::Binary(data)) => {
                    self.handle_binary_message(data).await;
                }
                Ok(WsMessage::Ping(_)) | Ok(WsMessage::Pong(_)) => {}
                Ok(WsMessage::Close(frame)) => {
                    println!("\n👋 连接关闭: {:?}", frame);
                    break;
                }
                Err(e) => {
                    println!("\n❌ 错误: {}", e);
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
                    println!("\n❌ 解压失败: {}", e);
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
                println!("\n❌ JSON 解析失败: {}", e);
                return;
            }
        };

        // 处理不同类型
        match resp.req_identifier {
            msg_type::WS_PUSH_MSG => {
                self.handle_push_message(&resp.data);
            }
            msg_type::WS_SEND_MSG => {
                println!("\n✅ 消息发送响应:");
                let (success, server_msg_id, client_msg_id) = if resp.err_code == 0 {
                    println!("   发送成功");
                    if let Ok(send_resp) = openim_protocol::msg::SendMsgResp::decode(&resp.data[..])
                    {
                        println!("   服务器消息ID: {}", send_resp.server_msg_id);
                        println!("   客户端消息ID: {}", send_resp.client_msg_id);
                        (true, send_resp.server_msg_id, send_resp.client_msg_id)
                    } else {
                        (true, String::new(), String::new())
                    }
                } else {
                    println!("   发送失败: {}", resp.err_msg);
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
                println!("\n⚠️ 被踢下线");
                self.emit_event(MessageEvent::KickedOffline);
            }
            _ => {
                println!("\n📨 消息类型: {}", resp.req_identifier);
                self.emit_event(MessageEvent::Other {
                    req_identifier: resp.req_identifier,
                    message: format!("未知消息类型: {}", resp.req_identifier),
                });
            }
        }
    }

    fn handle_push_message(&self, data: &[u8]) {
        use openim_protocol::sdkws;

        if data.is_empty() {
            return;
        }

        let push_msg = match sdkws::PushMessages::decode(data) {
            Ok(pm) => pm,
            Err(e) => {
                println!("\n❌ Protobuf 解析失败: {}", e);
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
            }
        }

        // 处理通知
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
            }
        }
    }

    fn is_duplicate_message(&self, msg_id: &str) -> bool {
        let mut set = self.received_msg_ids.lock().unwrap();
        !set.insert(msg_id.to_string())
    }
 

    fn get_content_type_name(content_type: i32) -> &'static str {
        match content_type {
            101 => "文本",
            102 => "图片",
            103 => "语音",
            104 => "视频",
            1201 => "好友申请通过",
            1203 => "好友申请",
            1204 => "好友添加",
            1501 => "群创建",
            1504 => "成员退出",
            1508 => "成员被踢",
            2200 => "已读回执",
            _ => "其他",
        }
    }

    fn parse_content(msg: &openim_protocol::sdkws::MsgData) {
        if msg.content.is_empty() {
            println!("  (空)");
            return;
        }

        let content_str = match String::from_utf8(msg.content.clone()) {
            Ok(s) => s,
            Err(_) => {
                println!("  [二进制 {} bytes]", msg.content.len());
                return;
            }
        };

        // 通知类型
        if msg.content_type >= 1000 {
            if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content_str) {
                if let Some(detail_str) = json.get("detail").and_then(|v| v.as_str()) {
                    if msg.content_type == 2200 {
                        // 已读回执
                        if let Ok(detail) = serde_json::from_str::<serde_json::Value>(detail_str) {
                            println!("  📖 已读回执:");
                            if let Some(seq) = detail.get("hasReadSeq").and_then(|v| v.as_i64()) {
                                println!("     已读到: seq {}", seq);
                            }
                        }
                    } else {
                        // 其他通知
                        if let Ok(detail) = serde_json::from_str::<serde_json::Value>(detail_str) {
                            if let Ok(pretty) = serde_json::to_string_pretty(&detail) {
                                for line in pretty.lines() {
                                    println!("    {}", line);
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
                    println!("  💬 \"{}\"", text);
                }
            } else {
                println!("  {}", content_str);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{ClientConfig, OpenIMClient};
    use crate::im::auth::login_async;

    #[tokio::test]
    #[ignore]
    async fn run_openim_client() {
        // 先登录获取 token
        println!("🔐 正在登录获取 token...\n");
        let token_info = match login_async(
            "+86".to_string(),
            "17764008284".to_string(),
            "284f3d09ea0695538e4ded1c1766d73a".to_string(),
            5,
        )
        .await
        {
            Ok(info) => {
                println!("✅ 登录成功！\n");
                info
            }
            Err(e) => {
                println!("❌ 登录失败: {}\n", e);
                return;
            }
        };

        // 解析 token（如果登录成功）
        let (user_id, im_token) = if !token_info.is_empty() {
            if let Ok(json) = serde_json::from_str::<serde_json::Value>(&token_info) {
                let user_id = json["userID"].as_str().unwrap_or("").to_string();
                let im_token = json["imToken"].as_str().unwrap_or("").to_string();
                (user_id, im_token)
            } else {
                ("".to_string(), "".to_string())
            }
        } else {
            ("".to_string(), "".to_string())
        };

        let config = ClientConfig::new(user_id.clone(), im_token, 5);
        let mut client = OpenIMClient::new(config);

        // 连接到服务器（内部会自动启动消息处理）
        match client.connect().await {
            Ok(_) => {
                println!("✅ WebSocket 连接成功！\n");
            }
            Err(e) => {
                println!("连接失败: {}", e);
                return;
            }
        }

        // 克隆 client 和 user_id 用于发送消息
        let client_for_send = client.clone();
        let recv_id = "4937393320".to_string();

        // 启动发送消息任务（延迟 3 秒后发送，确保连接稳定）
        tokio::spawn(async move {
            // 发送测试消息（单聊，发送给自己）
            println!("\n📤 准备发送测试消息...");
            match client_for_send
                .send_text_message(
                    recv_id.clone(), // 接收者 ID（发送给自己）
                    "Hello from Rust client!".to_string(),
                    1, // 单聊
                )
                .await
            {
                Ok(_) => {
                    println!("✅ 消息发送成功！");
                }
                Err(e) => {
                    println!("❌ 消息发送失败: {}", e);
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
                    println!("✅ 第二条消息发送成功！");
                }
                Err(e) => {
                    println!("❌ 第二条消息发送失败: {}", e);
                }
            }
        });

        // 保持主任务运行，让消息处理任务继续执行
        println!("📥 客户端运行中，等待消息推送...\n");

        // 订阅消息事件（Rust 端）
        let mut receiver = client.subscribe_messages();
        while let Some(event) = receiver.recv().await {
            match event {
                crate::im::types::MessageEvent::NewMessage {
                    conversation_id,
                    message,
                    ..
                } => {
                    println!("📨 收到消息:------------");
                    println!("   会话ID: {}", conversation_id);
                    println!(
                        "   发送者: {} -> 接收者: {}",
                        message.send_id, message.recv_id
                    );
                    println!("   内容类型: {}", message.content_type);

                    use openim_protocol::constant;
                    if message.content_type == constant::TEXT {
                      let text_elem: crate::im::msg::TextElem = match serde_json::from_slice(&message.content) {
                            Ok(elem) => {
                                elem
                            },
                            Err(e) => {
                                println!("   解析 TextElem 失败: {}", e);
                                // 可以根据需要选择 continue 或 default
                                crate::im::msg::TextElem { content: String::new() }
                            }
                        };
                        println!("   内容: {}", text_elem.content);

                    }
                }
                _ => {}
            }
        }
    }
}
