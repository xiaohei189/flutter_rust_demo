use crate::client::builder::OpenIMClientBuilder;

use crate::client::{ConnectionApi, MessageApi};
use crate::connection::manager::ConnectionManager;
use crate::conversation::service::ConversationService;
use crate::conversation::syncer::ConversationSyncer;
use crate::friend::service::FriendService;
use crate::group::service::GroupService;
use crate::message::send::MessageSender;
use crate::message::MessageProcessor;
use async_trait::async_trait;

use crate::error::{Result, SdkError};
use crate::event::events::connection::ConnectionEvent;
use crate::event::events::conversation::ConversationEvent;
use crate::event::events::friend::FriendEvent;
use crate::event::events::group::GroupEvent;
use crate::event::events::message::MessageEvent;
use crate::event::events::user::UserEvent;
use crate::event::hub::EventHub;
use crate::message::notification::NotificationHandler;
use crate::message::MessageService;
use crate::message::MessageSyncer;
use crate::user::online::service::OnlineStatusService;
use crate::user::service::UserService;

use crate::client::context::RuntimeContext;

use std::sync::Arc;

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

use crate::client::config::ClientConfig;
use crate::logger::span_from_operation_id;
use openim_protocol::sdkws::PushMessages;
use prost::Message as ProstMessage;
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
    pub async fn new(config: crate::client::config::ClientConfig) -> Result<Self> {
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
        tokio::spawn(async move {
            debug!("[SDK] 后台开始好友同步");
            if let Err(e) = friend.sync_friends_incremental().await {
                warn!("[SDK] 登录后好友增量同步失败，回退全量同步: {}", e);
                if let Err(e2) = friend.sync_friends().await {
                    warn!("[SDK] 登录后好友全量同步失败: {}", e2);
                }
            } else {
                debug!("[SDK] 好友同步完成");
            }
            debug!("[SDK] 后台开始群组同步");
            if let Err(e) = group.sync_groups_incremental().await {
                warn!("[SDK] 登录后群组增量同步失败，回退全量同步: {}", e);
                if let Err(e2) = group.sync_groups().await {
                    warn!("[SDK] 登录后群组全量同步失败: {}", e2);
                }
            } else {
                debug!("[SDK] 群组同步完成");
            }
        });

        let uid = user_id.to_string();
        match self.user.get_users_info(vec![uid.clone()]).await {
            Ok(users) => {
                if let Some(user) = users.into_iter().next() {
                    self.user.set_self_user_info(user).await;
                    debug!("[SDK] self_user 缓存已初始化");
                } else {
                    let minimal = crate::model::user::UserInfo {
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
                let minimal = crate::model::user::UserInfo {
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

    /// 登出
    #[tracing::instrument(level = "info", skip(self))]
    async fn logout(&self) -> Result<()> {
        self.user.clear().await;
        self.friend.clear().await;
        self.group.clear().await;
        self.conversation.clear_all().await;
        self.online_status.clear_subscriptions().await?;
        self.connection.send(ConnectionEvent::Logout);
        info!("用户登出成功");
        Ok(())
    }

    fn login_user_id(&self) -> String {
        self.context.get_user_id()
    }

    async fn get_connection_state(&self) -> crate::connection::manager::ConnectionState {
        self.connection.get_state().await
    }

    async fn is_connected(&self) -> bool {
        self.connection.is_connected().await
    }
}

impl OpenIMClient {
    /// 启动推送消息处理器 + 重连消息同步监听（仅由 Builder 启动一次）
    pub(crate) fn start_push_handler(&self) {
        let message_processor = self.message_processor.clone();
        let message_syncer = self.message_syncer.clone();
        let notification_handler = self.notification_handler.clone();
        let conversation_syncer = self.conversation_syncer.clone();
        let cancel_token = self.context.cancel_token.clone();

        let (push_tx, mut push_rx) = tokio::sync::mpsc::unbounded_channel::<(PushMessages, String)>();
        self.connection.set_push_sender(push_tx);

        *self.connection.on_connected_hook.lock().expect("on_connected_hook mutex poisoned") = Some(Box::new({
            let mh = message_processor.clone();
            let ms = message_syncer.clone();
            let cs = conversation_syncer.clone();
            let ct = cancel_token.clone();
            move || {
                let mh = mh.clone();
                let ms = ms.clone();
                let cs = cs.clone();
                let ct = ct.clone();
                tokio::spawn(async move {
                    tokio::time::sleep(std::time::Duration::from_millis(500)).await;
                    if ct.is_cancelled() {
                        return;
                    }
                    if ms.is_connection_kicked().await {
                        info!("push_message_handler: connection was kicked, skipping sync");
                        return;
                    }
                    info!("push_message_handler: connection established, syncing conversations then messages");
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
