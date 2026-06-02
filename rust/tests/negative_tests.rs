
mod common;

use common::*;
use std::time::Duration;

#[tokio::test]
#[ignore]
async fn test_register_with_existing_phone() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 重复注册测试 ===\n");

    let phone = generate_virtual_phone("dup");
    let cert1 = register_user(&phone, "DupUser1").await.expect("首次注册失败");
    println!("  首次注册成功: user_id={}", cert1.user_id);

    let result = register_user(&phone, "DupUser2").await;
    assert!(result.is_err(), "重复注册应该返回错误");
    println!("  重复注册被拒绝: {}", result.err().unwrap());

    println!("✅ 重复注册测试完成");
}

#[tokio::test]
#[ignore]
async fn test_login_invalid_token() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::config::ClientConfig;
    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;

    println!("=== 无效 token 登录测试 ===\n");

    let user = get_or_create_user1().await;

    let config = ClientConfig::new(
        user.user_id.clone(),
        "invalid_token_12345".to_string(),
        1,
        Some(WS_URL.to_string()),
        Some(API_BASE_URL.to_string()),
        Some(std::env::temp_dir().join(format!("invalid_token_{}", user.user_id)).to_string_lossy().to_string()),
    );

    let sdk = OpenIMClient::new(config).await.expect("SDK 创建失败");

    let result = sdk
        .connect(WS_URL, "invalid_token_12345", &user.user_id)
        .await;
    assert!(result.is_err(), "使用无效 token 连接应该失败");
    println!("  无效 token 连接被拒绝: {:?}", result.err());

    println!("✅ 无效 token 登录测试完成");
}

#[tokio::test]
#[ignore]
async fn test_duplicate_add_friend() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 重复添加好友测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let result = sdk.add_friend(&user2.user_id, Some("第一次添加")).await;
    assert!(result.is_ok(), "第一次添加好友应该成功: {:?}", result.err());
    println!("  第一次添加好友成功");

    tokio::time::sleep(Duration::from_secs(2)).await;

    let result = sdk.add_friend(&user2.user_id, Some("重复添加")).await;
    println!("  重复添加好友结果: {:?}", result);

    println!("✅ 重复添加好友测试完成");
}

#[tokio::test]
#[ignore]
async fn test_delete_non_existent_friend() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 删除不存在的好友测试 ===\n");

    let user1 = get_or_create_user1().await;
    let user2 = get_or_create_user2().await;

    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let is_friend = sdk.is_friend(&user2.user_id).await;
    println!("  好友关系检查: {}", if is_friend { "是好友" } else { "不是好友" });

    if !is_friend {
        let result = sdk.delete_friend(&user2.user_id).await;
        println!("  删除非好友结果: {:?}", result);
    } else {
        println!("  user2 是好友，先删除");
        let _ = sdk.delete_friend(&user2.user_id).await;
        let result = sdk.delete_friend(&user2.user_id).await;
        println!("  再次删除结果: {:?}", result);
    }

    println!("✅ 删除不存在的好友测试完成");
}

#[tokio::test]
#[ignore]
async fn test_send_message_to_nonexistent_user() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 向不存在用户发消息测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let result = sdk.send_text_message("发给不存在用户", "nonexistent_user_99999", 1).await;

    if let Err(e) = &result {
        println!("  发送失败（符合预期）: {:?}", e);
    } else {
        println!("  发送成功（服务端可能允许向不存在用户发消息）");
    }

    println!("✅ 向不存在用户发消息测试完成");
}

#[tokio::test]
#[ignore]
async fn test_kick_nonexistent_group_member() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    use rust_lib_flutter_rust_demo::domain::constant::enums::GroupType;

    println!("=== 踢不存在群成员测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let group = sdk
        .create_group("KickTestGroup", GroupType::Normal, &[user1.user_id.clone()])
        .await
        .expect("创建群组失败");
    println!("  群组创建成功: group_id={}", group.group_id);

    let result = sdk
        .kick_group_members(&group.group_id, &["nonexistent_member_999".to_string()], Some("踢不存在的人"))
        .await;

    assert!(result.is_err(), "踢不存在群成员应该失败");
    println!("  踢不存在成员被拒绝: {:?}", result.err());

    println!("✅ 踢不存在群成员测试完成");
}

#[tokio::test]
#[ignore]
async fn test_join_nonexistent_group() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 加入不存在群组测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let result = sdk.join_group("nonexistent_group_99999", Some("测试加入不存在群组")).await;
    assert!(result.is_err(), "加入不存在群组应该失败");
    println!("  加入不存在群组被拒绝: {:?}", result.err());

    println!("✅ 加入不存在群组测试完成");
}

#[tokio::test]
#[ignore]
async fn test_set_conversation_draft_empty() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 设置空草稿测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let convs = sdk.get_conversations().await.unwrap_or_default();
    if convs.is_empty() {
        println!("  无会话，跳过");
        return;
    }

    let conv_id = &convs[0].conversation_id;
    println!("  设置空字符串草稿到会话: {}", conv_id);

    let result = sdk.set_conversation_draft(conv_id, "").await;
    assert!(result.is_ok(), "设置空草稿应该成功: {:?}", result.err());
    println!("  空草稿设置成功");

    println!("✅ 设置空草稿测试完成");
}
