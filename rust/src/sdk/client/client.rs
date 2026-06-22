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
            event_bus.clone(),
            cancel_token.clone(),
        ));

        let user = Arc::new(UserManager::new(
            context.http_client.clone(),
            event_bus.clone(),
        ));
        let user_id = context.user_id.lock().unwrap().clone();
        let friend = Arc::new(FriendManager::new(
            context.http_client.clone(),
            event_bus.clone(),
            user_id.clone(),
            context.friend_dao.clone(),
            context.sync_version_dao.clone(),
        ));
        let group = Arc::new(GroupManager::new(
            context.http_client.clone(),
            event_bus.clone(),
            user_id.clone(),
            context.group_dao.clone(),
            context.sync_version_dao.clone(),
        ));
        let conversation = Arc::new(ConversationManager::new(
            context.conversation_dao.clone(),
            context.message_dao.clone(),
            event_bus.clone(),
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
            event_bus.clone(),
        ));

        let message_syncer = Arc::new(MessageSyncer::new(
            connection.clone(),
            context.conversation_dao.clone(),
            context.message_dao.clone(),
            context.sync_version_dao.clone(),
            context.notification_seq_dao.clone(),
            message_handler.clone(),
            event_bus.clone(),
            config.user_id.clone(),
        ));

        let conversation_syncer = Arc::new(ConversationSyncer::new(
            context.http_client.clone(),
            context.conversation_dao.clone(),
            event_bus.clone(),
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

        info!("OpenIM SDK 初始化完成");

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
        })
    }

    /// 连接到服务器
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
        let cancel_token = self.context.cancel_token.clone();

        tokio::spawn(async move {
            let mut subscription = event_bus.subscribe();
            info!("push_message_handler: started");
            loop {
                tokio::select! {
                    _ = cancel_token.cancelled() => {
                        info!("push_message_handler: cancelled");
                        break;
                    }
                    event = subscription.next() => {
                        match event {
                            Some(SdkEvent::Connected) => {
                                info!("push_message_handler: connection established, starting message sync");
                                if let Err(e) = message_syncer.sync_after_reconnect().await {
                                    warn!("push_message_handler: sync after reconnect failed: {:?}", e);
                                }
                            }
                            Some(SdkEvent::PushMessage { data, req_identifier }) => {
                                info!("push_message_handler: received PushMessage event, req_identifier={}, data_len={}", req_identifier, data.len());
                                match PushMessages::decode(data.as_slice()) {
                                    Ok(push_messages) => {
                                        info!("push_message_handler: decoded successfully, msgs={}, notification_msgs={}",
                                            push_messages.msgs.len(), push_messages.notification_msgs.len());

                                        // 处理普通消息（对齐 Go SDK triggerConversation）
                                        for (conv_id, pull_msgs) in &push_messages.msgs {
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
                                                info!("push_message_handler: handling {} messages for {}", messages.len(), conv_id);
                                                if let Err(e) = message_handler.handle_messages(messages).await {
                                                    warn!("failed to handle push messages for {}: {:?}", conv_id, e);
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

                                        // 处理通知消息（对齐 Go SDK triggerNotification）
                                        for (conv_id, pull_msgs) in &push_messages.notification_msgs {
                                            notification_handler.handle_notifications(&pull_msgs.msgs).await;

                                            let seqs: Vec<i64> = pull_msgs.msgs.iter().map(|m| m.seq).filter(|&s| s > 0).collect();
                                            if !seqs.is_empty() {
                                                if let Err(e) = message_syncer.push_trigger_and_sync(conv_id, &seqs).await {
                                                    warn!("push_trigger_and_sync (notification) failed for {}: {:?}", conv_id, e);
                                                }
                                            }
                                        }
                                    }
                                    Err(e) => {
                                        warn!("failed to decode push message: {}", e);
                                    }
                                }
                            }
                            Some(SdkEvent::PushMessages { conversation_id, msgs, is_end: _, end_seq: _ }) => {
                                info!("push_message_handler: received PushMessages event for {}, msg_count={}", conversation_id, msgs.len());

                                let messages: Vec<ReceivedMessage> = msgs.iter().filter_map(|msg| {
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
                                        conversation_id: conversation_id.clone(),
                                        group_id: msg.group_id.clone(),
                                        is_online_only: msg.options.get("isOnlineOnly").copied().unwrap_or(false),
                                    })
                                }).collect();

                                let seqs: Vec<i64> = msgs.iter().map(|m| m.seq).filter(|&s| s > 0).collect();

                                if !messages.is_empty() {
                                    info!("push_message_handler: handling {} messages for {}", messages.len(), conversation_id);
                                    if let Err(e) = message_handler.handle_messages(messages).await {
                                        warn!("failed to handle push messages for {}: {:?}", conversation_id, e);
                                    }
                                    if let Err(e) = message_syncer.push_trigger_and_sync(&conversation_id, &seqs).await {
                                        warn!("push_trigger_and_sync failed for {}: {:?}", conversation_id, e);
                                    }
                                }
                            }
                            Some(SdkEvent::PushNotificationMessages { conversation_id, msgs, is_end: _, end_seq: _ }) => {
                                info!("push_message_handler: received PushNotificationMessages for {}, msg_count={}", conversation_id, msgs.len());

                                // 通知消息路由到 NotificationHandler（对齐 Go SDK DoNotification）
                                notification_handler.handle_notifications(&msgs).await;

                                // 同步 seq
                                let seqs: Vec<i64> = msgs.iter().map(|m| m.seq).filter(|&s| s > 0).collect();
                                if !seqs.is_empty() {
                                    if let Err(e) = message_syncer.push_trigger_and_sync(&conversation_id, &seqs).await {
                                        warn!("push_trigger_and_sync failed for {}: {:?}", conversation_id, e);
                                    }
                                    // 持久化通知会话的 seq（对齐 Go SDK SetNotificationSeq）
                                    if let Some(&max_seq) = seqs.iter().max() {
                                        if let Err(e) = message_syncer.set_notification_seq(&conversation_id, max_seq).await {
                                            warn!("set_notification_seq failed for {}: {:?}", conversation_id, e);
                                        }
                                    }
                                }
                            }
                            Some(SdkEvent::BatchedPushMessages { msgs, notification_msgs }) => {
                                info!("push_message_handler: received BatchedPushMessages, {} msg conversations, {} notification conversations",
                                    msgs.len(), notification_msgs.len());

                                // 处理普通消息
                                for (conv_id, pull_msgs) in &msgs {
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
                                        info!("push_message_handler: handling {} batched messages for {}", messages.len(), conv_id);
                                        if let Err(e) = message_handler.handle_messages(messages).await {
                                            warn!("failed to handle batched messages for {}: {:?}", conv_id, e);
                                        }
                                        if let Err(e) = message_syncer.push_trigger_and_sync(conv_id, &seqs).await {
                                            warn!("push_trigger_and_sync (batched) failed for {}: {:?}", conv_id, e);
                                        }
                                    } else if !seqs.is_empty() {
                                        if let Err(e) = message_syncer.push_trigger_and_sync(conv_id, &seqs).await {
                                            warn!("push_trigger_and_sync (batched seq) failed for {}: {:?}", conv_id, e);
                                        }
                                    }
                                }

                                // 处理通知消息
                                for (conv_id, pull_msgs) in &notification_msgs {
                                    notification_handler.handle_notifications(&pull_msgs.msgs).await;

                                    let seqs: Vec<i64> = pull_msgs.msgs.iter().map(|m| m.seq).filter(|&s| s > 0).collect();
                                    if !seqs.is_empty() {
                                        if let Err(e) = message_syncer.push_trigger_and_sync(conv_id, &seqs).await {
                                            warn!("push_trigger_and_sync (batched notification) failed for {}: {:?}", conv_id, e);
                                        }
                                        // 持久化通知会话的 seq（对齐 Go SDK SetNotificationSeq）
                                        if let Some(&max_seq) = seqs.iter().max() {
                                            if let Err(e) = message_syncer.set_notification_seq(conv_id, max_seq).await {
                                                warn!("set_notification_seq (batched) failed for {}: {:?}", conv_id, e);
                                            }
                                        }
                                    }
                                }
                            }
                            Some(other) => {
                                info!("push_message_handler: event {:?}", other);
                            }
                            None => {
                                info!("push_message_handler: event stream closed");
                                break;
                            }
                        }
                    }
                }
            }
        });
    }

    /// 断开连接
    pub async fn disconnect(&self) {
        self.context.shutdown();
        info!("SDK 已断开连接");
    }

    /// 登录
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

        info!("[SDK] 用户上下文已设置");

        // 登录时清理发送中的消息（对齐 Go SDK userRelated.go L332-375）
        self.cleanup_sending_messages().await;

        if let Some(ws_url) = &self.context.config.ws_url {
            info!("[SDK] 开始 WebSocket 连接，ws_url={}", ws_url);
            self.connection.connect(ws_url, token, user_id, self.context.config.platform_id).await?;
            info!("[SDK] WebSocket 连接成功");
            self.spawn_push_message_handler();
        } else {
            warn!("[SDK] ws_url 未配置，跳过 WebSocket 连接");
        }

        // 会话同步：优先增量同步，首次或版本不匹配时回退全量（对齐 Go SDK syncFlag 路径）
        info!("[SDK] 开始会话同步");
        if let Err(e) = self.conversation_syncer.sync_incremental().await {
            warn!("[SDK] 登录后会话增量同步失败，回退全量同步: {}", e);
            if let Err(e2) = self.conversation_syncer.sync_full().await {
                warn!("[SDK] 登录后会话全量同步失败: {}", e2);
            }
        } else {
            info!("[SDK] 会话增量同步成功");
        }

        tokio::spawn({
            let message_syncer = self.message_syncer.clone();
            async move {
                info!("[SDK] 登录后异步触发消息同步");
                if let Err(e) = message_syncer.sync_on_login().await {
                    warn!("[SDK] 登录后消息同步失败: {}", e);
                } else {
                    info!("[SDK] 登录后消息同步完成");
                }
            }
        });

        self.event_bus.publish(SdkEvent::LoginSuccess {
            user_id: user_id.to_string(),
        });
        info!("[SDK] 用户登录成功: {}", user_id);
        Ok(())
    }

    /// 登出
    pub async fn logout(&self) -> Result<()> {
        self.user.clear().await;
        self.friend.clear().await;
        self.group.clear().await;
        self.conversation.clear_all().await;
        self.online_status.clear_subscriptions().await?;

        self.event_bus.publish(SdkEvent::Logout);
        info!("用户登出成功");
        Ok(())
    }

    /// 获取事件总线（内部使用）
    pub fn event_bus(&self) -> Arc<EventBus> {
        self.event_bus.clone()
    }

    /// 获取当前登录用户 ID
    pub fn login_user_id(&self) -> String {
        self.context.get_user_id()
    }

    /// 同步所有会话的 Hash Read Seq（用于前台唤醒）
    pub async fn sync_all_conversation_hash_read_seqs(&self) -> Result<()> {
        self.conversation_syncer
            .sync_conversation_hash_read_seqs(&self.message_handler.max_seq_recorder)
            .await
    }

    /// 增量同步会话列表（对齐 Go SDK `IncrSyncConversations`）
    ///
    /// 版本号持久化到数据库，重连后无需全量同步。
    /// 收到会话变更通知时调用。
    pub async fn incr_sync_conversations(&self) -> Result<()> {
        self.conversation_syncer.sync_incremental_with_lock().await?;
        Ok(())
    }

    /// 获取连接状态
    pub async fn get_connection_state(&self) -> crate::core::connection::manager::ConnectionState {
        self.connection.get_state().await
    }

    /// 是否已连接
    pub async fn is_connected(&self) -> bool {
        self.connection.is_connected().await
    }
}
