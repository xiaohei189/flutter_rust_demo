#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(test)]
mod tests {
    use super::super::openim_client::OpenIMClient;

    /// 运行 OpenIM 客户端（持续监听）
    /// 使用: cargo test run_openim_client -- --nocapture --ignored
    #[tokio::test]
    #[ignore]
    async fn run_openim_client() {
        let client = OpenIMClient::new(
            "4937393320".to_string(),
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJVc2VySUQiOiI0OTM3MzkzMzIwIiwiUGxhdGZvcm1JRCI6NSwiZXhwIjoxNzcwOTAzNjkwLCJpYXQiOjE3NjMxMjc2ODV9.bnTKyUQ_w0c_d5UAXWDoKq5YTG8ZPlhA0wXIshQpT6Y".to_string(),
            5,
        );

        if let Err(e) = client.connect_and_run().await {
            println!("客户端运行错误: {}", e);
        }
    }

    /// OpenIM WebSocket 快速连接测试
    #[tokio::test]
    async fn test_openim_websocket() {
        use tokio_tungstenite::connect_async;
        use futures_util::{StreamExt, SinkExt};
        use tokio_tungstenite::tungstenite::Message;
        
        // 真实的连接参数（从您提供的 URL 中提取）
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJVc2VySUQiOiI0OTM3MzkzMzIwIiwiUGxhdGZvcm1JRCI6NSwiZXhwIjoxNzcwOTAzNjkwLCJpYXQiOjE3NjMxMjc2ODV9.bnTKyUQ_w0c_d5UAXWDoKq5YTG8ZPlhA0wXIshQpT6Y";
        let send_id = "4937393320";
        let platform_id = 5;
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        
        let ws_url = format!(
            "ws://localhost:10001/?compression=gzip&isBackground=false&isMsgResp=true&operationID={}&platformID={}&sendID={}&token={}",
            operation_id, platform_id, send_id, token
        );
        
        println!("\n=== OpenIM WebSocket 连接测试 ===");
        println!("🔗 连接地址: ws://localhost:10001/?...");
        println!("👤 用户 ID: {}", send_id);
        println!("📱 平台 ID: {}", platform_id);
        println!("🔑 操作 ID: {}", operation_id);
        
        match connect_async(&ws_url).await {
            Ok((mut ws_stream, response)) => {
                println!("\n✅ WebSocket 连接成功!");
                println!("   状态码: {}", response.status());
                println!("   协议: {:?}", response.headers().get("upgrade"));
                
                // 监听服务器消息
                println!("\n📥 监听服务器消息...");
                
                let mut message_count = 0;
                loop {
                    match tokio::time::timeout(
                        std::time::Duration::from_secs(10),
                        ws_stream.next()
                    ).await {
                        Ok(Some(Ok(Message::Text(text)))) => {
                            message_count += 1;
                            println!("\n📨 [消息 #{}] 文本消息:", message_count);
                            println!("   内容: {}", text);
                            
                            // 解析 JSON（如果是）
                            if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text) {
                                println!("   JSON: {:#}", json);
                            }
                        }
                        Ok(Some(Ok(Message::Binary(data)))) => {
                            message_count += 1;
                            println!("\n📦 [消息 #{}] 二进制消息:", message_count);
                            println!("   大小: {} bytes", data.len());
                            println!("   数据（前40字节）: {:?}", &data[..data.len().min(40)]);
                            
                            // 尝试解析为 protobuf（根据实际协议调整）
                            // 这里可以尝试解析为 msggateway 的消息类型
                        }
                        Ok(Some(Ok(Message::Ping(data)))) => {
                            println!("\n🏓 收到 Ping: {} bytes", data.len());
                            // 自动回复 Pong
                            let _ = ws_stream.send(Message::Pong(data)).await;
                            println!("   已回复 Pong");
                        }
                        Ok(Some(Ok(Message::Pong(_)))) => {
                            println!("\n🏓 收到 Pong");
                        }
                        Ok(Some(Ok(Message::Close(frame)))) => {
                            println!("\n👋 服务器关闭连接: {:?}", frame);
                            break;
                        }
                        Ok(Some(Ok(Message::Frame(_)))) => {
                            // 原始帧，通常不需要处理
                            println!("\n🔧 收到原始帧");
                        }
                        Ok(Some(Err(e))) => {
                            println!("\n❌ 接收错误: {}", e);
                            break;
                        }
                        Ok(None) => {
                            println!("\n⚠️ 连接已关闭");
                            break;
                        }
                        Err(_) => {
                            println!("\n⏱️ 10秒内无新消息");
                            
                            // 发送心跳
                            println!("   💓 发送心跳 Ping...");
                            if let Err(e) = ws_stream.send(Message::Ping(vec![])).await {
                                println!("   ❌ 心跳发送失败: {}", e);
                                break;
                            }
                            
                            // 如果已经收到至少一条消息，可以选择退出
                            if message_count > 0 {
                                println!("   ℹ️ 已收到 {} 条消息，测试结束", message_count);
                                break;
                            }
                        }
                    }
                }
                
                println!("\n📊 统计信息:");
                println!("   总消息数: {}", message_count);
                
                println!("\n👋 关闭连接...");
                let _ = ws_stream.close(None).await;
                println!("✅ 测试完成");
            }
            Err(e) => {
                println!("\n❌ WebSocket 连接失败: {}", e);
                println!("\n🔍 排查建议：");
                println!("1. 检查 open-im-server 是否运行:");
                println!("   docker ps | grep openim");
                println!("2. 检查端口是否监听:");
                println!("   netstat -ano | findstr 10001");
                println!("3. Token 是否过期:");
                println!("   exp: 1770903690 ({})", 
                    chrono::DateTime::from_timestamp(1770903690, 0)
                        .map(|dt| dt.format("%Y-%m-%d %H:%M:%S").to_string())
                        .unwrap_or_else(|| "无效".to_string())
                );
            }
        }
    }

}
