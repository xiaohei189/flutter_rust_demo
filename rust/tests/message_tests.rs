mod common;

use common::*;
use std::time::Duration;

#[tokio::test]
async fn test_send_text_message_basic() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::SendMessageReq;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut event_subscription = receiver_sdk.event_bus().subscribe();

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;

    let client_msg_id = format!("test_text_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
    let req = SendMessageReq {
        recv_id: user2.user_id.clone(),
        group_id: String::new(),
        session_type: SessionType::SingleChat,
        content_type: ContentType::Text,
        content: r#"{"content":"Hello! 这是一条文本消息测试。"}"#.to_string(),
        client_msg_id: Some(client_msg_id.clone()),
    };

    let send_result = sender_sdk.send_message(req).await;
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

#[tokio::test]
async fn test_message_deduplication() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::SendMessageReq;

    let user1 = get_or_create_user1().await;
    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let mut event_subscription = sender_sdk.event_bus().subscribe();

    let client_msg_id = format!("dedup_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
    let req = SendMessageReq {
        recv_id: user1.user_id.clone(),
        group_id: String::new(),
        session_type: SessionType::SingleChat,
        content_type: ContentType::Text,
        content: r#"{"content":"自己发给自己测试"}"#.to_string(),
        client_msg_id: Some(client_msg_id.clone()),
    };

    let send_result = sender_sdk.send_message(req).await;
    assert!(send_result.is_ok(), "发送消息失败: {:?}", send_result.err());

    let timeout = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout);
    let mut new_message_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = event_subscription.next() => {
                match event {
                    Some(SdkEvent::NewMessage { message }) => {
                        if message.client_msg_id == client_msg_id {
                            new_message_count += 1;
                        }
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
    }

    assert_eq!(new_message_count, 0, "自己发的消息不应触发 NewMessage 事件（应被去重）");
}

#[tokio::test]
async fn test_bidirectional_messages() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::SendMessageReq;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;

    let mut user1_events = user1_sdk.event_bus().subscribe();
    let mut user2_events = user2_sdk.event_bus().subscribe();

    let req_1_to_2 = SendMessageReq {
        recv_id: user2.user_id.clone(),
        group_id: String::new(),
        session_type: SessionType::SingleChat,
        content_type: ContentType::Text,
        content: r#"{"content":"A→B 消息"}"#.to_string(),
        client_msg_id: Some(format!("a2b_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())),
    };

    let req_2_to_1 = SendMessageReq {
        recv_id: user1.user_id.clone(),
        group_id: String::new(),
        session_type: SessionType::SingleChat,
        content_type: ContentType::Text,
        content: r#"{"content":"B→A 消息"}"#.to_string(),
        client_msg_id: Some(format!("b2a_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())),
    };

    let send_1 = user1_sdk.send_message(req_1_to_2).await;
    assert!(send_1.is_ok(), "A→B 发送失败");

    tokio::time::sleep(Duration::from_millis(500)).await;

    let send_2 = user2_sdk.send_message(req_2_to_1).await;
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

#[tokio::test]
async fn test_message_status_flow() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::SendMessageReq;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let mut event_subscription = sender_sdk.event_bus().subscribe();

    let client_msg_id = format!("status_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
    let req = SendMessageReq {
        recv_id: user2.user_id.clone(),
        group_id: String::new(),
        session_type: SessionType::SingleChat,
        content_type: ContentType::Text,
        content: r#"{"content":"状态流转测试"}"#.to_string(),
        client_msg_id: Some(client_msg_id.clone()),
    };

    let send_result = sender_sdk.send_message(req).await;
    assert!(send_result.is_ok(), "发送消息失败: {:?}", send_result.err());

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut message_sent_received = false;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = event_subscription.next() => {
                match event {
                    Some(SdkEvent::MessageSent { client_msg_id: cmid, status, .. }) => {
                        if cmid == client_msg_id {
                            assert_eq!(status, 2, "MessageSent 事件状态应为成功(2)，实际: {}", status);
                            message_sent_received = true;
                            break;
                        }
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
    }

    assert!(message_sent_received, "未收到 MessageSent 事件");
}

#[tokio::test]
async fn test_mark_conversation_as_read() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::SendMessageReq;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;

    let mut user2_events = user2_sdk.event_bus().subscribe();

    let req = SendMessageReq {
        recv_id: user2.user_id.clone(),
        group_id: String::new(),
        session_type: SessionType::SingleChat,
        content_type: ContentType::Text,
        content: r#"{"content":"未读测试消息"}"#.to_string(),
        client_msg_id: Some(format!("unread_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())),
    };

    let send_result = user1_sdk.send_message(req).await;
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

    let conv_id = format!("si_{}_{}", user2.user_id, user1.user_id);
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

#[tokio::test]
async fn test_message_sync_multiple() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::SendMessageReq;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut event_subscription = receiver_sdk.event_bus().subscribe();
    tokio::time::sleep(Duration::from_secs(2)).await;

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;

    let message_count = 5;
    for i in 1..=message_count {
        let req = SendMessageReq {
            recv_id: user2.user_id.clone(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: ContentType::Text,
            content: format!("{{\"content\":\"同步测试消息 {}\"}}", i),
            client_msg_id: Some(format!("sync_{}_{}", i, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())),
        };

        let result = sender_sdk.send_message(req).await;
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
}

#[tokio::test]
async fn test_conversation_change_event() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::SendMessageReq;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = user2_sdk.event_bus().subscribe();

    for i in 1..=3 {
        let req = SendMessageReq {
            recv_id: user2.user_id.clone(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: ContentType::Text,
            content: format!("{{\"content\":\"会话变更测试消息 {}\"}}", i),
            client_msg_id: Some(format!("conv_change_{}_{}", i, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())),
        };
        let _ = user1_sdk.send_message(req).await;
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

#[tokio::test]
async fn test_message_read_status_in_db() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::SendMessageReq;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = user2_sdk.event_bus().subscribe();

    for i in 1..=3 {
        let req = SendMessageReq {
            recv_id: user2.user_id.clone(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: ContentType::Text,
            content: format!("{{\"content\":\"已读状态测试消息 {}\"}}", i),
            client_msg_id: Some(format!("read_status_{}_{}", i, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())),
        };
        let _ = user1_sdk.send_message(req).await;
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

    let conv_id = format!("si_{}_{}", user2.user_id, user1.user_id);
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

#[tokio::test]
async fn test_get_history_messages() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::{SendMessageReq, GetHistoryMessagesReq};

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = user2_sdk.event_bus().subscribe();

    let message_count = 10;
    let mut client_msg_ids = Vec::new();
    for i in 1..=message_count {
        let cmid = format!("history_{}_{}", i, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());
        client_msg_ids.push(cmid.clone());
        let req = SendMessageReq {
            recv_id: user2.user_id.clone(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: ContentType::Text,
            content: format!("{{\"content\":\"历史消息测试 {}\"}}", i),
            client_msg_id: Some(cmid),
        };
        let result = user1_sdk.send_message(req).await;
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

    let conv_id = format!("si_{}_{}", user2.user_id, user1.user_id);

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

#[tokio::test]
async fn test_unread_count_increment_and_clear() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::SendMessageReq;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = user2_sdk.event_bus().subscribe();

    for i in 1..=5 {
        let req = SendMessageReq {
            recv_id: user2.user_id.clone(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: ContentType::Text,
            content: format!("{{\"content\":\"未读递增测试消息 {}\"}}", i),
            client_msg_id: Some(format!("unread_inc_{}_{}", i, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())),
        };
        let _ = user1_sdk.send_message(req).await;
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    let timeout = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout);
    let mut new_msg_count = 0;
    let mut unread_counts = Vec::new();
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                match event {
                    Some(SdkEvent::NewMessage { .. }) => {
                        new_msg_count += 1;
                    }
                    Some(SdkEvent::ConversationChanged { conversations }) => {
                        if !conversations.is_empty() {
                            unread_counts.push(conversations[0].unread_count);
                        }
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

    let conv_id = format!("si_{}_{}", user2.user_id, user1.user_id);
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
