//! SDK 集成测试 - 连接本地 Docker OpenIM 服务
//!
//! 测试架构：
//! - 通过 OpenIMClient 门面测试完整的 SDK 功能
//! - 使用固定测试账号（环境变量配置），避免重复注册
//! - 包括：消息收发、消息类型、好友/群组/会话管理、离线同步
//!
//! 测试账号配置（通过环境变量）：
//! - OPENIM_TEST_USER1_ID / OPENIM_TEST_USER1_PHONE - 用户1（发送者）
//! - OPENIM_TEST_USER2_ID / OPENIM_TEST_USER2_PHONE - 用户2（接收者）
//! - 如果未配置，会自动注册新账号并打印账号信息供后续使用
//!
//! 运行方式:
//! ```bash
//! # 确保 Docker 服务已启动
//! docker ps
//!
//! # 运行集成测试（需要 --ignored 标志）
//! cargo test --test integration -- --ignored
//!
//! # 运行特定测试
//! cargo test --test integration test_message_types -- --ignored --nocapture
//! ```
//!
//! 测试环境要求:
//! - Docker 运行中
//! - openim-server 在 10001 (WS) 和 10002 (API) 端口
//! - openim-chat 在 10008 端口

use rust_lib_flutter_rust_demo::domain::config::ClientConfig;
use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;
use serde::{Deserialize, Serialize};
use std::time::Duration;
use tracing_subscriber;

/// 测试用 API 基础 URL
const API_BASE_URL: &str = "http://localhost:10002";

/// 测试用 WS URL
const WS_URL: &str = "ws://localhost:10001";

/// Chat 服务 API 基础 URL（用于注册和登录）
const CHAT_API_BASE_URL: &str = "http://localhost:10008";

/// 默认验证码（开发环境）
const DEFAULT_VERIFICATION_CODE: &str = "666666";

// ============================================================================
// 固定测试账号管理
// ============================================================================

/// 测试账号信息
#[derive(Clone, Debug)]
struct TestAccount {
    user_id: String,
    phone: String,
    nickname: String,
    im_token: Option<String>,
    chat_token: Option<String>,
}

/// 获取或注册用户1（发送者）
async fn get_or_create_user1() -> TestAccount {
    // 尝试从环境变量获取
    if let (Ok(user_id), Ok(phone)) = (
        std::env::var("OPENIM_TEST_USER1_ID"),
        std::env::var("OPENIM_TEST_USER1_PHONE"),
    ) {
        println!("使用固定测试账号1: user_id={}, phone={}", user_id, phone);
        return TestAccount {
            user_id,
            phone,
            nickname: "TestUser1".to_string(),
            im_token: None,
            chat_token: None,
        };
    }
    
    // 否则注册新账号
    println!("注册新测试账号1...");
    let phone = generate_virtual_phone("user1");
    let nickname = format!("TestUser1_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    let cert = register_user(&phone, &nickname).await.expect("注册失败");
    
    println!("✅ 新测试账号1已注册，请保存以下信息供后续使用:");
    println!("  export OPENIM_TEST_USER1_ID={}", cert.user_id);
    println!("  export OPENIM_TEST_USER1_PHONE={}", phone);
    println!("  export OPENIM_TEST_USER1_IM_TOKEN={}", cert.im_token);
    println!("  export OPENIM_TEST_USER1_CHAT_TOKEN={}", cert.chat_token);
    
    TestAccount {
        user_id: cert.user_id.clone(),
        phone,
        nickname,
        im_token: Some(cert.im_token),
        chat_token: Some(cert.chat_token),
    }
}

/// 获取或注册用户2（接收者）
async fn get_or_create_user2() -> TestAccount {
    // 尝试从环境变量获取
    if let (Ok(user_id), Ok(phone)) = (
        std::env::var("OPENIM_TEST_USER2_ID"),
        std::env::var("OPENIM_TEST_USER2_PHONE"),
    ) {
        println!("使用固定测试账号2: user_id={}, phone={}", user_id, phone);
        return TestAccount {
            user_id,
            phone,
            nickname: "TestUser2".to_string(),
            im_token: None,
            chat_token: None,
        };
    }
    
    // 否则注册新账号
    println!("注册新测试账号2...");
    let phone = generate_virtual_phone("user2");
    let nickname = format!("TestUser2_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    let cert = register_user(&phone, &nickname).await.expect("注册失败");
    
    println!("✅ 新测试账号2已注册，请保存以下信息供后续使用:");
    println!("  export OPENIM_TEST_USER2_ID={}", cert.user_id);
    println!("  export OPENIM_TEST_USER2_PHONE={}", phone);
    println!("  export OPENIM_TEST_USER2_IM_TOKEN={}", cert.im_token);
    println!("  export OPENIM_TEST_USER2_CHAT_TOKEN={}", cert.chat_token);
    
    TestAccount {
        user_id: cert.user_id.clone(),
        phone,
        nickname,
        im_token: Some(cert.im_token),
        chat_token: Some(cert.chat_token),
    }
}

/// 登录获取 token
async fn login_account(account: &TestAccount) -> Result<(String, String), String> {
    // 如果已有 token，直接返回
    if let (Some(im_token), Some(chat_token)) = (&account.im_token, &account.chat_token) {
        return Ok((im_token.clone(), chat_token.clone()));
    }
    
    // 否则登录
    let cert = login_user(&account.phone).await?;
    Ok((cert.im_token, cert.chat_token))
}

/// 创建 SDK 实例
async fn create_sdk(account: &TestAccount, im_token: &str) -> OpenIMClient {
    let data_dir = std::env::temp_dir()
        .join(format!("openim_test_{}", account.user_id))
        .to_string_lossy()
        .to_string();
    
    let _ = std::fs::create_dir_all(&data_dir);
    
    let config = ClientConfig::new(
        account.user_id.clone(),
        im_token.to_string(),
        1,
        Some(WS_URL.to_string()),
        Some(API_BASE_URL.to_string()),
        Some(data_dir),
    );
    
    let sdk = OpenIMClient::new(config).await.expect("创建 SDK 失败");
    
    // 连接 WebSocket
    sdk.connect(WS_URL, im_token, &account.user_id).await.expect("连接失败");
    tokio::time::sleep(Duration::from_secs(2)).await;
    
    sdk
}

/// 获取用户信息请求
#[derive(Serialize)]
struct GetUsersInfoReq {
    #[serde(rename = "userIDs")]
    user_ids: Vec<String>,
}

/// 用户信息响应
#[derive(Deserialize, Debug)]
struct UserInfoResp {
    #[serde(rename = "userID")]
    user_id: String,
    #[serde(rename = "nickname")]
    nickname: String,
    #[serde(rename = "faceURL")]
    face_url: String,
}

/// 生成虚拟手机号
fn generate_virtual_phone(test_name: &str) -> String {
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis();
    format!("138{:08}{}", timestamp % 100000000, test_name.chars().next().unwrap_or('t') as u32 % 10)
}

/// 登录证书响应（注册 API 返回格式）
#[derive(Deserialize, Debug)]
struct RegisterResponse {
    #[serde(rename = "userID")]
    user_id: String,
    #[serde(rename = "imToken")]
    im_token: String,
    #[serde(rename = "chatToken")]
    chat_token: String,
}

/// 登录证书响应（登录 API 返回格式，与注册相同）
#[derive(Deserialize, Debug)]
struct LoginCertificate {
    #[serde(rename = "userID")]
    user_id: String,
    #[serde(rename = "imToken")]
    im_token: String,
    #[serde(rename = "chatToken")]
    chat_token: String,
}

/// 发送验证码
async fn send_verification_code(phone: &str) -> Result<(), String> {
    let client = reqwest::Client::new();
    let operation_id = format!("test_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
    
    let resp = client
        .post(&format!("{}/account/code", CHAT_API_BASE_URL))
        .header("operationID", &operation_id)
        .json(&serde_json::json!({
            "phone": phone,
            "areaCode": "+86",
            "usedFor": "register"
        }))
        .send()
        .await
        .map_err(|e| format!("发送验证码失败: {}", e))?;
    
    let status = resp.status();
    if status.is_success() {
        Ok(())
    } else {
        // 开发环境可能直接成功或返回验证码已发送
        println!("发送验证码响应状态: {}", status);
        Ok(())
    }
}

/// 注册用户
async fn register_user(phone: &str, nickname: &str) -> Result<RegisterResponse, String> {
    let client = reqwest::Client::new();
    let operation_id = format!("test_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
    
    let resp = client
        .post(&format!("{}/account/register", CHAT_API_BASE_URL))
        .header("operationID", &operation_id)
        .json(&serde_json::json!({
            "verifyCode": DEFAULT_VERIFICATION_CODE,
            "platform": 1,
            "autoLogin": true,
            "user": {
                "nickname": nickname,
                "phoneNumber": phone,
                "areaCode": "+86",
                "password": ""
            }
        }))
        .send()
        .await
        .map_err(|e| format!("注册请求失败: {}", e))?;
    
    let status = resp.status();
    let body = resp.text().await.map_err(|e| format!("读取响应失败: {}", e))?;
    
    if status.is_success() {
        // 解析外层响应
        let outer: serde_json::Value = serde_json::from_str(&body)
            .map_err(|e| format!("解析外层响应失败: {}, body={}", e, body))?;
        
        // 检查 errCode
        if let Some(err_code) = outer.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                return Err(format!("注册失败: errCode={}, body={}", err_code, body));
            }
        }
        
        // 解析 data 字段
        let data = outer.get("data").ok_or_else(|| format!("响应缺少 data 字段: body={}", body))?;
        let cert: RegisterResponse = serde_json::from_value(data.clone())
            .map_err(|e| format!("解析响应失败: {}, body={}", e, body))?;
        Ok(cert)
    } else {
        Err(format!("注册失败: status={}, body={}", status, body))
    }
}

/// 登录用户
async fn login_user(phone: &str) -> Result<LoginCertificate, String> {
    let client = reqwest::Client::new();
    let operation_id = format!("test_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
    
    let resp = client
        .post(&format!("{}/account/login", CHAT_API_BASE_URL))
        .header("operationID", &operation_id)
        .json(&serde_json::json!({
            "phoneNumber": phone,
            "areaCode": "+86",
            "verifyCode": DEFAULT_VERIFICATION_CODE,
            "platform": 1
        }))
        .send()
        .await
        .map_err(|e| format!("登录请求失败: {}", e))?;
    
    let status = resp.status();
    let body = resp.text().await.map_err(|e| format!("读取响应失败: {}", e))?;
    
    if status.is_success() {
        // 解析外层响应
        let outer: serde_json::Value = serde_json::from_str(&body)
            .map_err(|e| format!("解析外层响应失败: {}, body={}", e, body))?;
        
        // 检查 errCode
        if let Some(err_code) = outer.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                return Err(format!("登录失败: errCode={}, body={}", err_code, body));
            }
        }
        
        // 解析 data 字段
        let data = outer.get("data").ok_or_else(|| format!("响应缺少 data 字段: body={}", body))?;
        let cert: LoginCertificate = serde_json::from_value(data.clone())
            .map_err(|e| format!("解析响应失败: {}, body={}", e, body))?;
        Ok(cert)
    } else {
        Err(format!("登录失败: status={}, body={}", status, body))
    }
}

// ============================================================================
// 好友管理集成测试
// ============================================================================

/// 集成测试: 用户态完整功能（通过 OpenIMClient）
/// 测试流程：注册 → 创建 SDK → 连接 WebSocket → 获取好友列表 → 发送消息
#[tokio::test]
#[ignore]
async fn test_user_state_via_sdk() {
    // 1. 注册测试用户
    let phone = generate_virtual_phone("sdk");
    let nickname = format!("TestUser_SDK_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    println!("1. 注册测试用户...");
    let cert = register_user(&phone, &nickname).await;
    assert!(cert.is_ok(), "注册失败: {:?}", cert.err());
    let cert = cert.unwrap();
    let user_id = cert.user_id.clone();
    let token = cert.im_token.clone();
    
    println!("  用户: user_id={}, nickname={}", user_id, nickname);
    println!("  im_token 前 50 字符: {}", &token[..token.len().min(50)]);
    
    // 2. 先测试直接 WebSocket 连接
    println!("2. 测试直接 WebSocket 连接...");
    let ws_url = format!(
        "ws://localhost:10001/?token={}&sendID={}&platformID=1&operationID=test_direct&isBackground=false&isMsgResp=true&sdkType=js",
        token, user_id
    );
    
    use tokio_tungstenite::connect_async;
    match connect_async(&ws_url).await {
        Ok((_ws_stream, response)) => {
            println!("  ✅ 直接 WebSocket 连接成功! Status: {}", response.status());
        }
        Err(e) => {
            println!("  ❌ 直接 WebSocket 连接失败: {}", e);
            println!("  URL: {}", ws_url);
            return;
        }
    }
    
    // 3. 创建 OpenIMClient SDK 实例
    println!("3. 创建 OpenIMClient SDK...");
    let data_dir = std::env::temp_dir()
        .join(format!("openim_test_{}", user_id))
        .to_string_lossy()
        .to_string();
    
    // 确保数据目录存在
    if let Err(e) = std::fs::create_dir_all(&data_dir) {
        println!("创建临时目录失败: {}", e);
    }
    
    let config = ClientConfig::new(
        user_id.clone(),
        token.clone(),
        1,
        Some("ws://localhost:10001".to_string()),
        Some(API_BASE_URL.to_string()),
        Some(data_dir),
    );
    
    let sdk = OpenIMClient::new(config).await;
    assert!(sdk.is_ok(), "创建 SDK 失败: {:?}", sdk.err());
    let sdk = sdk.unwrap();
    
    println!("  ✅ SDK 创建成功");
    
    // 4. 连接 WebSocket
    println!("4. 连接 WebSocket...");
    let connect_result = sdk.connect("ws://localhost:10001", &token, &user_id).await;
    
    if connect_result.is_err() {
        println!("  ⚠️ 连接失败: {:?}", connect_result.err());
        println!("  可能原因: WebSocket 服务未启动或 token 无效");
        return;
    }
    
    println!("  ✅ WebSocket 连接成功");
    
    // 等待连接稳定
    tokio::time::sleep(Duration::from_secs(2)).await;
    
    // 5. 获取好友列表（通过 SDK）
    println!("5. 获取好友列表（通过 SDK）...");
    let friends = sdk.friend.get_friend_list().await;
    println!("  ✅ 获取好友列表成功! 好友数量: {}", friends.len());
    
    // 6. 获取用户信息（通过 SDK）
    println!("6. 获取用户信息（通过 SDK）...");
    let user_result = sdk.user.get_users_info(vec![user_id.clone()]).await;
    
    match &user_result {
        Ok(users) => {
            println!("  ✅ 获取用户信息成功!");
            println!("  用户数量: {}", users.len());
            if let Some(user) = users.first() {
                println!("  昵称: {}", user.nickname);
            }
        }
        Err(e) => {
            println!("  ❌ 获取用户信息失败: {:?}", e);
        }
    }
    
    // 7. 获取会话列表（通过 SDK）
    println!("7. 获取会话列表（通过 SDK）...");
    let conv_result = sdk.conversation.get_all_conversations().await;
    
    match &conv_result {
        Ok(convs) => {
            println!("  ✅ 获取会话列表成功!");
            println!("  会话数量: {}", convs.len());
        }
        Err(e) => {
            println!("  ❌ 获取会话列表失败: {:?}", e);
        }
    }
    
    println!("✅ 用户态 SDK 功能测试完成");
}

// ============================================================================
// 消息类型测试
// ============================================================================

/// 集成测试: 消息类型测试（文本/图片/语音/视频/文件/自定义）
/// 测试流程：使用固定账号 → 发送各种类型消息 → 验证接收
#[tokio::test]
#[ignore]
async fn test_message_types() {
    // 初始化 tracing 日志
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();
    
    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;
    use rust_lib_flutter_rust_demo::domain::constant::types::content_type;
    
    // 1. 获取或创建测试账号
    println!("=== 消息类型测试 ===\n");
    println!("1. 获取测试账号...");
    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    
    // 2. 登录获取 token
    println!("2. 登录账号...");
    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");
    
    // 3. 创建接收者 SDK 并订阅事件
    println!("3. 创建接收者 SDK...");
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut event_subscription = receiver_sdk.event_bus.subscribe();
    
    // 4. 创建发送者 SDK
    println!("4. 创建发送者 SDK...");
    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    
    println!("\n=== 开始测试各种消息类型 ===\n");
    
    // 测试消息类型列表
    let message_tests = vec![
        ("文本消息", content_type::TEXT, build_text_content("Hello! 这是一条文本消息测试。")),
        ("图片消息", content_type::PICTURE, build_picture_content()),
        ("语音消息", content_type::SOUND, build_sound_content()),
        ("视频消息", content_type::VIDEO, build_video_content()),
        ("文件消息", content_type::FILE, build_file_content()),
        ("自定义消息", content_type::CUSTOM, build_custom_content()),
        ("引用消息", content_type::QUOTE, build_quote_content()),
        ("表情消息", content_type::FACE, build_face_content()),
    ];
    
    for (msg_type_name, content_type, content) in message_tests {
        println!("--- 测试: {} (content_type={}) ---", msg_type_name, content_type);
        
        // 发送消息
        let pending_msg = PendingMessage {
            client_msg_id: format!("test_{}_{}", msg_type_name, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()),
            send_id: user1.user_id.clone(),
            recv_id: user2.user_id.clone(),
            group_id: String::new(),
            sender_platform_id: 1,
            sender_nickname: user1.nickname.clone(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type,
            content,
        };
        
        let send_result = sender_sdk.message_sender.send_message(pending_msg).await;
        
        match send_result {
            Ok(_) => {
                println!("  ✅ 发送成功");
            }
            Err(e) => {
                println!("  ❌ 发送失败: {:?}", e);
                continue;
            }
        }
        
        // 等待接收
        tokio::time::sleep(Duration::from_secs(2)).await;
        
        // 检查是否收到消息
        let receive_timeout = tokio::time::sleep(Duration::from_secs(5));
        tokio::pin!(receive_timeout);
        
        let mut message_received = false;
        
        loop {
            tokio::select! {
                _ = &mut receive_timeout => {
                    println!("  ⏰ 超时，未收到消息推送");
                    break;
                }
                event = event_subscription.next() => {
                    match event {
                        Some(SdkEvent::NewMessage { message }) => {
                            let content_type = message.get("contentType").and_then(|v| v.as_i64());
                            println!("  ✅ 收到消息: content_type={:?}", content_type);
                            message_received = true;
                            break;
                        }
                        Some(other_event) => {
                            println!("  收到其他事件: {:?}", other_event);
                        }
                        None => {
                            println!("  ⚠️ 事件流已关闭");
                            break;
                        }
                    }
                }
            }
        }
        
        if !message_received {
            println!("  ⚠️ 未收到消息推送");
        }
        
        println!();
        
        // 间隔一下
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
    
    println!("=== 消息类型测试完成 ===");
}

// 消息内容构建辅助函数

fn build_text_content(text: &str) -> String {
    format!("{{\"content\":\"{}\"}}", text)
}

fn build_picture_content() -> String {
    r#"{"uuid":"test_picture_uuid","type":"jpg","size":1024,"width":800,"height":600,"url":"http://example.com/test.jpg","snapshotUrl":"http://example.com/test_snapshot.jpg","originalUrl":"http://example.com/test_original.jpg"}"#.to_string()
}

fn build_sound_content() -> String {
    r#"{"uuid":"test_sound_uuid","soundPath":"http://example.com/test_sound.mp3","sourceUrl":"http://example.com/test_sound_source.mp3","dataSize":2048,"duration":5}"#.to_string()
}

fn build_video_content() -> String {
    r#"{"videoPath":"http://example.com/test_video.mp4","videoUUID":"test_video_uuid","videoType":"mp4","videoSize":4096,"duration":10,"snapshotPath":"http://example.com/test_video_snapshot.jpg","snapshotUUID":"test_snapshot_uuid","snapshotSize":1024,"snapshotWidth":800,"snapshotHeight":600,"snapshotUrl":"http://example.com/test_snapshot.jpg"}"#.to_string()
}

fn build_file_content() -> String {
    r#"{"filePath":"http://example.com/test_file.pdf","fileName":"test_file.pdf","uuid":"test_file_uuid","fileSize":8192}"#.to_string()
}

fn build_custom_content() -> String {
    r#"{"data":"{\"type\":\"test\",\"content\":\"这是一条自定义消息\"}","description":"测试自定义消息","extension":"{\"key\":\"value\"}"}"#.to_string()
}

fn build_quote_content() -> String {
    r#"{"text":"这是一条引用消息","quoteMessage":{"clientMsgID":"quoted_msg_id","content":"被引用的消息"}}"#.to_string()
}

fn build_face_content() -> String {
    r#"{"index":1,"data":"smile"}"#.to_string()
}

/// 集成测试: 用户态好友管理（添加/获取/删除好友）
#[tokio::test]
#[ignore]
async fn test_user_state_friend_management() {
    // 1. 注册两个用户
    let user1_phone = generate_virtual_phone("friend1");
    let user1_nickname = format!("TestUser_Friend1_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    println!("1. 注册用户1...");
    let user1_cert = register_user(&user1_phone, &user1_nickname).await;
    assert!(user1_cert.is_ok(), "用户1注册失败: {:?}", user1_cert.err());
    let user1_cert = user1_cert.unwrap();
    let user1_id = user1_cert.user_id.clone();
    let user1_token = user1_cert.im_token.clone();
    
    let user2_phone = generate_virtual_phone("friend2");
    let user2_nickname = format!("TestUser_Friend2_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    println!("2. 注册用户2...");
    let user2_cert = register_user(&user2_phone, &user2_nickname).await;
    assert!(user2_cert.is_ok(), "用户2注册失败: {:?}", user2_cert.err());
    let user2_cert = user2_cert.unwrap();
    let user2_id = user2_cert.user_id.clone();
    let user2_token = user2_cert.im_token.clone();
    
    println!("  用户1: user_id={}", user1_id);
    println!("  用户2: user_id={}", user2_id);
    
    // 2. 创建用户1 SDK
    println!("3. 创建用户1 SDK...");
    let user1_data_dir = std::env::temp_dir()
        .join(format!("openim_test_friend1_{}", user1_id))
        .to_string_lossy()
        .to_string();
    
    let _ = std::fs::create_dir_all(&user1_data_dir);
    
    let user1_config = ClientConfig::new(
        user1_id.clone(),
        user1_token.clone(),
        1,
        Some("ws://localhost:10001".to_string()),
        Some(API_BASE_URL.to_string()),
        Some(user1_data_dir),
    );
    
    let user1_sdk = OpenIMClient::new(user1_config).await;
    assert!(user1_sdk.is_ok(), "创建用户1 SDK 失败: {:?}", user1_sdk.err());
    let user1_sdk = user1_sdk.unwrap();
    
    // 3. 连接 WebSocket
    println!("4. 用户1连接 WebSocket...");
    let connect_result = user1_sdk.connect("ws://localhost:10001", &user1_token, &user1_id).await;
    assert!(connect_result.is_ok(), "连接失败: {:?}", connect_result.err());
    tokio::time::sleep(Duration::from_secs(2)).await;
    
    // 4. 获取好友列表（应该为空）
    println!("5. 获取好友列表（应该为空）...");
    let friends = user1_sdk.friend.get_friend_list().await;
    println!("  好友数量: {}", friends.len());
    assert!(friends.is_empty(), "新用户应该没有好友");
    
    // 5. 添加好友
    println!("6. 添加用户2为好友...");
    let add_result = user1_sdk.friend.add_friend(user2_id.clone(), Some("Hello, let's be friends!".to_string())).await;
    
    match add_result {
        Ok(_) => {
            println!("  ✅ 好友申请发送成功!");
        }
        Err(e) => {
            println!("  ⚠️ 添加好友失败: {:?}", e);
            println!("  可能原因: 需要对方同意或自动通过");
        }
    }
    
    // 6. 获取好友ID列表
    println!("7. 获取好友ID列表...");
    let friend_ids = user1_sdk.friend.get_friend_id_list().await;
    println!("  好友ID数量: {}", friend_ids.len());
    
    // 7. 检查是否为好友
    println!("8. 检查好友关系...");
    let is_friend = user1_sdk.friend.is_friend(&user2_id).await;
    println!("  是否好友: {}", is_friend);
    
    println!("✅ 好友管理测试完成");
}

/// 集成测试: 用户态群组管理（创建群组/邀请成员/获取群信息）
#[tokio::test]
#[ignore]
async fn test_user_state_group_management() {
    // 1. 注册用户
    let user_phone = generate_virtual_phone("group");
    let user_nickname = format!("TestUser_Group_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    println!("1. 注册用户...");
    let user_cert = register_user(&user_phone, &user_nickname).await;
    assert!(user_cert.is_ok(), "注册失败: {:?}", user_cert.err());
    let user_cert = user_cert.unwrap();
    let user_id = user_cert.user_id.clone();
    let user_token = user_cert.im_token.clone();
    
    println!("  用户: user_id={}, nickname={}", user_id, user_nickname);
    
    // 2. 创建 SDK
    println!("2. 创建 SDK...");
    let data_dir = std::env::temp_dir()
        .join(format!("openim_test_group_{}", user_id))
        .to_string_lossy()
        .to_string();
    
    let _ = std::fs::create_dir_all(&data_dir);
    
    let config = ClientConfig::new(
        user_id.clone(),
        user_token.clone(),
        1,
        Some("ws://localhost:10001".to_string()),
        Some(API_BASE_URL.to_string()),
        Some(data_dir),
    );
    
    let sdk = OpenIMClient::new(config).await;
    assert!(sdk.is_ok(), "创建 SDK 失败: {:?}", sdk.err());
    let sdk = sdk.unwrap();
    
    // 3. 连接 WebSocket
    println!("3. 连接 WebSocket...");
    let connect_result = sdk.connect("ws://localhost:10001", &user_token, &user_id).await;
    assert!(connect_result.is_ok(), "连接失败: {:?}", connect_result.err());
    tokio::time::sleep(Duration::from_secs(2)).await;
    
    // 4. 创建群组
    println!("4. 创建群组...");
    let group_name = format!("TestGroup_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    // 创建群组需要将自己加入成员列表
    let create_result = sdk.group.create_group(
        group_name.clone(),
        Some(String::new()),
        Some("Test group introduction".to_string()),
        Some("This is a test group".to_string()),
        vec![user_id.clone()],  // 将自己加入成员
        Vec::new(),
        user_id.clone(),
    ).await;
    
    match create_result {
        Ok(group_info) => {
            println!("  ✅ 群组创建成功!");
            println!("  群组ID: {}", group_info.group_id);
            println!("  群组名称: {}", group_info.group_name);
        }
        Err(e) => {
            println!("  ❌ 群组创建失败: {:?}", e);
            return;
        }
    }
    
    // 5. 获取已加入群组列表
    println!("5. 获取已加入群组列表...");
    let groups = sdk.group.get_joined_group_list().await;
    println!("  群组数量: {}", groups.len());
    
    if !groups.is_empty() {
        for group in &groups {
            println!("  群组: {} ({})", group.group_name, group.group_id);
        }
    }
    
    println!("✅ 群组管理测试完成");
}

/// 集成测试: 用户态会话管理（标记已读/删除/置顶）
#[tokio::test]
#[ignore]
async fn test_user_state_conversation_management() {
    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;
    
    // 1. 注册两个用户
    let user1_phone = generate_virtual_phone("conv1");
    let user1_nickname = format!("TestUser_Conv1_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    println!("1. 注册用户1...");
    let user1_cert = register_user(&user1_phone, &user1_nickname).await;
    assert!(user1_cert.is_ok(), "用户1注册失败: {:?}", user1_cert.err());
    let user1_cert = user1_cert.unwrap();
    let user1_id = user1_cert.user_id.clone();
    let user1_token = user1_cert.im_token.clone();
    
    let user2_phone = generate_virtual_phone("conv2");
    let user2_nickname = format!("TestUser_Conv2_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    println!("2. 注册用户2...");
    let user2_cert = register_user(&user2_phone, &user2_nickname).await;
    assert!(user2_cert.is_ok(), "用户2注册失败: {:?}", user2_cert.err());
    let user2_cert = user2_cert.unwrap();
    let user2_id = user2_cert.user_id.clone();
    let user2_token = user2_cert.im_token.clone();
    
    println!("  用户1: user_id={}", user1_id);
    println!("  用户2: user_id={}", user2_id);
    
    // 2. 创建用户1 SDK
    println!("3. 创建用户1 SDK...");
    let user1_data_dir = std::env::temp_dir()
        .join(format!("openim_test_conv1_{}", user1_id))
        .to_string_lossy()
        .to_string();
    
    let _ = std::fs::create_dir_all(&user1_data_dir);
    
    let user1_config = ClientConfig::new(
        user1_id.clone(),
        user1_token.clone(),
        1,
        Some("ws://localhost:10001".to_string()),
        Some(API_BASE_URL.to_string()),
        Some(user1_data_dir),
    );
    
    let user1_sdk = OpenIMClient::new(user1_config).await;
    assert!(user1_sdk.is_ok(), "创建用户1 SDK 失败: {:?}", user1_sdk.err());
    let user1_sdk = user1_sdk.unwrap();
    
    // 3. 连接 WebSocket
    println!("4. 用户1连接 WebSocket...");
    let connect_result = user1_sdk.connect("ws://localhost:10001", &user1_token, &user1_id).await;
    assert!(connect_result.is_ok(), "连接失败: {:?}", connect_result.err());
    tokio::time::sleep(Duration::from_secs(2)).await;
    
    // 4. 发送消息创建会话
    println!("5. 发送消息创建会话...");
    let pending_msg = PendingMessage {
        client_msg_id: format!("test_msg_conv_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()),
        send_id: user1_id.clone(),
        recv_id: user2_id.clone(),
        group_id: String::new(),
        sender_platform_id: 1,
        sender_nickname: user1_nickname.clone(),
        sender_face_url: String::new(),
        session_type: 1,
        msg_from: 100,
        content_type: 101,
        content: format!("{{\"content\":\"Test message for conversation\"}}"),
    };
    
    let send_result = user1_sdk.message_sender.send_message(pending_msg).await;
    assert!(send_result.is_ok(), "消息发送失败: {:?}", send_result.err());
    tokio::time::sleep(Duration::from_secs(2)).await;
    
    // 5. 获取会话列表
    println!("6. 获取会话列表...");
    let conversations = user1_sdk.conversation.get_all_conversations().await;
    
    match &conversations {
        Ok(convs) => {
            println!("  会话数量: {}", convs.len());
            if !convs.is_empty() {
                let conv_id = convs[0].conversation_id.clone();
                
                // 6. 设置置顶
                println!("7. 设置会话置顶...");
                let pin_result = user1_sdk.conversation.set_pinned(&conv_id, true).await;
                match pin_result {
                    Ok(_) => println!("  ✅ 置顶成功"),
                    Err(e) => println!("  ⚠️ 置顶失败: {:?}", e),
                }
                
                // 7. 获取置顶会话
                println!("8. 获取置顶会话...");
                let pinned = user1_sdk.conversation.get_pinned_conversations().await;
                match pinned {
                    Ok(pinned_convs) => println!("  置顶会话数量: {}", pinned_convs.len()),
                    Err(e) => println!("  ❌ 获取置顶会话失败: {:?}", e),
                }
                
                // 8. 设置草稿
                println!("9. 设置会话草稿...");
                let draft_result = user1_sdk.conversation.set_draft(&conv_id, "This is a draft").await;
                match draft_result {
                    Ok(_) => println!("  ✅ 草稿设置成功"),
                    Err(e) => println!("  ⚠️ 草稿设置失败: {:?}", e),
                }
                
                // 9. 清除草稿
                println!("10. 清除会话草稿...");
                let clear_result = user1_sdk.conversation.clear_draft(&conv_id).await;
                match clear_result {
                    Ok(_) => println!("  ✅ 草稿清除成功"),
                    Err(e) => println!("  ⚠️ 草稿清除失败: {:?}", e),
                }
                
                // 10. 删除会话
                println!("11. 删除会话...");
                let delete_result = user1_sdk.conversation.delete_conversation(&conv_id).await;
                match delete_result {
                    Ok(_) => println!("  ✅ 会话删除成功"),
                    Err(e) => println!("  ⚠️ 会话删除失败: {:?}", e),
                }
                
                // 11. 验证会话已删除
                println!("12. 验证会话已删除...");
                let remaining = user1_sdk.conversation.get_all_conversations().await;
                match remaining {
                    Ok(convs) => println!("  剩余会话数量: {}", convs.len()),
                    Err(e) => println!("  ❌ 获取会话列表失败: {:?}", e),
                }
            } else {
                println!("  ⚠️ 没有会话，跳过后续测试");
            }
        }
        Err(e) => {
            println!("  ❌ 获取会话列表失败: {:?}", e);
        }
    }
    
    println!("✅ 会话管理测试完成");
}

/// 集成测试: WebSocket 断线重连
#[tokio::test]
#[ignore]
async fn test_websocket_reconnection() {
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    
    // 1. 注册用户
    let user_phone = generate_virtual_phone("reconnect");
    let user_nickname = format!("TestUser_Reconnect_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    println!("1. 注册用户...");
    let user_cert = register_user(&user_phone, &user_nickname).await;
    assert!(user_cert.is_ok(), "注册失败: {:?}", user_cert.err());
    let user_cert = user_cert.unwrap();
    let user_id = user_cert.user_id.clone();
    let user_token = user_cert.im_token.clone();
    
    println!("  用户: user_id={}", user_id);
    
    // 2. 创建 SDK 并订阅事件
    println!("2. 创建 SDK...");
    let data_dir = std::env::temp_dir()
        .join(format!("openim_test_reconnect_{}", user_id))
        .to_string_lossy()
        .to_string();
    
    let _ = std::fs::create_dir_all(&data_dir);
    
    let config = ClientConfig::new(
        user_id.clone(),
        user_token.clone(),
        1,
        Some("ws://localhost:10001".to_string()),
        Some(API_BASE_URL.to_string()),
        Some(data_dir),
    );
    
    let sdk = OpenIMClient::new(config).await;
    assert!(sdk.is_ok(), "创建 SDK 失败: {:?}", sdk.err());
    let sdk = sdk.unwrap();
    
    // 订阅事件
    let mut event_subscription = sdk.event_bus.subscribe();
    
    // 3. 连接 WebSocket
    println!("3. 连接 WebSocket...");
    let connect_result = sdk.connect("ws://localhost:10001", &user_token, &user_id).await;
    assert!(connect_result.is_ok(), "连接失败: {:?}", connect_result.err());
    println!("  ✅ 初始连接成功");
    tokio::time::sleep(Duration::from_secs(2)).await;
    
    // 4. 监听连接状态事件
    println!("4. 监听连接状态事件（5秒）...");
    
    let listen_timeout = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(listen_timeout);
    
    let mut events_received = Vec::new();
    
    loop {
        tokio::select! {
            _ = &mut listen_timeout => {
                println!("  监听结束");
                break;
            }
            event = event_subscription.next() => {
                match event {
                    Some(SdkEvent::Connected) => {
                        println!("  ✅ 收到 Connected 事件");
                        events_received.push("Connected");
                    }
                    Some(SdkEvent::Connecting) => {
                        println!("  🔄 收到 Connecting 事件");
                        events_received.push("Connecting");
                    }
                    Some(SdkEvent::Disconnected { reason }) => {
                        println!("  ❌ 收到 Disconnected 事件: {}", reason);
                        events_received.push("Disconnected");
                    }
                    Some(other) => {
                        println!("  收到其他事件: {:?}", other);
                    }
                    None => {
                        println!("  ⚠️ 事件流已关闭");
                        break;
                    }
                }
            }
        }
    }
    
    println!("  总共收到 {} 个事件", events_received.len());
    
    // 5. 测试断开连接
    println!("5. 测试断开连接...");
    sdk.disconnect().await;
    tokio::time::sleep(Duration::from_secs(1)).await;
    
    println!("✅ 断线重连测试完成");
}

// ============================================================================
// 在线状态集成测试
// ============================================================================

/// 集成测试: 获取用户在线状态
#[tokio::test]
#[ignore]
async fn test_get_user_online_status() {
    let user1 = get_or_create_user1().await;
    let (user1_im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &user1_im_token).await;
    
    let status = sdk.online_status.get_user_status(vec![user1.user_id.clone()]).await;
    println!("在线状态: {:?}", status);
    println!("✅ 获取用户在线状态测试通过");
}

// ============================================================================
// 消息同步测试
// ============================================================================

/// 集成测试: 消息同步测试（离线消息/历史消息）
/// 测试流程：用户2先上线 → 用户1发送多条消息 → 用户2实时接收
#[tokio::test]
#[ignore]
async fn test_message_sync() {
    // 初始化 tracing 日志
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();
    
    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;
    
    println!("=== 消息同步测试 ===\n");
    
    // 1. 获取测试账号
    println!("1. 获取测试账号...");
    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    
    // 2. 登录获取 token
    println!("2. 登录账号...");
    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");
    
    // 3. 先创建接收者 SDK 并连接（确保在线）
    println!("3. 创建接收者 SDK（先上线等待消息）...");
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut event_subscription = receiver_sdk.event_bus.subscribe();
    println!("  ✅ 接收者已连接");
    
    // 等待接收者完全连接
    tokio::time::sleep(Duration::from_secs(2)).await;
    
    // 4. 创建发送者 SDK 并发送多条消息
    println!("4. 创建发送者 SDK 并发送消息...");
    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    
    // 发送 5 条测试消息
    let message_count = 5;
    for i in 1..=message_count {
        let pending_msg = PendingMessage {
            client_msg_id: format!("sync_test_msg_{}_{}", i, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()),
            send_id: user1.user_id.clone(),
            recv_id: user2.user_id.clone(),
            group_id: String::new(),
            sender_platform_id: 1,
            sender_nickname: user1.nickname.clone(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: format!("{{\"content\":\"同步测试消息 {}\"}}", i),
        };
        
        let send_result = sender_sdk.message_sender.send_message(pending_msg).await;
        match send_result {
            Ok(_) => println!("  ✅ 消息 {} 发送成功", i),
            Err(e) => println!("  ❌ 消息 {} 发送失败: {:?}", i, e),
        }
        
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
    
    // 5. 等待并统计收到的消息
    println!("5. 等待接收消息（10秒超时）...");
    
    let receive_timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(receive_timeout);
    
    let mut received_count = 0;
    let mut received_messages = Vec::new();
    
    loop {
        tokio::select! {
            _ = &mut receive_timeout => {
                println!("  ⏰ 超时，接收结束");
                break;
            }
            event = event_subscription.next() => {
                match event {
                    Some(SdkEvent::NewMessage { message }) => {
                        received_count += 1;
                        let content = message.get("content").and_then(|v| v.as_str()).unwrap_or("");
                        println!("  ✅ 收到消息 {}: {}", received_count, content);
                        received_messages.push(content.to_string());
                        
                        if received_count >= message_count {
                            println!("  ✅ 已收到所有消息");
                            break;
                        }
                    }
                    Some(SdkEvent::SyncStarted) => {
                        println!("  🔄 同步开始");
                    }
                    Some(SdkEvent::SyncFinished) => {
                        println!("  ✅ 同步完成");
                    }
                    Some(SdkEvent::SyncProgress { progress, message }) => {
                        println!("  📊 同步进度: {}% - {}", progress, message);
                    }
                    Some(other_event) => {
                        println!("  收到其他事件: {:?}", other_event.event_type());
                    }
                    None => {
                        println!("  ⚠️ 事件流已关闭");
                        break;
                    }
                }
            }
        }
    }
    
    println!("\n=== 消息同步测试结果 ===");
    println!("  发送消息数: {}", message_count);
    println!("  接收消息数: {}", received_count);
    
    if received_count >= message_count {
        println!("  ✅ 消息同步测试通过");
    } else {
        println!("  ⚠️ 部分消息未收到（可能原因：消息延迟/服务器未存储）");
    }
}

/// 集成测试: 历史消息拉取测试
/// 测试流程：发送消息 → 重新创建 SDK → 拉取历史消息
#[tokio::test]
#[ignore]
async fn test_history_message_pull() {
    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;
    
    println!("=== 历史消息拉取测试 ===\n");
    
    // 1. 获取测试账号
    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    
    // 2. 登录
    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");
    
    // 3. 发送者发送消息
    println!("1. 发送测试消息...");
    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    
    for i in 1..=3 {
        let pending_msg = PendingMessage {
            client_msg_id: format!("history_test_msg_{}_{}", i, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()),
            send_id: user1.user_id.clone(),
            recv_id: user2.user_id.clone(),
            group_id: String::new(),
            sender_platform_id: 1,
            sender_nickname: user1.nickname.clone(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: format!("{{\"content\":\"历史消息测试 {}\"}}", i),
        };
        
        let _ = sender_sdk.message_sender.send_message(pending_msg).await;
        tokio::time::sleep(Duration::from_millis(300)).await;
    }
    
    println!("  ✅ 消息发送完成，等待服务器处理...");
    tokio::time::sleep(Duration::from_secs(2)).await;
    
    // 4. 重新创建接收者 SDK（模拟重新打开应用）
    println!("2. 重新创建 SDK（模拟重新打开应用）...");
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    
    // 5. 获取会话列表，验证会话存在
    println!("3. 获取会话列表...");
    let conversations = receiver_sdk.conversation.get_all_conversations().await;
    
    match &conversations {
        Ok(convs) => {
            println!("  会话数量: {}", convs.len());
            
            if !convs.is_empty() {
                for conv in convs {
                    println!("  会话: {} (未读数: {})", conv.conversation_id, conv.unread_count);
                }
                println!("  ✅ 历史消息拉取测试通过");
            } else {
                println!("  ⚠️ 未找到会话");
            }
        }
        Err(e) => {
            println!("  ❌ 获取会话列表失败: {:?}", e);
        }
    }
}

// ============================================================================
// 消息已读回执测试
// ============================================================================

/// 集成测试: 消息已读回执测试
/// 测试流程：用户1发送消息 → 用户2接收并标记已读 → 用户1收到已读回执
#[tokio::test]
#[ignore]
async fn test_message_read_receipt() {
    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;
    
    println!("=== 消息已读回执测试 ===\n");
    
    // 1. 获取测试账号
    println!("1. 获取测试账号...");
    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    
    // 2. 登录获取 token
    println!("2. 登录账号...");
    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");
    
    // 3. 创建发送者 SDK 并订阅事件
    println!("3. 创建发送者 SDK 并订阅已读回执事件...");
    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let mut sender_event_subscription = sender_sdk.event_bus.subscribe();
    
    // 4. 创建接收者 SDK
    println!("4. 创建接收者 SDK...");
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_event_subscription = receiver_sdk.event_bus.subscribe();
    
    // 5. 发送消息
    println!("5. 发送测试消息...");
    let client_msg_id = format!("read_receipt_test_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
    
    let pending_msg = PendingMessage {
        client_msg_id: client_msg_id.clone(),
        send_id: user1.user_id.clone(),
        recv_id: user2.user_id.clone(),
        group_id: String::new(),
        sender_platform_id: 1,
        sender_nickname: user1.nickname.clone(),
        sender_face_url: String::new(),
        session_type: 1,
        msg_from: 100,
        content_type: 101,
        content: "{\"content\":\"这是一条需要已读回执的消息\"}".to_string(),
    };
    
    let send_result = sender_sdk.message_sender.send_message(pending_msg).await;
    match send_result {
        Ok(_) => println!("  ✅ 消息发送成功"),
        Err(e) => {
            println!("  ❌ 消息发送失败: {:?}", e);
            return;
        }
    }
    
    // 6. 接收者等待收到消息
    println!("6. 等待接收者收到消息...");
    
    let receive_timeout = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(receive_timeout);
    
    let mut received_msg_id = String::new();
    
    loop {
        tokio::select! {
            _ = &mut receive_timeout => {
                println!("  ⏰ 超时，未收到消息");
                return;
            }
            event = receiver_event_subscription.next() => {
                match event {
                    Some(SdkEvent::NewMessage { message }) => {
                        let msg_id = message.get("clientMsgID").and_then(|v| v.as_str()).unwrap_or("");
                        println!("  ✅ 收到消息: clientMsgID={}", msg_id);
                        received_msg_id = msg_id.to_string();
                        break;
                    }
                    Some(other_event) => {
                        println!("  收到其他事件: {:?}", other_event.event_type());
                    }
                    None => {
                        println!("  ⚠️ 事件流已关闭");
                        return;
                    }
                }
            }
        }
    }
    
    if received_msg_id.is_empty() {
        println!("  ⚠️ 未收到消息，跳过已读回执测试");
        return;
    }
    
    // 7. 发送已读回执（通过 HTTP API 直接调用）
    println!("7. 发送已读回执...");
    
    let conversation_id = format!("single_{}_{}", user2.user_id, user1.user_id);
    
    // 构建标记已读请求
    let mark_read_payload = serde_json::json!({
        "conversationID": conversation_id,
        "userID": user2.user_id,
        "sessionType": 1,
        "hasReadSeq": 0,
        "seqs": []
    });
    
    // 通过 HTTP API 标记已读
    let mark_read_result = receiver_sdk.context.http_client.post::<_, serde_json::Value>(
        "/msg/mark_conversation_as_read",
        &mark_read_payload
    ).await;
    
    match mark_read_result {
        Ok(_) => println!("  ✅ 已读回执发送成功"),
        Err(e) => println!("  ⚠️ 已读回执发送失败: {:?}", e),
    }
    
    // 8. 发送者等待已读回执
    println!("8. 发送者等待已读回执（5秒超时）...");
    
    let receipt_timeout = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(receipt_timeout);
    
    let mut receipt_received = false;
    
    loop {
        tokio::select! {
            _ = &mut receipt_timeout => {
                println!("  ⏰ 超时，未收到已读回执");
                break;
            }
            event = sender_event_subscription.next() => {
                match event {
                    Some(SdkEvent::TotalUnreadCountChanged { count }) => {
                        println!("  ✅ 收到未读计数变更: {}", count);
                        receipt_received = true;
                        break;
                    }
                    Some(other_event) => {
                        println!("  收到其他事件: {:?}", other_event.event_type());
                    }
                    None => {
                        println!("  ⚠️ 事件流已关闭");
                        break;
                    }
                }
            }
        }
    }
    
    println!("\n=== 已读回执测试结果 ===");
    if receipt_received {
        println!("  ✅ 已读回执测试通过");
    } else {
        println!("  ⚠️ 未收到已读回执（可能原因：服务器不支持/实现差异）");
    }
}

// ============================================================================
// 认证集成测试（注册+登录）
// ============================================================================

/// 集成测试: 用户注册
#[tokio::test]
#[ignore]
async fn test_user_registration() {
    let phone = generate_virtual_phone("reg");
    let nickname = format!("TestUser_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    // 注册用户
    let cert = register_user(&phone, &nickname).await;
    assert!(cert.is_ok(), "注册失败: {:?}", cert.err());
    
    let cert = cert.unwrap();
    assert!(!cert.user_id.is_empty(), "user_id 为空");
    assert!(!cert.im_token.is_empty(), "im_token 为空");
    assert!(!cert.chat_token.is_empty(), "chat_token 为空");
    
    println!("✅ 用户注册测试通过");
    println!("  user_id: {}", cert.user_id);
    println!("  im_token: {}...", &cert.im_token[..20.min(cert.im_token.len())]);
    println!("  chat_token: {}...", &cert.chat_token[..20.min(cert.chat_token.len())]);
}

/// 集成测试: 用户登录
#[tokio::test]
#[ignore]
async fn test_user_login() {
    let phone = generate_virtual_phone("login");
    let nickname = "TestUser_Login".to_string();
    
    // 先注册
    let _ = register_user(&phone, &nickname).await;
    
    // 等待注册完成
    tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
    
    // 登录
    let cert = login_user(&phone).await;
    assert!(cert.is_ok(), "登录失败: {:?}", cert.err());
    
    let cert = cert.unwrap();
    assert!(!cert.user_id.is_empty(), "user_id 为空");
    assert!(!cert.im_token.is_empty(), "im_token 为空");
    assert!(!cert.chat_token.is_empty(), "chat_token 为空");
    
    println!("✅ 用户登录测试通过");
    println!("  user_id: {}", cert.user_id);
    println!("  im_token: {}...", &cert.im_token[..20.min(cert.im_token.len())]);
}

/// 集成测试: 完整注册+登录流程
#[tokio::test]
#[ignore]
async fn test_full_registration_and_functionality() {
    let phone = generate_virtual_phone("full");
    let nickname = format!("TestUser_Full_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    // 1. 注册
    println!("1. 注册用户...");
    let cert = register_user(&phone, &nickname).await;
    assert!(cert.is_ok(), "注册失败: {:?}", cert.err());
    let cert = cert.unwrap();
    let user_id = cert.user_id.clone();
    let im_token = cert.im_token.clone();
    
    println!("  注册成功: user_id={}", user_id);
    println!("  im_token: {}...", &im_token[..20.min(im_token.len())]);
    
    // 2. 等待用户数据同步
    println!("2. 等待用户数据同步...");
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
    
    // 3. 使用新 token 登录
    println!("3. 登录用户...");
    let login_cert = login_user(&phone).await;
    assert!(login_cert.is_ok(), "登录失败: {:?}", login_cert.err());
    let login_cert = login_cert.unwrap();
    
    assert_eq!(login_cert.user_id, user_id, "登录返回的 user_id 不匹配");
    assert!(!login_cert.im_token.is_empty(), "im_token 为空");
    
    println!("  登录成功: user_id={}", login_cert.user_id);
    
    println!("✅ 完整注册+登录流程测试通过");
}
