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
use crate::event::hub::EventHub;
use crate::infra::http::conversation_api::HttpConversationApi;
use crate::infra::http::friend_api::HttpFriendApi;
use crate::infra::http::group_api::HttpGroupApi;
use crate::infra::http::message_api::HttpMessageApi;
use crate::infra::http::online_api::HttpOnlineStatusApi;
use crate::infra::http::user_api::HttpUserApi;
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
        let cancel_token = CancellationToken::new();
        let listeners = EventHub::new();
        let context = Arc::new(RuntimeContext::new(self.config.clone(), listeners.clone(), cancel_token.clone()).await?);
        let connection = Arc::new(ConnectionManager::new(cancel_token.clone(), listeners.clone()));
        let user = Arc::new(UserService::new(Arc::new(HttpUserApi::new(context.infra.http_client.clone())), listeners.clone()));
        let friend = Arc::new(FriendService::new(Arc::new(HttpFriendApi::new(context.infra.http_client.clone())), context.repositories.clone(), context.user_id.clone(), listeners.clone()));
        let group = Arc::new(GroupService::new(Arc::new(HttpGroupApi::new(context.infra.http_client.clone())), context.repositories.clone(), context.user_id.clone(), listeners.clone()));
        let conversation = Arc::new(ConversationService::new(context.repositories.clone(), listeners.clone()));
        let online_status = Arc::new(OnlineStatusService::new(Arc::new(HttpOnlineStatusApi::new(context.infra.http_client.clone())), listeners.clone()));
        let file_uploader = Arc::new(FileUploader::new(context.infra.http_client.clone()));
        let message_handler = Arc::new(MessageHandler::new(context.repositories.clone(), context.user_id.clone(), listeners.clone(), listeners.clone()));
        let message_syncer = Arc::new(MessageSyncer::new(connection.clone(), context.repositories.clone(), message_handler.clone(), context.user_id.clone(), listeners.clone()));
        let conversation_syncer = Arc::new(ConversationSyncer::new(context.infra.http_client.clone(), context.repositories.clone(), context.user_id.clone(), listeners.clone()));
        let message_service = Arc::new(MessageService::new(context.repositories.clone(), Arc::new(HttpMessageApi::new(context.infra.http_client.clone())), listeners.clone(), listeners.clone(), context.user_id.clone()));
        let notification_handler = Arc::new(NotificationHandler::new(
            friend.clone(), group.clone(), user.clone(),
            conversation_syncer.clone(), message_handler.clone(),
            listeners.clone(), listeners.clone(), listeners.clone(), context.user_id.clone(),
        ));
        let send_queue = MessageSendQueue::new();
        debug!("OpenIM SDK init done (via Builder)");
        Ok(OpenIMClient {
            context, connection, user, friend, group, conversation,
            message_syncer, message_handler, notification_handler, conversation_syncer,
            online_status, file_uploader, message_service, listeners, send_queue,
        })
    }
}

