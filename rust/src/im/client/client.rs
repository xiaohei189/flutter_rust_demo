//! OpenIM 客户端核心实现模块
//!
//! 此模块包含 OpenIM 客户端的核心逻辑实现。

use crate::im::client::api::OpenIMClientApi;
use crate::im::client::config::ClientConfig;
use crate::im::client::reconnect::{ConnectFatalError, ReconnectStrategy};
use crate::im::client::seq_cache::ConversationSeqContextCache;
use crate::im::conversation::service::ConversationSyncer;
use crate::im::dao::MessageRepo;
use crate::im::db::db::create_sqlite_pool_with_migration;
use crate::im::friend::{FriendListener, FriendSyncer, FriendSyncerConfig};
use crate::im::listener::{AdvancedMsgListener, ConversationListener};
use crate::im::message::BinaryMessageHandler;
use crate::im::model::conversation::ConversationSyncerConfig;
use crate::im::model::message::{AtElem, AtInfo, CustomElem, FileElem, LocationElem, MarkdownTextElem, MsgStruct, PictureElem, QuoteElem, SeqRange as SeqRangeModel, SoundElem, VideoElem};
use crate::im::model::ws::CommandMessage;
use crate::im::model::{LocalConversation, OpenIMResp};
use crate::im::serialization::{decompress_gzip, generate_msg_id};
use crate::im::WebSocketConnectResp;
use anyhow::{Context, Result};
use futures_util::future::select_all;
use futures_util::stream::{SplitSink, SplitStream};
use futures_util::StreamExt;
use openim_protocol::constant;
use openim_protocol::sdkws;
use sqlx::{Pool, Sqlite};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::runtime::Runtime;
use tokio::sync::mpsc::Receiver;
use tokio::sync::{oneshot, Mutex};
use tokio::time::interval;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tokio_tungstenite::WebSocketStream;
use tokio_tungstenite::{connect_async, MaybeTlsStream};
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info, warn};

/// WebSocket 写入端类型别名
pub type WsWriter = SplitSink<WebSocketStream<MaybeTlsStream<TcpStream>>, WsMessage>;

/// WebSocket 读取端类型别名
pub type WsReader = SplitStream<WebSocketStream<MaybeTlsStream<TcpStream>>>;


/// 下行到 long_conn_mgr 的 RPC 请求，携带 oneshot 回复
#[derive(Debug)]
pub enum LongConnRpcCommand {
    GetNewestSeq {
        resp: oneshot::Sender<Result<sdkws::GetMaxSeqResp>>,
    },
    PullMsgByRange {
        ranges: Vec<SeqRangeModel>,
        resp: oneshot::Sender<Result<sdkws::PullMessageBySeqsResp>>,
    },
}
/// WS RPC 挂起请求：保存回执通道与发送时间
pub(crate) struct PendingRpc {
    pub(crate) tx: oneshot::Sender<OpenIMResp>,
    pub(crate) sent_at: std::time::Instant,
}

/// OpenIM 客户端
#[derive(Clone, Default)]
pub struct AppState {
    // 共享数据库连接池（用于会话和好友同步器）
    db: Option<Arc<Pool<Sqlite>>>,
    // 消息存储（本地 SQLite，sqlx 驱动）
    pub(crate) message_store: Option<Arc<MessageRepo>>,
    // 会话同步器（用于基于消息通知实时更新会话）
    pub(crate) conversation_syncer: Option<Arc<ConversationSyncer>>,
    // 好友同步器（用于联系人列表增量同步）
    pub(crate) friend_syncer: Option<Arc<FriendSyncer>>,
    // 高级消息监听器（可由调用方注册，参考 Go 版本的 OnAdvancedMsgListener）
    pub(crate) advanced_msg_listener: Option<Arc<dyn AdvancedMsgListener>>,
}

/// 核心 IM 逻辑实现
#[derive(Clone)]
pub struct OpenIMClient {
    pub(crate) config: ClientConfig,
    pub(crate) app_state: AppState,
    // WebSocket 消息发送通道（供其他模块使用，不直接暴露 writer）
    pub(crate) ws_message_tx: Arc<Mutex<Option<tokio::sync::mpsc::Sender<WsMessage>>>>,
    pub(crate) received_msg_ids: Arc<std::sync::Mutex<std::collections::HashSet<String>>>,
    pub(crate) pending_rpc: Arc<Mutex<HashMap<String, PendingRpc>>>,

    // 共享数据库连接池（用于会话和好友同步器）
    db: Option<Arc<Pool<Sqlite>>>,

    // 会话同步器（用于基于消息通知实时更新会话）
    pub(crate) conversation_syncer: Option<Arc<ConversationSyncer>>,
    // 好友同步器（用于联系人列表增量同步）
    pub(crate) friend_syncer: Option<Arc<FriendSyncer>>,

    // 会话监听器（可由调用方注册）
    conversation_listener: Option<Arc<dyn ConversationListener>>,
    // 好友监听器（可由调用方注册）
    friend_listener: Option<Arc<dyn FriendListener>>,
    // 高级消息监听器（可由调用方注册，参考 Go 版本的 OnAdvancedMsgListener）
    pub(crate) advanced_msg_listener: Option<Arc<dyn AdvancedMsgListener>>,

    // 消息存储（本地 SQLite，sqlx 驱动）
    pub(crate) message_store: Option<Arc<MessageRepo>>,
    // 重连策略（指数退避）
    reconnect_strategy: Arc<ReconnectStrategy>,
    // 消息拉取前向结束序列号映射（完全参考 Go SDK 的 messagePullForwardEndSeqMap）
    message_pull_forward_end_seq_map: ConversationSeqContextCache,
    // 消息拉取反向结束序列号映射（完全参考 Go SDK 的 messagePullReverseEndSeqMap）
    message_pull_reverse_end_seq_map: ConversationSeqContextCache,
}

impl OpenIMClient {
    /// 创建新的客户端
    /// - `config`: 客户端配置
    pub fn new(config: ClientConfig) -> Self {
        let pending = Arc::new(Mutex::new(HashMap::new()));
        let client = Self {
            config,
            ws_message_tx: Arc::new(Mutex::new(None)),
            received_msg_ids: Arc::new(std::sync::Mutex::new(std::collections::HashSet::new())),
            conversation_syncer: None,
            friend_syncer: None,
            conversation_listener: None,
            friend_listener: None,
            advanced_msg_listener: None,
            message_store: None,
            db: None,
            reconnect_strategy: Arc::new(ReconnectStrategy::new()),
            message_pull_forward_end_seq_map: ConversationSeqContextCache::new(),
            message_pull_reverse_end_seq_map: ConversationSeqContextCache::new(),
            pending_rpc: pending,
            app_state: AppState::default(),
        };
        client
    }

    async fn init(&mut self) -> Result<()> {
        self.initialize_resources().await?;
        Ok(())
    }

    /// 获取推送消息处理器上下文（供 BinaryMessageHandler 使用）
    pub(crate) fn get_push_message_handler_context(&self) -> Result<crate::im::message::binary_handler::PushMessageHandlerContext> {
        use crate::im::message::binary_handler::PushMessageHandlerContext;
        use crate::im::message::handler::MessageHandlerContext;

        let message_store = self.message_store.as_ref().ok_or_else(|| anyhow::anyhow!("消息存储未初始化"))?;

        let handler_ctx = MessageHandlerContext::new(self.config.user_id.clone(), message_store.clone(), self.advanced_msg_listener.clone(), self.conversation_syncer.clone());

        let is_duplicate = self.received_msg_ids.clone();
        Ok(PushMessageHandlerContext {
            message_handler_ctx: None,
            is_duplicate_message: Box::new(move |msg_id: &str| {
                let mut set = is_duplicate.lock().unwrap();
                !set.insert(msg_id.to_string())
            }),
            conversation_syncer: self.conversation_syncer.clone(),
        })
    }

    /// 构建 WebSocket 连接 URL
    pub(crate) fn connect_url(&self) -> String {
        let compression_param = if self.config.compression.is_empty() {
            String::new()
        } else {
            format!("&compression={}", self.config.compression)
        };

        format!(
            "{}/?token={}&sendID={}&platformID={}&operationID={}{}&isBackground={}&isMsgResp={}&sdkType={}",
            self.config.ws_url,
            self.config.token,
            self.config.user_id,
            self.config.platform_id,
            OpenIMClient::make_operation_id(),
            compression_param,
            self.config.is_background,
            self.config.is_msg_resp,
            self.config.sdk_type
        )
    }

    async fn init_friend_syncer(&mut self) -> Result<()> {
        let friend_cfg = FriendSyncerConfig {
            user_id: self.config.user_id.clone(),
            api_base_url: self.config.api_base_url.clone(),
            token: self.config.token.clone(),
            db_path: self.config.conversation_db_url.clone(),
        };
        let friend_syncer = Arc::new(FriendSyncer::new(friend_cfg, self.db.clone().unwrap(), self.friend_listener.clone()).await?);
        friend_syncer.clone().spawn_incr_sync();
        self.friend_syncer = Some(friend_syncer);
        Ok(())
    }

    /// 建立一次 WebSocket 连接并完成鉴权握手（不包含 DB/同步器初始化）
    // connect_ws_once 已迁移至 connection.rs

    /// 初始化数据库连接池
    async fn init_database(config: &ClientConfig) -> Result<Arc<Pool<Sqlite>>> {
        info!("[Client] 🔗 创建共享 SQLite 连接池并执行迁移: {}", config.conversation_db_url);
        let pool = create_sqlite_pool_with_migration(&config.conversation_db_url).await?;
        let db = Arc::new(pool);
        Ok(db)
    }

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

    /// 初始化会话同步器
    async fn init_conversation_syncer(
        config: &ClientConfig,
        db: Arc<Pool<Sqlite>>,
        http_client: reqwest::Client,
        conversation_listener: Option<Arc<dyn ConversationListener>>,
    ) -> Result<Arc<ConversationSyncer>> {
        let cfg = ConversationSyncerConfig {
            user_id: config.user_id.clone(),
            api_base_url: config.api_base_url.clone(),
            token: config.token.clone(),
            db_path: config.conversation_db_url.clone(),
        };
        let syncer = Arc::new(ConversationSyncer::with_listener_and_db_and_client(cfg, conversation_listener, db.clone(), http_client).await?);
        Ok(syncer)
    }

 

    /// 启动消息处理和重连任务
    pub async fn connect_with_reconnect(&self) -> Result<()> {
        let mut reconnect_count = 0;
        loop {
            if let Err(e) = self.connect().await {
                error!("[Client] 连接失败: {}", e);
            }
            // 断线后按 Go 版逻辑进行带退避的重连
            let wait = self.reconnect_strategy.next_interval();
            reconnect_count += 1;
            info!("[Client] 尝试重连，等待 {:?} 后重试（指数退避），重连次数: {}", wait, reconnect_count);
            tokio::time::sleep(wait).await;
        }
    }

    pub(crate) async fn connect(&self) -> Result<()> {
        let (tx, rx) = tokio::sync::mpsc::channel(100);
        let url = self.connect_url();
        debug!("[Client] 🔗 WebSocket 连接 URL: {}", url);
        let (ws_stream, response) = connect_async(&url).await?;
        info!("[Client] ✅ WebSocket 连接成功, 状态: {}", response.status());
        let (writer, mut read) = ws_stream.split();

        if let Some(Ok(WsMessage::Text(text))) = read.next().await {
            match serde_json::from_str::<WebSocketConnectResp>(&text) {
                Ok(resp) => {
                    if resp.err_code == 0 {
                        info!("[Client] ✅ 服务器连接鉴权成功");
                        let listener = self.advanced_msg_listener.clone();
                        tokio::spawn(async move {
                            if let Some(listener) = &listener {
                                listener.on_connection_status_changed(true, "连接成功".to_string()).await;
                            }
                        });
                    } else {
                        let error_msg = if !resp.err_dlt.is_empty() {
                            format!("{} (详情: {})", resp.err_msg, resp.err_dlt)
                        } else {
                            resp.err_msg.clone()
                        };
                        error!("[Client] ❌ WebSocket 连接失败，错误码: {}, 错误信息: {}", resp.err_code, error_msg);

                        let listener = self.advanced_msg_listener.clone();
                        let msg_for_cb = format!("WebSocket 鉴权失败, code={}, msg={}", resp.err_code, error_msg);
                        tokio::spawn(async move {
                            if let Some(listener) = &listener {
                                listener.on_connection_status_changed(false, msg_for_cb).await;
                            }
                        });

                        return Err(anyhow::anyhow!(error_msg));
                    }
                }
                Err(e) => {
                    error!("[Client] ❌ WebSocket 响应解析失败: {}, 原始响应: {}", e, text);
                    return Err(anyhow::anyhow!("WebSocket 响应解析失败: {}, 原始响应: {}", e, text));
                }
            }
        } else {
            error!("[Client] ❌ 未收到 WebSocket 连接响应");
            return Err(anyhow::anyhow!("未收到 WebSocket 连接响应"));
        }

        // 创建统一的取消令牌，用于协调所有任务的退出
        let cancel_token = CancellationToken::new();

        // 发送任务：从通道接收消息并写入 socket
        let send_task = self.send_message_loop(cancel_token.clone(), writer, rx);
        // 接收任务：从 socket 读取消息并处理
        let recv_task = self.recv_message_loop(cancel_token.clone(), read);
        // 心跳任务：定期通过 tx 发送 Ping 消息
        let heartbeat_task = self.heartbeat_task_with_cancel(tx.clone(), cancel_token.clone());

        //             // 重连后触发一次会话增量同步，确保会话名/头像/未读等被服务端数据覆盖
        //             if let Some(syncer) = client.conversation_syncer.clone() {
        //                 tokio::spawn(async move {
        //                     info!("[Client] 🔄 重连后触发会话增量同步");
        //                     if let Err(e) = syncer.incr_sync_conversations().await {
        //                         error!("[Client] ❌ 会话增量同步失败: {e}");
        //                     }
        //                 });
        //             }
        // 使用 select_all 等待三个任务，任何一个退出时取消所有任务
        let tasks = vec![send_task, recv_task, heartbeat_task];
        let (result, index, remaining) = select_all(tasks).await;

        // 取消所有任务（通过 cancel_token）
        let task_name = match index {
            0 => "发送",
            1 => "接收",
            2 => "心跳",
            _ => "未知",
        };
        debug!("[Client]  {task_name}任务退出，取消所有任务");
        cancel_token.cancel();

        // 等待所有任务完成清理
        for task in remaining {
            match task.await {
                Ok(Ok(())) => {}
                Ok(Err(e)) => {
                    error!("[Client] 剩余任务退出并返回错误: {e}");
                }
                Err(join_err) => {
                    error!("[Client] 剩余任务 Join 失败: {join_err}");
                }
            }
        }
        // 将首个退出任务的错误上抛（包含 JoinError 情况）
        let task_result = match result {
            Ok(inner) => inner,
            Err(join_err) => Err(anyhow::anyhow!("任务 Join 失败: {join_err}")),
        };
        if let Err(e) = task_result {
            return Err(anyhow::anyhow!("[Client] {task_name}任务异常退出: {e}"));
        }

        Ok(())
    }
    fn recv_message_loop(&self, recv_cancel_token: CancellationToken, mut read: SplitStream<WebSocketStream<MaybeTlsStream<TcpStream>>>) -> tokio::task::JoinHandle<Result<()>> {
        let app_state = self.app_state.clone();
        tokio::spawn(async move {
            loop {
                let msg_opt = tokio::select! {
                    // 检查取消信号
                    _ = recv_cancel_token.cancelled() => {
                        debug!("[Client] 接收任务收到取消信号，退出循环");
                        return Ok(());
                    }
                    // 接收消息
                    msg_opt = read.next() =>   msg_opt,
                };

                let msg = match msg_opt {
                    Some(Ok(msg)) => msg,
                    Some(Err(e)) => {
                        error!("[Client] 接收ws消息失败: {}", e);
                        return Err(anyhow::anyhow!("接收ws消息失败: {e}"));
                    }
                    None => {
                        warn!("[Client] 收到空ws消息，跳过不退出接收循环");
                        continue;
                    }
                };

                match msg {
                    WsMessage::Text(text) => {
                        info!("[Client] 收到文本消息: {}", text);
                    }
                    WsMessage::Binary(data) => {
                        // 解压 gzip 数据
                        let data = if data.len() >= 2 && data[0] == 0x1f && data[1] == 0x8b {
                            match decompress_gzip(&data) {
                                Ok(d) => d,
                                Err(e) => {
                                    return Err(anyhow::anyhow!("解压失败: {}", e));
                                }
                            }
                        } else {
                            data
                        };
                        // 将二进制消息尝试转为字符串后输出日志
                        info!("[Client] 收到二进制消息: {}", String::from_utf8_lossy(&data));
                        if let Err(e) = BinaryMessageHandler::handle_binary_message(app_state.clone(), &data).await {
                            error!("[Client] handle_binary_message 处理二进制消息失败: {}", e);
                        }
                    }
                    WsMessage::Ping(_) | WsMessage::Pong(_) => { /* 忽略处理 */ }
                    WsMessage::Close(frame) => {
                        warn!("[Client] 👋 连接关闭: {:?}", frame);
                        return Ok(());
                    }
                    _ => { /* 忽略其他类型 */ }
                }
            }
        })
    }
    fn send_message_loop(&self, send_cancel_token: CancellationToken, mut writer: WsWriter, mut rx: Receiver<CommandMessage>) -> tokio::task::JoinHandle<Result<()>> {
        tokio::spawn(async move {
            use futures_util::SinkExt;
            loop {
                tokio::select! {
                    // 检查取消信号
                    _ = send_cancel_token.cancelled() => {
                        debug!("[Client] 发送任务收到取消信号，退出循环");
                        return Ok(());
                    }
                    // 接收消息
                    msg_opt = rx.recv() => {
                        match msg_opt {
                            Some(msg) => {
                                match msg {
                                    CommandMessage::Text(text) => {
                                        if let Err(e) = writer.send(WsMessage::Text(text)).await {
                                            error!("[Client] ws消息发送失败: {}", e);
                                            return Err(anyhow::anyhow!("ws消息发送失败: {e}"));
                                        }
                                    }
                                    CommandMessage::Binary(data) => {
                                        if let Err(e) = writer.send(WsMessage::Binary(data)).await {
                                            error!("[Client] ws消息发送失败: {}", e);
                                            return Err(anyhow::anyhow!("ws消息发送失败: {e}"));
                                        }
                                    }
                                    CommandMessage::Ping => {
                                        if let Err(e) = writer.send(WsMessage::Ping(vec![])).await {
                                            error!("[Client] ws心跳发送失败: {}", e);
                                            return Err(anyhow::anyhow!("ws心跳发送失败: {e}"));
                                        }
                                    }
                                    CommandMessage::Disconnect(_reason) => {
                                        // 断开连接请求，退出发送循环
                                        debug!("[Client] 收到断开连接请求");
                                        return Ok(());
                                    }
                                }
                            }
                            None => {
                                debug!("[Client] ws消息mpsc通道已关闭，发送任务退出");
                                return Ok(());
                            }
                        }
                    }
                }
            }
        })
    }

    fn heartbeat_task_with_cancel(&self, tx: tokio::sync::mpsc::Sender<CommandMessage>, cancel_token: CancellationToken) -> tokio::task::JoinHandle<Result<()>> {
        tokio::spawn(async move {
            let mut ticker = interval(Duration::from_secs(25));
            loop {
                tokio::select! {
                    // 检查取消信号
                    _ = cancel_token.cancelled() => {
                        debug!("[Client] 💓 心跳任务收到取消信号，退出循环");
                        return Ok(());
                    }
                    // 发送心跳
                    _ = ticker.tick() => {
                        debug!("[Client] 💓 心跳任务：发送心跳");
                        if let Err(e) = tx.send(CommandMessage::Ping).await {
                            error!("[Client] 💓 心跳任务：消息通道发送失败: {}", e);
                            return Err(anyhow::anyhow!("心跳发送失败: {e}"));
                        }
                    }
                }
            }
            debug!("[Client] 💓 心跳任务退出");
            Ok(())
        })
    }

    /// 初始化所有资源（数据库、同步器、消息存储等）
    ///
    /// 使用当前客户端的配置 `self.config`，逐步完成：
    /// 1. 创建并缓存 SQLite 连接池
    /// 2. 创建带 token 的 HTTP 客户端
    /// 3. 初始化会话同步器并缓存
    /// 4. 初始化好友同步器并启动增量同步
    /// 5. 初始化消息存储
    async fn initialize_resources(&mut self) -> Result<()> {
        // 1) 初始化数据库连接池
        let db = Self::init_database(&self.config).await?;
        self.db = Some(db.clone());

        // 2) 创建 HTTP 客户端
        let http_client = Self::create_http_client(&self.config)?;

        // 3) 初始化会话同步器
        let conv_syncer = Self::init_conversation_syncer(&self.config, db, http_client, self.conversation_listener.clone()).await?;
        self.conversation_syncer = Some(conv_syncer);

        // 4) 初始化好友同步器
        self.init_friend_syncer().await?;

        // 将已初始化的资源同步到 app_state
        self.app_state.db = self.db.clone();
        self.app_state.message_store = self.message_store.clone();
        self.app_state.conversation_syncer = self.conversation_syncer.clone();
        self.app_state.friend_syncer = self.friend_syncer.clone();
        self.app_state.advanced_msg_listener = self.advanced_msg_listener.clone();
        Ok(())
    }

    /// 注册会话监听器
    pub fn set_conversation_listener(&mut self, listener: Arc<dyn ConversationListener>) {
        self.conversation_listener = Some(listener.clone());
    }

    /// 注册好友监听器
    pub fn set_friend_listener(&mut self, listener: Arc<dyn FriendListener>) {
        self.friend_listener = Some(listener.clone());
        // FriendSyncer 当前不再重建，沿用已有实例
    }

    /// 注册高级消息监听器（参考 Go 版本的 SetAdvancedMsgListener）
    pub fn set_advanced_msg_listener(&mut self, listener: Arc<dyn AdvancedMsgListener>) {
        self.advanced_msg_listener = Some(listener.clone());
        self.app_state.advanced_msg_listener = Some(listener);
    }
    /// 发送文本消息
    pub async fn send_text_message(
        &self,
        recv_id: String,
        text: String,
        session_type: i32, // 1=单聊, 2=群聊
    ) -> Result<()> {
        self.get_message_rpc_for_send().send_text_message(recv_id, text, session_type).await
    }

    /// 发送图片消息
    pub async fn send_picture_message(&self, recv_id: String, picture: PictureElem, session_type: i32) -> Result<()> {
        self.get_message_rpc_for_send().send_picture_message(recv_id, picture, session_type).await
    }

    /// 发送语音消息
    pub async fn send_sound_message(&self, recv_id: String, sound: SoundElem, session_type: i32) -> Result<()> {
        self.get_message_rpc_for_send().send_sound_message(recv_id, sound, session_type).await
    }

    /// 发送视频消息
    pub async fn send_video_message(&self, recv_id: String, video: VideoElem, session_type: i32) -> Result<()> {
        self.get_message_rpc_for_send().send_video_message(recv_id, video, session_type).await
    }

    /// 发送文件消息
    pub async fn send_file_message(&self, recv_id: String, file: FileElem, session_type: i32) -> Result<()> {
        self.get_message_rpc_for_send().send_file_message(recv_id, file, session_type).await
    }

    /// SendMessage NotOss
    pub async fn send_message_not_oss(
        &self,
        recv_id: String,
        group_id: String,
        message: MsgStruct,
        offline_push_info: Option<openim_protocol::sdkws::OfflinePushInfo>,
        is_online_only: bool,
    ) -> Result<()> {
        self.get_message_rpc_for_send().send_message(recv_id, group_id, message, offline_push_info, is_online_only, true).await
    }

    /// SendMessage（默认支持 oss）
    pub async fn send_message(&self, recv_id: String, group_id: String, message: MsgStruct, offline_push_info: Option<openim_protocol::sdkws::OfflinePushInfo>, is_online_only: bool) -> Result<()> {
        self.get_message_rpc_for_send().send_message(recv_id, group_id, message, offline_push_info, is_online_only, false).await
    }

    /// SendMessage（允许自定义 options 覆盖）
    pub async fn send_message_with_options(
        &self,
        recv_id: String,
        group_id: String,
        message: MsgStruct,
        offline_push_info: Option<openim_protocol::sdkws::OfflinePushInfo>,
        is_online_only: bool,
        _options_override: Option<HashMap<String, bool>>,
    ) -> Result<()> {
        // 注意：options_override 在当前实现中暂未使用，保留参数以保持 API 兼容性
        self.get_message_rpc_for_send().send_message(recv_id, group_id, message, offline_push_info, is_online_only, false).await
    }

    /// 获取消息 RPC 实例（用于查询操作）
    fn get_message_rpc(&self) -> crate::im::message::ws_rpc::WsMessageRpc<'_, Self> {
        use crate::im::message::ws_rpc::WsMessageRpc;
        WsMessageRpc::new(self, self.config.user_id.clone())
    }

    /// 获取消息 RPC 实例（用于发送操作）
    fn get_message_rpc_for_send(&self) -> crate::im::message::ws_rpc::WsMessageRpc<'_, Self> {
        use crate::im::message::ws_rpc::WsMessageRpc;
        WsMessageRpc::with_send_context(self, self.config.user_id.clone(), self.config.platform_id)
    }

    /// WebSocket：获取各会话最新 seq（reqIdentifier=1001）
    /// WebSocket：获取最新序列号（reqIdentifier=1001）
    pub async fn ws_get_newest_seq(&self) -> Result<sdkws::GetMaxSeqResp> {
        self.get_message_rpc().get_newest_seq().await
    }

    /// WebSocket：按区间拉取消息（reqIdentifier=1002）
    pub async fn ws_pull_msg_by_range(&self, ranges: Vec<SeqRangeModel>, order: i32) -> Result<sdkws::PullMessageBySeqsResp> {
        self.get_message_rpc().pull_msg_by_range(ranges, order).await
    }

    /// WebSocket：按序列号列表拉取消息（reqIdentifier=1003）
    pub async fn ws_pull_msg_by_seq_list(&self, conversation_id: String, seq_list: Vec<i64>) -> Result<sdkws::PullMessageBySeqsResp> {
        self.get_message_rpc().pull_msg_by_seq_list(conversation_id, seq_list).await
    }

    /// 处理接收消息（事件循环） -> ws_handlers 模块实现

    // handle_binary_message 迁移至 ws_handlers

    // handle_push_message 迁移至 ws_handlers

    /// 处理单个消息，返回是否已处理
    ///
    /// - `conv_id`: 会话 ID
    /// - `msg`: 消息数据
    /// - `_is_notification`: 是否为通知消息（保留用于后续扩展）
    /// - 返回: `true` 表示已处理，`false` 表示未处理（需要 warn）
    pub async fn handle_single_message(&self, conv_id: &str, msg: &openim_protocol::sdkws::MsgData, _is_notification: bool) -> bool {
        // 撤回消息
        if msg.content_type == constant::REVOKE {
            let revoked_json = serde_json::json!({
                "clientMsgID": msg.client_msg_id,
                "revokerID": msg.send_id,
                "revokeTime": msg.send_time,
                "seq": msg.seq,
                "conversationID": conv_id,
            });

            info!("receive message: revoked_json: {:?}", revoked_json);
            let revoked_json_str = serde_json::to_string(&revoked_json).unwrap_or_default();
            let listener = self.advanced_msg_listener.clone();
            tokio::spawn(async move {
                if let Some(listener) = &listener {
                    listener.on_new_recv_message_revoked(revoked_json_str).await;
                }
            });
            return true;
        }

        // 已读回执
        if msg.content_type == constant::HAS_READ_RECEIPT {
            let mut seqs: Vec<i64> = Vec::new();
            let mut receipt_list = Vec::new();
            if let Ok(json) = serde_json::from_slice::<serde_json::Value>(&msg.content) {
                if let Some(detail) = json.get("detail") {
                    if let Some(list) = detail.get("seqList").and_then(|v| v.as_array()) {
                        seqs = list.iter().filter_map(|x| x.as_i64()).collect();
                    }
                }
                receipt_list.push(serde_json::json!({
                    "userID": msg.send_id,
                    "msgIDList": seqs.iter().map(|s| format!("seq_{}", s)).collect::<Vec<_>>(),
                    "sessionType": msg.session_type,
                    "readTime": msg.send_time,
                }));
            }
            let receipt_json_str = serde_json::to_string(&receipt_list).unwrap_or_default();
            let listener = self.advanced_msg_listener.clone();
            tokio::spawn(async move {
                if let Some(listener) = &listener {
                    listener.on_recv_c2c_read_receipt(receipt_json_str).await;
                }
            });
            return true;
        }

        // Reaction 事件（已处理，但暂不通过回调）
        if msg.content_type == constant::REACTION_MESSAGE_MODIFIER || msg.content_type == constant::REACTION_MESSAGE_DELETER {
            // Reaction 事件：目前不通过回调处理（可后续扩展）
            return true;
        }

        // 输入提示（typing）
        if msg.content_type == constant::TYPING {
            let mut msg_tip = String::new();
            if let Ok(json) = serde_json::from_slice::<serde_json::Value>(&msg.content) {
                if let Some(v) = json.get("msgTip").and_then(|v| v.as_str()) {
                    msg_tip = v.to_string();
                }
            }
            let typing_json = serde_json::json!({
                "conversationID": conv_id,
                "sendID": msg.send_id,
                "msgTip": msg_tip,
            });
            info!("receive message: typing: {:?}", msg);
            let typing_json_str = serde_json::to_string(&typing_json).unwrap_or_default();
            let listener = self.advanced_msg_listener.clone();
            tokio::spawn(async move {
                if let Some(listener) = &listener {
                    listener.on_recv_typing_status(typing_json_str).await;
                }
            });
            return true;
        }

        // 普通消息类型（CONTENT_TYPE_BEGIN 到 NOTIFICATION_BEGIN 之间的所有类型）
        // 包括：TEXT, PICTURE, VOICE, VIDEO, FILE, AT_TEXT, MERGER, CARD, LOCATION, CUSTOM,
        // REVOKE, TYPING, QUOTE, ADVANCED_TEXT, MARKDOWN_TEXT, CUSTOM_NOT_TRIGGER_CONVERSATION,
        // CUSTOM_ONLINE_ONLY, REACTION_MESSAGE_MODIFIER, REACTION_MESSAGE_DELETER 等
        // 注意：REVOKE, HAS_READ_RECEIPT, REACTION, TYPING 已在上面处理，这里处理其他普通消息
        if msg.content_type >= constant::CONTENT_TYPE_BEGIN && msg.content_type < constant::NOTIFICATION_BEGIN {
            // 排除已特殊处理的消息类型
            if msg.content_type != constant::REVOKE
                && msg.content_type != constant::HAS_READ_RECEIPT
                && msg.content_type != constant::REACTION_MESSAGE_MODIFIER
                && msg.content_type != constant::REACTION_MESSAGE_DELETER
                && msg.content_type != constant::TYPING
            {
                let msg_json = self.msg_data_to_json(msg);
                let listener = self.advanced_msg_listener.clone();
                tokio::spawn(async move {
                    if let Some(listener) = &listener {
                        listener.on_recv_new_message(msg_json).await;
                    }
                });
                return true;
            }
        }

        // 通用消息类型（COMMON, GROUP_MSG, SIGNAL_MSG, CUSTOM_NOTIFICATION）
        if msg.content_type == constant::COMMON || msg.content_type == constant::GROUP_MSG || msg.content_type == constant::SIGNAL_MSG || msg.content_type == constant::CUSTOM_NOTIFICATION {
            let msg_json = self.msg_data_to_json(msg);
            let listener = self.advanced_msg_listener.clone();
            tokio::spawn(async move {
                if let Some(listener) = &listener {
                    listener.on_recv_new_message(msg_json).await;
                }
            });
            return true;
        }

        // 通知消息类型（NOTIFICATION_BEGIN 到 NOTIFICATION_END 之间的所有类型）
        // 包括：好友通知、用户通知、群组通知、会话通知等
        if msg.content_type >= constant::NOTIFICATION_BEGIN && msg.content_type <= constant::NOTIFICATION_END {
            // 排除已特殊处理的通知类型（HAS_READ_RECEIPT）
            if msg.content_type != constant::HAS_READ_RECEIPT {
                let msg_json = self.msg_data_to_json(msg);
                let listener = self.advanced_msg_listener.clone();
                tokio::spawn(async move {
                    if let Some(listener) = &listener {
                        listener.on_recv_new_message(msg_json).await;
                    }
                });
                return true;
            }
        }

        // 未处理的消息类型（会触发 warn 日志）
        false
    }

    /// 获取会话列表（分页）
    pub async fn get_conversation_list(&self, offset: usize, count: usize) -> Result<Vec<LocalConversation>> {
        let syncer = self.conversation_syncer.as_ref().ok_or_else(|| anyhow::anyhow!("会话同步器未初始化"))?;
        syncer.get_conversation_list_split(offset, count).await
    }

    /// 获取所有会话列表
    pub async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        let syncer = self.conversation_syncer.as_ref().ok_or_else(|| anyhow::anyhow!("会话同步器未初始化"))?;
        syncer.get_all_conversation_list().await
    }

    /// 获取消息列表的最大和最小序列号（完全参考 Go SDK 的 getMaxAndMinHaveSeqList）
    fn get_max_and_min_have_seq_list(messages: &[crate::im::message::models::LocalChatLog]) -> (i64, i64, Vec<i64>) {
        let mut max_seq = 0i64;
        let mut min_seq = 0i64;
        let mut seq_list = Vec::new();

        for msg in messages {
            if msg.seq != 0 {
                seq_list.push(msg.seq);
                if min_seq == 0 && max_seq == 0 {
                    min_seq = msg.seq;
                    max_seq = msg.seq;
                }
                if msg.seq < min_seq {
                    min_seq = msg.seq;
                }
                if msg.seq > max_seq {
                    max_seq = msg.seq;
                }
            }
        }

        (max_seq, min_seq, seq_list)
    }

    /// 获取丢失的序列号列表（完全参考 Go SDK 的 getLostSeqListWithLimitLength）
    ///
    /// - `min_seq`: 最小序列号
    /// - `max_seq`: 最大序列号
    /// - `have_seq_list`: 已有的序列号列表
    /// - `is_reverse`: 是否反向
    /// - 返回: 丢失的序列号列表（限制长度）
    fn get_lost_seq_list_with_limit_length(min_seq: i64, max_seq: i64, have_seq_list: &[i64], is_reverse: bool) -> Vec<i64> {
        let have_seq_set: std::collections::HashSet<i64> = have_seq_list.iter().copied().collect();
        let mut lost_seq_list = Vec::new();

        for seq in min_seq..=max_seq {
            if !have_seq_set.contains(&seq) {
                lost_seq_list.push(seq);
            }
        }

        // 限制长度（参考 Go SDK 的 PullMsgNumForReadDiffusion，这里使用 100）
        const MAX_LOST_SEQ_LENGTH: usize = 100;
        if lost_seq_list.len() > MAX_LOST_SEQ_LENGTH {
            if is_reverse {
                // 反向：取前 MAX_LOST_SEQ_LENGTH 个
                lost_seq_list.truncate(MAX_LOST_SEQ_LENGTH);
            } else {
                // 正向：取后 MAX_LOST_SEQ_LENGTH 个
                let start = lost_seq_list.len() - MAX_LOST_SEQ_LENGTH;
                lost_seq_list = lost_seq_list[start..].to_vec();
            }
        }

        lost_seq_list
    }

    /// 检查并填充消息块内部间隙（完全参考 Go SDK 的 validateAndFillInternalGaps）
    async fn validate_and_fill_internal_gaps(
        &self,
        conversation_id: &str,
        is_reverse: bool,
        count: i32,
        start_time: i64,
        list: &mut Vec<crate::im::message::models::LocalChatLog>,
        message_list_callback: &mut crate::im::message::types::GetAdvancedHistoryMessageListCallback,
    ) -> i64 {
        let (max_seq, min_seq, have_seq_list) = Self::get_max_and_min_have_seq_list(list);

        if max_seq != 0 && min_seq != 0 {
            let lost_seq_list = Self::get_lost_seq_list_with_limit_length(min_seq, max_seq, &have_seq_list, is_reverse);

            if !lost_seq_list.is_empty() {
                debug!("[Client] 检测到消息块内部间隙，conversationID={}, lostSeqList={:?}", conversation_id, lost_seq_list);
                self.fetch_and_merge_missing_messages(conversation_id, &lost_seq_list, is_reverse, count, start_time, list, message_list_callback)
                    .await;
            }
        }

        if is_reverse {
            min_seq
        } else {
            max_seq
        }
    }

    /// 检查并填充消息块之间的间隙（完全参考 Go SDK 的 validateAndFillInterBlockGaps）
    async fn validate_and_fill_inter_block_gaps(
        &self,
        this_start_seq: i64,
        conversation_id: &str,
        is_reverse: bool,
        view_type: i32,
        count: i32,
        start_time: i64,
        list: &mut Vec<crate::im::message::models::LocalChatLog>,
        message_list_callback: &mut crate::im::message::types::GetAdvancedHistoryMessageListCallback,
    ) {
        let (last_end_seq, start_seq, end_seq, is_lost_seq) = if is_reverse {
            let last_end_seq = self.message_pull_reverse_end_seq_map.load(conversation_id, view_type).unwrap_or(0);
            let is_lost_seq = last_end_seq != 0 && last_end_seq + 1 != this_start_seq;
            let start_seq = last_end_seq + 1;
            let end_seq = this_start_seq - 1;
            (last_end_seq, start_seq, end_seq, is_lost_seq)
        } else {
            let last_end_seq = self.message_pull_forward_end_seq_map.load(conversation_id, view_type).unwrap_or(0);
            let is_lost_seq = last_end_seq != 0 && this_start_seq + 1 != last_end_seq;
            let start_seq = this_start_seq + 1;
            let end_seq = last_end_seq - 1;
            (last_end_seq, start_seq, end_seq, is_lost_seq)
        };

        if is_lost_seq && last_end_seq != 0 {
            debug!(
                "[Client] 检测到消息块之间间隙，conversationID={}, lastEndSeq={}, thisStartSeq={}",
                conversation_id, last_end_seq, this_start_seq
            );
            let lost_seq_list = Self::get_lost_seq_list_with_limit_length(start_seq, end_seq, &[], is_reverse);

            if !lost_seq_list.is_empty() {
                self.fetch_and_merge_missing_messages(conversation_id, &lost_seq_list, is_reverse, count, start_time, list, message_list_callback)
                    .await;
            }
        }
    }

    /// 检查消息块是否结束（完全参考 Go SDK 的 checkEndBlock）
    async fn check_end_block(
        &self,
        conversation_id: &str,
        is_reverse: bool,
        view_type: i32,
        count: i32,
        list: &[crate::im::message::models::LocalChatLog],
        message_list_callback: &mut crate::im::message::types::GetAdvancedHistoryMessageListCallback,
    ) -> (bool, Vec<i64>) {
        if list.len() >= count as usize {
            message_list_callback.is_end = false;
            return (false, Vec::new());
        }

        if is_reverse {
            // 反向拉取：检查是否到达最大序列号
            let current_max_seq = self.get_conversation_max_seq(conversation_id).await;
            let (max_seq, _, _) = Self::get_max_and_min_have_seq_list(list);

            if max_seq >= current_max_seq {
                message_list_callback.is_end = true;
                return (false, Vec::new());
            }

            let last_end_seq = self.message_pull_reverse_end_seq_map.load(conversation_id, view_type).unwrap_or(0);

            if max_seq == 0 && last_end_seq >= current_max_seq {
                message_list_callback.is_end = true;
                return (false, Vec::new());
            }

            let lost_seq_list = Self::get_lost_seq_list_with_limit_length(max_seq + 1, current_max_seq, &[], is_reverse);

            if !lost_seq_list.is_empty() {
                return (true, lost_seq_list);
            }
        } else {
            // 正向拉取：检查是否到达最小序列号
            let user_can_pull_min_seq = self.get_conversation_min_seq(conversation_id).await;
            let (_, min_seq, _) = Self::get_max_and_min_have_seq_list(list);

            if min_seq <= user_can_pull_min_seq {
                message_list_callback.is_end = true;
                return (false, Vec::new());
            }

            let last_min_seq = self.message_pull_forward_end_seq_map.load(conversation_id, view_type).unwrap_or(0);

            if min_seq == 0 && last_min_seq <= user_can_pull_min_seq {
                message_list_callback.is_end = true;
                return (false, Vec::new());
            }

            let lost_seq_list = Self::get_lost_seq_list_with_limit_length(user_can_pull_min_seq, min_seq - 1, &[], is_reverse);

            if !lost_seq_list.is_empty() {
                return (true, lost_seq_list);
            }
        }

        (false, Vec::new())
    }

    /// 检查并填充消息块末尾连续性（完全参考 Go SDK 的 validateAndFillEndBlockContinuity）
    async fn validate_and_fill_end_block_continuity(
        &self,
        conversation_id: &str,
        is_reverse: bool,
        view_type: i32,
        count: i32,
        start_time: i64,
        list: &mut Vec<crate::im::message::models::LocalChatLog>,
        message_list_callback: &mut crate::im::message::types::GetAdvancedHistoryMessageListCallback,
    ) {
        let (is_should_fetch, lost_seq_list) = self.check_end_block(conversation_id, is_reverse, view_type, count, list, message_list_callback).await;

        if is_should_fetch && !lost_seq_list.is_empty() {
            self.fetch_and_merge_missing_messages(conversation_id, &lost_seq_list, is_reverse, count, start_time, list, message_list_callback)
                .await;

            // 再次检查
            let _ = self.check_end_block(conversation_id, is_reverse, view_type, count, list, message_list_callback).await;
        }
    }

    /// 获取并合并缺失消息（完全参考 Go SDK 的 fetchAndMergeMissingMessages）
    ///
    /// 注意：这里需要调用服务器 API 获取缺失的消息，然后合并到列表中
    async fn fetch_and_merge_missing_messages(
        &self,
        conversation_id: &str,
        seq_list: &[i64],
        is_reverse: bool,
        _count: i32,
        _start_time: i64,
        list: &mut Vec<crate::im::message::models::LocalChatLog>,
        message_list_callback: &mut crate::im::message::types::GetAdvancedHistoryMessageListCallback,
    ) {
        if seq_list.is_empty() {
            return;
        }

        // TODO: 实现从服务器拉取消息的逻辑
        // 参考 Go SDK 的 SendReqWaitResp 调用 constant.PullMsgBySeqList
        // 这里暂时只记录日志，实际实现需要：
        // 1. 构建 GetSeqMessageReq
        // 2. 调用服务器 API 获取消息
        // 3. 将消息转换为 LocalChatLog
        // 4. 合并到 list 中

        warn!(
            "[Client] 需要从服务器拉取缺失消息，conversationID={}, seqList={:?}, isReverse={}, listLen={}",
            conversation_id,
            seq_list,
            is_reverse,
            list.len()
        );

        // 暂时标记错误，表示需要实现服务器拉取逻辑
        message_list_callback.err_code = 100;
        message_list_callback.err_msg = format!("需要从服务器拉取缺失消息（seqList={:?}），但服务器拉取功能尚未实现", seq_list);
    }

    /// 获取会话最大序列号（完全参考 Go SDK 的 getConversationMaxSeq）
    async fn get_conversation_max_seq(&self, conversation_id: &str) -> i64 {
        // 从会话表中获取 MaxSeq，如果为 0 则返回一个较大的值
        if let Some(conv) = self.get_conversation_by_id(conversation_id).await.ok().flatten() {
            if conv.max_seq > 0 {
                return conv.max_seq;
            }
        }
        // 如果没有会话记录，返回一个默认值
        1_000_000_000 // 返回一个很大的值，表示还没有到达末尾
    }

    /// 获取会话最小序列号（完全参考 Go SDK 的 getConversationMinSeq）
    async fn get_conversation_min_seq(&self, conversation_id: &str) -> i64 {
        // 从会话表中获取 MinSeq，如果为 0 则返回 1
        if let Some(conv) = self.get_conversation_by_id(conversation_id).await.ok().flatten() {
            if conv.min_seq > 0 {
                return conv.min_seq;
            }
        }
        1 // 默认返回 1
    }

    /// 获取会话（通过会话同步器）
    async fn get_conversation_by_id(&self, conversation_id: &str) -> Result<Option<LocalConversation>> {
        if let Some(syncer) = &self.conversation_syncer {
            // 使用会话同步器的公开方法
            let conversations = syncer.get_all_conversations().await?;
            Ok(conversations.into_iter().find(|c| c.conversation_id == conversation_id))
        } else {
            Ok(None)
        }
    }

    /// 获取高级历史消息列表（完全参考 Go SDK 的 GetAdvancedHistoryMessageList 实现）
    ///
    /// 参数和返回值完全匹配 Go SDK，包含消息完整性检查
    pub async fn get_advanced_history_message_list(
        &self,
        req: crate::im::message::types::GetAdvancedHistoryMessageListParams,
        is_reverse: bool,
    ) -> Result<crate::im::message::types::GetAdvancedHistoryMessageListCallback> {
        use crate::im::message::types::{GetAdvancedHistoryMessageListCallback, MsgStruct};

        let store = self.message_store.as_ref().ok_or_else(|| anyhow::anyhow!("消息存储未初始化"))?;

        let conversation_id = &req.conversation_id;
        let mut start_time: i64 = 0;
        let mut start_seq: i64 = 0;
        let start_client_msg_id = req.start_client_msg_id.clone();

        // 如果提供了 StartClientMsgID，先获取该消息（完全匹配 Go SDK）
        if !start_client_msg_id.is_empty() {
            if let Some(msg) = store.get_by_client_msg_id(conversation_id, &start_client_msg_id).await? {
                start_time = msg.send_time;
                start_seq = msg.seq;
                // 处理结束序列号（参考 Go SDK 的 handleEndSeq）
                self.handle_end_seq(&req, is_reverse, &msg).await?;
            } else {
                return Ok(GetAdvancedHistoryMessageListCallback {
                    message_list: vec![],
                    is_end: true,
                    err_code: -1,
                    err_msg: format!("消息不存在: {}", start_client_msg_id),
                });
            }
        } else {
            // 清除序列号映射（参考 Go SDK）
            self.message_pull_forward_end_seq_map.delete(conversation_id, req.view_type);
            self.message_pull_reverse_end_seq_map.delete(conversation_id, req.view_type);
        }

        // 调用带间隙检查的消息拉取（完全参考 Go SDK 的 fetchMessagesWithGapCheck）
        let mut message_list_callback = GetAdvancedHistoryMessageListCallback {
            message_list: vec![],
            is_end: false,
            err_code: 0,
            err_msg: String::new(),
        };

        let list = self
            .fetch_messages_with_gap_check(
                conversation_id,
                req.count,
                start_time,
                start_seq,
                &start_client_msg_id,
                is_reverse,
                req.view_type,
                &mut message_list_callback,
            )
            .await?;

        // 转换为 MsgStruct（完全匹配 Go SDK 的 LocalChatLog2MsgStruct）
        let message_list: Vec<MsgStruct> = list.into_iter().map(|log| Self::local_chat_log_to_msg_struct(log)).collect();

        message_list_callback.message_list = message_list;

        Ok(message_list_callback)
    }

    /// 处理结束序列号（完全参考 Go SDK 的 handleEndSeq）
    async fn handle_end_seq(&self, req: &crate::im::message::types::GetAdvancedHistoryMessageListParams, is_reverse: bool, start_message: &crate::im::message::models::LocalChatLog) -> Result<()> {
        if is_reverse {
            if self.message_pull_reverse_end_seq_map.load(&req.conversation_id, req.view_type).is_none() {
                if start_message.seq != 0 {
                    self.message_pull_reverse_end_seq_map.store(&req.conversation_id, req.view_type, start_message.seq);
                } else {
                    // TODO: 获取有效的服务器消息
                    // 参考 Go SDK 的 GetLatestValidServerMessage
                }
            }
        } else {
            if self.message_pull_forward_end_seq_map.load(&req.conversation_id, req.view_type).is_none() {
                if start_message.seq != 0 {
                    self.message_pull_forward_end_seq_map.store(&req.conversation_id, req.view_type, start_message.seq);
                } else {
                    // TODO: 获取有效的服务器消息
                    // 参考 Go SDK 的 GetLatestValidServerMessage
                }
            }
        }
        Ok(())
    }

    /// 带间隙检查的消息拉取（完全参考 Go SDK 的 fetchMessagesWithGapCheck）
    async fn fetch_messages_with_gap_check(
        &self,
        conversation_id: &str,
        count: i32,
        start_time: i64,
        start_seq: i64,
        start_client_msg_id: &str,
        is_reverse: bool,
        view_type: i32,
        message_list_callback: &mut crate::im::message::types::GetAdvancedHistoryMessageListCallback,
    ) -> Result<Vec<crate::im::message::models::LocalChatLog>> {
        let store = self.message_store.as_ref().ok_or_else(|| anyhow::anyhow!("消息存储未初始化"))?;

        // 从数据库获取消息列表
        let mut list = store.get_message_list(conversation_id, count, start_time, start_seq, start_client_msg_id, is_reverse).await?;

        // 1. 检查并填充消息块内部间隙
        let this_start_seq = self
            .validate_and_fill_internal_gaps(conversation_id, is_reverse, count, start_time, &mut list, message_list_callback)
            .await;

        // 2. 检查并填充消息块之间的间隙
        self.validate_and_fill_inter_block_gaps(this_start_seq, conversation_id, is_reverse, view_type, count, start_time, &mut list, message_list_callback)
            .await;

        // 3. 检查并填充消息块末尾连续性
        self.validate_and_fill_end_block_continuity(conversation_id, is_reverse, view_type, count, start_time, &mut list, message_list_callback)
            .await;

        // 过滤有效消息（排除已删除和异常消息）
        let valid_messages: Vec<_> = list
            .into_iter()
            .filter(|msg| {
                use openim_protocol::constant;
                msg.status < constant::MSG_STATUS_HAS_DELETED
            })
            .collect();

        Ok(valid_messages)
    }

    /// 将 LocalChatLog 转换为 MsgStruct（参考 Go SDK 的 LocalChatLog2MsgStruct）
    fn local_chat_log_to_msg_struct(log: crate::im::message::models::LocalChatLog) -> crate::im::message::types::MsgStruct {
        use crate::im::message::types::MsgStruct;

        // 解析 content（可能是 JSON）
        let content_str = log.content.clone();
        // 暂时不解析具体的元素类型，直接使用 content
        // TODO: 根据 content_type 解析不同的元素类型（text_elem, picture_elem 等）
        let text_elem = None;
        let picture_elem = None;
        let sound_elem = None;
        let video_elem = None;
        let file_elem = None;
        let at_text_elem = None;
        let location_elem = None;
        let custom_elem = None;
        let quote_elem = None;

        MsgStruct {
            client_msg_id: Some(log.client_msg_id),
            server_msg_id: Some(log.server_msg_id),
            create_time: log.create_time,
            send_time: log.send_time,
            session_type: log.session_type,
            send_id: Some(log.send_id),
            recv_id: Some(log.recv_id),
            msg_from: log.msg_from,
            content_type: log.content_type,
            sender_platform_id: log.sender_platform_id,
            sender_nickname: Some(log.sender_nickname),
            sender_face_url: Some(log.sender_face_url),
            group_id: if !log.group_id.is_empty() { Some(log.group_id) } else { None },
            content: Some(content_str),
            seq: log.seq,
            is_read: log.is_read,
            status: log.status,
            is_react: None,
            is_external_extensions: None,
            offline_push: None,
            attached_info: Some(log.attached_info),
            ex: Some(log.ex),
            local_ex: Some(log.local_ex),
            text_elem,
            picture_elem,
            sound_elem,
            video_elem,
            file_elem,
            at_text_elem,
            location_elem,
            custom_elem,
            quote_elem,
        }
    }

    /// 获取所有好友列表
    pub async fn get_all_friends(&self) -> Result<Vec<sdkws::FriendInfo>> {
        let syncer = self.friend_syncer.as_ref().ok_or_else(|| anyhow::anyhow!("好友同步器未初始化"))?;
        syncer.get_all_friends().await
    }

    /// 获取总未读消息数（来自会话同步器的本地聚合）
    pub async fn get_total_unread_count(&self) -> Result<i32> {
        let syncer = self.conversation_syncer.as_ref().ok_or_else(|| anyhow::anyhow!("会话同步器未初始化"))?;
        syncer.get_total_unread_count().await
    }

    /// 标记所有会话为已读
    pub async fn mark_all_conversation_message_as_read(&self) -> Result<()> {
        let url = format!("{}/msg/mark_all_conversation_as_read", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        info!("[Client] 📡 标记所有会话已读");

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&serde_json::json!({
                "userID": self.config.user_id,
            }))
            .send()
            .await?;

        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            error!("[Client] 标记所有会话已读请求失败，HTTP状态: {}, 响应: {}", status, text);
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }

        let json_value: serde_json::Value = serde_json::from_str(&text)?;
        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value.get("errMsg").and_then(|v| v.as_str()).unwrap_or("未知错误");
                error!("[Client] 标记所有会话已读服务器错误，错误码: {}, 错误信息: {}", err_code, err_msg);
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client] ✅ 标记所有会话已读成功");
        Ok(())
    }

    // ===================== 消息管理相关 HTTP 能力 =====================

    /// 撤回消息（按会话 ID + clientMsgID，参考 Go 版本的 RevokeMessage）
    pub async fn revoke_message(&self, conversation_id: String, client_msg_id: String) -> Result<()> {
        // 1. 从本地数据库获取消息的 seq（参考 Go 版本的 waitForMessageSyncSeq）
        let store = self.message_store.as_ref().ok_or_else(|| anyhow::anyhow!("消息存储未初始化"))?;

        let msg = store
            .get_by_client_msg_id(&conversation_id, &client_msg_id)
            .await?
            .ok_or_else(|| anyhow::anyhow!("消息不存在或未同步: clientMsgID={}", client_msg_id))?;

        if msg.seq == 0 {
            return Err(anyhow::anyhow!("消息尚未同步到服务器，无法撤回: clientMsgID={}", client_msg_id));
        }

        // 2. 检查消息状态（只有发送成功的消息才能撤回）
        if msg.status != openim_protocol::constant::MSG_STATUS_SEND_SUCCESS {
            return Err(anyhow::anyhow!("只有发送成功的消息才能撤回: status={}", msg.status));
        }

        // 3. 调用服务端 API（服务端需要 seq）
        let url = format!("{}/msg/revoke_msg", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "seq": msg.seq,
            "userID": self.config.user_id,
        });

        info!("[Client] 📡 撤回消息: conversationID={}, clientMsgID={}, seq={}", conversation_id, client_msg_id, msg.seq);

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;

        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            error!("[Client] 撤回消息请求失败，HTTP状态: {}, 响应: {}", status, text);
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }

        let json_value: serde_json::Value = serde_json::from_str(&text)?;
        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value.get("errMsg").and_then(|v| v.as_str()).unwrap_or("未知错误");
                error!("[Client] 撤回消息服务器错误，错误码: {}, 错误信息: {}", err_code, err_msg);
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client] ✅ 撤回消息成功");
        Ok(())
    }

    /// 删除消息（按会话 ID + 多个 seq）
    pub async fn delete_messages(&self, conversation_id: String, seqs: Vec<i64>) -> Result<()> {
        let url = format!("{}/msg/delete_msgs", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "seqs": seqs,
            "userID": self.config.user_id,
        });

        info!("[Client] 📡 删除消息: conversationID={}", conversation_id);

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;

        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            error!("[Client] 删除消息请求失败，HTTP状态: {}, 响应: {}", status, text);
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }

        let json_value: serde_json::Value = serde_json::from_str(&text)?;
        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value.get("errMsg").and_then(|v| v.as_str()).unwrap_or("未知错误");
                error!("[Client] 删除消息服务器错误，错误码: {}, 错误信息: {}", err_code, err_msg);
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client] ✅ 删除消息成功");
        Ok(())
    }

    /// 删除本地消息（按 clientMsgID）
    pub async fn delete_message_from_local_storage(&self, conversation_id: String, client_msg_id: String) -> Result<()> {
        let store = self.message_store.as_ref().ok_or_else(|| anyhow::anyhow!("消息存储未初始化"))?;
        store.delete_by_client_msg_id(&conversation_id, &client_msg_id).await?;
        info!("[Client] 🗑️ 删除本地消息: conversationID={}, clientMsgID={}", conversation_id, client_msg_id);
        Ok(())
    }

    /// 删除会话本地消息并清理服务器（占位：本地清理 + HTTP 调用）
    pub async fn delete_message(&self, conversation_id: String, client_msg_id: String) -> Result<()> {
        // 本地
        if let Some(store) = &self.message_store {
            let _ = store.delete_by_client_msg_id(&conversation_id, &client_msg_id).await;
        }

        // 服务器
        let url = format!("{}/msg/delete_msg", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "clientMsgID": client_msg_id,
            "userID": self.config.user_id,
        });

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        if let Some(err_code) = serde_json::from_str::<serde_json::Value>(&text)?.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = serde_json::from_str::<serde_json::Value>(&text)
                    .ok()
                    .and_then(|v| v.get("errMsg").and_then(|s| s.as_str()).map(|s| s.to_string()))
                    .unwrap_or_else(|| "未知错误".to_string());
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client] ✅ 删除消息（本地+服务端）成功");
        Ok(())
    }

    /// 删除指定会话的全部本地消息
    pub async fn delete_all_msg_from_local(&self, conversation_id: String) -> Result<()> {
        if let Some(store) = &self.message_store {
            store.delete_conversation(&conversation_id).await?;
        }
        info!("[Client] 🗑️ 已删除本地会话全部消息，conversationID={}", conversation_id);
        Ok(())
    }

    /// 插入单聊消息到本地存储（仿 openim-core InsertSingleMessageToLocalStorage）
    pub async fn insert_single_message_to_local_storage(&self, message_json: String, recv_id: String, send_id: String) -> Result<MsgStruct> {
        let mut msg: MsgStruct = serde_json::from_str(&message_json)?;
        msg.send_id = Some(send_id.clone());
        msg.recv_id = Some(recv_id.clone());
        if msg.client_msg_id.is_none() {
            msg.client_msg_id = Some(generate_msg_id(&send_id));
        }
        let conv_id = format!("si_{}_{}", send_id, recv_id); // 简化版本
        self.store_msg(conv_id, msg.clone()).await?;
        Ok(msg)
    }

    /// 插入群聊消息到本地存储（仿 openim-core InsertGroupMessageToLocalStorage）
    pub async fn insert_group_message_to_local_storage(&self, message_json: String, group_id: String, send_id: String) -> Result<MsgStruct> {
        let mut msg: MsgStruct = serde_json::from_str(&message_json)?;
        msg.send_id = Some(send_id.clone());
        msg.group_id = Some(group_id.clone());
        msg.recv_id = Some(group_id.clone());
        if msg.client_msg_id.is_none() {
            msg.client_msg_id = Some(generate_msg_id(&send_id));
        }
        let conv_id = format!("gi_{}", group_id); // 简化版本
        self.store_msg(conv_id, msg.clone()).await?;
        Ok(msg)
    }

    /// 按消息 ID 标记已读（本地）
    pub async fn mark_messages_as_read_by_msg_id_local(&self, conversation_id: String, client_msg_ids: Vec<String>) -> Result<i64> {
        let store = self.message_store.as_ref().ok_or_else(|| anyhow::anyhow!("消息存储未初始化"))?;
        store.mark_as_read_by_msg_ids(&conversation_id, &client_msg_ids).await
    }

    /// 按消息 ID 标记已读（本地 + 服务端）
    pub async fn mark_messages_as_read_by_msg_id(&self, conversation_id: String, client_msg_ids: Vec<String>) -> Result<()> {
        // 本地
        if let Some(store) = &self.message_store {
            let _ = store.mark_as_read_by_msg_ids(&conversation_id, &client_msg_ids).await?;
        }

        // 服务端
        let url = format!("{}/msg/mark_msgs_as_read_by_msg_id", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "clientMsgIDs": client_msg_ids,
            "userID": self.config.user_id,
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        if let Some(err_code) = serde_json::from_str::<serde_json::Value>(&text)?.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = serde_json::from_str::<serde_json::Value>(&text)
                    .ok()
                    .and_then(|v| v.get("errMsg").and_then(|s| s.as_str()).map(|s| s.to_string()))
                    .unwrap_or_else(|| "未知错误".to_string());
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }
        Ok(())
    }

    /// 按会话标记已读（本地 + 服务端）
    pub async fn mark_conversation_message_as_read_full(&self, conversation_id: String) -> Result<()> {
        // 本地：标记对端消息已读
        if let Some(store) = &self.message_store {
            // 读取未读消息的 seq 用于可能的 has_read_seq
            let unread = store.get_unread_by_conversation(&conversation_id).await?;
            let seqs: Vec<i64> = unread.iter().map(|m| m.seq).collect();
            let _ = store.mark_as_read_by_seqs(&conversation_id, &seqs).await?;
        }

        // 服务端：沿用现有 HTTP 端点 mark_conversation_as_read
        let url = format!("{}/msg/mark_conversation_as_read", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "userID": self.config.user_id,
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        if let Some(err_code) = serde_json::from_str::<serde_json::Value>(&text)?.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = serde_json::from_str::<serde_json::Value>(&text)
                    .ok()
                    .and_then(|v| v.get("errMsg").and_then(|s| s.as_str()).map(|s| s.to_string()))
                    .unwrap_or_else(|| "未知错误".to_string());
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }
        Ok(())
    }

    /// 删除所有消息（本地 + 服务端）
    pub async fn delete_all_msg_from_local_and_server(&self) -> Result<()> {
        // 本地清空所有已知会话表（无法枚举表名，采取粗暴 drop 数据库时请谨慎）
        // 这里仅提示：需要调用方自行管理会话 ID 列表，逐个调用 delete_all_msg_from_local
        // 服务端
        let url = format!("{}/msg/delete_all_msg_from_local_and_svr", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "userID": self.config.user_id,
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        Ok(())
    }

    /// 清空会话消息（本地 + 服务端）
    pub async fn clear_conversation_and_delete_all_msg(&self, conversation_id: String) -> Result<()> {
        if let Some(store) = &self.message_store {
            let _ = store.delete_conversation(&conversation_id).await;
        }
        let url = format!("{}/msg/clear_conversation_and_delete_all_msg", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "userID": self.config.user_id,
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        Ok(())
    }

    /// 删除会话并删除全部消息（本地 + 服务端）
    pub async fn delete_conversation_and_delete_all_msg(&self, conversation_id: String) -> Result<()> {
        if let Some(store) = &self.message_store {
            let _ = store.delete_conversation(&conversation_id).await;
        }
        let url = format!("{}/msg/delete_conversation_and_delete_all_msg", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "userID": self.config.user_id,
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        Ok(())
    }

    /// Typing 状态更新（仿 openim-core TypingStatusUpdate）
    pub async fn typing_status_update(&self, recv_id: String, msg_tip: String) -> Result<()> {
        let url = format!("{}/msg/typing_status_update", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());
        let req_json = serde_json::json!({
            "recvID": recv_id,
            "msgTip": msg_tip,
            "sendID": self.config.user_id,
        });
        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        Ok(())
    }

    /// 消息构造器：文本
    pub fn create_text_message(&self, text: String) -> MsgStruct {
        self.build_msg(openim_protocol::constant::TEXT, Some(text), None, None)
    }

    /// 消息构造器：自定义
    pub fn create_custom_message(&self, data: String, extension: String, description: String) -> MsgStruct {
        let elem = CustomElem { data, description, extension };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::CUSTOM, Some(content), None, None)
    }

    /// 消息构造器：位置
    pub fn create_location_message(&self, description: String, longitude: f64, latitude: f64) -> MsgStruct {
        let elem = LocationElem { description, longitude, latitude };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::LOCATION, Some(content), None, None)
    }

    /// 消息构造器：引用
    pub fn create_quote_message(&self, text: Option<String>, quote: MsgStruct) -> MsgStruct {
        let elem = QuoteElem {
            text,
            quote_message: Some(Box::new(quote)),
        };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::QUOTE, Some(content), None, None)
    }

    /// 消息构造器：图片
    pub fn create_image_message(&self, elem: PictureElem) -> MsgStruct {
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::PICTURE, Some(content), None, None)
    }

    /// 消息构造器：语音
    pub fn create_sound_message(&self, elem: SoundElem) -> MsgStruct {
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::VOICE, Some(content), None, None)
    }

    /// 消息构造器：视频
    pub fn create_video_message(&self, elem: VideoElem) -> MsgStruct {
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::VIDEO, Some(content), None, None)
    }

    /// 消息构造器：文件
    pub fn create_file_message(&self, elem: FileElem) -> MsgStruct {
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::FILE, Some(content), None, None)
    }

    /// Typing 消息构造器（仅本地封装）
    pub fn create_typing_message(&self, msg_tip: String) -> MsgStruct {
        let content = serde_json::to_string(&serde_json::json!({ "msgTip": msg_tip })).unwrap_or_default();
        self.build_msg(openim_protocol::constant::TYPING, Some(content), None, None)
    }

    /// 消息构造器：文本@（带 atUserList / atUsersInfo）
    pub fn create_text_at_message(&self, text: String, at_user_list: Vec<String>, at_users_info: Option<Vec<AtInfo>>, quote_message: Option<MsgStruct>, is_at_self: bool) -> MsgStruct {
        let elem = AtElem {
            text,
            at_user_list,
            at_users_info,
            quote_message: quote_message.map(Box::new),
            is_at_self,
        };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::AT_TEXT, Some(content), None, None)
    }

    /// 消息构造器：合并消息（Merger）
    pub fn create_merger_message(&self, message_list: Vec<MsgStruct>, title: String, summary_list: Vec<String>) -> MsgStruct {
        let content = serde_json::to_string(&serde_json::json!({
            "title": title,
            "summaryList": summary_list,
            "multiMessage": message_list,
        }))
        .unwrap_or_default();
        self.build_msg(openim_protocol::constant::MERGER, Some(content), None, None)
    }

    /// 消息构造器：卡片消息（Card）
    pub fn create_card_message(&self, card_info: String) -> MsgStruct {
        let content = serde_json::to_string(&serde_json::json!({
            "cardInfo": card_info
        }))
        .unwrap_or_default();
        self.build_msg(openim_protocol::constant::CARD, Some(content), None, None)
    }

    /// 消息构造器：Markdown 文本
    pub fn create_markdown_message(&self, content: String) -> MsgStruct {
        let elem = MarkdownTextElem { content };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::MARKDOWN_TEXT, Some(content), None, None)
    }

    /// 消息构造器：Markdown 文本 + 实体列表
    pub fn create_markdown_with_entities_message(&self, content: String, message_entity_list: Option<String>) -> MsgStruct {
        let elem = crate::im::message::types::MarkdownEntityElem { content, message_entity_list };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::MARKDOWN_TEXT, Some(content), None, None)
    }

    /// 消息构造器：混合消息（Merger 近似，使用 MERGER contentType）
    pub fn create_mixed_message(&self, title: String, summary_list: Vec<String>, message_list: Vec<MsgStruct>) -> MsgStruct {
        let content = serde_json::to_string(&serde_json::json!({
            "title": title,
            "summaryList": summary_list,
            "message": message_list,
        }))
        .unwrap_or_default();
        self.build_msg(openim_protocol::constant::MERGER, Some(content), None, None)
    }

    /// 消息构造器：AdvancedText（text + messageEntityList json）
    pub fn create_advanced_text_message(&self, text: String, message_entity_list: String) -> MsgStruct {
        let content = serde_json::to_string(&serde_json::json!({
            "text": text,
            "messageEntityList": message_entity_list,
        }))
        .unwrap_or_default();
        self.build_msg(openim_protocol::constant::ADVANCED_TEXT, Some(content), None, None)
    }

    /// 消息构造器：AdvancedQuote（text + message + messageEntityList）
    pub fn create_advanced_quote_message(&self, text: String, message: MsgStruct, message_entity_list: String) -> MsgStruct {
        let content = serde_json::to_string(&serde_json::json!({
            "text": text,
            "message": message,
            "messageEntityList": message_entity_list,
        }))
        .unwrap_or_default();
        self.build_msg(openim_protocol::constant::ADVANCED_TEXT, Some(content), None, None)
    }

    /// 消息构造器：Markdown + @（复用 AtElem，text 使用 markdown）
    pub fn create_markdown_at_message(&self, markdown_text: String, at_user_list: Vec<String>, at_users_info: Option<Vec<AtInfo>>, quote_message: Option<MsgStruct>, is_at_self: bool) -> MsgStruct {
        let elem = AtElem {
            text: markdown_text,
            at_user_list,
            at_users_info,
            quote_message: quote_message.map(Box::new),
            is_at_self,
        };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::MARKDOWN_TEXT, Some(content), None, None)
    }

    /// 消息构造器：自定义 OnlineOnly
    pub fn create_custom_online_only_message(&self, data: String, extension: String, description: String) -> MsgStruct {
        let elem = CustomElem { data, description, extension };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::CUSTOM_ONLINE_ONLY, Some(content), None, None)
    }

    /// 消息构造器：自定义不触发会话
    pub fn create_custom_not_trigger_conversation_message(&self, data: String, extension: String, description: String) -> MsgStruct {
        let elem = CustomElem { data, description, extension };
        let content = serde_json::to_string(&elem).unwrap_or_default();
        self.build_msg(openim_protocol::constant::CUSTOM_NOT_TRIGGER_CONVERSATION, Some(content), None, None)
    }

    fn build_msg(&self, content_type: i32, content: Option<String>, recv_id: Option<String>, group_id: Option<String>) -> MsgStruct {
        let now = chrono::Utc::now().timestamp_millis();
        let mut msg = MsgStruct {
            client_msg_id: Some(generate_msg_id(&self.config.user_id)),
            server_msg_id: None,
            create_time: now,
            send_time: now,
            session_type: if group_id.is_some() {
                openim_protocol::constant::GROUP_MSG
            } else {
                openim_protocol::constant::SINGLE_CHAT_TYPE
            },
            send_id: Some(self.config.user_id.clone()),
            recv_id,
            msg_from: 100,
            content_type,
            sender_platform_id: self.config.platform_id,
            sender_nickname: None,
            sender_face_url: None,
            group_id,
            content: None,
            seq: 0,
            is_read: false,
            status: 1,
            is_react: None,
            is_external_extensions: None,
            offline_push: None,
            attached_info: None,
            ex: None,
            local_ex: None,
            text_elem: None,
            picture_elem: None,
            sound_elem: None,
            video_elem: None,
            file_elem: None,
            at_text_elem: None,
            location_elem: None,
            custom_elem: None,
            quote_elem: None,
        };
        msg.content = content;
        msg
    }

    async fn store_msg(&self, conversation_id: String, msg: MsgStruct) -> Result<()> {
        let store = self.message_store.as_ref().ok_or_else(|| anyhow::anyhow!("消息存储未初始化"))?;
        let now = chrono::Utc::now().timestamp_millis();
        let log = crate::im::message::models::LocalChatLog {
            conversation_id,
            client_msg_id: msg.client_msg_id.clone().unwrap_or_else(|| generate_msg_id("unk")),
            server_msg_id: msg.server_msg_id.clone().unwrap_or_default(),
            send_id: msg.send_id.clone().unwrap_or_default(),
            recv_id: msg.recv_id.clone().unwrap_or_default(),
            sender_platform_id: msg.sender_platform_id,
            sender_nickname: msg.sender_nickname.clone().unwrap_or_default(),
            sender_face_url: msg.sender_face_url.clone().unwrap_or_default(),
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: msg.content.clone().unwrap_or_default(),
            is_read: msg.is_read,
            status: msg.status,
            seq: msg.seq,
            send_time: if msg.send_time > 0 { msg.send_time } else { now },
            create_time: if msg.create_time > 0 { msg.create_time } else { now },
            attached_info: msg.attached_info.clone().unwrap_or_default(),
            ex: msg.ex.clone().unwrap_or_default(),
            local_ex: msg.local_ex.clone().unwrap_or_default(),
            group_id: msg.group_id.clone().unwrap_or_default(),
        };
        store.insert_message(&log).await
    }

    /// 清空指定会话的所有消息
    pub async fn clear_conversation_msgs(&self, conversation_ids: Vec<String>) -> Result<()> {
        let url = format!("{}/msg/clear_conversation_msg", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        let req_json = serde_json::json!({
            "conversationIDs": conversation_ids,
            "userID": self.config.user_id,
        });

        info!("[Client] 📡 清空会话消息");

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;

        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            error!("[Client] 清空会话消息请求失败，HTTP状态: {}, 响应: {}", status, text);
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }

        let json_value: serde_json::Value = serde_json::from_str(&text)?;
        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value.get("errMsg").and_then(|v| v.as_str()).unwrap_or("未知错误");
                error!("[Client] 清空会话消息服务器错误，错误码: {}, 错误信息: {}", err_code, err_msg);
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client] ✅ 清空会话消息成功");
        Ok(())
    }

    /// 标记会话为已读（设置 hasReadSeq，并可附带指定 seqs）
    pub async fn mark_conversation_as_read(&self, conversation_id: String, has_read_seq: i64, seqs: Vec<i64>) -> Result<()> {
        let url = format!("{}/msg/mark_conversation_as_read", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "userID": self.config.user_id,
            "hasReadSeq": has_read_seq,
            "seqs": seqs,
        });

        info!("[Client] 📡 标记会话已读: conversationID={}, hasReadSeq={}", conversation_id, has_read_seq);

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;

        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            error!("[Client] 标记会话已读请求失败，HTTP状态: {}, 响应: {}", status, text);
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }

        let json_value: serde_json::Value = serde_json::from_str(&text)?;
        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value.get("errMsg").and_then(|v| v.as_str()).unwrap_or("未知错误");
                error!("[Client] 标记会话已读服务器错误，错误码: {}, 错误信息: {}", err_code, err_msg);
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client] ✅ 标记会话已读成功");
        Ok(())
    }

    #[allow(dead_code, clippy::manual_range_contains, clippy::manual_range_contains)]
    fn get_content_type_name(content_type: i32) -> &'static str {
        use openim_protocol::constant;

        match content_type {
            // 普通消息
            constant::TEXT => "[TEXT]",
            constant::PICTURE => "[PICTURE]",
            constant::VOICE => "[VOICE]",
            constant::VIDEO => "[VIDEO]",
            constant::FILE => "[FILE]",
            constant::AT_TEXT => "[@TEXT]",
            constant::MERGER => "[MERGER]",
            constant::CARD => "[CARD]",
            constant::LOCATION => "[LOCATION]",
            constant::CUSTOM => "[CUSTOM]",
            constant::REVOKE => "[REVOKE]",
            constant::TYPING => "[TYPING]",
            constant::QUOTE => "[QUOTE]",
            constant::ADVANCED_TEXT => "[ADVANCED_TEXT]",
            constant::MARKDOWN_TEXT => "[MARKDOWN_TEXT]",
            constant::CUSTOM_NOT_TRIGGER_CONVERSATION => "[CUSTOM_NOT_TRIGGER_CONVERSATION]",
            constant::CUSTOM_ONLINE_ONLY => "[CUSTOM_ONLINE_ONLY]",
            constant::REACTION_MESSAGE_MODIFIER => "[REACTION_MODIFIER]",
            constant::REACTION_MESSAGE_DELETER => "[REACTION_DELETER]",

            // 通用消息类型
            constant::COMMON => "[COMMON]",
            constant::GROUP_MSG => "[GROUP_MSG]",
            constant::SIGNAL_MSG => "[SIGNAL_MSG]",
            constant::CUSTOM_NOTIFICATION => "[CUSTOM_NOTIFICATION]",

            // 好友相关通知
            constant::FRIEND_APPLICATION_APPROVED_NOTIFICATION => "[FRIEND_APPLICATION_APPROVED]",
            constant::FRIEND_APPLICATION_REJECTED_NOTIFICATION => "[FRIEND_APPLICATION_REJECTED]",
            constant::FRIEND_APPLICATION_NOTIFICATION => "[FRIEND_APPLICATION]",
            constant::FRIEND_ADDED_NOTIFICATION => "[FRIEND_ADDED]",
            constant::FRIEND_DELETED_NOTIFICATION => "[FRIEND_DELETED]",
            constant::FRIEND_REMARK_SET_NOTIFICATION => "[FRIEND_REMARK_SET]",
            constant::BLACK_ADDED_NOTIFICATION => "[BLACK_ADDED]",
            constant::BLACK_DELETED_NOTIFICATION => "[BLACK_DELETED]",
            constant::FRIEND_INFO_UPDATED_NOTIFICATION => "[FRIEND_INFO_UPDATED]",
            constant::FRIENDS_INFO_UPDATE_NOTIFICATION => "[FRIENDS_INFO_UPDATE]",

            // 会话 & 用户通知
            constant::CONVERSATION_CHANGE_NOTIFICATION => "[CONVERSATION_CHANGE]",
            constant::USER_INFO_UPDATED_NOTIFICATION => "[USER_INFO_UPDATED]",
            constant::USER_STATUS_CHANGE_NOTIFICATION => "[USER_STATUS_CHANGE]",

            // 群相关通知（只列常见的几种）
            constant::GROUP_CREATED_NOTIFICATION => "[GROUP_CREATED]",
            constant::GROUP_INFO_SET_NOTIFICATION => "[GROUP_INFO_SET]",
            constant::JOIN_GROUP_APPLICATION_NOTIFICATION => "[JOIN_GROUP_APPLICATION]",
            constant::MEMBER_QUIT_NOTIFICATION => "[MEMBER_QUIT]",
            constant::GROUP_APPLICATION_ACCEPTED_NOTIFICATION => "[GROUP_APPLICATION_ACCEPTED]",
            constant::GROUP_APPLICATION_REJECTED_NOTIFICATION => "[GROUP_APPLICATION_REJECTED]",
            constant::GROUP_OWNER_TRANSFERRED_NOTIFICATION => "[GROUP_OWNER_TRANSFERRED]",
            constant::MEMBER_KICKED_NOTIFICATION => "[MEMBER_KICKED]",
            constant::MEMBER_INVITED_NOTIFICATION => "[MEMBER_INVITED]",
            constant::MEMBER_ENTER_NOTIFICATION => "[MEMBER_ENTER]",
            constant::GROUP_DISMISSED_NOTIFICATION => "[GROUP_DISMISSED]",

            // 已读回执
            constant::HAS_READ_RECEIPT => "[HAS_READ_RECEIPT]",

            // 大类兜底：通知 / 普通消息
            _ if content_type >= constant::NOTIFICATION_BEGIN && content_type <= constant::NOTIFICATION_END => "[NOTIFICATION]",
            _ if content_type >= constant::CONTENT_TYPE_BEGIN && content_type < constant::NOTIFICATION_BEGIN => "[MESSAGE]",
            _ => "[UNKNOWN]",
        }
    }
}

// 实现 WsRpcClient trait（为 OpenIMClient 和 &OpenIMClient）
impl crate::im::message::ws_rpc::WsRpcClient for OpenIMClient {
    async fn send_request_and_wait(&self, req_identifier: i32, data: Vec<u8>, timeout_duration: Option<tokio::time::Duration>) -> Result<crate::im::model::OpenIMResp> {
        OpenIMClient::send_request_and_wait(self, req_identifier, data, timeout_duration).await
    }
}

impl crate::im::message::ws_rpc::WsRpcClient for &OpenIMClient {
    async fn send_request_and_wait(&self, req_identifier: i32, data: Vec<u8>, timeout_duration: Option<tokio::time::Duration>) -> Result<crate::im::model::OpenIMResp> {
        OpenIMClient::send_request_and_wait(self, req_identifier, data, timeout_duration).await
    }
}

// 对外特征接口实现
impl OpenIMClientApi for OpenIMClient {
    fn set_conversation_listener(&mut self, listener: Arc<dyn ConversationListener>) {
        OpenIMClient::set_conversation_listener(self, listener)
    }

    fn set_friend_listener(&mut self, listener: Arc<dyn FriendListener>) {
        OpenIMClient::set_friend_listener(self, listener)
    }

    fn set_advanced_msg_listener(&mut self, listener: Arc<dyn AdvancedMsgListener>) {
        OpenIMClient::set_advanced_msg_listener(self, listener)
    }

    fn connect(&mut self) -> Result<()> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::connect(self).await })
    }

    fn send_text_message(&self, recv_id: String, text: String, session_type: i32) -> Result<()> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::send_text_message(self, recv_id, text, session_type).await })
    }

    fn send_message(&self, recv_id: String, group_id: String, message: MsgStruct, offline_push_info: Option<sdkws::OfflinePushInfo>, is_online_only: bool) -> Result<()> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::send_message(self, recv_id, group_id, message, offline_push_info, is_online_only).await })
    }

    fn send_message_not_oss(&self, recv_id: String, group_id: String, message: MsgStruct, offline_push_info: Option<sdkws::OfflinePushInfo>, is_online_only: bool) -> Result<()> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::send_message_not_oss(self, recv_id, group_id, message, offline_push_info, is_online_only).await })
    }

    fn ws_get_newest_seq(&self) -> Result<sdkws::GetMaxSeqResp> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::ws_get_newest_seq(self).await })
    }

    fn ws_pull_msg_by_range(&self, ranges: Vec<SeqRangeModel>, order: i32) -> Result<sdkws::PullMessageBySeqsResp> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::ws_pull_msg_by_range(self, ranges, order).await })
    }

    fn insert_single_message_to_local_storage(&self, message_json: String, recv_id: String, send_id: String) -> Result<MsgStruct> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::insert_single_message_to_local_storage(self, message_json, recv_id, send_id).await })
    }

    fn insert_group_message_to_local_storage(&self, message_json: String, group_id: String, send_id: String) -> Result<MsgStruct> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::insert_group_message_to_local_storage(self, message_json, group_id, send_id).await })
    }

    fn mark_messages_as_read_by_msg_id(&self, conversation_id: String, client_msg_ids: Vec<String>) -> Result<()> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::mark_messages_as_read_by_msg_id(self, conversation_id, client_msg_ids).await })
    }

    fn mark_conversation_message_as_read_full(&self, conversation_id: String) -> Result<()> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::mark_conversation_message_as_read_full(self, conversation_id).await })
    }

    fn revoke_message(&self, conversation_id: String, client_msg_id: String) -> Result<()> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::revoke_message(self, conversation_id, client_msg_id).await })
    }

    fn delete_messages(&self, conversation_id: String, seqs: Vec<i64>) -> Result<()> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::delete_messages(self, conversation_id, seqs).await })
    }

    fn get_conversation_list(&self, offset: usize, count: usize) -> Result<Vec<LocalConversation>> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::get_conversation_list(self, offset, count).await })
    }

    fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::get_all_conversations(self).await })
    }

    fn get_total_unread_count(&self) -> Result<i32> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::get_total_unread_count(self).await })
    }

    fn get_all_friends(&self) -> Result<Vec<sdkws::FriendInfo>> {
        tokio::runtime::Handle::current().block_on(async { OpenIMClient::get_all_friends(self).await })
    }
}

// 允许未使用的辅助方法（日志解析/调试）
#[allow(dead_code, clippy::manual_range_contains, clippy::single_match)]
#[cfg(test)]
mod tests {
    use test_context::{test_context, AsyncTestContext};
    use tokio::sync::OnceCell;
    use tracing::{error, info, warn};

    use super::{ClientConfig, OpenIMClient};
    use crate::im::auth::login_async;
    use crate::im::friend::FriendListener;
    use crate::im::listener::{AdvancedMsgListener, ConversationListener};
    use crate::im::logger::logger::init_logger;
    use crate::im::model::SeqRange;
    // OpenIMClientApi 未直接使用，保留 OpenIMClient 本体即可
    use std::sync::Arc;
    use std::time::{self, Duration};

    static APP_CTX: OnceCell<AppCtx> = OnceCell::const_new();

    #[derive(Clone)]
    struct AppCtx {
        api: Arc<OpenIMClient>,
        self_user: String,
    }

    impl AsyncTestContext for AppCtx {
        async fn setup() -> Self {
            APP_CTX
                .get_or_init(|| async {
                    init_logger("info,rust_lib_flutter_rust_demo=debug,hyper_util::client=info,reqwest=info");
                    let area_code = "+86".to_string();
                    let password = "284f3d09ea0695538e4ded1c1766d73a".to_string();
                    let platform = 5;
                    let token_info = login_async(area_code, "17764338283".to_string(), password, platform).await.expect("登录失败");

                    // 解析 token（如果登录成功）
                    let (user_id, im_token) = (token_info.user_id.clone(), token_info.im_token.clone());

                    let config = ClientConfig::new(user_id, im_token, 5);
                    let mut client = OpenIMClient::new(config);
                    client.init().await.unwrap();
                    // client.set_conversation_listener(
                    //     Arc::new(TestConversationListener) as Arc<dyn ConversationListener>
                    // );
                    // client.set_friend_listener(Arc::new(TestFriendListener));
                    // client.set_advanced_msg_listener(
                    //     Arc::new(TestAdvancedMsgListener) as Arc<dyn AdvancedMsgListener>
                    // );

                    // 连接到服务器（内部会自动启动消息处理）
                    client.connect_with_reconnect().await.unwrap_or_else(|e| {
                        error!("连接失败: {}", e);
                        return;
                    });

                    AppCtx {
                        api: Arc::new(client),
                        self_user: token_info.user_id,
                    }
                })
                .await
                .clone()
        }

        async fn teardown(self) {
            let _ = self;
        }
    }
    #[test_context(AppCtx)]
    #[tokio::test]
    #[ignore]
    async fn connect(ctx: &mut AppCtx) {
        let client = ctx.api.clone();
    }
    #[test_context(AppCtx)]
    #[tokio::test]
    #[ignore]
    async fn run_openim_client(ctx: &mut AppCtx) {
        // // 克隆 client 和 user_id 用于发送消息
        let client = ctx.api.clone();

        let resp = client.ws_get_newest_seq().await.unwrap();
        info!("ws_get_newest_seq: {:?}", resp);
        client
            .send_text_message("1056224172".to_string(), chrono::Local::now().format("Hello from Rust client! %Y-%m-%d %H:%M:%S").to_string(), 1)
            .await
            .unwrap();

        let resp = client.get_all_conversations().await.unwrap();
        info!("get_all_conversations: {:?}", resp);

        for ele in resp {
            let resp = client
                .ws_pull_msg_by_range(
                    vec![SeqRange {
                        conversation_id: ele.conversation_id.clone(),
                        begin: 0,
                        end: 100,
                        num: 10,
                    }],
                    1,
                )
                .await
                .unwrap();
            info!("ws_pull_msg_by_range: {:?}", resp)
        }
        tokio::time::sleep(Duration::from_secs(300)).await;
    }

    struct TestConversationListener;
    #[async_trait::async_trait]
    impl ConversationListener for TestConversationListener {
        async fn on_sync_server_start(&self, reinstalled: bool) {
            info!("TestConversationListener 🔄 同步服务器开始: reinstalled={}", reinstalled);
        }

        async fn on_sync_server_finish(&self, reinstalled: bool) {
            info!("TestConversationListener ✅ 同步服务器完成: reinstalled={}", reinstalled);
        }

        async fn on_sync_server_progress(&self, progress: i32) {
            info!("TestConversationListener 📊 同步服务器进度: {}%", progress);
        }

        async fn on_sync_server_failed(&self, reinstalled: bool) {
            error!("TestConversationListener ❌ 同步服务器失败: reinstalled={}", reinstalled);
        }

        async fn on_new_conversation(&self, conversation_list: String) {
            info!("TestConversationListener 🆕 新会话: {}", conversation_list);
        }

        async fn on_conversation_changed(&self, conversation_list: String) {
            info!("TestConversationListener 🔄 会话变更: {}", conversation_list);
        }

        async fn on_total_unread_message_count_changed(&self, total_unread_count: i32) {
            info!("TestConversationListener 📬 总未读消息数变更: {} (同步未读数成功)", total_unread_count);
        }

        async fn on_conversation_user_input_status_changed(&self, change: String) {
            info!("TestConversationListener ⌨️ 会话用户输入状态变更: {}", change);
        }
    }

    struct TestFriendListener;
    #[async_trait::async_trait]
    impl FriendListener for TestFriendListener {
        async fn on_friend_list_changed(&self, friends_json: String) {
            info!("TestFriendListener 👥 好友列表变更: {}", friends_json);
        }

        async fn on_black_list_changed(&self, blacks_json: String) {
            info!("TestFriendListener 🚫 黑名单列表变更: {}", blacks_json);
        }

        async fn on_friend_request_list_changed(&self, requests_json: String) {
            info!("TestFriendListener 📝 好友申请列表变更: {}", requests_json);
        }
    }

    struct TestAdvancedMsgListener;
    #[async_trait::async_trait]
    impl AdvancedMsgListener for TestAdvancedMsgListener {
        async fn on_recv_new_message(&self, message: String) {
            info!("TestAdvancedMsgListener 📨 OnRecvNewMessage: {}", message);
        }

        async fn on_recv_c2c_read_receipt(&self, msg_receipt_list: String) {
            info!("TestAdvancedMsgListener 📖 OnRecvC2CReadReceipt: {}", msg_receipt_list);
        }

        async fn on_new_recv_message_revoked(&self, message_revoked: String) {
            info!("TestAdvancedMsgListener 🗑️ OnNewRecvMessageRevoked: {}", message_revoked);
        }

        async fn on_recv_offline_new_message(&self, message: String) {
            info!("TestAdvancedMsgListener 📬 OnRecvOfflineNewMessage: {}", message);
        }

        async fn on_msg_deleted(&self, message: String) {
            info!("TestAdvancedMsgListener 🗑️ OnMsgDeleted: {}", message);
        }

        async fn on_recv_online_only_message(&self, message: String) {
            info!("TestAdvancedMsgListener 💬 OnRecvOnlineOnlyMessage: {}", message);
        }

        async fn on_kicked_offline(&self) {
            warn!("TestAdvancedMsgListener ⚠️ OnKickedOffline: 被踢下线");
        }

        async fn on_connection_status_changed(&self, connected: bool, message: String) {
            if connected {
                info!("TestAdvancedMsgListener 🔗 OnConnectionStatusChanged: 已连接 - {}", message);
            } else {
                warn!("TestAdvancedMsgListener 🔗 OnConnectionStatusChanged: 断开 - {}", message);
            }
        }

        async fn on_recv_typing_status(&self, typing_info: String) {
            info!("TestAdvancedMsgListener ⌨️ OnRecvTypingStatus: {}", typing_info);
        }
    }
}
