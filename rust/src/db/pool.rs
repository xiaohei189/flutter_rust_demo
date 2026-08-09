use crate::error::{Result, SdkError};
use sqlx::sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePool, SqlitePoolOptions, SqliteSynchronous};
use sqlx::ConnectOptions;
use std::str::FromStr;
use std::time::Duration;

pub async fn create_pool(db_url: &str) -> Result<SqlitePool> {
    let options = SqliteConnectOptions::from_str(db_url)
        .map_err(|e| SdkError::database(format!("invalid db_url: {}", e)))?
        .create_if_missing(true)
        .journal_mode(SqliteJournalMode::Wal)
        .synchronous(SqliteSynchronous::Normal)
        .busy_timeout(Duration::from_secs(5))
        // 默认不输出每条 SQL，避免发送/同步时刷屏；慢 SQL 仍按 Info 告警
        .log_statements(tracing::log::LevelFilter::Trace)
        .log_slow_statements(tracing::log::LevelFilter::Info, Duration::from_millis(100));

    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect_with(options)
        .await
        .map_err(|e| SdkError::database(format!("connect failed: {}", e)))?;

    sqlx::migrate!().run(&pool).await.map_err(|e| SdkError::database(format!("migration failed: {}", e)))?;

    Ok(pool)
}

pub async fn create_pool_memory() -> Result<SqlitePool> {
    let pool = SqlitePoolOptions::new()
        .max_connections(1)
        .connect("sqlite::memory:")
        .await
        .map_err(|e| SdkError::database(format!("connect failed: {}", e)))?;

    sqlx::migrate!().run(&pool).await.map_err(|e| SdkError::database(format!("migration failed: {}", e)))?;

    Ok(pool)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_pool_memory() {
        let pool = create_pool_memory().await;
        assert!(pool.is_ok());
    }
}
