use crate::sdk::client::builder::OpenIMClientBuilder;

use crate::sdk::client::{ConnectionApi, MessageApi};
use crate::core::connection::manager::ConnectionManager;
use crate::core::conversation::service::ConversationService;
use crate::core::conversation::syncer::ConversationSyncer;
use crate::sdk::friend::service::FriendService;
use crate::sdk::group::service::GroupService;
use crate::core::message::send::MessageSender;
use crate::core::message::MessageProcessor;
use async_trait::async_trait;

use crate::domain::error::{Result, SdkError};
use crate::core::event::events::connection::ConnectionEvent;
use crate::core::event::hub::EventHub;
use crate::core::message::notification::NotificationHandler;
use crate::core::message::MessageService;
use crate::core::message::MessageSyncer;
use crate::core::user::online::service::OnlineStatusService;
use crate::core::user::service::UserService;

use crate::sdk::client::context::RuntimeContext;

use std::sync::Arc;
use std::time::Duration;
use tokio::time::timeout;

// ============================================================================
// SDK API 类型定义
// ============================================================================

pub struct OpenIMClient {
    pub(crate) context: Arc<RuntimeContext>,
    pub(crate) connection: Arc<ConnectionManager>,
    pub(crate) user: Arc<UserService>,
    pub(crate) friend: Arc<FriendService>,
    pub(crate) group: Arc<GroupService>,
    pub(crate) conversation: Arc<ConversationService>,
    pub(crate) message_syncer: Arc<MessageSyncer>,
    pub(crate) message_processor: Arc<MessageProcessor>,
    pub(crate) notification_handler: Arc<NotificationHandler>,
    pub(crate) conversation_syncer: Arc<ConversationSyncer>,
    pub(crate) online_status: Arc<OnlineStatusService>,
    pub(crate) sender: Arc<MessageSender>,
    pub(crate) message_service: Arc<MessageService>,

    /// 事件中枢（Listener 实现 → Dart StreamSink 数据源）
    pub(crate) listeners: Arc<EventHub>,
}

use crate::domain::constant::sync_flag;
use crate::domain::constant::ws_push_identifier;
use crate::infra::logger::span_from_operation_id;
use openim_protocol::sdkws::PushMessages;
use openim_protocol::sdkws::{SetAppBackgroundStatusReq, SetAppBackgroundStatusResp};
use tracing::{debug, info, warn, Instrument};

/// 处理一批推送消息
async fn handle_push_batch(message_processor: Arc<MessageProcessor>, message_syncer: Arc<MessageSyncer>, notification_handler: Arc<NotificationHandler>, batch: PushMessages) {
    let mut has_message_changes = false;

    for (conv_id, pull_msgs) in &batch.msgs {
        let messages = pull_msgs.msgs.clone();
        let seqs: Vec<i64> = pull_msgs.msgs.iter().map(|m| m.seq).filter(|&s| s > 0).collect();

        if !messages.is_empty() {
            match message_processor.handle_messages(conv_id, messages).await {
                Ok(changed) => {
                    if changed {
                        has_message_changes = true;
                    }
                }
                Err(e) => warn!("failed to handle push messages for {}: {:?}", conv_id, e),
            }
            if let Err(e) = message_syncer.push_trigger_and_sync(conv_id, &seqs).await {
                warn!("push_trigger_and_sync failed for {}: {:?}", conv_id, e);
            }
        } else if !seqs.is_empty() {
            if let Err(e) = message_syncer.push_trigger_and_sync(conv_id, &seqs).await {
                warn!("push_trigger_and_sync (seq 0) failed for {}: {:?}", conv_id, e);
            }
        }
    }

    for (_conv_id, pull_msgs) in &batch.notification_msgs {
        notification_handler.handle_notifications(&pull_msgs.msgs).await;
        let seqs: Vec<i64> = pull_msgs.msgs.iter().map(|m| m.seq).filter(|&s| s > 0).collect();
        if !seqs.is_empty() {
            let _ = message_syncer.push_trigger_and_sync(_conv_id, &seqs).await;
        }
    }

    if has_message_changes {
        message_processor.publish_total_unread_count_changed().await;
    }
}

impl OpenIMClient {
    /// 创建新的 SDK 实例（委托给 OpenIMClientBuilder）
    pub async fn new(config: crate::sdk::client::config::ClientConfig) -> Result<Self> {
        OpenIMClientBuilder::new(config).build().await
    }
}

#[async_trait]
impl ConnectionApi for OpenIMClient {
    /// 获取连接事件接收器（只能调用一次，重复调用返回错误）
    fn take_conn_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<ConnectionEvent>, SdkError> {
        self.listeners.take_conn_rx().ok_or_else(|| SdkError::unknown("connection receiver already taken"))
    }

    /// 连接到服务器
    #[tracing::instrument(level = "info", skip(self), fields(user_id = %user_id))]
    async fn connect(&self, ws_url: &str, token: &str, user_id: &str) -> Result<()> {
        self.connection.connect(ws_url, token, user_id, self.context.config.platform_id).await?;
        Ok(())
    }

    /// 断开连接
    #[tracing::instrument(level = "info", skip(self))]
    async fn disconnect(&self) {
        self.connection.disconnect().await;
        info!("SDK 已断开连接");
    }

    /// 登录
    #[tracing::instrument(level = "info", skip(self), fields(user_id = %user_id))]
    async fn login(&self, user_id: &str, token: &str) -> Result<()> {
        info!("[SDK] 开始登录，user_id={}", user_id);

        self.context.set_user_id(user_id.to_string());
        self.sender.set_login_user_id(user_id.to_string());

        debug!("[SDK] 用户上下文已设置");

        self.cleanup_sending_messages().await;

        if let Some(ws_url) = &self.context.config.ws_url {
            info!("[SDK] 开始 WebSocket 连接，ws_url={}", ws_url);
            self.connection.connect(ws_url, token, user_id, self.context.config.platform_id).await?;
            debug!("[SDK] WebSocket 连接成功");
        } else {
            warn!("[SDK] ws_url 未配置，跳过 WebSocket 连接");
        }

        let friend = self.friend.clone();
        let group = self.group.clone();
        let conversation_syncer = self.conversation_syncer.clone();
        let conversation_service = self.conversation.clone();
        let message_syncer = self.message_syncer.clone();
        let repositories = self.context.repositories.clone();
        tokio::spawn(async move {
            // 先从本地数据库加载好友/群组到内存缓存，避免增量同步无变更时列表为空
            friend.load_friends_from_db().await;
            group.load_groups_from_db().await;

            let reinstalled = repositories.sync_version_repo.is_reinstalled().await.unwrap_or(false);
            if reinstalled {
                let stage = repositories.sync_version_repo.get_sync_flag().await.unwrap_or(0);

                if stage < sync_flag::SYNC_STAGE_GROUPS {
                    let _ = repositories.sync_version_repo.set_sync_flag(sync_flag::SYNC_STAGE_FRIENDS).await;
                    debug!("[SDK] 重装阶段：好友全量同步");
                    if let Err(e) = friend.sync_friends().await {
                        warn!("[SDK] 重装好友全量同步失败: {}", e);
                    }
                    let _ = repositories.sync_version_repo.set_sync_flag(sync_flag::SYNC_STAGE_GROUPS).await;
                }

                let stage = repositories.sync_version_repo.get_sync_flag().await.unwrap_or(0);
                if stage < sync_flag::SYNC_STAGE_CONVERSATIONS {
                    let _ = repositories.sync_version_repo.set_sync_flag(sync_flag::SYNC_STAGE_GROUPS).await;
                    debug!("[SDK] 重装阶段：群组全量同步");
                    if let Err(e) = group.sync_groups().await {
                        warn!("[SDK] 重装群组全量同步失败: {}", e);
                    }
                    let _ = repositories.sync_version_repo.set_sync_flag(sync_flag::SYNC_STAGE_CONVERSATIONS).await;
                }

                let stage = repositories.sync_version_repo.get_sync_flag().await.unwrap_or(0);
                if stage < sync_flag::SYNC_STAGE_MESSAGES {
                    debug!("[SDK] 重装阶段：会话全量同步");
                    if let Err(e) = conversation_syncer.sync_full().await {
                        warn!("[SDK] 重装会话全量同步失败: {}", e);
                    }
                    let _ = repositories.sync_version_repo.set_sync_flag(sync_flag::SYNC_STAGE_MESSAGES).await;
                }

                let stage = repositories.sync_version_repo.get_sync_flag().await.unwrap_or(0);
                if stage < sync_flag::SYNC_STAGE_DONE {
                    debug!("[SDK] 重装阶段：消息全量同步");
                    let _ = message_syncer.sync_all_conversations(true).await;
                    let _ = repositories.sync_version_repo.set_sync_flag(sync_flag::SYNC_STAGE_DONE).await;
                }
            } else {
                debug!("[SDK] 普通登录：后台开始好友同步");
                if let Err(e) = friend.sync_friends_incremental().await {
                    warn!("[SDK] 登录后好友增量同步失败，回退全量同步: {}", e);
                    if let Err(e2) = friend.sync_friends().await {
                        warn!("[SDK] 登录后好友全量同步失败: {}", e2);
                    }
                }
                debug!("[SDK] 普通登录：后台开始群组同步");
                if let Err(e) = group.sync_groups_incremental().await {
                    warn!("[SDK] 登录后群组增量同步失败，回退全量同步: {}", e);
                    if let Err(e2) = group.sync_groups().await {
                        warn!("[SDK] 登录后群组全量同步失败: {}", e2);
                    }
                }
                debug!("[SDK] 普通登录：后台开始会话增量同步");
                let _ = conversation_syncer.sync_incremental().await;

                // 对齐 Go SDK：好友/群组/用户数据源就绪后重算全部会话名称，
                // 修复历史遗留的占位符（如 sg_xxx）或数据源晚于会话同步导致的空名
                if let Err(e) = conversation_service.refresh_face_url_and_name().await {
                    warn!("[SDK] 登录后刷新会话名称失败: {}", e);
                }
            }
        });

        let uid = user_id.to_string();
        match self.user.get_users_info(vec![uid.clone()]).await {
            Ok(users) => {
                if let Some(user) = users.into_iter().next() {
                    self.user.set_self_user_info(user).await;
                    debug!("[SDK] self_user 缓存已初始化");
                } else {
                    let minimal = crate::domain::model::user::UserInfo {
                        user_id: uid.clone(),
                        nickname: uid.clone(),
                        face_url: String::new(),
                        gender: 0,
                        telephone: String::new(),
                        email: String::new(),
                        remark: String::new(),
                        global_recv_msg_opt: 0,
                    };
                    self.user.set_self_user_info(minimal).await;
                    debug!("[SDK] self_user 使用最小信息初始化");
                }
            }
            Err(e) => {
                warn!("[SDK] 获取 self_user 失败，使用最小信息兜底: {}", e);
                let minimal = crate::domain::model::user::UserInfo {
                    user_id: uid.clone(),
                    nickname: uid.clone(),
                    face_url: String::new(),
                    gender: 0,
                    telephone: String::new(),
                    email: String::new(),
                    remark: String::new(),
                    global_recv_msg_opt: 0,
                };
                self.user.set_self_user_info(minimal).await;
            }
        }

        self.connection.send(ConnectionEvent::LoginSuccess(uid));
        debug!("[SDK] 用户登录成功: {}", user_id);
        Ok(())
    }

    /// 登出（对齐 Go SDK logout：通知登出事件 → 断开连接 → 关闭本地数据库 → 重置 SDK 状态）
    #[tracing::instrument(level = "info", skip(self))]
    async fn logout(&self) -> Result<()> {
        self.connection.send(ConnectionEvent::Logout);
        self.user.clear().await;
        self.friend.clear().await;
        self.group.clear().await;
        // 在线状态退订走 WS RPC（send_rpc 超时 30s），登出不应阻塞 UI：1s 短超时，失败仅告警（对齐 Go「失败不影响后续流程」）
        match timeout(Duration::from_secs(1), self.online_status.clear_subscriptions()).await {
            Ok(Ok(_)) => {}
            Ok(Err(e)) => warn!("[SDK] 登出时清理在线状态订阅失败: {}", e),
            Err(_) => warn!("[SDK] 登出时清理在线状态订阅超时，忽略"),
        }
        self.connection.disconnect().await;
        self.context.shutdown();
        // 关闭本地数据库（防御性短超时，避免极端情况下阻塞登出）
        let _ = timeout(Duration::from_secs(2), self.context.close_db()).await;
        info!("用户登出成功");
        Ok(())
    }

    fn login_user_id(&self) -> String {
        self.context.get_user_id()
    }

    async fn get_connection_state(&self) -> crate::core::connection::manager::ConnectionState {
        self.connection.get_state().await
    }

    async fn is_connected(&self) -> bool {
        self.connection.is_connected().await
    }

    async fn set_app_background_status(&self, is_background: bool) -> Result<()> {
        let req = SetAppBackgroundStatusReq {
            user_id: self.context.get_user_id(),
            is_background,
        };
        let _: SetAppBackgroundStatusResp = self.connection.send_rpc(ws_push_identifier::SET_BACKGROUND_STATUS, &req).await?;

        if !is_background {
            info!("[SDK] App 回到前台，触发会话/消息同步");
            if let Err(e) = self.conversation_syncer.sync_incremental().await {
                warn!("[SDK] 前台会话增量同步失败: {}", e);
            }
            if let Err(e) = self.message_syncer.sync_on_wakeup().await {
                warn!("[SDK] 前台消息同步失败: {}", e);
            }
            self.message_processor.publish_total_unread_count_changed().await;
        }
        Ok(())
    }

    async fn network_status_changed(&self) -> Result<()> {
        if self.connection.is_connected().await {
            info!("[SDK] 网络状态变化，触发增量同步");
            if let Err(e) = self.conversation_syncer.sync_incremental().await {
                warn!("[SDK] 网络变化会话同步失败: {}", e);
            }
            if let Err(e) = self.message_syncer.sync_after_reconnect().await {
                warn!("[SDK] 网络变化消息同步失败: {}", e);
            }
            self.message_processor.publish_total_unread_count_changed().await;
        } else {
            info!("[SDK] 网络状态变化，当前未连接，等待重连循环处理");
        }
        Ok(())
    }
}

impl OpenIMClient {
    /// 启动推送消息处理器 + 重连消息同步监听（仅由 Builder 启动一次）
    pub(crate) fn start_push_handler(&self) {
        let message_processor = self.message_processor.clone();
        let message_syncer = self.message_syncer.clone();
        let notification_handler = self.notification_handler.clone();
        let conversation_syncer = self.conversation_syncer.clone();
        let repositories = self.context.repositories.clone();
        let cancel_token = self.context.cancel_token.clone();
        let online_status = self.online_status.clone();

        let (push_tx, mut push_rx) = tokio::sync::mpsc::unbounded_channel::<(PushMessages, String)>();
        self.connection.set_push_sender(push_tx);

        *self.connection.on_connected_hook.lock().expect("on_connected_hook mutex poisoned") = Some(Box::new({
            let mh = message_processor.clone();
            let ms = message_syncer.clone();
            let cs = conversation_syncer.clone();
            let repos = repositories.clone();
            let ct = cancel_token.clone();
            let os = online_status.clone();
            move || {
                let mh = mh.clone();
                let ms = ms.clone();
                let cs = cs.clone();
                let repos = repos.clone();
                let ct = ct.clone();
                let os = os.clone();
                tokio::spawn(async move {
                    tokio::time::sleep(std::time::Duration::from_millis(500)).await;
                    if ct.is_cancelled() {
                        return;
                    }
                    if ms.is_connection_kicked().await {
                        info!("push_message_handler: connection was kicked, skipping sync");
                        return;
                    }
                    if repos.sync_version_repo.is_reinstalled().await.unwrap_or(false) {
                        info!("push_message_handler: reinstall sync in progress, skipping");
                        return;
                    }
                    info!("push_message_handler: connection established, syncing conversations then messages");
                    os.resubscribe_all().await;
                    if let Err(e) = cs.sync_incremental().await {
                        warn!("push_message_handler: conversation sync after reconnect failed: {:?}", e);
                        let _ = cs.sync_full().await;
                    }
                    let _ = ms.sync_after_reconnect().await;
                    mh.publish_total_unread_count_changed().await;
                });
            }
        }));

        tokio::spawn(async move {
            debug!("push_message_handler: started");
            loop {
                tokio::select! {
                    _ = cancel_token.cancelled() => {
                        info!("push_message_handler: cancelled");
                        break;
                    }

                    push_batch = push_rx.recv() => {
                        if let Some((batch, operation_id)) = push_batch {
                            let span = span_from_operation_id("push_message_handler", &operation_id);
                            handle_push_batch(
                                message_processor.clone(),
                                message_syncer.clone(),
                                notification_handler.clone(),
                                batch,
                            )
                            .instrument(span)
                            .await;
                        }
                    }
                }
            }
        });
    }
}
