use crate::domain::config::ClientConfig;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::model::UserId;
use crate::infra::database::pool::create_pool;
use crate::infra::database::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};
use crate::infra::http::client::HttpApiClient;
use sqlx::SqlitePool;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use tokio_util::sync::CancellationToken;

// 操作 ID task-local（对齐 Go context.WithValue("operationID")）
// 同 task 内跨 await 自动继承，跨 tokio::spawn/channel 断开
tokio::task_local! {
    pub(crate) static OPERATION_ID: String;
}

static OP_ID_COUNTER: AtomicU64 = AtomicU64::new(0);

/// 生成操作 ID，格式: {prefix}_{seq}
pub fn gen_operation_id(prefix: &str) -> String {
    format!("{}_{}", prefix, OP_ID_COUNTER.fetch_add(1, Ordering::SeqCst))
}

/// 所有 DAO 的聚合（按领域分组，生命周期由 RuntimeContext 管理）
pub struct Stores {
    pub message_dao: Arc<MessageDao>,
    pub conversation_dao: Arc<ConversationDao>,
    pub friend_dao: Arc<FriendDao>,
    pub user_dao: Arc<UserDao>,
    pub group_dao: Arc<GroupDao>,
    pub sync_version_dao: Arc<SyncVersionDao>,
    pub notification_seq_dao: Arc<NotificationSeqDao>,
    pub sending_message_dao: Arc<SendingMessageDao>,
}

/// 基础设施（网络 + 数据库连接）
pub struct Infra {
    pub http_client: Arc<HttpApiClient>,
    pub db_pool: SqlitePool,
}

/// SDK 运行时上下文，管理所有依赖组件的生命周期
pub struct RuntimeContext {
    /// 客户端配置
    pub config: ClientConfig,
    /// 事件总线
    pub event_bus: Arc<EventBus>,
    /// 取消令牌，用于优雅关闭
    pub cancel_token: CancellationToken,
    /// 当前登录用户 ID
    pub user_id: UserId,
    /// 操作 ID（用于追踪请求）
    pub operation_id: String,
    /// 持久化层聚合（Arc 共享给各模块）
    pub stores: Arc<Stores>,
    /// 基础设施
    pub infra: Infra,
}

impl RuntimeContext {
    /// 创建新的运行时上下文
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
        let notification_seq_dao = Arc::new(NotificationSeqDao::new(db_pool.clone()));
        let sending_message_dao = Arc::new(SendingMessageDao::new(db_pool.clone()));

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
                message_dao,
                conversation_dao,
                friend_dao,
                user_dao,
                group_dao,
                sync_version_dao,
                notification_seq_dao,
                sending_message_dao,
            }),
            infra: Infra {
                http_client,
                db_pool,
            },
        })
    }

    /// 设置当前登录用户 ID
    pub fn set_user_id(&self, user_id: String) {
        self.user_id.set_blocking(user_id);
    }

    /// 获取当前用户 ID
    pub fn get_user_id(&self) -> String {
        self.user_id.get_blocking()
    }

    /// 获取取消令牌的克隆
    pub fn cancel_token(&self) -> CancellationToken {
        self.cancel_token.clone()
    }

    /// 触发取消，关闭所有异步任务
    pub fn shutdown(&self) {
        self.cancel_token.cancel();
    }
}

/// 共享的运行时上下文（线程安全）
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
