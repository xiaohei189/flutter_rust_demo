//! 本地通知 seq 表 DAO（与 Go pkg/db/notification_model.go 对齐）
//!
//! 表名：local_notification_seqs
//! 用途：存储各会话通知消息已同步到的 seq，供 LoadSeq / 重装时持久化。

use anyhow::Result;
use sqlx::{Pool, Sqlite};

use crate::im::model::notification::LocalNotificationSeq;

const TABLE_NAME: &str = "local_notification_seqs";

#[derive(Clone)]
pub struct NotificationDao {
    db: Pool<Sqlite>,
}

impl NotificationDao {
    pub fn new(db: Pool<Sqlite>) -> Self {
        Self { db }
    }

    /// 与 Go GetNotificationAllSeqs 一致：查询所有会话的通知 seq
    pub async fn get_notification_all_seqs(&self) -> Result<Vec<LocalNotificationSeq>> {
        let rows = sqlx::query_as::<_, LocalNotificationSeq>(&format!(
            "SELECT conversation_id, seq FROM {}",
            TABLE_NAME
        ))
        .fetch_all(&self.db)
        .await?;
        Ok(rows)
    }

    /// 与 Go SetNotificationSeq 一致：按会话设置 seq（有则更新，无则插入）
    pub async fn set_notification_seq(&self, conversation_id: &str, seq: i64) -> Result<()> {
        let rows = sqlx::query(&format!(
            "UPDATE {} SET seq = ? WHERE conversation_id = ?",
            TABLE_NAME
        ))
        .bind(seq)
        .bind(conversation_id)
        .execute(&self.db)
        .await?
        .rows_affected();
        if rows == 0 {
            sqlx::query(&format!(
                "INSERT INTO {} (conversation_id, seq) VALUES (?, ?)",
                TABLE_NAME
            ))
            .bind(conversation_id)
            .bind(seq)
            .execute(&self.db)
            .await?;
        }
        Ok(())
    }

    /// 与 Go BatchInsertNotificationSeq 一致：批量写入/覆盖各会话的 seq（INSERT OR REPLACE）
    pub async fn batch_insert_notification_seq(&self, seqs: &[LocalNotificationSeq]) -> Result<()> {
        if seqs.is_empty() {
            return Ok(());
        }
        for item in seqs {
            self.set_notification_seq(&item.conversation_id, item.seq).await?;
        }
        Ok(())
    }
}