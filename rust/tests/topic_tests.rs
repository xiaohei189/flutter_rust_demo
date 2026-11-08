mod common;

use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
use common::*;
use rust_lib_flutter_rust_demo::core::event::events::message::MessageEvent;
use rust_lib_flutter_rust_demo::domain::constant::enums::GroupType;
use rust_lib_flutter_rust_demo::domain::model::message::MessageInfo;
use rust_lib_flutter_rust_demo::domain::model::msg_struct::{MsgStruct, PictureBaseInfo};
use rust_lib_flutter_rust_demo::sdk::client::*;
use serde_json::Value;
use std::time::Duration;

async fn raw_post_json(route: &str, token: &str, body: Value) -> Value {
    let response = reqwest::Client::new()
        .post(format!("{}{}", API_BASE_URL, route))
        .header("token", token)
        .header(
            "operationID",
            format!("topic_test_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()),
        )
        .json(&body)
        .send()
        .await
        .expect("话题 API 请求失败");
    assert!(response.status().is_success());
    response.json().await.expect("话题 API 响应不是 JSON")
}

async fn wait_for_topic(token: &str, group_id: &str, topic_id: &str, timeout: Duration) -> Value {
    let deadline = tokio::time::Instant::now() + timeout;
    loop {
        let response = raw_post_json("/topic/get_topic", token, serde_json::json!({"groupID": group_id, "topicID": topic_id})).await;
        if response["errCode"].as_i64() == Some(0) {
            return response["data"].clone();
        }
        if tokio::time::Instant::now() >= deadline {
            panic!("等待话题投影超时: {response}");
        }
        tokio::time::sleep(Duration::from_millis(300)).await;
    }
}

async fn wait_for_local_topic_message(sdk: &OpenIMClient, conversation_id: &str, client_msg_id: &str, topic_id: &str, timeout: Duration) -> MessageInfo {
    let deadline = tokio::time::Instant::now() + timeout;
    loop {
        if let Ok(history) = sdk
            .get_history_messages(GetHistoryMessagesReq {
                conversation_id: conversation_id.to_string(),
                start_client_msg_id: String::new(),
                count: 100,
            })
            .await
        {
            if let Some(message) = history.messages.into_iter().find(|message| message.client_msg_id == client_msg_id) {
                assert_eq!(message.topic_id, topic_id);
                return message;
            }
        }
        if tokio::time::Instant::now() >= deadline {
            panic!("等待本地消息 topic_id 落库超时: {client_msg_id}");
        }
        tokio::time::sleep(Duration::from_millis(300)).await;
    }
}

fn topic_event_action(message: &MessageInfo) -> String {
    let Ok(outer) = serde_json::from_str::<Value>(&message.content) else {
        return String::new();
    };
    let Some(data) = outer.get("data").and_then(Value::as_str) else {
        return String::new();
    };
    let Ok(event) = serde_json::from_str::<Value>(data) else {
        return String::new();
    };
    event.get("action").and_then(Value::as_str).unwrap_or_default().to_string()
}

#[tokio::test]
#[ignore = "requires docker OpenIM server; run via scripts/test-integration.ps1 -Suite topic_tests"]
async fn topic_group_sdk_end_to_end() {
    let _ = tracing_subscriber::fmt().with_max_level(tracing::Level::INFO).with_target(false).try_init();

    let owner = create_random_account("TopicOwner").await;
    let member = create_random_account("TopicMember").await;
    let (owner_token, _) = login_account(&owner).await.expect("群主登录失败");
    let (member_token, _) = login_account(&member).await.expect("成员登录失败");
    let owner_sdk = create_sdk(&owner, &owner_token).await;
    let member_sdk = create_sdk(&member, &member_token).await;

    let ex = r#"{"openim_topic":{"mode":2,"modeSinceSeq":0,"version":1}}"#;
    let group = owner_sdk
        .create_group("Topic SDK E2E", GroupType::Normal, std::slice::from_ref(&member.user_id), Some(ex))
        .await
        .expect("创建话题群失败");
    assert!(group.ex.contains("\"openim_topic\""));

    let mut root = MsgStruct::create_text_message("SDK 真实话题根消息");
    root.session_type = 3;
    root.topic_id = root.client_msg_id.clone();
    let root = owner_sdk.send_msg(root, &group.group_id, None).await.expect("发送话题根消息失败");
    let root_id = root.client_msg_id.clone();
    assert_eq!(root.topic_id, root_id);

    let topic = wait_for_topic(&owner_token, &group.group_id, &root_id, Duration::from_secs(15)).await;
    assert_eq!(topic["topic"]["rootClientMsgID"], root_id);

    let mut reply = MsgStruct::create_text_message("SDK 真实话题回复");
    reply.session_type = 3;
    reply.topic_id = root_id.clone();
    let reply = member_sdk.send_msg(reply, &group.group_id, None).await.expect("发送话题回复失败");
    assert_eq!(reply.topic_id, root_id);

    let topic = wait_for_topic(&member_token, &group.group_id, &root_id, Duration::from_secs(15)).await;
    let deadline = tokio::time::Instant::now() + Duration::from_secs(15);
    let topic = loop {
        if topic["topic"]["replyCount"].as_i64() == Some(1) {
            break topic;
        }
        if tokio::time::Instant::now() >= deadline {
            panic!("话题回复聚合超时: {topic}");
        }
        tokio::time::sleep(Duration::from_millis(300)).await;
        let live = wait_for_topic(&member_token, &group.group_id, &root_id, Duration::from_secs(5)).await;
        if live["topic"]["replyCount"].as_i64() == Some(1) {
            break live;
        }
    };
    assert_eq!(topic["topic"]["replyCount"], 1);
    let replies = raw_post_json("/topic/get_topic_replies", &member_token, serde_json::json!({"topicID": root_id, "beforeSeq": 0, "count": 30})).await;
    assert_eq!(replies["errCode"], 0);
    assert_eq!(replies["data"]["replies"][0]["message"]["topicID"], root_id);
    let summary = raw_post_json("/topic/get_group_topic_summaries", &member_token, serde_json::json!({"groupIDs": [group.group_id]})).await;
    assert_eq!(summary["errCode"], 0);
    assert_eq!(summary["data"]["summaries"][0]["topicCount"], 1);
    assert_eq!(summary["data"]["summaries"][0]["unreadTopicCount"], 1);
    assert_eq!(summary["data"]["summaries"][0]["latestActivityPreview"], "SDK 真实话题回复");
    let marked = raw_post_json("/topic/mark_group_topics_read", &member_token, serde_json::json!({"groupID": group.group_id})).await;
    assert_eq!(marked["errCode"], 0);
    assert_eq!(marked["data"]["updatedCount"], 1);
    let summary = raw_post_json("/topic/get_group_topic_summaries", &member_token, serde_json::json!({"groupIDs": [group.group_id]})).await;
    assert_eq!(summary["errCode"], 0, "读取已读后的群摘要失败: {summary}");
    assert_eq!(summary["data"]["summaries"].as_array().map(Vec::len), Some(1), "已读后群摘要为空: {summary}");
    assert_eq!(summary["data"]["summaries"][0]["unreadTopicCount"], 0);
    let reacted = raw_post_json(
        "/topic/set_topic_reaction",
        &member_token,
        serde_json::json!({
            "topicID": root_id,
            "emoji": "👍",
            "active": true
        }),
    )
    .await;
    assert_eq!(reacted["errCode"], 0);
    assert_eq!(reacted["data"]["reactions"]["counts"][0]["count"], 1);
    assert_eq!(reacted["data"]["reactions"]["myReactions"][0], "👍");
    let reacted_detail = wait_for_topic(&owner_token, &group.group_id, &root_id, Duration::from_secs(10)).await;
    assert_eq!(reacted_detail["topic"]["reactions"]["counts"][0]["count"], 1);
    let unreacted = raw_post_json(
        "/topic/set_topic_reaction",
        &member_token,
        serde_json::json!({
            "topicID": root_id,
            "emoji": "👍",
            "active": false
        }),
    )
    .await;
    assert_eq!(unreacted["errCode"], 0);
    assert_eq!(unreacted["data"]["reactions"]["counts"].as_array().map(Vec::len), Some(0));

    let conversation_id = format!("sg_{}", group.group_id);
    wait_for_local_topic_message(&owner_sdk, &conversation_id, &root_id, &root_id, Duration::from_secs(15)).await;
    wait_for_local_topic_message(&member_sdk, &conversation_id, &root_id, &root_id, Duration::from_secs(15)).await;
    wait_for_local_topic_message(&owner_sdk, &conversation_id, &reply.client_msg_id, &root_id, Duration::from_secs(15)).await;
    wait_for_local_topic_message(&member_sdk, &conversation_id, &reply.client_msg_id, &root_id, Duration::from_secs(15)).await;

    let mut member_events = subscribe_all(&member_sdk);
    let pinned = raw_post_json(
        "/topic/set_topic_pinned",
        &owner_token,
        serde_json::json!({
            "topicID": root_id,
            "pinned": true,
            "expectedVersion": 2
        }),
    )
    .await;
    assert_eq!(pinned["errCode"], 0);
    let pinned_version = pinned["data"]["topic"]["version"].as_i64().expect("Pin 版本缺失");
    let group_pinned = raw_post_json(
        "/topic/set_topic_group_pinned",
        &owner_token,
        serde_json::json!({
            "topicID": root_id,
            "pinned": true,
            "expectedVersion": pinned_version
        }),
    )
    .await;
    assert_eq!(group_pinned["errCode"], 0);
    assert_eq!(group_pinned["data"]["topic"]["pinned"], true);
    assert_eq!(group_pinned["data"]["topic"]["groupPinned"], true);
    let event_deadline = tokio::time::Instant::now() + Duration::from_secs(10);
    loop {
        if tokio::time::Instant::now() >= event_deadline {
            panic!("等待 Topic 实时事件超时");
        }
        let event = tokio::time::timeout(Duration::from_secs(2), member_events.next()).await;
        if let Ok(Some(event)) = event {
            let is_topic_event = match event {
                TestEvent::Message(MessageEvent::NewMessage { message, .. }) | TestEvent::Message(MessageEvent::OnlineOnlyMessage { message, .. }) => {
                    message.content_type == 120 && message.topic_id == root_id
                }
                _ => false,
            };
            if is_topic_event {
                break;
            }
        }
    }

    let task = raw_post_json(
        "/topic/create_topic_task",
        &owner_token,
        serde_json::json!({
            "topicID": root_id,
            "title": "确认 Android 发布包",
            "description": "完成真机回归",
            "assigneeID": member.user_id,
            "dueAt": 1800000000000_i64,
            "priority": 3
        }),
    )
    .await;
    assert_eq!(task["errCode"], 0);
    let task_id = task["data"]["task"]["taskID"].as_str().expect("任务 ID 缺失").to_string();
    assert_eq!(task["data"]["task"]["status"].as_i64(), Some(1));
    assert_eq!(task["data"]["task"]["assigneeID"], member.user_id);

    let task_event_deadline = tokio::time::Instant::now() + Duration::from_secs(10);
    loop {
        if tokio::time::Instant::now() >= task_event_deadline {
            panic!("等待任务分配事件超时");
        }
        if let Ok(Some(event)) = tokio::time::timeout(Duration::from_secs(2), member_events.next()).await {
            if let TestEvent::Message(MessageEvent::NewMessage { message, .. }) | TestEvent::Message(MessageEvent::OnlineOnlyMessage { message, .. }) = event {
                if topic_event_action(&message) == "topic_task_assigned" {
                    break;
                }
            }
        }
    }

    let tasks = raw_post_json("/topic/get_topic_tasks", &member_token, serde_json::json!({"topicID": root_id})).await;
    assert_eq!(tasks["errCode"], 0);
    assert_eq!(tasks["data"]["tasks"][0]["taskID"], task_id);
    let completed = raw_post_json(
        "/topic/change_topic_task_status",
        &member_token,
        serde_json::json!({
            "taskID": task_id,
            "status": 2,
            "expectedVersion": 1
        }),
    )
    .await;
    assert_eq!(completed["errCode"], 0);
    assert_eq!(completed["data"]["task"]["status"], 2);

    let mut attachment = MsgStruct::create_image_message(
        "",
        PictureBaseInfo {
            url: "https://example.com/topic-search.png".to_string(),
            ..Default::default()
        },
        PictureBaseInfo {
            url: "https://example.com/topic-search.png".to_string(),
            ..Default::default()
        },
        PictureBaseInfo {
            url: "https://example.com/topic-search.png".to_string(),
            ..Default::default()
        },
    );
    attachment.session_type = 3;
    attachment.topic_id = root_id.clone();
    member_sdk.send_msg(attachment, &group.group_id, None).await.expect("发送附件话题回复失败");
    let attachment_deadline = tokio::time::Instant::now() + Duration::from_secs(15);
    loop {
        let detail = wait_for_topic(&member_token, &group.group_id, &root_id, Duration::from_secs(5)).await;
        if detail["topic"]["replyCount"].as_i64() == Some(2) {
            break;
        }
        if tokio::time::Instant::now() >= attachment_deadline {
            panic!("等待附件回复索引超时");
        }
        tokio::time::sleep(Duration::from_millis(300)).await;
    }
    let mut mention = MsgStruct::create_at_text_message("请确认话题任务", vec![member.user_id.clone()], vec![], None);
    mention.session_type = 3;
    mention.topic_id = root_id.clone();
    owner_sdk.send_msg(mention, &group.group_id, None).await.expect("发送 @成员 话题回复失败");
    let mention_deadline = tokio::time::Instant::now() + Duration::from_secs(15);
    let mentioned_topic = loop {
        let detail = wait_for_topic(&member_token, &group.group_id, &root_id, Duration::from_secs(5)).await;
        if detail["topic"]["replyCount"].as_i64() == Some(3) && detail["topic"]["hasMention"] == true {
            break detail;
        }
        if tokio::time::Instant::now() >= mention_deadline {
            panic!("等待 @我 状态超时: {detail}");
        }
        tokio::time::sleep(Duration::from_millis(300)).await;
    };
    let mention_read_seq = mentioned_topic["topic"]["lastReplySeq"].as_i64().unwrap();
    let mention_marked = raw_post_json("/topic/mark_topic_read", &member_token, serde_json::json!({"topicID": root_id, "lastReadSeq": mention_read_seq})).await;
    assert_eq!(mention_marked["errCode"], 0);
    let mention_cleared = wait_for_topic(&member_token, &group.group_id, &root_id, Duration::from_secs(10)).await;
    assert_eq!(mention_cleared["topic"]["hasMention"], false);

    let notifications = raw_post_json(
        "/topic/get_topic_notifications",
        &member_token,
        serde_json::json!({"groupID": group.group_id, "cursor": "", "count": 50}),
    )
    .await;
    assert_eq!(notifications["errCode"], 0);
    let notification_types: Vec<i64> = notifications["data"]["notifications"].as_array().unwrap().iter().filter_map(|item| item["type"].as_i64()).collect();
    assert!(notification_types.contains(&6), "缺少任务分配通知: {notifications}");
    assert!(notification_types.contains(&1), "缺少新话题通知: {notifications}");
    assert!(notification_types.contains(&3), "缺少 @我 通知: {notifications}");
    assert!(notifications["data"]["unreadCount"].as_i64().unwrap_or_default() > 0);
    let owner_notifications = raw_post_json(
        "/topic/get_topic_notifications",
        &owner_token,
        serde_json::json!({"groupID": group.group_id, "cursor": "", "count": 50}),
    )
    .await;
    assert_eq!(owner_notifications["errCode"], 0);
    let owner_notification_types: Vec<i64> = owner_notifications["data"]["notifications"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(|item| item["type"].as_i64())
        .collect();
    assert!(owner_notification_types.contains(&7), "缺少任务状态通知: {owner_notifications}");
    assert!(owner_notification_types.contains(&2), "缺少回复通知: {owner_notifications}");
    let marked_notifications = raw_post_json("/topic/mark_topic_notifications_read", &member_token, serde_json::json!({"notificationIDs": []})).await;
    assert_eq!(marked_notifications["errCode"], 0);
    let notifications_after_read = raw_post_json(
        "/topic/get_topic_notifications",
        &member_token,
        serde_json::json!({"groupID": group.group_id, "cursor": "", "count": 1}),
    )
    .await;
    assert_eq!(notifications_after_read["data"]["unreadCount"], 0);

    let subscribed = raw_post_json("/topic/set_topic_subscription", &member_token, serde_json::json!({"topicID": root_id, "subscribed": true})).await;
    assert_eq!(subscribed["errCode"], 0);
    let search = raw_post_json(
        "/topic/search_topics",
        &member_token,
        serde_json::json!({
            "groupID": group.group_id,
            "keyword": "真实话题回复",
            "tab": 1,
            "count": 30,
            "authorID": owner.user_id,
            "createdAfter": 1_i64,
            "state": 1,
            "hasAttachments": true,
            "hasTasks": true,
            "pinnedOnly": true
        }),
    )
    .await;
    assert_eq!(search["errCode"], 0);
    assert_eq!(search["data"]["topics"][0]["topicID"], root_id);
    assert_eq!(search["data"]["hasMore"], false);
    let no_closed = raw_post_json(
        "/topic/search_topics",
        &member_token,
        serde_json::json!({
            "groupID": group.group_id,
            "tab": 0,
            "count": 30,
            "state": 2
        }),
    )
    .await;
    assert_eq!(no_closed["errCode"], 0);
    assert!(no_closed["data"]["topics"].as_array().map(Vec::is_empty).unwrap_or(true));

    let settings = raw_post_json("/topic/get_topic_group_settings", &member_token, serde_json::json!({"groupID": group.group_id})).await;
    assert_eq!(settings["errCode"], 0);
    assert_eq!(settings["data"]["settings"]["allowMemberPublish"], true);
    assert_eq!(settings["data"]["settings"]["allowMemberReply"], true);
    assert_eq!(settings["data"]["settings"]["allowMemberPin"], true);
    assert_eq!(settings["data"]["settings"]["allowMemberGroupPin"], true);
    let forbidden_settings = raw_post_json(
        "/topic/set_topic_group_settings",
        &member_token,
        serde_json::json!({
            "groupID": group.group_id,
            "settings": {
                "allowMemberPublish": false,
                "allowMemberReply": false,
                "defaultSubscribe": true,
                "notifyNewTopic": true,
                "notifyReplies": true,
                "allowMemberPin": false,
                "allowMemberGroupPin": false
            },
            "expectedVersion": settings["data"]["version"]
        }),
    )
    .await;
    assert_ne!(forbidden_settings["errCode"], 0);
    let restricted = raw_post_json(
        "/topic/set_topic_group_settings",
        &owner_token,
        serde_json::json!({
            "groupID": group.group_id,
            "settings": {
                "allowMemberPublish": false,
                "allowMemberReply": false,
                "defaultSubscribe": true,
                "notifyNewTopic": true,
                "notifyReplies": true,
                "allowMemberPin": false,
                "allowMemberGroupPin": false
            },
            "expectedVersion": settings["data"]["version"]
        }),
    )
    .await;
    assert_eq!(restricted["errCode"], 0);
    let forbidden_member_pin = raw_post_json(
        "/topic/set_topic_pinned",
        &member_token,
        serde_json::json!({
            "topicID": root_id,
            "pinned": false,
            "expectedVersion": restricted["data"]["version"]
        }),
    )
    .await;
    assert_ne!(forbidden_member_pin["errCode"], 0);
    let member_group_pin_hidden = raw_post_json(
        "/topic/set_topic_group_pinned",
        &member_token,
        serde_json::json!({
            "topicID": root_id,
            "pinned": false,
            "expectedVersion": 0
        }),
    )
    .await;
    assert_eq!(member_group_pin_hidden["errCode"], 0);
    assert_eq!(member_group_pin_hidden["data"]["topic"]["groupPinned"], false);
    assert_eq!(member_group_pin_hidden["data"]["topic"]["userState"]["groupPinnedHidden"], true);
    let member_feed_after_hide = raw_post_json("/topic/get_topics", &member_token, serde_json::json!({"groupID": group.group_id, "tab": 0, "count": 30})).await;
    assert_eq!(member_feed_after_hide["errCode"], 0);
    assert_eq!(member_feed_after_hide["data"]["items"][0]["topic"]["groupPinned"], false);
    let owner_still_group_pinned = raw_post_json("/topic/get_topic", &owner_token, serde_json::json!({"groupID": group.group_id, "topicID": root_id})).await;
    assert_eq!(owner_still_group_pinned["errCode"], 0);
    assert_eq!(owner_still_group_pinned["data"]["topic"]["groupPinned"], true);
    let owner_feed_after_member_hide = raw_post_json("/topic/get_topics", &owner_token, serde_json::json!({"groupID": group.group_id, "tab": 0, "count": 30})).await;
    assert_eq!(owner_feed_after_member_hide["errCode"], 0);
    assert_eq!(owner_feed_after_member_hide["data"]["items"][0]["topic"]["groupPinned"], true);
    let member_group_pin_restored = raw_post_json(
        "/topic/set_topic_group_pinned",
        &member_token,
        serde_json::json!({
            "topicID": root_id,
            "pinned": true,
            "expectedVersion": 0
        }),
    )
    .await;
    assert_eq!(member_group_pin_restored["errCode"], 0);
    assert_eq!(member_group_pin_restored["data"]["topic"]["groupPinned"], true);
    let blocked_root = MsgStruct::create_text_message("成员不应发布的话题");
    let blocked_root_error = member_sdk.send_msg(blocked_root, &group.group_id, None).await;
    assert!(blocked_root_error.is_err());
    let mut blocked_reply = MsgStruct::create_text_message("成员不应发送的回复");
    blocked_reply.session_type = 3;
    blocked_reply.topic_id = root_id.clone();
    let blocked_reply_error = member_sdk.send_msg(blocked_reply, &group.group_id, None).await;
    assert!(blocked_reply_error.is_err());
    let restored_settings = raw_post_json(
        "/topic/set_topic_group_settings",
        &owner_token,
        serde_json::json!({
            "groupID": group.group_id,
            "settings": {
                "allowMemberPublish": true,
                "allowMemberReply": true,
                "defaultSubscribe": true,
                "notifyNewTopic": true,
                "notifyReplies": true,
                "allowMemberPin": true,
                "allowMemberGroupPin": true
            },
            "expectedVersion": restricted["data"]["version"]
        }),
    )
    .await;
    assert_eq!(restored_settings["errCode"], 0);

    let unsubscribed = raw_post_json(
        "/topic/set_topic_subscription",
        &member_token,
        serde_json::json!({
            "topicID": root_id,
            "subscribed": false
        }),
    )
    .await;
    assert_eq!(unsubscribed["errCode"], 0);
    let subscription_event_deadline = tokio::time::Instant::now() + Duration::from_secs(10);
    loop {
        if tokio::time::Instant::now() >= subscription_event_deadline {
            panic!("等待订阅同步事件超时");
        }
        if let Ok(Some(event)) = tokio::time::timeout(Duration::from_secs(2), member_events.next()).await {
            if let TestEvent::Message(MessageEvent::NewMessage { message, .. }) | TestEvent::Message(MessageEvent::OnlineOnlyMessage { message, .. }) = event {
                if topic_event_action(&message) == "topic_subscription_changed" {
                    break;
                }
            }
        }
    }

    let mut extra_reply = MsgStruct::create_text_message("用于验证阅读位置同步");
    extra_reply.session_type = 3;
    extra_reply.topic_id = root_id.clone();
    owner_sdk.send_msg(extra_reply, &group.group_id, None).await.expect("发送阅读同步测试回复失败");
    let read_target = loop {
        let detail = raw_post_json("/topic/get_topic", &member_token, serde_json::json!({"groupID": group.group_id, "topicID": root_id})).await;
        if detail["data"]["topic"]["replyCount"].as_i64() == Some(4) {
            break detail["data"]["topic"]["lastReplySeq"].as_i64().unwrap_or_default();
        }
        tokio::time::sleep(Duration::from_millis(300)).await;
    };
    let marked_read = raw_post_json("/topic/mark_topic_read", &member_token, serde_json::json!({"topicID": root_id, "lastReadSeq": read_target})).await;
    assert_eq!(marked_read["errCode"], 0);
    let read_event_deadline = tokio::time::Instant::now() + Duration::from_secs(10);
    loop {
        if tokio::time::Instant::now() >= read_event_deadline {
            panic!("等待阅读位置同步事件超时");
        }
        if let Ok(Some(event)) = tokio::time::timeout(Duration::from_secs(2), member_events.next()).await {
            if let TestEvent::Message(MessageEvent::NewMessage { message, .. }) | TestEvent::Message(MessageEvent::OnlineOnlyMessage { message, .. }) = event {
                if topic_event_action(&message) == "topic_read_changed" {
                    break;
                }
            }
        }
    }

    let before_edit = wait_for_topic(&owner_token, &group.group_id, &root_id, Duration::from_secs(10)).await;
    let edited = raw_post_json(
        "/topic/edit_topic",
        &owner_token,
        serde_json::json!({
            "topicID": root_id,
            "text": "SDK 真实话题根消息（已编辑）",
            "expectedVersion": before_edit["topic"]["version"]
        }),
    )
    .await;
    assert_eq!(edited["errCode"], 0);
    assert_eq!(edited["data"]["topic"]["rootPreview"], "SDK 真实话题根消息（已编辑）");
    assert!(edited["data"]["topic"]["editedAt"].as_i64().unwrap_or_default() > 0);
    let forbidden_edit = raw_post_json(
        "/topic/edit_topic",
        &member_token,
        serde_json::json!({
            "topicID": root_id,
            "text": "成员不能编辑",
            "expectedVersion": edited["data"]["topic"]["version"]
        }),
    )
    .await;
    assert_ne!(forbidden_edit["errCode"], 0);
    let edited_detail = wait_for_topic(&member_token, &group.group_id, &root_id, Duration::from_secs(10)).await;
    let encoded_root_content = edited_detail["rootMessage"]["content"].as_str().expect("根消息内容必须是 Base64");
    let root_content = String::from_utf8(BASE64.decode(encoded_root_content).expect("根消息内容 Base64 解码失败")).expect("根消息内容不是 UTF-8");
    assert_eq!(root_content, "{\"content\":\"SDK 真实话题根消息（已编辑）\"}");

    let to_chat = raw_post_json(
        "/topic/set_group_mode",
        &owner_token,
        serde_json::json!({
            "groupID": group.group_id,
            "mode": 1,
            "expectedVersion": 3
        }),
    )
    .await;
    assert_eq!(to_chat["errCode"], 0);

    let mut normal = MsgStruct::create_text_message("切回普通群后的消息");
    normal.session_type = 3;
    let normal = owner_sdk.send_msg(normal, &group.group_id, None).await.expect("普通群消息发送失败");
    assert!(normal.topic_id.is_empty());

    let topics = raw_post_json(
        "/topic/get_topics",
        &owner_token,
        serde_json::json!({
            "groupID": group.group_id,
            "tab": 0,
            "cursor": "",
            "count": 30
        }),
    )
    .await;
    assert_eq!(topics["errCode"], 0);
    let topic_item_count = topics["data"]["items"].as_array().unwrap().iter().filter(|item| item["type"].as_i64() == Some(1)).count();
    assert_eq!(topic_item_count, 1);

    let to_topic = raw_post_json(
        "/topic/set_group_mode",
        &owner_token,
        serde_json::json!({
            "groupID": group.group_id,
            "mode": 2,
            "expectedVersion": 4
        }),
    )
    .await;
    assert_eq!(to_topic["errCode"], 0);

    let outsider = create_random_account("TopicOutsider").await;
    let (outsider_token, _) = login_account(&outsider).await.expect("非成员登录失败");
    let outsider_access = raw_post_json("/topic/get_topic", &outsider_token, serde_json::json!({"groupID": group.group_id, "topicID": root_id})).await;
    assert_ne!(outsider_access["errCode"], 0, "非群成员不应读取话题: {outsider_access}");

    owner_sdk
        .kick_group_members(&group.group_id, std::slice::from_ref(&member.user_id), Some("topic permission test"))
        .await
        .expect("踢出话题成员失败");
    let kicked_access = raw_post_json("/topic/get_topic", &member_token, serde_json::json!({"groupID": group.group_id, "topicID": root_id})).await;
    assert_ne!(kicked_access["errCode"], 0, "被踢成员不应继续读取话题: {kicked_access}");

    owner_sdk.dismiss_group(&group.group_id).await.expect("解散测试群失败");
}
