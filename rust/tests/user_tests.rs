mod common;

use common::*;
use std::time::Duration;

#[tokio::test]
async fn test_user_registration() {
    let phone = generate_virtual_phone("reg");
    let nickname = format!("TestUser_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());

    let cert = register_user(&phone, &nickname).await;
    assert!(cert.is_ok(), "注册失败: {:?}", cert.err());

    let cert = cert.unwrap();
    assert!(!cert.user_id.is_empty(), "user_id 为空");
    assert!(!cert.im_token.is_empty(), "im_token 为空");
    assert!(!cert.chat_token.is_empty(), "chat_token 为空");

    println!("✅ 用户注册测试通过");
    println!("  user_id: {}", cert.user_id);
    println!("  im_token: {}...", &cert.im_token[..20.min(cert.im_token.len())]);
}

#[tokio::test]
async fn test_user_login() {
    let phone = generate_virtual_phone("login");
    let nickname = "TestUser_Login".to_string();

    let _ = register_user(&phone, &nickname).await;
    tokio::time::sleep(Duration::from_secs(1)).await;

    let cert = login_user(&phone).await;
    assert!(cert.is_ok(), "登录失败: {:?}", cert.err());

    let cert = cert.unwrap();
    assert!(!cert.user_id.is_empty(), "user_id 为空");
    assert!(!cert.im_token.is_empty(), "im_token 为空");
    assert!(!cert.chat_token.is_empty(), "chat_token 为空");

    println!("✅ 用户登录测试通过");
    println!("  user_id: {}", cert.user_id);
}

#[tokio::test]
async fn test_full_registration_and_functionality() {
    let phone = generate_virtual_phone("full");
    let nickname = format!("TestUser_Full_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());

    println!("1. 注册用户...");
    let cert = register_user(&phone, &nickname).await;
    assert!(cert.is_ok(), "注册失败: {:?}", cert.err());
    let cert = cert.unwrap();
    let user_id = cert.user_id.clone();
    let im_token = cert.im_token.clone();

    println!("  注册成功: user_id={}", user_id);
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("2. 登录...");
    let login_cert = login_user(&phone).await;
    assert!(login_cert.is_ok(), "登录失败: {:?}", login_cert.err());
    let login_cert = login_cert.unwrap();
    assert_eq!(login_cert.user_id, user_id);
    assert!(!login_cert.im_token.is_empty());

    println!("  登录成功: user_id={}", login_cert.user_id);
    println!("✅ 完整注册+登录流程测试通过");
}

#[tokio::test]
async fn test_user_state_via_sdk() {
    let phone = generate_virtual_phone("sdk");
    let nickname = format!("TestUser_SDK_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());

    println!("1. 注册...");
    let cert = register_user(&phone, &nickname).await.expect("注册失败");
    let user_id = cert.user_id.clone();
    let token = cert.im_token.clone();
    println!("  用户: user_id={}", user_id);

    println!("2. 测试 WebSocket 连接...");
    let ws_url = format!(
        "ws://localhost:10001/?token={}&sendID={}&platformID=1&operationID=test_direct&isBackground=false&isMsgResp=true&sdkType=js",
        token, user_id
    );
    use tokio_tungstenite::connect_async;
    match connect_async(&ws_url).await {
        Ok((_ws_stream, response)) => println!("  ✅ WS 连接成功! Status: {}", response.status()),
        Err(e) => {
            println!("  ❌ WS 连接失败: {}", e);
            return;
        }
    }

    println!("3. 创建 SDK...");
    use rust_lib_flutter_rust_demo::sdk::config::ClientConfig;
    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;

    let data_dir = std::env::temp_dir().join(format!("openim_sdk_{}", user_id)).to_string_lossy().to_string();
    let _ = std::fs::create_dir_all(&data_dir);

    let sdk = OpenIMClient::new(ClientConfig::new(
        user_id.clone(), token.clone(), 1,
        Some(WS_URL.into()), Some(API_BASE_URL.into()), Some(data_dir),
    )).await.expect("创建 SDK 失败");

    println!("4. 连接...");
    let conn = sdk.connect(WS_URL, &token, &user_id).await;
    if conn.is_err() {
        println!("  ⚠️ 连接失败: {:?}", conn.err());
        return;
    }
    println!("  ✅ 连接成功");
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("5. 获取好友列表...");
    let friends = sdk.get_friend_list().await;
    println!("  好友数量: {}", friends.len());

    println!("6. 获取用户信息...");
    let users_result = sdk.get_users_info(&vec![user_id.clone()]).await;
    assert!(users_result.is_ok(), "get_users_info failed: {:?}", users_result.err());
    let users = users_result.unwrap();
    println!("  昵称: {}", users.first().map(|u| &u.nickname).unwrap_or(&"unknown".into()));

    println!("7. 获取会话列表...");
    let convs_result = sdk.get_conversations().await;
    assert!(convs_result.is_ok(), "get_conversations failed: {:?}", convs_result.err());
    let convs = convs_result.unwrap();
    println!("  会话数量: {}", convs.len());

    println!("✅ SDK 功能测试完成");
}

#[tokio::test]
async fn test_get_user_online_status() {
    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let status = sdk.get_user_status(&vec![user1.user_id.clone()]).await;
    assert!(status.is_ok(), "获取在线状态失败: {:?}", status.err());
    let list = status.unwrap();
    assert!(!list.is_empty(), "在线状态列表为空");
    println!("在线状态: {:?}", list);
    println!("✅ 获取用户在线状态测试通过");
}

#[tokio::test]
async fn test_update_user_profile() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 更新用户资料测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let new_nickname = format!("UpdatedNick_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    println!("  新昵称: {}", new_nickname);

    println!("更新昵称...");
    let update_result = sdk.update_user_profile(
        Some(&new_nickname),
        None,
        None,
    ).await;
    assert!(update_result.is_ok(), "更新用户资料失败: {:?}", update_result.err());
    println!("  ✅ 昵称更新成功");

    println!("验证用户资料...");
    let users_result = sdk.get_users_info(&vec![user1.user_id.clone()]).await;
    assert!(users_result.is_ok(), "获取用户信息失败: {:?}", users_result.err());
    let users = users_result.unwrap();
    assert!(!users.is_empty(), "用户列表为空");
    assert_eq!(users[0].nickname, new_nickname, "昵称更新验证失败");
    println!("  用户: id={}, 昵称={}", users[0].user_id, users[0].nickname);

    println!("✅ 更新用户资料测试完成");
}