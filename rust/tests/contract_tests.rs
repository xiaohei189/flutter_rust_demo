//! 真实服务端契约对齐冒烟测试。
//!
//! mock 层只验证 SDK 逻辑，不能证明请求/响应与服务端一致；
//! 本套件用真实 OpenIM 服务端验证各域代表性 client API，默认忽略、按需运行。

mod common;

use common::*;
use rust_lib_flutter_rust_demo::client::GetHistoryMessagesReq;
use rust_lib_flutter_rust_demo::client::*;
use rust_lib_flutter_rust_demo::constant::enums::GroupType;
use std::time::Duration;

fn make_conversation_id(uid1: &str, uid2: &str) -> String {
    let mut ids = vec![uid1.to_string(), uid2.to_string()];
    ids.sort();
    format!("si_{}_{}", ids[0], ids[1])
}

#[tokio::test]
#[ignore = "requires docker OpenIM server; run via scripts/test-contract.ps1"]
async fn client_api_contract_smoke() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::DEBUG).with_target(false).try_init();

    println!("=== 真实服务端契约冒烟 ===\n");

    let user_a = create_random_account("ContractA").await;
    let user_b = create_random_account("ContractB").await;
    let (a_token, _) = login_account(&user_a).await.expect("A 登录失败");
    let (b_token, _) = login_account(&user_b).await.expect("B 登录失败");
    let a_sdk = create_sdk(&user_a, &a_token).await;
    let b_sdk = create_sdk(&user_b, &b_token).await;

    // user + online status
    assert!(a_sdk.get_users_info(&[user_a.user_id.clone()]).await.is_ok());
    assert!(a_sdk.get_user_status(&[user_a.user_id.clone()]).await.is_ok());
    assert!(a_sdk.subscribe_users_status(vec![user_b.user_id.clone()]).await.is_ok());
    assert!(a_sdk.get_subscribe_users_status().await.is_ok());
    assert!(a_sdk.unsubscribe_users_status(vec![user_b.user_id.clone()]).await.is_ok());
    println!("  ✅ user/online 契约通过");

    // friend
    ensure_friends(&a_sdk, &user_a.user_id, &b_sdk, &user_b.user_id).await;
    assert!(a_sdk.is_friend(&user_b.user_id).await);
    assert!(!a_sdk.get_friend_list().await.is_empty());
    println!("  ✅ friend 契约通过");

    // message + conversation
    let msg = a_sdk.send_text_message("contract smoke", &user_b.user_id, 1).await.expect("发送消息失败");
    tokio::time::sleep(Duration::from_secs(2)).await;
    let conv_id = make_conversation_id(&user_a.user_id, &user_b.user_id);
    let history = a_sdk
        .get_history_messages(GetHistoryMessagesReq {
            conversation_id: conv_id.clone(),
            start_client_msg_id: String::new(),
            count: 20,
        })
        .await
        .expect("查询历史失败");
    assert!(history.messages.iter().any(|m| m.client_msg_id == msg.client_msg_id));
    assert!(a_sdk.get_conversations().await.expect("获取会话失败").iter().any(|c| c.conversation_id == conv_id));
    println!("  ✅ message/conversation 契约通过");

    // group
    let group = a_sdk.create_group("ContractGroup", GroupType::Normal, &[user_a.user_id.clone()]).await.expect("创建群组失败");
    assert!(!group.group_id.is_empty());
    assert!(a_sdk.get_groups_info(&[group.group_id.clone()]).await.is_ok());
    assert!(a_sdk.dismiss_group(&group.group_id).await.is_ok());
    println!("  ✅ group 契约通过");

    println!("✅ 真实服务端契约冒烟完成");
}
