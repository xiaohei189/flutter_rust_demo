//! 离线消息测试

use anyhow::Result;
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock};
use tokio::time::sleep;
use tracing::{info, warn};

use crate::e2e::fixtures::{TestConfig, TestUser};
use crate::e2e::helpers::{create_and_connect_client, login_user, wait_for_message};

/// 测试离线消息监听器
struct TestOfflineMessageListener {
    received_offline_messages: Arc<RwLock<Vec<String>>>,
    last_offline_message: Arc<RwLock<Option<String>>>,
}

impl TestOfflineMessageListener {
    fn new() -> Self {
        Self {
            received_offline_messages: Arc::new(RwLock::new(Vec::new())),
            last_offline_message: Arc::new(RwLock::new(None)),
        }
    }
}

#[async_trait::async_trait]
impl rust_lib_flutter_rust_demo::im::message::listener::AdvancedMsgListener
    for TestOfflineMessageListener
{
    async fn on_recv_new_message(&self, _message: String) {
        // 在线消息，这里不处理
    }

    async fn on_recv_c2c_read_receipt(&self, _msg_receipt_list: String) {}
    async fn on_new_recv_message_revoked(&self, _message_revoked: String) {}

    async fn on_recv_offline_new_message(&self, message: String) {
        info!("📬 收到离线消息: {}", message);
        let mut msgs = self.received_offline_messages.write().await;
        msgs.push(message.clone());
        let mut last = self.last_offline_message.write().await;
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

/// 测试离线消息
///
/// 测试流程：
/// 1. 发送者登录并连接
/// 2. 接收者不登录（离线状态）
/// 3. 发送者发送消息给接收者
/// 4. 接收者登录并连接
/// 5. 验证接收者收到离线消息
#[tokio::test]
#[ignore] // 默认忽略，需要手动运行
async fn test_offline_message() -> Result<()> {
    init_test_logger();

    let config = TestConfig::default();
    let sender = TestUser::new("17764338283");
    let receiver = TestUser::new("17764338284");

    info!("🧪 开始测试离线消息");

    // 步骤 1: 发送者登录并连接
    let sender_login = login_user(&sender, &config).await?;
    let sender_client = create_and_connect_client(
        sender_login.user_id.clone(),
        sender_login.im_token.clone(),
        &config,
    )
    .await?;

    info!("✅ 发送者已登录并连接");

    // 步骤 2: 接收者不登录（模拟离线状态）
    let receiver_login = login_user(&receiver, &config).await?;
    info!("ℹ️  接收者已登录但未连接（模拟离线状态）");

    // 步骤 3: 发送者发送消息给接收者
    let test_message = "This is an offline message from E2E test!";
    info!("📤 发送离线消息: {}", test_message);

    {
        let client = sender_client.lock().await;
        client
            .send_text_message(
                receiver_login.user_id.clone(),
                test_message.to_string(),
                1, // 单聊
            )
            .await?;
    }

    info!("✅ 消息已发送（接收者离线）");

    // 等待一段时间，确保消息已存储到服务器
    sleep(tokio::time::Duration::from_secs(2)).await;

    // 步骤 4: 接收者登录并连接（此时应该收到离线消息）
    let receiver_listener = Arc::new(TestOfflineMessageListener::new());
    let receiver_received = receiver_listener.last_offline_message.clone();

    let receiver_client = create_and_connect_client(
        receiver_login.user_id.clone(),
        receiver_login.im_token.clone(),
        &config,
    )
    .await?;

    {
        let mut client = receiver_client.lock().await;
        client.set_advanced_msg_listener(receiver_listener.clone());
    }

    info!("✅ 接收者已连接，等待离线消息...");

    // 步骤 5: 验证接收者收到离线消息
    // 等待离线消息接收（最多等待 10 秒，因为需要同步）
    let received = wait_for_message(&receiver_received, 10).await?;

    if let Some(msg_json) = received {
        info!("✅ 离线消息接收成功: {}", msg_json);
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
            info!("✅ 离线消息内容验证通过");
            return Ok(());
        }
        return Err(anyhow::anyhow!("离线消息内容不匹配: {}", msg_json));
    } else {
        return Err(anyhow::anyhow!("离线消息接收超时"));
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

