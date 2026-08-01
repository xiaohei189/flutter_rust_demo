use crate::sdk::config::ClientConfig;
use crate::domain::error::{Result, SdkError};
use crate::event::EventBus;
use crate::domain::model::UserId;
use crate::domain::repository::*;
use crate::infra::database::pool::create_pool;
use crate::infra::database::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};
use crate::infra::http::client::HttpApiClient;
use sqlx::SqlitePool;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use tokio_util::sync::CancellationToken;

tokio::task_local! {
    pub(crate) static OPERATION_ID: String;
}

static OP_ID_COUNTER: AtomicU64 = AtomicU64::new(0);

pub fn gen_operation_id(prefix: &str) -> String {
    format!("{}_{}", prefix, OP_ID_COUNTER.fetch_add(1, Ordering::SeqCst))
}

/// 所有 Repository 的聚合（按领域分组，生命周期由 RuntimeContext 管理）
pub struct Stores {
    pub message_repo: Arc<dyn MessageRepository>,
    pub conversation_repo: Arc<dyn ConversationRepository>,
    pub friend_repo: Arc<dyn FriendRepository>,
    pub user_repo: Arc<dyn UserRepository>,
    pub group_repo: Arc<dyn GroupRepository>,
    pub sync_version_repo: Arc<dyn SyncVersionRepository>,
    pub notification_seq_repo: Arc<dyn NotificationSeqRepository>,
    pub sending_message_repo: Arc<dyn SendingMessageRepository>,
}

pub struct Infra {
    pub http_client: Arc<HttpApiClient>,
    pub db_pool: SqlitePool,
}

pub struct RuntimeContext {
    pub config: ClientConfig,
    pub event_bus: Arc<EventBus>,
    pub cancel_token: CancellationToken,
    pub user_id: UserId,
    pub operation_id: String,
    pub stores: Arc<Stores>,
    pub infra: Infra,
}

impl RuntimeContext {
    pub async fn new(
        config: ClientConfig,
        event_bus: Arc<EventBus>,
        cancel_token: CancellationToken,
    ) -> Result<Self> {
        let operation_id = format!("op_{}", chrono::Utc::now().timestamp_millis());

        std::fs::create_dir_all(&config.data_dir)
            .map_err(|e| SdkError::database(format!("create data_dir {}: {}", config.data_dir, e)))?;
        let db_url = format!("sqlite:{}/openim_{}.db", config.data_dir, config.platform_id);
        let db_pool = create_pool(&db_url).await?;
        let message_dao = Arc::new(MessageDao::new(db_pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(db_pool.clone()));
        let friend_dao = Arc::new(FriendDao::new(db_pool.clone()));
        let user_dao = Arc::new(UserDao::new(db_pool.clone()));
        let group_dao = Arc::new(GroupDao::new(db_pool.clone()));
        let sync_version_dao = Arc::new(SyncVersionDao::new(db_pool.clone()));
        let notification_seq_repo = Arc::new(NotificationSeqDao::new(db_pool.clone()));
        let sending_message_repo = Arc::new(SendingMessageDao::new(db_pool.clone()));

        let http_client = Arc::new(HttpApiClient::new(
            config.api_base_url.clone(),
            config.token.clone(),
            "sdk_init".to_string(),
        ));

        Ok(Self {
            config,
            event_bus,
            cancel_token,
            user_id: UserId::new(""),
            operation_id,
            stores: Arc::new(Stores {
                message_repo: message_dao,
                conversation_repo: conversation_dao,
                friend_repo: friend_dao,
                user_repo: user_dao,
                group_repo: group_dao,
                sync_version_repo: sync_version_dao,
                notification_seq_repo,
                sending_message_repo,
            }),
            infra: Infra {
                http_client,
                db_pool,
            },
        })
    }

    pub fn set_user_id(&self, user_id: String) {
        self.user_id.set_blocking(user_id);
    }

    pub fn get_user_id(&self) -> String {
        self.user_id.get_blocking()
    }

    pub fn cancel_token(&self) -> CancellationToken {
        self.cancel_token.clone()
    }

    pub fn shutdown(&self) {
        self.cancel_token.cancel();
    }
}

pub type SharedRuntimeContext = Arc<RuntimeContext>;

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_runtime_context_creation() {
        let data_dir = std::env::temp_dir()
            .join(format!("openim_test_{}", chrono::Utc::now().timestamp_millis()))
            .to_string_lossy()
            .to_string();
        std::fs::create_dir_all(&data_dir).unwrap();

        let config = ClientConfig {
            user_id: "user123".to_string(),
            token: "token123".to_string(),
            platform_id: 1,
            ws_url: Some("ws://localhost:10001".to_string()),
            api_base_url: "http://localhost:10002".to_string(),
            upload_url: Some("http://localhost:10003".to_string()),
            data_dir: data_dir.clone(),
        };
        let event_bus = Arc::new(EventBus::new());
        let cancel_token = CancellationToken::new();

        let context = RuntimeContext::new(config, event_bus, cancel_token).await;
        assert!(context.is_ok());

        let _ = std::fs::remove_dir_all(&data_dir);
    }
}

