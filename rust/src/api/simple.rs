// 重新导出认证相关函数
pub use super::auth::{login, login_async};

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
    use super::super::client::{OpenIMClient, ClientConfig};
    use super::login_async;


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
        ).await {
            Ok(info) => {
                println!("✅ 登录成功！\n");
                info
            }
            Err(e) => {
                println!("❌ 登录失败: {}\n", e);
                println!("⚠️  使用硬编码的 token 继续...\n");
                "".to_string()
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
        
        // 如果登录失败，使用硬编码的值
        let user_id = if user_id.is_empty() {
            "6354135995".to_string()
        } else {
            user_id
        };
        
        let im_token = if im_token.is_empty() {
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJVc2VySUQiOiI0OTM3MzkzMzIwIiwiUGxhdGZvcm1JRCI6NSwiZXhwIjoxNzcwOTAzNjkwLCJpYXQiOjE3NjMxMjc2ODV9.bnTKyUQ_w0c_d5UAXWDoKq5YTG8ZPlhA0wXIshQpT6Y".to_string()
        } else {
            im_token
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
        let recv_id = "4937393320".to_string(); // 接收者 ID（发送给自己）
        
        // 启动发送消息任务（延迟 3 秒后发送，确保连接稳定）
        tokio::spawn(async move {
            tokio::time::sleep(tokio::time::Duration::from_secs(3)).await;
            
            // 发送测试消息（单聊，发送给自己）
            println!("\n📤 准备发送测试消息...");
            match client_for_send.send_text_message(
                recv_id.clone(), // 接收者 ID（发送给自己）
                "Hello from Rust client!".to_string(),
                1, // 单聊
            ).await {
                Ok(_) => {
                    println!("✅ 消息发送成功！");
                }
                Err(e) => {
                    println!("❌ 消息发送失败: {}", e);
                }
            }
            
            // 等待 2 秒后发送第二条消息
            tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
            
            match client_for_send.send_text_message(
                recv_id,
                "这是第二条测试消息".to_string(),
                1, // 单聊
            ).await {
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
        tokio::time::sleep(tokio::time::Duration::from_secs(30)).await;
    }
}
