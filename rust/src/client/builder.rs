//! OpenIMClient Builder - extract ~150 line constructor into builder

use crate::client::config::ClientConfig;
use crate::client::context::RuntimeContext;
use crate::client::core::OpenIMClient;
use crate::connection::manager::ConnectionManager;
use crate::conversation::service::ConversationService;
use crate::conversation::syncer::ConversationSyncer;
use crate::error::Result;
use crate::event::hub::EventHub;
use crate::file::upload::FileUploader;
use crate::friend::service::FriendService;
use crate::group::service::GroupService;
use crate::http::conversation_api::HttpConversationApi;
use crate::http::friend_api::HttpFriendApi;
use crate::http::group_api::HttpGroupApi;
use crate::http::message_api::HttpMessageApi;
use crate::http::online_api::HttpOnlineStatusApi;
use crate::http::user_api::HttpUserApi;
use crate::message::notification::NotificationHandler;
use crate::message::send::MessageSendQueue;
use crate::message::send::MessageSender;
use crate::message::MessageProcessor;
use crate::message::MessageService;
use crate::message::MessageSyncer;
use crate::user::online::service::OnlineStatusService;
use crate::user::service::UserService;
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
        let friend = Arc::new(FriendService::new(
            Arc::new(HttpFriendApi::new(context.infra.http_client.clone())),
            context.repositories.clone(),
            context.user_id.clone(),
            listeners.clone(),
        ));
        let group = Arc::new(GroupService::new(
            Arc::new(HttpGroupApi::new(context.infra.http_client.clone())),
            context.repositories.clone(),
            context.user_id.clone(),
            listeners.clone(),
        ));
        let conversation_api = Arc::new(HttpConversationApi::new(context.infra.http_client.clone()));
        let conversation = Arc::new(ConversationService::new(context.repositories.clone(), listeners.clone()).with_server_api(conversation_api));
        let online_status = Arc::new(OnlineStatusService::new(Arc::new(HttpOnlineStatusApi::new(context.infra.http_client.clone())), listeners.clone()));
        let file_uploader = Arc::new(FileUploader::new(context.infra.http_client.clone()));
        let message_processor = Arc::new(MessageProcessor::new(context.repositories.clone(), context.user_id.clone(), listeners.clone(), listeners.clone()));
        let message_syncer = Arc::new(MessageSyncer::new(
            connection.clone(),
            context.repositories.clone(),
            message_processor.clone(),
            context.user_id.clone(),
            listeners.clone(),
        ));
        let mut conversation_syncer = ConversationSyncer::new(context.infra.http_client.clone(), context.repositories.clone(), context.user_id.clone(), listeners.clone());
        conversation_syncer.set_connection(connection.clone());
        let conversation_syncer = Arc::new(conversation_syncer);
        let message_service = Arc::new(MessageService::new(
            context.repositories.clone(),
            Arc::new(HttpMessageApi::new(context.infra.http_client.clone())),
            listeners.clone(),
            listeners.clone(),
            context.user_id.clone(),
        ));
        let notification_handler = Arc::new(NotificationHandler::new(
            friend.clone(),
            group.clone(),
            user.clone(),
            conversation_syncer.clone(),
            message_processor.clone(),
            listeners.clone(),
            listeners.clone(),
            listeners.clone(),
            context.user_id.clone(),
        ));
        let send_queue = MessageSendQueue::new();
        let sender = Arc::new(MessageSender::new(context.clone(), connection.clone(), file_uploader.clone(), send_queue.clone(), user.clone()));
        debug!("OpenIM SDK init done (via Builder)");
        Ok(OpenIMClient {
            context,
            connection,
            user,
            friend,
            group,
            conversation,
            message_syncer,
            message_processor,
            notification_handler,
            conversation_syncer,
            online_status,
            message_service,
            listeners,
            sender,
        })
    }
}
