use crate::domain::config::ClientConfig;
use crate::domain::error::types::Result;
use crate::domain::event::EventBus;
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
}

impl RuntimeContext {
    /// 创建新的运行时上下文
    pub async fn new(
        config: ClientConfig,
        event_bus: Arc<EventBus>,
        cancel_token: CancellationToken,
    ) -> Result<Self> {
        let operation_id = format!("op_{}", chrono::Utc::now().timestamp_millis());

        Ok(Self {
            config,
            event_bus,
            cancel_token,
            user_id: Mutex::new("".to_string()),
            operation_id,
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
        let config = ClientConfig::new(
            "user123".to_string(),
            "token123".to_string(),
            1,
            Some("ws://localhost:10001".to_string()),
            Some("http://localhost:10002".to_string()),
        );
        let event_bus = Arc::new(EventBus::new());
        let cancel_token = CancellationToken::new();

        let context = RuntimeContext::new(config, event_bus, cancel_token).await;
        assert!(context.is_ok());
    }
}
