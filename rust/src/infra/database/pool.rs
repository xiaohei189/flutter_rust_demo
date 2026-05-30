use crate::domain::error::types::{Result, SdkError};
use sqlx::sqlite::{SqliteConnectOptions, SqlitePool, SqlitePoolOptions};
use std::str::FromStr;

pub async fn create_pool(db_url: &str) -> Result<SqlitePool> {
    let options = SqliteConnectOptions::from_str(db_url)
        .map_err(|e| SdkError::database(format!("invalid db_url: {}", e)))?
        .create_if_missing(true);

    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect_with(options)
        .await
        .map_err(|e| SdkError::database(format!("connect failed: {}", e)))?;

    sqlx::migrate!()
        .run(&pool)
        .await
        .map_err(|e| SdkError::database(format!("migration failed: {}", e)))?;

    Ok(pool)
}

pub async fn create_pool_memory() -> Result<SqlitePool> {
    let pool = SqlitePoolOptions::new()
        .max_connections(1)
        .connect("sqlite::memory:")
        .await
        .map_err(|e| SdkError::database(format!("connect failed: {}", e)))?;

    sqlx::migrate!()
        .run(&pool)
        .await
        .map_err(|e| SdkError::database(format!("migration failed: {}", e)))?;

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
