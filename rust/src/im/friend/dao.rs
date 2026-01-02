//! 好友数据访问层（DAO）
//!
//! 负责所有好友相关的数据库操作，将数据访问逻辑与业务逻辑分离。
//! 本模块已从 SeaORM 完全迁移到 sqlx。

use crate::im::conversation::models::LocalVersionSync;
use anyhow::{Context, Result};
use openim_protocol::sdkws;
use sqlx::{Pool, Row, Sqlite};
use tracing::{debug, info};

/// 好友 DAO（基于 sqlx）
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
        let rows = sqlx::query(
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

        let friends: Vec<sdkws::FriendInfo> = rows
            .into_iter()
            .map(|m| {
                let is_pinned: i64 = m.get("is_pinned");
                sdkws::FriendInfo {
                    owner_user_id: m.get("owner_user_id"),
                    remark: m.get("remark"),
                    create_time: m.get("create_time"),
                    friend_user: Some(sdkws::UserInfo {
                        user_id: m.get("friend_user_id"),
                        nickname: m.get("nickname"),
                        face_url: m.get("face_url"),
                        ex: m.get("ex"),
                        create_time: 0,
                        app_manger_level: 0,
                        global_recv_msg_opt: 0,
                    }),
                    add_source: m.get("add_source"),
                    operator_user_id: m.get("operator_user_id"),
                    ex: m.get("ex"),
                    is_pinned: is_pinned != 0,
                }
            })
            .collect();
        Ok(friends)
    }

    /// 获取本地所有好友的 userID 列表
    pub async fn get_all_friend_ids(&self) -> Result<Vec<String>> {
        let rows = sqlx::query(
            r#"
            SELECT friend_user_id FROM local_friends WHERE owner_user_id = ?
            "#,
        )
        .bind(&self.user_id)
        .fetch_all(&self.db)
        .await
        .context("查询好友ID列表失败")?;

        let ids = rows
            .into_iter()
            .map(|m| m.get::<String, _>("friend_user_id"))
            .collect::<Vec<_>>();
        Ok(ids)
    }

    /// 从数据库获取版本同步信息（tableName = local_friends）
    pub async fn get_version_sync(&self) -> Result<Option<LocalVersionSync>> {
        let row = sqlx::query(
            r#"
            SELECT table_name, entity_id, version, version_id
            FROM local_version_sync
            WHERE table_name = 'local_friends' AND entity_id = ?
            "#,
        )
        .bind(&self.user_id)
        .fetch_optional(&self.db)
        .await
        .context("查询好友版本同步信息失败")?;
        info!(user_id = self.user_id.clone(), "[FriendDAO] 查询好友版本同步信息");
        Ok(row.map(|m| LocalVersionSync {
            table_name: m.get("table_name"),
            entity_id: m.get("entity_id"),
            version: m.get::<i64, _>("version") as u64,
            version_id: m.get("version_id"),
        }))
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
            .context("保存好友版本同步信息失败")?;
        Ok(())
    }

    /// 插入或更新好友到数据库
    pub async fn upsert_friend(&self, f: &sdkws::FriendInfo) -> Result<()> {
        let friend_user_id = f
            .friend_user
            .as_ref()
            .map(|u| u.user_id.as_str())
            .unwrap_or("");
        let nickname = f
            .friend_user
            .as_ref()
            .map(|u| u.nickname.as_str())
            .unwrap_or("");
        let face_url = f
            .friend_user
            .as_ref()
            .map(|u| u.face_url.as_str())
            .unwrap_or("");

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


