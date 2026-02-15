//! 好友数据访问层（DAO）
//!
//! 负责所有好友相关的数据库操作，将数据访问逻辑与业务逻辑分离。
//! 本模块已从 SeaORM 完全迁移到 sqlx。

use super::conversation::VersionSyncRow;
use crate::im::model::conversation::LocalVersionSync;
use anyhow::{Context, Result};
use openim_protocol::sdkws;
use sqlx::{FromRow, Pool, Sqlite};
use tracing::info;

/// 好友表行映射（DB 中 is_pinned 为 INTEGER 0/1）
#[derive(Debug, FromRow)]
struct LocalFriendRow {
    owner_user_id: String,
    friend_user_id: String,
    remark: String,
    create_time: i64,
    add_source: i32,
    operator_user_id: String,
    nickname: String,
    face_url: String,
    ex: String,
    attached_info: String,
    is_pinned: i64,
}

impl From<LocalFriendRow> for sdkws::FriendInfo {
    fn from(r: LocalFriendRow) -> Self {
        let ex = r.ex.clone();
        sdkws::FriendInfo {
            owner_user_id: r.owner_user_id,
            remark: r.remark,
            create_time: r.create_time,
            friend_user: Some(sdkws::UserInfo {
                user_id: r.friend_user_id,
                nickname: r.nickname,
                face_url: r.face_url,
                ex: r.ex,
                create_time: 0,
                app_manger_level: 0,
                global_recv_msg_opt: 0,
            }),
            add_source: r.add_source,
            operator_user_id: r.operator_user_id,
            ex,
            is_pinned: r.is_pinned != 0,
        }
    }
}

/// 好友 ID 查询结果
#[derive(FromRow)]
struct FriendIdRow {
    friend_user_id: String,
}

#[derive( Clone)]
pub struct FriendDao {
    db: Pool<Sqlite>,
    user_id: String,
}

impl FriendDao {
    /// 创建新的好友 DAO
    pub fn new(db: Pool<Sqlite>, user_id: String) -> Self {
        Self { db, user_id }
    }

    /// 初始化数据库表结构（表结构交由 sqlx migration 管理，这里仅保留兼容接口）
    pub async fn init_db(&self) -> Result<()> {
        info!("[FriendDAO/DB] init_db 已由 sqlx::migrate! 接管，无需额外建表");
        Ok(())
    }

    /// 从数据库获取所有好友
    pub async fn get_all_friends(&self) -> Result<Vec<sdkws::FriendInfo>> {
        let rows: Vec<LocalFriendRow> = sqlx::query_as(
            r#"
            SELECT
                owner_user_id,
                friend_user_id,
                remark,
                create_time,
                add_source,
                operator_user_id,
                nickname,
                face_url,
                ex,
                attached_info,
                is_pinned
            FROM local_friends
            WHERE owner_user_id = ?
            "#,
        )
        .bind(&self.user_id)
        .fetch_all(&self.db)
        .await
        .context("查询好友列表失败")?;

        Ok(rows.into_iter().map(Into::into).collect())
    }

    /// 与 Go batchGetUserNameAndFaceURL 对齐：按好友 user_id 查单条，用于补全会话 face/name
    pub async fn get_friend_by_friend_user_id(&self, friend_user_id: &str) -> Result<Option<sdkws::FriendInfo>> {
        let row: Option<LocalFriendRow> = sqlx::query_as(
            r#"
            SELECT owner_user_id, friend_user_id, remark, create_time, add_source, operator_user_id, nickname, face_url, ex, attached_info, is_pinned
            FROM local_friends WHERE owner_user_id = ? AND friend_user_id = ? LIMIT 1
            "#,
        )
        .bind(&self.user_id)
        .bind(friend_user_id)
        .fetch_optional(&self.db)
        .await
        .context("查询好友失败")?;
        Ok(row.map(Into::into))
    }

    /// 获取本地所有好友的 userID 列表
    pub async fn get_all_friend_ids(&self) -> Result<Vec<String>> {
        let rows: Vec<FriendIdRow> = sqlx::query_as(
            "SELECT friend_user_id FROM local_friends WHERE owner_user_id = ?",
        )
        .bind(&self.user_id)
        .fetch_all(&self.db)
        .await
        .context("查询好友ID列表失败")?;

        Ok(rows.into_iter().map(|r| r.friend_user_id).collect())
    }

    /// 与 Go GetVersionSync 一致：按 table_name + entity_id 查询（此处为 local_friends + user_id）
    pub async fn get_version_sync(&self) -> Result<Option<LocalVersionSync>> {
        const TABLE: &str = "local_sync_version";
        let row: Option<VersionSyncRow> = sqlx::query_as(&format!(
            "SELECT table_name, entity_id, version, version_id FROM {} WHERE table_name = 'local_friends' AND entity_id = ?",
            TABLE
        ))
        .bind(&self.user_id)
        .fetch_optional(&self.db)
        .await
        .context("查询好友版本同步信息失败")?;
        info!(user_id = self.user_id.clone(), "[FriendDAO] 查询好友版本同步信息");
        Ok(row.map(Into::into))
    }

    /// 与 Go SetVersionSync 一致：有则更新，无则插入
    pub async fn save_version_sync(&self, version_sync: &LocalVersionSync) -> Result<()> {
        const TABLE: &str = "local_sync_version";
        let sql = format!(
            r#"INSERT INTO {} (table_name, entity_id, version, version_id) VALUES (?, ?, ?, ?)
            ON CONFLICT(table_name, entity_id) DO UPDATE SET version = excluded.version, version_id = excluded.version_id"#,
            TABLE
        );
        sqlx::query(&sql)
            .bind(&version_sync.table_name)
            .bind(&version_sync.entity_id)
            .bind(version_sync.version as i64)
            .bind(&version_sync.version_id)
            .execute(&self.db)
            .await
            .context("保存好友版本同步信息失败")?;
        Ok(())
    }

    /// 插入或更新好友到数据库
    pub async fn upsert_friend(&self, f: &sdkws::FriendInfo) -> Result<()> {
        let friend_user_id = f.friend_user.as_ref().map(|u| u.user_id.as_str()).unwrap_or("");
        let nickname = f.friend_user.as_ref().map(|u| u.nickname.as_str()).unwrap_or("");
        let face_url = f.friend_user.as_ref().map(|u| u.face_url.as_str()).unwrap_or("");

        let sql = r#"
            INSERT INTO local_friends (
                owner_user_id,
                friend_user_id,
                remark,
                create_time,
                add_source,
                operator_user_id,
                nickname,
                face_url,
                ex,
                attached_info,
                is_pinned
            ) VALUES (
                ?,?,?,?,?,?,?,?,?,?,?
            )
            ON CONFLICT(owner_user_id, friend_user_id) DO UPDATE SET
                remark = excluded.remark,
                create_time = excluded.create_time,
                add_source = excluded.add_source,
                operator_user_id = excluded.operator_user_id,
                nickname = excluded.nickname,
                face_url = excluded.face_url,
                ex = excluded.ex,
                attached_info = excluded.attached_info,
                is_pinned = excluded.is_pinned
        "#;

        sqlx::query(sql)
            .bind(&f.owner_user_id)
            .bind(friend_user_id)
            .bind(&f.remark)
            .bind(f.create_time)
            .bind(f.add_source)
            .bind(&f.operator_user_id)
            .bind(nickname)
            .bind(face_url)
            .bind(&f.ex)
            .bind("") // attached_info 字段在 FriendInfo 中不存在，使用空字符串
            .bind(if f.is_pinned { 1 } else { 0 })
            .execute(&self.db)
            .await
            .context("插入或更新好友失败")?;
        Ok(())
    }

    /// 从数据库删除好友
    pub async fn delete_friend(&self, friend_user_id: &str) -> Result<()> {
        sqlx::query(
            r#"
            DELETE FROM local_friends
            WHERE owner_user_id = ? AND friend_user_id = ?
            "#,
        )
        .bind(&self.user_id)
        .bind(friend_user_id)
        .execute(&self.db)
        .await
        .context("删除好友失败")?;
        Ok(())
    }
}
