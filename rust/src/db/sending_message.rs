use crate::domain::error::Result;
use crate::domain::model::local::LocalSendingMessage;
use async_trait::async_trait;

/// 发送中消息仓库接口
#[async_trait]
pub trait SendingMessageRepository: Send + Sync {
    async fn insert(&self, msg: &LocalSendingMessage) -> Result<()>;
    async fn delete(&self, conversation_id: &str, client_msg_id: &str) -> Result<()>;
    async fn get_all(&self) -> Result<Vec<LocalSendingMessage>>;
    async fn get_by_client_msg_id(&self, conversation_id: &str, client_msg_id: &str) -> Result<Option<LocalSendingMessage>>;
}
