//! SQLite 数据库工具：统一创建连接池并执行 sqlx 迁移
//!
//! 约定：本 crate 根目录下存在 `migrations/` 目录，存放所有迁移 SQL 文件。
//! 通过 `sqlx::migrate!()` 自动管理 schema 升级。

use anyhow::{Context, Result};
use sqlx::{sqlite::SqlitePoolOptions, Pool, Sqlite};

/// 创建 SQLite 连接池并执行所有未执行的迁移
pub async fn create_sqlite_pool_with_migration(db_url: &str) -> Result<Pool<Sqlite>> {
    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect(db_url)
        .await?;

    // 从 `rust/migrations/` 目录读取迁移并执行
    match sqlx::migrate!().run(&pool).await {
        Ok(_) => {}
        Err(e) => {
            // 如果 migration 被修改了，删除旧的 migration 记录并重试
            let error_msg = e.to_string();
            if error_msg.contains("was previously applied but has been modified") {
                log::warn!("检测到 migration 文件被修改，将删除旧的 migration 记录并重新应用");

                // 删除所有 migration 记录
                sqlx::query("DELETE FROM _sqlx_migrations")
                    .execute(&pool)
                    .await
                    .context("删除 migration 记录失败")?;

                // 重新运行 migration
                sqlx::migrate!().run(&pool).await?;
            } else {
                return Err(e.into());
            }
        }
    }

    Ok(pool)
}
