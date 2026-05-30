use crate::core::connection::manager::ConnectionManager;
use crate::core::conversation::manager::ConversationManager;
use crate::core::conversation::syncer::ConversationSyncer;
use crate::core::file::uploader::FileUploader;
use crate::core::friend::manager::FriendManager;
use crate::core::group::manager::GroupManager;
use crate::core::message::handler::MessageHandler;
use crate::core::message::sender::MessageSender;
use crate::core::message::syncer::MessageSyncer;
use crate::core::online::manager::OnlineStatusManager;
use crate::core::user::manager::UserManager;
use crate::domain::config::ClientConfig;
use crate::domain::error::types::Result;
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::infra::cache::memory::CacheManager;
use crate::infra::http::client::HttpApiClient;
use crate::sdk::context::RuntimeContext;
use std::sync::Arc;
use tokio::sync::RwLock;
use tokio_util::sync::CancellationToken;
use tracing::info;

/// SDK 门面，提供统一的 API 入口
pub struct OpenIMClient {
    /// 运行时上下文
    pub context: Arc<RuntimeContext>,
    /// 连接管理器
    pub connection: Arc<ConnectionManager>,
    /// 用户管理器
    pub user: Arc<UserManager>,
    /// 好友管理器
    pub friend: Arc<FriendManager>,
    /// 群组管理器
    pub group: Arc<GroupManager>,
    /// 会话管理器
    pub conversation: Arc<ConversationManager>,
    /// 消息发送器
    pub message_sender: Arc<MessageSender>,
    /// 消息同步器
    pub message_syncer: Arc<MessageSyncer>,
    /// 消息处理器
    pub message_handler: Arc<MessageHandler>,
    /// 会话同步器
    pub conversation_syncer: Arc<ConversationSyncer>,
    /// 在线状态管理器
    pub online_status: Arc<OnlineStatusManager>,
    /// 文件上传服务
    pub file_uploader: Arc<FileUploader>,
    /// 事件总线
    pub event_bus: Arc<EventBus>,
    /// 缓存管理器
    pub cache: Arc<CacheManager>,
}

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
        let friend = Arc::new(FriendManager::new(
            context.http_client.clone(),
            event_bus.clone(),
        ));
        let group = Arc::new(GroupManager::new(event_bus.clone()));
        let conversation = Arc::new(ConversationManager::new(
            context.conversation_dao.clone(),
            event_bus.clone(),
        ));
        let online_status = Arc::new(OnlineStatusManager::new(event_bus.clone()));

        let http_client = Arc::new(HttpApiClient::new(
            config.api_base_url.clone(),
            config.token.clone(),
            context.operation_id.clone(),
        ));

        let mut message_sender = MessageSender::new(
            connection.clone(),
            event_bus.clone(),
            config.user_id.clone(),
            config.platform_id,
        );
        message_sender.start_workers();
        let message_sender = Arc::new(message_sender);

        let message_handler = Arc::new(MessageHandler::new(
            context.message_dao.clone(),
            context.conversation_dao.clone(),
            event_bus.clone(),
        ));

        let message_syncer = Arc::new(MessageSyncer::new(
            connection.clone(),
            context.conversation_dao.clone(),
            context.message_dao.clone(),
            message_handler.clone(),
            event_bus.clone(),
            config.user_id.clone(),
        ));

        let conversation_syncer = Arc::new(ConversationSyncer::new(event_bus.clone()));

        let file_uploader = Arc::new(FileUploader::new(
            http_client.clone(),
            config.upload_url.clone().unwrap_or_default(),
        ));

        info!("OpenIM SDK 初始化完成");

        Ok(Self {
            context,
            connection,
            user,
            friend,
            group,
            conversation,
            message_sender,
            message_syncer,
            message_handler,
            conversation_syncer,
            online_status,
            file_uploader,
            event_bus,
            cache,
        })
    }

    /// 连接到服务器
    pub async fn connect(&self, ws_url: &str, token: &str, user_id: &str) -> Result<()> {
        self.connection.connect(ws_url, token, user_id).await
    }

    /// 断开连接
    pub async fn disconnect(&self) {
        self.context.shutdown();
        info!("SDK 已断开连接");
    }

    /// 登录
    pub async fn login(&self, user_id: &str, token: &str) -> Result<()> {
        self.context.set_user_id(user_id.to_string());
        self.event_bus.publish(SdkEvent::LoginSuccess {
            user_id: user_id.to_string(),
        });
        info!("用户登录成功: {}", user_id);
        Ok(())
    }

    /// 登出
    pub async fn logout(&self) -> Result<()> {
        self.user.clear().await;
        self.friend.clear().await;
        self.group.clear().await;
        self.conversation.clear_all().await;
        self.online_status.clear().await;
        
        self.event_bus.publish(SdkEvent::Logout);
        info!("用户登出成功");
        Ok(())
    }

    /// 获取事件总线
    pub fn event_bus(&self) -> Arc<EventBus> {
        self.event_bus.clone()
    }
}
