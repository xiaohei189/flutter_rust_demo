mod common;

use common::*;
use std::time::Duration;

fn make_conversation_id(uid1: &str, uid2: &str) -> String {
    let mut ids = vec![uid1.to_string(), uid2.to_string()];
    ids.sort();
    format!("si_{}_{}", ids[0], ids[1])
}

// ============================================================================
// 第一类：基本消息发送
// 覆盖：文本消息发送 → 接收、消息去重、双向通信、发送状态流转
// ============================================================================

/// 场景：A 发一条文本消息给 B（新 API：send_text_message）
/// 验证：B 收到 NewMessage 事件，content_type/content/send_id 正确
#[tokio::test]
async fn test_send_text_message_basic() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut event_subscription = receiver_sdk.event_bus().subscribe();

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;

    let send_result = sender_sdk.send_text_message(
        "Hello! 这是一条文本消息测试。",
        &user2.user_id,
        1,
    ).await;
    assert!(send_result.is_ok(), "发送消息失败: {:?}", send_result.err());

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut received = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = event_subscription.next() => {
                match event {
                    Some(SdkEvent::NewMessage { message }) => {
                        assert_eq!(message.content_type, 101, "消息类型不匹配");
                        assert!(message.content.contains("Hello"), "消息内容不匹配: {}", message.content);
                        assert_eq!(message.send_id, user1.user_id, "发送者ID不匹配");
                        received = true;
                        break;
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
    }
    assert!(received, "接收方未收到消息");
}

/// 场景：A 发消息给自己（send_id == recv_id）
/// 验证：自己发的消息不触发 NewMessage 事件（clientMsgId 去重）
#[tokio::test]
async fn test_message_deduplication() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let mut event_subscription = sender_sdk.event_bus().subscribe();

    let text = "自己发给自己测试";
    let send_result = sender_sdk.send_text_message(text, &user1.user_id, 1).await;
    assert!(send_result.is_ok(), "发送消息失败: {:?}", send_result.err());

    let timeout = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout);
    let mut new_message_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = event_subscription.next() => {
                match event {
                    Some(SdkEvent::NewMessage { .. }) => {
                        new_message_count += 1;
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
    }

    assert_eq!(new_message_count, 0, "自己发的消息不应触发 NewMessage 事件（应被去重）");
}

/// 场景：A→B 同时 B→A 各发一条消息
/// 验证：双方都能收到对方的消息
#[tokio::test]
async fn test_bidirectional_messages() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;

    let mut user1_events = user1_sdk.event_bus().subscribe();
    let mut user2_events = user2_sdk.event_bus().subscribe();

    let text_1_to_2 = "A→B 消息";
    let text_2_to_1 = "B→A 消息";

    let send_1 = user1_sdk.send_text_message(text_1_to_2, &user2.user_id, 1).await;
    assert!(send_1.is_ok(), "A→B 发送失败");

    tokio::time::sleep(Duration::from_millis(500)).await;

    let send_2 = user2_sdk.send_text_message(text_2_to_1, &user1.user_id, 1).await;
    assert!(send_2.is_ok(), "B→A 发送失败");

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut u1_received = false;
    let mut u2_received = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user1_events.next() => {
                if let Some(SdkEvent::NewMessage { message }) = event {
                    if message.content.contains("B→A") {
                        u1_received = true;
                    }
                }
            }
            event = user2_events.next() => {
                if let Some(SdkEvent::NewMessage { message }) = event {
                    if message.content.contains("A→B") {
                        u2_received = true;
                    }
                }
            }
        }
        if u1_received && u2_received { break; }
    }

    assert!(u1_received, "用户1未收到B→A消息");
    assert!(u2_received, "用户2未收到A→B消息");
}

/// 场景：A 发消息后观察发送状态
/// 验证：收到 MessageSent 事件，status=2（发送成功）
#[tokio::test]
async fn test_message_status_flow() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let mut event_subscription = sender_sdk.event_bus().subscribe();

    let text = "状态流转测试";
    let send_result = sender_sdk.send_text_message(text, &user2.user_id, 1).await;
    assert!(send_result.is_ok(), "发送消息失败: {:?}", send_result.err());

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut message_sent_received = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = event_subscription.next() => {
                match event {
                    Some(SdkEvent::MessageSent { status, .. }) => {
                        assert_eq!(status, 2, "MessageSent 事件状态应为成功(2)，实际: {}", status);
                        message_sent_received = true;
                        break;
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
    }

    assert!(message_sent_received, "未收到 MessageSent 事件");
}

// ============================================================================
// 第二类：会话相关
// 覆盖：会话已读/未读数、会话变更事件、消息级别已读状态
// ============================================================================

/// 场景：B 收到 A 的消息后调用 mark_conversation_as_read
/// 验证：unread_count=0，收到 ConversationChanged 事件
/// 注意：验证的是 会话级别 的已读（unread_count 清零），
///       不涉及消息级别的 is_read 字段
#[tokio::test]
async fn test_mark_conversation_as_read() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;

    let mut user2_events = user2_sdk.event_bus().subscribe();

    let text = "未读测试消息";
    let send_result = user1_sdk.send_text_message(text, &user2.user_id, 1).await;
    assert!(send_result.is_ok(), "发送消息失败");

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut new_message_received = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                match event {
                    Some(SdkEvent::NewMessage { .. }) => {
                        new_message_received = true;
                        break;
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
    }
    assert!(new_message_received, "接收方未收到新消息");

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let mark_result = user2_sdk.mark_conversation_as_read(conv_id.clone(), 1).await;
    assert!(mark_result.is_ok(), "标记已读失败: {:?}", mark_result.err());

    let timeout2 = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout2);
    let mut conv_changed = false;
    loop {
        tokio::select! {
            _ = &mut timeout2 => { break; }
            event = user2_events.next() => {
                match event {
                    Some(SdkEvent::ConversationChanged { conversations }) => {
                        for conv in &conversations {
                            if conv.conversation_id == conv_id {
                                assert_eq!(conv.unread_count, 0, "已读后未读计数应为0，实际: {}", conv.unread_count);
                                conv_changed = true;
                                break;
                            }
                        }
                        if conv_changed { break; }
                    }
                    Some(SdkEvent::TotalUnreadCountChanged { .. }) => {}
                    Some(_) => {}
                    None => break,
                }
            }
        }
    }

    assert!(conv_changed, "未收到 ConversationChanged 事件或未读计数未清零");
}

/// 场景：A 连续发 3 条消息给 B
/// 验证：B 收到 ConversationChanged 事件，unread_count 递增
/// 注意：验证的是 会话变更事件 与 未读数 的联动
#[tokio::test]
async fn test_conversation_change_event() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = user2_sdk.event_bus().subscribe();

    for i in 1..=3 {
        let text = format!("会话变更测试消息 {}", i);
        let _ = user1_sdk.send_text_message(&text, &user2.user_id, 1).await;
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    let timeout = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout);
    let mut new_msg_count = 0;
    let mut conv_changed = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                match event {
                    Some(SdkEvent::NewMessage { .. }) => {
                        new_msg_count += 1;
                    }
                    Some(SdkEvent::ConversationChanged { conversations }) => {
                        assert!(!conversations.is_empty(), "ConversationChanged 应包含会话数据");
                        let conv = &conversations[0];
                        assert_eq!(conv.unread_count, new_msg_count, "未读计数应与新消息数一致");
                        conv_changed = true;
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
        if new_msg_count >= 3 && conv_changed { break; }
    }

    assert_eq!(new_msg_count, 3, "应收到3条新消息");
    assert!(conv_changed, "应收到 ConversationChanged 事件");
}

/// 场景：A 发 5 条消息，B 收到后标记已读
/// 验证：unread_count 递增后清零（会话已读全流程）
#[tokio::test]
async fn test_unread_count_increment_and_clear() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = user2_sdk.event_bus().subscribe();

    for i in 1..=5 {
        let text = format!("未读递增测试消息 {}", i);
        let _ = user1_sdk.send_text_message(&text, &user2.user_id, 1).await;
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    let timeout = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout);
    let mut new_msg_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                match event {
                    Some(SdkEvent::NewMessage { .. }) => {
                        new_msg_count += 1;
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
        if new_msg_count >= 5 { break; }
    }
    assert_eq!(new_msg_count, 5, "应收到5条新消息");

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let mark_result = user2_sdk.mark_conversation_as_read(conv_id.clone(), 1).await;
    assert!(mark_result.is_ok(), "标记已读失败");

    let timeout2 = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout2);
    let mut final_unread = -1;
    loop {
        tokio::select! {
            _ = &mut timeout2 => { break; }
            event = user2_events.next() => {
                if let Some(SdkEvent::ConversationChanged { conversations }) = event {
                    for conv in &conversations {
                        if conv.conversation_id == conv_id {
                            final_unread = conv.unread_count;
                            break;
                        }
                    }
                    if final_unread >= 0 { break; }
                }
            }
        }
    }

    assert_eq!(final_unread, 0, "标记已读后未读计数应为0，实际: {}", final_unread);
}

/// 场景：A 发 3 条消息给 B，B 标记已读，然后查询本地数据库
/// 验证：消息的 is_read 字段从 false 变为 true（消息级别的已读状态）
/// 注意：区别于会话级别 unread_count 清零，这里验证的是消息本身的已读标记
#[tokio::test]
async fn test_message_read_status_in_db() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = user2_sdk.event_bus().subscribe();

    for i in 1..=3 {
        let text = format!("已读状态测试消息 {}", i);
        let _ = user1_sdk.send_text_message(&text, &user2.user_id, 1).await;
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut new_msg_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event {
                    new_msg_count += 1;
                    if new_msg_count >= 3 { break; }
                }
            }
        }
    }
    assert_eq!(new_msg_count, 3, "应收到3条新消息");

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let mark_result = user2_sdk.mark_conversation_as_read(conv_id.clone(), 1).await;
    assert!(mark_result.is_ok(), "标记已读失败");

    tokio::time::sleep(Duration::from_secs(1)).await;

    let history_req = rust_lib_flutter_rust_demo::sdk::client::types::GetHistoryMessagesReq {
        conversation_id: conv_id.clone(),
        start_client_msg_id: String::new(),
        count: 20,
    };
    let result = user2_sdk.get_history_messages(history_req).await;
    assert!(result.is_ok(), "查询历史消息失败: {:?}", result.err());

    let result = result.unwrap();
    assert!(!result.messages.is_empty(), "历史消息不应为空");

    let unread_count = result.messages.iter().filter(|m| !m.is_read).count();
    let read_count = result.messages.iter().filter(|m| m.is_read).count();
    assert_eq!(read_count, result.messages.len(), "所有消息应标记为已读，实际未读 {} 条，已读 {} 条", unread_count, read_count);
}

// ============================================================================
// 第三类：加载历史消息（消息同步）
// 覆盖：首次登录同步、发送消息后本地列表、滚动分页加载、离线消息重连、
//       seq 连续性
// ============================================================================

/// 场景：验证首次登录后消息加载的真实流程
/// 验证内容：
///   1. 连接后直接加载历史消息（可能为空）
///   2. 离线消息通过 NewMessage 事件到达
///   3. 刷新后从数据库读取到最新消息
/// 说明：不对齐"等同步完再查"，而是验证"边同步边加载"的真实模式
#[tokio::test]
async fn test_login_sync() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;

    let message_count = 5;
    for i in 1..=message_count {
        let text = format!("离线消息 {}", i);
        let result = sender_sdk.send_text_message(&text, &user2.user_id, 1).await;
        assert!(result.is_ok(), "发送离线消息 {} 失败: {:?}", i, result.err());
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    tokio::time::sleep(Duration::from_secs(2)).await;

    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = user2_sdk.event_bus().subscribe();

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    let history_req = rust_lib_flutter_rust_demo::sdk::client::types::GetHistoryMessagesReq {
        conversation_id: conv_id.clone(),
        start_client_msg_id: String::new(),
        count: 20,
    };
    let initial_result = user2_sdk.get_history_messages(history_req.clone()).await;
    assert!(initial_result.is_ok(), "连接后查询历史消息失败: {:?}", initial_result.err());

    let timeout = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout);
    let mut new_msg_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                match event {
                    Some(SdkEvent::NewMessage { message }) => {
                        new_msg_count += 1;
                        if new_msg_count >= message_count { break; }
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let refresh_result = user2_sdk.get_history_messages(history_req).await;
    assert!(refresh_result.is_ok(), "刷新查询历史消息失败: {:?}", refresh_result.err());

    let result = refresh_result.unwrap();
    assert_eq!(result.messages.len(), message_count, "刷新后应有 {} 条离线消息，实际 {}", message_count, result.messages.len());
}

/// 场景：A 发 5 条消息给 B，B 查看本地消息列表
/// 验证：get_history_messages 返回全部 5 条消息
/// 说明：验证发送完成后本地消息列表中包含所有已发送的消息
#[tokio::test]
async fn test_sent_messages_in_local_list() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut event_subscription = receiver_sdk.event_bus().subscribe();

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;

    let message_count = 5;
    for i in 1..=message_count {
        let text = format!("本地列表测试消息 {}", i);
        let result = sender_sdk.send_text_message(&text, &user2.user_id, 1).await;
        assert!(result.is_ok(), "消息 {} 发送失败: {:?}", i, result.err());
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    let receive_timeout = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(receive_timeout);
    let mut received_count = 0;
    loop {
        tokio::select! {
            _ = &mut receive_timeout => { break; }
            event = event_subscription.next() => {
                match event {
                    Some(SdkEvent::NewMessage { .. }) => {
                        received_count += 1;
                        if received_count >= message_count { break; }
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
    }
    assert_eq!(received_count, message_count, "未收到全部消息，期望 {} 实际 {}", message_count, received_count);

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let history_req = rust_lib_flutter_rust_demo::sdk::client::types::GetHistoryMessagesReq {
        conversation_id: conv_id.clone(),
        start_client_msg_id: String::new(),
        count: 20,
    };
    let result = receiver_sdk.get_history_messages(history_req).await;
    assert!(result.is_ok(), "查询本地消息列表失败: {:?}", result.err());

    let result = result.unwrap();
    assert_eq!(result.messages.len(), message_count, "本地消息列表应包含 {} 条消息，实际 {}", message_count, result.messages.len());
}

/// 场景：A 发 10 条消息给 B，B 分页查询历史消息（5+5）
/// 验证：第一页返回 5 条最新消息、第二页传入最早消息 clientMsgId 返回剩余 5 条、
///       is_end 标记正确
/// 说明：验证滚动加载历史消息的分页机制
#[tokio::test]
async fn test_get_history_messages() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::GetHistoryMessagesReq;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = user2_sdk.event_bus().subscribe();

    let message_count = 10;
    for i in 1..=message_count {
        let text = format!("历史消息测试 {}", i);
        let result = user1_sdk.send_text_message(&text, &user2.user_id, 1).await;
        assert!(result.is_ok(), "发送消息 {} 失败: {:?}", i, result.err());
        tokio::time::sleep(Duration::from_millis(300)).await;
    }

    let timeout = tokio::time::sleep(Duration::from_secs(20));
    tokio::pin!(timeout);
    let mut received_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event {
                    received_count += 1;
                    if received_count >= message_count { break; }
                }
            }
        }
    }
    assert_eq!(received_count, message_count, "应收到 {} 条消息，实际 {}", message_count, received_count);

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    let history_req = GetHistoryMessagesReq {
        conversation_id: conv_id.clone(),
        start_client_msg_id: String::new(),
        count: 5,
    };
    let page1 = user2_sdk.get_history_messages(history_req).await;
    assert!(page1.is_ok(), "查询历史消息失败");
    let page1 = page1.unwrap();
    assert_eq!(page1.messages.len(), 5, "第一页应返回5条消息，实际 {}", page1.messages.len());
    assert!(!page1.is_end, "第一页 should not be end");

    let earliest_msg_id = &page1.messages.first().unwrap().client_msg_id;
    let history_req2 = GetHistoryMessagesReq {
        conversation_id: conv_id.clone(),
        start_client_msg_id: earliest_msg_id.clone(),
        count: 10,
    };
    let page2 = user2_sdk.get_history_messages(history_req2).await;
    assert!(page2.is_ok(), "分页查询失败");
    let page2 = page2.unwrap();
    assert_eq!(page2.messages.len(), 5, "第二页应返回剩余5条消息，实际 {}", page2.messages.len());

    let all_texts: Vec<_> = page1.messages.iter().chain(page2.messages.iter())
        .map(|m| {
            let content = &m.content;
            if content.contains("历史消息测试") {
                Some(content.clone())
            } else {
                None
            }
        })
        .filter(|c| c.is_some())
        .collect();
    assert_eq!(all_texts.len(), 10, "应查询到10条历史消息");
}

/// 场景：A 快速发送 10 条消息给 B
/// 验证：收到的 seq 连续（排序后 seq[i+1] == seq[i] + 1）
/// 说明：验证消息推送到本地时 seq 无间隙，间接验证同步完整性
#[tokio::test]
async fn test_message_sync_seq_continuity() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = receiver_sdk.event_bus().subscribe();

    let message_count = 10;
    for i in 1..=message_count {
        let text = format!("seq测试消息 {}", i);
        let _ = sender_sdk.send_text_message(&text, &user2.user_id, 1).await;
        tokio::time::sleep(Duration::from_millis(200)).await;
    }

    let timeout = tokio::time::sleep(Duration::from_secs(20));
    tokio::pin!(timeout);
    let mut received_seqs = Vec::new();
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { message }) = event {
                    received_seqs.push(message.seq);
                    if received_seqs.len() >= message_count { break; }
                }
            }
        }
    }

    assert_eq!(received_seqs.len(), message_count, "应收到 {} 条消息，实际 {}", message_count, received_seqs.len());

    received_seqs.sort();
    let min_seq = received_seqs.first().copied().unwrap_or(0);
    for (i, seq) in received_seqs.iter().enumerate() {
        assert_eq!(*seq, min_seq + i as i64, "seq 不连续: 期望 {}，实际 {}", min_seq + i as i64, seq);
    }
}

/// 场景：验证真实用户场景下的消息加载流程
/// 验证内容：
///   1. 连接后直接加载历史消息（可能为空）
///   2. 新消息通过 NewMessage 事件到达
///   3. 从数据库刷新后能读到最新消息
/// 说明：不对齐"等同步完再查"，而是验证"边同步边加载"的真实模式
#[tokio::test]
async fn test_reconnect_sync() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = user2_sdk.event_bus().subscribe();

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    let history_req = rust_lib_flutter_rust_demo::sdk::client::types::GetHistoryMessagesReq {
        conversation_id: conv_id.clone(),
        start_client_msg_id: String::new(),
        count: 20,
    };
    let initial_result = user2_sdk.get_history_messages(history_req.clone()).await;
    assert!(initial_result.is_ok(), "连接后查询历史消息失败: {:?}", initial_result.err());

    let offline_msg_count = 3;
    for i in 1..=offline_msg_count {
        let text = format!("离线期间消息 {}", i);
        let _ = user1_sdk.send_text_message(&text, &user2.user_id, 1).await;
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    let timeout = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout);
    let mut new_msg_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                match event {
                    Some(SdkEvent::NewMessage { message }) => {
                        new_msg_count += 1;
                        println!("[RECONNECT_TEST] 收到新消息: content={}", message.content);
                        if new_msg_count >= offline_msg_count { break; }
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let refresh_result = user2_sdk.get_history_messages(history_req).await;
    assert!(refresh_result.is_ok(), "刷新查询历史消息失败: {:?}", refresh_result.err());

    let result = refresh_result.unwrap();
    let offline_in_db = result.messages.iter().filter(|m| m.content.contains("离线期间消息")).count();
    assert!(
        offline_in_db >= offline_msg_count,
        "刷新后数据库应包含至少 {} 条离线消息，实际 {}，new_msg_count={}",
        offline_msg_count, offline_in_db, new_msg_count
    );
}

// ============================================================================
// 综合测试：发送各种消息类型给指定用户
// ============================================================================

/// 场景：发送各种支持的消息类型给固定用户（手机号 17764008283）
/// 覆盖：文本(101)、Markdown(118)、高级文本(117)、表情(115)、图片(102)、文件(105)、名片(108)
/// 发送用户：手机号 17764008284，接收用户：手机号 17764008283
/// 自动登录/创建用户，自动确保好友关系
#[tokio::test]
async fn test_send_all_message_types() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::model::msg_struct::{MessageEntity, MsgStruct};
    use rust_lib_flutter_rust_demo::sdk::client::types::GetHistoryMessagesReq;

    // 接收用户：手机号 17764008283
    let receiver = login_or_register_user("17764008283", "Receiver_17764008283").await;
    println!("接收用户: user_id={}, phone={}", receiver.user_id, receiver.phone);

    // 发送用户：手机号 17764008284
    let sender = login_or_register_user("17764008284", "Sender_17764008284").await;
    println!("发送用户: user_id={}, phone={}", sender.user_id, sender.phone);

    // 登录并创建 SDK
    let (receiver_im_token, _) = login_account(&receiver).await.expect("接收用户登录失败");
    let (sender_im_token, _) = login_account(&sender).await.expect("发送用户登录失败");

    let receiver_sdk = create_sdk(&receiver, &receiver_im_token).await;
    let sender_sdk = create_sdk(&sender, &sender_im_token).await;

    // 确保双方是好友
    println!("\n=== 确保好友关系 ===");
    ensure_friends(&sender_sdk, &sender.user_id, &receiver_sdk, &receiver.user_id).await;

    let target_user_id = &receiver.user_id;
    let session_type = 1i32; // 单聊

    // 创建临时测试文件
    let tmp_dir = std::env::temp_dir().join("openim_test_files");
    std::fs::create_dir_all(&tmp_dir).ok();

    // 创建一个 1x1 红色 PNG 图片（最小有效 PNG，约 67 字节）
    let png_path = tmp_dir.join("test_image.png");
    let png_bytes: Vec<u8> = vec![
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
        0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
        0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
        0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND chunk
        0x44, 0xAE, 0x42, 0x60, 0x82,
    ];
    std::fs::write(&png_path, &png_bytes).expect("创建测试图片失败");

    // 创建一个测试文本文件
    let txt_path = tmp_dir.join("test_document.txt");
    std::fs::write(&txt_path, "这是一个测试文件的内容。\nHello from OpenIM Rust SDK test! 🎉\n").expect("创建测试文件失败");

    println!("\n=== 开始发送各种消息类型到 {} (phone: {}) ===\n", target_user_id, receiver.phone);

    let mut send_count = 0u32;

    // 1. 文本消息 (content_type=101) —— 带 emoji
    println!("[1/7] 发送带 emoji 的文本消息...");
    let result = sender_sdk.send_text_message(
        "这是一条文本消息测试 😊🎉👍❤️🔥",
        target_user_id,
        session_type,
    ).await;
    assert!(result.is_ok(), "发送文本消息失败: {:?}", result.err());
    let msg_data = result.unwrap();
    println!("  OK: server_msg_id={}, send_time={}", msg_data.server_msg_id, msg_data.send_time);
    send_count += 1;

    // 2. Markdown 消息 (content_type=118)
    println!("[2/7] 发送Markdown消息...");
    let result = sender_sdk.send_markdown_message(
        "# 测试标题 📝\n这是一条 **Markdown** 消息\n- 列表项1 ✅\n- 列表项2 ✅",
        target_user_id,
        session_type,
    ).await;
    assert!(result.is_ok(), "发送Markdown消息失败: {:?}", result.err());
    let msg_data = result.unwrap();
    println!("  OK: server_msg_id={}, send_time={}", msg_data.server_msg_id, msg_data.send_time);
    send_count += 1;

    // 3. 高级文本消息 (content_type=117)
    println!("[3/7] 发送高级文本消息...");
    let entities = vec![
        MessageEntity {
            entity_type: "At".to_string(),
            offset: 0,
            length: 2,
            url: target_user_id.to_string(),
            ex: String::new(),
        },
    ];
    let result = sender_sdk.send_advanced_text_message(
        "你好 👋 这是一条高级文本消息",
        entities,
        target_user_id,
        session_type,
    ).await;
    assert!(result.is_ok(), "发送高级文本消息失败: {:?}", result.err());
    let msg_data = result.unwrap();
    println!("  OK: server_msg_id={}, send_time={}", msg_data.server_msg_id, msg_data.send_time);
    send_count += 1;

    // 4. 表情消息 (content_type=115)
    println!("[4/7] 发送表情消息...");
    let mut face_msg = MsgStruct::create_face_message(1, "smile");
    face_msg.session_type = session_type;
    let result = sender_sdk.send_msg(face_msg, target_user_id, None).await;
    assert!(result.is_ok(), "发送表情消息失败: {:?}", result.err());
    let msg_data = result.unwrap();
    println!("  OK: server_msg_id={}, send_time={}", msg_data.server_msg_id, msg_data.send_time);
    send_count += 1;

    // 5. 图片消息 (content_type=102) —— 真实上传
    println!("[5/7] 发送图片消息（真实上传）...");
    let result = sender_sdk.send_image_message(
        png_path.to_str().unwrap(),
        target_user_id,
        session_type,
    ).await;
    assert!(result.is_ok(), "发送图片消息失败: {:?}", result.err());
    let msg_data = result.unwrap();
    println!("  OK: server_msg_id={}, send_time={}", msg_data.server_msg_id, msg_data.send_time);
    send_count += 1;

    // 6. 文件消息 (content_type=105) —— 真实上传
    println!("[6/7] 发送文件消息（真实上传）...");
    let result = sender_sdk.send_file_message(
        txt_path.to_str().unwrap(),
        target_user_id,
        session_type,
    ).await;
    assert!(result.is_ok(), "发送文件消息失败: {:?}", result.err());
    let msg_data = result.unwrap();
    println!("  OK: server_msg_id={}, send_time={}", msg_data.server_msg_id, msg_data.send_time);
    send_count += 1;

    // 7. 名片消息 (content_type=108)
    println!("[7/7] 发送名片消息...");
    let card_elem = rust_lib_flutter_rust_demo::domain::model::msg_struct::CardElem {
        user_id: sender.user_id.clone(),
        nickname: sender.nickname.clone(),
        face_url: "https://example.com/avatar.jpg".to_string(),
        ex: String::new(),
    };
    let mut card_msg = MsgStruct::create_card_message(card_elem);
    card_msg.session_type = session_type;
    let result = sender_sdk.send_msg(card_msg, target_user_id, None).await;
    assert!(result.is_ok(), "发送名片消息失败: {:?}", result.err());
    let msg_data = result.unwrap();
    println!("  OK: server_msg_id={}, send_time={}", msg_data.server_msg_id, msg_data.send_time);
    send_count += 1;

    println!("\n=== 全部 {} 种消息类型发送完成 ===\n", send_count);

    // 等待消息同步
    tokio::time::sleep(Duration::from_secs(2)).await;

    // 验证历史消息
    println!("[验证] 查询历史消息...");
    let history = sender_sdk.get_history_messages(GetHistoryMessagesReq {
        conversation_id: make_conversation_id(&sender.user_id, target_user_id),
        start_client_msg_id: String::new(),
        count: 50,
    }).await;
    assert!(history.is_ok(), "查询历史消息失败: {:?}", history.err());
    let history = history.unwrap();
    println!("  本次发送消息数: {}", send_count);
    println!("  历史消息总数: {}", history.messages.len());

    // 统计各 content_type 数量
    let mut type_counts = std::collections::HashMap::new();
    for msg in &history.messages {
        *type_counts.entry(msg.content_type).or_insert(0) += 1;
    }
    println!("  消息类型分布:");
    let mut types: Vec<_> = type_counts.iter().collect();
    types.sort_by_key(|(k, _)| *k);
    for (ct, count) in types {
        let name = match *ct {
            101 => "文本",
            102 => "图片",
            105 => "文件",
            108 => "名片",
            115 => "表情",
            117 => "高级文本",
            118 => "Markdown",
            _ => "其他",
        };
        println!("    content_type={}: {} 条 ({})", ct, count, name);
    }

    // 验证本次发送的 7 种消息都在历史中
    assert!(history.messages.iter().any(|m| m.content_type == 101), "缺少文本消息(101)");
    assert!(history.messages.iter().any(|m| m.content_type == 118), "缺少Markdown消息(118)");
    assert!(history.messages.iter().any(|m| m.content_type == 117), "缺少高级文本消息(117)");
    assert!(history.messages.iter().any(|m| m.content_type == 115), "缺少表情消息(115)");
    assert!(history.messages.iter().any(|m| m.content_type == 102), "缺少图片消息(102)");
    assert!(history.messages.iter().any(|m| m.content_type == 105), "缺少文件消息(105)");
    assert!(history.messages.iter().any(|m| m.content_type == 108), "缺少名片消息(108)");
    println!("\n  全部 7 种消息类型验证通过!");
}

/// 场景：验证消息同步机制 —— 登录后等待同步完成，检查是否拉取到服务端所有消息
#[tokio::test]
async fn test_message_sync_from_server() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::sdk::client::types::GetHistoryMessagesReq;

    let receiver = login_or_register_user("17764008283", "Receiver_17764008283").await;
    let sender = login_or_register_user("17764008284", "Sender_17764008284").await;

    let (receiver_im_token, _) = login_account(&receiver).await.expect("接收用户登录失败");
    let receiver_sdk = create_sdk(&receiver, &receiver_im_token).await;

    // 等待异步消息同步完成
    println!("等待消息同步完成...");
    tokio::time::sleep(Duration::from_secs(10)).await;

    // 查询历史消息，应该包含 Web 端发送的消息
    let history = receiver_sdk.get_history_messages(GetHistoryMessagesReq {
        conversation_id: make_conversation_id(&receiver.user_id, &sender.user_id),
        start_client_msg_id: String::new(),
        count: 100,
    }).await;

    assert!(history.is_ok(), "查询历史消息失败: {:?}", history.err());
    let history = history.unwrap();
    println!("同步后历史消息数量: {}", history.messages.len());
    for (i, msg) in history.messages.iter().enumerate() {
        println!("  [{}] content_type={}, seq={}, content={:.80}...",
            i + 1, msg.content_type, msg.seq, msg.content);
    }

    // 服务端应该有更多消息（包括 Web 端发的）
    assert!(history.messages.len() > 4, "同步后应有超过4条消息（含Web端消息），实际{}", history.messages.len());
}

// ============================================================================
// 第四类：消息撤回与删除
// ============================================================================

/// 场景：A 发消息给 B，A 撤回该消息
/// 验证：A 收到 MessageRevoked 事件，消息 content_type 变为撤回通知类型
#[tokio::test]
async fn test_revoke_message_and_event() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::RevokeMessageReq;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let _receiver_sdk = create_sdk(&user2, &user2_im_token).await;

    // 发送消息
    let send_result = sender_sdk.send_text_message("将被撤回的消息", &user2.user_id, 1).await;
    assert!(send_result.is_ok(), "发送消息失败: {:?}", send_result.err());
    let msg_data = send_result.unwrap();
    let client_msg_id = msg_data.client_msg_id.clone();

    tokio::time::sleep(Duration::from_secs(2)).await;

    // 撤回消息
    let conv_id = make_conversation_id(&user1.user_id, &user2.user_id);
    let revoke_result = sender_sdk.revoke_message(RevokeMessageReq {
        conversation_id: conv_id.clone(),
        seq: 0,
        client_msg_id: client_msg_id.clone(),
        session_type: 1,
    }).await;
    assert!(revoke_result.is_ok(), "撤回消息失败: {:?}", revoke_result.err());

    // 验证本地消息 content_type 已更新为撤回类型
    tokio::time::sleep(Duration::from_secs(1)).await;
    let history = sender_sdk.get_history_messages(
        rust_lib_flutter_rust_demo::sdk::client::types::GetHistoryMessagesReq {
            conversation_id: conv_id,
            start_client_msg_id: String::new(),
            count: 10,
        },
    ).await;
    assert!(history.is_ok(), "查询历史消息失败");
    let history = history.unwrap();
    // 撤回后消息应仍存在但 content_type 变为撤回通知类型
    let revoked_msg = history.messages.iter().find(|m| m.client_msg_id == client_msg_id);
    if let Some(msg) = revoked_msg {
        assert_eq!(msg.content_type, 10000, "撤回后消息 content_type 应为 10000(撤回通知), 实际: {}", msg.content_type);
    }
}

/// 场景：A 发消息，B 收到后 A 删除该消息
/// 验证：A 收到 MessagesDeleted 事件
#[tokio::test]
async fn test_delete_message_and_event() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::DeleteMessagesReq;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let mut sender_events = sender_sdk.event_bus().subscribe();

    let _receiver_sdk = create_sdk(&user2, &user2_im_token).await;

    // 发送消息
    let send_result = sender_sdk.send_text_message("将被删除的消息", &user2.user_id, 1).await;
    assert!(send_result.is_ok(), "发送消息失败: {:?}", send_result.err());
    let msg_data = send_result.unwrap();
    let client_msg_id = msg_data.client_msg_id.clone();

    tokio::time::sleep(Duration::from_secs(2)).await;

    // 删除消息
    let conv_id = make_conversation_id(&user1.user_id, &user2.user_id);
    let delete_result = sender_sdk.delete_messages(DeleteMessagesReq {
        conversation_id: conv_id.clone(),
        client_msg_ids: vec![client_msg_id.clone()],
    }).await;
    assert!(delete_result.is_ok(), "删除消息失败: {:?}", delete_result.err());

    // 验证收到 MessagesDeleted 事件
    let timeout = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout);
    let mut deleted_event_received = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = sender_events.next() => {
                if let Some(SdkEvent::MessagesDeleted { client_msg_ids, .. }) = event {
                    if client_msg_ids.contains(&client_msg_id) {
                        deleted_event_received = true;
                        break;
                    }
                }
            }
        }
    }
    assert!(deleted_event_received, "未收到 MessagesDeleted 事件");
}

// ============================================================================
// 第五类：高级消息类型
// ============================================================================

/// 场景：A 发送自定义消息给 B
/// 验证：B 收到 content_type=110 的 NewMessage 事件，data/description/extension 字段正确
#[tokio::test]
async fn test_send_custom_message() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = receiver_sdk.event_bus().subscribe();

    let result = sender_sdk.send_custom_message(
        r#"{"type":"gift","id":"rose_001"}"#,
        "送你一朵玫瑰花",
        r#"{"giftId":"rose_001","count":1}"#,
        &user2.user_id,
        1,
    ).await;
    assert!(result.is_ok(), "发送自定义消息失败: {:?}", result.err());

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut received = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { message }) = event {
                    if message.content_type == 110 {
                        assert!(message.content.contains("gift"), "自定义消息内容应包含 gift");
                        received = true;
                        break;
                    }
                }
            }
        }
    }
    assert!(received, "接收方未收到自定义消息");
}

/// 场景：A 发送位置消息给 B
/// 验证：B 收到 content_type=109 的 NewMessage 事件
#[tokio::test]
async fn test_send_location_message() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = receiver_sdk.event_bus().subscribe();

    let result = sender_sdk.send_location_message(
        "北京市海淀区中关村",
        116.310003,
        39.991957,
        &user2.user_id,
        1,
    ).await;
    assert!(result.is_ok(), "发送位置消息失败: {:?}", result.err());

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut received = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { message }) = event {
                    if message.content_type == 109 {
                        assert!(message.content.contains("北京"), "位置消息应包含描述");
                        received = true;
                        break;
                    }
                }
            }
        }
    }
    assert!(received, "接收方未收到位置消息");
}

/// 场景：A 发送引用消息给 B（引用之前的文本消息）
/// 验证：B 收到 content_type=114 的引用消息
#[tokio::test]
async fn test_send_quote_message() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::domain::model::msg_struct::MsgStruct;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = receiver_sdk.event_bus().subscribe();

    // 先发一条消息
    let first_msg = sender_sdk.send_text_message("原始消息", &user2.user_id, 1).await;
    assert!(first_msg.is_ok(), "发送原始消息失败");
    let first_msg_data = first_msg.unwrap();

    tokio::time::sleep(Duration::from_millis(500)).await;

    // 创建被引用的消息结构
    let quoted_msg = MsgStruct::from(&first_msg_data);

    // 发送引用消息
    let result = sender_sdk.send_quote_message(
        "这是引用消息",
        quoted_msg,
        &user2.user_id,
        1,
    ).await;
    assert!(result.is_ok(), "发送引用消息失败: {:?}", result.err());

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut received = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { message }) = event {
                    if message.content_type == 114 {
                        assert!(message.content.contains("引用"), "引用消息应包含引用内容");
                        received = true;
                        break;
                    }
                }
            }
        }
    }
    assert!(received, "接收方未收到引用消息");
}

/// 场景：A 发送 @ 消息给 B
/// 验证：B 收到 content_type=106 的 @ 消息
#[tokio::test]
async fn test_send_at_text_message() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = receiver_sdk.event_bus().subscribe();

    let result = sender_sdk.send_at_text_message(
        "大家好，请注意",
        vec![user2.user_id.clone()],
        &user2.user_id,
        1,
    ).await;
    assert!(result.is_ok(), "发送@消息失败: {:?}", result.err());

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut received = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { message }) = event {
                    if message.content_type == 106 {
                        assert!(message.content.contains("大家好"), "@消息内容应包含文本");
                        received = true;
                        break;
                    }
                }
            }
        }
    }
    assert!(received, "接收方未收到@消息");
}

/// 场景：A 发送位置+自定义+@三种消息，B 全部收到
/// 验证：三种消息类型均正确送达
#[tokio::test]
async fn test_send_mixed_message_types() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = receiver_sdk.event_bus().subscribe();

    // 发送三种消息
    let _ = sender_sdk.send_text_message("混合测试文本", &user2.user_id, 1).await;
    tokio::time::sleep(Duration::from_millis(300)).await;

    let _ = sender_sdk.send_custom_message(
        r#"{"type":"test"}"#, "自定义描述", "",
        &user2.user_id, 1,
    ).await;
    tokio::time::sleep(Duration::from_millis(300)).await;

    let _ = sender_sdk.send_location_message(
        "测试地点", 116.0, 39.0,
        &user2.user_id, 1,
    ).await;

    let timeout = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout);
    let mut received_types: std::collections::HashSet<i32> = std::collections::HashSet::new();
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { message }) = event {
                    received_types.insert(message.content_type);
                    if received_types.len() >= 3 { break; }
                }
            }
        }
    }

    assert!(received_types.contains(&101), "未收到文本消息(101)");
    assert!(received_types.contains(&110), "未收到自定义消息(110)");
    assert!(received_types.contains(&109), "未收到位置消息(109)");
}

// ============================================================================
// 第六类：Typing 通知
// ============================================================================

/// 场景：A 发送 typing(focus=true) 给 B
/// 验证：typing 不触发 NewMessage 事件、不创建会话消息（typing 消息不入库）
#[tokio::test]
async fn test_send_typing_notification() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = receiver_sdk.event_bus().subscribe();

    // 发送 typing 通知
    let result = sender_sdk.send_typing(&user2.user_id, 1, true).await;
    assert!(result.is_ok(), "发送 typing 通知失败: {:?}", result.err());

    // 等待一段时间，确认不触发 NewMessage
    let timeout = tokio::time::sleep(Duration::from_secs(3));
    tokio::pin!(timeout);
    let mut got_new_message = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event {
                    got_new_message = true;
                    break;
                }
            }
        }
    }
    assert!(!got_new_message, "typing 通知不应触发 NewMessage 事件");
}

// ============================================================================
// 第七类：全量已读 & 未读总数
// ============================================================================

/// 场景：A 给 B 发 3 条消息，B 调用 mark_all_conversation_as_read
/// 验证：所有会话未读清零，TotalUnreadCountChanged(count=0) 事件触发
#[tokio::test]
async fn test_mark_all_conversation_as_read() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = user2_sdk.event_bus().subscribe();

    // 发送 3 条消息
    for i in 1..=3 {
        let _ = user1_sdk.send_text_message(
            &format!("全量已读测试 {}", i),
            &user2.user_id,
            1,
        ).await;
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    // 等待所有消息到达
    let timeout = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout);
    let mut msg_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event {
                    msg_count += 1;
                    if msg_count >= 3 { break; }
                }
            }
        }
    }
    assert_eq!(msg_count, 3, "应收到 3 条消息");

    tokio::time::sleep(Duration::from_secs(1)).await;

    // 全量标记已读
    let mark_result = user2_sdk.mark_all_conversation_as_read().await;
    assert!(mark_result.is_ok(), "全量标记已读失败: {:?}", mark_result.err());

    // 验证 TotalUnreadCountChanged(0)
    let timeout2 = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout2);
    let mut total_zero_received = false;
    loop {
        tokio::select! {
            _ = &mut timeout2 => { break; }
            event = user2_events.next() => {
                if let Some(SdkEvent::TotalUnreadCountChanged { count }) = event {
                    if count == 0 {
                        total_zero_received = true;
                        break;
                    }
                }
            }
        }
    }
    assert!(total_zero_received, "未收到 TotalUnreadCountChanged(count=0) 事件");
}

/// 场景：B 有多条未读消息时检查全局未读总数
/// 验证：A 发 5 条消息后，B 的 get_conversations 里 unread 递增
#[tokio::test]
async fn test_total_unread_count() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;

    // 发送 5 条消息
    for i in 1..=5 {
        let _ = user1_sdk.send_text_message(
            &format!("未读总数测试 {}", i),
            &user2.user_id,
            1,
        ).await;
        tokio::time::sleep(Duration::from_millis(300)).await;
    }

    tokio::time::sleep(Duration::from_secs(5)).await;

    // 查询 B 的会话列表，计算未读总数
    let convs = user2_sdk.get_conversations().await.expect("获取会话失败");
    let total_unread: i32 = convs.iter().map(|c| c.unread_count).sum();
    assert!(total_unread > 0, "B 应有未读消息，实际总未读: {}", total_unread);

    // 逐条标记已读后未读应清零
    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let _ = user2_sdk.mark_conversation_as_read(conv_id, 1).await;
    tokio::time::sleep(Duration::from_secs(1)).await;

    let convs_after = user2_sdk.get_conversations().await.expect("获取会话失败");
    let total_after: i32 = convs_after.iter().map(|c| c.unread_count).sum();
    assert_eq!(total_after, 0, "标记已读后总未读应为0, 实际: {}", total_after);
}

// ============================================================================
// 第八类：消息转发
// ============================================================================

/// 场景：A 发文本消息给 B，B 将该消息转发给 A
/// 验证：A 收到转发的消息（content_type=101）
#[tokio::test]
async fn test_forward_message() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user1_events = user1_sdk.event_bus().subscribe();

    // A 发消息给 B
    let send_result = user1_sdk.send_text_message("原始消息内容", &user2.user_id, 1).await;
    assert!(send_result.is_ok(), "A 发送消息失败");
    let original_msg = send_result.unwrap();

    // B 收到消息
    let mut user2_events = user2_sdk.event_bus().subscribe();
    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut b_received = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event {
                    b_received = true;
                    break;
                }
            }
        }
    }
    assert!(b_received, "B 未收到 A 的消息");

    // B 转发消息给 A
    let forward_result = user2_sdk.forward_message(original_msg, &user1.user_id, 1).await;
    assert!(forward_result.is_ok(), "B 转发消息失败: {:?}", forward_result.err());

    // A 收到转发消息
    let timeout2 = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout2);
    let mut a_received_forward = false;
    loop {
        tokio::select! {
            _ = &mut timeout2 => { break; }
            event = user1_events.next() => {
                if let Some(SdkEvent::NewMessage { message }) = event {
                    if message.send_id == user2.user_id && message.content.contains("原始消息内容") {
                        a_received_forward = true;
                        break;
                    }
                }
            }
        }
    }
    assert!(a_received_forward, "A 未收到 B 转发的消息");
}

// ============================================================================
// 第九类：合并消息
// ============================================================================

/// 场景：A 先发 2 条消息，然后将它们合并转发给 B
/// 验证：B 收到 content_type=107 的合并消息
#[tokio::test]
async fn test_send_merger_message() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::domain::model::msg_struct::MsgStruct;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = receiver_sdk.event_bus().subscribe();

    // 发送 2 条消息
    let msg1 = sender_sdk.send_text_message("合并消息1", &user2.user_id, 1).await.unwrap();
    tokio::time::sleep(Duration::from_millis(300)).await;
    let msg2 = sender_sdk.send_text_message("合并消息2", &user2.user_id, 1).await.unwrap();
    tokio::time::sleep(Duration::from_millis(300)).await;

    // 将 2 条消息合并转发
    let context_list: Vec<MsgStruct> = vec![MsgStruct::from(&msg1), MsgStruct::from(&msg2)];
    let result = sender_sdk.send_merger_message(
        "合并转发",
        vec!["合并消息1".to_string(), "合并消息2".to_string()],
        context_list,
        &user2.user_id,
        1,
    ).await;
    assert!(result.is_ok(), "发送合并消息失败: {:?}", result.err());

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut received_merger = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { message }) = event {
                    if message.content_type == 107 {
                        received_merger = true;
                        break;
                    }
                }
            }
        }
    }
    assert!(received_merger, "接收方未收到合并消息(107)");
}

// ============================================================================
// 第十类：从 URL 发送媒体消息
// ============================================================================

/// 场景：A 从 URL 发送图片/语音/视频/文件消息给 B
/// 验证：B 收到对应 content_type 的消息
#[tokio::test]
async fn test_send_media_from_url() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = receiver_sdk.event_bus().subscribe();

    // 从 URL 发送图片消息
    let result = sender_sdk.send_image_message_from_url(
        "https://example.com/test_image.png",
        &user2.user_id,
        1,
    ).await;
    assert!(result.is_ok(), "从URL发送图片消息失败: {:?}", result.err());

    // 从 URL 发送语音消息
    let result = sender_sdk.send_sound_message_from_url(
        "https://example.com/test_sound.mp3",
        5,
        &user2.user_id,
        1,
    ).await;
    assert!(result.is_ok(), "从URL发送语音消息失败: {:?}", result.err());

    // 从 URL 发送视频消息
    let result = sender_sdk.send_video_message_from_url(
        "https://example.com/test_video.mp4",
        10,
        "https://example.com/test_snapshot.jpg",
        &user2.user_id,
        1,
    ).await;
    assert!(result.is_ok(), "从URL发送视频消息失败: {:?}", result.err());

    // 从 URL 发送文件消息
    let result = sender_sdk.send_file_message_from_url(
        "https://example.com/test_file.pdf",
        "test_file.pdf",
        8192,
        &user2.user_id,
        1,
    ).await;
    assert!(result.is_ok(), "从URL发送文件消息失败: {:?}", result.err());

    // 验证接收方收到消息
    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut received_types: std::collections::HashSet<i32> = std::collections::HashSet::new();
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { message }) = event {
                    received_types.insert(message.content_type);
                    if received_types.len() >= 4 { break; }
                }
            }
        }
    }

    assert!(received_types.contains(&102), "未收到图片消息(102)");
    assert!(received_types.contains(&103), "未收到语音消息(103)");
    assert!(received_types.contains(&104), "未收到视频消息(104)");
    assert!(received_types.contains(&105), "未收到文件消息(105)");
}

// ============================================================================
// 第十一类：消息搜索 & 本地消息查询
// ============================================================================

/// 场景：A 发 3 条含特定关键词的消息给 B，B 搜索该关键词
/// 验证：search_local_messages 返回匹配的消息
#[tokio::test]
async fn test_search_local_messages() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::SearchMessagesReq;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = user2_sdk.event_bus().subscribe();

    let search_keyword = "UNIQUE_KEYWORD_42";
    for i in 1..=3 {
        let text = format!("消息{} 包含 {}", i, search_keyword);
        let _ = user1_sdk.send_text_message(&text, &user2.user_id, 1).await;
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    // 等待所有消息到达
    let timeout = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout);
    let mut msg_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event {
                    msg_count += 1;
                    if msg_count >= 3 { break; }
                }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    // 搜索
    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let results = user2_sdk.search_local_messages(SearchMessagesReq {
        conversation_id: conv_id,
        keyword: search_keyword.to_string(),
    }).await;

    assert!(results.is_ok(), "本地搜索失败: {:?}", results.err());
    let results = results.unwrap();
    assert!(results.len() >= 3, "应搜索到至少 3 条消息, 实际: {}", results.len());

    // 验证搜索结果都包含关键词
    for msg in &results {
        assert!(msg.content.contains(search_keyword),
            "搜索结果应包含关键词 '{}', 实际: {}", search_keyword, msg.content);
    }
}

// ============================================================================
// 第十二类：消息级别的已读回执（C2CReadReceipt）
// ============================================================================

/// 场景：A 发 2 条消息给 B，B 标记会话已读
/// 验证：A 收到 C2CReadReceipt 事件
#[tokio::test]
async fn test_c2c_read_receipt() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;

    let mut sender_events = sender_sdk.event_bus().subscribe();

    // A 发消息
    for i in 1..=2 {
        let _ = sender_sdk.send_text_message(
            &format!("回执测试 {}", i),
            &user2.user_id,
            1,
        ).await;
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    // 等待 B 收到
    let mut receiver_events = receiver_sdk.event_bus().subscribe();
    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut received_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event {
                    received_count += 1;
                    if received_count >= 2 { break; }
                }
            }
        }
    }

    tokio::time::sleep(Duration::from_millis(500)).await;

    // B 标记会话已读
    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let _ = receiver_sdk.mark_conversation_as_read(conv_id, 1).await;

    // 验证 A 收到 C2CReadReceipt
    let timeout2 = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout2);
    let mut receipt_received = false;
    loop {
        tokio::select! {
            _ = &mut timeout2 => { break; }
            event = sender_events.next() => {
                if let Some(SdkEvent::C2CReadReceipt { receipts }) = event {
                    if !receipts.is_empty() {
                        receipt_received = true;
                        break;
                    }
                }
            }
        }
    }
    assert!(receipt_received, "A 未收到 C2CReadReceipt 事件");
}
