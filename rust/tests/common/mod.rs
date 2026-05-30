use rust_lib_flutter_rust_demo::domain::config::ClientConfig;
use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;
use serde::{Deserialize, Serialize};

pub const API_BASE_URL: &str = "http://localhost:10002";
pub const WS_URL: &str = "ws://localhost:10001";
pub const CHAT_API_BASE_URL: &str = "http://localhost:10008";
pub const DEFAULT_VERIFICATION_CODE: &str = "666666";

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
        println!("使用固定测试账号1: user_id={}, phone={}", user_id, phone);
        return TestAccount {
            user_id,
            phone,
            nickname: "TestUser1".to_string(),
            im_token: None,
            chat_token: None,
        };
    }

    println!("注册新测试账号1...");
    let phone = generate_virtual_phone("user1");
    let nickname = format!("TestUser1_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    let cert = register_user(&phone, &nickname).await.expect("注册失败");

    println!("  export OPENIM_TEST_USER1_ID={}", cert.user_id);
    println!("  export OPENIM_TEST_USER1_PHONE={}", phone);

    TestAccount {
        user_id: cert.user_id,
        phone,
        nickname,
        im_token: Some(cert.im_token),
        chat_token: Some(cert.chat_token),
    }
}

pub async fn get_or_create_user2() -> TestAccount {
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

    println!("注册新测试账号2...");
    let phone = generate_virtual_phone("user2");
    let nickname = format!("TestUser2_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    let cert = register_user(&phone, &nickname).await.expect("注册失败");

    println!("  export OPENIM_TEST_USER2_ID={}", cert.user_id);
    println!("  export OPENIM_TEST_USER2_PHONE={}", phone);

    TestAccount {
        user_id: cert.user_id,
        phone,
        nickname,
        im_token: Some(cert.im_token),
        chat_token: Some(cert.chat_token),
    }
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
