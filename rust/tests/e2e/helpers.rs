//! 测试辅助函数和工具

use anyhow::Result;
use rust_lib_flutter_rust_demo::im::auth::{login_async, LoginData};
use rust_lib_flutter_rust_demo::im::client::{ClientConfig, OpenIMClient};
use rust_lib_flutter_rust_demo::im::conversation::listener::ConversationListener;
use rust_lib_flutter_rust_demo::im::friend::FriendListener;
use rust_lib_flutter_rust_demo::im::message::listener::AdvancedMsgListener;
use std::sync::Arc;
use tokio::sync::Mutex;
use tokio::time::{sleep, Duration, timeout};
use tracing::{error, info, warn};

use crate::e2e::fixtures::{TestConfig, TestUser};

/// 登录并获取 token 信息
pub async fn login_user(user: &TestUser, config: &TestConfig) -> Result<LoginData> {
    info!("🔐 登录用户: {}", user.phone);
    let token_info = login_async(
        user.area_code.clone(),
        user.phone.clone(),
        user.password.clone(),
        config.platform_id,
    )
    .await
    .map_err(|e| anyhow::anyhow!("登录失败: {}", e))?;

    if let Some(data) = token_info.data {
        info!("✅ 登录成功: {}", data.user_id);
        Ok(data)
    } else {
        Err(anyhow::anyhow!("登录失败：服务器返回数据为空"))
    }
}

/// 创建并连接客户端
pub async fn create_and_connect_client(
    user_id: String,
    token: String,
    config: &TestConfig,
) -> Result<Arc<Mutex<OpenIMClient>>> {
    let client_config = ClientConfig {
        user_id: user_id.clone(),
        token: token.clone(),
        platform_id: config.platform_id,
        ws_url: config.ws_url.clone(),
        compression: "gzip".to_string(),
        is_background: false,
        is_msg_resp: true,
        sdk_type: "js".to_string(),
        api_base_url: config.api_base_url.clone(),
        conversation_db_url: format!("sqlite://test_conversations_{}.db?mode=rwc", user_id),
    };

    let mut client = OpenIMClient::new(client_config);

    // 设置空的监听器（测试中可以根据需要自定义）
    client.set_conversation_listener(Arc::new(EmptyTestConversationListener));
    client.set_friend_listener(Arc::new(EmptyTestFriendListener));
    client.set_advanced_msg_listener(Arc::new(EmptyTestAdvancedMsgListener));

    let client = Arc::new(Mutex::new(client));

    // 连接
    {
        let mut client_guard = client.lock().await;
        client_guard
            .connect()
            .await
            .map_err(|e| anyhow::anyhow!("连接失败: {}", e))?;
    }

    // 等待连接稳定
    sleep(Duration::from_millis(500)).await;

    info!("✅ 客户端连接成功: {}", user_id);
    Ok(client)
}

/// 等待条件满足（带超时）
pub async fn wait_for_condition<F, Fut>(condition: F, timeout_secs: u64) -> Result<bool>
where
    F: Fn() -> Fut,
    Fut: std::future::Future<Output = bool>,
{
    let start = std::time::Instant::now();
    let timeout_duration = Duration::from_secs(timeout_secs);

    loop {
        if condition().await {
            return Ok(true);
        }

        if start.elapsed() > timeout_duration {
            return Ok(false);
        }

        sleep(Duration::from_millis(100)).await;
    }
}

/// 等待消息接收（带超时）
pub async fn wait_for_message(
    message_received: &Arc<tokio::sync::RwLock<Option<String>>>,
    timeout_secs: u64,
) -> Result<Option<String>> {
    let start = std::time::Instant::now();
    let timeout_duration = Duration::from_secs(timeout_secs);

    loop {
        {
            let msg = message_received.read().await;
            if msg.is_some() {
                return Ok(msg.clone());
            }
        }

        if start.elapsed() > timeout_duration {
            return Ok(None);
        }

        sleep(Duration::from_millis(100)).await;
    }
}

/// 空会话监听器（用于测试）
struct EmptyTestConversationListener;

#[async_trait::async_trait]
impl ConversationListener for EmptyTestConversationListener {
    async fn on_sync_server_start(&self, _reinstalled: bool) {}
    async fn on_sync_server_finish(&self, _reinstalled: bool) {}
    async fn on_sync_server_progress(&self, _progress: i32) {}
    async fn on_sync_server_failed(&self, _reinstalled: bool) {}
    async fn on_new_conversation(&self, _conversation_list: String) {}
    async fn on_conversation_changed(&self, _conversation_list: String) {}
    async fn on_total_unread_message_count_changed(&self, _total_unread_count: i32) {}
    async fn on_conversation_user_input_status_changed(&self, _change: String) {}
}

/// 空好友监听器（用于测试）
struct EmptyTestFriendListener;

#[async_trait::async_trait]
impl FriendListener for EmptyTestFriendListener {
    async fn on_friend_list_changed(&self, _friends_json: String) {}
    async fn on_black_list_changed(&self, _blacks_json: String) {}
    async fn on_friend_request_list_changed(&self, _requests_json: String) {}
}

/// 空消息监听器（用于测试）
struct EmptyTestAdvancedMsgListener;

#[async_trait::async_trait]
impl AdvancedMsgListener for EmptyTestAdvancedMsgListener {
    async fn on_recv_new_message(&self, _message: String) {}
    async fn on_recv_c2c_read_receipt(&self, _msg_receipt_list: String) {}
    async fn on_new_recv_message_revoked(&self, _message_revoked: String) {}
    async fn on_recv_offline_new_message(&self, _message: String) {}
    async fn on_msg_deleted(&self, _message: String) {}
    async fn on_recv_online_only_message(&self, _message: String) {}
    async fn on_kicked_offline(&self) {}
    async fn on_connection_status_changed(&self, _connected: bool, _message: String) {}
    async fn on_recv_typing_status(&self, _typing_info: String) {}
}

