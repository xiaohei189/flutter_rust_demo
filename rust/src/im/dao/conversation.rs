//! 会话数据访问层（DAO）
//!
//! 负责所有会话相关的数据库操作，将数据访问逻辑与业务逻辑分离。
//! 本模块已从 SeaORM 完全迁移到 sqlx。

use crate::im::model::conversation::LocalVersionSync;
use crate::im::model::LocalConversation;
use anyhow::{Context, Result};
use sqlx::{FromRow, Pool, Sqlite};
use tracing::{debug, info};

/// 版本同步表行映射（DB version 为 INTEGER），供 conversation / friend 等 dao 复用
#[derive(Debug, FromRow)]
pub struct VersionSyncRow {
    pub table_name: String,
    pub entity_id: String,
    pub version: i64,
    pub version_id: String,
}

impl From<VersionSyncRow> for LocalVersionSync {
    fn from(r: VersionSyncRow) -> Self {
        LocalVersionSync {
            table_name: r.table_name,
            entity_id: r.entity_id,
            version: r.version as u64,
            version_id: r.version_id,
        }
    }
}

/// 总未读数查询结果
#[derive(FromRow)]
struct UnreadTotalRow {
    total: Option<i64>,
}

/// 会话 DAO（基于 sqlx）
#[derive(Debug, Clone)]
pub struct ConversationDao {
    db: Pool<Sqlite>,
}

impl ConversationDao {
    /// 创建新的会话 DAO
    pub fn new(db: Pool<Sqlite>) -> Self {
        Self { db }
    }

    /// 初始化数据库表结构
    pub async fn init_db(&self) -> Result<()> {
        Self::init_db_with_connection(&self.db).await
    }

    /// 使用共享连接初始化数据库表结构（静态方法）
    pub async fn init_db_with_connection(db: &Pool<Sqlite>) -> Result<()> {
        info!("[ConvDAO/DB] 初始化会话数据库表结构");

        let sql1 = r#"
            CREATE TABLE IF NOT EXISTS local_conversations (
                conversation_id TEXT PRIMARY KEY,
                conversation_type INTEGER NOT NULL,
                user_id TEXT NOT NULL DEFAULT '',
                group_id TEXT NOT NULL DEFAULT '',
                show_name TEXT NOT NULL DEFAULT '',
                face_url TEXT NOT NULL DEFAULT '',
                latest_msg TEXT NOT NULL DEFAULT '',
                latest_msg_send_time INTEGER NOT NULL DEFAULT 0,
                unread_count INTEGER NOT NULL DEFAULT 0,
                recv_msg_opt INTEGER NOT NULL DEFAULT 0,
                is_pinned INTEGER NOT NULL DEFAULT 0,
                is_private_chat INTEGER NOT NULL DEFAULT 0,
                burn_duration INTEGER NOT NULL DEFAULT 0,
                group_at_type INTEGER NOT NULL DEFAULT 0,
                is_not_in_group INTEGER NOT NULL DEFAULT 0,
                update_unread_count_time INTEGER NOT NULL DEFAULT 0,
                attached_info TEXT NOT NULL DEFAULT '',
                ex TEXT NOT NULL DEFAULT '',
                draft_text TEXT NOT NULL DEFAULT '',
                draft_text_time INTEGER NOT NULL DEFAULT 0,
                max_seq INTEGER NOT NULL DEFAULT 0,
                min_seq INTEGER NOT NULL DEFAULT 0,
                is_msg_destruct INTEGER NOT NULL DEFAULT 0,
                msg_destruct_time INTEGER NOT NULL DEFAULT 0
            )
        "#;
        sqlx::query(sql1).execute(db).await.context("创建会话表失败")?;

        let sql2 = r#"
            CREATE TABLE IF NOT EXISTS local_version_sync (
                table_name TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                version INTEGER NOT NULL DEFAULT 0,
                version_id TEXT NOT NULL DEFAULT '',
                PRIMARY KEY (table_name, entity_id)
            )
        "#;
        sqlx::query(sql2).execute(db).await.context("创建版本同步表失败")?;

        info!("[ConvDAO/DB] 数据库表初始化完成");
        Ok(())
    }

    /// 从数据库获取所有本地会话
    pub async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        let rows: Vec<LocalConversation> = sqlx::query_as(
            r#"
            SELECT
                conversation_id,
                conversation_type,
                user_id,
                group_id,
                show_name,
                face_url,
                latest_msg,
                latest_msg_send_time,
                unread_count,
                recv_msg_opt,
                is_pinned,
                is_private_chat,
                burn_duration,
                group_at_type,
                is_not_in_group,
                update_unread_count_time,
                attached_info,
                ex,
                draft_text,
                draft_text_time,
                max_seq,
                min_seq,
                is_msg_destruct,
                msg_destruct_time
            FROM local_conversations
            "#,
        )
        .fetch_all(&self.db)
        .await
        .context("查询会话列表失败")?;

        Ok(rows)
    }

    /// 从数据库获取所有会话 ID
    pub async fn get_all_conversation_ids(&self) -> Result<Vec<String>> {
        #[derive(FromRow)]
        struct IdRow {
            conversation_id: String,
        }
        let rows: Vec<IdRow> =
            sqlx::query_as("SELECT conversation_id FROM local_conversations")
                .fetch_all(&self.db)
                .await
                .context("查询会话ID列表失败")?;
        let ids: Vec<String> = rows.into_iter().map(|r| r.conversation_id).collect();
        Ok(ids)
    }

    /// 根据会话ID查询单个会话
    pub async fn get_conversation_by_id(&self, conversation_id: &str) -> Result<Option<LocalConversation>> {
        let row: Option<LocalConversation> = sqlx::query_as(
            r#"
            SELECT
                conversation_id,
                conversation_type,
                user_id,
                group_id,
                show_name,
                face_url,
                latest_msg,
                latest_msg_send_time,
                unread_count,
                recv_msg_opt,
                is_pinned,
                is_private_chat,
                burn_duration,
                group_at_type,
                is_not_in_group,
                update_unread_count_time,
                attached_info,
                ex,
                draft_text,
                draft_text_time,
                max_seq,
                min_seq,
                is_msg_destruct,
                msg_destruct_time
            FROM local_conversations
            WHERE conversation_id = ?
            "#,
        )
        .bind(conversation_id)
        .fetch_optional(&self.db)
        .await
        .context("查询单个会话失败")?;

        Ok(row)
    }

    /// 插入或更新会话到数据库
    pub async fn upsert_conversation(&self, conv: &LocalConversation) -> Result<()> {
        let sql = r#"
            INSERT INTO local_conversations (
                conversation_id,
                conversation_type,
                user_id,
                group_id,
                show_name,
                face_url,
                latest_msg,
                latest_msg_send_time,
                unread_count,
                recv_msg_opt,
                is_pinned,
                is_private_chat,
                burn_duration,
                group_at_type,
                is_not_in_group,
                update_unread_count_time,
                attached_info,
                ex,
                draft_text,
                draft_text_time,
                max_seq,
                min_seq,
                is_msg_destruct,
                msg_destruct_time
            ) VALUES (
                ?,?,?,?,?,?,
                ?,?,?,?,?,?,
                ?,?,?,?,?,?,
                ?,?,?,?,?,?
            )
            ON CONFLICT(conversation_id) DO UPDATE SET
                conversation_type = excluded.conversation_type,
                user_id = excluded.user_id,
                group_id = excluded.group_id,
                show_name = excluded.show_name,
                face_url = excluded.face_url,
                latest_msg = excluded.latest_msg,
                latest_msg_send_time = excluded.latest_msg_send_time,
                unread_count = excluded.unread_count,
                recv_msg_opt = excluded.recv_msg_opt,
                is_pinned = excluded.is_pinned,
                is_private_chat = excluded.is_private_chat,
                burn_duration = excluded.burn_duration,
                group_at_type = excluded.group_at_type,
                is_not_in_group = excluded.is_not_in_group,
                update_unread_count_time = excluded.update_unread_count_time,
                attached_info = excluded.attached_info,
                ex = excluded.ex,
                draft_text = excluded.draft_text,
                draft_text_time = excluded.draft_text_time,
                max_seq = excluded.max_seq,
                min_seq = excluded.min_seq,
                is_msg_destruct = excluded.is_msg_destruct,
                msg_destruct_time = excluded.msg_destruct_time
        "#;

        sqlx::query(sql)
            .bind(&conv.conversation_id)
            .bind(conv.conversation_type)
            .bind(&conv.user_id)
            .bind(&conv.group_id)
            .bind(&conv.show_name)
            .bind(&conv.face_url)
            .bind(&conv.latest_msg)
            .bind(conv.latest_msg_send_time)
            .bind(conv.unread_count)
            .bind(conv.recv_msg_opt)
            .bind(if conv.is_pinned { 1 } else { 0 })
            .bind(if conv.is_private_chat { 1 } else { 0 })
            .bind(conv.burn_duration)
            .bind(conv.group_at_type)
            .bind(if conv.is_not_in_group { 1 } else { 0 })
            .bind(conv.update_unread_count_time)
            .bind(&conv.attached_info)
            .bind(&conv.ex)
            .bind(&conv.draft_text)
            .bind(conv.draft_text_time)
            .bind(conv.max_seq)
            .bind(conv.min_seq)
            .bind(if conv.is_msg_destruct { 1 } else { 0 })
            .bind(conv.msg_destruct_time)
            .execute(&self.db)
            .await
            .context("插入或更新会话失败")?;

        Ok(())
    }

    /// 从数据库删除会话
    pub async fn delete_conversation(&self, conversation_id: &str) -> Result<()> {
        sqlx::query(
            r#"
            DELETE FROM local_conversations WHERE conversation_id = ?
            "#,
        )
        .bind(conversation_id)
        .execute(&self.db)
        .await
        .context("删除会话失败")?;
        Ok(())
    }

    /// 获取总未读消息数
    pub async fn get_total_unread_count(&self) -> Result<i32> {
        let row: UnreadTotalRow = sqlx::query_as("SELECT SUM(unread_count) as total FROM local_conversations")
            .fetch_one(&self.db)
            .await
            .context("查询总未读数失败")?;
        Ok(row.total.unwrap_or(0) as i32)
    }
}

/// 版本同步 DAO（基于 sqlx）
#[derive(Clone)]
pub struct VersionSyncDao {
    db: Pool<Sqlite>,
    user_id: String,
}

impl VersionSyncDao {
    /// 创建新的版本同步 DAO
    pub fn new(db: Pool<Sqlite>, user_id: String) -> Self {
        Self { db, user_id }
    }

    /// 从数据库获取版本同步信息
    pub async fn get_version_sync(&self) -> Result<Option<LocalVersionSync>> {
        let row: Option<VersionSyncRow> = sqlx::query_as(
            "SELECT table_name, entity_id, version, version_id FROM local_version_sync WHERE table_name = 'local_conversations' AND entity_id = ?",
        )
        .bind(&self.user_id)
        .fetch_optional(&self.db)
        .await
        .context("查询版本同步信息失败")?;
        Ok(row.map(Into::into))
    }

    /// 保存版本同步信息到数据库
    pub async fn save_version_sync(&self, version_sync: &LocalVersionSync) -> Result<()> {
        let sql = r#"
            INSERT INTO local_version_sync (
                table_name, entity_id, version, version_id
            ) VALUES (?, ?, ?, ?)
            ON CONFLICT(table_name, entity_id) DO UPDATE SET
                version = excluded.version,
                version_id = excluded.version_id
        "#;

        sqlx::query(sql)
            .bind(&version_sync.table_name)
            .bind(&version_sync.entity_id)
            .bind(version_sync.version as i64)
            .bind(&version_sync.version_id)
            .execute(&self.db)
            .await
            .context("保存版本同步信息失败")?;
        Ok(())
    }
}
