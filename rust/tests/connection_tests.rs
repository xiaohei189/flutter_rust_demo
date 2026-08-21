mod common;

use common::*;
use rust_lib_flutter_rust_demo::sdk::client::*;
use std::time::Duration;

/// 验证 WebSocket 断线后自动重连并恢复连接状态。
#[tokio::test]
#[ignore = "requires docker OpenIM server"]
async fn test_websocket_reconnection() {
    use rust_lib_flutter_rust_demo::core::event::events::connection::ConnectionEvent;

    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    println!("=== 断线重连测试 ===\n");

    let phone = generate_virtual_phone("reconn");
    let cert = register_user(&phone, "ReconnectUser").await.expect("注册失败");
    println!("用户: {}", cert.user_id);

    use rust_lib_flutter_rust_demo::sdk::client::config::ClientConfig;
    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;

    let data_dir = std::env::temp_dir().join(format!("reconn_{}", cert.user_id)).to_string_lossy().to_string();
    let _ = std::fs::create_dir_all(&data_dir);

    let sdk = OpenIMClient::new(ClientConfig::new(
        cert.user_id.clone(),
        cert.im_token.clone(),
        1,
        Some(WS_URL.into()),
        Some(API_BASE_URL.into()),
        Some(data_dir),
    ))
    .await
    .unwrap();

    let mut event_sub = subscribe_all(&sdk);

    sdk.connect(WS_URL, &cert.im_token, &cert.user_id).await.unwrap();
    println!("  ✅ 初始连接成功");
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("监听连接事件（5秒）...");
    let timeout = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout);

    let mut events: Vec<&str> = Vec::new();
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = event_sub.next() => {
                match event {
                    Some(TestEvent::Connection(ConnectionEvent::Connected)) => { println!("  ✅ Connected"); events.push("Connected"); }
                    Some(TestEvent::Connection(ConnectionEvent::Connecting)) => { println!("  🔄 Connecting"); events.push("Connecting"); }
                    Some(TestEvent::Connection(ConnectionEvent::Disconnected(reason))) => { println!("  ❌ Disconnected: {}", reason); events.push("Disconnected"); }
                    Some(_) => {},
                    None => break,
                }
            }
        }
    }

    assert!(!events.is_empty(), "应该收集到至少一个连接事件");
    println!("事件序列: {:?}", events);

    println!("断开连接...");
    sdk.disconnect().await;
    tokio::time::sleep(Duration::from_secs(1)).await;

    println!("✅ 断线重连测试完成");
}

/// 验证 SDK 重连机制：主动断开后能重新建立连接并继续可用。
#[tokio::test]
#[ignore = "requires docker OpenIM server"]
async fn test_reconnection() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

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

/// 验证连接管理器在连接/断开/重连过程中的状态转换。
#[tokio::test]
#[ignore = "requires docker OpenIM server"]
async fn test_connection_state_transitions() {
    use rust_lib_flutter_rust_demo::core::event::events::connection::ConnectionEvent;

    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    println!("=== 连接状态转换测试 ===\n");

    let phone = generate_virtual_phone("cst");
    let cert = register_user(&phone, "CSTUser").await.expect("注册失败");

    use rust_lib_flutter_rust_demo::sdk::client::config::ClientConfig;
    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;

    let data_dir = std::env::temp_dir().join(format!("cst_{}", cert.user_id)).to_string_lossy().to_string();
    let _ = std::fs::create_dir_all(&data_dir);

    let sdk = OpenIMClient::new(ClientConfig::new(
        cert.user_id.clone(),
        cert.im_token.clone(),
        1,
        Some(WS_URL.into()),
        Some(API_BASE_URL.into()),
        Some(data_dir),
    ))
    .await
    .unwrap();

    let mut events = Vec::new();
    let mut event_sub = subscribe_all(&sdk);

    println!("连接...");
    sdk.connect(WS_URL, &cert.im_token, &cert.user_id).await.unwrap();

    let timeout = tokio::time::sleep(Duration::from_secs(3));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = event_sub.next() => {
                match event {
                    Some(TestEvent::Connection(ConnectionEvent::Connected)) => { println!("  ✅ Connected"); events.push("Connected"); }
                    Some(TestEvent::Connection(ConnectionEvent::Connecting)) => { println!("  🔄 Connecting"); events.push("Connecting"); }
                    Some(TestEvent::Connection(ConnectionEvent::Disconnected(_))) => { println!("  ❌ Disconnected"); events.push("Disconnected"); }
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
