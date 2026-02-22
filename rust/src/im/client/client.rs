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

use crate::im::client::connection_handle::ConnectionHandle;
use crate::im::client::conversation_handle::ConversationHandle;
use crate::im::client::listeners::{
    AdvancedMsgEvent, ConnEvent, ConversationEvent, FriendEvent, GroupEvent, Listeners, UserEvent,
};
use crate::im::client::message_handle::{MessageHandle, MsgSyncCommand};
use crate::im::dao::black::LocalBlack;
use crate::im::dao::group::LocalGroup;
use crate::im::dao::group_member::LocalGroupMember;
use crate::im::dao::repository::Repository;
use crate::im::dao::user::LocalUser;
use crate::im::http_client::friend::FriendApi;
use crate::im::http_client::Api;
use crate::im::model::constant::{PULL_MSG_BY_SEQ_LIST, PULL_MSG_NUM_FOR_READ_DIFFUSION};
use crate::im::model::conversation::{ConversationSyncerConfig, LocalConversation};
use crate::im::model::friend::AllFriendsResp;
use crate::im::model::group::server_group_to_local;
use crate::im::{create_text_message, init_basic_info};
use crate::im::model::message::{
    local_chat_log_to_msg_struct, msg_handle_by_content_type_result, msg_struct_to_local_chat_log, ClearConversationsMsgReq, ConversationArgs, FindMessageListCallback,
    GetAdvancedHistoryMessageListCallback, GetAdvancedHistoryMessageListParams, LocalChatLog, MarkConversationAsReadReq, MsgStruct, RevokeMsgReq, SearchByConversationResult,
    SearchLocalMessagesCallback, SearchLocalMessagesParams, UserClearAllMsgReq,
};
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
use tokio_stream::wrappers::UnboundedReceiverStream;
use tokio::time::timeout;
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info, trace};
use uuid::Uuid;

/// 发送消息 WS 等待响应超时（秒）
const SEND_MSG_WS_TIMEOUT_SECS: u64 = 10;

/// 核心 IM 逻辑实现
#[derive(Clone)]
pub struct IMClient {
    pub(crate) config: ClientConfig,
    /// 全局回调（连接、会话、消息、好友等），统一由此结构体管理
    callbacks: Arc<RwLock<Listeners>>,
    /// WebSocket RPC 发送端；在 start() 中设置，用于通过长连发送消息（直接使用变量，不通过参数传递）
    ws_send_tx: Arc<RwLock<Option<mpsc::UnboundedSender<WsRpcEnvelope>>>>,
    /// start() 内运行循环的 JoinHandle，用于 wait_for_exit() 阻塞等待退出
    run_handle: Arc<RwLock<Option<JoinHandle<Result<()>>>>>,
    /// 用于 stop() 取消连接循环；在 start() 中设置
    cancel_token: Arc<RwLock<Option<CancellationToken>>>,
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

        let callbacks = Listeners::default();
        let http_client = Self::create_http_client(&config)?;
        let api = Api::new(http_client, config.api_base_url.clone(), config.user_id.clone(), &config.token);
        Ok(Self {
            config,
            callbacks: Arc::new(RwLock::new(callbacks)),
            ws_send_tx: Arc::new(RwLock::new(None)),
            run_handle: Arc::new(RwLock::new(None)),
            cancel_token: Arc::new(RwLock::new(None)),
            local_repo: repo,
            api,
            message_pull_forward_end_seq_map: Arc::new(RwLock::new(HashMap::new())),
            message_pull_reverse_end_seq_map: Arc::new(RwLock::new(HashMap::new())),
        })
    }

    /// 只读访问当前配置（供桥接层创建消息时获取 user_id、platform_id）
    pub fn config(&self) -> &ClientConfig {
        &self.config
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
        let parent_token = CancellationToken::new();
        let cancel_token = parent_token.child_token();
        let _ = self.cancel_token.write().unwrap().insert(parent_token);

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

    /// 停止客户端（取消连接循环，用于 Flutter 热重启等场景断开旧连接）
    pub fn stop(&self) {
        if let Some(token) = self.cancel_token.write().unwrap().take() {
            token.cancel();
            info!("[Client] 已发送停止信号");
        }
    }

    /// 订阅连接状态事件（Stream）。应在 start() 之前调用。
    pub fn subscribe_conn_events(&self) -> UnboundedReceiverStream<ConnEvent> {
        let (tx, rx) = mpsc::unbounded_channel::<ConnEvent>();
        self.callbacks.write().unwrap().conn_event_tx = Some(Arc::new(RwLock::new(Some(tx))));
        UnboundedReceiverStream::new(rx)
    }

    /// 订阅会话事件（Stream）。应在 start() 之前调用。
    pub fn subscribe_conversation_events(&self) -> UnboundedReceiverStream<ConversationEvent> {
        let (tx, rx) = mpsc::unbounded_channel::<ConversationEvent>();
        self.callbacks.write().unwrap().conversation_event_tx = Some(Arc::new(RwLock::new(Some(tx))));
        UnboundedReceiverStream::new(rx)
    }

    /// 订阅高级消息事件（Stream）。应在 start() 之前调用。
    pub fn subscribe_advanced_msg_events(&self) -> UnboundedReceiverStream<AdvancedMsgEvent> {
        let (tx, rx) = mpsc::unbounded_channel::<AdvancedMsgEvent>();
        self.callbacks.write().unwrap().advanced_msg_event_tx = Some(Arc::new(RwLock::new(Some(tx))));
        UnboundedReceiverStream::new(rx)
    }

    /// 订阅用户事件（Stream）。应在 start() 之前调用。
    pub fn subscribe_user_events(&self) -> UnboundedReceiverStream<UserEvent> {
        let (tx, rx) = mpsc::unbounded_channel::<UserEvent>();
        self.callbacks.write().unwrap().user_event_tx = Some(Arc::new(RwLock::new(Some(tx))));
        UnboundedReceiverStream::new(rx)
    }

    /// 订阅好友事件（Stream）。应在 start() 之前调用。
    pub fn subscribe_friend_events(&self) -> UnboundedReceiverStream<FriendEvent> {
        let (tx, rx) = mpsc::unbounded_channel::<FriendEvent>();
        self.callbacks.write().unwrap().friend_event_tx = Some(Arc::new(RwLock::new(Some(tx))));
        UnboundedReceiverStream::new(rx)
    }

    /// 订阅群组事件（Stream）。应在 start() 之前调用。
    pub fn subscribe_group_events(&self) -> UnboundedReceiverStream<GroupEvent> {
        let (tx, rx) = mpsc::unbounded_channel::<GroupEvent>();
        self.callbacks.write().unwrap().group_event_tx = Some(Arc::new(RwLock::new(Some(tx))));
        UnboundedReceiverStream::new(rx)
    }

    /// 获取当前登录用户 ID（Go: GetLoginUserID）
    pub fn get_login_user_id(&self) -> String {
        self.config.user_id.clone()
    }

    /// 获取登录状态（Go: GetLoginStatus）。1=未登录，2=登录中，3=已登录
    pub fn get_login_status(&self) -> i32 {
        if self.run_handle.read().unwrap().is_some() {
            3
        } else if !self.config.user_id.is_empty() && !self.config.token.is_empty() {
            2
        } else {
            1
        }
    }

    /// 获取 SDK 版本号（Go: GetSdkVersion）
    pub fn get_sdk_version() -> &'static str {
        Self::SDK_VERSION
    }

    /// 反初始化 SDK（与 Go UnInitSDK 对齐），需先 logout 再调用，否则返回错误
    pub fn un_init_sdk(&self) -> Result<()> {
        if self.get_login_status() == 3 {
            anyhow::bail!("sdk not logout, please logout first");
        }
        Ok(())
    }

    /// 设置应用前后台状态（与 Go SetAppBackgroundStatus 对齐），通过 WS 上报服务端
    pub async fn set_app_background_status(&self, is_background: bool) -> Result<()> {
        use crate::im::model::constant;
        let req = sdkws::SetAppBackgroundStatusReq {
            user_id: self.config.user_id.clone(),
            is_background,
        };
        let _: sdkws::SetAppBackgroundStatusResp = self.send_ws_req(constant::SET_BACKGROUND_STATUS, &req).await?;
        Ok(())
    }

    /// 获取会话列表（从本地 DB 读取，与 Go GetAllConversationList 一致）
    pub async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        self.local_repo.conversation.get_all_conversations().await
    }

    /// 分页获取会话列表（与 Go GetConversationListSplit 一致）
    pub async fn get_conversation_list_split(&self, offset: i32, count: i32) -> Result<Vec<LocalConversation>> {
        self.local_repo.conversation.get_conversations_split(offset, count).await
    }

    /// 根据会话类型与对方 ID 获取单个会话（与 Go GetOneConversation 一致）。若本地不存在返回 None。
    pub async fn get_one_conversation(&self, session_type: i32, source_id: &str) -> Result<Option<LocalConversation>> {
        let cid = self.conversation_id_by_session_type(source_id, session_type);
        self.local_repo.conversation.get_conversation_by_id(&cid).await
    }

    /// 批量获取会话（与 Go GetMultipleConversation 一致）
    pub async fn get_multiple_conversations(&self, conversation_id_list: &[String]) -> Result<Vec<LocalConversation>> {
        let mut out = Vec::with_capacity(conversation_id_list.len());
        for id in conversation_id_list {
            if let Ok(Some(c)) = self.local_repo.conversation.get_conversation_by_id(id).await {
                out.push(c);
            }
        }
        Ok(out)
    }

    /// 设置会话（与 Go SetConversation 一致）：置顶、免打扰等，None 表示不更新该字段
    pub async fn set_conversation(&self, conversation_id: &str, is_pinned: Option<bool>, recv_msg_opt: Option<i32>) -> Result<()> {
        self.local_repo.conversation.update_conversation_partial(conversation_id, is_pinned, recv_msg_opt).await
    }

    /// 隐藏会话（与 Go HideConversation 一致）
    pub async fn hide_conversation(&self, conversation_id: &str) -> Result<()> {
        self.local_repo.conversation.hide_conversation(conversation_id).await
    }

    /// 设置会话草稿（与 Go SetConversationDraft 一致）
    pub async fn set_conversation_draft(&self, conversation_id: &str, draft_text: &str) -> Result<()> {
        self.local_repo.conversation.set_draft(conversation_id, draft_text).await
    }

    /// 获取总未读消息数（与 Go GetTotalUnreadMsgCount 一致）
    pub async fn get_total_unread_msg_count(&self) -> Result<i32> {
        self.local_repo.conversation.get_total_unread_count().await
    }

    fn conversation_id_by_session_type(&self, source_id: &str, session_type: i32) -> String {
        match session_type {
            constant::SINGLE_CHAT_TYPE => {
                let mut v = vec![self.config.user_id.as_str(), source_id];
                v.sort();
                format!("si_{}_{}", v[0], v[1])
            }
            constant::READ_GROUP_CHAT_TYPE => format!("sg_{}", source_id),
            constant::NOTIFICATION_CHAT_TYPE => format!("sn_{}_{}", source_id, self.config.user_id),
            _ => format!("g_{}", source_id),
        }
    }

    /// 标记会话消息已读（与 Go MarkConversationMessageAsRead 一致）：先取未读 seq，上报服务端，再本地标已读并会话未读清零
    pub async fn mark_conversation_message_as_read(&self, conversation_id: &str) -> Result<()> {
        let unread = self.local_repo.message.get_unread_by_conversation(conversation_id).await?;
        let has_read_seq = unread.iter().map(|m| m.seq).max().unwrap_or(0);
        let seqs: Vec<i64> = unread.iter().map(|m| m.seq).collect();
        let req = MarkConversationAsReadReq {
            conversation_id: conversation_id.to_string(),
            user_id: self.config.user_id.clone(),
            has_read_seq,
            seqs: seqs.clone(),
        };
        let _ = self.api.message.mark_conversation_as_read(req).await;
        let _ = self.local_repo.message.mark_conversation_as_read(conversation_id).await?;
        if let Some(mut conv) = self.local_repo.conversation.get_conversation_by_id(conversation_id).await? {
            conv.unread_count = 0;
            let _ = self.local_repo.conversation.upsert_conversation(&conv).await;
        }
        Ok(())
    }

    /// 全部会话标记已读（与 Go MarkAllConversationMessageAsRead 一致）
    pub async fn mark_all_conversation_message_as_read(&self) -> Result<()> {
        let list = self.local_repo.conversation.get_all_conversations().await?;
        for c in list {
            if c.unread_count > 0 {
                let _ = self.mark_conversation_message_as_read(&c.conversation_id).await;
            }
        }
        Ok(())
    }

    /// 撤回消息（与 Go RevokeMessage 一致）：调用服务端撤回并依赖推送更新本地
    pub async fn revoke_message(&self, conversation_id: &str, client_msg_id: &str) -> Result<()> {
        let msg = self
            .local_repo
            .message
            .get_message(conversation_id, client_msg_id)
            .await?
            .ok_or_else(|| anyhow::anyhow!("message not found"))?;
        let conv = self
            .local_repo
            .conversation
            .get_conversation_by_id(conversation_id)
            .await?
            .ok_or_else(|| anyhow::anyhow!("conversation not found"))?;
        let req = RevokeMsgReq {
            revoke_msg_client_id: client_msg_id.to_string(),
            conversation_id: Some(conversation_id.to_string()),
            user_id: Some(self.config.user_id.clone()),
            seq: Some(msg.seq as u32),
            session_type: Some(conv.conversation_type),
        };
        self.api.message.revoke_message(req).await?;
        Ok(())
    }

    /// 仅从本地存储删除消息（与 Go DeleteMessageFromLocalStorage 一致）
    pub async fn delete_message_from_local_storage(&self, conversation_id: &str, client_msg_id: &str) -> Result<()> {
        self.local_repo.message.delete_by_client_msg_id(conversation_id, client_msg_id).await
    }

    /// 删除消息：服务端删除并删本地（与 Go DeleteMessage 一致）
    pub async fn delete_message(&self, conversation_id: &str, client_msg_id: &str) -> Result<()> {
        let msg = self
            .local_repo
            .message
            .get_message(conversation_id, client_msg_id)
            .await?
            .ok_or_else(|| anyhow::anyhow!("message not found"))?;
        let req = crate::im::model::message::DeleteMsgsReq {
            conversation_id: conversation_id.to_string(),
            seqs: vec![msg.seq],
            user_id: self.config.user_id.clone(),
            delete_sync_opt: None,
        };
        self.api.message.delete_msgs(req).await?;
        self.local_repo.message.delete_by_client_msg_id(conversation_id, client_msg_id).await
    }

    /// 从本地 DB 查询单条消息（推送落库后可用）
    pub async fn get_local_message(&self, conversation_id: &str, client_msg_id: &str) -> Result<Option<LocalChatLog>> {
        self.local_repo.message.get_message(conversation_id, client_msg_id).await
    }

    // ---------- 会话/消息扩展（与 Go deleteConversationAndDeleteAllMsg、getAtAllTag、findMessageList、searchLocalMessages、searchConversation、insertSingleMessageToLocalStorage、setMessageLocalEx、hideAllConversations、deleteAllMsgFromLocal、clearConversationAndDeleteAllMsg 对齐） ----------

    /// 获取 @all 标签字符串（与 Go GetAtAllTag 一致）
    pub fn get_at_all_tag(&self) -> String {
        constant::AT_ALL_STRING.to_string()
    }

    /// 清空会话并删除该会话下所有本地消息（先调服务端 clear_conversation_msg，再本地删消息并清空会话；与 Go ClearConversationAndDeleteAllMsg 一致）
    pub async fn clear_conversation_and_delete_all_msg(&self, conversation_id: &str) -> Result<()> {
        let _ = self
            .api
            .message
            .clear_conversation_msg(ClearConversationsMsgReq {
                conversation_ids: vec![conversation_id.to_string()],
                user_id: self.config.user_id.clone(),
                delete_sync_opt: None,
            })
            .await;
        let _ = self.local_repo.message.mark_conversation_as_read(conversation_id).await;
        self.local_repo.message.delete_conversation(conversation_id).await?;
        self.local_repo.conversation.clear_conversation(conversation_id).await
    }

    /// 删除会话并删除该会话下所有本地消息（先调服务端 clear_conversation_msg，再本地删消息并重置会话；与 Go DeleteConversationAndDeleteAllMsg 一致）
    pub async fn delete_conversation_and_delete_all_msg(&self, conversation_id: &str) -> Result<()> {
        let _ = self
            .api
            .message
            .clear_conversation_msg(ClearConversationsMsgReq {
                conversation_ids: vec![conversation_id.to_string()],
                user_id: self.config.user_id.clone(),
                delete_sync_opt: None,
            })
            .await;
        let _ = self.local_repo.message.mark_conversation_as_read(conversation_id).await;
        self.local_repo.message.delete_conversation(conversation_id).await?;
        self.local_repo.conversation.reset_conversation(conversation_id).await
    }

    /// 仅本地：删除所有会话的消息（mark_delete=true 时标记删除，否则物理删除；与 Go DeleteAllMessageFromLocalStorage / DeleteAllMsgFromLocal 一致）
    pub async fn delete_all_msg_from_local(&self, mark_delete: bool) -> Result<()> {
        let list = self.local_repo.conversation.get_all_conversations().await?;
        for c in &list {
            let _ = self.local_repo.message.mark_conversation_as_read(&c.conversation_id).await;
            if mark_delete {
                let _ = self.local_repo.message.mark_delete_conversation_all_messages(&c.conversation_id).await;
            } else {
                let _ = self.local_repo.message.delete_conversation(&c.conversation_id).await;
            }
            let _ = self.local_repo.conversation.clear_conversation(&c.conversation_id).await;
        }
        self.local_repo.conversation.reset_all_conversations().await
    }

    /// 服务端+本地删除全部消息（与 Go DeleteAllMsgFromLocalAndServer 一致）
    pub async fn delete_all_msg_from_local_and_server(&self) -> Result<()> {
        let _ = self
            .api
            .message
            .user_clear_all_msg(UserClearAllMsgReq {
                user_id: self.config.user_id.clone(),
                delete_sync_opt: None,
            })
            .await;
        self.delete_all_msg_from_local(false).await
    }

    /// 按会话与 clientMsgID 列表批量查消息，返回按会话分组的结果（与 Go FindMessageList 一致）
    pub async fn find_message_list(&self, req: Vec<ConversationArgs>) -> Result<FindMessageListCallback> {
        let mut total_count = 0i32;
        let mut find_result_items = Vec::new();
        for args in req {
            let conv = match self.local_repo.conversation.get_conversation_by_id(&args.conversation_id).await? {
                Some(c) => c,
                None => continue,
            };
            let list = self.local_repo.message.get_messages_by_client_msg_ids(&args.conversation_id, &args.client_msg_id_list).await?;
            let message_list: Vec<MsgStruct> = list.iter().map(local_chat_log_to_msg_struct).collect();
            total_count += message_list.len() as i32;
            find_result_items.push(SearchByConversationResult {
                conversation_id: args.conversation_id,
                conversation_type: conv.conversation_type,
                show_name: conv.show_name.clone(),
                face_url: conv.face_url.clone(),
                latest_msg_send_time: conv.latest_msg_send_time,
                message_count: message_list.len() as i32,
                message_list,
            });
        }
        Ok(FindMessageListCallback { total_count, find_result_items })
    }

    /// 本地搜索消息（与 Go SearchLocalMessages 一致；按 params 过滤后分页返回）
    pub async fn search_local_messages(&self, params: SearchLocalMessagesParams) -> Result<SearchLocalMessagesCallback> {
        let keyword = params.keyword_list.first().map(String::as_str);
        let begin = if params.search_time_position > 0 && params.search_time_period > 0 {
            Some(params.search_time_position - params.search_time_period)
        } else {
            None
        };
        let end = if params.search_time_position > 0 && params.search_time_period > 0 {
            Some(params.search_time_position)
        } else {
            None
        };
        let ctypes = if params.message_type_list.is_empty() { None } else { Some(params.message_type_list.as_slice()) };
        let logs = self.local_repo.message.search_local_messages(Some(&params.conversation_id), keyword, ctypes, begin, end).await?;
        let mut search_result_items = Vec::new();
        if !logs.is_empty() {
            let conv = self.local_repo.conversation.get_conversation_by_id(&params.conversation_id).await?.unwrap_or_default();
            let message_list: Vec<MsgStruct> = logs.iter().map(local_chat_log_to_msg_struct).collect();
            let total = message_list.len() as i32;
            let page_size = params.count.max(1);
            let start = (params.page_index * page_size) as usize;
            let page: Vec<MsgStruct> = message_list.into_iter().skip(start).take(page_size as usize).collect();
            search_result_items.push(SearchByConversationResult {
                conversation_id: params.conversation_id.clone(),
                conversation_type: conv.conversation_type,
                show_name: conv.show_name,
                face_url: conv.face_url,
                latest_msg_send_time: conv.latest_msg_send_time,
                message_count: page.len() as i32,
                message_list: page,
            });
        }
        Ok(SearchLocalMessagesCallback {
            total_count: logs.len() as i32,
            search_result_items,
        })
    }

    /// 按 show_name 模糊搜索会话（与 Go SearchConversation 一致）
    pub async fn search_conversation(&self, search_param: &str) -> Result<Vec<LocalConversation>> {
        self.local_repo.conversation.search_conversations(search_param).await
    }

    /// 单条消息写入本地（单聊；与 Go InsertSingleMessageToLocalStorage 一致，recv_id/send_id 必填）
    pub async fn insert_single_message_to_local_storage(&self, mut msg: MsgStruct, recv_id: &str, send_id: &str) -> Result<MsgStruct> {
        if recv_id.is_empty() || send_id.is_empty() {
            return Err(anyhow!("recv_id and send_id required"));
        }
        let peer_id = if send_id == self.config.user_id { recv_id } else { send_id };
        let conversation_id = self.conversation_id_by_session_type(peer_id, constant::SINGLE_CHAT_TYPE);
        msg.send_id = Some(send_id.to_string());
        msg.recv_id = Some(recv_id.to_string());
        msg.client_msg_id = Some(Uuid::new_v4().to_string());
        msg.send_time = chrono::Utc::now().timestamp_millis();
        msg.create_time = msg.send_time;
        msg.session_type = constant::SINGLE_CHAT_TYPE;
        msg.status = constant::MSG_STATUS_SEND_SUCCESS;
        let log = msg_struct_to_local_chat_log(&msg, &conversation_id);
        self.local_repo.message.insert_message(&log).await?;
        let conv = self.local_repo.conversation.get_conversation_by_id(&conversation_id).await?.unwrap_or_else(|| {
            let mut c = LocalConversation::default();
            c.conversation_id = conversation_id.clone();
            c.conversation_type = constant::SINGLE_CHAT_TYPE;
            c
        });
        let mut updated = conv;
        updated.latest_msg = serde_json::to_string(&msg).unwrap_or_default();
        updated.latest_msg_send_time = msg.send_time;
        let _ = self.local_repo.conversation.upsert_conversation(&updated).await;
        Ok(msg)
    }

    /// 设置消息本地扩展字段；若该条为会话最新消息则同步更新会话 latest_msg（与 Go SetMessageLocalEx 一致）
    pub async fn set_message_local_ex(&self, conversation_id: &str, client_msg_id: &str, local_ex: &str) -> Result<()> {
        self.local_repo.message.update_local_ex(conversation_id, client_msg_id, local_ex).await?;
        if let Some(conv) = self.local_repo.conversation.get_conversation_by_id(conversation_id).await? {
            if !conv.latest_msg.is_empty() {
                if let Ok(mut ms) = serde_json::from_str::<MsgStruct>(&conv.latest_msg) {
                    if ms.client_msg_id.as_deref() == Some(client_msg_id) {
                        ms.local_ex = Some(local_ex.to_string());
                        let latest_str = serde_json::to_string(&ms).unwrap_or_default();
                        let _ = self.local_repo.conversation.update_conversation_latest_msg(conversation_id, &latest_str, ms.send_time).await;
                    }
                }
            }
        }
        Ok(())
    }

    /// 隐藏全部会话（与 Go HideAllConversations 一致）
    pub async fn hide_all_conversations(&self) -> Result<()> {
        self.local_repo.conversation.reset_all_conversations().await
    }

    // ---------- 群组对外 API（与 Go GetJoinedGroupList / GetSpecifiedGroupsInfo / GetGroupMemberList 等对齐） ----------

    /// 获取当前用户已加入的群列表（本地）
    pub async fn get_joined_group_list(&self) -> Result<Vec<LocalGroup>> {
        self.local_repo.group.get_joined_group_list().await
    }

    /// 分页获取已加入群列表（与 Go GetJoinedGroupListPage 对齐）
    pub async fn get_joined_group_list_page(&self, offset: i32, count: i32) -> Result<Vec<LocalGroup>> {
        self.local_repo.group.get_joined_group_list_page(offset, count).await
    }

    /// 拉取指定群信息（先请求服务端，转 LocalGroup 并可选写回本地后返回，与 Go GetSpecifiedGroupsInfo 对齐）
    pub async fn get_specified_groups_info(&self, group_id_list: &[String]) -> Result<Vec<LocalGroup>> {
        if group_id_list.is_empty() {
            return Ok(Vec::new());
        }
        let ids: Vec<String> = group_id_list.to_vec();
        let infos = self.api.group.get_groups_info(ids).await?;
        let local: Vec<LocalGroup> = infos.iter().map(server_group_to_local).collect();
        for g in &local {
            if self.local_repo.group.get_group_info_by_group_id(&g.group_id).await?.is_some() {
                let _ = self.local_repo.group.update(g).await;
            } else {
                let _ = self.local_repo.group.insert(g).await;
            }
        }
        Ok(local)
    }

    /// 获取群成员列表（本地）
    pub async fn get_group_member_list(&self, group_id: &str) -> Result<Vec<LocalGroupMember>> {
        self.local_repo.group_member.get_member_list_by_group_id(group_id).await
    }

    /// 获取指定群成员信息（本地，与 Go GetSpecifiedGroupMembersInfo 对齐）
    pub async fn get_specified_group_members_info(&self, group_id: &str, user_id_list: &[String]) -> Result<Vec<LocalGroupMember>> {
        self.local_repo.group_member.get_some_member_info(group_id, user_id_list).await
    }

    /// 是否已加入该群（本地）
    pub async fn is_join_group(&self, group_id: &str) -> Result<bool> {
        Ok(self.local_repo.group.get_group_info_by_group_id(group_id).await?.is_some())
    }

    /// 从服务器获取好友列表（HTTP API）
    pub async fn get_all_friends(&self) -> Result<AllFriendsResp> {
        let raw = IMClient::create_http_client(&self.config)?;
        let api = FriendApi::new(raw, self.config.api_base_url.clone(), self.config.user_id.clone(), &self.config.token);
        api.get_all_friends().await
    }

    /// 获取好友列表（本地，与 Go GetFriendList 对齐）。filter_black 为 true 时排除黑名单用户
    pub async fn get_friend_list(&self, filter_black: bool) -> Result<Vec<sdkws::FriendInfo>> {
        let list = self.local_repo.friend.get_all_friends().await?;
        if !filter_black {
            return Ok(list);
        }
        let blacks = self.local_repo.black.get_black_list().await?;
        let black_set: std::collections::HashSet<String> = blacks.into_iter().map(|b| b.block_user_id).collect();
        Ok(list.into_iter().filter(|f| f.friend_user.as_ref().map(|u| !black_set.contains(&u.user_id)).unwrap_or(true)).collect())
    }

    /// 分页获取好友列表（与 Go GetFriendListPage 对齐）。filter_black 为 true 时排除黑名单用户
    pub async fn get_friend_list_page(&self, offset: i32, count: i32, filter_black: bool) -> Result<Vec<sdkws::FriendInfo>> {
        let list = self.local_repo.friend.get_friend_list_page(offset, count).await?;
        if !filter_black {
            return Ok(list);
        }
        let blacks = self.local_repo.black.get_black_list().await?;
        let black_set: std::collections::HashSet<String> = blacks.into_iter().map(|b| b.block_user_id).collect();
        Ok(list.into_iter().filter(|f| f.friend_user.as_ref().map(|u| !black_set.contains(&u.user_id)).unwrap_or(true)).collect())
    }

    /// 获取黑名单列表（本地，与 Go GetBlackList 对齐）
    pub async fn get_black_list(&self) -> Result<Vec<LocalBlack>> {
        self.local_repo.black.get_black_list().await
    }

    /// 申请添加好友（与 Go AddFriend 对齐）：调用服务端后仅返回成功/失败，本地需同步更新
    pub async fn add_friend(&self, to_user_id: &str, req_msg: &str) -> Result<()> {
        self.api.friend.add_friend(to_user_id, req_msg).await
    }

    /// 删除好友（与 Go DeleteFriend 对齐）：先调服务端再删本地
    pub async fn delete_friend(&self, friend_user_id: &str) -> Result<()> {
        self.api.friend.delete_friend(friend_user_id).await?;
        self.local_repo.friend.delete_friend(friend_user_id).await
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
            if let Some(remote) = resp.users_info.into_iter().next() {
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
    /// 单聊发送文本消息：先创建消息体再发送（创建与发送分离，与 Go CreateTextMessage + SendMessage 一致）。
    pub async fn send_text_message(&self, recv_id: String, text: String) -> Result<openim_protocol::msg::SendMsgResp> {
        let mut msg_data = create_text_message(&text);
        init_basic_info(&mut msg_data, &self.config.user_id, self.config.platform_id);
        msg_data.recv_id = recv_id;
        msg_data.session_type = constant::SINGLE_CHAT_TYPE;
        self.send_message(msg_data).await
    }

    /// 群聊发送文本消息：先创建消息体再发送；TEXT 的 content 使用 TextElem 格式 `{"content":"..."}`。
    pub async fn send_text_to_group(&self, group_id: String, text: String) -> Result<openim_protocol::msg::SendMsgResp> {
        debug!("[send_text_to_group] group_id={}, text={}", group_id, text);
        let mut msg_data = create_text_message(&text);
        init_basic_info(&mut msg_data, &self.config.user_id, self.config.platform_id);
        msg_data.group_id = group_id;
        msg_data.session_type = constant::READ_GROUP_CHAT_TYPE;
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
        // 与 Go 一致：保证返回非 null 列表，无消息时为空数组
        callback.message_list = if message_list.is_empty() { vec![] } else { message_list };
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
