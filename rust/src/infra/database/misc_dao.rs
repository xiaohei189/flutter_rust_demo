// misc DAO — 轻量数据访问对象聚合
// 包含: 通知序列(notification_seq)、发送中消息(sending_message)、上传记录(upload)

use crate::domain::model::local::{LocalNotificationSeq, LocalSendingMessage, LocalUpload};
use crate::domain::error::{Result, SdkError};
use crate::domain::repository::{NotificationSeqRepository, SendingMessageRepository};
use async_trait::async_trait;
use sqlx::SqlitePool;

// ============================================================================
// 通知序列 DAO
// ============================================================================

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

#[async_trait]
impl NotificationSeqRepository for NotificationSeqDao {
    async fn set_notification_seq(&self, conversation_id: &str, seq: i64) -> Result<()> {
        self.set_notification_seq(conversation_id, seq).await
    }

    async fn batch_insert(&self, seqs: &[LocalNotificationSeq]) -> Result<()> {
        self.batch_insert(seqs).await
    }

    async fn get_all(&self) -> Result<Vec<LocalNotificationSeq>> {
        self.get_all().await
    }
}

// ============================================================================
// 发送中消息 DAO
// ============================================================================

pub struct SendingMessageDao {
    pool: SqlitePool,
}

impl SendingMessageDao {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub async fn insert(&self, msg: &LocalSendingMessage) -> Result<()> {
        sqlx::query(
            "INSERT OR IGNORE INTO local_sending_messages (conversation_id, client_msg_id, ex) VALUES (?, ?, ?)",
        )
        .bind(&msg.conversation_id)
        .bind(&msg.client_msg_id)
        .bind(&msg.ex)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("insert sending message: {}", e)))?;
        Ok(())
    }

    pub async fn delete(&self, conversation_id: &str, client_msg_id: &str) -> Result<()> {
        sqlx::query(
            "DELETE FROM local_sending_messages WHERE conversation_id = ? AND client_msg_id = ?",
        )
        .bind(conversation_id)
        .bind(client_msg_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("delete sending message: {}", e)))?;
        Ok(())
    }

    pub async fn get_all(&self) -> Result<Vec<LocalSendingMessage>> {
        let rows = sqlx::query_as::<_, LocalSendingMessage>(
            "SELECT conversation_id, client_msg_id, ex FROM local_sending_messages",
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("get all sending messages: {}", e)))?;
        Ok(rows)
    }

    /// 根据 conversation_id + client_msg_id 查询发送中消息
    pub async fn get_by_client_msg_id(&self, conversation_id: &str, client_msg_id: &str) -> Result<Option<LocalSendingMessage>> {
        let row = sqlx::query_as::<_, LocalSendingMessage>(
            "SELECT conversation_id, client_msg_id, ex FROM local_sending_messages WHERE conversation_id = ? AND client_msg_id = ?",
        )
        .bind(conversation_id)
        .bind(client_msg_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("get sending message by client_msg_id: {}", e)))?;
        Ok(row)
    }
}

#[async_trait]
impl SendingMessageRepository for SendingMessageDao {
    async fn insert(&self, msg: &LocalSendingMessage) -> Result<()> {
        self.insert(msg).await
    }

    async fn delete(&self, conversation_id: &str, client_msg_id: &str) -> Result<()> {
        self.delete(conversation_id, client_msg_id).await
    }

    async fn get_all(&self) -> Result<Vec<LocalSendingMessage>> {
        self.get_all().await
    }

    async fn get_by_client_msg_id(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
    ) -> Result<Option<LocalSendingMessage>> {
        self.get_by_client_msg_id(conversation_id, client_msg_id).await
    }
}

// ============================================================================
// 上传记录 DAO
// ============================================================================

/// local_uploads 表 DAO — 断点续传状态持久化
/// 对齐 Go SDK `pkg/db/upload_model.go`
pub struct UploadDao {
    pool: SqlitePool,
}

impl UploadDao {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    /// 根据 part_hash 查询上传记录
    pub async fn get_upload(&self, part_hash: &str) -> Result<Option<LocalUpload>> {
        let row = sqlx::query_as::<_, LocalUpload>(
            "SELECT part_hash, upload_id, upload_info, expire_time, create_time FROM local_uploads WHERE part_hash = ?",
        )
        .bind(part_hash)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("查询上传记录失败: {}", e)))?;
        Ok(row)
    }

    /// 插入新的上传记录
    pub async fn insert_upload(&self, info: &LocalUpload) -> Result<()> {
        sqlx::query(
            "INSERT OR REPLACE INTO local_uploads (part_hash, upload_id, upload_info, expire_time, create_time) VALUES (?, ?, ?, ?, ?)",
        )
        .bind(&info.part_hash)
        .bind(&info.upload_id)
        .bind(&info.upload_info)
        .bind(info.expire_time)
        .bind(info.create_time)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("插入上传记录失败: {}", e)))?;
        Ok(())
    }

    /// 更新上传记录
    pub async fn update_upload(&self, info: &LocalUpload) -> Result<()> {
        sqlx::query(
            "UPDATE local_uploads SET upload_id = ?, upload_info = ?, expire_time = ? WHERE part_hash = ?",
        )
        .bind(&info.upload_id)
        .bind(&info.upload_info)
        .bind(info.expire_time)
        .bind(&info.part_hash)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("更新上传记录失败: {}", e)))?;
        Ok(())
    }

    /// 删除上传记录
    pub async fn delete_upload(&self, part_hash: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_uploads WHERE part_hash = ?")
            .bind(part_hash)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("删除上传记录失败: {}", e)))?;
        Ok(())
    }
}