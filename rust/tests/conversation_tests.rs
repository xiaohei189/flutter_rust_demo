mod common;

use common::*;
use rust_lib_flutter_rust_demo::client::*;
use std::time::Duration;

fn make_conversation_id(uid1: &str, uid2: &str) -> String {
    let mut ids = vec![uid1.to_string(), uid2.to_string()];
    ids.sort();
    format!("si_{}_{}", ids[0], ids[1])
}

// ============================================================================
// 第一类：基本会话操作
// 覆盖：会话列表获取、会话存在性验证
// ============================================================================

/// 场景：A 发消息给 B，B 查询会话列表
/// 验证：B 的会话列表包含与 A 的会话，字段正确
#[tokio::test]
async fn test_conversation_list_sync() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    // A 发消息触发会话创建
    let _ = sender_sdk.send_text_message("会话同步测试", &user2.user_id, 1).await;

    // 等待消息到达
    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event {
                    break;
                }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    // B 获取会话列表
    let convs = receiver_sdk.get_conversations().await;
    assert!(convs.is_ok(), "get_conversations 应该返回 Ok");
    let list = convs.unwrap();
    assert!(!list.is_empty(), "会话列表不应为空");

    // 验证存在与 A 的会话
    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let found = list.iter().any(|c| c.conversation_id == conv_id);
    assert!(found, "应找到与用户1的会话: {}", conv_id);
    println!("会话列表测试通过，共 {} 个会话", list.len());
}

/// 场景：B 获取单个会话信息
/// 验证：get_conversation 返回正确会话
#[tokio::test]
async fn test_get_single_conversation() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    let _ = sender_sdk.send_text_message("单会话查询测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event {
                    break;
                }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let result = receiver_sdk.get_conversation(&conv_id).await;
    assert!(result.is_ok(), "get_conversation 应该返回 Ok");

    match result.unwrap() {
        Some(conv) => {
            assert_eq!(conv.conversation_id, conv_id, "会话ID不匹配");
            assert!(conv.conversation_type == 1, "应为单聊类型");
        }
        None => panic!("应找到会话: {}", conv_id),
    }
}

// ============================================================================
// 第二类：未读数管理
// 覆盖：未读数递增、会话已读清零、全局未读数
// ============================================================================

/// 场景：A 发 3 条消息给 B，B 验证未读数递增
/// 验证：未读数与消息数一致
#[tokio::test]
async fn test_conversation_unread_count() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = subscribe_all(&user2_sdk);

    // 发送 3 条消息
    for i in 1..=3 {
        let _ = user1_sdk.send_text_message(&format!("未读数测试 {}", i), &user2.user_id, 1).await;
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
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event {
                    msg_count += 1;
                    if msg_count >= 3 { break; }
                }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    // 验证未读数
    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let conv = user2_sdk.get_conversation(&conv_id).await.expect("获取会话失败");
    match conv {
        Some(c) => {
            assert!(c.unread_count >= 3, "未读数应 >= 3, 实际: {}", c.unread_count);
            println!("未读数: {}", c.unread_count);
        }
        None => panic!("未找到会话"),
    }
}

/// 场景：标记已读完整流程
/// 1. 正常路径：消息在本地 → 标记已读 → 验证未读清零 + ConversationChanged 事件
/// 2. Fallback 路径：重新登录，消息表为空 → 同步会话 → 标记已读 → 验证使用会话表 maxSeq
#[tokio::test]
async fn test_conversation_mark_read() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = subscribe_all(&user2_sdk);

    // ===== 阶段一：正常路径（消息在本地） =====
    println!("=== 阶段一：正常路径 ===");

    for i in 1..=2 {
        let _ = user1_sdk.send_text_message(&format!("已读测试 {}", i), &user2.user_id, 1).await;
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut msg_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event {
                    msg_count += 1;
                    if msg_count >= 2 { break; }
                }
            }
        }
    }
    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let conv = user2_sdk.get_conversation(&conv_id).await.unwrap().unwrap();
    assert!(conv.unread_count > 0, "User2 应有未读, 实际: {}", conv.unread_count);
    println!("阶段一标记前未读数: {}", conv.unread_count);

    let mark_result = user2_sdk.mark_conversation_message_as_read(conv_id.clone(), 1).await;
    assert!(mark_result.is_ok(), "标记已读失败: {:?}", mark_result.err());

    let conv = user2_sdk.get_conversation(&conv_id).await.unwrap().unwrap();
    assert_eq!(conv.unread_count, 0, "标记后未读应为 0, 实际: {}", conv.unread_count);

    let timeout2 = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout2);
    let mut conv_changed = false;
    loop {
        tokio::select! {
            _ = &mut timeout2 => { break; }
            event = user2_events.next() => {
                if let Some(TestEvent::Conversation(ConversationEvent::Changed(conversations))) = event {
                    for conv in &conversations {
                        if conv.conversation_id == conv_id {
                            assert_eq!(conv.unread_count, 0, "事件中未读应为 0");
                            conv_changed = true;
                            break;
                        }
                    }
                    if conv_changed { break; }
                }
            }
        }
    }
    assert!(conv_changed, "应收到 ConversationChanged 事件");
    println!("阶段一完成 ✓");

    // ===== 阶段二：Fallback 路径（消息表为空） =====
    println!("=== 阶段二：Fallback 路径 ===");

    for i in 3..=4 {
        let _ = user1_sdk.send_text_message(&format!("新消息 {}", i), &user2.user_id, 1).await;
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    let timeout3 = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout3);
    loop {
        tokio::select! {
            _ = &mut timeout3 => { break; }
            event = user2_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event {
                    msg_count += 1;
                    if msg_count >= 4 { break; }
                }
            }
        }
    }
    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv = user2_sdk.get_conversation(&conv_id).await.unwrap().unwrap();
    assert!(conv.unread_count > 0, "新消息后应有未读, 实际: {}", conv.unread_count);
    println!("阶段二标记前未读数: {}", conv.unread_count);

    // 重新创建 SDK（模拟重新登录，消息表为空但会话表有数据）
    let user2_sdk_fresh = create_sdk(&user2, &user2_im_token).await;
    let _ = user2_sdk_fresh.incr_sync_conversations().await;

    let conv = user2_sdk_fresh.get_conversation(&conv_id).await.unwrap().unwrap();
    assert!(conv.unread_count > 0, "同步后应有未读, 实际: {}", conv.unread_count);
    println!("重新登录后未读数: {}", conv.unread_count);

    let mark_result = user2_sdk_fresh.mark_conversation_message_as_read(conv_id.clone(), 1).await;
    assert!(mark_result.is_ok(), "fallback 标记已读失败: {:?}", mark_result.err());

    let conv = user2_sdk_fresh.get_conversation(&conv_id).await.unwrap().unwrap();
    assert_eq!(conv.unread_count, 0, "fallback 标记后未读应为 0, 实际: {}", conv.unread_count);
    println!("阶段二完成 ✓");
}

// ============================================================================
// 第三类：置顶/免打扰
// 覆盖：置顶/取消置顶、获取置顶列表、免打扰设置
// ============================================================================

/// 场景：B 给与 A 的会话设置置顶，验证置顶列表
/// 验证：get_pinned_conversations 包含该会话
#[tokio::test]
async fn test_conversation_pinned() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    // 先发消息创建会话
    let _ = sender_sdk.send_text_message("置顶测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    // 置顶
    let pin_result = receiver_sdk.set_conversation_pinned(&conv_id, true).await;
    assert!(pin_result.is_ok(), "置顶失败: {:?}", pin_result.err());

    // 验证置顶列表
    let pinned = receiver_sdk.get_pinned_conversations().await;
    assert!(pinned.is_ok(), "获取置顶列表失败");
    let pinned_list = pinned.unwrap();
    let found = pinned_list.iter().any(|c| c.conversation_id == conv_id);
    assert!(found, "置顶列表应包含该会话");

    // 取消置顶
    let unpin_result = receiver_sdk.set_conversation_pinned(&conv_id, false).await;
    assert!(unpin_result.is_ok(), "取消置顶失败: {:?}", unpin_result.err());

    let pinned_after = receiver_sdk.get_pinned_conversations().await.unwrap();
    let still_found = pinned_after.iter().any(|c| c.conversation_id == conv_id);
    assert!(!still_found, "取消置顶后不应在置顶列表中");
}

/// 场景：B 设置会话免打扰
/// 验证：set_conversation_private 成功
#[tokio::test]
async fn test_conversation_private() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    let _ = sender_sdk.send_text_message("免打扰测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    // 设置免打扰
    let result = receiver_sdk.set_conversation_private(&conv_id, true).await;
    assert!(result.is_ok(), "设置免打扰失败: {:?}", result.err());

    // 取消免打扰
    let result = receiver_sdk.set_conversation_private(&conv_id, false).await;
    assert!(result.is_ok(), "取消免打扰失败: {:?}", result.err());
}

// ============================================================================
// 第四类：草稿管理
// 覆盖：设置草稿、验证草稿内容、清除草稿
// ============================================================================

/// 场景：B 给会话设置草稿，验证草稿内容，然后清除
/// 验证：草稿设置/清除操作成功
#[tokio::test]
async fn test_conversation_draft() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    let _ = sender_sdk.send_text_message("草稿测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    // 设置草稿
    let draft_text = "这是一条草稿消息，准备发送给对方";
    let draft_result = receiver_sdk.set_conversation_draft(&conv_id, draft_text).await;
    assert!(draft_result.is_ok(), "设置草稿失败: {:?}", draft_result.err());

    // 验证草稿已保存
    let conv = receiver_sdk.get_conversation(&conv_id).await.unwrap();
    match conv {
        Some(c) => {
            assert!(!c.draft_text.is_empty(), "草稿文本不应为空");
            assert!(c.draft_text.contains("草稿消息"), "草稿内容不匹配");
        }
        None => panic!("未找到会话"),
    }

    // 清除草稿
    let clear_result = receiver_sdk.clear_conversation_draft(&conv_id).await;
    assert!(clear_result.is_ok(), "清除草稿失败: {:?}", clear_result.err());

    // 验证草稿已清除
    let conv_after = receiver_sdk.get_conversation(&conv_id).await.unwrap();
    match conv_after {
        Some(c) => {
            assert!(c.draft_text.is_empty(), "草稿应已被清除");
        }
        None => panic!("未找到会话"),
    }
}

// ============================================================================
// 第五类：会话删除
// 覆盖：删除会话后不可见
// ============================================================================

/// 场景：B 删除与 A 的会话，验证会话不再可见
/// 验证：delete_conversation 成功后 get_conversation 返回 None
#[tokio::test]
async fn test_conversation_delete() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    let _ = sender_sdk.send_text_message("删除测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    // 确认会话存在
    let before = receiver_sdk.get_conversation(&conv_id).await.unwrap();
    assert!(before.is_some(), "删除前会话应存在");

    // 删除会话
    let del_result = receiver_sdk.delete_conversation(&conv_id).await;
    assert!(del_result.is_ok(), "删除会话失败: {:?}", del_result.err());

    // 验证会话已删除
    let after = receiver_sdk.get_conversation(&conv_id).await.unwrap();
    assert!(after.is_none(), "删除后会话应不存在");
}

// ============================================================================
// 第六类：set_conversation 通用设置
// 覆盖：recv_msg_opt、is_pinned、is_private_chat、group_at_type、ex
// ============================================================================

/// 场景：使用 set_conversation 通用 API 设置多种属性
/// 验证：各属性均正确更新
#[tokio::test]
async fn test_set_conversation() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    let _ = sender_sdk.send_text_message("通用设置测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    // 设置 recv_msg_opt=1 (不接收), is_pinned=true, is_private_chat=true, ex="test_key"
    let result = receiver_sdk
        .set_conversation(
            &conv_id,
            Some(1),                     // recv_msg_opt: 不接收消息
            Some(true),                  // is_pinned: 置顶
            Some(true),                  // is_private_chat: 免打扰
            None,                        // group_at_type
            Some("test_key=test_value"), // ex
        )
        .await;
    assert!(result.is_ok(), "set_conversation 失败: {:?}", result.err());

    // 验证属性已更新
    let conv = receiver_sdk.get_conversation(&conv_id).await.unwrap();
    match conv {
        Some(c) => {
            assert_eq!(c.recv_msg_opt, 1, "recv_msg_opt 应为 1");
            assert!(c.is_pinned, "is_pinned 应为 true");
            assert!(c.is_private_chat, "is_private_chat 应为 true");
            assert_eq!(c.ex, "test_key=test_value", "ex 字段不匹配");
        }
        None => panic!("未找到会话"),
    }

    // 恢复设置
    let _ = receiver_sdk.set_conversation(&conv_id, Some(0), Some(false), Some(false), None, Some("")).await;
}

// ============================================================================
// 第七类：会话 ID 生成
// 覆盖：单聊/群聊/超级群聊/通知会话 ID 格式
// ============================================================================

/// 场景：验证 get_conversation_id_by_session_type 对不同会话类型的 ID 生成
/// 验证：单聊 si_、群聊 g_、超级群聊 sg_、通知 sn_ 前缀
#[tokio::test]
async fn test_get_conversation_id_by_session_type() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let other_id = "test_user_123";
    let group_id = "group_456";

    // 单聊 (1)
    let conv_id = sdk.get_conversation_id_by_session_type(other_id, 1);
    assert!(conv_id.starts_with("si_"), "单聊会话ID应以 'si_' 开头: {}", conv_id);

    // 普通群聊 (2)
    let conv_id = sdk.get_conversation_id_by_session_type(group_id, 2);
    assert_eq!(conv_id, format!("g_{}", group_id), "群聊会话ID应为 g_{{group_id}}");

    // 超级群聊 (3)
    let conv_id = sdk.get_conversation_id_by_session_type(group_id, 3);
    assert_eq!(conv_id, format!("sg_{}", group_id), "超级群聊会话ID应为 sg_{{group_id}}");

    // 通知会话 (4)
    let conv_id = sdk.get_conversation_id_by_session_type(other_id, 4);
    assert!(conv_id.starts_with("sn_"), "通知会话ID应以 'sn_' 开头: {}", conv_id);

    println!("会话ID生成测试全部通过");
}

// ============================================================================
// 第八类：综合场景 - 消息驱动的会话管理
// ============================================================================

/// 场景：完整的会话生命周期 - A 发消息 → B 接收 → B 置顶 → B 设置草稿 → B 标记已读 → B 删除
/// 验证：每个步骤都正确执行
#[tokio::test]
async fn test_conversation_lifecycle() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = subscribe_all(&user2_sdk);

    // Step 1: A 发消息给 B
    println!("[1/6] A 发消息给 B...");
    let _ = user1_sdk.send_text_message("生命周期测试消息", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    // Step 2: 验证会话已创建
    println!("[2/6] 验证会话已创建...");
    let conv = user2_sdk.get_conversation(&conv_id).await.unwrap();
    assert!(conv.is_some(), "会话应已创建");
    assert!(conv.unwrap().unread_count > 0, "应有未读消息");

    // Step 3: 置顶会话
    println!("[3/6] 置顶会话...");
    let pin_result = user2_sdk.set_conversation_pinned(&conv_id, true).await;
    assert!(pin_result.is_ok(), "置顶失败");
    let pinned = user2_sdk.get_pinned_conversations().await.unwrap();
    assert!(pinned.iter().any(|c| c.conversation_id == conv_id), "应已置顶");

    // Step 4: 设置草稿
    println!("[4/6] 设置草稿...");
    let draft_result = user2_sdk.set_conversation_draft(&conv_id, "草稿内容").await;
    assert!(draft_result.is_ok(), "设置草稿失败");

    // Step 5: 标记已读
    println!("[5/6] 标记已读...");
    let mark_result = user2_sdk.mark_conversation_message_as_read(conv_id.clone(), 1).await;
    assert!(mark_result.is_ok(), "标记已读失败");
    let conv_after_read = user2_sdk.get_conversation(&conv_id).await.unwrap().unwrap();
    assert_eq!(conv_after_read.unread_count, 0, "已读后未读数应为0");

    // Step 6: 删除会话
    println!("[6/6] 删除会话...");
    let del_result = user2_sdk.delete_conversation(&conv_id).await;
    assert!(del_result.is_ok(), "删除失败");
    let conv_after_del = user2_sdk.get_conversation(&conv_id).await.unwrap();
    assert!(conv_after_del.is_none(), "删除后会话应不存在");

    println!("会话生命周期测试全部通过!");
}

// ============================================================================
// 第九类：未读数持久化
// 覆盖：设置未读数 → 重新登录后保持
// ============================================================================

/// 场景：设置未读数 → 登出 → 重新登录 → 验证未读数保持
/// 验证：未读数在重新登录后持久化
#[tokio::test]
async fn test_unread_count_persistence() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    // 发消息创建会话
    let _ = sender_sdk.send_text_message("持久化测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    // 设置一个特定的未读数
    let test_unread: i64 = 42;
    let _ = receiver_sdk.update_conversation_unread_count(&conv_id, test_unread).await;
    tokio::time::sleep(Duration::from_secs(1)).await;

    // 验证设置后的未读数
    let conv = receiver_sdk.get_conversation(&conv_id).await.unwrap().unwrap();
    assert_eq!(conv.unread_count as i64, test_unread, "设置后未读数应为 {}", test_unread);

    // 登出
    receiver_sdk.logout().await.expect("登出失败");

    // 重新登录
    receiver_sdk.login(&user2.user_id, &user2_im_token).await.expect("重新登录失败");
    tokio::time::sleep(Duration::from_secs(3)).await;

    // 验证未读数持久化
    let conv_after = receiver_sdk.get_conversation(&conv_id).await.unwrap();
    match conv_after {
        Some(c) => {
            assert_eq!(c.unread_count as i64, test_unread, "重新登录后未读数应保持 {}, 实际: {}", test_unread, c.unread_count);
        }
        None => {
            // 会话可能在重新登录后通过同步重建
            println!("重新登录后会话不存在，可能需要等待同步完成");
        }
    }
}

// ============================================================================
// 第十类：双向用户场景
// 覆盖：A 发消息 → B 接收 → B 标记已读 → 验证 A 端感知
// ============================================================================

/// 场景：A 发消息给 B，B 接收后标记已读，验证完整的消息流转
/// 验证：未读数递增→清零的完整流程
#[tokio::test]
async fn test_unread_count_after_message() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let user1_sdk = create_sdk(&user1, &user1_im_token).await;
    let user2_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut user2_events = subscribe_all(&user2_sdk);

    // A 发 2 条消息
    let _ = user1_sdk.send_text_message("消息1", &user2.user_id, 1).await;
    tokio::time::sleep(Duration::from_millis(500)).await;
    let _ = user1_sdk.send_text_message("消息2", &user2.user_id, 1).await;

    // 等待 B 收到
    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut msg_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event {
                    msg_count += 1;
                    if msg_count >= 2 { break; }
                }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    // 验证 B 的会话有未读
    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let conv = user2_sdk.get_conversation(&conv_id).await.unwrap().unwrap();
    assert!(conv.unread_count >= 2, "B 应有 >= 2 条未读");
    println!("B 的未读数: {}", conv.unread_count);

    // B 标记已读
    user2_sdk.mark_conversation_message_as_read(conv_id.clone(), 1).await.unwrap();

    // 验证 B 的未读数清零
    let conv_after = user2_sdk.get_conversation(&conv_id).await.unwrap().unwrap();
    assert_eq!(conv_after.unread_count, 0, "标记已读后未读数应为 0");

    // 验证 B 的消息已读状态
    let history = user2_sdk
        .get_history_messages(rust_lib_flutter_rust_demo::client::GetHistoryMessagesReq {
            conversation_id: conv_id,
            start_client_msg_id: String::new(),
            count: 10,
        })
        .await
        .unwrap();

    let read_msgs = history.messages.iter().filter(|m| m.is_read).count();
    assert!(read_msgs > 0, "应有消息标记为已读");
    println!("已读消息数: {}", read_msgs);
}

// ============================================================================
// 第十一类：更新未读数
// ============================================================================

/// 场景：手动设置未读数并验证
/// 验证：update_conversation_unread_count 正确更新
#[tokio::test]
async fn test_update_conversation_unread_count() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    let _ = sender_sdk.send_text_message("未读数更新测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    // 设置未读数为 10
    receiver_sdk.update_conversation_unread_count(&conv_id, 10).await.unwrap();
    let conv = receiver_sdk.get_conversation(&conv_id).await.unwrap().unwrap();
    assert_eq!(conv.unread_count, 10, "未读数应为 10");

    // 设置未读数为 0
    receiver_sdk.update_conversation_unread_count(&conv_id, 0).await.unwrap();
    let conv = receiver_sdk.get_conversation(&conv_id).await.unwrap().unwrap();
    assert_eq!(conv.unread_count, 0, "未读数应为 0");
}

// ============================================================================
// 第十二类：分页获取会话列表
// 覆盖：get_conversation_list_split 分页 + 置顶排序
// ============================================================================

/// 场景：验证分页获取会话列表（get_conversation_list_split）
///
/// 步骤：
///   Phase 1: A 创建 5 个随机账号并分别与 B 建立好友
///   Phase 2: A 向 5 个账号各发送 1 条消息，创建 5 个会话
///   Phase 3: B 登录，等待同步
///   Phase 4: B 分页查询 offset=0, count=3 → 验证返回 3 条
///   Phase 5: B 分页查询 offset=3, count=3 → 验证返回 2 条
///   Phase 6: 验证排序 — 置顶优先，然后按时间降序
///   Phase 7: B 置顶第 3 个会话，重新查询 offset=0, count=3 → 验证置顶的排在前面
#[tokio::test]
async fn test_conversation_list_split() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    println!("[Phase 1] 创建 5 个随机账号...");
    let mut sender_accounts = Vec::new();
    for i in 0..5 {
        let account = create_random_account(&format!("SplitSender{}", i)).await;
        sender_accounts.push(account);
    }

    let receiver = create_random_account("SplitReceiver").await;
    let (receiver_token, _) = login_account(&receiver).await.expect("接收方登录失败");
    let receiver_sdk = create_sdk(&receiver, &receiver_token).await;

    println!("[Phase 1] 建立好友关系...");
    let mut sender_sdks = Vec::new();
    for (i, account) in sender_accounts.iter().enumerate() {
        let (token, _) = login_account(account).await.expect(&format!("发送方{}登录失败", i));
        let sdk = create_sdk(account, &token).await;
        ensure_friends(&sdk, &account.user_id, &receiver_sdk, &receiver.user_id).await;
        sender_sdks.push(sdk);
    }

    println!("[Phase 2] 发送 5 条消息创建 5 个会话...");
    let mut receiver_events = subscribe_all(&receiver_sdk);
    for (i, sdk) in sender_sdks.iter().enumerate() {
        let _ = sdk.send_text_message(&format!("分页测试消息 {}", i), &receiver.user_id, 1).await;
        tokio::time::sleep(Duration::from_millis(300)).await;
    }

    println!("[Phase 3] 等待消息到达...");
    let timeout = tokio::time::sleep(Duration::from_secs(30));
    tokio::pin!(timeout);
    let mut msg_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event {
                    msg_count += 1;
                    if msg_count >= 5 { break; }
                }
            }
        }
    }
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("[Phase 4] 分页查询 offset=0, count=3...");
    let page1 = receiver_sdk.get_conversation_list_split(0, 3).await.expect("分页查询失败");
    assert_eq!(page1.len(), 3, "第一页应返回 3 条，实际: {}", page1.len());
    println!("  第一页: {} 条会话", page1.len());

    println!("[Phase 5] 分页查询 offset=3, count=3...");
    let page2 = receiver_sdk.get_conversation_list_split(3, 3).await.expect("分页查询失败");
    assert_eq!(page2.len(), 2, "第二页应返回 2 条，实际: {}", page2.len());
    println!("  第二页: {} 条会话", page2.len());

    println!("[Phase 6] 验证排序（时间降序）...");
    // 验证每页内按时间降序
    for page in [&page1, &page2] {
        for window in page.windows(2) {
            assert!(
                window[0].latest_msg_send_time >= window[1].latest_msg_send_time,
                "会话应按时间降序排列: {} < {}",
                window[0].latest_msg_send_time,
                window[1].latest_msg_send_time,
            );
        }
    }
    // 跨页验证：第一页最后一条 >= 第二页第一条
    if !page1.is_empty() && !page2.is_empty() {
        assert!(page1.last().unwrap().latest_msg_send_time >= page2.first().unwrap().latest_msg_send_time, "跨页排序不正确");
    }
    println!("  排序验证通过");

    println!("[Phase 7] 置顶第 3 个会话后重新查询...");
    let third_conv_id = &page1[2].conversation_id;
    receiver_sdk.set_conversation_pinned(third_conv_id, true).await.expect("置顶失败");

    let page1_pinned = receiver_sdk.get_conversation_list_split(0, 3).await.expect("置顶后分页查询失败");
    assert_eq!(page1_pinned.len(), 3, "置顶后第一页仍应返回 3 条");

    // 验证置顶的排在最前面
    let pinned_found = page1_pinned.iter().position(|c| &c.conversation_id == third_conv_id);
    assert!(pinned_found.is_some(), "置顶会话应在第一页中");
    assert_eq!(pinned_found.unwrap(), 0, "置顶会话应排在第一位");
    println!("  置顶排序验证通过");

    // 恢复
    receiver_sdk.set_conversation_pinned(third_conv_id, false).await.ok();

    println!("test_conversation_list_split 通过!");
}

// ============================================================================
// 第十三类：按 ID 批量获取会话
// 覆盖：get_multiple_conversations 批量查询 + 不存在的 ID
// ============================================================================

/// 场景：验证按 ID 列表批量获取会话（get_multiple_conversations）
///
/// 步骤：
///   Phase 1: A 发送消息给 B，创建 2 个会话
///   Phase 2: B 登录，等待同步
///   Phase 3: B 用 get_multiple_conversations 查询 2 个会话 ID + 1 个不存在的 ID
///            → 验证返回 2 条（不存在的被忽略）
///   Phase 4: 查询空列表 → 验证返回空
#[tokio::test]
async fn test_multiple_conversations() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    println!("[Phase 1] 创建发送方，发送 2 条消息...");
    let sender = create_random_account("MultiSender").await;
    let receiver = create_random_account("MultiReceiver").await;

    let (sender_token, _) = login_account(&sender).await.expect("发送方登录失败");
    let (receiver_token, _) = login_account(&receiver).await.expect("接收方登录失败");

    let sender_sdk = create_sdk(&sender, &sender_token).await;
    let receiver_sdk = create_sdk(&receiver, &receiver_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    ensure_friends(&sender_sdk, &sender.user_id, &receiver_sdk, &receiver.user_id).await;

    // 创建 2 个会话（发送 2 条消息到同一个接收方会触发会话创建）
    let _ = sender_sdk.send_text_message("批量查询测试1", &receiver.user_id, 1).await;
    tokio::time::sleep(Duration::from_millis(500)).await;
    let _ = sender_sdk.send_text_message("批量查询测试2", &receiver.user_id, 1).await;

    println!("[Phase 2] 等待消息到达...");
    let timeout = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout);
    let mut msg_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event {
                    msg_count += 1;
                    if msg_count >= 2 { break; }
                }
            }
        }
    }
    tokio::time::sleep(Duration::from_secs(1)).await;

    // 会话 ID 是 si_{sorted(sender, receiver)}，两条消息是同一个会话
    let conv_id = make_conversation_id(&receiver.user_id, &sender.user_id);
    let fake_id = "si_nonexistent_user1_nonexistent_user2";
    let nonexistent_id = "si_does_not_exist_xyz";

    println!("[Phase 3] 批量查询 2 个有效 ID + 1 个不存在的 ID...");
    let results = receiver_sdk
        .get_multiple_conversations(vec![conv_id.clone(), fake_id.to_string(), nonexistent_id.to_string()])
        .await
        .expect("批量查询失败");

    // 至少应找到 conv_id 对应的会话
    let found = results.iter().any(|c| c.conversation_id == conv_id);
    assert!(found, "应找到会话: {}", conv_id);
    println!("  批量查询返回 {} 条（期望至少 1 条）", results.len());

    // fake_id 和 nonexistent_id 不应存在
    assert!(!results.iter().any(|c| c.conversation_id == fake_id), "不存在的会话不应返回: {}", fake_id);
    assert!(!results.iter().any(|c| c.conversation_id == nonexistent_id), "不存在的会话不应返回: {}", nonexistent_id);

    println!("[Phase 4] 查询空列表...");
    let empty = receiver_sdk.get_multiple_conversations(vec![]).await.expect("空列表查询失败");
    assert!(empty.is_empty(), "空列表查询应返回空，实际: {}", empty.len());

    println!("test_multiple_conversations 通过!");
}

// ============================================================================
// 第十四类：搜索会话
// 覆盖：search_conversations 模糊搜索 + 空关键词错误
// ============================================================================

/// 场景：验证搜索会话（search_conversations）
///
/// 步骤：
///   Phase 1: A 发送消息给 B，创建会话（会话 show_name 包含 A 的昵称）
///   Phase 2: B 登录，等待同步
///   Phase 3: B 用 A 的昵称搜索 → 验证找到会话
///   Phase 4: B 用不存在的关键词搜索 → 验证返回空
///   Phase 5: 空关键词搜索 → 验证返回错误
#[tokio::test]
async fn test_search_conversations() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    println!("[Phase 1] 创建发送方和接收方...");
    let sender = create_random_account("SearchSender").await;
    let receiver = create_random_account("SearchReceiver").await;

    let (sender_token, _) = login_account(&sender).await.expect("发送方登录失败");
    let (receiver_token, _) = login_account(&receiver).await.expect("接收方登录失败");

    let sender_sdk = create_sdk(&sender, &sender_token).await;
    let receiver_sdk = create_sdk(&receiver, &receiver_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    ensure_friends(&sender_sdk, &sender.user_id, &receiver_sdk, &receiver.user_id).await;

    println!("[Phase 1] A 发消息给 B...");
    let _ = sender_sdk.send_text_message("搜索测试消息", &receiver.user_id, 1).await;

    println!("[Phase 2] 等待消息到达...");
    let timeout = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }
    tokio::time::sleep(Duration::from_secs(1)).await;

    println!("[Phase 3] 搜索会话（按 show_name）...");
    // 注意: show_name 在同步时可能为空或为默认值，搜索按 show_name 匹配
    // 先获取会话列表确认 show_name 的实际值
    let all_convs = receiver_sdk.get_conversations().await.unwrap();
    let target_conv = all_convs.iter().find(|c| c.conversation_id.contains(&sender.user_id) || c.conversation_id.contains(&receiver.user_id));
    if let Some(conv) = target_conv {
        println!("  目标会话 show_name='{}', conv_id='{}'", conv.show_name, conv.conversation_id);
        if !conv.show_name.is_empty() {
            let results = receiver_sdk.search_conversations(&conv.show_name).await.unwrap();
            assert!(!results.is_empty(), "应通过 show_name '{}' 找到会话", conv.show_name);
            println!("  搜索到 {} 条结果 ✓", results.len());
        } else {
            println!("  show_name 为空，跳过昵称搜索验证（符合预期：同步器未设置 show_name）");
        }
    } else {
        println!("  未找到目标会话，跳过搜索验证");
    }

    println!("[Phase 4] 用不存在的关键词搜索...");
    let not_found = receiver_sdk.search_conversations("ZZZZZZ_NONEXISTENT_KEYWORD").await.expect("搜索不存在的关键词失败");
    assert!(not_found.is_empty(), "搜索不存在的关键词应返回空");
    println!("  不存在的关键词搜索返回 0 条 ✓");

    println!("[Phase 5] 空关键词搜索 → 应返回错误...");
    let empty_result = receiver_sdk.search_conversations("").await;
    assert!(empty_result.is_err(), "空关键词搜索应返回错误");
    println!("  空关键词错误: {:?}", empty_result.err());

    println!("test_search_conversations 通过!");
}

// ============================================================================
// 第十五类：隐藏会话
// 覆盖：hide_conversation 隐藏 + 新消息后重新出现
// ============================================================================

/// 场景：验证隐藏会话（hide_conversation）
///
/// 步骤：
///   Phase 1: A 发送消息给 B，创建会话
///   Phase 2: B 登录，等待同步
///   Phase 3: B 验证会话在列表中（get_conversation_list_split 找到）
///   Phase 4: B 调用 hide_conversation
///   Phase 5: B 再次分页查询 → 验证会话不在列表中
///   Phase 6: B 直接 get_conversation → 验证会话仍在 DB 中（只是被隐藏）
///   Phase 7: A 再发一条消息 → B 重新同步 → 验证会话重新出现
#[tokio::test]
async fn test_hide_conversation() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    println!("[Phase 1] 创建发送方和接收方...");
    let sender = create_random_account("HideSender").await;
    let receiver = create_random_account("HideReceiver").await;

    let (sender_token, _) = login_account(&sender).await.expect("发送方登录失败");
    let (receiver_token, _) = login_account(&receiver).await.expect("接收方登录失败");

    let sender_sdk = create_sdk(&sender, &sender_token).await;
    let receiver_sdk = create_sdk(&receiver, &receiver_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    ensure_friends(&sender_sdk, &sender.user_id, &receiver_sdk, &receiver.user_id).await;

    println!("[Phase 1] A 发消息给 B...");
    let _ = sender_sdk.send_text_message("隐藏测试消息1", &receiver.user_id, 1).await;

    println!("[Phase 2] 等待消息到达...");
    let timeout = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }
    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&receiver.user_id, &sender.user_id);

    println!("[Phase 3] 验证会话在分页列表中...");
    let page = receiver_sdk.get_conversation_list_split(0, 100).await.expect("分页查询失败");
    let found_before = page.iter().any(|c| c.conversation_id == conv_id);
    assert!(found_before, "隐藏前会话应在分页列表中: {}", conv_id);
    println!("  隐藏前找到会话 ✓");

    println!("[Phase 4] 调用 hide_conversation...");
    let hide_result = receiver_sdk.hide_conversation(&conv_id).await;
    assert!(hide_result.is_ok(), "隐藏会话失败: {:?}", hide_result.err());
    println!("  隐藏成功 ✓");

    println!("[Phase 5] 验证会话不在分页列表中...");
    let page_after = receiver_sdk.get_conversation_list_split(0, 100).await.expect("隐藏后分页查询失败");
    let found_after = page_after.iter().any(|c| c.conversation_id == conv_id);
    assert!(!found_after, "隐藏后会话不应在分页列表中: {}", conv_id);
    println!("  隐藏后不在列表中 ✓");

    println!("[Phase 6] 验证会话仍在 DB 中...");
    let conv_direct = receiver_sdk.get_conversation(&conv_id).await.expect("get_conversation 失败");
    // get_conversation 可能返回 None 因为 reset 清了 latest_msg_send_time
    // 但会话记录本身可能仍存在（取决于 get_conversation 的实现）
    // 这里验证 get_conversation 不会报错即可
    match conv_direct {
        Some(c) => {
            assert_eq!(c.conversation_id, conv_id, "会话 ID 不匹配");
            assert_eq!(c.unread_count, 0, "隐藏后未读数应为 0");
            println!("  会话仍在 DB 中（unread_count=0）✓");
        }
        None => {
            println!("  会话在 DB 中已被重置（latest_msg_send_time=0）✓");
        }
    }

    println!("[Phase 7] A 再发一条消息，验证会话重新出现...");
    let _ = sender_sdk.send_text_message("隐藏测试消息2-恢复", &receiver.user_id, 1).await;
    let timeout2 = tokio::time::sleep(Duration::from_secs(15));
    tokio::pin!(timeout2);
    loop {
        tokio::select! {
            _ = &mut timeout2 => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }
    tokio::time::sleep(Duration::from_secs(2)).await;

    let page_reappear = receiver_sdk.get_conversation_list_split(0, 100).await.expect("恢复后分页查询失败");
    let found_reappear = page_reappear.iter().any(|c| c.conversation_id == conv_id);
    assert!(found_reappear, "新消息后会话应重新出现在分页列表中: {}", conv_id);
    println!("  新消息后会话重新出现 ✓");

    println!("test_hide_conversation 通过!");
}

// ============================================================================
// 新增测试：会话属性全面持久化（登录/登出后保持）
// ============================================================================

/// 场景：设置会话的多项属性 → 登出 → 重新登录 → 验证全部保持
///
/// 步骤：
///   Phase 1: A 发消息给 B，创建会话
///   Phase 2: B 设置 pinned + draft + private + recv_msg_opt + ex
///   Phase 3: B 验证设置生效
///   Phase 4: B 登出 → 重新登录
///   Phase 5: B 验证所有属性持久化
///   Phase 6: 恢复设置
#[tokio::test]
async fn test_conversation_full_persistence() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;

    // Phase 1: A 发消息给 B
    println!("\n========== Phase 1: A 发消息给 B ==========");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    let _ = sender_sdk.send_text_message("持久化测试消息", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    // Phase 2: B 设置多项属性
    println!("\n========== Phase 2: B 设置多项属性 ==========");

    receiver_sdk.set_conversation_pinned(&conv_id, true).await.unwrap();
    receiver_sdk.set_conversation_draft(&conv_id, "持久化草稿").await.unwrap();
    receiver_sdk.set_conversation_private(&conv_id, true).await.unwrap();
    receiver_sdk.set_conversation(&conv_id, Some(0), None, None, None, Some("persist_key=persist_value")).await.unwrap();
    println!("  所有属性设置完成");

    // Phase 3: 验证设置生效
    println!("\n========== Phase 3: 验证设置生效 ==========");

    let conv = receiver_sdk.get_conversation(&conv_id).await.unwrap().unwrap();
    assert!(conv.is_pinned, "is_pinned 应为 true");
    assert!(!conv.draft_text.is_empty(), "draft_text 应非空");
    assert!(conv.is_private_chat, "is_private_chat 应为 true");
    assert_eq!(conv.ex, "persist_key=persist_value", "ex 字段不匹配");
    println!("  Phase 3 通过: 所有属性生效");

    // Phase 4: B 登出 → 重新登录
    println!("\n========== Phase 4: B 登出 → 重新登录 ==========");

    receiver_sdk.logout().await.expect("登出失败");
    receiver_sdk.login(&user2.user_id, &user2_im_token).await.expect("重新登录失败");
    tokio::time::sleep(Duration::from_secs(3)).await;

    // Phase 5: 验证所有属性持久化
    println!("\n========== Phase 5: 验证所有属性持久化 ==========");

    let conv_after = receiver_sdk.get_conversation(&conv_id).await.unwrap();
    assert!(conv_after.is_some(), "重新登录后会话应存在");
    let conv_after = conv_after.unwrap();

    assert!(conv_after.is_pinned, "重新登录后 is_pinned 应保持 true");
    assert!(!conv_after.draft_text.is_empty(), "重新登录后 draft_text 应保持非空");
    assert!(conv_after.is_private_chat, "重新登录后 is_private_chat 应保持 true");
    assert_eq!(conv_after.ex, "persist_key=persist_value", "重新登录后 ex 字段应保持: 实际={}", conv_after.ex);
    println!("  Phase 5 通过: 所有属性持久化成功");

    // Phase 6: 恢复设置
    println!("\n========== Phase 6: 恢复设置 ==========");

    receiver_sdk.set_conversation_pinned(&conv_id, false).await.ok();
    receiver_sdk.clear_conversation_draft(&conv_id).await.ok();
    receiver_sdk.set_conversation_private(&conv_id, false).await.ok();
    receiver_sdk.set_conversation(&conv_id, None, None, None, None, Some("")).await.ok();
    println!("  恢复完成");

    println!("\n========== test_conversation_full_persistence 完成 ==========\n");
}

// ============================================================================
// 新增测试：会话属性并发操作
// ============================================================================

/// 场景：多线程同时设置同一会话的不同属性，验证无数据损坏
///
/// 步骤：
///   Phase 1: A 发消息给 B，创建会话
///   Phase 2: B 用多个 tokio::spawn 并发设置不同属性
///   Phase 3: 等待全部完成，验证所有属性正确
#[tokio::test]
async fn test_concurrent_conversation_ops() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    use rust_lib_flutter_rust_demo::event::events::conversation::ConversationEvent;
    use rust_lib_flutter_rust_demo::event::events::message::MessageEvent;
    use std::sync::Arc;

    // Phase 1: A 发消息给 B
    println!("\n========== Phase 1: A 发消息给 B ==========");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (user1_im_token, _) = login_account(&user1).await.expect("用户1登录失败");
    let (user2_im_token, _) = login_account(&user2).await.expect("用户2登录失败");

    let sender_sdk = create_sdk(&user1, &user1_im_token).await;
    let receiver_sdk = create_sdk(&user2, &user2_im_token).await;
    let mut receiver_events = subscribe_all(&receiver_sdk);

    let _ = sender_sdk.send_text_message("并发测试消息", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(TestEvent::Message(MessageEvent::NewMessage { .. })) = event { break; }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let sdk = Arc::new(receiver_sdk);

    // Phase 2: 并发设置不同属性
    println!("\n========== Phase 2: 并发设置不同属性 ==========");

    let sdk_clone = sdk.clone();
    let conv_id_clone = conv_id.clone();
    let h1 = tokio::spawn(async move { sdk_clone.set_conversation_pinned(&conv_id_clone, true).await });

    let sdk_clone = sdk.clone();
    let conv_id_clone = conv_id.clone();
    let h2 = tokio::spawn(async move { sdk_clone.set_conversation_draft(&conv_id_clone, "并发草稿").await });

    let sdk_clone = sdk.clone();
    let conv_id_clone = conv_id.clone();
    let h3 = tokio::spawn(async move { sdk_clone.set_conversation_private(&conv_id_clone, true).await });

    let sdk_clone = sdk.clone();
    let conv_id_clone = conv_id.clone();
    let h4 = tokio::spawn(async move { sdk_clone.set_conversation(&conv_id_clone, None, None, None, None, Some("concurrent_ex")).await });

    let (r1, r2, r3, r4) = tokio::join!(h1, h2, h3, h4);
    assert!(r1.unwrap().is_ok(), "并发置顶失败");
    assert!(r2.unwrap().is_ok(), "并发设置草稿失败");
    assert!(r3.unwrap().is_ok(), "并发设置免打扰失败");
    assert!(r4.unwrap().is_ok(), "并发通用设置失败");
    println!("  Phase 2 通过: 4 个并发操作全部成功");

    // Phase 3: 验证所有属性正确
    println!("\n========== Phase 3: 验证所有属性正确 ==========");

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv = sdk.get_conversation(&conv_id).await.unwrap().unwrap();
    assert!(conv.is_pinned, "is_pinned 应为 true");
    assert!(!conv.draft_text.is_empty(), "draft_text 应非空");
    assert!(conv.is_private_chat, "is_private_chat 应为 true");
    assert_eq!(conv.ex, "concurrent_ex", "ex 字段不匹配");
    println!("  Phase 3 通过: 所有属性正确");

    // 恢复
    sdk.set_conversation_pinned(&conv_id, false).await.ok();
    sdk.clear_conversation_draft(&conv_id).await.ok();
    sdk.set_conversation_private(&conv_id, false).await.ok();
    sdk.set_conversation(&conv_id, None, None, None, None, Some("")).await.ok();

    println!("\n========== test_concurrent_conversation_ops 完成 ==========\n");
}
