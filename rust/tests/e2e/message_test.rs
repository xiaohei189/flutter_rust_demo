//! 消息发送测试（单聊）

use anyhow::Result;
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock};
use tokio::time::sleep;
use tracing::{info, warn};

use crate::e2e::fixtures::{TestConfig, TestUser};
use crate::e2e::helpers::{create_and_connect_client, login_user, wait_for_message};

/// 测试消息监听器（收集接收到的消息）
struct TestMessageListener {
    received_messages: Arc<RwLock<Vec<String>>>,
    last_message: Arc<RwLock<Option<String>>>,
}

impl TestMessageListener {
    fn new() -> Self {
        Self {
            received_messages: Arc::new(RwLock::new(Vec::new())),
            last_message: Arc::new(RwLock::new(None)),
        }
    }
}

#[async_trait::async_trait]
impl rust_lib_flutter_rust_demo::im::message::listener::AdvancedMsgListener
    for TestMessageListener
{
    async fn on_recv_new_message(&self, message: String) {
        info!("📨 收到新消息: {}", message);
        let mut msgs = self.received_messages.write().await;
        msgs.push(message.clone());
        let mut last = self.last_message.write().await;
        *last = Some(message);
    }

    async fn on_recv_c2c_read_receipt(&self, _msg_receipt_list: String) {}
    async fn on_new_recv_message_revoked(&self, _message_revoked: String) {}
    async fn on_recv_offline_new_message(&self, message: String) {
        info!("📬 收到离线消息: {}", message);
        let mut msgs = self.received_messages.write().await;
        msgs.push(message.clone());
        let mut last = self.last_message.write().await;
        *last = Some(message);
    }
    async fn on_msg_deleted(&self, _message: String) {}
    async fn on_recv_online_only_message(&self, _message: String) {}
    async fn on_kicked_offline(&self) {
        warn!("⚠️ 被踢下线");
    }
    async fn on_connection_status_changed(&self, connected: bool, message: String) {
        if connected {
            info!("🔗 连接成功: {}", message);
        } else {
            warn!("🔗 断开连接: {}", message);
        }
    }
    async fn on_recv_typing_status(&self, _typing_info: String) {}
}

/// 测试单聊消息发送
#[tokio::test]
#[ignore] // 默认忽略，需要手动运行
async fn test_send_single_chat_message() -> Result<()> {
    // 初始化日志
    init_test_logger();

    let config = TestConfig::default();
    let sender = TestUser::new("17764338283");
    let receiver = TestUser::new("17764338284");

    info!("🧪 开始测试单聊消息发送");

    // 登录发送者
    let sender_login = login_user(&sender, &config).await?;
    let sender_client = create_and_connect_client(
        sender_login.user_id.clone(),
        sender_login.im_token.clone(),
        &config,
    )
    .await?;

    // 登录接收者
    let receiver_login = login_user(&receiver, &config).await?;
    let receiver_listener = Arc::new(TestMessageListener::new());
    let receiver_received = receiver_listener.last_message.clone();

    // 设置接收者的消息监听器
    {
        let mut receiver_client_guard = create_and_connect_client(
            receiver_login.user_id.clone(),
            receiver_login.im_token.clone(),
            &config,
        )
        .await?;
        let mut client = receiver_client_guard.lock().await;
        client.set_advanced_msg_listener(receiver_listener.clone());
    }

    // 等待连接稳定
    sleep(tokio::time::Duration::from_secs(1)).await;

    // 发送消息
    let test_message = "Hello from E2E test!";
    info!("📤 发送消息: {}", test_message);

    let msg = MsgStruct {
        client_msg_id: None,
        server_msg_id: None,
        create_time: None,
        send_time: None,
        send_id: None,
        recv_id: Some(receiver_login.user_id.clone()),
        group_id: None,
        sender_face_url: None,
        sender_nickname: None,
        session_type: Some(1), // 单聊
        msg_from: None,
        content_type: Some(101), // 文本消息
        platform_id: None,
        sender_platform_id: None,
        sender_id: None,
        sender_face_url: None,
        content: Some(json!({
            "text": test_message
        })
        .to_string()),
        content_bytes: None,
        body: Some(serde_json::to_value(TextElem {
            content: test_message.to_string(),
        })?),
        at_elem: None,
        face_elem: None,
        location_elem: None,
        custom_elem: None,
        sound_elem: None,
        video_elem: None,
        file_elem: None,
        picture_elem: None,
        quote_elem: None,
        merge_elem: None,
        at_text_elem: None,
        face_elem_list: None,
        notification_elem: None,
        attached_info_elem: None,
        ex: None,
        local_ex: None,
        status: None,
        is_read: None,
        seq: None,
        options: None,
        offline_push: None,
        attached_info: None,
    });

    {
        let mut client = sender_client.lock().await;
        client
            .send_message(
                receiver_login.user_id.clone(),
                String::new(), // 单聊，group_id 为空
                msg,
                None,
                false, // 不是仅在线消息
            )
            .await?;
    }

    info!("✅ 消息已发送，等待接收...");

    // 等待消息接收（最多等待 5 秒）
    let received = wait_for_message(&receiver_received, 5).await?;

    if let Some(msg_json) = received {
        info!("✅ 消息接收成功: {}", msg_json);
        // 验证消息内容
        let msg_obj: serde_json::Value = serde_json::from_str(&msg_json)?;
        // 检查消息内容（可能是 content 字段或 textElem 字段）
        let content_match = if let Some(content) = msg_obj.get("content") {
            content.as_str().map(|s| s.contains(test_message)).unwrap_or(false)
        } else if let Some(text_elem) = msg_obj.get("textElem") {
            text_elem
                .get("content")
                .and_then(|c| c.as_str())
                .map(|s| s == test_message)
                .unwrap_or(false)
        } else {
            false
        };

        if content_match {
            info!("✅ 消息内容验证通过");
            return Ok(());
        }
        return Err(anyhow::anyhow!("消息内容不匹配: {}", msg_json));
    } else {
        return Err(anyhow::anyhow!("消息接收超时"));
    }
}

/// 初始化测试日志
fn init_test_logger() {
    use tracing_subscriber::prelude::*;
    use tracing_subscriber::EnvFilter;

    let filter_layer =
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info,rust_lib_flutter_rust_demo=debug"));

    let stdout_layer = tracing_subscriber::fmt::layer()
        .with_writer(std::io::stdout)
        .with_file(true)
        .with_line_number(true)
        .with_target(false)
        .with_ansi(true);

    tracing_subscriber::registry()
        .with(filter_layer)
        .with(stdout_layer)
        .init();
}

