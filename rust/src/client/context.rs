//! 运行时上下文 — 聚合基础设施与仓储，管理 SDK 生命周期

use crate::client::config::ClientConfig;
use crate::infra::db::pool::create_pool;
use crate::infra::db::*;
use crate::infra::db::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};
use crate::domain::error::{Result, SdkError};
use crate::event::hub::EventHub;
use crate::infra::http::client::HttpApiClient;
use crate::domain::model::UserId;
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

// ============================================================================
// Infra — 基础设施层（数据库连接池、HTTP 客户端）
// ============================================================================

impl Infra {
    /// 创建基础设施：数据库连接池 + HTTP 客户端
    pub async fn new(config: &ClientConfig) -> Result<Self> {
        std::fs::create_dir_all(&config.data_dir).map_err(|e| SdkError::database(format!("create data_dir {}: {}", config.data_dir, e)))?;
        let db_url = format!("sqlite:{}/openim_{}.db", config.data_dir, config.platform_id);
        let db_pool = create_pool(&db_url).await?;
        let http_client = Arc::new(HttpApiClient::new(config.api_base_url.clone(), config.token.clone(), "sdk_init".to_string()));
        Ok(Self { http_client, db_pool })
    }
}

// ============================================================================
// Repositories — 仓储聚合（封装 DAO 创建）
// ============================================================================

impl Repositories {
    /// 使用数据库连接池创建所有仓储实例
    pub fn new(pool: &SqlitePool) -> Arc<Self> {
        Arc::new(Self {
            message_repo: Arc::new(MessageDao::new(pool.clone())),
            conversation_repo: Arc::new(ConversationDao::new(pool.clone())),
            friend_repo: Arc::new(FriendDao::new(pool.clone())),
            user_repo: Arc::new(UserDao::new(pool.clone())),
            group_repo: Arc::new(GroupDao::new(pool.clone())),
            sync_version_repo: Arc::new(SyncVersionDao::new(pool.clone())),
            notification_seq_repo: Arc::new(NotificationSeqDao::new(pool.clone())),
            sending_message_repo: Arc::new(SendingMessageDao::new(pool.clone())),
        })
    }
}

/// 所有 Repository 的聚合
pub struct Repositories {
    pub message_repo: Arc<dyn MessageRepository>,
    pub conversation_repo: Arc<dyn ConversationRepository>,
    pub friend_repo: Arc<dyn FriendRepository>,
    pub user_repo: Arc<dyn UserRepository>,
    pub group_repo: Arc<dyn GroupRepository>,
    pub sync_version_repo: Arc<dyn SyncVersionRepository>,
    pub notification_seq_repo: Arc<dyn NotificationSeqRepository>,
    pub sending_message_repo: Arc<dyn SendingMessageRepository>,
}

/// 基础设施（数据库连接池、HTTP 客户端）
pub struct Infra {
    pub http_client: Arc<HttpApiClient>,
    pub db_pool: SqlitePool,
}

/// 运行时上下文 — SDK 所有组件的共享状态
pub struct RuntimeContext {
    pub config: ClientConfig,
    pub listeners: Arc<EventHub>,
    pub cancel_token: CancellationToken,
    pub user_id: UserId,
    pub operation_id: String,
    pub repositories: Arc<Repositories>,
    pub infra: Infra,
}

impl RuntimeContext {
    /// 创建运行时上下文
    pub async fn new(config: ClientConfig, listeners: Arc<EventHub>, cancel_token: CancellationToken) -> Result<Self> {
        let infra = Infra::new(&config).await?;
        let repositories = Repositories::new(&infra.db_pool);
        let operation_id = format!("op_{}", chrono::Utc::now().timestamp_millis());

        Ok(Self {
            config,
            listeners,
            cancel_token,
            user_id: UserId::new(""),
            operation_id,
            repositories,
            infra,
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
        let listeners = EventHub::new();
        let cancel_token = CancellationToken::new();

        let context = RuntimeContext::new(config, listeners, cancel_token).await;
        assert!(context.is_ok());

        let _ = std::fs::remove_dir_all(&data_dir);
    }
}
