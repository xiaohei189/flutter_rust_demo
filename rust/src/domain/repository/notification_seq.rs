use crate::domain::error::Result;
use crate::domain::model::local::LocalNotificationSeq;
use async_trait::async_trait;

/// 通知序列仓库接口
#[async_trait]
pub trait NotificationSeqRepository: Send + Sync {
    async fn set_notification_seq(&self, conversation_id: &str, seq: i64) -> Result<()>;
    async fn batch_insert(&self, seqs: &[LocalNotificationSeq]) -> Result<()>;
    async fn get_all(&self) -> Result<Vec<LocalNotificationSeq>>;
}