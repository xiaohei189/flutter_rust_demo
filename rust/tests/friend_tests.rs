mod common;

use common::*;
use std::time::Duration;

#[tokio::test]
#[ignore]
async fn test_add_friend() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 添加好友测试 ===\n");

    let phone1 = generate_virtual_phone("addf1");
    let phone2 = generate_virtual_phone("addf2");

    let cert1 = register_user(&phone1, "AddFriendUser1").await.expect("注册失败");
    let cert2 = register_user(&phone2, "AddFriendUser2").await.expect("注册失败");

    println!("用户1: {}, 用户2: {}", cert1.user_id, cert2.user_id);

    let sdk = create_sdk(&TestAccount {
        user_id: cert1.user_id.clone(),
        phone: phone1,
        nickname: "AddFriendUser1".into(),
        im_token: Some(cert1.im_token.clone()),
        chat_token: None,
    }, &cert1.im_token).await;

    println!("添加好友...");
    match sdk.add_friend(cert2.user_id.clone(), Some("Hello!".into())).await {
        Ok(_) => println!("  ✅ 好友申请发送成功"),
        Err(e) => println!("  ⚠️ 失败: {:?}", e),
    }

    let is_friend = sdk.is_friend(&cert2.user_id).await;
    println!("是否好友: {}", is_friend);
    println!("✅ 添加好友测试完成");
}

#[tokio::test]
#[ignore]
async fn test_delete_friend() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 删除好友测试 ===\n");

    let phone1 = generate_virtual_phone("delf1");
    let phone2 = generate_virtual_phone("delf2");

    let cert1 = register_user(&phone1, "DelFriendUser1").await.expect("注册失败");
    let cert2 = register_user(&phone2, "DelFriendUser2").await.expect("注册失败");

    println!("用户1: {}, 用户2: {}", cert1.user_id, cert2.user_id);

    let sdk = create_sdk(&TestAccount {
        user_id: cert1.user_id.clone(),
        phone: phone1,
        nickname: "DelFriendUser1".into(),
        im_token: Some(cert1.im_token.clone()),
        chat_token: None,
    }, &cert1.im_token).await;

    println!("添加好友...");
    let _ = sdk.add_friend(cert2.user_id.clone(), Some("Add me".into())).await;
    tokio::time::sleep(Duration::from_secs(1)).await;

    println!("删除好友...");
    match sdk.delete_friend(cert2.user_id.clone()).await {
        Ok(_) => println!("  ✅ 删除成功"),
        Err(e) => println!("  ⚠️ 失败: {:?}", e),
    }

    println!("✅ 删除好友测试完成");
}

#[tokio::test]
#[ignore]
async fn test_blacklist_management() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 黑名单管理测试 ===\n");

    let phone1 = generate_virtual_phone("blk1");
    let phone2 = generate_virtual_phone("blk2");

    let cert1 = register_user(&phone1, "BlackUser1").await.expect("注册失败");
    let cert2 = register_user(&phone2, "BlackUser2").await.expect("注册失败");

    let sdk = create_sdk(&TestAccount {
        user_id: cert1.user_id.clone(),
        phone: phone1,
        nickname: "BlackUser1".into(),
        im_token: Some(cert1.im_token.clone()),
        chat_token: None,
    }, &cert1.im_token).await;

    let initial = sdk.get_black_list().await;
    println!("初始黑名单: {}", initial.len());

    println!("拉黑用户...");
    match sdk.add_black(cert2.user_id.clone()).await {
        Ok(_) => println!("  ✅ 拉黑成功"),
        Err(e) => println!("  ⚠️ 失败: {:?}", e),
    }

    tokio::time::sleep(Duration::from_secs(1)).await;

    let after_add = sdk.get_black_list().await;
    println!("拉黑后数量: {}", after_add.len());

    println!("移出黑名单...");
    match sdk.remove_black(cert2.user_id.clone()).await {
        Ok(_) => println!("  ✅ 移出成功"),
        Err(e) => println!("  ⚠️ 失败: {:?}", e),
    }

    println!("✅ 黑名单管理测试完成");
}

#[tokio::test]
#[ignore]
async fn test_friend_list_sync() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 好友列表同步测试 ===\n");

    let user1 = get_or_create_user1().await;
    let (im_token, _) = login_account(&user1).await.expect("登录失败");
    let sdk = create_sdk(&user1, &im_token).await;

    println!("获取好友列表...");
    let friends = sdk.get_friend_list().await;
    println!("好友数量: {}", friends.len());

    println!("获取好友 ID 列表...");
    let ids = sdk.get_friend_id_list().await;
    println!("好友 ID 数量: {}", ids.len());

    println!("✅ 好友列表同步测试完成");
}

#[tokio::test]
#[ignore]
async fn test_user_state_friend_management() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    let phone1 = generate_virtual_phone("uf1");
    let phone2 = generate_virtual_phone("uf2");

    println!("注册用户...");
    let cert1 = register_user(&phone1, "UFriend1").await.expect("注册失败");
    let cert2 = register_user(&phone2, "UFriend2").await.expect("注册失败");

    println!("用户1: {}, 用户2: {}", cert1.user_id, cert2.user_id);

    use rust_lib_flutter_rust_demo::domain::config::ClientConfig;
    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;

    let data_dir = std::env::temp_dir()
        .join(format!("openim_test_uf_{}", cert1.user_id))
        .to_string_lossy()
        .to_string();
    let _ = std::fs::create_dir_all(&data_dir);

    let config = ClientConfig::new(
        cert1.user_id.clone(),
        cert1.im_token.clone(),
        1,
        Some(WS_URL.to_string()),
        Some(API_BASE_URL.to_string()),
        Some(data_dir),
    );
    let sdk = OpenIMClient::new(config).await.expect("创建 SDK 失败");
    sdk.connect(WS_URL, &cert1.im_token, &cert1.user_id).await.expect("连接失败");
    tokio::time::sleep(Duration::from_secs(2)).await;

    let friends = sdk.get_friend_list().await;
    println!("好友数量: {}", friends.len());
    assert!(friends.is_empty(), "新用户应该没有好友");

    let _ = sdk.add_friend(cert2.user_id.clone(), Some("Hello!".into())).await;
    println!("✅ 好友管理测试完成");
}

#[tokio::test]
#[ignore]
async fn test_friend_application_flow() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .try_init();

    println!("=== 好友申请/接受/拒绝完整流程测试 ===\n");

    use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;
    use rust_lib_flutter_rust_demo::domain::config::ClientConfig;

    let phone1 = generate_virtual_phone("fapp1");
    let phone2 = generate_virtual_phone("fapp2");

    let cert1 = register_user(&phone1, "FApp1").await.expect("注册失败");
    let cert2 = register_user(&phone2, "FApp2").await.expect("注册失败");

    let data_dir1 = std::env::temp_dir().join(format!("fapp_{}", cert1.user_id)).to_string_lossy().to_string();
    let data_dir2 = std::env::temp_dir().join(format!("fapp_{}", cert2.user_id)).to_string_lossy().to_string();
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

    println!("用户1申请添加用户2...");
    let result = sdk1.add_friend(cert2.user_id.clone(), Some("Add me".into())).await;
    match &result {
        Ok(_) => println!("  ✅ 申请已发送"),
        Err(e) => println!("  ❌ 失败: {:?}", e),
    }
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("用户2获取好友申请列表...");
    let apply_resp = sdk2.get_friend_apply_list().await;
    match &apply_resp {
        Ok(resp) => {
            let infos = resp;
            assert!(!infos.is_empty(), "应有好友申请");
            for info in infos {
                println!("  申请: {} - {}", info.nickname, info.req_msg.as_deref().unwrap_or("无"));
            }
        }
        Err(e) => println!("  ❌ 获取失败: {:?}", e),
    }

    println!("用户2接受申请...");
    match sdk2.accept_friend_application(cert1.user_id.clone(), None).await {
        Ok(_) => println!("  ✅ 接受成功"),
        Err(e) => println!("  ❌ 失败: {:?}", e),
    }
    tokio::time::sleep(Duration::from_secs(2)).await;

    println!("验证好友关系...");
    let friends1 = sdk1.get_friend_list().await;
    let friends2 = sdk2.get_friend_list().await;
    let has1 = friends1.iter().any(|f| f.user_id == cert2.user_id);
    let has2 = friends2.iter().any(|f| f.user_id == cert1.user_id);
    println!("用户1-用户2: {} (期望 true)", has1);
    println!("用户2-用户1: {} (期望 true)", has2);

    println!("\n=== 拒绝测试 ===");
    let phone3 = generate_virtual_phone("fapp3");
    let cert3 = register_user(&phone3, "FApp3").await.expect("注册失败");
    let _ = sdk1.add_friend(cert3.user_id.clone(), Some("Hello".into())).await;
    tokio::time::sleep(Duration::from_secs(2)).await;

    match sdk1.refuse_friend_application(cert3.user_id.clone(), None).await {
        Ok(_) => println!("  ✅ 拒绝成功"),
        Err(e) => println!("  ❌ 失败: {:?}", e),
    }

    println!("\n=== 好友申请流程测试完成 ===");
}
