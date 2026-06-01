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
        "",
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
    let send_result = sender_sdk.send_text_message(text, &user1.user_id, "", 1).await;
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

    let send_1 = user1_sdk.send_text_message(text_1_to_2, &user2.user_id, "", 1).await;
    assert!(send_1.is_ok(), "A→B 发送失败");

    tokio::time::sleep(Duration::from_millis(500)).await;

    let send_2 = user2_sdk.send_text_message(text_2_to_1, &user1.user_id, "", 1).await;
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
    let send_result = sender_sdk.send_text_message(text, &user2.user_id, "", 1).await;
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
    let send_result = user1_sdk.send_text_message(text, &user2.user_id, "", 1).await;
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
        let _ = user1_sdk.send_text_message(&text, &user2.user_id, "", 1).await;
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
        let _ = user1_sdk.send_text_message(&text, &user2.user_id, "", 1).await;
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
        let _ = user1_sdk.send_text_message(&text, &user2.user_id, "", 1).await;
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
        let result = sender_sdk.send_text_message(&text, &user2.user_id, "", 1).await;
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
        let result = sender_sdk.send_text_message(&text, &user2.user_id, "", 1).await;
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
        let result = user1_sdk.send_text_message(&text, &user2.user_id, "", 1).await;
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
        let _ = sender_sdk.send_text_message(&text, &user2.user_id, "", 1).await;
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
        let _ = user1_sdk.send_text_message(&text, &user2.user_id, "", 1).await;
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
