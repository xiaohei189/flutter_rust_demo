mod common;

use common::*;
use rust_lib_flutter_rust_demo::domain::constant::enums::GroupType;
use std::time::Duration;

#[tokio::test]
#[ignore]
async fn test_create_group() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 创建群组测试 ===\n");

    let phone = generate_virtual_phone("cgrp");
    let cert = register_user(&phone, "CreateGroupUser").await.expect("注册失败");
    println!("用户: {}", cert.user_id);

    let sdk = create_sdk(&TestAccount {
        user_id: cert.user_id.clone(),
        phone,
        nickname: "CreateGroupUser".into(),
        im_token: Some(cert.im_token.clone()),
        chat_token: None,
    }, &cert.im_token).await;

    let group_name = format!("TestGroup_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());

    let result = sdk.create_group(
        &group_name,
        GroupType::Normal,
        &vec![cert.user_id.clone()],
    ).await;

    assert!(result.is_ok(), "创建群组失败: {:?}", result.err());
    let group = result.unwrap();
    assert!(!group.group_id.is_empty(), "群组ID不应为空");
    println!("  ✅ 创建成功: {} ({})", group.group_name, group.group_id);
    println!("✅ 创建群组测试完成");
}

#[tokio::test]
#[ignore]
async fn test_join_and_quit_group() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 加入/退出群组测试 ===\n");

    let phone1 = generate_virtual_phone("jq1");
    let phone2 = generate_virtual_phone("jq2");

    let cert1 = register_user(&phone1, "JQUser1").await.expect("注册失败");
    let cert2 = register_user(&phone2, "JQUser2").await.expect("注册失败");

    let sdk1 = create_sdk(&TestAccount {
        user_id: cert1.user_id.clone(), phone: phone1, nickname: "JQUser1".into(),
        im_token: Some(cert1.im_token.clone()), chat_token: None,
    }, &cert1.im_token).await;

    let sdk2 = create_sdk(&TestAccount {
        user_id: cert2.user_id.clone(), phone: phone2, nickname: "JQUser2".into(),
        im_token: Some(cert2.im_token.clone()), chat_token: None,
    }, &cert2.im_token).await;

    let group_name = format!("JQGroup_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    let group = sdk1.create_group(
        &group_name, GroupType::Normal,
        &vec![cert1.user_id.clone()],
    ).await.expect("创建群组失败");
    println!("群组: {}", group.group_id);

    println!("用户2申请加入...");
    let join_result = sdk2.join_group(&group.group_id, None).await;
    assert!(join_result.is_ok(), "加入群组失败: {:?}", join_result.err());
    println!("  ✅ 加入成功");
    tokio::time::sleep(Duration::from_secs(1)).await;

    println!("用户1邀请用户2...");
    let invite_result = sdk1.invite_group_members(&group.group_id, &vec![cert2.user_id.clone()], None).await;
    assert!(invite_result.is_ok(), "邀请失败: {:?}", invite_result.err());
    println!("  ✅ 邀请成功");

    println!("用户2退出群组...");
    let quit_result = sdk2.quit_group(&group.group_id).await;
    assert!(quit_result.is_ok(), "退出失败: {:?}", quit_result.err());
    println!("  ✅ 退出成功");

    println!("✅ 加入/退出群组测试完成");
}

#[tokio::test]
#[ignore]
async fn test_group_member_management() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 群成员管理测试 ===\n");

    let phone = generate_virtual_phone("gmem");
    let cert = register_user(&phone, "GMemUser").await.expect("注册失败");

    let sdk = create_sdk(&TestAccount {
        user_id: cert.user_id.clone(), phone, nickname: "GMemUser".into(),
        im_token: Some(cert.im_token.clone()), chat_token: None,
    }, &cert.im_token).await;

    let group = sdk.create_group(
        "MemberTestGroup", GroupType::Normal,
        &vec![cert.user_id.clone()],
    ).await.expect("创建群组失败");

    println!("获取群成员...");
    let members_result = sdk.get_group_members(&group.group_id).await;
    assert!(members_result.is_ok(), "获取群成员失败: {:?}", members_result.err());
    let members = members_result.unwrap();
    assert!(!members.is_empty(), "群成员列表不应为空");
    println!("  成员数: {}", members.len());

    println!("获取群成员 ID 列表...");
    let ids_result = sdk.get_group_members(&group.group_id).await;
    assert!(ids_result.is_ok(), "获取群成员失败: {:?}", ids_result.err());
    let ids = ids_result.unwrap().into_iter().map(|m| m.user_id).collect::<Vec<_>>();
    assert!(!ids.is_empty(), "群成员 ID 列表不应为空");
    println!("  成员 ID 数: {}", ids.len());

    println!("✅ 群成员管理测试完成");
}

#[tokio::test]
#[ignore]
async fn test_group_info_update() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 群信息更新测试 ===\n");

    let phone = generate_virtual_phone("ginf");
    let cert = register_user(&phone, "GInfoUser").await.expect("注册失败");

    let sdk = create_sdk(&TestAccount {
        user_id: cert.user_id.clone(), phone, nickname: "GInfoUser".into(),
        im_token: Some(cert.im_token.clone()), chat_token: None,
    }, &cert.im_token).await;

    let group = sdk.create_group(
        "InfoTestGroup", GroupType::Normal,
        &vec![cert.user_id.clone()],
    ).await.expect("创建失败");
    println!("群: {} ({})", group.group_name, group.group_id);

    println!("更新群名称...");
    let set_result = sdk.set_group_info(&group.group_id, Some("UpdatedName"), None).await;
    assert!(set_result.is_ok(), "更新群信息失败: {:?}", set_result.err());
    println!("  ✅ 更新成功");

    println!("获取群信息...");
    let get_result = sdk.get_groups_info(&vec![group.group_id.clone()]).await;
    assert!(get_result.is_ok(), "获取群信息失败: {:?}", get_result.err());
    let info = get_result.unwrap();
    let first = info.first().expect("群信息不应为空");
    assert_eq!(first.group_name, "UpdatedName", "群名称应为 UpdatedName");
    println!("  群名称: {}", first.group_name);

    println!("✅ 群信息更新测试完成");
}

#[tokio::test]
#[ignore]
async fn test_group_list_sync() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 群列表同步测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    let groups = sdk.get_group_list().await;
    println!("已加入群组数: {}", groups.len());
    println!("✅ 群列表同步测试完成");
}

#[tokio::test]
#[ignore]
async fn test_user_state_group_management() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 群组管理测试 ===\n");

    let phone = generate_virtual_phone("ugrp");
    let nickname = format!("UGroupUser_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());

    println!("注册用户...");
    let cert = register_user(&phone, &nickname).await.expect("注册失败");
    println!("用户: {}", cert.user_id);

    use rust_lib_flutter_rust_demo::domain::config::ClientConfig;
    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;

    let data_dir = std::env::temp_dir().join(format!("ugrp_{}", cert.user_id)).to_string_lossy().to_string();
    let _ = std::fs::create_dir_all(&data_dir);

    let sdk = OpenIMClient::new(ClientConfig::new(
        cert.user_id.clone(), cert.im_token.clone(), 1,
        Some(WS_URL.into()), Some(API_BASE_URL.into()), Some(data_dir),
    )).await.unwrap();
    sdk.connect(WS_URL, &cert.im_token, &cert.user_id).await.unwrap();
    tokio::time::sleep(Duration::from_secs(2)).await;

    let group_name = format!("UGroup_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    let result = sdk.create_group(
        &group_name, GroupType::Normal,
        &vec![cert.user_id.clone()],
    ).await;

    assert!(result.is_ok(), "创建群组失败: {:?}", result.err());
    let group = result.unwrap();
    assert!(!group.group_id.is_empty(), "群组ID不应为空");
    println!("  ✅ 群组创建成功: {} ({})", group.group_name, group.group_id);

    let groups = sdk.get_group_list().await;
    println!("群组数量: {}", groups.len());
    println!("✅ 群组管理测试完成");
}

#[tokio::test]
#[ignore]
async fn test_group_application_flow() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 群组申请/审批流程测试 ===\n");

    use rust_lib_flutter_rust_demo::domain::config::ClientConfig;
    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;

    let phone1 = generate_virtual_phone("gapp1");
    let phone2 = generate_virtual_phone("gapp2");

    let cert1 = register_user(&phone1, "GAppOwner").await.expect("注册失败");
    let cert2 = register_user(&phone2, "GAppUser").await.expect("注册失败");

    let data_dir1 = std::env::temp_dir().join(format!("gapp_{}", cert1.user_id)).to_string_lossy().to_string();
    let data_dir2 = std::env::temp_dir().join(format!("gapp_{}", cert2.user_id)).to_string_lossy().to_string();
    let _ = std::fs::create_dir_all(&data_dir1);
    let _ = std::fs::create_dir_all(&data_dir2);

    let sdk1 = OpenIMClient::new(ClientConfig::new(
        cert1.user_id.clone(), cert1.im_token.clone(), 1,
        Some(WS_URL.into()), Some(API_BASE_URL.into()), Some(data_dir1),
    )).await.unwrap();
    sdk1.login(&cert1.user_id, &cert1.im_token).await.unwrap();
    tokio::time::sleep(Duration::from_secs(2)).await;

    let sdk2 = OpenIMClient::new(ClientConfig::new(
        cert2.user_id.clone(), cert2.im_token.clone(), 1,
        Some(WS_URL.into()), Some(API_BASE_URL.into()), Some(data_dir2),
    )).await.unwrap();
    sdk2.login(&cert2.user_id, &cert2.im_token).await.unwrap();
    tokio::time::sleep(Duration::from_secs(2)).await;

    let group_name = format!("GAppGroup_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    let group = sdk1.create_group(
        &group_name, GroupType::Normal,
        &vec![cert1.user_id.clone()],
    ).await.expect("创建群组失败");
    println!("群组: {}", group.group_id);

    println!("用户2申请加入群组...");
    let join_result = sdk2.join_group(&group.group_id, None).await;
    assert!(join_result.is_ok(), "申请加入群组失败: {:?}", join_result.err());
    println!("  ✅ 申请成功");
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("用户1获取群组申请列表...");
    let app_list_result = sdk1.get_group_application_list().await;
    assert!(app_list_result.is_ok(), "获取申请列表失败: {:?}", app_list_result.err());
    let app_list = app_list_result.unwrap();
    println!("  ✅ 申请数: {}", app_list.len());

    println!("用户1审批用户2的申请...");
    let accept_result = sdk1.accept_group_application(&group.group_id, &cert2.user_id).await;
    assert!(accept_result.is_ok(), "审批失败: {:?}", accept_result.err());
    println!("  ✅ 同意申请");
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("验证成员列表...");
    let members_result = sdk1.get_group_members(&group.group_id).await;
    assert!(members_result.is_ok(), "获取成员列表失败: {:?}", members_result.err());
    let members = members_result.unwrap();
    println!("  成员数: {} (期望 >= 2)", members.len());
    assert!(members.len() >= 2, "成员数应 >= 2");
    for m in &members {
        println!("    - {} ({})", m.nickname, m.user_id);
    }

    println!("✅ 群组申请流程测试完成");
}
