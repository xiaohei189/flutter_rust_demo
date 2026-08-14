//! 真实服务端契约对齐测试。
//!
//! mock 层只验证 SDK 逻辑，不能证明请求/响应与服务端一致；
//! 本套件用真实 OpenIM 服务端验证各域代表性 client API，默认忽略、按需运行。
//! 同时校验 `tests/fixtures/` 中 mock 响应的字段结构没有被服务端协议变更破坏。

mod common;

use common::*;
use rust_lib_flutter_rust_demo::client::GetHistoryMessagesReq;
use rust_lib_flutter_rust_demo::client::*;
use rust_lib_flutter_rust_demo::constant::enums::GroupType;
use serde_json::Value;
use std::time::Duration;

/// 按字典序生成单聊会话 ID：`si_{小user_id}_{大user_id}`。
fn make_conversation_id(uid1: &str, uid2: &str) -> String {
    let mut ids = [uid1.to_string(), uid2.to_string()];
    ids.sort();
    format!("si_{}_{}", ids[0], ids[1])
}

/// 直接调用真实服务端 HTTP API，返回完整响应 JSON（含 errCode/errMsg/data 信封）。
async fn raw_post_json(route: &str, token: &str, body: serde_json::Value) -> Value {
    let client = reqwest::Client::new();
    let resp = client
        .post(format!("{}{}", API_BASE_URL, route))
        .header("token", token)
        .header("operationID", "fixture_drift")
        .json(&body)
        .send()
        .await
        .expect("真实服务端请求失败");
    assert!(resp.status().is_success(), "HTTP 状态非 2xx: {}", resp.status());
    resp.json().await.expect("真实服务端响应 JSON 解析失败")
}

/// 轮询等待本地会话出现，避免固定 sleep 导致时序脆弱。
/// 服务端会话创建可能晚于发送 RPC 返回，因此每轮先增量同步再检查。
async fn wait_for_conversation(sdk: &OpenIMClient, conversation_id: &str, timeout_secs: u64) -> bool {
    let deadline = tokio::time::Instant::now() + Duration::from_secs(timeout_secs);
    loop {
        if sdk.incr_sync_conversations().await.is_ok() {
            if let Ok(convs) = sdk.get_conversations().await {
                if convs.iter().any(|c| c.conversation_id == conversation_id) {
                    return true;
                }
            }
        }
        if tokio::time::Instant::now() >= deadline {
            return false;
        }
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}

/// 轮询等待历史消息中出现指定 client_msg_id。
async fn wait_for_message_in_history(sdk: &OpenIMClient, conversation_id: &str, client_msg_id: &str, timeout_secs: u64) -> bool {
    let deadline = tokio::time::Instant::now() + Duration::from_secs(timeout_secs);
    loop {
        if let Ok(history) = sdk
            .get_history_messages(GetHistoryMessagesReq {
                conversation_id: conversation_id.to_string(),
                start_client_msg_id: String::new(),
                count: 50,
            })
            .await
        {
            if history.messages.iter().any(|m| m.client_msg_id == client_msg_id) {
                return true;
            }
        }
        if tokio::time::Instant::now() >= deadline {
            return false;
        }
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}

/// 校验 fixture 中出现的每个字段（含嵌套对象）都仍存在于真实响应中。
/// 数组只比较首元素结构，避免真实数据为空时误报。
fn assert_fixture_keys_covered(fixture: &Value, live: &Value, path: &str) {
    match (fixture, live) {
        (Value::Object(f), Value::Object(l)) => {
            for key in f.keys() {
                let live_value = l.get(key).unwrap_or_else(|| panic!("fixture 字段在真实响应中缺失: {} . {}", path, key));
                assert_fixture_keys_covered(&f[key], live_value, &format!("{}.{}", path, key));
            }
        }
        (Value::Array(fa), Value::Array(la)) => {
            if let (Some(fe), Some(le)) = (fa.first(), la.first()) {
                assert_fixture_keys_covered(fe, le, &format!("{}[0]", path));
            }
        }
        _ => {}
    }
}

/// 验证真实服务端 user/online 域代表性 API 契约。
#[tokio::test]
#[ignore = "requires docker OpenIM server; run via scripts/test-contract.ps1"]
async fn user_online_contract() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::INFO).with_target(false).try_init();

    let user_a = create_random_account("ContractA").await;
    let user_b = create_random_account("ContractB").await;
    let (a_token, _) = login_account(&user_a).await.expect("A 登录失败");
    let (b_token, _) = login_account(&user_b).await.expect("B 登录失败");
    let a_sdk = create_sdk(&user_a, &a_token).await;
    let _b_sdk = create_sdk(&user_b, &b_token).await;

    assert!(a_sdk.get_users_info(std::slice::from_ref(&user_a.user_id)).await.is_ok());
    assert!(a_sdk.get_user_status(std::slice::from_ref(&user_a.user_id)).await.is_ok());
    assert!(a_sdk.subscribe_users_status(vec![user_b.user_id.clone()]).await.is_ok());
    assert!(a_sdk.get_subscribe_users_status().await.is_ok());
    assert!(a_sdk.unsubscribe_users_status(vec![user_b.user_id.clone()]).await.is_ok());
    println!("✅ user/online 契约通过");
}

/// 验证真实服务端好友域契约（加好友、好友列表、好友关系检查）。
#[tokio::test]
#[ignore = "requires docker OpenIM server; run via scripts/test-contract.ps1"]
async fn friend_contract() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::INFO).with_target(false).try_init();

    let user_a = create_random_account("ContractA").await;
    let user_b = create_random_account("ContractB").await;
    let (a_token, _) = login_account(&user_a).await.expect("A 登录失败");
    let (b_token, _) = login_account(&user_b).await.expect("B 登录失败");
    let a_sdk = create_sdk(&user_a, &a_token).await;
    let b_sdk = create_sdk(&user_b, &b_token).await;

    ensure_friends(&a_sdk, &user_a.user_id, &b_sdk, &user_b.user_id).await;
    assert!(a_sdk.is_friend(&user_b.user_id).await);
    assert!(!a_sdk.get_friend_list().await.is_empty());
    println!("✅ friend 契约通过");
}

/// 验证真实服务端消息发送、历史查询与会话契约。
#[tokio::test]
#[ignore = "requires docker OpenIM server; run via scripts/test-contract.ps1"]
async fn message_conversation_contract() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::INFO).with_target(false).try_init();

    let user_a = create_random_account("ContractA").await;
    let user_b = create_random_account("ContractB").await;
    let (a_token, _) = login_account(&user_a).await.expect("A 登录失败");
    let (b_token, _) = login_account(&user_b).await.expect("B 登录失败");
    let a_sdk = create_sdk(&user_a, &a_token).await;
    let _b_sdk = create_sdk(&user_b, &b_token).await;

    let msg = a_sdk.send_text_message("contract smoke", &user_b.user_id, 1).await.expect("发送消息失败");
    let conv_id = make_conversation_id(&user_a.user_id, &user_b.user_id);
    assert!(wait_for_message_in_history(&a_sdk, &conv_id, &msg.client_msg_id, 10).await, "历史中应能找到已发送消息");
    assert!(wait_for_conversation(&a_sdk, &conv_id, 10).await, "发送并同步后应存在本地会话");
    println!("✅ message/conversation 契约通过");
}

/// 验证真实服务端群组创建、查询与解散契约。
#[tokio::test]
#[ignore = "requires docker OpenIM server; run via scripts/test-contract.ps1"]
async fn group_contract() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::INFO).with_target(false).try_init();

    let user_a = create_random_account("ContractA").await;
    let (a_token, _) = login_account(&user_a).await.expect("A 登录失败");
    let a_sdk = create_sdk(&user_a, &a_token).await;

    let group = a_sdk
        .create_group("ContractGroup", GroupType::Normal, std::slice::from_ref(&user_a.user_id))
        .await
        .expect("创建群组失败");
    assert!(!group.group_id.is_empty());
    assert!(a_sdk.get_groups_info(std::slice::from_ref(&group.group_id)).await.is_ok());
    assert!(a_sdk.dismiss_group(&group.group_id).await.is_ok());
    println!("✅ group 契约通过");
}

/// 用真实服务端响应校验所有 JSON fixtures 的字段结构仍与服务端一致。
#[tokio::test]
#[ignore = "requires docker OpenIM server; run via scripts/test-contract.ps1"]
async fn fixture_drift_contract() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::INFO).with_target(false).try_init();

    let user_a = create_random_account("ContractA").await;
    let user_b = create_random_account("ContractB").await;
    let (a_token, _) = login_account(&user_a).await.expect("A 登录失败");
    let (b_token, _) = login_account(&user_b).await.expect("B 登录失败");
    let a_sdk = create_sdk(&user_a, &a_token).await;
    let b_sdk = create_sdk(&user_b, &b_token).await;

    // 播种数据，保证列表类 fixture 能在真实响应中找到同结构样本
    ensure_friends(&a_sdk, &user_a.user_id, &b_sdk, &user_b.user_id).await;
    a_sdk.add_black(&user_b.user_id).await.expect("添加黑名单失败");
    a_sdk.send_text_message("fixture drift", &user_b.user_id, 1).await.expect("发送消息失败");
    tokio::time::sleep(Duration::from_secs(2)).await;
    let group = a_sdk
        .create_group("FixtureGroup", GroupType::Normal, std::slice::from_ref(&user_a.user_id))
        .await
        .expect("创建群组失败");

    let friend_live = raw_post_json(
        "/friend/get_friend_list",
        &a_token,
        serde_json::json!({"userID": user_a.user_id, "pagination": {"pageNumber": 1, "showNumber": 100}}),
    )
    .await;
    let conversation_live = raw_post_json("/conversation/get_all_conversations", &a_token, serde_json::json!({"ownerUserID": user_a.user_id})).await;
    let conversation_inc_live = raw_post_json(
        "/conversation/get_incremental_conversations",
        &a_token,
        serde_json::json!({"userID": user_a.user_id, "versionID": "", "version": 0}),
    )
    .await;
    let group_live = raw_post_json(
        "/group/get_joined_group_list",
        &a_token,
        serde_json::json!({"fromUserID": user_a.user_id, "pagination": {"pageNumber": 1, "showNumber": 100}}),
    )
    .await;
    let group_inc_live = raw_post_json(
        "/group/get_incremental_join_groups",
        &a_token,
        serde_json::json!({"userID": user_a.user_id, "versionID": "", "version": 0}),
    )
    .await;
    let user_status_live = raw_post_json("/user/get_users_status", &a_token, serde_json::json!({"userIDs": [user_a.user_id]})).await;
    let black_list_live = raw_post_json(
        "/friend/get_black_list",
        &a_token,
        serde_json::json!({"userID": user_a.user_id, "pagination": {"pageNumber": 1, "showNumber": 100}}),
    )
    .await;
    let group_members_live = raw_post_json(
        "/group/get_group_member_list",
        &a_token,
        serde_json::json!({"groupID": group.group_id, "filter": 0, "pagination": {"pageNumber": 1, "showNumber": 100}}),
    )
    .await;
    let server_time_live = raw_post_json("/msg/get_server_time", &a_token, serde_json::json!({})).await;

    // 列表必须有样本，否则嵌套结构校验会退化为只查信封
    assert!(friend_live["data"]["friendsInfo"].as_array().is_some_and(|a| !a.is_empty()), "好友列表为空，无法校验 fixture 嵌套结构");
    assert!(
        conversation_live["data"]["conversations"].as_array().is_some_and(|a| !a.is_empty()),
        "会话列表为空，无法校验 fixture 嵌套结构"
    );
    assert!(group_live["data"]["groups"].as_array().is_some_and(|a| !a.is_empty()), "群组列表为空，无法校验 fixture 嵌套结构");
    assert!(black_list_live["data"]["blacks"].as_array().is_some_and(|a| !a.is_empty()), "黑名单为空，无法校验 fixture 嵌套结构");
    assert!(group_members_live["data"]["members"].as_array().is_some_and(|a| !a.is_empty()), "群成员为空，无法校验 fixture 嵌套结构");

    let checks: Vec<(&str, &str, Value)> = vec![
        ("friend_list.json", include_str!("fixtures/friend_list.json"), friend_live),
        ("conversation_list.json", include_str!("fixtures/conversation_list.json"), conversation_live),
        ("conversation_incremental.json", include_str!("fixtures/conversation_incremental.json"), conversation_inc_live),
        ("group_list.json", include_str!("fixtures/group_list.json"), group_live),
        ("group_incremental.json", include_str!("fixtures/group_incremental.json"), group_inc_live),
        ("user_status.json", include_str!("fixtures/user_status.json"), user_status_live),
        ("black_list.json", include_str!("fixtures/black_list.json"), black_list_live),
        ("group_members.json", include_str!("fixtures/group_members.json"), group_members_live),
        ("server_time.json", include_str!("fixtures/server_time.json"), server_time_live.clone()),
        ("api_ok.json", include_str!("fixtures/api_ok.json"), server_time_live.clone()),
        ("api_error.json", include_str!("fixtures/api_error.json"), server_time_live),
    ];
    for (name, fixture_raw, live) in checks {
        let fixture: Value = serde_json::from_str(fixture_raw).unwrap_or_else(|e| panic!("解析 fixture {} 失败: {}", name, e));
        assert_fixture_keys_covered(&fixture, &live, name);
        println!("  ✅ {} 结构对齐", name);
    }

    a_sdk.remove_black(&user_b.user_id).await.expect("移除黑名单失败");
    assert!(a_sdk.dismiss_group(&group.group_id).await.is_ok());
    println!("✅ fixture 结构对齐校验通过");
}
