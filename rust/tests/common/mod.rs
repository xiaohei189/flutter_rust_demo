//! IM 集成测试公共模块：登录配置、客户端启动、会话解析与消息构造等
//!
//! 供 `im_client_integration.rs` 等集成测试复用。
//! Token 全进程只登录一次并复用，避免多次登录导致旧 token 失效。

use chrono::Utc;
use futures_util::StreamExt;
use once_cell::sync::Lazy;
use openim_protocol::constant;
use openim_protocol::sdkws;
use rust_lib_flutter_rust_demo::im::client::client::{ClientConfig, IMClient};
use rust_lib_flutter_rust_demo::im::http_client::auth::LoginData;
use rust_lib_flutter_rust_demo::im::{create_text_message, init_basic_info, AdvancedMsgEvent, ConversationEvent, MsgStruct};
use rust_lib_flutter_rust_demo::im::logger::logger::init_logger;
use rust_lib_flutter_rust_demo::login_async;
use std::sync::Arc;
use std::sync::Mutex;
use std::time::Duration;
use tokio::sync::OnceCell;
use tokio::time::{interval, timeout};
use tokio_stream::wrappers::UnboundedReceiverStream;
use tracing::debug;

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

/// 初始化日志（info + debug for lib），需配合 `cargo test -- --nocapture` 查看
pub fn setup_logger() {
    let _ = init_logger("info");
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

/// 创建纯净客户端（不 start、不订阅 stream）。调用方自行 `client.start().await`，需要 stream 时再订阅。
pub async fn create_client(db_suffix: &str) -> anyhow::Result<IMClient> {
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
    let client = IMClient::new(config).await?;
    Ok(client)
}

/// 测试用：缓存所有订阅的会话/消息事件，支持查询并在获取后移除。
pub struct StreamEventCache {
    conv_events: Arc<Mutex<Vec<ConversationEvent>>>,
    msg_events: Arc<Mutex<Vec<AdvancedMsgEvent>>>,
}

impl StreamEventCache {
    pub fn new() -> Self {
        Self {
            conv_events: Arc::new(Mutex::new(Vec::new())),
            msg_events: Arc::new(Mutex::new(Vec::new())),
        }
    }

    /// 从 client 订阅会话/消息流并启动后台任务，将事件写入内部缓存。
    pub fn start_collecting(self: Arc<Self>, client: &IMClient) {
        let mut conv_rx = client.subscribe_conversation_events();
        let mut msg_rx = client.subscribe_advanced_msg_events();
        let conv_events = self.conv_events.clone();
        let msg_events = self.msg_events.clone();
        tokio::spawn(async move {
            loop {
                tokio::select! {
                    Some(ev) = conv_rx.next() => {
                        if let Ok(mut g) = conv_events.lock() {
                            g.push(ev);
                        }
                    }
                    Some(ev) = msg_rx.next() => {
                        if let Ok(mut g) = msg_events.lock() {
                            g.push(ev);
                        }
                    }
                    else => break,
                }
            }
        });
    }

    /// 是否存在 SyncServerFinish(reinstalled:false)，不移除。
    pub fn has_sync_finish(&self) -> bool {
        let g = match self.conv_events.lock() {
            Ok(g) => g,
            Err(_) => return false,
        };
        g.iter()
            .any(|e| matches!(e, ConversationEvent::SyncServerFinish { reinstalled: false }))
    }

    /// 取出并移除第一个 SyncServerFinish(reinstalled:false)，返回是否找到。
    pub fn take_sync_finish(&self) -> bool {
        let mut g = match self.conv_events.lock() {
            Ok(g) => g,
            Err(_) => return false,
        };
        if let Some(pos) = g.iter().position(|e| matches!(e, ConversationEvent::SyncServerFinish { reinstalled: false })) {
            g.remove(pos);
            return true;
        }
        false
    }

    /// 是否存在指定 client_msg_id 的消息事件（RecvNewMessage/RecvOfflineNewMessage/RecvOnlineOnlyMessage），不移除。
    pub fn has_message(&self, client_msg_id: &str) -> bool {
        let g = match self.msg_events.lock() {
            Ok(g) => g,
            Err(_) => return false,
        };
        g.iter().any(|e| {
            let id = match e {
                AdvancedMsgEvent::RecvNewMessage(ms)
                | AdvancedMsgEvent::RecvOfflineNewMessage(ms)
                | AdvancedMsgEvent::RecvOnlineOnlyMessage(ms) => ms.client_msg_id.as_deref(),
                _ => None,
            };
            id == Some(client_msg_id)
        })
    }

    /// 取出并移除第一个匹配 client_msg_id 的消息事件，返回是否找到。
    pub fn take_message_by_id(&self, client_msg_id: &str) -> bool {
        self.take_message_struct_by_id(client_msg_id).is_some()
    }

    /// 取出并移除第一个匹配 client_msg_id 的消息事件，返回其中的 MsgStruct（可从中取 server_msg_id）。
    pub fn take_message_struct_by_id(&self, client_msg_id: &str) -> Option<MsgStruct> {
        let mut g = match self.msg_events.lock() {
            Ok(g) => g,
            Err(_) => return None,
        };
        let pos = g.iter().position(|e| {
            let id = match e {
                AdvancedMsgEvent::RecvNewMessage(ms)
                | AdvancedMsgEvent::RecvOfflineNewMessage(ms)
                | AdvancedMsgEvent::RecvOnlineOnlyMessage(ms) => ms.client_msg_id.as_deref(),
                _ => None,
            };
            id == Some(client_msg_id)
        });
        pos.and_then(|pos| {
            let ev = g.remove(pos);
            match ev {
                AdvancedMsgEvent::RecvNewMessage(ms)
                | AdvancedMsgEvent::RecvOfflineNewMessage(ms)
                | AdvancedMsgEvent::RecvOnlineOnlyMessage(ms) => Some(ms),
                _ => None,
            }
        })
    }

    /// 等待 SyncServerFinish(reinstalled:false) 出现，获取到后移除并返回 Ok(())，超时返回错误。
    pub async fn wait_for_sync_finish(&self, timeout_duration: Duration) -> anyhow::Result<()> {
        let deadline = tokio::time::Instant::now() + timeout_duration;
        let mut ticker = interval(Duration::from_millis(50));
        loop {
            if self.take_sync_finish() {
                return Ok(());
            }
            if tokio::time::Instant::now() >= deadline {
                anyhow::bail!(
                    "等待同步完成超时（{}ms）未收到 SyncServerFinish(false)",
                    timeout_duration.as_millis()
                );
            }
            ticker.tick().await;
        }
    }

    /// 等待指定 client_msg_id 的消息事件出现，获取到后移除并返回 Ok(())，超时返回错误。
    /// 每次轮询前 sleep(50ms)，避免占用 current_thread 调度器导致推送处理 task 无法运行。
    pub async fn wait_for_message(
        &self,
        client_msg_id: &str,
        timeout_duration: Duration,
    ) -> anyhow::Result<()> {
        let id_for_error = client_msg_id.to_string();
        let deadline = tokio::time::Instant::now() + timeout_duration;
        let poll_interval = Duration::from_millis(50);
        loop {
            if self.take_message_by_id(client_msg_id) {
                return Ok(());
            }
            if tokio::time::Instant::now() >= deadline {
                anyhow::bail!(
                    "等待推送超时（{}ms）未收到 client_msg_id={}",
                    timeout_duration.as_millis(),
                    id_for_error
                );
            }
            tokio::time::sleep(poll_interval).await;
        }
    }
}

impl Default for StreamEventCache {
    fn default() -> Self {
        Self::new()
    }
}

/// 从会话事件流中等待 SyncServerFinish(reinstalled=false)，超时返回错误。
pub async fn wait_for_sync_finish(
    mut conv_rx: UnboundedReceiverStream<ConversationEvent>,
    timeout_duration: Duration,
) -> anyhow::Result<()> {
    let res = timeout(
        timeout_duration,
        async move {
            while let Some(ev) = conv_rx.next().await {
                if let ConversationEvent::SyncServerFinish { reinstalled: false } = ev {
                    return Ok(());
                }
            }
            anyhow::bail!("stream closed before SyncServerFinish(false)")
        },
    )
    .await;
    match res {
        Ok(Ok(())) => Ok(()),
        Ok(Err(e)) => Err(e),
        Err(_) => anyhow::bail!(
            "等待同步完成超时（{}ms）未收到 SyncServerFinish(false)",
            timeout_duration.as_millis()
        ),
    }
}

/// 从消息事件流中等待指定 client_msg_id 的推送（RecvNewMessage/RecvOfflineNewMessage/RecvOnlineOnlyMessage），超时返回错误。
pub async fn wait_for_message(
    mut msg_rx: UnboundedReceiverStream<AdvancedMsgEvent>,
    client_msg_id: &str,
    timeout_duration: Duration,
) -> anyhow::Result<()> {
    let id_for_timeout_msg = client_msg_id.to_string();
    let client_msg_id = client_msg_id.to_string();
    let res = timeout(
        timeout_duration,
        async move {
            while let Some(ev) = msg_rx.next().await {
                let id = match &ev {
                    AdvancedMsgEvent::RecvNewMessage(ms)
                    | AdvancedMsgEvent::RecvOfflineNewMessage(ms)
                    | AdvancedMsgEvent::RecvOnlineOnlyMessage(ms) => ms.client_msg_id.as_deref(),
                    _ => None,
                };
                if id.as_deref() == Some(client_msg_id.as_str()) {
                    return Ok(());
                }
            }
            anyhow::bail!("stream closed before message client_msg_id={}", client_msg_id)
        },
    )
    .await;
    match res {
        Ok(Ok(())) => Ok(()),
        Ok(Err(e)) => Err(e),
        Err(_) => anyhow::bail!(
            "等待推送超时（{}ms）未收到 client_msg_id={}",
            timeout_duration.as_millis(),
            id_for_timeout_msg
        ),
    }
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


/// 创建与发送分离：仅构造群文本消息体，不发送。调用方设置后交给 `client.send_message(msg, is_online_only)`。
pub fn build_group_text_msg(user_id: &str, platform_id: i32, group_id: &str, text: &str) -> sdkws::MsgData {
    let mut msg_data = create_text_message(text);
    init_basic_info(&mut msg_data, user_id, platform_id);
    msg_data.group_id = group_id.to_string();
    msg_data.session_type = constant::READ_GROUP_CHAT_TYPE;
    msg_data
}

/// 创建与发送分离：仅构造单聊文本消息体，不发送。调用方设置后交给 `client.send_message(msg, is_online_only)`。
pub fn build_single_text_msg(user_id: &str, platform_id: i32, recv_id: &str, text: &str) -> sdkws::MsgData {
    let mut msg_data = create_text_message(text);
    init_basic_info(&mut msg_data, user_id, platform_id);
    msg_data.recv_id = recv_id.to_string();
    msg_data.session_type = constant::SINGLE_CHAT_TYPE;
    msg_data
}

/// 从会话列表中取第一个群会话，返回 (conversation_id, group_id, conversation_type)。
/// 若无群会话返回 None。
pub fn first_group_from_list(list: &[rust_lib_flutter_rust_demo::LocalConversation]) -> Option<(String, String, i32)> {
    let first = list.iter().find(|c| {
        c.conversation_type == CONVERSATION_TYPE_GROUP || c.conversation_type == CONVERSATION_TYPE_SUPER_GROUP
    })?;
    debug!("first_group_from_list: {:?}", first);
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

