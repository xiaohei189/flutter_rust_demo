use rust_lib_flutter_rust_demo::sdk::config::ClientConfig;
use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;
use serde::{Deserialize, Serialize};
use std::time::Duration;

pub const API_BASE_URL: &str = "http://localhost:10002";
pub const WS_URL: &str = "ws://localhost:10001";
pub const CHAT_API_BASE_URL: &str = "http://localhost:10008";
pub const DEFAULT_VERIFICATION_CODE: &str = "666666";

// 固定测试手机号
pub const SENDER_PHONE: &str = "17764008284";   // 发送方
pub const RECEIVER_PHONE: &str = "17764008283"; // 接收方
// 群组测试固定手机号
pub const GROUP_OWNER_PHONE: &str = "17764008280";   // 群主
pub const GROUP_MEMBER1_PHONE: &str = "17764008281"; // 群成员1
pub const GROUP_MEMBER2_PHONE: &str = "17764008282"; // 群成员2
pub const GROUP_APPLICANT_PHONE: &str = "17764008285"; // 申请人

#[derive(Clone, Debug)]
pub struct TestAccount {
    pub user_id: String,
    pub phone: String,
    pub nickname: String,
    pub im_token: Option<String>,
    pub chat_token: Option<String>,
}

#[derive(Deserialize, Debug)]
pub struct RegisterResponse {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "imToken")]
    pub im_token: String,
    #[serde(rename = "chatToken")]
    pub chat_token: String,
}

#[derive(Deserialize, Debug)]
pub struct LoginCertificate {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "imToken")]
    pub im_token: String,
    #[serde(rename = "chatToken")]
    pub chat_token: String,
}

#[derive(Serialize)]
pub struct GetUsersInfoReq {
    #[serde(rename = "userIDs")]
    pub user_ids: Vec<String>,
}

#[derive(Deserialize, Debug)]
pub struct UserInfoResp {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "nickname")]
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
}

pub fn generate_virtual_phone(test_name: &str) -> String {
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let name_hash: u64 = test_name.bytes().fold(0u64, |acc, b| acc.wrapping_mul(31).wrapping_add(b as u64));
    format!("138{:07}{:02}", timestamp % 10000000, name_hash % 100)
}

pub async fn register_user(phone: &str, nickname: &str) -> Result<RegisterResponse, String> {
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
        let outer: serde_json::Value = serde_json::from_str(&body)
            .map_err(|e| format!("解析响应失败: {}, body={}", e, body))?;

        if let Some(err_code) = outer.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                return Err(format!("注册失败: errCode={}, body={}", err_code, body));
            }
        }

        let data = outer.get("data").ok_or_else(|| format!("响应缺少 data 字段: body={}", body))?;
        let cert: RegisterResponse = serde_json::from_value(data.clone())
            .map_err(|e| format!("解析失败: {}, body={}", e, body))?;
        Ok(cert)
    } else {
        Err(format!("注册失败: status={}, body={}", status, body))
    }
}

pub async fn login_user(phone: &str) -> Result<LoginCertificate, String> {
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
        let outer: serde_json::Value = serde_json::from_str(&body)
            .map_err(|e| format!("解析响应失败: {}, body={}", e, body))?;

        if let Some(err_code) = outer.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                return Err(format!("登录失败: errCode={}, body={}", err_code, body));
            }
        }

        let data = outer.get("data").ok_or_else(|| format!("响应缺少 data 字段: body={}", body))?;
        let cert: LoginCertificate = serde_json::from_value(data.clone())
            .map_err(|e| format!("解析失败: {}, body={}", e, body))?;
        Ok(cert)
    } else {
        Err(format!("登录失败: status={}, body={}", status, body))
    }
}

pub async fn login_account(account: &TestAccount) -> Result<(String, String), String> {
    if let (Some(im_token), Some(chat_token)) = (&account.im_token, &account.chat_token) {
        return Ok((im_token.clone(), chat_token.clone()));
    }
    let cert = login_user(&account.phone).await?;
    Ok((cert.im_token, cert.chat_token))
}

pub async fn get_or_create_user1() -> TestAccount {
    if let (Ok(user_id), Ok(phone)) = (
        std::env::var("OPENIM_TEST_USER1_ID"),
        std::env::var("OPENIM_TEST_USER1_PHONE"),
    ) {
        println!("使用固定测试账号1(发送方): user_id={}, phone={}", user_id, phone);
        return TestAccount {
            user_id,
            phone,
            nickname: "TestSender".to_string(),
            im_token: None,
            chat_token: None,
        };
    }

    let phone = SENDER_PHONE;
    let nickname = "TestSender";
    println!("使用固定发送方手机号: {}", phone);
    let account = login_or_register_user(phone, nickname).await;
    println!("发送方账号: user_id={}, phone={}", account.user_id, phone);

    println!("  export OPENIM_TEST_USER1_ID={}", account.user_id);
    println!("  export OPENIM_TEST_USER1_PHONE={}", phone);

    account
}

pub async fn get_or_create_user2() -> TestAccount {
    if let (Ok(user_id), Ok(phone)) = (
        std::env::var("OPENIM_TEST_USER2_ID"),
        std::env::var("OPENIM_TEST_USER2_PHONE"),
    ) {
        println!("使用固定测试账号2(接收方): user_id={}, phone={}", user_id, phone);
        return TestAccount {
            user_id,
            phone,
            nickname: "TestReceiver".to_string(),
            im_token: None,
            chat_token: None,
        };
    }

    let phone = RECEIVER_PHONE;
    let nickname = "TestReceiver";
    println!("使用固定接收方手机号: {}", phone);
    let account = login_or_register_user(phone, nickname).await;
    println!("接收方账号: user_id={}, phone={}", account.user_id, phone);

    println!("  export OPENIM_TEST_USER2_ID={}", account.user_id);
    println!("  export OPENIM_TEST_USER2_PHONE={}", phone);

    account
}

pub async fn get_or_create_group_owner() -> TestAccount {
    login_or_register_user(GROUP_OWNER_PHONE, "GroupOwner").await
}

pub async fn get_or_create_group_member1() -> TestAccount {
    login_or_register_user(GROUP_MEMBER1_PHONE, "GroupMember1").await
}

pub async fn get_or_create_group_member2() -> TestAccount {
    login_or_register_user(GROUP_MEMBER2_PHONE, "GroupMember2").await
}

pub async fn get_or_create_group_applicant() -> TestAccount {
    login_or_register_user(GROUP_APPLICANT_PHONE, "GroupApplicant").await
}

pub async fn create_sdk(account: &TestAccount, im_token: &str) -> OpenIMClient {
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
    sdk.login(&account.user_id, im_token).await.expect("登录失败");
    tokio::time::sleep(std::time::Duration::from_secs(2)).await;

    sdk
}

// ============================================================================
// 消息内容构建辅助函数
// ============================================================================

pub fn build_text_content(text: &str) -> String {
    format!("{{\"content\":\"{}\"}}", text)
}

pub fn build_picture_content() -> String {
    r#"{"uuid":"test_picture_uuid","type":"jpg","size":1024,"width":800,"height":600,"url":"http://example.com/test.jpg","snapshotUrl":"http://example.com/test_snapshot.jpg","originalUrl":"http://example.com/test_original.jpg"}"#.to_string()
}

pub fn build_sound_content() -> String {
    r#"{"uuid":"test_sound_uuid","soundPath":"http://example.com/test_sound.mp3","sourceUrl":"http://example.com/test_sound_source.mp3","dataSize":2048,"duration":5}"#.to_string()
}

pub fn build_video_content() -> String {
    r#"{"videoPath":"http://example.com/test_video.mp4","videoUUID":"test_video_uuid","videoType":"mp4","videoSize":4096,"duration":10,"snapshotPath":"http://example.com/test_video_snapshot.jpg","snapshotUUID":"test_snapshot_uuid","snapshotSize":1024,"snapshotWidth":800,"snapshotHeight":600,"snapshotUrl":"http://example.com/test_snapshot.jpg"}"#.to_string()
}

pub fn build_file_content() -> String {
    r#"{"filePath":"http://example.com/test_file.pdf","fileName":"test_file.pdf","uuid":"test_file_uuid","fileSize":8192}"#.to_string()
}

pub fn build_custom_content() -> String {
    r#"{"data":"{\"type\":\"test\",\"content\":\"这是一条自定义消息\"}","description":"测试自定义消息","extension":"{\"key\":\"value\"}"}"#.to_string()
}

pub fn build_quote_content() -> String {
    r#"{"text":"这是一条引用消息","quoteMessage":{"clientMsgID":"quoted_msg_id","content":"被引用的消息"}}"#.to_string()
}

pub fn build_face_content() -> String {
    r#"{"index":1,"data":"smile"}"#.to_string()
}

// ============================================================================
// 固定手机号用户辅助函数
// ============================================================================

/// 使用指定手机号登录用户，如果用户不存在则自动注册
pub async fn login_or_register_user(phone: &str, nickname: &str) -> TestAccount {
    // 尝试登录
    match login_user(phone).await {
        Ok(cert) => {
            println!("用户已存在，登录成功: phone={}, user_id={}", phone, cert.user_id);
            TestAccount {
                user_id: cert.user_id,
                phone: phone.to_string(),
                nickname: nickname.to_string(),
                im_token: Some(cert.im_token),
                chat_token: Some(cert.chat_token),
            }
        }
        Err(e) => {
            println!("用户不存在（{}），正在注册: phone={}", e, phone);
            let reg = register_user(phone, nickname).await.expect("注册用户失败");
            TestAccount {
                user_id: reg.user_id,
                phone: phone.to_string(),
                nickname: nickname.to_string(),
                im_token: Some(reg.im_token),
                chat_token: Some(reg.chat_token),
            }
        }
    }
}

/// 创建一个全新的随机账号（每次调用注册新用户，确保无历史数据）
pub async fn create_random_account(nickname: &str) -> TestAccount {
    let phone = generate_virtual_phone(&format!("{}_{}", nickname, std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos()));
    println!("创建随机账号: nickname={}, phone={}", nickname, phone);
    let reg = register_user(&phone, nickname).await
        .unwrap_or_else(|e| panic!("注册随机账号失败: {}", e));
    TestAccount {
        user_id: reg.user_id,
        phone,
        nickname: nickname.to_string(),
        im_token: Some(reg.im_token),
        chat_token: Some(reg.chat_token),
    }
}

/// 确保两个用户是好友关系
/// 如果还不是好友，则 user1_sdk 向 user2 发送好友申请，user2_sdk 接受
pub async fn ensure_friends(
    user1_sdk: &OpenIMClient,
    user1_id: &str,
    user2_sdk: &OpenIMClient,
    user2_id: &str,
) {
    // 先同步好友列表，确保 is_friend 检查准确
    user1_sdk.sync_friends().await.ok();
    user2_sdk.sync_friends().await.ok();

    // 双向检查
    let user1_is_friend_of_user2 = user1_sdk.is_friend(user2_id).await;
    let user2_is_friend_of_user1 = user2_sdk.is_friend(user1_id).await;

    if user1_is_friend_of_user2 && user2_is_friend_of_user1 {
        println!("双方已经是好友: {} <-> {}", user1_id, user2_id);
        return;
    }

    // user1 向 user2 发送好友申请
    println!("{} 向 {} 发送好友申请...", user1_id, user2_id);
    let add_result = user1_sdk.add_friend(user2_id, Some("测试加好友")).await;
    match &add_result {
        Ok(_) => {
            println!("好友申请发送成功");
        }
        Err(e) => {
            // errCode 1304 = RelationshipAlreadyError（已经是好友）
            let msg = format!("{:?}", e);
            if msg.contains("1304") || msg.contains("RelationshipAlready") {
                println!("双方已经是好友（服务器返回 RelationshipAlready）");
                return;
            }
            println!("发送好友申请失败: {:?}", e);
            // 等一下再检查
            tokio::time::sleep(Duration::from_secs(2)).await;
            user1_sdk.sync_friends().await.ok();
            let still_not = !user1_sdk.is_friend(user2_id).await;
            if still_not {
                panic!("好友申请失败且仍不是好友: {:?}", e);
            }
            println!("实际上已经是好友了");
            return;
        }
    }

    // 等待好友申请送达
    tokio::time::sleep(Duration::from_secs(2)).await;

    // user2 查看待处理的好友申请并接受
    println!("{} 正在处理好友申请...", user2_id);
    let apply_list = user2_sdk.get_friend_apply_list().await;
    match apply_list {
        Ok(apply_infos) => {
            for apply in apply_infos {
                if apply.user_id == user1_id && apply.handle_result == 0 {
                    println!("{} 接受 {} 的好友申请", user2_id, user1_id);
                    let accept_result = user2_sdk
                        .accept_friend_application(user1_id, Some("同意加好友"))
                        .await;
                    assert!(
                        accept_result.is_ok(),
                        "接受好友申请失败: {:?}",
                        accept_result.err()
                    );
                    // 等待好友关系同步
                    tokio::time::sleep(Duration::from_secs(2)).await;
                    println!("好友关系建立成功: {} <-> {}", user1_id, user2_id);
                    return;
                }
            }
            println!("未找到来自 {} 的待处理好友申请，可能已经是好友", user1_id);
        }
        Err(e) => {
            println!("获取好友申请列表失败: {:?}，可能已经是好友", e);
        }
    }

    // 最终验证
    tokio::time::sleep(Duration::from_secs(1)).await;
    let final_check = user1_sdk.is_friend(user2_id).await;
    println!("最终好友关系检查: {} -> {} = {}", user1_id, user2_id, final_check);
}

// ============================================================================
// 测试文件生成辅助函数
// ============================================================================

/// 生成最小合法 WAV 文件（8kHz 单声道 16bit，约 16KB）
/// 格式：RIFF header + fmt chunk + data chunk
pub fn create_test_audio_file(dir: &std::path::Path) -> std::path::PathBuf {
    let path = dir.join("test_audio.wav");
    if path.exists() {
        return path;
    }

    let sample_rate: u32 = 8000;
    let num_channels: u16 = 1;
    let bits_per_sample: u16 = 16;
    let num_samples: u32 = sample_rate; // 1 second
    let data_size = num_samples * (bits_per_sample as u32 / 8) * (num_channels as u32);

    let mut wav = Vec::new();
    // RIFF header
    wav.extend_from_slice(b"RIFF");
    wav.extend_from_slice(&(36 + data_size).to_le_bytes());
    wav.extend_from_slice(b"WAVE");
    // fmt chunk
    wav.extend_from_slice(b"fmt ");
    wav.extend_from_slice(&16u32.to_le_bytes()); // chunk size
    wav.extend_from_slice(&1u16.to_le_bytes());  // PCM format
    wav.extend_from_slice(&num_channels.to_le_bytes());
    wav.extend_from_slice(&sample_rate.to_le_bytes());
    wav.extend_from_slice(&(sample_rate * num_channels as u32 * bits_per_sample as u32 / 8).to_le_bytes());
    wav.extend_from_slice(&(num_channels as u16 * bits_per_sample / 8).to_le_bytes());
    wav.extend_from_slice(&bits_per_sample.to_le_bytes());
    // data chunk
    wav.extend_from_slice(b"data");
    wav.extend_from_slice(&data_size.to_le_bytes());
    // 1 second of silence (zero bytes)
    wav.extend_from_slice(&vec![0u8; data_size as usize]);

    std::fs::write(&path, &wav).expect("创建测试音频文件失败");
    path
}

/// 生成最小合法 MP4 文件（约 1KB，仅含 moov+mdat 容器结构）
/// 这是一个最小可解析的 MP4，足以通过上传测试
pub fn create_test_video_file(dir: &std::path::Path) -> std::path::PathBuf {
    let path = dir.join("test_video.mp4");
    if path.exists() {
        return path;
    }

    // 最小合法 MP4：moov box + 空 mdat box
    let mut mp4 = Vec::new();

    // ftyp box
    mp4.extend_from_slice(&[0x00, 0x00, 0x00, 0x14]); // size = 20
    mp4.extend_from_slice(b"ftyp");
    mp4.extend_from_slice(b"isom");
    mp4.extend_from_slice(&[0x00, 0x00, 0x00, 0x01]); // version
    mp4.extend_from_slice(b"isom");
    mp4.extend_from_slice(b"iso2");
    mp4.extend_from_slice(b"mp41");

    // moov box (minimal, empty content)
    mp4.extend_from_slice(&[0x00, 0x00, 0x00, 0x08]); // size = 8
    mp4.extend_from_slice(b"moov");

    // mdat box (minimal)
    mp4.extend_from_slice(&[0x00, 0x00, 0x00, 0x08]); // size = 8
    mp4.extend_from_slice(b"mdat");

    std::fs::write(&path, &mp4).expect("创建测试视频文件失败");
    path
}

/// 生成 1x1 像素的 PNG 文件（67 字节，最小合法 PNG）
pub fn create_test_snapshot_file(dir: &std::path::Path) -> std::path::PathBuf {
    let path = dir.join("test_snapshot.png");
    if path.exists() {
        return path;
    }

    let png_bytes: Vec<u8> = vec![
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
        0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
        0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
        0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
        0x44, 0xAE, 0x42, 0x60, 0x82,
    ];
    std::fs::write(&path, &png_bytes).expect("创建测试截图文件失败");
    path
}

// ============================================================================
// Mock 服务器 — 用于离线集成测试
// ============================================================================

/// 使用 wiremock 创建本地 mock HTTP 服务器，测试不依赖外部服务
#[cfg(test)]
pub mod mock {
    use wiremock::MockServer;
    use wiremock::matchers::{method, path};
    use wiremock::ResponseTemplate;

    /// 创建一个本地 mock 服务器，并注册所有基础 API 端点
    pub async fn start_mock_server() -> MockServer {
        let server = MockServer::start().await;
        register_default_handlers(&server).await;
        server
    }

    /// 注册默认的 API 端点处理
    async fn register_default_handlers(server: &MockServer) {
        // 注册成功响应
        server.register(
            wiremock::Mock::given(method("POST"))
                .and(path("/account/register"))
                .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                    "errCode": 0,
                    "errMsg": "",
                    "data": {
                        "userID": "mock_user_001",
                        "imToken": "mock_im_token",
                        "chatToken": "mock_chat_token"
                    }
                })))
        ).await;

        server.register(
            wiremock::Mock::given(method("POST"))
                .and(path("/account/login"))
                .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                    "errCode": 0,
                    "errMsg": "",
                    "data": {
                        "userID": "mock_user_001",
                        "imToken": "mock_im_token",
                        "chatToken": "mock_chat_token"
                    }
                })))
        ).await;

        // 通用的成功响应（用于其他所有 API 端点）
        server.register(
            wiremock::Mock::given(method("POST"))
                .and(path("/msg/revoke_msg"))
                .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                    "errCode": 0, "errMsg": ""
                })))
        ).await;

        server.register(
            wiremock::Mock::given(method("POST"))
                .and(path("/msg/delete_msgs"))
                .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                    "errCode": 0, "errMsg": ""
                })))
        ).await;

        server.register(
            wiremock::Mock::given(method("POST"))
                .and(path("/msg/mark_msgs_as_read"))
                .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                    "errCode": 0, "errMsg": ""
                })))
        ).await;
    }
}
