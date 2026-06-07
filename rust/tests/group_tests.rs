mod common;

use common::*;
use rust_lib_flutter_rust_demo::domain::constant::enums::GroupType;
use std::time::Duration;

#[tokio::test]
async fn test_create_group() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 创建群组测试 ===\n");

    let account = get_or_create_group_owner().await;
    let (im_token, _) = login_account(&account).await.expect("登录失败");
    let sdk = create_sdk(&account, &im_token).await;

    let group_name = format!("TestGroup_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());

    let result = sdk.create_group(
        &group_name,
        GroupType::Normal,
        &vec![account.user_id.clone()],
    ).await;

    assert!(result.is_ok(), "创建群组失败: {:?}", result.err());
    let group = result.unwrap();
    assert!(!group.group_id.is_empty(), "群组ID不应为空");
    println!("  ✅ 创建成功: {} ({})", group.group_name, group.group_id);
    println!("✅ 创建群组测试完成");
}

#[tokio::test]
async fn test_join_and_quit_group() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 加入/退出群组测试 ===\n");

    let account1 = get_or_create_group_owner().await;
    let account2 = get_or_create_group_member1().await;
    let (im_token1, _) = login_account(&account1).await.expect("登录失败");
    let (im_token2, _) = login_account(&account2).await.expect("登录失败");

    let sdk1 = create_sdk(&account1, &im_token1).await;
    let sdk2 = create_sdk(&account2, &im_token2).await;

    let group_name = format!("JQGroup_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    let group = sdk1.create_group(
        &group_name, GroupType::Normal,
        &vec![account1.user_id.clone()],
    ).await.expect("创建群组失败");
    println!("群组: {}", group.group_id);

    println!("用户2申请加入...");
    let join_result = sdk2.join_group(&group.group_id, None).await;
    assert!(join_result.is_ok(), "加入群组失败: {:?}", join_result.err());
    println!("  ✅ 加入成功");
    tokio::time::sleep(Duration::from_secs(1)).await;

    println!("用户1邀请用户2...");
    let invite_result = sdk1.invite_group_members(&group.group_id, &vec![account2.user_id.clone()], None).await;
    assert!(invite_result.is_ok(), "邀请失败: {:?}", invite_result.err());
    println!("  ✅ 邀请成功");

    println!("用户2退出群组...");
    let quit_result = sdk2.quit_group(&group.group_id).await;
    assert!(quit_result.is_ok(), "退出失败: {:?}", quit_result.err());
    println!("  ✅ 退出成功");

    println!("✅ 加入/退出群组测试完成");
}

#[tokio::test]
async fn test_group_member_management() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 群成员管理测试 ===\n");

    let account = get_or_create_group_owner().await;
    let (im_token, _) = login_account(&account).await.expect("登录失败");
    let sdk = create_sdk(&account, &im_token).await;

    let group = sdk.create_group(
        "MemberTestGroup", GroupType::Normal,
        &vec![account.user_id.clone()],
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

    // 获取群主和管理员
    println!("获取群主和管理员...");
    let owner_admin = sdk.get_group_member_owner_and_admin(&group.group_id).await;
    match &owner_admin {
        Ok(members) => {
            println!("  群主/管理员数: {}", members.len());
            for m in members {
                println!("    {} (role={})", m.user_id, m.role_level);
            }
        }
        Err(e) => println!("  ⚠ 失败: {:?}", e),
    }

    // 按入群时间过滤群成员
    println!("按入群时间过滤群成员...");
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;
    let filtered = sdk.get_group_member_list_by_join_time_filter(
        &group.group_id, 0, 10, 0, now, vec![],
    ).await;
    match &filtered {
        Ok(members) => {
            println!("  时间范围内成员数: {}", members.len());
            assert!(!members.is_empty(), "应有成员在时间范围内");
        }
        Err(e) => println!("  ⚠ 失败: {:?}", e),
    }

    // 检查用户是否在群中
    println!("检查用户是否在群中...");
    let users_check = sdk.get_users_in_group(
        &group.group_id,
        vec![account.user_id.clone(), "nonexistent_user".to_string()],
    ).await;
    println!("  在群中的用户: {:?}", users_check);
    assert!(users_check.contains(&account.user_id), "群主应在群中");
    assert!(!users_check.contains(&"nonexistent_user".to_string()), "不存在的用户不应在群中");

    // 设置群成员信息
    println!("设置群成员信息...");
    let member_info_result = sdk.set_group_member_info(
        &group.group_id,
        &account.user_id,
        Some("新昵称"),
        None,
        None,
        None,
    ).await;
    match &member_info_result {
        Ok(_) => println!("  ✅ 设置成功"),
        Err(e) => println!("  ⚠ 失败: {:?}", e),
    }

    // 搜索群成员
    println!("搜索群成员...");
    let search_members = sdk.search_group_members(&group.group_id, &account.user_id).await;
    println!("  搜索结果: {} 个", search_members.len());

    println!("✅ 群成员管理测试完成");
}

#[tokio::test]
async fn test_group_info_update() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 群信息更新测试 ===\n");

    let account = get_or_create_group_owner().await;
    let (im_token, _) = login_account(&account).await.expect("登录失败");
    let sdk = create_sdk(&account, &im_token).await;

    let group = sdk.create_group(
        "InfoTestGroup", GroupType::Normal,
        &vec![account.user_id.clone()],
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
async fn test_user_state_group_management() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 群组管理测试 ===\n");

    let account = get_or_create_group_owner().await;
    let (im_token, _) = login_account(&account).await.expect("登录失败");
    let sdk = create_sdk(&account, &im_token).await;

    let group_name = format!("UGroup_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    let result = sdk.create_group(
        &group_name, GroupType::Normal,
        &vec![account.user_id.clone()],
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
async fn test_group_application_flow() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 群组申请/审批流程测试 ===\n");

    let account1 = get_or_create_group_owner().await;
    let account2 = get_or_create_group_applicant().await;
    let (im_token1, _) = login_account(&account1).await.expect("登录失败");
    let (im_token2, _) = login_account(&account2).await.expect("登录失败");

    let sdk1 = create_sdk(&account1, &im_token1).await;
    let sdk2 = create_sdk(&account2, &im_token2).await;

    let group_name = format!("GAppGroup_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    let group = sdk1.create_group(
        &group_name, GroupType::Normal,
        &vec![account1.user_id.clone()],
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
    let accept_result = sdk1.accept_group_application(&group.group_id, &account2.user_id, Some("同意加入")).await;
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

    // 申请人视角的群组申请列表
    println!("用户2获取申请人视角的群组申请列表...");
    let applicant_list = sdk2.get_group_application_list_as_applicant().await;
    match &applicant_list {
        Ok(list) => {
            println!("  申请人列表: {} 条", list.len());
            for info in list {
                println!("    群组: {} state={}", info.group_id, info.handle_result);
            }
        }
        Err(e) => println!("  ⚠ 失败: {:?}", e),
    }

    println!("✅ 群组申请流程测试完成");
}

#[tokio::test]
async fn test_group_dismiss_and_transfer() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 群组解散与转让测试 ===\n");

    use rust_lib_flutter_rust_demo::domain::constant::enums::GroupType;

    let account1 = get_or_create_group_owner().await;
    let account2 = get_or_create_group_member1().await;
    let (im_token1, _) = login_account(&account1).await.expect("登录失败");
    let (im_token2, _) = login_account(&account2).await.expect("登录失败");

    let sdk1 = create_sdk(&account1, &im_token1).await;
    let sdk2 = create_sdk(&account2, &im_token2).await;

    // 创建群组
    let group_name = format!("DismissTransfer_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    let group = sdk1.create_group(
        &group_name, GroupType::Normal,
        &vec![account1.user_id.clone()],
    ).await.expect("创建群组失败");
    println!("群组: {} ({})", group.group_name, group.group_id);

    // 邀请 account2
    sdk1.invite_group_members(&group.group_id, &vec![account2.user_id.clone()], None).await.expect("邀请失败");
    tokio::time::sleep(Duration::from_secs(2)).await;

    // 转让群主
    println!("转让群主...");
    let transfer_result = sdk1.transfer_group_owner(&group.group_id, &account2.user_id).await;
    match &transfer_result {
        Ok(_) => println!("  ✅ 转让成功"),
        Err(e) => println!("  ⚠ 转让失败: {:?}", e),
    }

    if transfer_result.is_ok() {
        tokio::time::sleep(Duration::from_secs(1)).await;

        // 验证新群主
        let members = sdk1.get_group_members(&group.group_id).await.unwrap();
        let new_owner = members.iter().find(|m| m.user_id == account2.user_id);
        if let Some(owner) = new_owner {
            println!("  新群主 role_level: {}", owner.role_level);
        }

        // 新群主解散群组
        println!("新群主解散群组...");
        let dismiss_result = sdk2.dismiss_group(&group.group_id).await;
        match &dismiss_result {
            Ok(_) => println!("  ✅ 解散成功"),
            Err(e) => println!("  ⚠ 解散失败: {:?}", e),
        }
    } else {
        // 转让失败则直接测试解散
        println!("转让失败，直接测试群主解散...");
        let dismiss_result = sdk1.dismiss_group(&group.group_id).await;
        match &dismiss_result {
            Ok(_) => println!("  ✅ 解散成功"),
            Err(e) => println!("  ⚠ 解散失败: {:?}", e),
        }
    }

    println!("✅ 群组解散与转让测试完成");
}

#[tokio::test]
async fn test_group_mute_operations() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 群组禁言测试 ===\n");

    use rust_lib_flutter_rust_demo::domain::constant::enums::GroupType;

    let account1 = get_or_create_group_owner().await;
    let account2 = get_or_create_group_member1().await;
    let (im_token1, _) = login_account(&account1).await.expect("登录失败");
    let (im_token2, _) = login_account(&account2).await.expect("登录失败");

    let sdk1 = create_sdk(&account1, &im_token1).await;
    let sdk2 = create_sdk(&account2, &im_token2).await;

    // 创建群组
    let group_name = format!("MuteTest_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    let group = sdk1.create_group(
        &group_name, GroupType::Normal,
        &vec![account1.user_id.clone()],
    ).await.expect("创建群组失败");
    println!("群组: {} ({})", group.group_name, group.group_id);

    // 邀请 account2
    sdk1.invite_group_members(&group.group_id, &vec![account2.user_id.clone()], None).await.expect("邀请失败");
    tokio::time::sleep(Duration::from_secs(2)).await;

    // 全员禁言
    println!("开启全员禁言...");
    let mute_result = sdk1.mute_group(&group.group_id, true).await;
    match &mute_result {
        Ok(_) => println!("  ✅ 全员禁言开启"),
        Err(e) => println!("  ⚠ 失败: {:?}", e),
    }

    // 单成员禁言（60秒）
    println!("设置单成员禁言（60秒）...");
    let member_mute_result = sdk1.mute_group_member(&group.group_id, &account2.user_id, 60).await;
    match &member_mute_result {
        Ok(_) => println!("  ✅ 单成员禁言设置成功"),
        Err(e) => println!("  ⚠ 失败: {:?}", e),
    }

    // 取消全员禁言
    println!("取消全员禁言...");
    let unmute_result = sdk1.mute_group(&group.group_id, false).await;
    match &unmute_result {
        Ok(_) => println!("  ✅ 全员禁言取消"),
        Err(e) => println!("  ⚠ 失败: {:?}", e),
    }

    println!("✅ 群组禁言测试完成");
}
