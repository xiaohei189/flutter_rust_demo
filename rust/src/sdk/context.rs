use crate::domain::config::ClientConfig;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::infra::database::pool::create_pool;
use crate::infra::database::{ConversationDao, MessageDao};
use crate::infra::http::client::HttpApiClient;
use sqlx::SqlitePool;
use std::sync::{Arc, Mutex};
use tokio_util::sync::CancellationToken;

/// SDK 运行时上下文，管理所有依赖组件的生命周期
pub struct RuntimeContext {
    /// 客户端配置
    pub config: ClientConfig,
    /// 事件总线
    pub event_bus: Arc<EventBus>,
    /// 取消令牌，用于优雅关闭
    pub cancel_token: CancellationToken,
    /// 当前登录用户 ID
    pub user_id: Mutex<String>,
    /// 操作 ID（用于追踪请求）
    pub operation_id: String,
    /// 数据库连接池
    pub db_pool: SqlitePool,
    /// 消息 DAO
    pub message_dao: Arc<MessageDao>,
    /// 会话 DAO
    pub conversation_dao: Arc<ConversationDao>,
    /// HTTP API 客户端
    pub http_client: Arc<HttpApiClient>,
}

impl RuntimeContext {
    /// 创建新的运行时上下文
    pub async fn new(
        config: ClientConfig,
        event_bus: Arc<EventBus>,
        cancel_token: CancellationToken,
    ) -> Result<Self> {
        let operation_id = format!("op_{}", chrono::Utc::now().timestamp_millis());

        // 确保数据目录存在，否则 SQLite 无法创建数据库文件
        std::fs::create_dir_all(&config.data_dir)
            .map_err(|e| SdkError::database(format!("create data_dir {}: {}", config.data_dir, e)))?;
        let db_url = format!("sqlite:{}/openim_{}.db", config.data_dir, config.platform_id);
        let db_pool = create_pool(&db_url).await?;
        let message_dao = Arc::new(MessageDao::new(db_pool.clone()));
        let conversation_dao = Arc::new(ConversationDao::new(db_pool.clone()));

        let http_client = Arc::new(HttpApiClient::new(
            config.api_base_url.clone(),
            config.token.clone(),
            operation_id.clone(),
        ));

        Ok(Self {
            config,
            event_bus,
            cancel_token,
            user_id: Mutex::new("".to_string()),
            operation_id,
            db_pool,
            message_dao,
            conversation_dao,
            http_client,
        })
    }

    /// 设置当前登录用户 ID
    pub fn set_user_id(&self, user_id: String) {
        *self.user_id.lock().unwrap() = user_id;
    }

    /// 获取当前用户 ID
    pub fn get_user_id(&self) -> String {
        self.user_id.lock().unwrap().clone()
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
