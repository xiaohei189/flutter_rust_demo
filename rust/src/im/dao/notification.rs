use anyhow::Result;
use sqlx::{Pool, Sqlite};

use crate::im::model::notification::LocalNotificationSeq;



pub struct NotificationDao {
    db: Pool<Sqlite>,
}

impl NotificationDao {
    /// 创建新的会话 DAO
    pub fn new(db: Pool<Sqlite>) -> Self {
        Self { db }
    }

    pub async fn get_notification_all_seqs(&self) -> Result<Vec<LocalNotificationSeq>> {
        let rows = sqlx::query_as::<_, LocalNotificationSeq>(
            "SELECT conversation_id, seq FROM local_notification_seq",
        )
        .fetch_all(&self.db)
        .await?;
        Ok(rows)
    }
}