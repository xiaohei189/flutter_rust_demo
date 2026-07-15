use crate::core::connection::manager::ConnectionManager;
use crate::core::conversation::manager::ConversationManager;
use crate::core::conversation::syncer::ConversationSyncer;
use crate::core::file::uploader::FileUploader;
use crate::core::friend::manager::FriendManager;
use crate::core::group::manager::GroupManager;
use crate::core::message::handler::MessageHandler;
use crate::core::message::send_queue::MessageSendQueue;
use crate::core::notification::handler::NotificationHandler;
use crate::domain::model::message::ReceivedMessage;
use crate::core::message::service::MessageService;
use crate::core::message::syncer::MessageSyncer;
use crate::core::online::manager::OnlineStatusManager;
use crate::core::user::manager::UserManager;
use crate::domain::config::ClientConfig;
use crate::domain::error::types::Result;
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::listener::connection::ConnectionEvent;
use crate::domain::listener::conversation::ConversationEvent;
use crate::domain::listener::friend::FriendEvent;
use crate::domain::listener::group::GroupEvent;
use crate::infra::cache::memory::CacheManager;
use crate::protocol::sdkws::PushMessages;
use crate::sdk::client::OpenIMClient;
use crate::sdk::context::RuntimeContext;
use prost::Message as ProstMessage;
use std::sync::Arc;
use tokio_stream::StreamExt;
use tokio_util::sync::CancellationToken;
use tracing::{info, warn, debug};

impl OpenIMClient {
    /// 创建新的 SDK 实例
    pub async fn new(config: ClientConfig) -> Result<Self> {
        let event_bus = Arc::new(EventBus::new());
        let cache = Arc::new(CacheManager::new());
        let cancel_token = CancellationToken::new();

        let context = Arc::new(
            RuntimeContext::new(
                config.clone(),
                event_bus.clone(),
                cancel_token.clone(),
            )
            .await?,
        );

        let connection = Arc::new(ConnectionManager::new(
            cancel_token.clone(),
        ));

        let user = Arc::new(UserManager::new(
            context.http_client.clone(),
            event_bus.clone(),
        ));
        let user_id = context.user_id.lock().unwrap().clone();
        let friend = Arc::new(FriendManager::new(
            context.http_client.clone(),
            user_id.clone(),
            context.friend_dao.clone(),
            context.sync_version_dao.clone(),
        ));
        let group = Arc::new(GroupManager::new(
            context.http_client.clone(),
            user_id.clone(),
            context.group_dao.clone(),
            context.sync_version_dao.clone(),
        ));
        let conversation = Arc::new(ConversationManager::new(
            context.conversation_dao.clone(),
            context.message_dao.clone(),
        ));
        let online_status = Arc::new(OnlineStatusManager::new(
            context.http_client.clone(),
            event_bus.clone(),
        ));

        let file_uploader = Arc::new(FileUploader::new(
            context.http_client.clone(),
        ));

        let message_handler = Arc::new(MessageHandler::new(
            context.message_dao.clone(),
            context.conversation_dao.clone(),
            context.user_dao.clone(),
            context.group_dao.clone(),
        ));

        let message_syncer = Arc::new(MessageSyncer::new(
            connection.clone(),
            context.conversation_dao.clone(),
            context.message_dao.clone(),
            context.sync_version_dao.clone(),
            context.notification_seq_dao.clone(),
            message_handler.clone(),
            config.user_id.clone(),
        ));

        let conversation_syncer = Arc::new(ConversationSyncer::new(
            context.http_client.clone(),
            context.conversation_dao.clone(),
            context.sync_version_dao.clone(),
            config.user_id.clone(),
        ));

        let message_service = Arc::new(MessageService::new(
            context.message_dao.clone(),
            context.conversation_dao.clone(),
            event_bus.clone(),
            context.http_client.clone(),
            config.user_id.clone(),
        ));

        let notification_handler = Arc::new(NotificationHandler::new(
            friend.clone(),
            group.clone(),
            user.clone(),
            conversation_syncer.clone(),
            message_handler.clone(),
            event_bus.clone(),
        ));

        let send_queue = MessageSendQueue::new();

        // 创建 4 个事件通道，在 login 之前设置 sender，login 期间的事件不会丢失
        let (conn_tx, conn_rx) = tokio::sync::mpsc::unbounded_channel::<ConnectionEvent>();
        connection.set_event_sender(conn_tx);
        let (conv_tx, conv_rx) = tokio::sync::mpsc::unbounded_channel::<ConversationEvent>();
        message_handler.set_event_sender(conv_tx.clone());
        message_service.set_event_sender(conv_tx.clone());
        message_syncer.set_event_sender(conv_tx.clone());
        conversation_syncer.set_event_sender(conv_tx.clone());
        conversation.set_event_sender(conv_tx);
        let (friend_tx, friend_rx) = tokio::sync::mpsc::unbounded_channel::<FriendEvent>();
        friend.set_event_sender(friend_tx);
        let (group_tx, group_rx) = tokio::sync::mpsc::unbounded_channel::<GroupEvent>();
        group.set_event_sender(group_tx);

        debug!("OpenIM SDK 初始化完成");

        Ok(Self {
            context,
            connection,
            user,
            friend,
            group,
            conversation,
            message_syncer,
            message_handler,
            notification_handler,
            conversation_syncer,
            online_status,
            file_uploader,
            message_service,
            event_bus,
            cache,
            send_queue,
            conn_rx: Arc::new(std::sync::Mutex::new(Some(conn_rx))),
            conv_rx: Arc::new(std::sync::Mutex::new(Some(conv_rx))),
            friend_rx: Arc::new(std::sync::Mutex::new(Some(friend_rx))),
            group_rx: Arc::new(std::sync::Mutex::new(Some(group_rx))),
        })
    }

    /// 连接到服务器
    #[tracing::instrument(level = "info", skip(self), fields(user_id = %user_id))]
    pub async fn connect(&self, ws_url: &str, token: &str, user_id: &str) -> Result<()> {
        self.connection.connect(ws_url, token, user_id, self.context.config.platform_id).await?;
        self.spawn_push_message_handler();
        Ok(())
    }

    /// 启动推送消息处理器 + 重连消息同步监听
    fn spawn_push_message_handler(&self) {
        let event_bus = self.event_bus.clone();
        let message_handler = self.message_handler.clone();
        let message_syncer = self.message_syncer.clone();
        let notification_handler = self.notification_handler.clone();
        let conversation_syncer = self.conversation_syncer.clone();
        let cancel_token = self.context.cancel_token.clone();

        // 内部消息通道：对齐 Go SDK 直接调用模式，WS 消息不走 EventBus
        // 携带 trace context 以便跨 task 传递
        let (push_tx, mut push_rx) = tokio::sync::mpsc::unbounded_channel::<(PushMessages, tracing::Span)>();
        self.connection.set_push_sender(push_tx);

        // 对齐 Go SDK：Connected 事件直接回调同步，不走 EventBus
        *self.connection.on_connected_hook.lock().unwrap() = Some(Box::new({
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
            let mut subscription = event_bus.subscribe();
            debug!("push_message_handler: started");
            loop {
                tokio::select! {
                    _ = cancel_token.cancelled() => {
                        info!("push_message_handler: cancelled");
                        break;
                    }
                    event = subscription.next() => {
                        match event {
                            Some(SdkEvent::PushNotificationMessages { msgs, .. }) => {
                                notification_handler.handle_notifications(&msgs).await;
                            }
                            None => {
                                info!("push_message_handler: event stream closed");
                                break;
                            }
                            _ => {}
                        }
                    }
                    push_batch = push_rx.recv() => {
                        if let Some((batch, span)) = push_batch {
                            let mut has_message_changes = false;
                            let _enter = span.enter();

                            for (conv_id, pull_msgs) in &batch.msgs {
                                let messages: Vec<ReceivedMessage> = pull_msgs.msgs.iter().filter_map(|msg| {
                                    let content_str = String::from_utf8_lossy(&msg.content).to_string();
                                    Some(ReceivedMessage {
                                        server_msg_id: msg.server_msg_id.clone(),
                                        client_msg_id: msg.client_msg_id.clone(),
                                        send_id: msg.send_id.clone(),
                                        recv_id: msg.recv_id.clone(),
                                        sender_platform_id: msg.sender_platform_id,
                                        sender_nick_name: msg.sender_nickname.clone(),
                                        sender_face_url: msg.sender_face_url.clone(),
                                        session_type: msg.session_type,
                                        msg_from: msg.msg_from,
                                        content_type: msg.content_type,
                                        content: content_str,
                                        seq: msg.seq,
                                        send_time: msg.send_time,
                                        create_time: msg.create_time,
                                        conversation_id: conv_id.clone(),
                                        group_id: msg.group_id.clone(),
                                        is_online_only: msg.options.get("isOnlineOnly").copied().unwrap_or(false),
                                    })
                                }).collect();
                                let seqs: Vec<i64> = pull_msgs.msgs.iter().map(|m| m.seq).filter(|&s| s > 0).collect();

                                if !messages.is_empty() {
                                    match message_handler.handle_messages(messages).await {
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

        // 登录时清理发送中的消息（对齐 Go SDK userRelated.go L332-375）
        self.cleanup_sending_messages().await;

        if let Some(ws_url) = &self.context.config.ws_url {
            info!("[SDK] 开始 WebSocket 连接，ws_url={}", ws_url);
            self.connection.connect(ws_url, token, user_id, self.context.config.platform_id).await?;
            debug!("[SDK] WebSocket 连接成功");
            self.spawn_push_message_handler();
        } else {
            warn!("[SDK] ws_url 未配置，跳过 WebSocket 连接");
        }

        // 好友、群组同步在后台执行
        // 会话和消息同步已移到 Connected 事件处理器（先会话后消息，对齐 Go SDK）
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

        // 初始化 self_user 缓存：拉取当前用户信息并写入内存，后续 update_self_user_info 依赖此缓存
        let uid = user_id.to_string();
        match self.user.get_users_info(vec![uid.clone()]).await {
            Ok(users) => {
                if let Some(user) = users.into_iter().next() {
                    self.user.set_self_user_info(user).await;
                    debug!("[SDK] self_user 缓存已初始化");
                } else {
                    // 服务器未返回用户信息，至少设置 user_id 确保后续操作不报"用户未登录"
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
                // 网络失败时用最小信息兜底
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

    /// 获取事件总线（内部使用）
    #[tracing::instrument(level = "info", skip(self))]
    pub fn event_bus(&self) -> Arc<EventBus> {
        self.event_bus.clone()
    }

    /// 获取当前登录用户 ID
    #[tracing::instrument(level = "info", skip(self))]
    pub fn login_user_id(&self) -> String {
        self.context.get_user_id()
    }

    /// 同步所有会话的 Hash Read Seq（用于前台唤醒）
    #[tracing::instrument(level = "info", skip(self))]
    pub async fn sync_all_conversation_hash_read_seqs(&self) -> Result<()> {
        self.conversation_syncer
            .sync_conversation_hash_read_seqs(&self.message_handler.max_seq_recorder)
            .await
    }

    /// 增量同步会话列表（对齐 Go SDK `IncrSyncConversations`）
    ///
    /// 版本号持久化到数据库，重连后无需全量同步。
    /// 收到会话变更通知时调用。
    #[tracing::instrument(level = "info", skip(self))]
    pub async fn incr_sync_conversations(&self) -> Result<()> {
        self.conversation_syncer.sync_incremental_with_lock().await?;
        Ok(())
    }

    /// 获取连接状态
    #[tracing::instrument(level = "info", skip(self))]
    pub async fn get_connection_state(&self) -> crate::core::connection::manager::ConnectionState {
        self.connection.get_state().await
    }

    /// 是否已连接
    pub async fn is_connected(&self) -> bool {
        self.connection.is_connected().await
    }
}
