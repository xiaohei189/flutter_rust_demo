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

    let convs = sdk.get_conversations().await;
    assert!(convs.is_ok(), "get_conversations 应该返回 Ok");
    let list = convs.unwrap();
    println!("会话数量: {}", list.len());

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

    let convs = sdk.get_conversations().await.unwrap_or_default();
    println!("会话数量: {}", convs.len());

    for conv in &convs {
        println!("  会话 {}: 未读={}", conv.conversation_id, conv.unread_count);
        assert!(conv.unread_count >= 0, "unread_count 应 >= 0");
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

    let convs = sdk.get_conversations().await.unwrap_or_default();
    if convs.is_empty() {
        println!("无会话，跳过");
        return;
    }

    let conv_id = &convs[0].conversation_id;

    println!("置顶会话...");
    let pin_result = sdk.set_conversation_pinned(conv_id, true).await;
    assert!(pin_result.is_ok(), "set_conversation_pinned 应该返回 Ok");
    println!("  ✅ 置顶成功");

    let pinned = sdk.get_pinned_conversations().await;
    assert!(pinned.is_ok(), "get_pinned_conversations 应该返回 Ok");
    println!("置顶会话数: {}", pinned.unwrap().len());

    println!("取消置顶...");
    let unpin_result = sdk.set_conversation_pinned(conv_id, false).await;
    assert!(unpin_result.is_ok(), "取消置顶应该返回 Ok");

    println!("设置私聊...");
    let priv_result = sdk.set_conversation_private(conv_id, true).await;
    assert!(priv_result.is_ok(), "set_conversation_private 应该返回 Ok");
    println!("  ✅ 设置成功");

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

    let convs = sdk.get_conversations().await.unwrap_or_default();
    if convs.is_empty() {
        println!("无会话，跳过");
        return;
    }

    let conv_id = &convs[0].conversation_id;
    println!("删除会话...");
    let del_result = sdk.delete_conversation(conv_id).await;
    assert!(del_result.is_ok(), "delete_conversation 应该返回 Ok");
    println!("  ✅ 删除成功");

    println!("✅ 会话删除测试完成");
}

#[tokio::test]
#[ignore]
async fn test_conversation_draft() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 会话草稿测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let convs = sdk.get_conversations().await.unwrap_or_default();
    if convs.is_empty() {
        println!("无会话，跳过");
        return;
    }

    let conv_id = &convs[0].conversation_id;
    println!("设置草稿...");
    let draft_result = sdk.set_conversation_draft(conv_id, "Test draft content").await;
    assert!(draft_result.is_ok(), "set_conversation_draft 应该返回 Ok");
    println!("  ✅ 设置草稿成功");

    println!("清除草稿...");
    let clear_result = sdk.clear_conversation_draft(conv_id).await;
    assert!(clear_result.is_ok(), "clear_conversation_draft 应该返回 Ok");
    println!("  ✅ 清除草稿成功");

    println!("✅ 会话草稿测试完成");
}

#[tokio::test]
#[ignore]
async fn test_user_state_conversation_management() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

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

    sdk.send_text_message("Test conversation", &cert2.user_id, 1).await.unwrap();
    tokio::time::sleep(Duration::from_secs(2)).await;

    let convs = sdk.get_conversations().await.unwrap_or_default();
    println!("会话数量: {}", convs.len());

    if !convs.is_empty() {
        let cid = &convs[0].conversation_id;

        let pin_result = sdk.set_conversation_pinned(cid, true).await;
        assert!(pin_result.is_ok(), "set_conversation_pinned 应该返回 Ok");
        println!("设置置顶完成");

        let pinned = sdk.get_pinned_conversations().await;
        assert!(pinned.is_ok(), "get_pinned_conversations 应该返回 Ok");
        println!("置顶会话数: {}", pinned.unwrap().len());

        let draft_result = sdk.set_conversation_draft(cid, "Draft").await;
        assert!(draft_result.is_ok(), "set_conversation_draft 应该返回 Ok");
        println!("设置草稿完成");

        let clear_result = sdk.clear_conversation_draft(cid).await;
        assert!(clear_result.is_ok(), "clear_conversation_draft 应该返回 Ok");
        println!("清除草稿完成");

        let del_result = sdk.delete_conversation(cid).await;
        assert!(del_result.is_ok(), "delete_conversation 应该返回 Ok");
        println!("删除会话完成");
    }

    println!("✅ 会话管理测试完成");
}

#[tokio::test]
#[ignore]
async fn test_unread_count_after_message() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 消息发送后未读数测试 ===\n");

    use rust_lib_flutter_rust_demo::domain::config::ClientConfig;
    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;
    use rust_lib_flutter_rust_demo::sdk::client::types::MarkMessagesAsReadReq;

    let phone_a = generate_virtual_phone("unread_a");
    let phone_b = generate_virtual_phone("unread_b");

    println!("注册用户 A...");
    let cert_a = register_user(&phone_a, "UnreadTestA").await.expect("注册 A 失败");
    println!("注册用户 B...");
    let cert_b = register_user(&phone_b, "UnreadTestB").await.expect("注册 B 失败");

    println!("创建 SDK 并登录 B（等待推送）...");
    let data_dir_b = std::env::temp_dir()
        .join(format!("unread_b_{}", cert_b.user_id))
        .to_string_lossy()
        .to_string();
    let _ = std::fs::create_dir_all(&data_dir_b);
    let sdk_b = OpenIMClient::new(ClientConfig::new(
        cert_b.user_id.clone(), cert_b.im_token.clone(), 1,
        Some(WS_URL.into()), Some(API_BASE_URL.into()), Some(data_dir_b),
    )).await.unwrap();
    sdk_b.connect(WS_URL, &cert_b.im_token, &cert_b.user_id).await.unwrap();
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("创建 SDK 并登录 A...");
    let data_dir_a = std::env::temp_dir()
        .join(format!("unread_a_{}", cert_a.user_id))
        .to_string_lossy()
        .to_string();
    let _ = std::fs::create_dir_all(&data_dir_a);
    let sdk_a = OpenIMClient::new(ClientConfig::new(
        cert_a.user_id.clone(), cert_a.im_token.clone(), 1,
        Some(WS_URL.into()), Some(API_BASE_URL.into()), Some(data_dir_a),
    )).await.unwrap();
    sdk_a.connect(WS_URL, &cert_a.im_token, &cert_a.user_id).await.unwrap();
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("A 向 B 发送消息...");
    sdk_a.send_text_message("Hello from A to B", &cert_b.user_id, "", 1).await.expect("发送消息失败");

    println!("等待推送处理...");
    tokio::time::sleep(Duration::from_secs(5)).await;

    let convs_b = sdk_b.get_conversations().await.expect("B 获取会话失败");
    println!("B 的会话数量: {}", convs_b.len());
    assert!(!convs_b.is_empty(), "B 应至少有一个会话");

    let conv = &convs_b[0];
    let conv_id = conv.conversation_id.clone();
    println!("B 的会话 {} 未读数: {}", conv_id, conv.unread_count);
    assert!(conv.unread_count > 0, "B 的会话未读数应大于 0");

    println!("B 标记消息已读...");
    let mark_req = MarkMessagesAsReadReq {
        conversation_id: conv_id.clone(),
        session_type: 1,
        has_read_seq: conv.max_seq,
        seqs: vec![],
    };
    sdk_b.mark_messages_as_read(mark_req).await.expect("标记已读失败");

    println!("B 重置未读数为 0...");
    sdk_b.update_conversation_unread_count(&conv_id, 0).await.expect("重置未读数失败");

    let updated = sdk_b.get_conversation(&conv_id).await.expect("获取会话失败");
    match updated {
        Some(updated_conv) => {
            println!("重置后未读数: {}", updated_conv.unread_count);
            assert_eq!(updated_conv.unread_count, 0, "未读数应重置为 0");
        }
        None => panic!("会话 {} 不存在", conv_id),
    }

    println!("✅ 消息发送后未读数测试完成");
}

#[tokio::test]
#[ignore]
async fn test_unread_count_persistence() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 未读数持久化测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let convs = sdk.get_conversations().await.unwrap_or_default();
    if convs.is_empty() {
        println!("无会话，跳过持久化测试");
        return;
    }

    let conv_id = convs[0].conversation_id.clone();
    let original_unread = convs[0].unread_count;
    println!("原始未读数: {} (会话: {})", original_unread, conv_id);

    let test_unread: i64 = 42;
    println!("设置未读数 -> {}", test_unread);
    sdk.update_conversation_unread_count(&conv_id, test_unread)
        .await
        .expect("设置未读数失败");

    let conv_after_set = sdk.get_conversation(&conv_id).await.expect("获取会话失败");
    match &conv_after_set {
        Some(c) => {
            println!("设置后未读数: {}", c.unread_count);
            assert_eq!(c.unread_count as i64, test_unread, "设置未读数后应等于 {}", test_unread);
        }
        None => panic!("会话 {} 不存在", conv_id),
    }

    println!("登出...");
    sdk.logout().await.expect("登出失败");

    println!("重新登录...");
    sdk.login(&user1.user_id, &im_token).await.expect("重新登录失败");
    tokio::time::sleep(Duration::from_secs(3)).await;

    let conv_after_relogin = sdk.get_conversation(&conv_id).await.expect("重新登录后获取会话失败");
    match &conv_after_relogin {
        Some(c) => {
            println!("重新登录后未读数: {}", c.unread_count);
            assert_eq!(c.unread_count as i64, test_unread,
                "重新登录后未读数应保持为 {}，但实际为 {}", test_unread, c.unread_count);
        }
        None => panic!("重新登录后会话 {} 不存在", conv_id),
    }

    println!("✅ 未读数持久化测试完成");
}
