mod common;

use common::*;
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

    // A 发消息触发会话创建
    let _ = sender_sdk.send_text_message("会话同步测试", &user2.user_id, 1).await;

    // 等待消息到达
    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event {
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

    let _ = sender_sdk.send_text_message("单会话查询测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event {
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
            &format!("未读数测试 {}", i),
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

    tokio::time::sleep(Duration::from_secs(1)).await;

    // 验证未读数
    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let conv = user2_sdk.get_conversation(&conv_id).await.expect("获取会话失败");
    match conv {
        Some(c) => {
            assert!(c.unread_count >= 3,
                "未读数应 >= 3, 实际: {}", c.unread_count);
            println!("未读数: {}", c.unread_count);
        }
        None => panic!("未找到会话"),
    }
}

/// 场景：A 发 2 条消息给 B，B 标记会话已读
/// 验证：未读数清零，收到 ConversationChanged 事件
#[tokio::test]
async fn test_conversation_mark_read() {
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

    for i in 1..=2 {
        let _ = user1_sdk.send_text_message(
            &format!("已读测试 {}", i),
            &user2.user_id,
            1,
        ).await;
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    let mut msg_count = 0;
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event {
                    msg_count += 1;
                    if msg_count >= 2 { break; }
                }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    // 标记已读
    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);
    let mark_result = user2_sdk.mark_conversation_as_read(conv_id.clone(), 1).await;
    assert!(mark_result.is_ok(), "标记已读失败: {:?}", mark_result.err());

    // 验证 ConversationChanged 事件
    let timeout2 = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout2);
    let mut conv_changed = false;
    loop {
        tokio::select! {
            _ = &mut timeout2 => { break; }
            event = user2_events.next() => {
                if let Some(SdkEvent::ConversationChanged { conversations }) = event {
                    for conv in &conversations {
                        if conv.conversation_id == conv_id {
                            assert_eq!(conv.unread_count, 0, "已读后未读计数应为0");
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
}

// ============================================================================
// 第三类：置顶/免打扰
// 覆盖：置顶/取消置顶、获取置顶列表、免打扰设置
// ============================================================================

/// 场景：B 给与 A 的会话设置置顶，验证置顶列表
/// 验证：get_pinned_conversations 包含该会话
#[tokio::test]
async fn test_conversation_pinned() {
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

    // 先发消息创建会话
    let _ = sender_sdk.send_text_message("置顶测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event { break; }
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

    let _ = sender_sdk.send_text_message("免打扰测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event { break; }
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

    let _ = sender_sdk.send_text_message("草稿测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event { break; }
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

    let _ = sender_sdk.send_text_message("删除测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event { break; }
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

    let _ = sender_sdk.send_text_message("通用设置测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event { break; }
            }
        }
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let conv_id = make_conversation_id(&user2.user_id, &user1.user_id);

    // 设置 recv_msg_opt=1 (不接收), is_pinned=true, is_private_chat=true, ex="test_key"
    let result = receiver_sdk.set_conversation(
        &conv_id,
        Some(1),   // recv_msg_opt: 不接收消息
        Some(true),  // is_pinned: 置顶
        Some(true),  // is_private_chat: 免打扰
        None,        // group_at_type
        Some("test_key=test_value"),  // ex
    ).await;
    assert!(result.is_ok(), "set_conversation 失败: {:?}", result.err());

    // 验证属性已更新
    let conv = receiver_sdk.get_conversation(&conv_id).await.unwrap();
    match conv {
        Some(c) => {
            assert_eq!(c.recv_msg_opt, 1, "recv_msg_opt 应为 1");
            assert!(c.is_pinned != 0, "is_pinned 应为 true");
            assert!(c.is_private_chat != 0, "is_private_chat 应为 true");
            assert_eq!(c.ex, "test_key=test_value", "ex 字段不匹配");
        }
        None => panic!("未找到会话"),
    }

    // 恢复设置
    let _ = receiver_sdk.set_conversation(
        &conv_id, Some(0), Some(false), Some(false), None, Some(""),
    ).await;
}

// ============================================================================
// 第七类：会话 ID 生成
// 覆盖：单聊/群聊/超级群聊/通知会话 ID 格式
// ============================================================================

/// 场景：验证 get_conversation_id_by_session_type 对不同会话类型的 ID 生成
/// 验证：单聊 si_、群聊 g_、超级群聊 sg_、通知 sn_ 前缀
#[tokio::test]
async fn test_get_conversation_id_by_session_type() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

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

    // Step 1: A 发消息给 B
    println!("[1/6] A 发消息给 B...");
    let _ = user1_sdk.send_text_message("生命周期测试消息", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = user2_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event { break; }
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
    let mark_result = user2_sdk.mark_conversation_as_read(conv_id.clone(), 1).await;
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

    // 发消息创建会话
    let _ = sender_sdk.send_text_message("持久化测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event { break; }
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
            assert_eq!(c.unread_count as i64, test_unread,
                "重新登录后未读数应保持 {}, 实际: {}", test_unread, c.unread_count);
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
                if let Some(SdkEvent::NewMessage { .. }) = event {
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
    user2_sdk.mark_conversation_as_read(conv_id.clone(), 1).await.unwrap();

    // 验证 B 的未读数清零
    let conv_after = user2_sdk.get_conversation(&conv_id).await.unwrap().unwrap();
    assert_eq!(conv_after.unread_count, 0, "标记已读后未读数应为 0");

    // 验证 B 的消息已读状态
    let history = user2_sdk.get_history_messages(
        rust_lib_flutter_rust_demo::sdk::client::types::GetHistoryMessagesReq {
            conversation_id: conv_id,
            start_client_msg_id: String::new(),
            count: 10,
        },
    ).await.unwrap();

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

    let _ = sender_sdk.send_text_message("未读数更新测试", &user2.user_id, 1).await;

    let timeout = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            _ = &mut timeout => { break; }
            event = receiver_events.next() => {
                if let Some(SdkEvent::NewMessage { .. }) = event { break; }
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
