//! 群聊测试

use anyhow::Result;
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock};
use tokio::time::sleep;
use tracing::{info, warn};

use crate::e2e::fixtures::{TestConfig, TestUser};
use crate::e2e::helpers::{create_and_connect_client, login_user, wait_for_message};

/// 测试群聊消息监听器
struct TestGroupMessageListener {
    received_messages: Arc<RwLock<Vec<String>>>,
    last_message: Arc<RwLock<Option<String>>>,
    group_id: String,
}

impl TestGroupMessageListener {
    fn new(group_id: String) -> Self {
        Self {
            received_messages: Arc::new(RwLock::new(Vec::new())),
            last_message: Arc::new(RwLock::new(None)),
            group_id,
        }
    }
}

#[async_trait::async_trait]
impl rust_lib_flutter_rust_demo::im::message::listener::AdvancedMsgListener
    for TestGroupMessageListener
{
    async fn on_recv_new_message(&self, message: String) {
        info!("📨 收到群聊新消息: {}", message);
        // 验证是否是群聊消息
        if let Ok(msg_obj) = serde_json::from_str::<serde_json::Value>(&message) {
            if let Some(group_id) = msg_obj.get("groupID") {
                if group_id.as_str() == Some(&self.group_id) {
                    let mut msgs = self.received_messages.write().await;
                    msgs.push(message.clone());
                    let mut last = self.last_message.write().await;
                    *last = Some(message);
                }
            }
        }
    }

    async fn on_recv_c2c_read_receipt(&self, _msg_receipt_list: String) {}
    async fn on_new_recv_message_revoked(&self, _message_revoked: String) {}
    async fn on_recv_offline_new_message(&self, message: String) {
        info!("📬 收到群聊离线消息: {}", message);
        if let Ok(msg_obj) = serde_json::from_str::<serde_json::Value>(&message) {
            if let Some(group_id) = msg_obj.get("groupID") {
                if group_id.as_str() == Some(&self.group_id) {
                    let mut msgs = self.received_messages.write().await;
                    msgs.push(message.clone());
                    let mut last = self.last_message.write().await;
                    *last = Some(message);
                }
            }
        }
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

/// 测试群聊消息发送
///
/// 注意：此测试需要预先创建群组，或者使用已有的群组 ID
/// 可以通过 OpenIM API 创建群组，或者手动创建后使用群组 ID
#[tokio::test]
#[ignore] // 默认忽略，需要手动运行
async fn test_send_group_message() -> Result<()> {
    init_test_logger();

    let config = TestConfig::default();
    let sender = TestUser::new("17764338283");
    let receiver = TestUser::new("17764338284");

    info!("🧪 开始测试群聊消息发送");

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

    // TODO: 这里需要实际的群组 ID，可以通过 API 创建或使用已有群组
    // 示例：假设已经有一个群组，群组 ID 需要从实际环境中获取
    let group_id = "test_group_123".to_string(); // 需要替换为实际群组 ID

    let receiver_listener = Arc::new(TestGroupMessageListener::new(group_id.clone()));
    let receiver_received = receiver_listener.last_message.clone();

    // 设置接收者的消息监听器
    {
        let receiver_client = create_and_connect_client(
            receiver_login.user_id.clone(),
            receiver_login.im_token.clone(),
            &config,
        )
        .await?;
        let mut client = receiver_client.lock().await;
        client.set_advanced_msg_listener(receiver_listener.clone());
    }

    // 等待连接稳定
    sleep(tokio::time::Duration::from_secs(1)).await;

    // 发送群聊消息
    let test_message = "Hello from group chat E2E test!";
    info!("📤 发送群聊消息到群组: {}", group_id);

    {
        let client = sender_client.lock().await;
        client
            .send_text_message(
                group_id.clone(), // 群聊时 recv_id 是群组 ID
                test_message.to_string(),
                2, // 群聊
            )
            .await?;
    }

    info!("✅ 群聊消息已发送，等待接收...");

    // 等待消息接收（最多等待 5 秒）
    let received = wait_for_message(&receiver_received, 5).await?;

    if let Some(msg_json) = received {
        info!("✅ 群聊消息接收成功: {}", msg_json);
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
            info!("✅ 群聊消息内容验证通过");
            return Ok(());
        }
        return Err(anyhow::anyhow!("群聊消息内容不匹配: {}", msg_json));
    } else {
        return Err(anyhow::anyhow!("群聊消息接收超时"));
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

