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

    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;
    use rust_lib_flutter_rust_demo::domain::constant::types::content_type;
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut event_subscription = receiver_sdk.event_bus.subscribe();

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;

    let message_tests = vec![
        ("文本消息", content_type::TEXT, build_text_content("Hello! 这是一条文本消息测试。")),
        ("图片消息", content_type::PICTURE, build_picture_content()),
        ("语音消息", content_type::SOUND, build_sound_content()),
        ("视频消息", content_type::VIDEO, build_video_content()),
        ("文件消息", content_type::FILE, build_file_content()),
        ("自定义消息", content_type::CUSTOM, build_custom_content()),
        ("引用消息", content_type::QUOTE, build_quote_content()),
        ("表情消息", content_type::FACE, build_face_content()),
    ];

    for (name, ct, content) in &message_tests {
        println!("--- 测试: {} ---", name);

        let msg = PendingMessage {
            client_msg_id: format!("test_{}_{}", name, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()),
            send_id: user1.user_id.clone(),
            recv_id: user2.user_id.clone(),
            group_id: String::new(),
            sender_platform_id: 1,
            sender_nickname: user1.nickname.clone(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: *ct,
            content: content.clone(),
        };

        match sender_sdk.message_sender.send_message(msg).await {
            Ok(_) => println!("  ✅ 发送成功"),
            Err(e) => println!("  ❌ 发送失败: {:?}", e),
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
}

#[tokio::test]
#[ignore]
async fn test_multiple_message_types() {
    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;
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
    let mut event_subscription = receiver_sdk.event_bus.subscribe();
    tokio::time::sleep(Duration::from_secs(2)).await;

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;

    struct TestCase {
        name: &'static str,
        content_type: i32,
        content: String,
    }

    let test_cases = vec![
        TestCase { name: "文本消息", content_type: 101, content: r#"{"content":"这是一条纯文本消息"}"#.to_string() },
        TestCase { name: "图片消息", content_type: 102, content: r#"{"sourcePicture":{"width":800,"height":600,"type":"image/jpeg","size":102400,"url":"https://example.com/image.jpg"},"bigPicture":{"width":800,"height":600,"type":"image/jpeg","size":102400,"url":"https://example.com/image_big.jpg"},"snapshotPicture":{"width":200,"height":150,"type":"image/jpeg","size":10240,"url":"https://example.com/thumb.jpg"}}"#.to_string() },
        TestCase { name: "语音消息", content_type: 103, content: r#"{"uuid":"sound_123","sourceUrl":"https://example.com/sound.amr","dataSize":51200,"duration":3000}"#.to_string() },
        TestCase { name: "视频消息", content_type: 104, content: r#"{"videoUrl":"https://example.com/video.mp4","videoType":"mp4","videoSize":1048576,"duration":15000,"snapshotUrl":"https://example.com/snapshot.jpg","snapshotWidth":640,"snapshotHeight":480}"#.to_string() },
        TestCase { name: "文件消息", content_type: 105, content: r#"{"sourceUrl":"https://example.com/doc.pdf","fileName":"test.pdf","fileSize":204800}"#.to_string() },
        TestCase { name: "@消息", content_type: 106, content: r#"{"text":"@所有人 这是一条@消息","atUserList":["all"],"isAtSelf":false}"#.to_string() },
        TestCase { name: "合并转发", content_type: 107, content: r#"{"title":"聊天记录","abstractList":["消息1","消息2"]}"#.to_string() },
        TestCase { name: "名片消息", content_type: 108, content: r#"{"userID":"card_123","nickname":"名片用户"}"#.to_string() },
        TestCase { name: "位置消息", content_type: 109, content: r#"{"description":"北京市朝阳区","longitude":116.48,"latitude":39.99}"#.to_string() },
        TestCase { name: "引用消息", content_type: 114, content: r#"{"text":"回复内容","quoteMessage":{"clientMsgID":"qid","content":"{}","contentType":101}}"#.to_string() },
        TestCase { name: "表情消息", content_type: 115, content: r#"{"index":1,"data":"😀"}"#.to_string() },
        TestCase { name: "自定义消息", content_type: 110, content: r#"{"data":"{\"type\":\"custom\"}""#.to_string() },
    ];

    println!("发送 {} 种类型的消息...", test_cases.len());
    let mut sent_results = Vec::new();

    for (i, tc) in test_cases.iter().enumerate() {
        let client_msg_id = format!("mtype_{}_{}", tc.content_type,
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());

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
            content_type: tc.content_type,
            content: tc.content.clone(),
        };

        println!("  [{}] {}...", i + 1, tc.name);
        let ok = sender_sdk.message_sender.send_message(msg).await.is_ok();
        sent_results.push((tc.name, tc.content_type, ok));
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

    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;

    let msg = PendingMessage {
        client_msg_id: format!("persist_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()),
        send_id: user1.user_id.clone(),
        recv_id: user2.user_id.clone(),
        group_id: String::new(),
        sender_platform_id: 1,
        sender_nickname: user1.nickname.clone(),
        sender_face_url: String::new(),
        session_type: 1,
        msg_from: 100,
        content_type: 101,
        content: r#"{"content":"持久化测试消息"}"#.to_string(),
    };

    let result = sdk.message_sender.send_message(msg).await;
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

    use rust_lib_flutter_rust_demo::core::message::sender::PendingMessage;
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    println!("=== 消息同步测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut event_subscription = receiver_sdk.event_bus.subscribe();
    tokio::time::sleep(Duration::from_secs(2)).await;

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;

    let message_count = 5;
    for i in 1..=message_count {
        let msg = PendingMessage {
            client_msg_id: format!("sync_{}_{}", i, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis()),
            send_id: user1.user_id.clone(),
            recv_id: user2.user_id.clone(),
            group_id: String::new(),
            sender_platform_id: 1,
            sender_nickname: user1.nickname.clone(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: format!("{{\"content\":\"同步测试消息 {}\"}}", i),
        };

        match sender_sdk.message_sender.send_message(msg).await {
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
    if received_count >= message_count {
        println!("  ✅ 消息同步测试通过");
    } else {
        println!("  ⚠️ 部分消息未收到");
    }
}
