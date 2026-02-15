use tokio::time::Duration;
#[derive(Clone, Debug)]
pub struct ClientConfig {
    /// 用户 ID
    pub user_id: String,
    /// 认证 token
    pub token: String,
    /// 平台 ID
    pub platform_id: i32,
    /// WebSocket 服务器 URL
    pub ws_url: String,
    /// 压缩方式，例如 "gzip" 或空字符串表示不压缩
    pub compression: String,
    /// 是否为后台模式
    pub is_background: bool,
    /// 是否需要消息响应
    pub is_msg_resp: bool,
    /// SDK 类型，例如 "js" 或 "go"
    pub sdk_type: String,
    /// HTTP API 基础地址（用于会话同步）
    pub api_base_url: String,
    /// 会话同步使用的本地 SQLite 数据库 URL
    ///
    /// 例如：`sqlite://conversations.db?mode=rwc`
    pub conversation_db_url: String,
    /// 消息响应超时时间
    pub msg_resp_timeout: Duration,
}

impl ClientConfig {
    /// 创建默认配置
    pub fn new(user_id: String, token: String, platform_id: i32) -> Self {
        Self {
            user_id,
            token,
            platform_id,
            ws_url: "ws://localhost:10001".to_string(),
            compression: "gzip".to_string(),
            is_background: false,
            is_msg_resp: true,
            sdk_type: "js".to_string(),
            api_base_url: "http://localhost:10002".to_string(),
            conversation_db_url: "sqlite://conversations.db?mode=rwc".to_string(),
            msg_resp_timeout: Duration::from_secs(10),
        }
    }
}

pub struct Client {
    config: ClientConfig,
}

impl Client {
    pub fn new(config: ClientConfig) -> Self {
        Self { config }
    }
}

use crate::im::client::callbacks::ClientCallbacks;
use crate::im::client::connection_handle::ConnectionHandle;
use crate::im::client::conversation_handle::ConversationHandle;
use crate::im::client::message_handle::{MessageHandle, MsgSyncCommand};
use crate::im::dao::repository::Repository;
use crate::im::friend::FriendListener;
use crate::im::listener::{
    AdvancedMsgListener, ConnListener, ConversationListener, EmptyAdvancedMsgListener,
    EmptyConnListener, EmptyConversationListener,
};
use crate::im::model::conversation::ConversationSyncerConfig;
use crate::im::model::ws::WsRpcEnvelope;
use anyhow::{Context, Result};
use openim_protocol::constant;
use openim_protocol::sdkws;
use std::sync::{Arc, RwLock};
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;
use tracing::{error, info, trace};



/// 核心 IM 逻辑实现
#[derive(Clone)]
pub struct OpenIMClient {
    pub(crate) config: ClientConfig,
    /// 全局回调（连接、会话、消息、好友等），统一由此结构体管理
    callbacks: Arc<RwLock<ClientCallbacks>>,
}

impl OpenIMClient {
    /// 创建新的客户端
    /// - `config`: 客户端配置
    /// - 回调默认为空实现（会输出日志），可通过 set_*_listener 覆盖
    pub fn new(config: ClientConfig) -> Self {
        let callbacks = ClientCallbacks {
            conn_listener: Some(Arc::new(EmptyConnListener)),
            conversation_listener: Some(Arc::new(EmptyConversationListener)),
            advanced_msg_listener: Some(Arc::new(EmptyAdvancedMsgListener)),
            friend_listener: None,
        };
        let client = Self {
            config,
            callbacks: Arc::new(RwLock::new(callbacks)),
        };
        client
    }

    /// 建立一次 WebSocket 连接并完成鉴权握手（不包含 DB/同步器初始化）
    // connect_ws_once 已迁移至 connection.rs

    /// 创建带认证的 HTTP 客户端
    fn create_http_client(config: &ClientConfig) -> Result<reqwest::Client> {
        reqwest::Client::builder()
            .default_headers({
                let mut headers = reqwest::header::HeaderMap::new();
                headers.insert(
                    reqwest::header::HeaderName::from_static("token"),
                    reqwest::header::HeaderValue::from_str(&config.token).context("无效的 token")?,
                );
                headers
            })
            .build()
            .context("创建 HTTP 客户端失败")
    }

    /// 与 Go 一致的 SDK 版本号，用于 local_app_sdk_version 表
    const SDK_VERSION: &str = "3.8.0";

    /// 初始化并运行客户端（WebSocket 连接、消息/会话同步），阻塞直到退出或取消
    pub async fn init(&mut self) -> Result<()> {
        let repo = Repository::create(&self.config.conversation_db_url).await?;
        // 与 Go versionDataMigrate 一致：首次无记录时写入 SDK 版本
        if repo.app_version.get_app_sdk_version().await?.is_none() {
            repo.app_version
                .set_app_sdk_version(&crate::im::LocalAppSDKVersion {
                    version: Self::SDK_VERSION.to_string(),
                    installed: false,
                })
                .await?;
        }
        // 与 Go 一致：确保当前登录用户在 local_users 中有记录（后续用户同步会更新 nickname/face_url）
        if repo.user.get_login_user(&self.config.user_id).await?.is_none() {
            let _ = repo.user.insert_login_user(&crate::im::LocalUser {
                user_id: self.config.user_id.clone(),
                nickname: String::new(),
                face_url: String::new(),
                create_time: 0,
                app_manger_level: 0,
                ex: String::new(),
                attached_info: String::new(),
                global_recv_msg_opt: 0,
            }).await;
        }
        let (connection_tx, connection_rx) = mpsc::unbounded_channel();
        let (msg_sync_cmd_tx, msg_sync_cmd_rx) = mpsc::unbounded_channel();
        let cancel_token = CancellationToken::new();

        let callbacks_snap = self.callbacks.read().unwrap().clone();
        let callbacks = Arc::new(callbacks_snap);

        let mut connection = ConnectionHandle::new(
            self.config.clone(),
            connection_rx,
            msg_sync_cmd_tx.clone(),
            cancel_token.clone(),
            Some(callbacks.clone()),
        );
        let mut connection_handle = tokio::spawn(async move {
            if let Err(e) = connection.auto_connect().await {
                error!("连接失败: {}", e);
            }
        });
        let (msg_sync_event_tx, _msg_sync_event_rx) = mpsc::unbounded_channel();
        let (conv_cmd_tx, conv_cmd_rx) = mpsc::unbounded_channel();
        let http_client_for_conv = Self::create_http_client(&self.config)?;
        let conv_cfg = ConversationSyncerConfig {
            user_id: self.config.user_id.clone(),
            api_base_url: self.config.api_base_url.clone(),
            token: self.config.token.clone(),
            db_path: self.config.conversation_db_url.clone(),
            get_background: None,
        };
        let mut conversation_handle = ConversationHandle::with_listener_and_db_and_client(
            conv_cfg,
            Some(callbacks),
            repo.pool.clone(),
            http_client_for_conv,
            conv_cmd_rx,
            cancel_token.clone(),
        )
        .await?;
        let mut conversation_handle_task = tokio::spawn(async move {
            if let Err(e) = conversation_handle.run().await {
                error!("会话处理器运行失败: {}", e);
            }
        });
        let mut message_syncer = MessageHandle::new(
            self.config.user_id.clone(),
            repo,
            connection_tx,
            cancel_token.clone(),
            msg_sync_event_tx,
            msg_sync_cmd_rx,
            conv_cmd_tx,
        );
        let mut message_syncer_handle = tokio::spawn(async move {
            if let Err(e) = message_syncer.load_seq().await {
                return Err(anyhow::anyhow!("运行消息同步器失败: {}", e));
            }
            if let Err(e) = message_syncer.run().await {
                return Err(anyhow::anyhow!("运行消息同步器失败: {}", e));
            }
            Ok(())
        });
        tokio::select! {
            _ = &mut connection_handle => {
                info!("连接器运行完成，退出客户端");
            }
            _ = &mut message_syncer_handle => {
                info!("消息同步器运行完成，退出客户端");
            }
            _ = &mut conversation_handle_task => {
                info!("会话处理器运行完成，退出客户端");
            }
        }
        cancel_token.cancel();
        Ok(())
    }

    /// 注册连接监听器（对应 Go 的 SetConnListener / OnConnListener）
    pub fn set_conn_listener(&mut self, listener: Arc<dyn ConnListener>) {
        self.callbacks.write().unwrap().conn_listener = Some(listener);
    }

    /// 注册会话监听器
    pub fn set_conversation_listener(&mut self, listener: Arc<dyn ConversationListener>) {
        self.callbacks.write().unwrap().conversation_listener = Some(listener);
    }

    /// 注册好友监听器
    pub fn set_friend_listener(&mut self, listener: Arc<dyn FriendListener>) {
        self.callbacks.write().unwrap().friend_listener = Some(listener);
    }

    /// 注册高级消息监听器（参考 Go 版本的 SetAdvancedMsgListener）
    pub fn set_advanced_msg_listener(&mut self, listener: Arc<dyn AdvancedMsgListener>) {
        self.callbacks.write().unwrap().advanced_msg_listener = Some(listener);
    }
  }