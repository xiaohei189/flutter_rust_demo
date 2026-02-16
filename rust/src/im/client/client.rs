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

use crate::im::api::message::MessageApi;
use crate::im::client::callbacks::ClientCallbacks;
use crate::im::client::connection_handle::ConnectionHandle;
use crate::im::client::conversation_handle::ConversationHandle;
use crate::im::client::message_handle::{MessageHandle, MsgSyncCommand};
use crate::im::dao::repository::Repository;
use crate::im::friend::FriendListener;
use crate::im::listener::{AdvancedMsgListener, ConnListener, ConversationListener, EmptyAdvancedMsgListener, EmptyConnListener, EmptyConversationListener};
use crate::im::model::conversation::ConversationSyncerConfig;
use crate::im::model::message::{send_message_params_to_req, SendMessageParams, SendMsgReq, SendMsgResp};
use crate::im::model::ws::{msg_type, OpenIMReq, WsRpcEnvelope};
use crate::im::util;
use crate::im::ws_rpc;
use anyhow::{Context, Result};
use chrono;
use openim_protocol::constant;
use openim_protocol::sdkws;
use serde_json::json;
use std::sync::{Arc, RwLock};
use openim_protocol::prost::Message;
use tokio::sync::mpsc;
use tokio::task::JoinHandle;
use tokio_util::sync::CancellationToken;
use tracing::{error, info, trace};
use uuid::Uuid;

/// 发送消息 WS 等待响应超时（秒）
const SEND_MSG_WS_TIMEOUT_SECS: u64 = 10;

/// 核心 IM 逻辑实现
#[derive(Clone)]
pub struct IMClient {
    pub(crate) config: ClientConfig,
    /// 全局回调（连接、会话、消息、好友等），统一由此结构体管理
    callbacks: Arc<RwLock<ClientCallbacks>>,
    /// WebSocket RPC 发送端；在 start() 中设置，用于通过长连发送消息（直接使用变量，不通过参数传递）
    ws_send_tx: Arc<RwLock<Option<mpsc::UnboundedSender<WsRpcEnvelope>>>>,
    /// start() 内运行循环的 JoinHandle，用于 wait_for_exit() 阻塞等待退出
    run_handle: Arc<RwLock<Option<JoinHandle<Result<()>>>>>,
}

impl IMClient {
    /// 与 Go 一致的 SDK 版本号，用于 local_app_sdk_version 表
    const SDK_VERSION: &str = "3.8.0";
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
        Self {
            config,
            callbacks: Arc::new(RwLock::new(callbacks)),
            ws_send_tx: Arc::new(RwLock::new(None)),
            run_handle: Arc::new(RwLock::new(None)),
        }
    }
}

impl IMClient {
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

    /// 启动客户端（WebSocket 连接、消息/会话同步），非阻塞；运行循环在后台执行
    pub async fn start(&mut self) -> Result<()> {
        let repo = Repository::create(&self.config.conversation_db_url).await?;
        if repo.app_version.get_app_sdk_version().await?.is_none() {
            repo.app_version
                .set_app_sdk_version(&crate::im::LocalAppSDKVersion {
                    version: Self::SDK_VERSION.to_string(),
                    installed: false,
                })
                .await?;
        }
        if repo.user.get_login_user(&self.config.user_id).await?.is_none() {
            let _ = repo
                .user
                .insert_login_user(&crate::im::LocalUser {
                    user_id: self.config.user_id.clone(),
                    nickname: String::new(),
                    face_url: String::new(),
                    create_time: 0,
                    app_manger_level: 0,
                    ex: String::new(),
                    attached_info: String::new(),
                    global_recv_msg_opt: 0,
                })
                .await;
        }
        let (ws_tx, connection_rx) = mpsc::unbounded_channel();
        let _ = self.ws_send_tx.write().unwrap().insert(ws_tx.clone());
        let (msg_sync_cmd_tx, msg_sync_cmd_rx) = mpsc::unbounded_channel();
        let cancel_token = CancellationToken::new();

        let callbacks_snap = self.callbacks.read().unwrap().clone();
        let callbacks = Arc::new(callbacks_snap);
        let config = self.config.clone();
        let ws_send_tx = self.ws_send_tx.clone();

        let run_handle = tokio::spawn(async move {
            let mut connection = ConnectionHandle::new(config.clone(), connection_rx, msg_sync_cmd_tx.clone(), cancel_token.clone(), Some(callbacks.clone()));
            let mut connection_handle = tokio::spawn(async move {
                if let Err(e) = connection.auto_connect().await {
                    error!("连接失败: {}", e);
                }
            });
            let (msg_sync_event_tx, _msg_sync_event_rx) = mpsc::unbounded_channel();
            let (conv_cmd_tx, conv_cmd_rx) = mpsc::unbounded_channel();
            let http_client_for_conv = match IMClient::create_http_client(&config) {
                Ok(c) => c,
                Err(e) => {
                    error!("创建 HTTP 客户端失败: {}", e);
                    cancel_token.cancel();
                    return Err(anyhow::anyhow!("create_http_client: {}", e));
                }
            };
            let conv_cfg = ConversationSyncerConfig {
                user_id: config.user_id.clone(),
                api_base_url: config.api_base_url.clone(),
                token: config.token.clone(),
                db_path: config.conversation_db_url.clone(),
                get_background: None,
            };
            let mut conversation_handle =
                match ConversationHandle::with_listener_and_db_and_client(conv_cfg, Some(callbacks), repo.pool.clone(), http_client_for_conv, conv_cmd_rx, cancel_token.clone()).await {
                    Ok(h) => h,
                    Err(e) => {
                        error!("会话处理器初始化失败: {}", e);
                        cancel_token.cancel();
                        return Err(e);
                    }
                };
            let mut conversation_handle_task = tokio::spawn(async move {
                if let Err(e) = conversation_handle.run().await {
                    error!("会话处理器运行失败: {}", e);
                }
            });
            let mut message_syncer = MessageHandle::new(
                config.user_id.clone(),
                repo,
                ws_send_tx,
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
        });
        let _ = self.run_handle.write().unwrap().insert(run_handle);
        Ok(())
    }

    /// 阻塞等待客户端运行循环退出；若未调用 start 或已等待过则立即返回
    pub async fn wait_for_exit(&self) -> Result<()> {
        let handle = self.run_handle.write().unwrap().take();
        if let Some(h) = handle {
            h.await.map_err(|e| anyhow::anyhow!("run task join error: {}", e))?
        } else {
            Ok(())
        }
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

    /// 发送消息（入口与 Go SendMessage 一致：先 Default 再显式填值）；优先 WebSocket，否则 HTTP
    pub async fn send_message(&self, params: SendMessageParams) -> Result<SendMsgResp> {
        let req = send_message_params_to_req(&params, self.config.user_id.clone());
        if let Some(tx) = self.ws_send_tx.read().unwrap().as_ref() {
            if let Ok(resp) = self.send_message_via_ws(tx.clone(), &req).await {
                return Ok(resp);
            }
            trace!("WS 发送失败或超时，回退 HTTP");
        }
        let raw = IMClient::create_http_client(&self.config)?;
        let api = MessageApi::new(
            raw,
            self.config.api_base_url.clone(),
            self.config.user_id.clone(),
            &self.config.token,
        );
        api.send_message(req).await
    }

    /// 通过 WebSocket 发送消息（req_identifier=1003），使用公共 ws_rpc 工具
    async fn send_message_via_ws(&self, tx: mpsc::UnboundedSender<WsRpcEnvelope>, req: &SendMsgReq) -> Result<SendMsgResp> {
        let msg_data = send_msg_req_to_ws_msg_data(req)?;
        let data = msg_data.encode_to_vec();
        let open_req = OpenIMReq {
            req_identifier: msg_type::WS_SEND_MSG,
            token: self.config.token.clone(),
            send_id: self.config.user_id.clone(),
            operation_id: util::make_operation_id(),
            msg_incr: util::make_msg_incr(),
            data,
        };
        let ws_resp = ws_rpc::send_ws_req_wait(&tx, open_req, Duration::from_secs(SEND_MSG_WS_TIMEOUT_SECS)).await?;
        let pb = ws_rpc::decode_ws_resp::<openim_protocol::msg::SendMsgResp>(&ws_resp)?;
        Ok(SendMsgResp {
            server_msg_id: pb.server_msg_id,
            client_msg_id: pb.client_msg_id,
            send_time: pb.send_time,
            modify: None,
        })
    }

    /// 单聊发送文本消息（Default + 显式填值）
    pub async fn send_text_message(&self, recv_id: String, text: String) -> Result<SendMsgResp> {
        let mut params = SendMessageParams::default();
        params.operation_id = util::make_operation_id();
        params.message = json!({ "text": { "content": text } }).to_string();
        params.recv_id = recv_id;
        params.content_type = constant::TEXT;
        params.session_type = constant::SINGLE_CHAT_TYPE;
        self.send_message(params).await
    }

    /// 群聊发送文本消息（Default + 显式填值）
    pub async fn send_text_to_group(&self, group_id: String, text: String) -> Result<SendMsgResp> {
        let mut params = SendMessageParams::default();
        params.operation_id = util::make_operation_id();
        params.message = json!({ "text": { "content": text } }).to_string();
        params.group_id = group_id;
        params.content_type = constant::TEXT;
        params.session_type = constant::READ_GROUP_CHAT_TYPE;
        self.send_message(params).await
    }
}

/// 将 HTTP 风格的 SendMsgReq 转为 WS 使用的 sdkws::MsgData（protobuf）
fn send_msg_req_to_ws_msg_data(req: &SendMsgReq) -> Result<sdkws::MsgData> {
    let client_msg_id = Uuid::new_v4().to_string();
    let content = serde_json::to_vec(&req.content).unwrap_or_default();
    let create_time = chrono::Utc::now().timestamp_millis();
    let mut options = std::collections::HashMap::new();
    if req.is_online_only {
        options.insert("isHistory".to_string(), false);
        options.insert("isPersistent".to_string(), false);
    }
    Ok(sdkws::MsgData {
        send_id: req.send_id.clone(),
        recv_id: req.recv_id.clone().unwrap_or_default(),
        group_id: req.group_id.clone().unwrap_or_default(),
        client_msg_id,
        server_msg_id: String::new(),
        sender_platform_id: req.sender_platform_id.unwrap_or(0),
        sender_nickname: req.sender_nickname.clone().unwrap_or_default(),
        sender_face_url: req.sender_face_url.clone().unwrap_or_default(),
        session_type: req.session_type,
        msg_from: constant::USER_MSG_TYPE,
        content_type: req.content_type,
        content,
        seq: 0,
        send_time: req.send_time.unwrap_or(0),
        create_time,
        status: 0,
        is_read: false,
        options,
        offline_push_info: None,
        at_user_id_list: vec![],
        attached_info: String::new(),
        ex: req.ex.clone().unwrap_or_default(),
    })
}
