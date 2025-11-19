use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
struct LoginRequest {
    #[serde(rename = "areaCode")]
    area_code: String,
    #[serde(rename = "phoneNumber")]
    phone_number: String,
    password: String,
    platform: i32,
}

#[derive(Debug, Deserialize)]
struct LoginResponse {
    #[serde(rename = "errCode")]
    err_code: i32,
    #[serde(rename = "errMsg")]
    err_msg: String,
    data: Option<LoginData>,
}

#[derive(Debug, Deserialize)]
struct LoginData {
    #[serde(rename = "imToken")]
    im_token: String,
    #[serde(rename = "chatToken")]
    chat_token: String,
    #[serde(rename = "userID")]
    user_id: String,
}

/// 登录并获取 token
/// 
/// # 参数
/// - `area_code`: 区号，例如 "+86"
/// - `phone_number`: 手机号
/// - `password`: 密码（MD5 加密后的字符串）
/// - `platform`: 平台 ID，例如 5
/// 
/// # 返回
/// 返回包含 imToken、chatToken 和 userID 的 JSON 字符串
#[flutter_rust_bridge::frb(sync)]
pub fn login(area_code: String, phone_number: String, password: String, platform: i32) -> Result<String, String> {
    let rt = tokio::runtime::Runtime::new().map_err(|e| format!("创建运行时失败: {}", e))?;
    rt.block_on(async {
        login_async(area_code, phone_number, password, platform).await
    })
}

pub async fn login_async(area_code: String, phone_number: String, password: String, platform: i32) -> Result<String, String> {
    use uuid::Uuid;
    
    let client = reqwest::Client::new();
    let operation_id = Uuid::new_v4().to_string();
    
    let login_req = LoginRequest {
        area_code,
        phone_number,
        password,
        platform,
    };
    
    let url = "http://localhost:10008/account/login";
    
    println!("🔐 正在登录...");
    println!("   URL: {}", url);
    println!("   手机号: {}", login_req.phone_number);
    println!("   OperationID: {}", operation_id);
    
    let response = client
        .post(url)
        .header("Accept", "application/json, text/plain, */*")
        .header("Accept-Language", "zh-CN,zh;q=0.9")
        .header("Cache-Control", "no-cache")
        .header("Connection", "keep-alive")
        .header("Content-Type", "application/json")
        .header("Origin", "http://localhost:11001")
        .header("Pragma", "no-cache")
        .header("Referer", "http://localhost:11001/")
        .header("Sec-Fetch-Dest", "empty")
        .header("Sec-Fetch-Mode", "cors")
        .header("Sec-Fetch-Site", "same-site")
        .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36")
        .header("operationID", &operation_id)
        .header("sec-ch-ua", r#""Not)A;Brand";v="8", "Chromium";v="138", "Google Chrome";v="138""#)
        .header("sec-ch-ua-mobile", "?0")
        .header("sec-ch-ua-platform", r#""Windows""#)
        .json(&login_req)
        .send()
        .await
        .map_err(|e| format!("请求失败: {}", e))?;
    
    let status = response.status();
    let text = response.text().await.map_err(|e| format!("读取响应失败: {}", e))?;
    
    if !status.is_success() {
        return Err(format!("HTTP 错误 {}: {}", status, text));
    }
    
    println!("✅ 登录响应: {}", text);
    
    let login_resp: LoginResponse = serde_json::from_str(&text)
        .map_err(|e| format!("解析响应失败: {}，原始响应: {}", e, text))?;
    
    if login_resp.err_code != 0 {
        return Err(format!("登录失败: {} (错误码: {})", login_resp.err_msg, login_resp.err_code));
    }
    
    match login_resp.data {
        Some(data) => {
            let result = serde_json::json!({
                "imToken": data.im_token,
                "chatToken": data.chat_token,
                "userID": data.user_id,
            });
            Ok(serde_json::to_string_pretty(&result).unwrap_or_else(|_| result.to_string()))
        }
        None => Err("响应中没有数据".to_string()),
    }
}

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
        
        let mut client = OpenIMClient::new(user_id.clone(), im_token, 5);

        // 连接到服务器
        let read = match client.connect().await {
            Ok(r) => r,
            Err(e) => {
                println!("连接失败: {}", e);
                return;
            }
        };

        println!("✅ WebSocket 连接成功！\n");

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

        // 持续监听消息
        println!("📥 客户端运行中，等待消息推送...\n");
        if let Err(e) = client.handle_messages(read).await {
            println!("错误: {}", e);
        }
    }
}
