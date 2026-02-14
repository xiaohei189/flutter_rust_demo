//! 本地用户表 DAO（与 Go pkg/db/user_model.go 对齐）
//!
//! 表名：local_users
//! 用途：存储用户信息，含当前登录用户；GetLoginUser / InsertLoginUser / UpdateLoginUser。

use anyhow::Result;
use sqlx::{FromRow, Pool, Sqlite};

/// 与 Go model_struct.LocalUser 一致（列 name 对应 Nickname）
#[derive(Debug, Clone, FromRow)]
pub struct LocalUser {
    pub user_id: String,
    #[sqlx(rename = "name")]
    pub nickname: String,
    pub face_url: String,
    pub create_time: i64,
    pub app_manger_level: i32,
    pub ex: String,
    pub attached_info: String,
    pub global_recv_msg_opt: i32,
}

const TABLE_NAME: &str = "local_users";

/// 本地用户 DAO
#[derive(Clone)]
pub struct UserDao {
    pool: Pool<Sqlite>,
}

impl UserDao {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self { pool }
    }

    /// 与 Go GetLoginUser 一致：按 user_id 查询
    pub async fn get_login_user(&self, user_id: &str) -> Result<Option<LocalUser>> {
        let row = sqlx::query_as::<_, LocalUser>(&format!(
            "SELECT user_id, name, face_url, create_time, app_manger_level, ex, attached_info, global_recv_msg_opt FROM {} WHERE user_id = ? LIMIT 1",
            TABLE_NAME
        ))
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?;
        Ok(row)
    }

    /// 与 Go UpdateLoginUser 一致：按 user 主键更新整行
    pub async fn update_login_user(&self, user: &LocalUser) -> Result<()> {
        let rows = sqlx::query(&format!(
            "UPDATE {} SET name = ?, face_url = ?, create_time = ?, app_manger_level = ?, ex = ?, attached_info = ?, global_recv_msg_opt = ? WHERE user_id = ?",
            TABLE_NAME
        ))
        .bind(&user.nickname)
        .bind(&user.face_url)
        .bind(user.create_time)
        .bind(user.app_manger_level)
        .bind(&user.ex)
        .bind(&user.attached_info)
        .bind(user.global_recv_msg_opt)
        .bind(&user.user_id)
        .execute(&self.pool)
        .await?
        .rows_affected();
        if rows == 0 {
            anyhow::bail!("UpdateLoginUser: no row updated");
        }
        Ok(())
    }

    /// 与 Go UpdateLoginUserByMap 一致：按 user_id 更新指定字段（args 为列名 -> 值）
    pub async fn update_login_user_by_map(
        &self,
        user_id: &str,
        args: &[(String, String)],
    ) -> Result<()> {
        if args.is_empty() {
            return Ok(());
        }
        let mut set_clauses = Vec::with_capacity(args.len());
        for (k, _) in args {
            set_clauses.push(format!("{} = ?", k));
        }
        let sql = format!(
            "UPDATE {} SET {} WHERE user_id = ?",
            TABLE_NAME,
            set_clauses.join(", ")
        );
        let mut q = sqlx::query(&sql);
        for (_, v) in args {
            q = q.bind(v);
        }
        q = q.bind(user_id);
        let rows = q.execute(&self.pool).await?.rows_affected();
        if rows == 0 {
            anyhow::bail!("UpdateLoginUserByMap: no row updated");
        }
        Ok(())
    }

    /// 与 Go InsertLoginUser 一致：插入一条用户
    pub async fn insert_login_user(&self, user: &LocalUser) -> Result<()> {
        sqlx::query(&format!(
            "INSERT INTO {} (user_id, name, face_url, create_time, app_manger_level, ex, attached_info, global_recv_msg_opt) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            TABLE_NAME
        ))
        .bind(&user.user_id)
        .bind(&user.nickname)
        .bind(&user.face_url)
        .bind(user.create_time)
        .bind(user.app_manger_level)
        .bind(&user.ex)
        .bind(&user.attached_info)
        .bind(user.global_recv_msg_opt)
        .execute(&self.pool)
        .await?;
        Ok(())
    }
}
