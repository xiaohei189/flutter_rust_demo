use tokio_tungstenite::{connect_async, tungstenite::Message as WsMessage};
use futures_util::{StreamExt, SinkExt};
use serde::{Deserialize, Serialize};
use std::time::Duration;
use tokio::time::interval;
use openim_protocol::Message as ProtobufMessage;
use flate2::read::GzDecoder;
use std::io::Read;

/// 消息类型标识符（对应服务器常量）
#[allow(dead_code)]
mod msg_type {
    pub const WS_GET_NEWEST_SEQ: i32 = 1001;
    pub const WS_PULL_MSG_BY_SEQ_LIST: i32 = 1002;
    pub const WS_SEND_MSG: i32 = 1003;
    pub const WS_SEND_SIGNAL_MSG: i32 = 1004;
    pub const WS_PULL_MSG: i32 = 1005;
    pub const WS_GET_CONV_MAX_READ_SEQ: i32 = 1006;
    pub const WS_PULL_CONV_LAST_MESSAGE: i32 = 1007;
    pub const WS_PUSH_MSG: i32 = 2001;
    pub const WS_KICK_ONLINE_MSG: i32 = 2002;
    pub const WS_LOGOUT_MSG: i32 = 2003;
    pub const WS_SET_BACKGROUND_STATUS: i32 = 2004;
}

/// OpenIM 客户端配置
pub struct OpenIMClient {
    pub user_id: String,
    pub token: String,
    pub platform_id: i32,
    pub ws_url: String,
    received_msg_ids: std::sync::Arc<std::sync::Mutex<std::collections::HashSet<String>>>,
}

/// OpenIM 请求结构（对应服务器的 Req）
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

/// OpenIM 响应结构（对应服务器的 Resp）
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

/// 自定义反序列化：从 base64 字符串解码为字节数组
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

/// 服务器初始响应
#[derive(Debug, Deserialize)]
struct ServerResponse {
    #[serde(rename = "errCode")]
    err_code: i32,
    #[serde(rename = "errMsg")]
    err_msg: String,
    #[serde(rename = "errDlt")]
    err_dlt: String,
}

impl OpenIMClient {
    pub fn new(user_id: String, token: String, platform_id: i32) -> Self {
        Self {
            user_id,
            token,
            platform_id,
            ws_url: "ws://localhost:10001".to_string(),
            received_msg_ids: std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashSet::new())),
        }
    }

    /// 构建 WebSocket 连接 URL
    fn build_url(&self, operation_id: &str) -> String {
        format!(
            "{}/?token={}&sendID={}&platformID={}&operationID={}&compression=gzip&isBackground=false&isMsgResp=true&sdkType=js",
            self.ws_url, self.token, self.user_id, self.platform_id, operation_id
        )
    }

    /// 检查消息是否已处理过（去重）
    fn is_duplicate_message(&self, msg_id: &str) -> bool {
        let mut set = self.received_msg_ids.lock().unwrap();
        !set.insert(msg_id.to_string())
    }

    /// 连接并运行客户端
    pub async fn connect_and_run(&self) -> Result<(), Box<dyn std::error::Error>> {
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let url = self.build_url(&operation_id);

        println!("🔗 连接到 OpenIM Server...");
        println!("   用户: {}", self.user_id);
        println!("   平台: {}", self.platform_id);

        let (ws_stream, response) = connect_async(&url).await?;
        println!("✅ WebSocket 连接成功! 状态: {}", response.status());

        let (mut write, mut read) = ws_stream.split();

        // 等待连接成功响应
        if let Some(Ok(WsMessage::Text(text))) = read.next().await {
            if let Ok(resp) = serde_json::from_str::<ServerResponse>(&text) {
                if resp.err_code == 0 {
                    println!("✅ 服务器响应成功");
                } else {
                    println!("❌ 服务器返回错误: {} - {}", resp.err_code, resp.err_msg);
                    return Ok(());
                }
            }
        }

        println!("\n💓 启动心跳...");
        println!("📥 监听消息...\n");

        // 启动心跳任务（静默）
        let heartbeat_task = tokio::spawn(async move {
            let mut ticker = interval(Duration::from_secs(25));
            loop {
                ticker.tick().await;
                if write.send(WsMessage::Ping(vec![])).await.is_err() {
                    break;
                }
            }
        });

        // 监听消息循环
        while let Some(msg_result) = read.next().await {
            match msg_result {
                Ok(WsMessage::Text(text)) => {
                    println!("\n📨 收到文本消息:");
                    println!("   {}", text);
                    
                    // 尝试解析为 OpenIMResp
                    if let Ok(resp) = serde_json::from_str::<OpenIMResp>(&text) {
                        println!("   请求标识: {}", resp.req_identifier);
                        println!("   错误码: {}", resp.err_code);
                        if !resp.data.is_empty() {
                            println!("   数据: {} bytes", resp.data.len());
                        }
                    }
                }
                Ok(WsMessage::Binary(data)) => {
                    // 步骤 1: 解压 gzip
                    let decompressed_data = if data.len() >= 2 && data[0] == 0x1f && data[1] == 0x8b {
                        match Self::decompress_gzip(&data) {
                            Ok(d) => d,
                            Err(e) => {
                                println!("\n❌ Gzip 解压失败: {}", e);
                                println!("   原始数据 ({} bytes): {:?}", data.len(), &data[..data.len().min(40)]);
                                continue;
                            }
                        }
                    } else {
                        data.to_vec()
                    };
                    
                    // 步骤 2: 解析 JSON
                    let resp = match serde_json::from_slice::<OpenIMResp>(&decompressed_data) {
                        Ok(r) => r,
                        Err(e) => {
                            println!("\n❌ JSON 解析失败: {}", e);
                            if let Ok(json_str) = String::from_utf8(decompressed_data.clone()) {
                                println!("   JSON 内容: {}", &json_str[..json_str.len().min(200)]);
                            } else {
                                println!("   数据 ({} bytes): {:?}", decompressed_data.len(), &decompressed_data[..decompressed_data.len().min(40)]);
                            }
                            continue;
                        }
                    };
                    
                    // 步骤 3: 根据消息类型处理
                    match resp.req_identifier {
                        msg_type::WS_PUSH_MSG => {
                            self.handle_push_message(&resp.data);
                        }
                        msg_type::WS_KICK_ONLINE_MSG => {
                            println!("\n⚠️ 踢下线消息");
                        }
                        msg_type::WS_LOGOUT_MSG => {
                            println!("\n🚪 登出消息");
                        }
                        _ => {
                            println!("\n📨 未知消息类型: {}", resp.req_identifier);
                        }
                    }
                }
                Ok(WsMessage::Ping(_)) => {
                    // Ping 静默处理
                }
                Ok(WsMessage::Pong(_)) => {
                    // Pong 静默处理
                }
                Ok(WsMessage::Close(frame)) => {
                    println!("\n👋 服务器关闭连接: {:?}", frame);
                    break;
                }
                Err(e) => {
                    println!("\n❌ 接收消息错误: {}", e);
                    break;
                }
                _ => {}
            }
        }

        // 取消心跳任务
        heartbeat_task.abort();
        
        println!("\n✅ 客户端已断开");
        Ok(())
    }

    /// 处理推送消息（使用 protocol 中的数据结构）
    fn handle_push_message(&self, data: &[u8]) {
        use openim_protocol::sdkws;
        
        if data.is_empty() {
            println!("⚠️ 推送消息数据为空");
            return;
        }

        // 解析为 PushMessages
        let push_msg = match sdkws::PushMessages::decode(data) {
            Ok(pm) => pm,
            Err(e) => {
                println!("\n❌ [Protobuf 解析失败] {}", e);
                println!("════════════════════════════════════");
                println!("数据长度: {} bytes", data.len());
                use base64::Engine;
                println!("Base64: {}", base64::engine::general_purpose::STANDARD.encode(data));
                println!("十六进制（前60字节）:");
                let hex: String = data.iter()
                    .take(60)
                    .map(|b| format!("{:02x}", b))
                    .collect::<Vec<_>>()
                    .chunks(20)
                    .map(|chunk| chunk.join(" "))
                    .collect::<Vec<_>>()
                    .join("\n  ");
                println!("  {}", hex);
                println!("════════════════════════════════════\n");
                return;
            }
        };
        
        // 处理普通消息
        for (conv_id, pull_msgs) in &push_msg.msgs {
            for msg in &pull_msgs.msgs {
                // 去重检查
                if self.is_duplicate_message(&msg.client_msg_id) {
                    continue;
                }
                self.print_msg_data(conv_id, msg, false);
            }
        }
        
        // 处理通知消息
        for (conv_id, pull_msgs) in &push_msg.notification_msgs {
            for msg in &pull_msgs.msgs {
                // 去重检查
                if self.is_duplicate_message(&msg.client_msg_id) {
                    continue;
                }
                self.print_msg_data(conv_id, msg, true);
            }
        }
    }

    /// 打印消息详情（详细版，带去重）
    fn print_msg_data(&self, conv_id: &str, msg: &openim_protocol::sdkws::MsgData, is_notification: bool) {
        // 时间格式化
        let time_str = chrono::DateTime::from_timestamp_millis(msg.send_time)
            .map(|dt| dt.format("%H:%M:%S").to_string())
            .unwrap_or_else(|| "??:??:??".to_string());
        
        // 消息类型标识
        let msg_icon = if is_notification { "🔔" } else { "💬" };
        
        println!("\n{} ═══════════════════════════════════", msg_icon);
        println!("时间: {}", time_str);
        println!("会话: {}", conv_id);
        println!("发送者: {} (平台:{})", msg.send_id, msg.sender_platform_id);
        
        // 内容类型
        let content_type = match msg.content_type {
            101 => "文本", 102 => "图片", 103 => "语音", 104 => "视频",
            105 => "文件", 106 => "@消息", 107 => "合并", 108 => "名片",
            109 => "位置", 110 => "自定义", 111 => "撤回", 113 => "引用",
            _ => "未知",
        };
        println!("类型: {} ({})", content_type, msg.content_type);
        
        // 解析并显示消息内容
        println!("\n【消息内容】:");
        if msg.content.is_empty() {
            println!("  (空)");
        } else if let Ok(content_str) = String::from_utf8(msg.content.clone()) {
            // 尝试解析 JSON
            if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content_str) {
                // 格式化 JSON
                if let Ok(pretty) = serde_json::to_string_pretty(&json) {
                    for line in pretty.lines() {
                        println!("  {}", line);
                    }
                } else {
                    println!("  {}", content_str);
                }
                
                // 如果有 content 字段，单独突出显示
                if let Some(text) = json.get("content").and_then(|v| v.as_str()) {
                    println!("\n💬 文本: \"{}\"", text);
                }
            } else {
                // 纯文本
                println!("  {}", content_str);
            }
        } else {
            // 二进制内容
            println!("  [二进制数据 {} bytes]", msg.content.len());
            println!("  十六进制: {:02x?}", &msg.content[..msg.content.len().min(40)]);
        }
        
        println!("═══════════════════════════════════════\n");
    }

    /// 解压 gzip 数据
    fn decompress_gzip(data: &[u8]) -> Result<Vec<u8>, std::io::Error> {
        let mut decoder = GzDecoder::new(data);
        let mut decompressed = Vec::new();
        decoder.read_to_end(&mut decompressed)?;
        Ok(decompressed)
    }

    /// 发送请求到服务器（使用 protocol 中的数据结构）
    #[allow(dead_code)]
    pub async fn send_request(
        &self,
        write: &mut futures_util::stream::SplitSink<
            tokio_tungstenite::WebSocketStream<tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>>,
            WsMessage,
        >,
        req_identifier: i32,
        data: Vec<u8>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let req = OpenIMReq {
            req_identifier,
            token: self.token.clone(),
            send_id: self.user_id.clone(),
            operation_id: format!("{}", chrono::Utc::now().timestamp_millis()),
            msg_incr: "1".to_string(),
            data,
        };

        let json = serde_json::to_vec(&req)?;
        write.send(WsMessage::Binary(json)).await?;
        
        println!("📤 请求已发送 (类型: {})", req_identifier);
        Ok(())
    }
}

