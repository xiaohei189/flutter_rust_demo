use super::models::LocalNotificationSeq;
use crate::domain::error::types::{Result, SdkError};
use sqlx::SqlitePool;

pub struct NotificationSeqDao {
    pool: SqlitePool,
}

impl NotificationSeqDao {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    /// 设置通知会话的 seq（UPSERT 语义）
    /// 对齐 Go SDK `notification_model.go:27-38` SetNotificationSeq
    pub async fn set_notification_seq(&self, conversation_id: &str, seq: i64) -> Result<()> {
        sqlx::query(
            "INSERT INTO local_notification_seqs (conversation_id, seq) VALUES (?, ?) \
             ON CONFLICT(conversation_id) DO UPDATE SET seq = excluded.seq",
        )
        .bind(conversation_id)
        .bind(seq)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("set notification seq: {}", e)))?;
        Ok(())
    }

    /// 批量插入通知 seq 记录
    /// 对齐 Go SDK `notification_model.go:40-44` BatchInsertNotificationSeq
    pub async fn batch_insert(&self, seqs: &[LocalNotificationSeq]) -> Result<()> {
        if seqs.is_empty() {
            return Ok(());
        }
        for seq_record in seqs {
            sqlx::query(
                "INSERT INTO local_notification_seqs (conversation_id, seq) VALUES (?, ?) \
                 ON CONFLICT(conversation_id) DO UPDATE SET seq = excluded.seq",
            )
            .bind(&seq_record.conversation_id)
            .bind(seq_record.seq)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("batch insert notification seq: {}", e)))?;
        }
        Ok(())
    }

    /// 获取所有通知会话的 seq 记录
    /// 对齐 Go SDK `notification_model.go:46-51` GetNotificationAllSeqs
    pub async fn get_all(&self) -> Result<Vec<LocalNotificationSeq>> {
        let rows = sqlx::query_as::<_, LocalNotificationSeq>(
            "SELECT * FROM local_notification_seqs",
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("get all notification seqs: {}", e)))?;
        Ok(rows)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

    #[tokio::test]
    async fn test_set_and_get_notification_seq() {
        let pool = create_pool_memory().await.unwrap();
        let dao = NotificationSeqDao::new(pool);

        dao.set_notification_seq("n_conv_1", 10).await.unwrap();
        dao.set_notification_seq("n_conv_2", 20).await.unwrap();

        let all = dao.get_all().await.unwrap();
        assert_eq!(all.len(), 2);
    }

    #[tokio::test]
    async fn test_upsert_notification_seq() {
        let pool = create_pool_memory().await.unwrap();
        let dao = NotificationSeqDao::new(pool);

        dao.set_notification_seq("n_conv_1", 10).await.unwrap();
        dao.set_notification_seq("n_conv_1", 20).await.unwrap();

        let all = dao.get_all().await.unwrap();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].seq, 20);
    }

    #[tokio::test]
    async fn test_batch_insert() {
        let pool = create_pool_memory().await.unwrap();
        let dao = NotificationSeqDao::new(pool);

        let seqs = vec![
            LocalNotificationSeq { conversation_id: "n_conv_1".into(), seq: 10 },
            LocalNotificationSeq { conversation_id: "n_conv_2".into(), seq: 20 },
        ];
        dao.batch_insert(&seqs).await.unwrap();

        let all = dao.get_all().await.unwrap();
        assert_eq!(all.len(), 2);
    }
}
