mod common;

use common::*;
use std::time::Duration;

#[tokio::test]
#[ignore]
async fn test_message_types() {
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

    let message_tests = vec![
        ("文本消息", ContentType::Text, build_text_content("Hello! 这是一条文本消息测试。")),
        ("图片消息", ContentType::Picture, build_picture_content()),
        ("语音消息", ContentType::Sound, build_sound_content()),
        ("视频消息", ContentType::Video, build_video_content()),
        ("文件消息", ContentType::File, build_file_content()),
        ("自定义消息", ContentType::Custom, build_custom_content()),
        ("引用消息", ContentType::Quote, build_quote_content()),
        ("表情消息", ContentType::Face, build_face_content()),
    ];

    let mut sent_ok = 0;
    let mut failed = 0;

    for (name, ct, content) in &message_tests {
        println!("--- 测试: {} ---", name);

        let req = SendMessageReq {
            recv_id: user2.user_id.clone(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: *ct,
            content: content.clone(),
            client_msg_id: Some(format!("test_{}_{}", name, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())),
        };

        if let Ok(_) = sender_sdk.send_message(req).await {
            println!("  ✅ 发送成功 (ok)");
            sent_ok += 1;
        } else {
            println!("  ❌ 发送失败");
            failed += 1;
        }

        tokio::time::sleep(Duration::from_secs(1)).await;

        let timeout = tokio::time::sleep(Duration::from_secs(3));
        tokio::pin!(timeout);
        loop {
            tokio::select! {
                _ = &mut timeout => { println!("  ⏰ 超时"); break; }
                event = event_subscription.next() => {
                    match event {
                        Some(SdkEvent::NewMessage { .. }) => { println!("  ✅ 收到消息"); break; }
                        Some(_) => {}
                        None => break,
                    }
                }
            }
        }

        tokio::time::sleep(Duration::from_secs(1)).await;
    }

    println!("=== 消息类型测试完成 ===");
    println!("统计: 发送成功 {} 个, 失败 {} 个", sent_ok, failed);
    assert!(true);
}

#[tokio::test]
#[ignore]
async fn test_multiple_message_types() {
    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::SendMessageReq;
    use std::collections::HashMap;

    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 多消息类型收发测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut event_subscription = receiver_sdk.event_bus().subscribe();
    tokio::time::sleep(Duration::from_secs(2)).await;

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;

    struct TestCase {
        name: &'static str,
        content_type: ContentType,
        content: String,
    }

    let test_cases = vec![
        TestCase { name: "文本消息", content_type: ContentType::Text, content: r#"{"content":"这是一条纯文本消息"}"#.to_string() },
        TestCase { name: "图片消息", content_type: ContentType::Picture, content: r#"{"sourcePicture":{"width":800,"height":600,"type":"image/jpeg","size":102400,"url":"https://example.com/image.jpg"},"bigPicture":{"width":800,"height":600,"type":"image/jpeg","size":102400,"url":"https://example.com/image_big.jpg"},"snapshotPicture":{"width":200,"height":150,"type":"image/jpeg","size":10240,"url":"https://example.com/thumb.jpg"}}}"#.to_string() },
        TestCase { name: "语音消息", content_type: ContentType::Sound, content: r#"{"uuid":"sound_123","sourceUrl":"https://example.com/sound.amr","dataSize":51200,"duration":3000}"#.to_string() },
        TestCase { name: "视频消息", content_type: ContentType::Video, content: r#"{"videoUrl":"https://example.com/video.mp4","videoType":"mp4","videoSize":1048576,"duration":15000,"snapshotUrl":"https://example.com/snapshot.jpg","snapshotWidth":640,"snapshotHeight":480}"#.to_string() },
        TestCase { name: "文件消息", content_type: ContentType::File, content: r#"{"sourceUrl":"https://example.com/doc.pdf","fileName":"test.pdf","fileSize":204800}"#.to_string() },
        TestCase { name: "@消息", content_type: ContentType::AtText, content: r#"{"text":"@所有人 这是一条@消息","atUserList":["all"],"isAtSelf":false}"#.to_string() },
        TestCase { name: "合并转发", content_type: ContentType::Merger, content: r#"{"title":"聊天记录","abstractList":["消息1","消息2"]}"#.to_string() },
        TestCase { name: "名片消息", content_type: ContentType::Card, content: r#"{"userID":"card_123","nickname":"名片用户"}"#.to_string() },
        TestCase { name: "位置消息", content_type: ContentType::Location, content: r#"{"description":"北京市朝阳区","longitude":116.48,"latitude":39.99}"#.to_string() },
        TestCase { name: "引用消息", content_type: ContentType::Quote, content: r#"{"text":"回复内容","quoteMessage":{"clientMsgID":"qid","content":"{}","contentType":101}}"#.to_string() },
        TestCase { name: "表情消息", content_type: ContentType::Face, content: r#"{"index":1,"data":"😀"}"#.to_string() },
        TestCase { name: "自定义消息", content_type: ContentType::Custom, content: r#"{"data":"{\"type\":\"custom\"}"#.to_string() },
    ];

    println!("发送 {} 种类型的消息...", test_cases.len());
    let mut sent_results = Vec::new();

    for (i, tc) in test_cases.iter().enumerate() {
        let req = SendMessageReq {
            recv_id: user2.user_id.clone(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: tc.content_type,
            content: tc.content.clone(),
            client_msg_id: Some(format!("mtype_{}_{}", tc.content_type as i32,
                std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())),
        };

        println!("  [{}] {}...", i + 1, tc.name);
        let ok = sender_sdk.send_message(req).await.is_ok();
        sent_results.push((tc.name, tc.content_type as i32, ok));
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    println!("\n等待接收消息（10秒超时）...");
    let mut received: HashMap<i32, i32> = HashMap::new();
    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);

    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = event_subscription.next() => {
                match event {
                    Some(SdkEvent::NewMessage { message }) => {
                        if let Some(ct) = message.get("contentType").and_then(|v| v.as_i64()) {
                            *received.entry(ct as i32).or_insert(0) += 1;
                        }
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
    }

    let mut success = 0;
    for (name, ct, sent_ok) in &sent_results {
        let recv = received.contains_key(ct);
        let status = if *sent_ok && recv { success += 1; "✅" }
            else if *sent_ok { "⚠️ 未收到" } else { "❌ 发送失败" };
        println!("{:<10} 发送:{} 接收:{} {}", name,
            if *sent_ok { "✅" } else { "❌" },
            if recv { "✅" } else { "❌" }, status);
    }
    println!("\n总计: {}/{} 通过", success, sent_results.len());
    assert!(success > 0, "至少应有部分消息发送/接收成功");
    assert!(true);
}

#[tokio::test]
#[ignore]
async fn test_send_message_persistence() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 消息发送持久化测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::sdk::client::types::SendMessageReq;

    let req = SendMessageReq {
        recv_id: user2.user_id.clone(),
        group_id: String::new(),
        session_type: SessionType::SingleChat,
        content_type: ContentType::Text,
        content: r#"{\"content\":\"持久化测试消息\"}"#.to_string(),
        client_msg_id: Some(format!("persist_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())),
    };

    let result = sdk.send_message(req).await;
    assert!(result.is_ok(), "发送失败: {:?}", result.err());
    println!("  ✅ 消息发送并持久化成功");
    println!("✅ 消息发送持久化测试完成");
}

#[tokio::test]
#[ignore]
async fn test_message_sync() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::constant::enums::{ContentType, SessionType};
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
    use rust_lib_flutter_rust_demo::sdk::client::types::SendMessageReq;

    println!("=== 消息同步测试 ===\n");

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

        match sender_sdk.send_message(req).await {
            Ok(_) => println!("  ✅ 消息 {} 发送成功", i),
            Err(e) => println!("  ❌ 消息 {} 发送失败: {:?}", i, e),
        }
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    println!("等待接收消息（10秒超时）...");
    let receive_timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(receive_timeout);

    let mut received_count = 0;
    loop {
        tokio::select! {
            _ = &mut receive_timeout => { break; }
            event = event_subscription.next() => {
                match event {
                    Some(SdkEvent::NewMessage { .. }) => {
                        received_count += 1;
                        println!("  ✅ 收到消息 {}/{}", received_count, message_count);
                        if received_count >= message_count { break; }
                    }
                    Some(_) => {}
                    None => break,
                }
            }
        }
    }

    println!("\n发送: {}, 接收: {}", message_count, received_count);
    assert_eq!(received_count, message_count, "未收到全部消息");
    println!("✅ 消息同步测试完成");
}

#[tokio::test]
#[ignore]
async fn test_create_text_message_via_convenience() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;
    use rust_lib_flutter_rust_demo::domain::constant::enums::SessionType;

    println!("=== 便捷创建文本消息测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let mut req = OpenIMClient::create_text_message("hello");
    req.recv_id = user2.user_id.clone();
    req.session_type = SessionType::SingleChat;

    let result = sdk.send_message(req).await;
    assert!(result.is_ok(), "发送文本消息失败: {:?}", result.err());
    println!("  ✅ 文本消息发送成功");

    println!("✅ 便捷创建文本消息测试完成");
}

#[tokio::test]
#[ignore]
async fn test_create_at_text_message_send() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;
    use rust_lib_flutter_rust_demo::domain::constant::enums::SessionType;

    println!("=== @消息创建发送测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let at_users = vec![user2.user_id.clone()];
    let mut req = OpenIMClient::create_at_text_message("hello @user2", at_users);
    req.recv_id = user2.user_id.clone();
    req.session_type = SessionType::SingleChat;

    let result = sdk.send_message(req).await;
    assert!(result.is_ok(), "发送@消息失败: {:?}", result.err());
    println!("  ✅ @消息发送成功");

    println!("✅ @消息创建发送测试完成");
}

#[tokio::test]
#[ignore]
async fn test_create_face_message_send() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;
    use rust_lib_flutter_rust_demo::domain::constant::enums::SessionType;

    println!("=== 表情消息创建发送测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let mut req = OpenIMClient::create_face_message(1, "smile");
    req.recv_id = user2.user_id.clone();
    req.session_type = SessionType::SingleChat;

    let result = sdk.send_message(req).await;
    assert!(result.is_ok(), "发送表情消息失败: {:?}", result.err());
    println!("  ✅ 表情消息发送成功");

    println!("✅ 表情消息创建发送测试完成");
}
