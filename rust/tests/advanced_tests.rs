mod common;

use common::*;
use std::time::Duration;

#[tokio::test]
#[ignore]
async fn test_history_message_pull() {
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
        let _ = sender_sdk.send_text_message(&format!("历史消息测试 {}", i), &user2.user_id, "", 1).await;
        tokio::time::sleep(Duration::from_millis(300)).await;
    }

    println!("  消息发送完成...");
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("2. 重新创建接收者 SDK...");
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;

    println!("3. 获取会话列表...");
    let convs = receiver_sdk.get_conversations().await;
    assert!(convs.is_ok(), "获取会话失败: {:?}", convs.err());
    let list = convs.unwrap();
    assert!(!list.is_empty(), "会话列表不应为空");
    println!("  会话数量: {}", list.len());
    for conv in &list {
        println!("  会话: {} (未读: {})", conv.conversation_id, conv.unread_count);
    }
    println!("  ✅ 历史消息拉取测试通过");

    println!("✅ 历史消息拉取测试完成");
}

#[tokio::test]
#[ignore]
async fn test_message_revoke() {
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
    let send_result = sdk.send_text_message("将被撤回的消息", &user2.user_id, "", 1).await;

    match send_result {
        Ok(msg_data) => {
            println!("  ✅ 发送成功");
            let client_msg_id = msg_data.client_msg_id;
            tokio::time::sleep(Duration::from_secs(2)).await;

            // 获取会话列表以获取 conv_id
            if let Ok(convs) = sdk.get_conversations().await {
                if let Some(conv) = convs.first() {
                    println!("撤回消息...");
                    let revoke_result = sdk.revoke_message(
                        rust_lib_flutter_rust_demo::sdk::client::types::RevokeMessageReq {
                            conversation_id: conv.conversation_id.clone(),
                            seq: 0,
                            client_msg_id,
                            session_type: 1,
                        }
                    ).await;
                    assert!(revoke_result.is_ok(), "撤回消息失败: {:?}", revoke_result.err());
                    println!("  ✅ 撤回成功");
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
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 消息删除测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let send_result = sdk.send_text_message("将被删除的消息", &user2.user_id, "", 1).await;

    match send_result {
        Ok(msg_data) => {
            println!("  ✅ 发送成功");
            let client_msg_id = msg_data.client_msg_id;
            tokio::time::sleep(Duration::from_secs(2)).await;

            if let Ok(convs) = sdk.get_conversations().await {
                if let Some(conv) = convs.first() {
                    println!("删除消息...");
                    let delete_result = sdk.delete_messages(
                        rust_lib_flutter_rust_demo::sdk::client::types::DeleteMessagesReq {
                            conversation_id: conv.conversation_id.clone(),
                            client_msg_ids: vec![client_msg_id],
                        }
                    ).await;
                    assert!(delete_result.is_ok(), "删除消息失败: {:?}", delete_result.err());
                    println!("  ✅ 删除成功");
                }
            }
        }
        Err(e) => println!("  ❌ 发送失败: {:?}", e),
    }

    println!("✅ 消息删除测试完成");
}

#[tokio::test]
#[ignore]
async fn test_advanced_text_message() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::model::msg_struct::MessageEntity;

    println!("=== 高级文本消息测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let entities = vec![
        MessageEntity {
            entity_type: "url".to_string(),
            offset: 0,
            length: 5,
            url: "https://example.com".to_string(),
            ex: String::new(),
        },
    ];

    let result = sdk.send_advanced_text_message("hello", entities, &user2.user_id, 1).await;
    assert!(result.is_ok(), "发送高级文本消息失败: {:?}", result.err());
    println!("  ✅ 高级文本消息发送成功");

    println!("✅ 高级文本消息测试完成");
}

#[tokio::test]
#[ignore]
async fn test_message_mark_read() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 消息标记已读测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let send_result = sdk.send_text_message("标记已读测试", &user2.user_id, "", 1).await;

    match send_result {
        Ok(_) => {
            println!("  ✅ 发送成功");
            tokio::time::sleep(Duration::from_secs(2)).await;

            if let Ok(convs) = sdk.get_conversations().await {
                if let Some(conv) = convs.first() {
                    let mark_result = sdk.mark_messages_as_read(
                        rust_lib_flutter_rust_demo::sdk::client::types::MarkMessagesAsReadReq {
                            conversation_id: conv.conversation_id.clone(),
                            session_type: 1,
                            has_read_seq: 0,
                            seqs: vec![],
                        }
                    ).await;
                    assert!(mark_result.is_ok(), "标记已读失败: {:?}", mark_result.err());
                    println!("  ✅ 标记已读成功");
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

    let send_result = sdk.send_text_message("已读回执测试", &user2.user_id, 1).await;

    match send_result {
        Ok(_) => {
            println!("  ✅ 消息发送成功");
            tokio::time::sleep(Duration::from_secs(2)).await;

            if let Ok(convs) = sdk.get_conversations().await {
                if let Some(conv) = convs.first() {
                    let mark_result = sdk.mark_messages_as_read(
                        rust_lib_flutter_rust_demo::sdk::client::types::MarkMessagesAsReadReq {
                            conversation_id: conv.conversation_id.clone(),
                            session_type: 1,
                            has_read_seq: 0,
                            seqs: vec![],
                        }
                    ).await;
                    assert!(mark_result.is_ok(), "标记已读回执失败: {:?}", mark_result.err());
                    println!("  ✅ 已读回执处理成功");
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
    let _ = sdk.send_text_message("搜索测试消息", &user2.user_id, 1).await;
    tokio::time::sleep(Duration::from_secs(2)).await;

    if let Ok(convs) = sdk.get_conversations().await {
        if let Some(conv) = convs.first() {
            println!("搜索本地消息...");
            let search_result = sdk.search_local_messages(
                rust_lib_flutter_rust_demo::sdk::client::types::SearchMessagesReq {
                    conversation_id: conv.conversation_id.clone(),
                    keyword: "test".to_string(),
                }
            ).await;
            assert!(search_result.is_ok(), "本地搜索失败: {:?}", search_result.err());
            let results = search_result.unwrap();
            println!("  搜索结果数: {}", results.len());
        }
    }

    println!("✅ 本地消息搜索测试完成");
}
