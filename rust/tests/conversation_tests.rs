mod common;

use common::*;
use std::time::Duration;

#[tokio::test]
#[ignore]
async fn test_conversation_list_sync() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 会话列表同步测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let convs = sdk.conversation.get_all_conversations().await;
    match &convs {
        Ok(list) => println!("会话数量: {}", list.len()),
        Err(e) => println!("获取失败: {:?}", e),
    }

    println!("✅ 会话列表同步测试完成");
}

#[tokio::test]
#[ignore]
async fn test_conversation_unread_count() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 会话未读数测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let convs = sdk.conversation.get_all_conversations().await.unwrap_or_default();
    println!("会话数量: {}", convs.len());

    for conv in &convs {
        println!("  会话 {}: 未读={}", conv.conversation_id, conv.unread_count);
    }

    println!("✅ 会话未读数测试完成");
}

#[tokio::test]
#[ignore]
async fn test_conversation_pinned_private() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 会话置顶/私聊测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let convs = sdk.conversation.get_all_conversations().await.unwrap_or_default();
    if convs.is_empty() {
        println!("无会话，跳过");
        return;
    }

    let conv_id = &convs[0].conversation_id;

    println!("置顶会话...");
    match sdk.conversation.set_pinned(conv_id, true).await {
        Ok(_) => println!("  ✅ 置顶成功"),
        Err(e) => println!("  ❌ 失败: {:?}", e),
    }

    let pinned = sdk.conversation.get_pinned_conversations().await;
    match pinned {
        Ok(p) => println!("置顶会话数: {}", p.len()),
        Err(e) => println!("获取置顶失败: {:?}", e),
    }

    println!("取消置顶...");
    let _ = sdk.conversation.set_pinned(conv_id, false).await;

    println!("设置私聊...");
    match sdk.conversation.set_private_chat(conv_id, true).await {
        Ok(_) => println!("  ✅ 设置成功"),
        Err(e) => println!("  ❌ 失败: {:?}", e),
    }

    println!("✅ 会话置顶/私聊测试完成");
}

#[tokio::test]
#[ignore]
async fn test_conversation_delete() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 会话删除测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let convs = sdk.conversation.get_all_conversations().await.unwrap_or_default();
    if convs.is_empty() {
        println!("无会话，跳过");
        return;
    }

    let conv_id = &convs[0].conversation_id;
    println!("删除会话...");
    match sdk.conversation.delete_conversation(conv_id).await {
        Ok(_) => println!("  ✅ 删除成功"),
        Err(e) => println!("  ❌ 失败: {:?}", e),
    }

    println!("✅ 会话删除测试完成");
}

#[tokio::test]
#[ignore]
async fn test_user_state_conversation_management() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;
    use rust_lib_flutter_rust_demo::domain::config::ClientConfig;
    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;

    let phone1 = generate_virtual_phone("ucv1");
    let phone2 = generate_virtual_phone("ucv2");

    println!("注册用户...");
    let cert1 = register_user(&phone1, "UConv1").await.expect("注册失败");
    let cert2 = register_user(&phone2, "UConv2").await.expect("注册失败");

    let data_dir = std::env::temp_dir().join(format!("ucv_{}", cert1.user_id)).to_string_lossy().to_string();
    let _ = std::fs::create_dir_all(&data_dir);

    let sdk = OpenIMClient::new(ClientConfig::new(
        cert1.user_id.clone(), cert1.im_token.clone(), 1,
        Some(WS_URL.into()), Some(API_BASE_URL.into()), Some(data_dir),
    )).await.unwrap();
    sdk.connect(WS_URL, &cert1.im_token, &cert1.user_id).await.unwrap();
    tokio::time::sleep(Duration::from_secs(2)).await;

    let msg = PendingMessage {
        client_msg_id: format!("ucv_msg_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()),
        send_id: cert1.user_id.clone(),
        recv_id: cert2.user_id.clone(),
        group_id: String::new(),
        sender_platform_id: 1,
        sender_nickname: "UConv1".into(),
        sender_face_url: String::new(),
        session_type: 1,
        msg_from: 100,
        content_type: 101,
        content: r#"{"content":"Test conversation"}"#.to_string(),
    };
    sdk.message_sender.send_message(msg).await.unwrap();
    tokio::time::sleep(Duration::from_secs(2)).await;

    let convs = sdk.conversation.get_all_conversations().await.unwrap_or_default();
    println!("会话数量: {}", convs.len());

    if !convs.is_empty() {
        let cid = &convs[0].conversation_id;

        let _ = sdk.conversation.set_pinned(cid, true).await;
        println!("设置置顶完成");

        let pinned = sdk.conversation.get_pinned_conversations().await;
        match pinned {
            Ok(p) => println!("置顶会话数: {}", p.len()),
            Err(e) => println!("获取置顶失败: {:?}", e),
        }

        let _ = sdk.conversation.set_draft(cid, "Draft").await;
        println!("设置草稿完成");

        let _ = sdk.conversation.clear_draft(cid).await;
        println!("清除草稿完成");

        let _ = sdk.conversation.delete_conversation(cid).await;
        println!("删除会话完成");
    }

    println!("✅ 会话管理测试完成");
}
