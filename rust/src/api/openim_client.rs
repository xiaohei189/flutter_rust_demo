use tokio_tungstenite::{connect_async, tungstenite::Message as WsMessage};
use futures_util::{StreamExt, SinkExt, stream::{SplitSink, SplitStream}};
use serde::{Deserialize, Serialize};
use std::time::Duration;
use tokio::time::interval;
use openim_protocol::Message as ProtobufMessage;
use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use flate2::Compression;
use std::io::{Read, Write};
use std::sync::Arc;
use tokio::sync::Mutex;
use anyhow::Result;

/// 消息类型标识符
mod msg_type {
    pub const WS_GET_NEWEST_SEQ: i32 = 1001;
    pub const WS_SEND_MSG: i32 = 1003;
    pub const WS_PUSH_MSG: i32 = 2001;
    pub const WS_KICK_ONLINE_MSG: i32 = 2002;
    pub const WS_LOGOUT_MSG: i32 = 2003;
}

type WsWriter = SplitSink<
    tokio_tungstenite::WebSocketStream<tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>>,
    WsMessage,
>;
type WsReader = SplitStream<
    tokio_tungstenite::WebSocketStream<tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>>
>;

/// OpenIM 客户端
#[derive(Clone)]
pub struct OpenIMClient {
    pub user_id: String,
    pub token: String,
    pub platform_id: i32,
    pub ws_url: String,
    received_msg_ids: Arc<std::sync::Mutex<std::collections::HashSet<String>>>,
    writer: Option<Arc<Mutex<WsWriter>>>,
}

/// OpenIM 请求结构
#[derive(Debug, Serialize, Deserialize)]
struct OpenIMReq {
    #[serde(rename = "reqIdentifier")]
    req_identifier: i32,
    token: String,
    #[serde(rename = "sendID")]
    send_id: String,
    #[serde(rename = "operationID")]
    operation_id: String,
    #[serde(rename = "msgIncr")]
    msg_incr: String,
    #[serde(default)]
    data: Vec<u8>,
}

/// OpenIM 响应结构
#[derive(Debug, Deserialize, Serialize)]
struct OpenIMResp {
    #[serde(rename = "reqIdentifier")]
    req_identifier: i32,
    #[serde(rename = "msgIncr")]
    msg_incr: String,
    #[serde(rename = "operationID")]
    operation_id: String,
    #[serde(rename = "errCode")]
    err_code: i32,
    #[serde(rename = "errMsg")]
    err_msg: String,
    #[serde(default, deserialize_with = "deserialize_base64")]
    data: Vec<u8>,
}

fn deserialize_base64<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    use base64::Engine;
    let s: String = Deserialize::deserialize(deserializer)?;
    if s.is_empty() {
        return Ok(Vec::new());
    }
    base64::engine::general_purpose::STANDARD
        .decode(s)
        .map_err(serde::de::Error::custom)
}

#[derive(Debug, Deserialize)]
struct ServerResponse {
    #[serde(rename = "errCode")]
    err_code: i32,
    #[serde(rename = "errMsg")]
    err_msg: String,
}

impl OpenIMClient {
    pub fn new(user_id: String, token: String, platform_id: i32) -> Self {
        Self {
            user_id,
            token,
            platform_id,
            ws_url: "ws://localhost:10001".to_string(),
            received_msg_ids: Arc::new(std::sync::Mutex::new(std::collections::HashSet::new())),
            writer: None,
        }
    }

    fn build_url(&self, operation_id: &str) -> String {
        format!(
            "{}/?token={}&sendID={}&platformID={}&operationID={}&compression=gzip&isBackground=false&isMsgResp=true&sdkType=js",
            self.ws_url, self.token, self.user_id, self.platform_id, operation_id
        )
    }

    fn is_duplicate_message(&self, msg_id: &str) -> bool {
        let mut set = self.received_msg_ids.lock().unwrap();
        !set.insert(msg_id.to_string())
    }

    /// 连接到服务器并在内部启动消息处理
    pub async fn connect(&mut self) -> Result<()> {
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let url = self.build_url(&operation_id);

        println!("🔗 连接到 OpenIM Server...");
        println!("   用户: {}", self.user_id);
        println!("   平台: {}", self.platform_id);

        let (ws_stream, response) = connect_async(&url).await?;
        println!("✅ WebSocket 连接成功! 状态: {}", response.status());

        let (write, mut read) = ws_stream.split();
        self.writer = Some(Arc::new(Mutex::new(write)));

        // 等待连接成功响应
        if let Some(Ok(WsMessage::Text(text))) = read.next().await {
            if let Ok(resp) = serde_json::from_str::<ServerResponse>(&text) {
                if resp.err_code == 0 {
                    println!("✅ 服务器响应成功\n");
                } else {
                    return Err(anyhow::anyhow!("服务器错误: {}", resp.err_msg));
                }
            }
        }

        println!("💓 启动心跳...");
        println!("📥 开始监听...\n");

        // 启动心跳
        if let Some(writer) = self.writer.clone() {
            tokio::spawn(async move {
                let mut ticker = interval(Duration::from_secs(25));
                loop {
                    ticker.tick().await;
                    let mut w = writer.lock().await;
                    if w.send(WsMessage::Ping(vec![])).await.is_err() {
                        break;
                    }
                }
            });
        }

        // 在内部启动消息处理任务
        let client = self.clone();
        tokio::spawn(async move {
            if let Err(e) = client.handle_messages_internal(read).await {
                println!("消息处理错误: {}", e);
            }
        });

        Ok(())
    }

    /// 发送文本消息（参考 Go SDK 实现）
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
        let client_msg_id = self.generate_msg_id();

        // 构造消息内容（参考接收到的消息，使用 JSON 格式）
        let content_json = serde_json::json!({
            "content": text.clone()
        });
        let content_str = serde_json::to_string(&content_json)?;

        println!("   消息 ID: {}", client_msg_id);
        println!("   Content: {}", content_str);

        // 构造 options（参考 Go SDK 的默认值）
        let mut options = HashMap::new();
        options.insert("history".to_string(), true);
        options.insert("persistent".to_string(), true);
        options.insert("senderSync".to_string(), true);
        options.insert("conversationUpdate".to_string(), true);
        options.insert("senderConversationUpdate".to_string(), true);
        options.insert("unreadCount".to_string(), true);
        options.insert("offlinePush".to_string(), true);

        // 构造 MsgData（参考 Go SDK）
        let msg_data = sdkws::MsgData {
            send_id: self.user_id.clone(),
            recv_id: recv_id.clone(),
            group_id: if session_type == 2 { recv_id.clone() } else { String::new() },
            client_msg_id: client_msg_id.clone(),
            server_msg_id: String::new(),
            sender_platform_id: self.platform_id,
            sender_nickname: String::new(),
            sender_face_url: String::new(),
            session_type,
            msg_from: 100, // UserMsgType
            content_type: 101, // Text
            content: content_str.into_bytes(),
            seq: 0,
            send_time: 0, // 发送时由服务器设置
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

    /// 生成消息 ID（参考 Go SDK 的 GetMsgID）
    fn generate_msg_id(&self) -> String {
        use std::time::SystemTime;
        let nanos = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        format!("{}{}", self.user_id, nanos)
    }

    /// 发送请求
    async fn send_request(
        &self,
        req_identifier: i32,
        data: Vec<u8>,
    ) -> Result<()> {
        let writer = self.writer.as_ref()
            .ok_or_else(|| anyhow::anyhow!("未连接"))?;

        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        
        let req = OpenIMReq {
            req_identifier,
            token: self.token.clone(),
            send_id: self.user_id.clone(),
            operation_id: operation_id.clone(),
            msg_incr: String::new(), // 留空，让服务器处理
            data,
        };

        println!("   请求结构:");
        println!("     reqIdentifier: {}", req.req_identifier);
        println!("     sendID: {}", req.send_id);
        println!("     operationID: {}", operation_id);
        println!("     data 长度: {} bytes", req.data.len());

        let json = serde_json::to_vec(&req)?;
        println!("   JSON 大小: {} bytes", json.len());
        
        // 压缩 JSON（因为连接时指定了 compression=gzip）
        let compressed = Self::compress_gzip(&json)?;
        println!("   压缩后大小: {} bytes (压缩率: {:.1}%)", 
                 compressed.len(), 
                 (compressed.len() as f64 / json.len() as f64) * 100.0);
        
        let mut w = writer.lock().await;
        w.send(WsMessage::Binary(compressed)).await?;
        
        println!("   ✅ WebSocket 发送成功");
        Ok(())
    }

    /// 内部消息处理（事件循环）
    async fn handle_messages_internal(&self, mut read: WsReader) -> Result<()> {
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
            match Self::decompress_gzip(&data) {
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
                // 发送消息的响应
                println!("\n✅ 消息发送响应:");
                if resp.err_code == 0 {
                    println!("   发送成功");
                    // 解析 SendMsgResp
                    if let Ok(send_resp) = openim_protocol::msg::SendMsgResp::decode(&resp.data[..]) {
                        println!("   服务器消息ID: {}", send_resp.server_msg_id);
                        println!("   客户端消息ID: {}", send_resp.client_msg_id);
                    }
                } else {
                    println!("   发送失败: {}", resp.err_msg);
                }
            }
            msg_type::WS_KICK_ONLINE_MSG => {
                println!("\n⚠️ 被踢下线");
            }
            _ => {
                println!("\n📨 消息类型: {}", resp.req_identifier);
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
                self.print_msg_data(conv_id, msg, false);
            }
        }

        // 处理通知
        for (conv_id, pull_msgs) in &push_msg.notification_msgs {
            for msg in &pull_msgs.msgs {
                if self.is_duplicate_message(&msg.client_msg_id) {
                    continue;
                }
                self.print_msg_data(conv_id, msg, true);
            }
        }
    }

    fn print_msg_data(&self, conv_id: &str, msg: &openim_protocol::sdkws::MsgData, is_notification: bool) {
        let time_str = chrono::DateTime::from_timestamp_millis(msg.send_time)
            .map(|dt| dt.format("%H:%M:%S").to_string())
            .unwrap_or_else(|| "??:??:??".to_string());

        let icon = if is_notification { "🔔" } else { "💬" };

        println!("\n{} ═══════════════════════════════════", icon);
        println!("时间: {}", time_str);
        println!("会话: {}", conv_id);
        println!("发送者: {}", msg.send_id);
        println!("类型: {} ({})", Self::get_content_type_name(msg.content_type), msg.content_type);

        println!("\n【消息内容】:");
        self.parse_content(msg);
        println!("═══════════════════════════════════════\n");
    }

    fn get_content_type_name(content_type: i32) -> &'static str {
        match content_type {
            101 => "文本", 102 => "图片", 103 => "语音", 104 => "视频",
            1201 => "好友申请通过", 1203 => "好友申请", 1204 => "好友添加",
            1501 => "群创建", 1504 => "成员退出", 1508 => "成员被踢",
            2200 => "已读回执",
            _ => "其他",
        }
    }

    fn parse_content(&self, msg: &openim_protocol::sdkws::MsgData) {
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

    fn decompress_gzip(data: &[u8]) -> Result<Vec<u8>, std::io::Error> {
        let mut decoder = GzDecoder::new(data);
        let mut decompressed = Vec::new();
        decoder.read_to_end(&mut decompressed)?;
        Ok(decompressed)
    }

    /// 压缩数据为 gzip 格式
    fn compress_gzip(data: &[u8]) -> Result<Vec<u8>, std::io::Error> {
        let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(data)?;
        encoder.finish()
    }
}
