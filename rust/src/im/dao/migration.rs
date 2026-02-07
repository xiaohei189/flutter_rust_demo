//! 迁移与脚本执行：集中在此模块，由 Repository 创建时触发。
//!
//! 约定：crate 根目录下 `migrations/` 存放所有迁移 SQL，通过 `sqlx::migrate!()` 管理 schema 升级。

use anyhow::{Context, Result};
use sqlx::{sqlite::SqlitePoolOptions, Pool, Sqlite};
use tracing::info;

/// 对已有连接池执行所有未执行的迁移（升级脚本）
pub async fn run_migrations(pool: &Pool<Sqlite>) -> Result<()> {
    match sqlx::migrate!().run(pool).await {
        Ok(_) => Ok(()),
        Err(e) => {
            let error_msg = e.to_string();
            if error_msg.contains("was previously applied but has been modified") {
                tracing::warn!("检测到 migration 文件被修改，将删除旧的 migration 记录并重新应用");
                sqlx::query("DELETE FROM _sqlx_migrations")
                    .execute(pool)
                    .await
                    .context("删除 migration 记录失败")?;
                sqlx::migrate!().run(pool).await?;
                Ok(())
            } else {
                Err(e.into())
            }
        }
    }
}

/// 创建 SQLite 连接池并立即执行迁移（供 Repository::create 或需要单独建池时使用）
pub async fn create_pool_and_migrate(db_url: &str) -> Result<Pool<Sqlite>> {
    info!("[DAO] 创建 SQLite 连接池并执行迁移: {}", db_url);
    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect(db_url)
        .await?;
    run_migrations(&pool).await?;
    Ok(pool)
}
