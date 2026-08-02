//! OpenIMClient Builder - extract ~150 line constructor into builder

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
use crate::domain::error::Result;
use crate::event::EventBus;
use crate::event::events::connection::ConnectionEvent;
use crate::event::events::conversation::ConversationEvent;
use crate::event::events::friend::FriendEvent;
use crate::event::events::group::GroupEvent;
use crate::infra::http::message_api::HttpMessageApi;
use crate::sdk::client::OpenIMClient;
use crate::sdk::config::ClientConfig;
use crate::sdk::context::RuntimeContext;
use std::sync::Arc;
use tokio_util::sync::CancellationToken;
use tracing::debug;

pub struct OpenIMClientBuilder {
    config: ClientConfig,
}

impl OpenIMClientBuilder {
    pub fn new(config: ClientConfig) -> Self {
        Self { config }
    }

    pub async fn build(self) -> Result<OpenIMClient> {
        let event_bus = Arc::new(EventBus::new());
        let cancel_token = CancellationToken::new();
        let context = Arc::new(RuntimeContext::new(self.config.clone(), event_bus.clone(), cancel_token.clone()).await?);
        let connection = Arc::new(ConnectionManager::new(cancel_token.clone()));
        let user = Arc::new(UserService::new(context.infra.http_client.clone(), event_bus.clone()));
        let friend = Arc::new(FriendService::new(context.infra.http_client.clone(), context.repositories.clone(), context.user_id.clone()));
        let group = Arc::new(GroupService::new(context.infra.http_client.clone(), context.repositories.clone(), context.user_id.clone()));
        let conversation = Arc::new(ConversationService::new(context.repositories.clone()));
        let online_status = Arc::new(OnlineStatusService::new(context.infra.http_client.clone(), event_bus.clone()));
        let file_uploader = Arc::new(FileUploader::new(context.infra.http_client.clone()));
        let message_handler = Arc::new(MessageHandler::new(context.repositories.clone(), context.user_id.clone()));
        let message_syncer = Arc::new(MessageSyncer::new(connection.clone(), context.repositories.clone(), message_handler.clone(), context.user_id.clone()));
        let conversation_syncer = Arc::new(ConversationSyncer::new(context.infra.http_client.clone(), context.repositories.clone(), context.user_id.clone()));
        let message_service = Arc::new(MessageService::new(context.repositories.clone(), Arc::new(HttpMessageApi::new(context.infra.http_client.clone())), event_bus.clone(), context.user_id.clone()));
        let notification_handler = Arc::new(NotificationHandler::new(friend.clone(), group.clone(), user.clone(), conversation_syncer.clone(), message_handler.clone(), event_bus.clone()));
        let send_queue = MessageSendQueue::new();
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
        debug!("OpenIM SDK init done (via Builder)");
        Ok(OpenIMClient {
            context, connection, user, friend, group, conversation,
            message_syncer, message_handler, notification_handler, conversation_syncer,
            online_status, file_uploader, message_service, event_bus, send_queue,
            conn_rx: Arc::new(std::sync::Mutex::new(Some(conn_rx))),
            conv_rx: Arc::new(std::sync::Mutex::new(Some(conv_rx))),
            friend_rx: Arc::new(std::sync::Mutex::new(Some(friend_rx))),
            group_rx: Arc::new(std::sync::Mutex::new(Some(group_rx))),
        })
    }
}
