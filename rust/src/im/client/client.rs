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

use crate::im::api::api::Api;
use crate::im::api::friend::FriendApi;
use crate::im::client::callbacks::ClientCallbacks;
use crate::im::client::connection_handle::ConnectionHandle;
use crate::im::client::conversation_handle::ConversationHandle;
use crate::im::client::message_handle::{MessageHandle, MsgSyncCommand};
use crate::im::dao::repository::Repository;
use crate::im::dao::user::LocalUser;
use crate::im::friend::FriendListener;
use crate::im::listener::{AdvancedMsgListener, ConnListener, ConversationListener, EmptyAdvancedMsgListener, EmptyConnListener, EmptyConversationListener, EmptyUserListener, UserListener};
use crate::im::model::constant::{PULL_MSG_BY_SEQ_LIST, PULL_MSG_NUM_FOR_READ_DIFFUSION};
use crate::im::model::conversation::{ConversationSyncerConfig, LocalConversation};
use crate::im::model::friend::AllFriendsResp;
use crate::im::model::message::{local_chat_log_to_msg_struct, msg_handle_by_content_type_result, GetAdvancedHistoryMessageListCallback, GetAdvancedHistoryMessageListParams, LocalChatLog};
use crate::im::model::ws::{msg_type, OpenIMReq, OpenIMResp, WsRpcEnvelope};
use crate::im::util;
use anyhow::{anyhow, Context, Result};
use chrono;
use openim_protocol::constant;
use openim_protocol::prost::Message;
use openim_protocol::sdkws;
use serde_json::json;
use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use tokio::sync::{mpsc, oneshot};
use tokio::task::JoinHandle;
use tokio::time::timeout;
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
    /// 本地 DB 副本，new 时初始化，用于查询本地消息/会话及发送人信息
    local_repo: Repository,
    /// HTTP API（与 Go 一致，供 GetUserInfoWithCache / 发消息等使用）
    api: Api,
    /// 正序拉取时各 (conversation_id, view_type) 已拉到的末端 seq（对齐 Go messagePullForwardEndSeqMap）
    message_pull_forward_end_seq_map: Arc<RwLock<HashMap<(String, i32), i64>>>,
    /// 反序拉取时各 (conversation_id, view_type) 已拉到的末端 seq（对齐 Go messagePullReverseEndSeqMap）
    message_pull_reverse_end_seq_map: Arc<RwLock<HashMap<(String, i32), i64>>>,
}

impl IMClient {
    /// 与 Go 一致的 SDK 版本号，用于 local_app_sdk_version 表
    const SDK_VERSION: &str = "3.8.0";
    /// 创建新的客户端并初始化本地资源（DB 连接池、迁移、登录用户占位）
    /// - `config`: 客户端配置
    /// - 回调默认为空实现（会输出日志），可通过 set_*_listener 覆盖
    pub async fn new(config: ClientConfig) -> Result<Self> {
        let repo = Repository::create(&config.conversation_db_url).await?;
        if repo.app_version.get_app_sdk_version().await?.is_none() {
            repo.app_version
                .set_app_sdk_version(&crate::im::LocalAppSDKVersion {
                    version: Self::SDK_VERSION.to_string(),
                    installed: false,
                })
                .await?;
        }

        let callbacks = ClientCallbacks {
            conn_listener: Some(Arc::new(EmptyConnListener)),
            conversation_listener: Some(Arc::new(EmptyConversationListener)),
            advanced_msg_listener: Some(Arc::new(EmptyAdvancedMsgListener)),
            friend_listener: None,
            user_listener: Some(Arc::new(EmptyUserListener)),
        };
        let http_client = Self::create_http_client(&config)?;
        let api = Api::new(http_client, config.api_base_url.clone(), config.user_id.clone(), &config.token);
        Ok(Self {
            config,
            callbacks: Arc::new(RwLock::new(callbacks)),
            ws_send_tx: Arc::new(RwLock::new(None)),
            run_handle: Arc::new(RwLock::new(None)),
            local_repo: repo,
            api,
            message_pull_forward_end_seq_map: Arc::new(RwLock::new(HashMap::new())),
            message_pull_reverse_end_seq_map: Arc::new(RwLock::new(HashMap::new())),
        })
    }

    /// 与 Go GetUserInfoWithCache 一致：先本地，缺或昵称/头像为空则拉服务端并落库后返回
    async fn get_login_user_info_with_cache(&self) -> Result<(String, String)> {
        let (nickname, face_url) = self
            .local_repo
            .user
            .get_login_user(&self.config.user_id)
            .await?
            .map(|u| (u.nickname, u.face_url))
            .unwrap_or_else(|| (String::new(), String::new()));
        if !nickname.is_empty() && !face_url.is_empty() {
            return Ok((nickname, face_url));
        }
        if let Some(remote) = self.api.user.get_login_user_from_server().await? {
            let local = LocalUser {
                user_id: remote.user_id,
                nickname: remote.nickname.clone(),
                face_url: remote.face_url.clone(),
                create_time: remote.create_time,
                app_manger_level: remote.app_manger_level,
                ex: remote.ex,
                attached_info: remote.attached_info,
                global_recv_msg_opt: remote.global_recv_msg_opt,
            };
            self.local_repo.user.upsert_login_user(&local).await?;
            return Ok((remote.nickname, remote.face_url));
        }
        Ok((nickname, face_url))
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

    /// 启动客户端（WebSocket 连接、消息/会话同步），非阻塞；运行循环在后台执行。需先通过 new 完成资源初始化。
    pub async fn start(&mut self) -> Result<()> {
        let repo = self.local_repo.clone();
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
            let mut message_syncer = MessageHandle::new(config.user_id.clone(), repo, ws_send_tx, cancel_token.clone(), msg_sync_event_tx, msg_sync_cmd_rx, conv_cmd_tx);
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

    /// 注册用户监听器（Go: SetUserListener，含 OnSelfInfoUpdated）
    pub fn set_user_listener(&mut self, listener: Arc<dyn UserListener>) {
        self.callbacks.write().unwrap().user_listener = Some(listener);
    }

    /// 获取会话列表（从本地 DB 读取，与 Go GetAllConversationList 一致）
    pub async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        self.local_repo.conversation.get_all_conversations().await
    }

    /// 从本地 DB 查询单条消息（推送落库后可用）
    pub async fn get_local_message(&self, conversation_id: &str, client_msg_id: &str) -> Result<Option<LocalChatLog>> {
        self.local_repo.message.get_message(conversation_id, client_msg_id).await
    }

    /// 从服务器获取好友列表（HTTP API）
    pub async fn get_all_friends(&self) -> Result<AllFriendsResp> {
        let raw = IMClient::create_http_client(&self.config)?;
        let api = FriendApi::new(raw, self.config.api_base_url.clone(), self.config.user_id.clone(), &self.config.token);
        api.get_all_friends().await
    }

    /// 与 Go GetUserInfoWithCache 对齐：任意 userID，先本地，缺或昵称/头像为空则拉服务端并落库后返回
    pub async fn get_user_info_with_cache(&self, user_id: &str) -> Result<Option<LocalUser>> {
        let local = self.local_repo.user.get_login_user(user_id).await?;
        if let Some(ref u) = local {
            if !u.nickname.is_empty() && !u.face_url.is_empty() {
                return Ok(local);
            }
        }
        if let Ok(resp) = self.api.user.get_users_info(vec![user_id.to_string()]).await {
            for remote in resp.users_info {
                let local_user = LocalUser {
                    user_id: remote.user_id,
                    nickname: remote.nickname,
                    face_url: remote.face_url,
                    create_time: remote.create_time,
                    app_manger_level: remote.app_manger_level,
                    ex: remote.ex,
                    attached_info: remote.attached_info,
                    global_recv_msg_opt: remote.global_recv_msg_opt,
                };
                let _ = self.local_repo.user.upsert_login_user(&local_user).await;
                return Ok(Some(local_user));
            }
        }
        Ok(local)
    }

    /// 与 Go GetUsersInfoWithCache 对齐：按 user_ids 顺序返回 LocalUser，缺或空的先批量拉远程并落库
    pub async fn get_users_info_with_cache(&self, user_ids: Vec<String>) -> Result<Vec<LocalUser>> {
        let mut result: Vec<LocalUser> = Vec::with_capacity(user_ids.len());
        let mut need_fetch: Vec<String> = Vec::new();
        for id in &user_ids {
            if let Ok(Some(u)) = self.local_repo.user.get_login_user(id).await {
                if !u.nickname.is_empty() && !u.face_url.is_empty() {
                    result.push(u);
                    continue;
                }
            }
            result.push(LocalUser {
                user_id: id.clone(),
                nickname: String::new(),
                face_url: String::new(),
                create_time: 0,
                app_manger_level: 0,
                ex: String::new(),
                attached_info: String::new(),
                global_recv_msg_opt: 0,
            });
            need_fetch.push(id.clone());
        }
        if need_fetch.is_empty() {
            return Ok(result);
        }
        if let Ok(resp) = self.api.user.get_users_info(need_fetch.clone()).await {
            for remote in resp.users_info {
                let local_user = LocalUser {
                    user_id: remote.user_id.clone(),
                    nickname: remote.nickname,
                    face_url: remote.face_url,
                    create_time: remote.create_time,
                    app_manger_level: remote.app_manger_level,
                    ex: remote.ex,
                    attached_info: remote.attached_info,
                    global_recv_msg_opt: remote.global_recv_msg_opt,
                };
                let _ = self.local_repo.user.upsert_login_user(&local_user).await;
                for r in &mut result {
                    if r.user_id == remote.user_id {
                        *r = local_user.clone();
                        break;
                    }
                }
            }
        }
        Ok(result)
    }

    /// 通用 WS 请求：入参为 pb 请求体 + req_identifier，出参为 pb 响应体；需先 start()。
    pub async fn send_ws_req<Req, Resp>(&self, req_identifier: i32, req: &Req) -> Result<Resp>
    where
        Req: Message,
        Resp: Message + Default,
    {
        let tx = self.ws_send_tx.read().unwrap().clone().ok_or_else(|| anyhow::anyhow!("WS 请求需先 start() 建立 WebSocket 连接"))?;
        let data = req.encode_to_vec();
        let open_req = OpenIMReq {
            req_identifier,
            token: self.config.token.clone(),
            send_id: self.config.user_id.clone(),
            operation_id: util::make_operation_id(),
            msg_incr: util::make_msg_incr(),
            data,
        };
        let (resp_tx, resp_rx) = oneshot::channel();
        tx.send((open_req, Some(resp_tx))).map_err(|_| anyhow!("ws rpc channel closed"))?;
        let ws_resp = match timeout(Duration::from_secs(SEND_MSG_WS_TIMEOUT_SECS), resp_rx).await {
            Ok(Ok(resp)) => resp,
            Ok(Err(e)) => return Err(anyhow!("ws response channel dropped: {:?}", e)),
            Err(_) => return Err(anyhow!("ws rpc timeout")),
        };
        if ws_resp.err_code != 0 {
            return Err(anyhow!("ws rpc err code={}, msg={}", ws_resp.err_code, ws_resp.err_msg));
        }
        Resp::decode(ws_resp.data.as_slice()).map_err(|e| anyhow!("decode ws resp: {}", e))
    }

    /// 发送消息：入参 MsgData，内部补齐公共字段（client_msg_id、create_time、msg_from）及个人信息（send_id、sender_platform_id、sender_nickname、sender_face_url）后发送；仅通过 WebSocket，需先 start()。
    /// 与 open-im-server msggateway 一致：WS 请求的 Data 为 MsgData 的 protobuf 编码，非 SendMsgReq。
    pub async fn send_message(&self, mut msg_data: sdkws::MsgData) -> Result<openim_protocol::msg::SendMsgResp> {
        if msg_data.client_msg_id.is_empty() {
            msg_data.client_msg_id = Uuid::new_v4().to_string();
        }
        if msg_data.create_time == 0 {
            msg_data.create_time = chrono::Utc::now().timestamp_millis();
        }
        msg_data.msg_from = constant::USER_MSG_TYPE;

        let (nickname, face_url) = self.get_login_user_info_with_cache().await.unwrap_or_else(|_| (String::new(), String::new()));

        if msg_data.send_id.is_empty() {
            msg_data.send_id = self.config.user_id.clone();
        }
        if msg_data.sender_platform_id == 0 {
            msg_data.sender_platform_id = self.config.platform_id;
        }
        if msg_data.sender_nickname.is_empty() {
            msg_data.sender_nickname = nickname;
        }
        if msg_data.sender_face_url.is_empty() {
            msg_data.sender_face_url = face_url;
        }

        self.send_ws_req::<sdkws::MsgData, openim_protocol::msg::SendMsgResp>(msg_type::WS_SEND_MSG, &msg_data).await
    }

    /// 单聊发送文本消息；TEXT 的 content 使用 TextElem 格式 `{"content":"..."}`，与 Go SDK 一致。
    pub async fn send_text_message(&self, recv_id: String, text: String) -> Result<openim_protocol::msg::SendMsgResp> {
        let mut msg_data = sdkws::MsgData::default();
        msg_data.recv_id = recv_id;
        msg_data.content_type = constant::TEXT;
        msg_data.session_type = constant::SINGLE_CHAT_TYPE;
        msg_data.content = serde_json::to_vec(&json!({ "content": text })).unwrap_or_default();
        self.send_message(msg_data).await
    }

    /// 群聊发送文本消息；TEXT 的 content 使用 TextElem 格式 `{"content":"..."}`。
    pub async fn send_text_to_group(&self, group_id: String, text: String) -> Result<openim_protocol::msg::SendMsgResp> {
        let mut msg_data = sdkws::MsgData::default();
        msg_data.group_id = group_id;
        msg_data.content_type = constant::TEXT;
        msg_data.session_type = constant::READ_GROUP_CHAT_TYPE;
        msg_data.content = serde_json::to_vec(&json!({ "content": text })).unwrap_or_default();
        self.send_message(msg_data).await
    }

    /// 获取高级历史消息列表（正序：从新到旧，对齐 Go GetAdvancedHistoryMessageList）
    ///
    /// 从本地读一批后做块内/块间/块尾 seq 连续性检查，有缺口则通过 WebSocket PullMsgBySeqList 拉取并落库合并。
    /// - `params.conversation_id`: 会话 ID
    /// - `params.start_client_msg_id`: 起始消息 clientMsgID，空表示从最新/最旧开始
    /// - `params.count`: 每页条数
    /// - `params.view_type`: 视图类型（当前仅占位，与 Go 一致）
    /// 返回 `message_list` 与 `is_end`（本页不足 count 或已到端则为 true）。
    pub async fn get_advanced_history_message_list(&self, params: GetAdvancedHistoryMessageListParams) -> Result<GetAdvancedHistoryMessageListCallback> {
        self.get_advanced_history_message_list_impl(params, false).await
    }

    /// 获取高级历史消息列表（反序：从旧到新，对齐 Go GetAdvancedHistoryMessageListReverse）
    pub async fn get_advanced_history_message_list_reverse(&self, params: GetAdvancedHistoryMessageListParams) -> Result<GetAdvancedHistoryMessageListCallback> {
        self.get_advanced_history_message_list_impl(params, true).await
    }

    async fn get_advanced_history_message_list_impl(&self, params: GetAdvancedHistoryMessageListParams, is_reverse: bool) -> Result<GetAdvancedHistoryMessageListCallback> {
        let mut start_time: i64 = 0;
        let mut start_seq: i64 = 0;
        let mut start_client_msg_id = params.start_client_msg_id.clone();
        if !start_client_msg_id.is_empty() {
            if let Some(m) = self.local_repo.message.get_by_client_msg_id(&params.conversation_id, &start_client_msg_id).await? {
                start_time = m.send_time;
                start_seq = m.seq;
                self.handle_end_seq(&params, is_reverse, &m).await?;
            } else {
                start_client_msg_id.clear();
            }
        } else {
            let key_forward = (params.conversation_id.clone(), params.view_type);
            let _ = self.message_pull_forward_end_seq_map.write().unwrap().remove(&key_forward);
            let _ = self.message_pull_reverse_end_seq_map.write().unwrap().remove(&key_forward);
        }
        let mut callback = GetAdvancedHistoryMessageListCallback {
            message_list: vec![],
            is_end: false,
            err_code: 0,
            err_msg: String::new(),
        };
        let list = self
            .fetch_messages_with_gap_check(
                &params.conversation_id,
                params.count,
                start_time,
                start_seq,
                start_client_msg_id,
                is_reverse,
                params.view_type,
                &mut callback,
            )
            .await?;
        let mut message_list: Vec<_> = list.iter().map(local_chat_log_to_msg_struct).collect();
        if !is_reverse {
            message_list.sort_by(|a, b| (b.send_time, b.seq).cmp(&(a.send_time, a.seq)));
        }
        callback.message_list = message_list;
        Ok(callback)
    }

    /// 按 seq 列表通过 WebSocket 拉取消息（对齐 Go PullMsgBySeqList / GetSeqMessage）
    async fn pull_msg_by_seq_list_ws(&self, conversation_id: &str, seq_list: &[i64], is_reverse: bool) -> Result<openim_protocol::msg::GetSeqMessageResp> {
        if seq_list.is_empty() {
            return Ok(openim_protocol::msg::GetSeqMessageResp {
                msgs: HashMap::new(),
                notification_msgs: HashMap::new(),
            });
        }
        let conv_seqs = openim_protocol::msg::ConversationSeqs {
            conversation_id: conversation_id.to_string(),
            seqs: seq_list.to_vec(),
        };
        let order = if is_reverse { 0i32 } else { 1i32 }; // PullOrder Asc=0, Desc=1
        let req = openim_protocol::msg::GetSeqMessageReq {
            user_id: self.config.user_id.clone(),
            conversations: vec![conv_seqs],
            order,
        };
        self.send_ws_req::<openim_protocol::msg::GetSeqMessageReq, openim_protocol::msg::GetSeqMessageResp>(PULL_MSG_BY_SEQ_LIST, &req)
            .await
    }

    /// MsgData 转 LocalChatLog 并处理 content（对齐 Go MsgDataToLocalChatLog）
    fn msg_data_to_local_chat_log(&self, v: &sdkws::MsgData, conversation_id: &str) -> Result<LocalChatLog> {
        let mut log = LocalChatLog::from((v, conversation_id.to_string()));
        log.status = constant::MSG_STATUS_SEND_SUCCESS;
        log.content = msg_handle_by_content_type_result(&v.content, v.content_type).unwrap_or_else(|_| String::from_utf8_lossy(&v.content).to_string());
        Ok(log)
    }

    async fn get_conversation_max_seq(&self, conversation_id: &str) -> i64 {
        if let Ok(Some(c)) = self.local_repo.conversation.get_conversation_by_id(conversation_id).await {
            if c.max_seq != 0 {
                return c.max_seq;
            }
        }
        self.local_repo.message.max_seq(conversation_id).await.unwrap_or(0)
    }

    async fn get_conversation_min_seq(&self, conversation_id: &str) -> i64 {
        if let Ok(Some(c)) = self.local_repo.conversation.get_conversation_by_id(conversation_id).await {
            if c.min_seq != 0 {
                return c.min_seq;
            }
        }
        1
    }

    fn get_max_and_min_have_seq_list(list: &[LocalChatLog]) -> (i64, i64, Vec<i64>) {
        let mut max = 0i64;
        let mut min = 0i64;
        let mut seq_list = Vec::new();
        for m in list {
            if m.seq != 0 {
                seq_list.push(m.seq);
                if min == 0 && max == 0 {
                    min = m.seq;
                    max = m.seq;
                }
                if m.seq < min {
                    min = m.seq;
                }
                if m.seq > max {
                    max = m.seq;
                }
            }
        }
        (max, min, seq_list)
    }

    fn get_lost_seq_list_with_limit_length(min_seq: i64, max_seq: i64, have_seq_list: &[i64], is_reverse: bool) -> Vec<i64> {
        let set: std::collections::HashSet<i64> = have_seq_list.iter().copied().collect();
        let mut lost: Vec<i64> = (min_seq..=max_seq).filter(|s| !set.contains(s)).collect();
        if lost.len() > PULL_MSG_NUM_FOR_READ_DIFFUSION {
            if is_reverse {
                lost.truncate(PULL_MSG_NUM_FOR_READ_DIFFUSION);
            } else {
                lost = lost.into_iter().rev().take(PULL_MSG_NUM_FOR_READ_DIFFUSION).collect();
                lost.reverse();
            }
        }
        lost
    }

    /// 合并两段按 send_time/seq 有序的 LocalChatLog，取前 count 条；desc 表示从新到旧
    fn merge_sorted_local_chat_logs(a: Vec<LocalChatLog>, b: Vec<LocalChatLog>, count: i32, desc: bool) -> Vec<LocalChatLog> {
        let mut out = Vec::with_capacity((a.len() + b.len()).min(count as usize));
        let mut i = 0;
        let mut j = 0;
        let cmp = |x: &LocalChatLog, y: &LocalChatLog| {
            if desc {
                (y.send_time, y.seq).cmp(&(x.send_time, x.seq))
            } else {
                (x.send_time, x.seq).cmp(&(y.send_time, y.seq))
            }
        };
        while out.len() < count as usize {
            let use_a = match (a.get(i), b.get(j)) {
                (Some(ax), Some(bx)) => cmp(ax, bx).is_lt(),
                (Some(_), None) => true,
                (None, Some(_)) => false,
                (None, None) => break,
            };
            if use_a {
                out.push(a[i].clone());
                i += 1;
            } else {
                out.push(b[j].clone());
                j += 1;
            }
        }
        out
    }

    async fn fetch_and_merge_missing_messages(
        &self,
        conversation_id: &str,
        seq_list: &[i64],
        is_reverse: bool,
        list: &mut Vec<LocalChatLog>,
        count: i32,
        _start_time: i64,
        callback: &mut GetAdvancedHistoryMessageListCallback,
    ) {
        if seq_list.is_empty() {
            return;
        }
        if _start_time == 0 {
            if let Ok(tx) = self.ws_send_tx.read() {
                if tx.is_none() {
                    return;
                }
            }
        }
        match self.pull_msg_by_seq_list_ws(conversation_id, seq_list, is_reverse).await {
            Ok(resp) => {
                let msgs = match resp.msgs.get(conversation_id) {
                    Some(pull_msgs) => &pull_msgs.msgs,
                    None => return,
                };
                let mut local_list: Vec<LocalChatLog> = Vec::new();
                for v in msgs {
                    if let Ok(log) = self.msg_data_to_local_chat_log(v, conversation_id) {
                        local_list.push(log);
                    }
                }
                if let Err(e) = self.local_repo.message.batch_insert_message_list(conversation_id, &local_list).await {
                    tracing::warn!("[get_advanced_history] batch_insert_message_list err: {}", e);
                }
                if !is_reverse {
                    local_list.reverse();
                }
                *list = Self::merge_sorted_local_chat_logs(std::mem::take(list), local_list, count, !is_reverse);
            }
            Err(e) => {
                callback.err_code = 100;
                callback.err_msg = e.to_string();
                let need_pull_max = *seq_list.last().unwrap_or(&0);
                list.retain(|m| m.seq == 0 || m.seq > need_pull_max);
            }
        }
    }

    async fn validate_and_fill_internal_gaps(
        &self,
        conversation_id: &str,
        is_reverse: bool,
        count: i32,
        start_time: i64,
        list: &mut Vec<LocalChatLog>,
        callback: &mut GetAdvancedHistoryMessageListCallback,
    ) -> i64 {
        let (max_seq, min_seq, have_seq_list) = Self::get_max_and_min_have_seq_list(list);
        if max_seq == 0 || min_seq == 0 {
            return if is_reverse { min_seq } else { max_seq };
        }
        let lost = Self::get_lost_seq_list_with_limit_length(min_seq, max_seq, &have_seq_list, is_reverse);
        if !lost.is_empty() {
            self.fetch_and_merge_missing_messages(conversation_id, &lost, is_reverse, list, count, start_time, callback).await;
        }
        if is_reverse {
            min_seq
        } else {
            max_seq
        }
    }

    async fn validate_and_fill_inter_block_gaps(
        &self,
        this_start_seq: i64,
        conversation_id: &str,
        is_reverse: bool,
        view_type: i32,
        count: i32,
        start_time: i64,
        list: &mut Vec<LocalChatLog>,
        callback: &mut GetAdvancedHistoryMessageListCallback,
    ) {
        let key = (conversation_id.to_string(), view_type);
        let (last_end_seq, is_lost, start_seq, end_seq) = if is_reverse {
            let last = *self.message_pull_reverse_end_seq_map.read().unwrap().get(&key).unwrap_or(&0);
            let lost = last != 0 && last + 1 != this_start_seq;
            (last, lost, last + 1, this_start_seq - 1)
        } else {
            let last = *self.message_pull_forward_end_seq_map.read().unwrap().get(&key).unwrap_or(&0);
            let lost = last != 0 && this_start_seq + 1 != last;
            (last, lost, this_start_seq + 1, last - 1)
        };
        if is_lost && last_end_seq != 0 && start_seq <= end_seq {
            let lost_list = Self::get_lost_seq_list_with_limit_length(start_seq, end_seq, &[], is_reverse);
            if !lost_list.is_empty() {
                self.fetch_and_merge_missing_messages(conversation_id, &lost_list, is_reverse, list, count, start_time, callback).await;
            }
        }
    }

    async fn validate_and_fill_end_block_continuity(
        &self,
        conversation_id: &str,
        is_reverse: bool,
        view_type: i32,
        count: i32,
        start_time: i64,
        list: &mut Vec<LocalChatLog>,
        callback: &mut GetAdvancedHistoryMessageListCallback,
    ) {
        loop {
            if list.len() >= count as usize {
                callback.is_end = false;
                return;
            }
            let (max_seq, min_seq, _) = Self::get_max_and_min_have_seq_list(list);
            let mut did_fetch = false;
            if is_reverse {
                let current_max = self.get_conversation_max_seq(conversation_id).await;
                if max_seq >= current_max {
                    callback.is_end = true;
                    return;
                }
                let key = (conversation_id.to_string(), view_type);
                let last_end = *self.message_pull_reverse_end_seq_map.read().unwrap().get(&key).unwrap_or(&0);
                if max_seq == 0 && last_end >= current_max {
                    callback.is_end = true;
                    return;
                }
                let lost_list = Self::get_lost_seq_list_with_limit_length(max_seq + 1, current_max, &[], is_reverse);
                if !lost_list.is_empty() {
                    self.fetch_and_merge_missing_messages(conversation_id, &lost_list, is_reverse, list, count, start_time, callback).await;
                    did_fetch = true;
                }
            } else {
                let user_min = self.get_conversation_min_seq(conversation_id).await;
                if min_seq <= user_min {
                    callback.is_end = true;
                    return;
                }
                let key = (conversation_id.to_string(), view_type);
                let last_min = *self.message_pull_forward_end_seq_map.read().unwrap().get(&key).unwrap_or(&0);
                if min_seq == 0 && last_min <= user_min {
                    callback.is_end = true;
                    return;
                }
                let lost_list = Self::get_lost_seq_list_with_limit_length(user_min, min_seq - 1, &[], is_reverse);
                if !lost_list.is_empty() {
                    self.fetch_and_merge_missing_messages(conversation_id, &lost_list, is_reverse, list, count, start_time, callback).await;
                    did_fetch = true;
                }
            }
            if !did_fetch {
                break;
            }
        }
    }

    async fn handle_end_seq(&self, req: &GetAdvancedHistoryMessageListParams, is_reverse: bool, start_message: &LocalChatLog) -> Result<()> {
        let key = (req.conversation_id.clone(), req.view_type);
        if is_reverse {
            let mut m = self.message_pull_reverse_end_seq_map.write().unwrap();
            if !m.contains_key(&key) {
                if start_message.seq != 0 {
                    m.insert(key, start_message.seq);
                }
            }
        } else {
            let mut m = self.message_pull_forward_end_seq_map.write().unwrap();
            if !m.contains_key(&key) {
                if start_message.seq != 0 {
                    m.insert(key, start_message.seq);
                }
            }
        }
        Ok(())
    }

    async fn fetch_messages_with_gap_check(
        &self,
        conversation_id: &str,
        mut count: i32,
        mut start_time: i64,
        mut start_seq: i64,
        mut start_client_msg_id: String,
        is_reverse: bool,
        view_type: i32,
        callback: &mut GetAdvancedHistoryMessageListCallback,
    ) -> Result<Vec<LocalChatLog>> {
        let key = (conversation_id.to_string(), view_type);
        let mut all_valid: Vec<LocalChatLog> = Vec::new();
        loop {
            let mut list = self
                .local_repo
                .message
                .get_message_list(conversation_id, count, start_time, start_seq, &start_client_msg_id, is_reverse)
                .await?;
            let this_start_seq = self.validate_and_fill_internal_gaps(conversation_id, is_reverse, count, start_time, &mut list, callback).await;
            self.validate_and_fill_inter_block_gaps(this_start_seq, conversation_id, is_reverse, view_type, count, start_time, &mut list, callback)
                .await;
            self.validate_and_fill_end_block_continuity(conversation_id, is_reverse, view_type, count, start_time, &mut list, callback)
                .await;
            let valid_messages: Vec<LocalChatLog> = list.iter().filter(|m| m.status < constant::MSG_STATUS_HAS_DELETED).cloned().collect();
            let mut this_end_seq = 0i64;
            for m in &valid_messages {
                if m.seq != 0 {
                    if this_end_seq == 0 {
                        this_end_seq = m.seq;
                    }
                    if is_reverse {
                        if m.seq > this_end_seq {
                            this_end_seq = m.seq;
                        }
                    } else if m.seq < this_end_seq {
                        this_end_seq = m.seq;
                    }
                }
            }
            if this_end_seq != 0 {
                if is_reverse {
                    let mut m = self.message_pull_reverse_end_seq_map.write().unwrap();
                    let last = *m.get(&key).unwrap_or(&0);
                    if last == 0 || this_end_seq > last {
                        m.insert(key.clone(), this_end_seq);
                    }
                } else {
                    let mut m = self.message_pull_forward_end_seq_map.write().unwrap();
                    let last = *m.get(&key).unwrap_or(&0);
                    if last == 0 || this_end_seq < last {
                        m.insert(key.clone(), this_end_seq);
                    }
                }
            }
            all_valid.extend(valid_messages.clone());
            let missing_count = count - valid_messages.len() as i32;
            if missing_count <= 0 || callback.is_end {
                return Ok(all_valid);
            }
            let Some(lm) = valid_messages.last() else {
                return Ok(all_valid);
            };
            start_time = lm.send_time;
            start_seq = lm.seq;
            start_client_msg_id = lm.client_msg_id.clone();
            count = missing_count;
        }
    }
}
