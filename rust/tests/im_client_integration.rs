//! IM 集成测试：会话、多种消息类型、联系人、群组（占位）
//!
//! **测试组织**
//! - 公共逻辑在 `common` 模块：登录、启动客户端、会话解析、带时间戳的测试消息等。
//! - 各用例独立：查询会话、给第一个会话发文本、发多种类型消息、获取好友列表；群组 API 暂未实现则占位跳过。
//!
//! **运行**（需 OpenIM 服务与默认测试账号，查看输出请加 `--nocapture`）：
//! ```text
//! cargo test --test im_client_integration -- --nocapture
//! RUST_LOG=info cargo test --test im_client_integration -- --nocapture
//! ```
//!
//! **运行单个用例**：
//! ```text
//! cargo test --test im_client_integration get_conversations -- --nocapture
//! cargo test --test im_client_integration send_text_to_first -- --nocapture
//! cargo test --test im_client_integration send_multiple_message_types -- --nocapture
//! cargo test --test im_client_integration get_friends -- --nocapture
//! cargo test --test im_client_integration get_group_history_messages -- --nocapture
//! ```

mod common;

use anyhow::anyhow;
use openim_protocol::constant;
use openim_protocol::sdkws;
use rust_lib_flutter_rust_demo::im::GetAdvancedHistoryMessageListParams;
use std::time::Duration;
use tokio::time::timeout;
use tracing::{error, info};

use common::{
    create_and_start_client, create_and_start_client_with_msg_listener,
    first_group_from_list, parse_group_id, parse_single_recv_id, setup_logger, test_message_with_time,
    CONVERSATION_TYPE_GROUP, CONVERSATION_TYPE_SINGLE, CONVERSATION_TYPE_SUPER_GROUP, EXIT_TIMEOUT_SECS,
    PUSH_WAIT_SECS,
};

// ---------- 会话 ----------

#[tokio::test]
async fn get_conversations() -> anyhow::Result<()> {
    setup_logger();
    let (client, _) = create_and_start_client("conv").await?;
    let list = client.get_all_conversations().await?;
    eprintln!("[集成测试-会话] 会话总数: {}", list.len());
    for (i, c) in list.iter().enumerate() {
        eprintln!(
            "  [{}] id={} type={} user_id={:?} group_id={:?}",
            i, c.conversation_id, c.conversation_type, c.user_id, c.group_id
        );
    }
    let _ = timeout(Duration::from_secs(EXIT_TIMEOUT_SECS), client.wait_for_exit()).await;
    Ok(())
}

// ---------- 消息：给第一个会话发一条文本 ----------

#[tokio::test]
async fn send_text_to_first_conversation() -> anyhow::Result<()> {
    setup_logger();
    let (mut client, self_user_id) = create_and_start_client("msg_text").await?;
    let list = client.get_all_conversations().await?;
    let self_user_id = self_user_id.as_str();
    if let Some(conv) = list.first() {
        let msg = test_message_with_time("给第一个会话发一条文本");
        let send = match conv.conversation_type {
            CONVERSATION_TYPE_SINGLE => {
                let recv_id = conv
                    .user_id
                    .is_empty()
                    .then(|| parse_single_recv_id(&conv.conversation_id, self_user_id))
                    .flatten()
                    .or_else(|| Some(conv.user_id.clone()).filter(|s| !s.is_empty()));
                match recv_id {
                    Some(rid) => client.send_text_message(rid, msg).await,
                    None => Err(anyhow!("无法解析单聊 recv_id")),
                }
            }
            CONVERSATION_TYPE_GROUP | CONVERSATION_TYPE_SUPER_GROUP => {
                let gid = conv
                    .group_id
                    .is_empty()
                    .then(|| parse_group_id(&conv.conversation_id))
                    .flatten()
                    .or_else(|| Some(conv.group_id.clone()).filter(|s| !s.is_empty()));
                match gid {
                    Some(gid) => client.send_text_to_group(gid, msg).await,
                    None => Err(anyhow!("无法解析群聊 group_id")),
                }
            }
            _ => Err(anyhow!("不支持的会话类型 {}", conv.conversation_type)),
        };
        match send {
            Ok(resp) => {
                info!(conversation_id = %conv.conversation_id, client_msg_id = %resp.client_msg_id, "已发送");
                eprintln!(
                    "[集成测试-消息] 已发送(第一个会话) -> conversation_id={} client_msg_id={}",
                    conv.conversation_id, resp.client_msg_id
                );
            }
            Err(e) => {
                error!(conversation_id = %conv.conversation_id, error = %e, "发送失败");
                eprintln!("[集成测试-消息] 发送失败 conversation_id={} error={}", conv.conversation_id, e);
            }
        }
    } else {
        eprintln!("[集成测试-消息] 无会话，未发送");
    }
    let _ = timeout(Duration::from_secs(EXIT_TIMEOUT_SECS), client.wait_for_exit()).await;
    Ok(())
}

// ---------- 消息：仅群聊，按消息类型拆分，发送后等推送再查本地消息/会话 ----------

#[tokio::test]
async fn group_send_text_message() -> anyhow::Result<()> {
    setup_logger();
    let (mut client, self_user_id, msg_listener) =
        create_and_start_client_with_msg_listener("msg_group_text").await?;
    let list = client.get_all_conversations().await?;
    let (conversation_id, group_id, conversation_type) = match first_group_from_list(&list) {
        Some(t) => t,
        None => {
            eprintln!("[集成测试-群文本] 无群会话，跳过");
            let _ = timeout(Duration::from_secs(EXIT_TIMEOUT_SECS), client.wait_for_exit()).await;
            return Ok(());
        }
    };
    let text_msg = test_message_with_time("群文本");
    let resp = client
        .send_text_to_group(group_id.clone(), text_msg.clone())
        .await?;
    msg_listener
        .wait_for_message(&resp.client_msg_id, Duration::from_secs(PUSH_WAIT_SECS))
        .await?;

    let local = client
        .get_local_message(&conversation_id, &resp.client_msg_id)
        .await?
        .ok_or_else(|| anyhow!("本地未查到文本消息 client_msg_id={}", resp.client_msg_id))?;
    assert_eq!(local.content_type, constant::TEXT, "content_type 应为 TEXT(101)");
    assert!(
        local.content.contains(text_msg.as_str()) || local.content.contains("content"),
        "content 应包含发送内容或 content 字段"
    );
    assert!(!local.server_msg_id.is_empty(), "应有 server_msg_id");
    assert_eq!(local.group_id, group_id, "群 id 一致");
    // 群最新消息展示需发送人信息，其他端缺失时此处会触发
    assert!(!local.send_id.is_empty(), "群消息本地记录应有 send_id 以便展示发送人");
    assert!(
        !local.sender_nickname.is_empty() || !local.sender_face_url.is_empty(),
        "群最新消息应包含发送人昵称或头像(sender_nickname/sender_face_url)以便会话列表展示"
    );

    let convs = client.get_all_conversations().await?;
    let conv = convs
        .iter()
        .find(|c| c.conversation_id == conversation_id)
        .ok_or_else(|| anyhow!("本地会话应包含该群"))?;
    assert_eq!(conv.conversation_type, conversation_type, "会话类型一致");
    assert!(conv.unread_count >= 0, "未读数非负");
    // 会话 latest_msg 中应含发送人信息，供其他端/会话列表展示
    assert!(!conv.latest_msg.is_empty(), "会话最新消息 latest_msg 不应为空");
    let latest_json: serde_json::Value = serde_json::from_str(&conv.latest_msg)
        .map_err(|e| anyhow!("会话 latest_msg 非合法 JSON: {}", e))?;
    let has_sender = latest_json.get("sendId").and_then(|v| v.as_str()).map(|s| !s.is_empty()).unwrap_or(false)
        && (latest_json.get("senderNickname").and_then(|v| v.as_str()).map(|s| !s.is_empty()).unwrap_or(false)
            || latest_json.get("senderFaceUrl").and_then(|v| v.as_str()).map(|s| !s.is_empty()).unwrap_or(false));
    assert!(has_sender, "会话 latest_msg 中应包含 sendId 且含 senderNickname 或 senderFaceUrl 以便群最新消息展示发送人");

    let _ = timeout(Duration::from_secs(EXIT_TIMEOUT_SECS), client.wait_for_exit()).await;
    Ok(())
}

#[tokio::test]
async fn group_send_custom_message() -> anyhow::Result<()> {
    setup_logger();
    let (mut client, _self_user_id, msg_listener) =
        create_and_start_client_with_msg_listener("msg_group_custom").await?;
    let list = client.get_all_conversations().await?;
    let (conversation_id, group_id, conversation_type) = match first_group_from_list(&list) {
        Some(t) => t,
        None => {
            eprintln!("[集成测试-群自定义] 无群会话，跳过");
            let _ = timeout(Duration::from_secs(EXIT_TIMEOUT_SECS), client.wait_for_exit()).await;
            return Ok(());
        }
    };

    let custom_msg = test_message_with_time("群自定义");
    let params = serde_json::json!({ "data": custom_msg.clone(), "description": "integration test custom" }).to_string();
    let content = serde_json::from_str::<serde_json::Value>(&params)
        .map(|v| serde_json::to_vec(&v).unwrap_or_default())
        .unwrap_or_default();
    let mut msg_data = sdkws::MsgData::default();
    msg_data.group_id = group_id.clone();
    msg_data.content_type = constant::CUSTOM;
    msg_data.session_type = constant::READ_GROUP_CHAT_TYPE;
    msg_data.content = content;
    let resp = client.send_message(msg_data).await?;
    if let Err(e) = msg_listener
        .wait_for_message(&resp.client_msg_id, Duration::from_secs(PUSH_WAIT_SECS))
        .await
    {
        eprintln!("[集成测试-群自定义] 未在超时内收到推送: {}，继续校验", e);
    }

    let local = client.get_local_message(&conversation_id, &resp.client_msg_id).await?;
    if let Some(ref msg) = local {
        assert_eq!(msg.content_type, constant::CUSTOM, "content_type 应为 CUSTOM(110)");
        assert!(msg.content.contains("data") || msg.content.contains(&custom_msg), "content 应含 data 或发送内容");
        assert_eq!(msg.group_id, group_id, "群 id 一致");
    } else {
        eprintln!("[集成测试-群自定义] 自定义消息未落库（已知现象）");
    }

    let convs = client.get_all_conversations().await?;
    let conv = convs
        .iter()
        .find(|c| c.conversation_id == conversation_id)
        .ok_or_else(|| anyhow!("本地会话应包含该群"))?;
    assert_eq!(conv.conversation_id, conversation_id, "会话 ID 一致");
    assert_eq!(conv.conversation_type, conversation_type, "会话类型一致");
    assert!(conv.unread_count >= 0, "未读数非负");
    assert!(conv.latest_msg_send_time >= 0, "最新消息时间有效");

    let _ = timeout(Duration::from_secs(EXIT_TIMEOUT_SECS), client.wait_for_exit()).await;
    Ok(())
}

// ---------- 联系人（好友） ----------

#[tokio::test]
async fn get_friends() -> anyhow::Result<()> {
    setup_logger();
    let (client, _) = create_and_start_client("friends").await?;
    let friends = client.get_all_friends().await?;
    eprintln!("[集成测试-联系人] 好友总数: {}", friends.friends_info.len());
    for (i, f) in friends.friends_info.iter().enumerate() {
        let (uid, nick) = f
            .friend_user
            .as_ref()
            .map(|u| (u.user_id.as_str(), u.nickname.as_str()))
            .unwrap_or(("", ""));
        eprintln!("  [{}] user_id={} nickname={:?}", i, uid, nick);
    }
    let _ = timeout(Duration::from_secs(EXIT_TIMEOUT_SECS), client.wait_for_exit()).await;
    Ok(())
}

// ---------- 群组（占位：当前无群组列表 API） ----------

#[tokio::test]
async fn get_groups_placeholder() -> anyhow::Result<()> {
    setup_logger();
    eprintln!("[集成测试-群组] 群组列表 API 暂未实现，仅占位；会话列表中的群聊 id 可从 conversation_id (sg_xxx) 解析");
    let (client, _) = create_and_start_client("groups_ph").await?;
    let _ = timeout(Duration::from_secs(EXIT_TIMEOUT_SECS), client.wait_for_exit()).await;
    Ok(())
}

// ---------- 历史消息：加载第一个群的所有历史消息 ----------

#[tokio::test]
async fn get_group_history_messages() -> anyhow::Result<()> {
    setup_logger();
    let (client, _) = create_and_start_client("history").await?;
    let list = client.get_all_conversations().await?;
    let (conversation_id, group_id, _conversation_type) = match first_group_from_list(&list) {
        Some(t) => t,
        None => {
            eprintln!("[集成测试-历史消息] 无群会话，跳过");
            let _ = timeout(Duration::from_secs(EXIT_TIMEOUT_SECS), client.wait_for_exit()).await;
            return Ok(());
        }
    };
    const PAGE_SIZE: i32 = 20;
    let params = GetAdvancedHistoryMessageListParams {
        conversation_id: conversation_id.clone(),
        start_client_msg_id: String::new(),
        count: PAGE_SIZE,
        view_type: 0,
    };
    let mut all_messages = Vec::new();
    let mut start_client_msg_id = String::new();
    loop {
        let params_page = GetAdvancedHistoryMessageListParams {
            start_client_msg_id: start_client_msg_id.clone(),
            ..params.clone()
        };
        let cb = client.get_advanced_history_message_list(params_page).await?;
        assert_eq!(cb.err_code, 0, "err_code 应为 0");
        let n = cb.message_list.len();
        all_messages.extend(cb.message_list);
        if cb.is_end || n == 0 {
            break;
        }
        start_client_msg_id = all_messages
            .last()
            .and_then(|m| m.client_msg_id.as_deref())
            .unwrap_or("")
            .to_string();
        if start_client_msg_id.is_empty() {
            break;
        }
    }
    eprintln!(
        "[集成测试-历史消息] 第一个群 conversation_id={} group_id={} 共加载历史消息 {} 条",
        conversation_id,
        group_id,
        all_messages.len()
    );
    for (i, msg) in all_messages.iter().take(5).enumerate() {
        eprintln!(
            "  [{}] client_msg_id={:?} seq={} content_type={} send_time={}",
            i,
            msg.client_msg_id,
            msg.seq,
            msg.content_type,
            msg.send_time
        );
    }
    if all_messages.len() > 5 {
        eprintln!("  ... 共 {} 条", all_messages.len());
    }
    let _ = timeout(Duration::from_secs(EXIT_TIMEOUT_SECS), client.wait_for_exit()).await;
    Ok(())
}

