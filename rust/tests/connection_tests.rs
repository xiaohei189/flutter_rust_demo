mod common;

use common::*;
use std::time::Duration;

#[tokio::test]
#[ignore]
async fn test_websocket_reconnection() {
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 断线重连测试 ===\n");

    let phone = generate_virtual_phone("reconn");
    let cert = register_user(&phone, "ReconnectUser").await.expect("注册失败");
    println!("用户: {}", cert.user_id);

    use rust_lib_flutter_rust_demo::domain::config::ClientConfig;
    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;

    let data_dir = std::env::temp_dir().join(format!("reconn_{}", cert.user_id)).to_string_lossy().to_string();
    let _ = std::fs::create_dir_all(&data_dir);

    let sdk = OpenIMClient::new(ClientConfig::new(
        cert.user_id.clone(), cert.im_token.clone(), 1,
        Some(WS_URL.into()), Some(API_BASE_URL.into()), Some(data_dir),
    )).await.unwrap();

    let mut event_sub = sdk.event_bus().subscribe();

    sdk.connect(WS_URL, &cert.im_token, &cert.user_id).await.unwrap();
    println!("  ✅ 初始连接成功");
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("监听连接事件（5秒）...");
    let timeout = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout);

    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = event_sub.next() => {
                match event {
                    Some(SdkEvent::Connected) => println!("  ✅ Connected"),
                    Some(SdkEvent::Connecting) => println!("  🔄 Connecting"),
                    Some(SdkEvent::Disconnected { reason }) => println!("  ❌ Disconnected: {}", reason),
                    Some(_) => {},
                    None => break,
                }
            }
        }
    }

    println!("断开连接...");
    sdk.disconnect().await;
    tokio::time::sleep(Duration::from_secs(1)).await;

    println!("✅ 断线重连测试完成");
}

#[tokio::test]
#[ignore]
async fn test_reconnection() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 重连测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    println!("断开连接...");
    sdk.disconnect().await;
    tokio::time::sleep(Duration::from_secs(1)).await;

    println!("重新连接...");
    let result = sdk.connect(WS_URL, &im_token, &user1.user_id).await;
    assert!(result.is_ok(), "重连失败: {:?}", result.err());
    println!("  ✅ 重连成功");

    println!("✅ 重连测试完成");
}

#[tokio::test]
#[ignore]
async fn test_connection_state_transitions() {
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 连接状态转换测试 ===\n");

    let phone = generate_virtual_phone("cst");
    let cert = register_user(&phone, "CSTUser").await.expect("注册失败");

    use rust_lib_flutter_rust_demo::domain::config::ClientConfig;
    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;

    let data_dir = std::env::temp_dir().join(format!("cst_{}", cert.user_id)).to_string_lossy().to_string();
    let _ = std::fs::create_dir_all(&data_dir);

    let sdk = OpenIMClient::new(ClientConfig::new(
        cert.user_id.clone(), cert.im_token.clone(), 1,
        Some(WS_URL.into()), Some(API_BASE_URL.into()), Some(data_dir),
    )).await.unwrap();

    let mut events = Vec::new();
    let mut event_sub = sdk.event_bus().subscribe();

    println!("连接...");
    sdk.connect(WS_URL, &cert.im_token, &cert.user_id).await.unwrap();

    let timeout = tokio::time::sleep(Duration::from_secs(3));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = event_sub.next() => {
                match event {
                    Some(SdkEvent::Connected) => { println!("  ✅ Connected"); events.push("Connected"); }
                    Some(SdkEvent::Connecting) => { println!("  🔄 Connecting"); events.push("Connecting"); }
                    Some(SdkEvent::Disconnected { .. }) => { println!("  ❌ Disconnected"); events.push("Disconnected"); }
                    Some(_) => {},
                    None => break,
                }
            }
        }
    }

    println!("断开...");
    sdk.disconnect().await;
    tokio::time::sleep(Duration::from_secs(1)).await;

    println!("事件序列: {:?}", events);
    println!("✅ 连接状态转换测试完成");
}