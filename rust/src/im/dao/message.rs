//! 消息数据访问层（DAO）
//!
//! 负责所有消息相关的数据库操作，将数据访问逻辑与业务逻辑分离

use crate::im::message::models::LocalChatLog;
use anyhow::Result;
use chrono::Utc;
use sqlx::{sqlite::SqlitePoolOptions, FromRow, Pool, Sqlite};

/// 消息表行映射（单表 local_chat_logs，列名 sender_nick_name）
#[derive(Debug, FromRow)]
struct LocalChatLogRow {
    conversation_id: String,
    client_msg_id: String,
    server_msg_id: String,
    send_id: String,
    recv_id: String,
    sender_platform_id: i32,
    #[sqlx(rename = "sender_nick_name")]
    sender_nickname: String,
    sender_face_url: String,
    session_type: i32,
    msg_from: i32,
    content_type: i32,
    content: String,
    is_read: i32,
    status: i32,
    seq: i64,
    send_time: i64,
    create_time: i64,
    attached_info: String,
    ex: String,
    local_ex: String,
    group_id: String,
}

fn row_to_log(r: LocalChatLogRow) -> LocalChatLog {
    LocalChatLog {
        conversation_id: r.conversation_id,
        client_msg_id: r.client_msg_id,
        server_msg_id: r.server_msg_id,
        send_id: r.send_id,
        recv_id: r.recv_id,
        sender_platform_id: r.sender_platform_id,
        sender_nickname: r.sender_nickname,
        sender_face_url: r.sender_face_url,
        session_type: r.session_type,
        msg_from: r.msg_from,
        content_type: r.content_type,
        content: r.content,
        is_read: r.is_read != 0,
        status: r.status,
        seq: r.seq,
        send_time: r.send_time,
        create_time: if r.create_time != 0 { r.create_time } else { Utc::now().timestamp_millis() },
        attached_info: r.attached_info,
        ex: r.ex,
        local_ex: r.local_ex,
        group_id: r.group_id,
    }
}

/// 标量 max_seq 查询结果
#[derive(FromRow)]
struct MaxSeqRow {
    max_seq: i64,
}

/// 本地消息存储（使用 sqlx / SQLite，单表 local_chat_logs，主键 (conversation_id, client_msg_id)）
///
/// 表结构由迁移 20250216000000_local_chat_logs.sql 创建。
#[derive(Clone)]
pub struct MessageRepo {
    pool: Pool<Sqlite>,
    /// 当前登录用户，用于过滤自发消息的已读逻辑
    pub login_user_id: String,
}

const TABLE_LOCAL_CHAT_LOGS: &str = "local_chat_logs";

impl MessageRepo {
    pub fn new(pool: Pool<Sqlite>, login_user_id: String) -> Self {
        Self { pool, login_user_id }
    }

    /// 表由迁移创建，此处仅返回表名
    fn table(&self) -> &'static str {
        TABLE_LOCAL_CHAT_LOGS
    }

    fn placeholders(n: usize) -> String {
        if n == 0 {
            String::new()
        } else {
            vec!["?"; n].join(",")
        }
    }

    pub async fn insert_message(&self, msg: &LocalChatLog) -> Result<()> {
        let table = self.table();
        let sql = format!(
            r#"INSERT OR REPLACE INTO {} (
            conversation_id, client_msg_id, server_msg_id, send_id, recv_id, sender_platform_id,
            sender_nick_name, sender_face_url, session_type, msg_from, content_type, content,
            is_read, status, seq, send_time, create_time, attached_info, ex, local_ex, group_id
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"#,
            table
        );
        sqlx::query(&sql)
            .bind(&msg.conversation_id)
            .bind(&msg.client_msg_id)
            .bind(&msg.server_msg_id)
            .bind(&msg.send_id)
            .bind(&msg.recv_id)
            .bind(msg.sender_platform_id)
            .bind(&msg.sender_nickname)
            .bind(&msg.sender_face_url)
            .bind(msg.session_type)
            .bind(msg.msg_from)
            .bind(msg.content_type)
            .bind(&msg.content)
            .bind(if msg.is_read { 1 } else { 0 })
            .bind(msg.status)
            .bind(msg.seq)
            .bind(msg.send_time)
            .bind(msg.create_time)
            .bind(&msg.attached_info)
            .bind(&msg.ex)
            .bind(&msg.local_ex)
            .bind(&msg.group_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    /// 批量插入消息列表（完全参考 Go SDK 的 BatchInsertMessageList）
    ///
    /// - `conversation_id`: 会话 ID
    /// - `messages`: 消息列表
    pub async fn batch_insert_message_list(&self, conversation_id: &str, messages: &[LocalChatLog]) -> Result<()> {
        if messages.is_empty() {
            return Ok(());
        }

        let table = self.table();
        let mut tx = self.pool.begin().await?;

        for msg in messages {
            let sql = format!(
                r#"INSERT OR REPLACE INTO {} (
                conversation_id, client_msg_id, server_msg_id, send_id, recv_id, sender_platform_id,
                sender_nick_name, sender_face_url, session_type, msg_from, content_type, content,
                is_read, status, seq, send_time, create_time, attached_info, ex, local_ex, group_id
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"#,
                table
            );
            sqlx::query(&sql)
                .bind(&msg.conversation_id)
                .bind(&msg.client_msg_id)
                .bind(&msg.server_msg_id)
                .bind(&msg.send_id)
                .bind(&msg.recv_id)
                .bind(msg.sender_platform_id)
                .bind(&msg.sender_nickname)
                .bind(&msg.sender_face_url)
                .bind(msg.session_type)
                .bind(msg.msg_from)
                .bind(msg.content_type)
                .bind(&msg.content)
                .bind(if msg.is_read { 1 } else { 0 })
                .bind(msg.status)
                .bind(msg.seq)
                .bind(msg.send_time)
                .bind(msg.create_time)
                .bind(&msg.attached_info)
                .bind(&msg.ex)
                .bind(&msg.local_ex)
                .bind(&msg.group_id)
                .execute(&mut *tx)
                .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    /// 更新消息（完全参考 Go SDK 的 UpdateMessage）
    ///
    /// - `conversation_id`: 会话 ID
    /// - `msg`: 要更新的消息
    pub async fn update_message(&self, conversation_id: &str, msg: &LocalChatLog) -> Result<()> {
        let table = self.table();
        let sql = format!(
            r#"UPDATE {} SET server_msg_id = ?, send_id = ?, recv_id = ?, sender_platform_id = ?, sender_nick_name = ?, sender_face_url = ?, session_type = ?, msg_from = ?, content_type = ?, content = ?, is_read = ?, status = ?, seq = ?, send_time = ?, create_time = ?, attached_info = ?, ex = ?, local_ex = ?, group_id = ? WHERE conversation_id = ? AND client_msg_id = ?"#,
            table
        );
        let rows_affected = sqlx::query(&sql)
            .bind(&msg.server_msg_id)
            .bind(&msg.send_id)
            .bind(&msg.recv_id)
            .bind(msg.sender_platform_id)
            .bind(&msg.sender_nickname)
            .bind(&msg.sender_face_url)
            .bind(msg.session_type)
            .bind(msg.msg_from)
            .bind(msg.content_type)
            .bind(&msg.content)
            .bind(if msg.is_read { 1 } else { 0 })
            .bind(msg.status)
            .bind(msg.seq)
            .bind(msg.send_time)
            .bind(msg.create_time)
            .bind(&msg.attached_info)
            .bind(&msg.ex)
            .bind(&msg.local_ex)
            .bind(&msg.group_id)
            .bind(conversation_id)
            .bind(&msg.client_msg_id)
            .execute(&self.pool)
            .await?
            .rows_affected();

        if rows_affected == 0 {
            return Err(anyhow::anyhow!("消息不存在或未更新"));
        }
        Ok(())
    }

    /// 更新消息时间和状态（完全参考 Go SDK 的 UpdateMessageTimeAndStatus）
    ///
    /// - `conversation_id`: 会话 ID
    /// - `client_msg_id`: 消息 ID
    /// - `server_msg_id`: 服务器消息 ID
    /// - `send_time`: 发送时间
    /// - `status`: 消息状态
    pub async fn update_message_time_and_status(&self, conversation_id: &str, client_msg_id: &str, server_msg_id: &str, send_time: i64, status: i32) -> Result<()> {
        let table = self.table();
        let sql = format!(r#"UPDATE {} SET server_msg_id = ?, send_time = ?, status = ? WHERE conversation_id = ? AND client_msg_id = ?"#, table);
        sqlx::query(&sql).bind(server_msg_id).bind(send_time).bind(status).bind(conversation_id).bind(client_msg_id).execute(&self.pool).await?;
        Ok(())
    }

    pub async fn get_by_client_msg_id(&self, conversation_id: &str, client_msg_id: &str) -> Result<Option<LocalChatLog>> {
        let table = self.table();
        let sql = format!("SELECT * FROM {} WHERE conversation_id = ? AND client_msg_id = ? LIMIT 1", table);
        let row: Option<LocalChatLogRow> = sqlx::query_as(&sql).bind(conversation_id).bind(client_msg_id).fetch_optional(&self.pool).await?;
        Ok(row.map(row_to_log))
    }

    pub async fn delete_by_client_msg_id(&self, conversation_id: &str, client_msg_id: &str) -> Result<()> {
        let table = self.table();
        let sql = format!("DELETE FROM {} WHERE conversation_id = ? AND client_msg_id = ?", table);
        sqlx::query(&sql).bind(conversation_id).bind(client_msg_id).execute(&self.pool).await?;
        Ok(())
    }

    pub async fn delete_conversation(&self, conversation_id: &str) -> Result<()> {
        let table = self.table();
        let sql = format!("DELETE FROM {} WHERE conversation_id = ?", table);
        sqlx::query(&sql).bind(conversation_id).execute(&self.pool).await?;
        Ok(())
    }

    pub async fn mark_as_read_by_msg_ids(&self, conversation_id: &str, msg_ids: &[String]) -> Result<i64> {
        if msg_ids.is_empty() {
            return Ok(0);
        }
        let table = self.table();
        let placeholders = Self::placeholders(msg_ids.len());
        let sql = format!("UPDATE {} SET is_read = 1 WHERE conversation_id = ? AND client_msg_id IN ({}) AND send_id != ?", table, placeholders);
        let mut query = sqlx::query(&sql).bind(conversation_id);
        for id in msg_ids {
            query = query.bind(id);
        }
        query = query.bind(self.login_user_id.clone());
        let res = query.execute(&self.pool).await?;
        Ok(res.rows_affected() as i64)
    }

    pub async fn mark_as_read_by_seqs(&self, conversation_id: &str, seqs: &[i64]) -> Result<i64> {
        if seqs.is_empty() {
            return Ok(0);
        }
        let table = self.table();
        let placeholders = Self::placeholders(seqs.len());
        let sql = format!("UPDATE {} SET is_read = 1 WHERE conversation_id = ? AND seq IN ({}) AND send_id != ?", table, placeholders);
        let mut query = sqlx::query(&sql).bind(conversation_id);
        for s in seqs {
            query = query.bind(s);
        }
        query = query.bind(self.login_user_id.clone());
        let res = query.execute(&self.pool).await?;
        Ok(res.rows_affected() as i64)
    }

    pub async fn get_unread_by_conversation(&self, conversation_id: &str) -> Result<Vec<LocalChatLog>> {
        let table = self.table();
        let sql = format!("SELECT * FROM {} WHERE conversation_id = ? AND is_read = 0 AND send_id != ? ORDER BY send_time DESC", table);
        let rows: Vec<LocalChatLogRow> = sqlx::query_as(&sql).bind(conversation_id).bind(&self.login_user_id).fetch_all(&self.pool).await?;
        Ok(rows.into_iter().map(row_to_log).collect())
    }

    pub async fn get_messages_by_seq(&self, conversation_id: &str, seqs: &[i64]) -> Result<Vec<LocalChatLog>> {
        if seqs.is_empty() {
            return Ok(vec![]);
        }
        let table = self.table();
        let placeholders = Self::placeholders(seqs.len());
        let sql = format!("SELECT * FROM {} WHERE conversation_id = ? AND seq IN ({}) ORDER BY send_time DESC", table, placeholders);
        let mut query = sqlx::query_as::<_, LocalChatLogRow>(&sql).bind(conversation_id);
        for s in seqs {
            query = query.bind(s);
        }
        let rows = query.fetch_all(&self.pool).await?;
        Ok(rows.into_iter().map(row_to_log).collect())
    }

    pub async fn get_messages_by_client_msg_ids(&self, conversation_id: &str, ids: &[String]) -> Result<Vec<LocalChatLog>> {
        if ids.is_empty() {
            return Ok(vec![]);
        }
        let table = self.table();
        let placeholders = Self::placeholders(ids.len());
        let sql = format!("SELECT * FROM {} WHERE conversation_id = ? AND client_msg_id IN ({}) ORDER BY send_time DESC", table, placeholders);
        let mut query = sqlx::query_as::<_, LocalChatLogRow>(&sql).bind(conversation_id);
        for id in ids {
            query = query.bind(id);
        }
        let rows = query.fetch_all(&self.pool).await?;
        Ok(rows.into_iter().map(row_to_log).collect())
    }

    pub async fn max_seq(&self, conversation_id: &str) -> Result<i64> {
        let table = self.table();
        let sql = format!("SELECT IFNULL(MAX(seq),0) as max_seq FROM {} WHERE conversation_id = ?", table);
        let row: MaxSeqRow = sqlx::query_as(&sql).bind(conversation_id).fetch_one(&self.pool).await?;
        Ok(row.max_seq)
    }

    pub async fn check_conversation_normal_msg_seq(&self, conversation_id: &str) -> Result<i64> {
        self.max_seq(conversation_id).await
    }

    pub async fn peer_max_seq(&self, conversation_id: &str) -> Result<i64> {
        let table = self.table();
        let sql = format!("SELECT IFNULL(MAX(seq),0) as max_seq FROM {} WHERE conversation_id = ? AND send_id != ?", table);
        let row: MaxSeqRow = sqlx::query_as(&sql).bind(conversation_id).bind(&self.login_user_id).fetch_one(&self.pool).await?;
        Ok(row.max_seq)
    }

    pub async fn update_local_ex(&self, conversation_id: &str, client_msg_id: &str, local_ex: &str) -> Result<u64> {
        let table = self.table();
        let sql = format!(r#"UPDATE {} SET local_ex = ? WHERE conversation_id = ? AND client_msg_id = ?"#, table);
        let res = sqlx::query(&sql).bind(local_ex).bind(conversation_id).bind(client_msg_id).execute(&self.pool).await?;
        Ok(res.rows_affected())
    }

    /// 获取历史消息列表（完全参考 Go SDK 的 GetMessageList 实现）
    ///
    /// 参数完全匹配 Go SDK：
    /// - `conversation_id`: 会话 ID
    /// - `count`: 每次加载的消息数量
    /// - `start_time`: 起始时间戳（0 表示从最新开始）
    /// - `start_seq`: 起始序列号（0 表示从最新开始）
    /// - `start_client_msg_id`: 起始消息ID（空字符串表示从最新开始）
    /// - `is_reverse`: 是否反向（true=从旧到新，false=从新到旧）
    ///
    /// 返回: 消息列表
    pub async fn get_message_list(&self, conversation_id: &str, count: i32, start_time: i64, start_seq: i64, start_client_msg_id: &str, is_reverse: bool) -> Result<Vec<LocalChatLog>> {
        let table = self.table();
        let (time_order, time_symbol) = if is_reverse { ("send_time ASC, seq ASC", ">") } else { ("send_time DESC, seq DESC", "<") };

        let rows: Vec<LocalChatLogRow> = if start_time > 0 {
            let condition = format!("conversation_id = ? AND (send_time {} ? OR (send_time = ? AND (seq {} ? OR (seq = 0 AND client_msg_id != ?))))", time_symbol, time_symbol);
            let sql = format!("SELECT * FROM {} WHERE {} ORDER BY {} LIMIT ?", table, condition, time_order);
            sqlx::query_as(&sql)
                .bind(conversation_id)
                .bind(start_time)
                .bind(start_time)
                .bind(start_seq)
                .bind(start_client_msg_id)
                .bind(count)
                .fetch_all(&self.pool)
                .await?
        } else {
            let sql = format!("SELECT * FROM {} WHERE conversation_id = ? ORDER BY {} LIMIT ?", table, time_order);
            sqlx::query_as(&sql).bind(conversation_id).bind(count).fetch_all(&self.pool).await?
        };

        Ok(rows.into_iter().map(row_to_log).collect())
    }

    pub async fn search_local_messages(
        &self,
        conversation_id: Option<&str>,
        keyword: Option<&str>,
        content_types: Option<&[i32]>,
        send_time_begin: Option<i64>,
        send_time_end: Option<i64>,
    ) -> Result<Vec<LocalChatLog>> {
        let conversation_id = conversation_id.ok_or_else(|| anyhow::anyhow!("search_local_messages 需要指定 conversation_id"))?;
        let table = self.table();
        let mut clauses = vec!["conversation_id = ?".to_string()];
        enum Bind {
            Str(String),
            I64(i64),
            I32(i32),
        }
        let mut binds: Vec<Bind> = vec![Bind::Str(conversation_id.to_string())];
        if let Some(kw) = keyword {
            clauses.push("content LIKE ?".to_string());
            binds.push(Bind::Str(format!("%{}%", kw)));
        }
        if let Some(cts) = content_types {
            if !cts.is_empty() {
                let placeholders = Self::placeholders(cts.len());
                clauses.push(format!("content_type IN ({})", placeholders));
                for ct in cts {
                    binds.push(Bind::I32(*ct));
                }
            }
        }
        if let Some(start) = send_time_begin {
            clauses.push("send_time >= ?".to_string());
            binds.push(Bind::I64(start));
        }
        if let Some(end) = send_time_end {
            clauses.push("send_time <= ?".to_string());
            binds.push(Bind::I64(end));
        }
        let where_sql = format!("WHERE {}", clauses.join(" AND "));
        let sql = format!("SELECT * FROM {} {} ORDER BY send_time DESC LIMIT 200", table, where_sql);
        let mut query = sqlx::query_as::<_, LocalChatLogRow>(&sql);
        for val in binds {
            match val {
                Bind::Str(s) => query = query.bind(s),
                Bind::I64(i) => query = query.bind(i),
                Bind::I32(i) => query = query.bind(i),
            }
        }
        let rows: Vec<LocalChatLogRow> = query.fetch_all(&self.pool).await?;
        Ok(rows.into_iter().map(row_to_log).collect())
    }
}
