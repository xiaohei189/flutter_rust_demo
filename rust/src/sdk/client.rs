mod builder;
mod message;
mod conversation;
mod friend;
mod group;
mod online_status;
pub mod types;
mod user;

pub use self::builder::OpenIMClientBuilder;
pub use self::message::*;
pub use self::conversation::*;
pub use self::friend::*;
pub use self::group::*;
pub use self::online_status::*;
pub use self::user::*;

use crate::core::connection::manager::ConnectionManager;
use crate::core::conversation::service::ConversationService;
use crate::core::conversation::syncer::ConversationSyncer;
use crate::core::file::uploader::FileUploader;
use crate::core::friend::service::FriendService;
use crate::core::group::service::GroupService;
use crate::core::message::MessageHandler;
use crate::core::message::MessageSendQueue;
use crate::core::message::MessageService;
use crate::core::message::MessageSyncer;
use crate::core::message::notification::handler::NotificationHandler;
use crate::core::user::online::service::OnlineStatusService;
use crate::core::user::service::UserService;
use crate::domain::error::{Result, SdkError};
use crate::event::events::connection::ConnectionEvent;
use crate::event::events::message::MessageEvent;
use crate::event::events::user::UserEvent;
use crate::event::hub::EventHub;
use crate::event::events::conversation::ConversationEvent;
use crate::event::events::friend::FriendEvent;
use crate::event::events::group::GroupEvent;

use crate::sdk::context::RuntimeContext;

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
    pub(crate) message_handler: Arc<MessageHandler>,
    pub(crate) notification_handler: Arc<NotificationHandler>,
    pub(crate) conversation_syncer: Arc<ConversationSyncer>,
    pub(crate) online_status: Arc<OnlineStatusService>,
    pub(crate) file_uploader: Arc<FileUploader>,
    pub(crate) message_service: Arc<MessageService>,
    
    pub(crate) send_queue: Arc<MessageSendQueue>,
    /// 事件中枢（Listener 实现 → Dart StreamSink 数据源）
    pub(crate) listeners: Arc<EventHub>,
}

impl OpenIMClient {
    /// 创建新的 SDK 实例（委托给 OpenIMClientBuilder）
    pub async fn new(config: crate::sdk::config::ClientConfig) -> Result<Self> {
        OpenIMClientBuilder::new(config).build().await
    }

    /// 获取连接事件接收器（只能调用一次，重复调用返回错误）
    pub fn take_conn_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<ConnectionEvent>, SdkError> {
        self.listeners.take_conn_rx().ok_or_else(|| SdkError::unknown("connection receiver already taken"))
    }

    /// 获取会话事件接收器（只能调用一次，重复调用返回错误）
    pub fn take_conv_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<ConversationEvent>, SdkError> {
        self.listeners.take_conv_rx().ok_or_else(|| SdkError::unknown("conversation receiver already taken"))
    }

    /// 获取好友事件接收器（只能调用一次，重复调用返回错误）
    pub fn take_friend_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<FriendEvent>, SdkError> {
        self.listeners.take_friend_rx().ok_or_else(|| SdkError::unknown("friend receiver already taken"))
    }

    /// 获取群组事件接收器（只能调用一次，重复调用返回错误）
    pub fn take_group_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<GroupEvent>, SdkError> {
        self.listeners.take_group_rx().ok_or_else(|| SdkError::unknown("group receiver already taken"))
    }

    /// 获取消息事件接收器（只能调用一次，重复调用返回错误）
    pub fn take_message_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<MessageEvent>, SdkError> {
        self.listeners.take_message_rx().ok_or_else(|| SdkError::unknown("message receiver already taken"))
    }

    /// 获取用户事件接收器（只能调用一次，重复调用返回错误）
    pub fn take_user_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<UserEvent>, SdkError> {
        self.listeners.take_user_rx().ok_or_else(|| SdkError::unknown("user receiver already taken"))
    }
}

use crate::sdk::config::ClientConfig;
use crate::infra::logger::span_from_operation_id;
use openim_protocol::sdkws::PushMessages;
use prost::Message as ProstMessage;
use tokio_util::sync::CancellationToken;
use tracing::{info, warn, debug, Instrument};

impl OpenIMClient {
    /// 连接到服务器
    #[tracing::instrument(level = "info", skip(self), fields(user_id = %user_id))]
    pub async fn connect(&self, ws_url: &str, token: &str, user_id: &str) -> Result<()> {
        self.connection.connect(ws_url, token, user_id, self.context.config.platform_id).await?;
        self.spawn_push_message_handler();
        Ok(())
    }

    /// 启动推送消息处理器 + 重连消息同步监听
    fn spawn_push_message_handler(&self) {
                let message_handler = self.message_handler.clone();
        let message_syncer = self.message_syncer.clone();
        let notification_handler = self.notification_handler.clone();
        let conversation_syncer = self.conversation_syncer.clone();
        let cancel_token = self.context.cancel_token.clone();

        let (push_tx, mut push_rx) = tokio::sync::mpsc::unbounded_channel::<(PushMessages, String)>();
        self.connection.set_push_sender(push_tx);

        *self.connection.on_connected_hook.lock().expect("on_connected_hook mutex poisoned") = Some(Box::new({
            let mh = message_handler.clone();
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
                    if ct.is_cancelled() { return; }
                    if ms.is_connection_kicked().await { info!("push_message_handler: connection was kicked, skipping sync"); return; }
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
                                message_handler.clone(),
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

    /// 断开连接
    #[tracing::instrument(level = "info", skip(self))]
    pub async fn disconnect(&self) {
        self.context.shutdown();
        info!("SDK 已断开连接");
    }

    /// 登录
    #[tracing::instrument(level = "info", skip(self), fields(user_id = %user_id))]
    pub async fn login(&self, user_id: &str, token: &str) -> Result<()> {
        info!("[SDK] 开始登录，user_id={}", user_id);

        self.context.set_user_id(user_id.to_string());
        self.friend.set_user_id(user_id.to_string()).await;
        self.group.set_user_id(user_id.to_string()).await;
        self.notification_handler.set_user_id(user_id.to_string());
        self.message_handler.set_user_id(user_id.to_string());
        self.message_service.set_user_id(user_id.to_string());
        self.conversation_syncer.set_user_id(user_id.to_string()).await;
        self.file_uploader.set_login_user_id(user_id.to_string());

        debug!("[SDK] 用户上下文已设置");

        self.cleanup_sending_messages().await;

        if let Some(ws_url) = &self.context.config.ws_url {
            info!("[SDK] 开始 WebSocket 连接，ws_url={}", ws_url);
            self.connection.connect(ws_url, token, user_id, self.context.config.platform_id).await?;
            debug!("[SDK] WebSocket 连接成功");
            self.spawn_push_message_handler();
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
                    let minimal = crate::domain::model::user::UserInfo {
                        user_id: uid.clone(), nickname: uid.clone(),
                        face_url: String::new(), gender: 0, telephone: String::new(),
                        email: String::new(), remark: String::new(), global_recv_msg_opt: 0,
                    };
                    self.user.set_self_user_info(minimal).await;
                    debug!("[SDK] self_user 使用最小信息初始化");
                }
            }
            Err(e) => {
                warn!("[SDK] 获取 self_user 失败，使用最小信息兜底: {}", e);
                let minimal = crate::domain::model::user::UserInfo {
                    user_id: uid.clone(), nickname: uid.clone(),
                    face_url: String::new(), gender: 0, telephone: String::new(),
                    email: String::new(), remark: String::new(), global_recv_msg_opt: 0,
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
    pub async fn logout(&self) -> Result<()> {
        self.user.clear().await;
        self.friend.clear().await;
        self.group.clear().await;
        self.conversation.clear_all().await;
        self.online_status.clear_subscriptions().await?;
        self.connection.send(ConnectionEvent::Logout);
        info!("用户登出成功");
        Ok(())
    }

    

    pub fn login_user_id(&self) -> String {
        self.context.get_user_id()
    }

    pub async fn sync_all_conversation_hash_read_seqs(&self) -> Result<()> {
        self.conversation_syncer
            .sync_conversation_hash_read_seqs(&self.message_handler.max_seq_recorder).await
    }

    pub async fn incr_sync_conversations(&self) -> Result<()> {
        self.conversation_syncer.sync_incremental_with_lock().await?;
        Ok(())
    }

    pub async fn get_connection_state(&self) -> crate::core::connection::manager::ConnectionState {
        self.connection.get_state().await
    }

    pub async fn is_connected(&self) -> bool {
        self.connection.is_connected().await
    }
}

/// 处理一批推送消息
async fn handle_push_batch(
    message_handler: Arc<MessageHandler>,
    message_syncer: Arc<MessageSyncer>,
    notification_handler: Arc<NotificationHandler>,
    batch: PushMessages,
) {
    let mut has_message_changes = false;

    for (conv_id, pull_msgs) in &batch.msgs {
        let messages = pull_msgs.msgs.clone();
        let seqs: Vec<i64> = pull_msgs.msgs.iter().map(|m| m.seq).filter(|&s| s > 0).collect();

        if !messages.is_empty() {
            match message_handler.handle_messages(conv_id, messages).await {
                Ok(changed) => { if changed { has_message_changes = true; } }
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
        message_handler.publish_total_unread_count_changed().await;
    }
}



