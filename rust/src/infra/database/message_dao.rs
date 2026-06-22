use super::models::LocalChatLog;
use crate::domain::constant::enums::MessageSendStatus;
use crate::domain::error::types::{Result, SdkError};
use sqlx::SqlitePool;

pub struct MessageDao {
    pool: SqlitePool,
}

impl MessageDao {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub async fn batch_insert(&self, logs: &[LocalChatLog]) -> Result<()> {
        for log in logs {
            sqlx::query(
                "INSERT OR IGNORE INTO local_chat_logs (conversation_id, client_msg_id, server_msg_id, send_id, recv_id, sender_platform_id, sender_nick_name, sender_face_url, session_type, msg_from, content_type, content, is_read, status, seq, send_time, create_time, attached_info, ex, local_ex, group_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            )
            .bind(&log.conversation_id)
            .bind(&log.client_msg_id)
            .bind(&log.server_msg_id)
            .bind(&log.send_id)
            .bind(&log.recv_id)
            .bind(log.sender_platform_id)
            .bind(&log.sender_nick_name)
            .bind(&log.sender_face_url)
            .bind(log.session_type)
            .bind(log.msg_from)
            .bind(log.content_type)
            .bind(&log.content)
            .bind(log.is_read)
            .bind(log.status)
            .bind(log.seq)
            .bind(log.send_time)
            .bind(log.create_time)
            .bind(&log.attached_info)
            .bind(&log.ex)
            .bind(&log.local_ex)
            .bind(&log.group_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("insert message: {}", e)))?;
        }
        Ok(())
    }

    pub async fn get_by_conversation(
        &self,
        conversation_id: &str,
        start_time: i64,
        count: i64,
    ) -> Result<Vec<LocalChatLog>> {
        let rows = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? AND (send_time < ? OR ? = 0) ORDER BY send_time DESC LIMIT ?",
        )
        .bind(conversation_id)
        .bind(start_time)
        .bind(start_time)
        .bind(count)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query messages: {}", e)))?;

        Ok(rows)
    }

    pub async fn get_max_seq(&self, conversation_id: &str) -> Result<i64> {
        let row: (Option<i64>,) = sqlx::query_as(
            "SELECT MAX(seq) FROM local_chat_logs WHERE conversation_id = ?",
        )
        .bind(conversation_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query max seq: {}", e)))?;
        Ok(row.0.unwrap_or(0))
    }

    pub async fn get_by_client_msg_id(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
    ) -> Result<Option<LocalChatLog>> {
        let row = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? AND client_msg_id = ?",
        )
        .bind(conversation_id)
        .bind(client_msg_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query message by client_msg_id: {}", e)))?;
        Ok(row)
    }

    /// 按 seq 获取单条消息
    pub async fn get_by_seq(&self, seq: i64) -> Result<Option<LocalChatLog>> {
        let row = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE seq = ? LIMIT 1",
        )
        .bind(seq)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query message by seq: {}", e)))?;
        Ok(row)
    }

    pub async fn get_by_conversation_and_seq(&self, conversation_id: &str, seq: i64) -> Result<Option<LocalChatLog>> {
        let row = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? AND seq = ? LIMIT 1",
        )
        .bind(conversation_id)
        .bind(seq)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query message by conversation and seq: {}", e)))?;
        Ok(row)
    }

    pub async fn get_by_client_msg_ids(&self, client_msg_ids: &[String]) -> Result<Vec<LocalChatLog>> {
        if client_msg_ids.is_empty() {
            return Ok(Vec::new());
        }
        let placeholders = client_msg_ids.iter().map(|_| "?").collect::<Vec<_>>().join(", ");
        let query = format!(
            "SELECT * FROM local_chat_logs WHERE client_msg_id IN ({})",
            placeholders
        );
        let mut builder = sqlx::query_as::<_, LocalChatLog>(&query);
        for id in client_msg_ids {
            builder = builder.bind(id);
        }
        let rows = builder.fetch_all(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("query by client_msg_ids: {}", e)))?;
        Ok(rows)
    }

    pub async fn get_latest(
        &self,
        conversation_id: &str,
        limit: i64,
    ) -> Result<Vec<LocalChatLog>> {
        let rows = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? ORDER BY send_time DESC LIMIT ?",
        )
        .bind(conversation_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query latest: {}", e)))?;
        Ok(rows)
    }

    pub async fn delete_by_conversation(&self, conversation_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_chat_logs WHERE conversation_id = ?")
            .bind(conversation_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("delete by conversation: {}", e)))?;

        Ok(())
    }

    pub async fn update_send_status(&self, client_msg_id: &str, status: MessageSendStatus) -> Result<()> {
        sqlx::query("UPDATE local_chat_logs SET status = ? WHERE client_msg_id = ?")
            .bind(status as i32)
            .bind(client_msg_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("update send status: {}", e)))?;
        Ok(())
    }

    pub async fn update_after_send_success(&self, client_msg_id: &str, server_msg_id: &str, send_time: i64) -> Result<()> {
        sqlx::query(
            "UPDATE local_chat_logs SET server_msg_id = ?, send_time = ?, create_time = ?, status = ? WHERE client_msg_id = ?"
        )
        .bind(server_msg_id)
        .bind(send_time)
        .bind(send_time)
        .bind(MessageSendStatus::SendSuccess as i32)
        .bind(client_msg_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("update after send success: {}", e)))?;
        Ok(())
    }

    /// 批量更新消息的 seq（对齐 Go SDK batchUpdateMessageList）
    pub async fn batch_update_seq(&self, updates: &[(String, i64)]) -> Result<()> {
        for (client_msg_id, seq) in updates {
            sqlx::query(
                "UPDATE local_chat_logs SET seq = ? WHERE client_msg_id = ? AND seq = 0"
            )
            .bind(seq)
            .bind(client_msg_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("batch update seq: {}", e)))?;
        }
        Ok(())
    }

    /// 按 max_seq 批量标记消息为已读（排除自己发送的消息）
    /// 对齐 Go SDK `MarkConversationMessageAsReadBySeqs` 中 `send_id != GetSelfUserID()`
    pub async fn mark_as_read_by_max_seq(&self, conversation_id: &str, max_seq: i64, self_user_id: &str) -> Result<()> {
        sqlx::query(
            "UPDATE local_chat_logs SET is_read = 1 WHERE conversation_id = ? AND seq <= ? AND seq > 0 AND send_id != ?",
        )
            .bind(conversation_id)
            .bind(max_seq)
            .bind(self_user_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("mark as read by max seq: {}", e)))?;
        Ok(())
    }

    pub async fn delete_by_client_msg_id(&self, conversation_id: &str, client_msg_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_chat_logs WHERE conversation_id = ? AND client_msg_id = ?")
            .bind(conversation_id)
            .bind(client_msg_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("delete message by client_msg_id: {}", e)))?;
        Ok(())
    }

    pub async fn update_content_type(&self, conversation_id: &str, client_msg_id: &str, content_type: i32) -> Result<()> {
        sqlx::query("UPDATE local_chat_logs SET content_type = ? WHERE conversation_id = ? AND client_msg_id = ?")
            .bind(content_type)
            .bind(conversation_id)
            .bind(client_msg_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("update content_type: {}", e)))?;
        Ok(())
    }

    /// 更新消息的 content 和 content_type（用于撤回消息时替换内容）
    pub async fn update_message_content_and_type(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
        content: &str,
        content_type: i32,
    ) -> Result<()> {
        sqlx::query("UPDATE local_chat_logs SET content = ?, content_type = ? WHERE conversation_id = ? AND client_msg_id = ?")
            .bind(content)
            .bind(content_type)
            .bind(conversation_id)
            .bind(client_msg_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("update message content and type: {}", e)))?;
        Ok(())
    }

    pub async fn search_by_keyword(&self, conversation_id: &str, keyword: &str, max_count: i64) -> Result<Vec<LocalChatLog>> {
        let pattern = format!("%{}%", keyword);
        let rows = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? AND content LIKE ? ORDER BY send_time DESC LIMIT ?",
        )
        .bind(conversation_id)
        .bind(&pattern)
        .bind(max_count)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("search messages: {}", e)))?;
        Ok(rows)
    }

    /// 按内容类型搜索消息（用于撤回时查找引用消息）
    pub async fn search_by_content_type(&self, conversation_id: &str, content_type: i32) -> Result<Vec<LocalChatLog>> {
        let rows = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? AND content_type = ?",
        )
        .bind(conversation_id)
        .bind(content_type)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("search messages by content_type: {}", e)))?;
        Ok(rows)
    }

    pub async fn mark_as_read_by_seqs(&self, conversation_id: &str, seqs: &[i64], self_user_id: &str) -> Result<()> {
        if seqs.is_empty() {
            return Ok(());
        }
        let placeholders = seqs.iter().map(|_| "?").collect::<Vec<_>>().join(",");
        let sql = format!(
            "UPDATE local_chat_logs SET is_read = 1 WHERE conversation_id = ? AND seq IN ({}) AND send_id != ?",
            placeholders
        );
        let mut query = sqlx::query(&sql).bind(conversation_id);
        for seq in seqs {
            query = query.bind(seq);
        }
        query = query.bind(self_user_id);
        query.execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("mark as read: {}", e)))?;
        Ok(())
    }

    /// 按 seq 列表标记消息已读（不过滤 send_id，用于已读回执处理）
    /// 对齐 Go SDK doReadDrawing：收到已读回执时直接标记指定 seq 的消息
    pub async fn mark_as_read_by_seqs_all(&self, conversation_id: &str, seqs: &[i64]) -> Result<()> {
        if seqs.is_empty() {
            return Ok(());
        }
        let placeholders = seqs.iter().map(|_| "?").collect::<Vec<_>>().join(",");
        let sql = format!(
            "UPDATE local_chat_logs SET is_read = 1 WHERE conversation_id = ? AND seq IN ({})",
            placeholders
        );
        let mut query = sqlx::query(&sql).bind(conversation_id);
        for seq in seqs {
            query = query.bind(seq);
        }
        query.execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("mark as read all: {}", e)))?;
        Ok(())
    }

    /// 获取会话中对方发送的未读消息（对齐 Go SDK `GetUnreadMessage`）
    /// WHERE send_id != self AND is_read = 0
    pub async fn get_unread_messages(&self, conversation_id: &str, self_user_id: &str) -> Result<Vec<LocalChatLog>> {
        let rows = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? AND send_id != ? AND is_read = 0",
        )
        .bind(conversation_id)
        .bind(self_user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query unread messages: {}", e)))?;
        Ok(rows)
    }

    /// 按 client_msg_id 列表标记消息已读（排除自己发送的消息）
    /// 对齐 Go SDK `MarkConversationMessageAsReadDB`：WHERE client_msg_id IN (?) AND send_id != self
    pub async fn mark_as_read_by_client_msg_ids(
        &self,
        conversation_id: &str,
        client_msg_ids: &[String],
        self_user_id: &str,
    ) -> Result<()> {
        if client_msg_ids.is_empty() {
            return Ok(());
        }
        let placeholders = client_msg_ids.iter().map(|_| "?").collect::<Vec<_>>().join(",");
        let sql = format!(
            "UPDATE local_chat_logs SET is_read = 1 WHERE conversation_id = ? AND client_msg_id IN ({}) AND send_id != ?",
            placeholders
        );
        let mut query = sqlx::query(&sql).bind(conversation_id);
        for id in client_msg_ids {
            query = query.bind(id);
        }
        query = query.bind(self_user_id);
        query.execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("mark as read by client_msg_ids: {}", e)))?;
        Ok(())
    }

    /// 获取会话中对方发送消息的最大 seq（对齐 Go SDK `GetConversationPeerNormalMsgSeq`）
    pub async fn get_peer_normal_msg_seq(&self, conversation_id: &str, self_user_id: &str) -> Result<i64> {
        let row: (Option<i64>,) = sqlx::query_as(
            "SELECT MAX(seq) FROM local_chat_logs WHERE conversation_id = ? AND send_id != ?",
        )
        .bind(conversation_id)
        .bind(self_user_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query peer max seq: {}", e)))?;
        Ok(row.0.unwrap_or(0))
    }

    /// 按 seq 列表查询消息（对齐 Go SDK `GetMessagesBySeqs`）
    pub async fn get_by_seqs(&self, conversation_id: &str, seqs: &[i64]) -> Result<Vec<LocalChatLog>> {
        if seqs.is_empty() {
            return Ok(Vec::new());
        }
        let placeholders = seqs.iter().map(|_| "?").collect::<Vec<_>>().join(",");
        let sql = format!(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? AND seq IN ({})",
            placeholders
        );
        let mut query = sqlx::query_as::<_, LocalChatLog>(&sql).bind(conversation_id);
        for seq in seqs {
            query = query.bind(seq);
        }
        let rows = query.fetch_all(&self.pool).await
            .map_err(|e| SdkError::database(format!("query messages by seqs: {}", e)))?;
        Ok(rows)
    }

    /// 按会话 ASC 排序获取消息（用于倒序翻页，对齐 Go SDK `GetAdvancedHistoryMessageListReverse`）
    pub async fn get_by_conversation_asc(
        &self,
        conversation_id: &str,
        start_time: i64,
        count: i64,
    ) -> Result<Vec<LocalChatLog>> {
        let rows = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? AND (send_time > ? OR ? = 0) ORDER BY send_time ASC LIMIT ?",
        )
        .bind(conversation_id)
        .bind(start_time)
        .bind(start_time)
        .bind(count)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query messages asc: {}", e)))?;

        Ok(rows)
    }

    /// 更新消息本地扩展字段（对齐 Go SDK `SetMessageLocalEx`）
    pub async fn update_local_ex(&self, conversation_id: &str, client_msg_id: &str, local_ex: &str) -> Result<()> {
        sqlx::query("UPDATE local_chat_logs SET local_ex = ? WHERE conversation_id = ? AND client_msg_id = ?")
            .bind(local_ex)
            .bind(conversation_id)
            .bind(client_msg_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("update local_ex: {}", e)))?;
        Ok(())
    }

    /// 软删除单条消息（对齐 Go SDK `DeleteMessageFromLocalStorage`）
    ///
    /// 将状态标记为 MsgStatusHasDeleted (4)
    pub async fn mark_as_deleted(&self, conversation_id: &str, client_msg_id: &str) -> Result<()> {
        sqlx::query("UPDATE local_chat_logs SET status = 4 WHERE conversation_id = ? AND client_msg_id = ?")
            .bind(conversation_id)
            .bind(client_msg_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("mark as deleted: {}", e)))?;
        Ok(())
    }

    /// 软删除指定会话的所有消息（对齐 Go SDK `DeleteAllMsgFromLocal`）
    pub async fn mark_all_as_deleted(&self) -> Result<()> {
        sqlx::query("UPDATE local_chat_logs SET status = 4")
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("mark all as deleted: {}", e)))?;
        Ok(())
    }

    /// 硬删除所有消息（对齐 Go SDK `DeleteAllMsgFromLocalAndSvr` 本地部分）
    pub async fn delete_all(&self) -> Result<()> {
        sqlx::query("DELETE FROM local_chat_logs")
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("delete all: {}", e)))?;
        Ok(())
    }

    /// 获取指定会话的最小 seq（对齐 Go SDK message_check.go 中的 userCanPullMinSeq）
    pub async fn get_min_seq(&self, conversation_id: &str) -> Result<i64> {
        let row: (Option<i64>,) = sqlx::query_as(
            "SELECT MIN(seq) FROM local_chat_logs WHERE conversation_id = ? AND seq > 0",
        )
        .bind(conversation_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query min seq: {}", e)))?;
        Ok(row.0.unwrap_or(0))
    }

    /// 获取指定会话在 [min_seq, max_seq] 范围内已有的 seq 列表
    ///
    /// 用于 seq gap 检测时快速判断哪些 seq 已存在于本地。
    pub async fn get_existing_seqs_in_range(
        &self,
        conversation_id: &str,
        min_seq: i64,
        max_seq: i64,
    ) -> Result<Vec<i64>> {
        let rows: Vec<(i64,)> = sqlx::query_as(
            "SELECT seq FROM local_chat_logs WHERE conversation_id = ? AND seq >= ? AND seq <= ? AND seq > 0",
        )
        .bind(conversation_id)
        .bind(min_seq)
        .bind(max_seq)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query seqs in range: {}", e)))?;
        Ok(rows.into_iter().map(|(s,)| s).collect())
    }

    /// 按 seq 范围查询消息（对齐 Go SDK `GetAdvancedHistoryMessageList` seq 范围）
    pub async fn get_by_seq_range(
        &self,
        conversation_id: &str,
        start_seq: i64,
        end_seq: i64,
        count: i64,
    ) -> Result<Vec<LocalChatLog>> {
        let rows = sqlx::query_as::<_, LocalChatLog>(
            "SELECT * FROM local_chat_logs WHERE conversation_id = ? AND seq >= ? AND seq <= ? AND seq > 0 ORDER BY seq ASC LIMIT ?",
        )
        .bind(conversation_id)
        .bind(start_seq)
        .bind(end_seq)
        .bind(count)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("get_by_seq_range: {}", e)))?;
        Ok(rows)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

    #[tokio::test]
    async fn test_message_dao_batch_insert() {
        let pool = create_pool_memory().await.unwrap();
        let dao = MessageDao::new(pool);

        let msg = LocalChatLog {
            conversation_id: "conv_1".into(),
            client_msg_id: "msg_1".into(),
            server_msg_id: String::new(),
            send_id: "user_1".into(),
            recv_id: "user_2".into(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: r#"{"text":"hello"}"#.into(),
            is_read: 0,
            status: MessageSendStatus::SendSuccess as i32,
            seq: 1,
            send_time: 1000,
            create_time: 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        };

        dao.batch_insert(&[msg]).await.unwrap();
        let seq = dao.get_max_seq("conv_1").await.unwrap();
        assert_eq!(seq, 1);
    }

    #[tokio::test]
    async fn test_message_dao_dedup() {
        let pool = create_pool_memory().await.unwrap();
        let dao = MessageDao::new(pool);

        let msg = LocalChatLog {
            conversation_id: "conv_1".into(),
            client_msg_id: "msg_1".into(),
            server_msg_id: String::new(),
            send_id: "user_1".into(),
            recv_id: "user_2".into(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: String::new(),
            is_read: 0,
            status: MessageSendStatus::SendSuccess as i32,
            seq: 1,
            send_time: 1000,
            create_time: 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        };

        dao.batch_insert(&[msg.clone()]).await.unwrap();
        dao.batch_insert(&[msg]).await.unwrap();
        let msgs = dao.get_by_conversation("conv_1", 0, 100).await.unwrap();
        assert_eq!(msgs.len(), 1);    }

    #[tokio::test]
    async fn test_mark_as_read_by_seqs() {
        let pool = create_pool_memory().await.unwrap();
        let dao = MessageDao::new(pool);

        let mut msg = LocalChatLog {
            conversation_id: "conv_1".into(),
            client_msg_id: "msg_1".into(),
            server_msg_id: String::new(),
            send_id: "user_1".into(),
            recv_id: "user_2".into(),
            sender_platform_id: 1,
            sender_nick_name: String::new(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 100,
            content_type: 101,
            content: String::new(),
            is_read: 0,
            status: MessageSendStatus::SendSuccess as i32,
            seq: 1,
            send_time: 1000,
            create_time: 1000,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: String::new(),
        };

        dao.batch_insert(&[msg]).await.unwrap();
        dao.mark_as_read_by_seqs("conv_1", &[1], "user1").await.unwrap();

        let msgs = dao.get_by_conversation("conv_1", 0, 100).await.unwrap();
        assert_eq!(msgs.len(), 1);
        assert_eq!(msgs[0].is_read, 1);
    }
}
