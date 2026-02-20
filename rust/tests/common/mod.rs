//! IM 集成测试公共模块：登录配置、客户端启动、会话解析与消息构造等
//!
//! 供 `im_client_integration.rs` 等集成测试复用。
//! Token 全进程只登录一次并复用，避免多次登录导致旧 token 失效。

use chrono::Utc;
use futures_util::StreamExt;
use once_cell::sync::Lazy;
use rust_lib_flutter_rust_demo::im::client::client::{ClientConfig, IMClient};
use rust_lib_flutter_rust_demo::im::http_client::auth::LoginData;
use rust_lib_flutter_rust_demo::im::{AdvancedMsgEvent, ConversationEvent};
use rust_lib_flutter_rust_demo::im::logger::logger::init_logger;
use rust_lib_flutter_rust_demo::login_async;
use std::sync::{Arc, RwLock};
use std::time::Duration;
use tokio::sync::{oneshot, OnceCell};

/// 全进程只初始化一次的登录 token，供各 test 复用
static TOKEN: Lazy<OnceCell<LoginData>> = Lazy::new(OnceCell::new);

/// 获取或初始化 token（首次调用执行登录，后续直接返回缓存）
async fn get_or_init_token() -> anyhow::Result<&'static LoginData> {
    Ok(TOKEN
        .get_or_init(|| {
            async {
                login_async(
                    DEFAULT_AREA_CODE.to_string(),
                    DEFAULT_PHONE.to_string(),
                    DEFAULT_PASSWORD.to_string(),
                    DEFAULT_PLATFORM,
                )
                .await
                .expect("integration test login failed")
            }
        })
        .await)
}

/// 与 bin/im_client 一致的默认测试密码
pub const DEFAULT_PASSWORD: &str = "284f3d09ea0695538e4ded1c1766d73a";

/// 会话类型：1=单聊, 2=普通群聊, 3=超级群聊, 4=通知会话（不发消息）
pub const CONVERSATION_TYPE_SINGLE: i32 = 1;
pub const CONVERSATION_TYPE_GROUP: i32 = 2;
pub const CONVERSATION_TYPE_SUPER_GROUP: i32 = 3;

/// 默认测试账号与 API 配置
pub const DEFAULT_AREA_CODE: &str = "+86";
pub const DEFAULT_PHONE: &str = "17764338283";
pub const DEFAULT_PLATFORM: i32 = 5;
pub const SYNC_WAIT_SECS: u64 = 3;
pub const EXIT_TIMEOUT_SECS: u64 = 3;
/// 发送消息后等待服务端推送落库的时间（秒）
pub const PUSH_WAIT_SECS: u64 = 10;

/// 后台任务：消费会话与消息事件并通知 ExpectSyncListener / ExpectMsgListener
fn spawn_event_forwarder(
    mut conv_rx: tokio_stream::wrappers::UnboundedReceiverStream<ConversationEvent>,
    mut msg_rx: tokio_stream::wrappers::UnboundedReceiverStream<AdvancedMsgEvent>,
    sync_listener: Arc<ExpectSyncListener>,
    msg_listener: Arc<ExpectMsgListener>,
) {
    tokio::spawn(async move {
        loop {
            tokio::select! {
                Some(ev) = conv_rx.next() => {
                    if let ConversationEvent::SyncServerFinish { reinstalled: false } = ev {
                        sync_listener.try_complete_sync();
                    }
                }
                Some(ev) = msg_rx.next() => {
                    let id = match &ev {
                        AdvancedMsgEvent::RecvNewMessage(ms)
                        | AdvancedMsgEvent::RecvOfflineNewMessage(ms)
                        | AdvancedMsgEvent::RecvOnlineOnlyMessage(ms) => ms.client_msg_id.as_deref(),
                        _ => None,
                    };
                    if let Some(id) = id {
                        try_notify_pending_id(&msg_listener.state, id);
                    }
                }
                else => break,
            }
        }
    });
}

/// 初始化日志（info + debug for lib），需配合 `cargo test -- --nocapture` 查看
pub fn setup_logger() {
    let _ = init_logger("info,rust_lib_flutter_rust_demo=debug");
}

/// 登录并创建已启动的客户端与 self_user_id；等待 SYNC_WAIT_SECS 以便同步完成。
/// 使用全进程复用的 token，每个 case 仍是独立客户端与连接，但只登录一次。
pub async fn create_and_start_client(db_suffix: &str) -> anyhow::Result<(IMClient, String)> {
    let token_info = get_or_init_token().await?;
    let mut config = ClientConfig::new(
        token_info.user_id.clone(),
        token_info.im_token.clone(),
        DEFAULT_PLATFORM,
    );
    config.conversation_db_url = format!(
        "sqlite://{}/conversations_test_{}.db?mode=rwc",
        std::env::temp_dir().as_path().to_string_lossy(),
        db_suffix
    );
    let self_user_id = config.user_id.clone();
    let mut client = IMClient::new(config).await?;
    client.start().await?;
    tokio::time::sleep(Duration::from_secs(SYNC_WAIT_SECS)).await;
    Ok((client, self_user_id))
}

/// 创建客户端并订阅会话/消息 Stream 后再 start，供“发消息后等推送”的用例使用。
/// 使用 ExpectSyncListener 等待同步完成。
pub async fn create_and_start_client_with_msg_listener(
    db_suffix: &str,
) -> anyhow::Result<(IMClient, String, Arc<ExpectMsgListener>)> {
    let token_info = get_or_init_token().await?;
    let mut config = ClientConfig::new(
        token_info.user_id.clone(),
        token_info.im_token.clone(),
        DEFAULT_PLATFORM,
    );
    config.conversation_db_url = format!(
        "sqlite://{}/conversations_test_{}.db?mode=rwc",
        std::env::temp_dir().as_path().to_string_lossy(),
        db_suffix
    );
    let self_user_id = config.user_id.clone();
    let msg_listener = Arc::new(ExpectMsgListener::new());
    let sync_listener = Arc::new(ExpectSyncListener::new());
    let mut client = IMClient::new(config).await?;
    let conv_rx = client.subscribe_conversation_events();
    let msg_rx = client.subscribe_advanced_msg_events();
    spawn_event_forwarder(conv_rx, msg_rx, sync_listener.clone(), msg_listener.clone());
    client.start().await?;
    sync_listener
        .wait_for_sync_finish(Duration::from_secs(SYNC_WAIT_SECS))
        .await?;
    Ok((client, self_user_id, msg_listener))
}

/// 创建客户端并订阅会话/消息 Stream，供“等同步完成 + 发消息后等推送”的用例使用。
/// 不在此处等待，由调用方显式调用 sync_listener.wait_for_sync_finish() 后再查询会话/发送消息。
pub async fn create_and_start_client_with_sync_and_msg_listener(
    db_suffix: &str,
) -> anyhow::Result<(IMClient, String, Arc<ExpectSyncListener>, Arc<ExpectMsgListener>)> {
    let token_info = get_or_init_token().await?;
    let mut config = ClientConfig::new(
        token_info.user_id.clone(),
        token_info.im_token.clone(),
        DEFAULT_PLATFORM,
    );
    config.conversation_db_url = format!(
        "sqlite://{}/conversations_test_{}.db?mode=rwc",
        std::env::temp_dir().as_path().to_string_lossy(),
        db_suffix
    );
    let self_user_id = config.user_id.clone();
    let sync_listener = Arc::new(ExpectSyncListener::new());
    let msg_listener = Arc::new(ExpectMsgListener::new());
    let mut client = IMClient::new(config).await?;
    let conv_rx = client.subscribe_conversation_events();
    let msg_rx = client.subscribe_advanced_msg_events();
    spawn_event_forwarder(conv_rx, msg_rx, sync_listener.clone(), msg_listener.clone());
    client.start().await?;
    Ok((client, self_user_id, sync_listener, msg_listener))
}

/// 生成带格式化时间的测试消息（用于文本消息）
pub fn test_message_with_time(tag: &str) -> String {
    format!(
        "[集成测试] {} {}",
        Utc::now().format("%Y-%m-%d %H:%M:%S"),
        tag
    )
}

/// 从 conversation_id 解析出单聊对方 user_id（与 OpenIM 约定一致：si_userA_userB）
pub fn parse_single_recv_id(conversation_id: &str, self_user_id: &str) -> Option<String> {
    let rest = conversation_id.strip_prefix("si_")?;
    let parts: Vec<&str> = rest.splitn(2, '_').collect();
    if parts.len() >= 2 {
        let a = parts[0];
        let b = parts[1];
        if a == self_user_id {
            return Some(b.to_string());
        }
        if b == self_user_id {
            return Some(a.to_string());
        }
        return Some(b.to_string());
    }
    if parts.len() == 1 && !parts[0].is_empty() && parts[0] != self_user_id {
        return Some(parts[0].to_string());
    }
    None
}

/// 从 conversation_id 解析出群聊 group_id（sg_groupID）
pub fn parse_group_id(conversation_id: &str) -> Option<String> {
    conversation_id
        .strip_prefix("sg_")
        .filter(|s| !s.is_empty())
        .map(String::from)
}


/// 从会话列表中取第一个群会话，返回 (conversation_id, group_id, conversation_type)。
/// 若无群会话返回 None。
pub fn first_group_from_list(list: &[rust_lib_flutter_rust_demo::LocalConversation]) -> Option<(String, String, i32)> {
    let first = list.iter().find(|c| {
        c.conversation_type == CONVERSATION_TYPE_GROUP || c.conversation_type == CONVERSATION_TYPE_SUPER_GROUP
    })?;
    let group_id = first
        .group_id
        .is_empty()
        .then(|| parse_group_id(&first.conversation_id))
        .flatten()
        .or_else(|| Some(first.group_id.clone()).filter(|s| !s.is_empty()))?;
    Some((
        first.conversation_id.clone(),
        group_id,
        first.conversation_type,
    ))
}

// ---------- 通用“等指定消息回调再继续、超时则报错”监听器 ----------

/// 内部状态：当前等待的 client_msg_id 与 oneshot 发送端
type PendingMsg = (String, oneshot::Sender<()>);

/// 可复用的消息监听器：在回调里匹配 client_msg_id，匹配则通知等待方，收到即继续，超时则报错。
pub struct ExpectMsgListener {
    state: Arc<RwLock<Option<PendingMsg>>>,
}

impl ExpectMsgListener {
    pub fn new() -> Self {
        Self {
            state: Arc::new(RwLock::new(None)),
        }
    }

    /// 等待指定 client_msg_id 的推送事件，超时返回错误。
    /// 应在发送消息后立即调用（先 subscribe_advanced_msg_events 再 send 再本方法）。
    pub async fn wait_for_message(
        &self,
        client_msg_id: &str,
        timeout_duration: Duration,
    ) -> anyhow::Result<()> {
        let (tx, rx) = oneshot::channel();
        {
            let mut g = self.state.write().unwrap();
            *g = Some((client_msg_id.to_string(), tx));
        }
        match tokio::time::timeout(timeout_duration, rx).await {
            Ok(Ok(())) => Ok(()),
            Ok(Err(e)) => anyhow::bail!("等待推送 channel 关闭: {}", e),
            Err(_) => anyhow::bail!("等待推送超时（{}ms）未收到 client_msg_id={}", timeout_duration.as_millis(), client_msg_id),
        }
    }
}

impl Default for ExpectMsgListener {
    fn default() -> Self {
        Self::new()
    }
}

/// 收到指定 client_msg_id 时触发等待方
fn try_notify_pending_id(state: &RwLock<Option<PendingMsg>>, client_msg_id: &str) {
    let mut g = state.write().unwrap();
    if let Some((expected, tx)) = g.take() {
        if expected == client_msg_id {
            let _ = tx.send(());
        } else {
            *g = Some((expected, tx));
        }
    }
}

// ---------- 会话同步 + 消息同步回调等待监听器 ----------

/// 可复用的同步等待器：收到 SyncServerFinish(reinstalled=false) 时通知等待方。
pub struct ExpectSyncListener {
    state: Arc<RwLock<Option<oneshot::Sender<()>>>>,
}

impl ExpectSyncListener {
    pub fn new() -> Self {
        Self {
            state: Arc::new(RwLock::new(None)),
        }
    }

    /// 由事件转发任务调用
    pub fn try_complete_sync(&self) {
        let mut g = self.state.write().unwrap();
        if let Some(tx) = g.take() {
            let _ = tx.send(());
        }
    }

    /// 等待消息同步完成（SyncServerFinish(reinstalled=false)），超时返回错误。
    pub async fn wait_for_sync_finish(
        &self,
        timeout_duration: Duration,
    ) -> anyhow::Result<()> {
        let (tx, rx) = oneshot::channel();
        {
            let mut g = self.state.write().unwrap();
            *g = Some(tx);
        }
        match tokio::time::timeout(timeout_duration, rx).await {
            Ok(Ok(())) => Ok(()),
            Ok(Err(e)) => anyhow::bail!("等待同步 channel 关闭: {}", e),
            Err(_) => anyhow::bail!(
                "等待同步完成超时（{}ms）未收到 SyncServerFinish(false)",
                timeout_duration.as_millis()
            ),
        }
    }
}

impl Default for ExpectSyncListener {
    fn default() -> Self {
        Self::new()
    }
}
