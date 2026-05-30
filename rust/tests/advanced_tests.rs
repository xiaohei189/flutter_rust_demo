mod common;

use common::*;
use std::time::Duration;

#[tokio::test]
#[ignore]
async fn test_history_message_pull() {
    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;

    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 历史消息拉取测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    println!("1. 发送测试消息...");
    let sender_sdk = create_sdk(&user1, &user1_im_token).await;

    for i in 1..=3 {
        let msg = PendingMessage {
            client_msg_id: format!("history_{}_{}", i,
                std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()),
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
        let _ = sender_sdk.message_sender.send_message(msg).await;
        tokio::time::sleep(Duration::from_millis(300)).await;
    }

    println!("  消息发送完成...");
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("2. 重新创建接收者 SDK...");
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;

    println!("3. 获取会话列表...");
    let convs = receiver_sdk.conversation.get_all_conversations().await;
    match &convs {
        Ok(list) => {
            println!("  会话数量: {}", list.len());
            if !list.is_empty() {
                for conv in list {
                    println!("  会话: {} (未读: {})", conv.conversation_id, conv.unread_count);
                }
                println!("  ✅ 历史消息拉取测试通过");
            } else {
                println!("  ⚠️ 未找到会话");
            }
        }
        Err(e) => println!("  ❌ 获取失败: {:?}", e),
    }

    println!("✅ 历史消息拉取测试完成");
}

#[tokio::test]
#[ignore]
async fn test_message_revoke() {
    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;

    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 消息撤回测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    println!("发送消息...");
    let client_msg_id = format!("revoke_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
    let msg = PendingMessage {
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
        content: r#"{"content":"将被撤回的消息"}"#.to_string(),
    };

    match sdk.message_sender.send_message(msg).await {
        Ok(_) => {
            println!("  ✅ 发送成功");
            tokio::time::sleep(Duration::from_secs(2)).await;

            // 获取会话列表以获取 conv_id
            if let Ok(convs) = sdk.conversation.get_all_conversations().await {
                if let Some(conv) = convs.first() {
                    println!("撤回消息...");
                    match sdk.message_service.revoke_message(
                        conv.conversation_id.clone(), 0, client_msg_id, 1
                    ).await {
                        Ok(_) => println!("  ✅ 撤回成功"),
                        Err(e) => println!("  ❌ 撤回失败: {:?}", e),
                    }
                }
            }
        }
        Err(e) => println!("  ❌ 发送失败: {:?}", e),
    }

    println!("✅ 消息撤回测试完成");
}

#[tokio::test]
#[ignore]
async fn test_message_delete() {
    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;

    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 消息删除测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let client_msg_id = format!("delete_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
    let msg = PendingMessage {
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
        content: r#"{"content":"将被删除的消息"}"#.to_string(),
    };

    match sdk.message_sender.send_message(msg).await {
        Ok(_) => {
            println!("  ✅ 发送成功");
            tokio::time::sleep(Duration::from_secs(2)).await;

            if let Ok(convs) = sdk.conversation.get_all_conversations().await {
                if let Some(conv) = convs.first() {
                    println!("删除消息...");
                    match sdk.message_service.delete_messages(
                        conv.conversation_id.clone(), vec![client_msg_id]
                    ).await {
                        Ok(_) => println!("  ✅ 删除成功"),
                        Err(e) => println!("  ❌ 删除失败: {:?}", e),
                    }
                }
            }
        }
        Err(e) => println!("  ❌ 发送失败: {:?}", e),
    }

    println!("✅ 消息删除测试完成");
}

#[tokio::test]
#[ignore]
async fn test_message_mark_read() {
    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;

    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 消息标记已读测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let client_msg_id = format!("read_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
    let msg = PendingMessage {
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
        content: r#"{"content":"标记已读测试"}"#.to_string(),
    };

    match sdk.message_sender.send_message(msg).await {
        Ok(_) => {
            println!("  ✅ 发送成功");
            tokio::time::sleep(Duration::from_secs(2)).await;

            if let Ok(convs) = sdk.conversation.get_all_conversations().await {
                if let Some(conv) = convs.first() {
                    match sdk.message_service.mark_messages_as_read(
                        conv.conversation_id.clone(), 1, 0, vec![]
                    ).await {
                        Ok(_) => println!("  ✅ 标记已读成功"),
                        Err(e) => println!("  ❌ 标记已读失败: {:?}", e),
                    }
                }
            }
        }
        Err(e) => println!("  ❌ 发送失败: {:?}", e),
    }

    println!("✅ 消息标记已读测试完成");
}

#[tokio::test]
#[ignore]
async fn test_message_read_receipt() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 消息已读回执测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;
    let client_msg_id = format!("receipt_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
    let msg = PendingMessage {
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
        content: r#"{"content":"已读回执测试"}"#.to_string(),
    };

    match sdk.message_sender.send_message(msg).await {
        Ok(_) => {
            println!("  ✅ 消息发送成功");
            tokio::time::sleep(Duration::from_secs(2)).await;

            if let Ok(convs) = sdk.conversation.get_all_conversations().await {
                if let Some(conv) = convs.first() {
                    match sdk.message_service.mark_messages_as_read(
                        conv.conversation_id.clone(), 1, 0, vec![]
                    ).await {
                        Ok(_) => println!("  ✅ 已读回执处理成功"),
                        Err(e) => println!("  ❌ 处理失败: {:?}", e),
                    }
                }
            }
        }
        Err(e) => println!("  ❌ 发送失败: {:?}", e),
    }

    println!("✅ 消息已读回执测试完成");
}

#[tokio::test]
#[ignore]
async fn test_local_message_search() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 本地消息搜索测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    // 先发送消息确保有数据
    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;
    let msg = PendingMessage {
        client_msg_id: format!("search_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()),
        send_id: user1.user_id.clone(),
        recv_id: user2.user_id.clone(),
        group_id: String::new(),
        sender_platform_id: 1,
        sender_nickname: user1.nickname.clone(),
        sender_face_url: String::new(),
        session_type: 1,
        msg_from: 100,
        content_type: 101,
        content: r#"{"content":"搜索测试消息"}"#.to_string(),
    };
    let _ = sdk.message_sender.send_message(msg).await;
    tokio::time::sleep(Duration::from_secs(2)).await;

    if let Ok(convs) = sdk.conversation.get_all_conversations().await {
        if let Some(conv) = convs.first() {
            println!("搜索本地消息...");
            match sdk.message_service.search_local_messages(
                conv.conversation_id.clone(), "test".to_string(), 100
            ).await {
                Ok(results) => println!("  搜索结果数: {}", results.len()),
                Err(e) => println!("  ❌ 搜索失败: {:?}", e),
            }
        }
    }

    println!("✅ 本地消息搜索测试完成");
}
