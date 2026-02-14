//! 本地 App/SDK 版本表 DAO（与 Go pkg/db/app_version.go 对齐）
//!
//! 表名：local_app_sdk_version
//! 用途：记录当前 SDK 版本及是否已完成“重装同步”（Installed），供消息同步器判断 reinstalled。

use anyhow::Result;
use sqlx::{FromRow, Pool, Sqlite};

/// 与 Go model_struct.LocalAppSDKVersion 一致
#[derive(Debug, Clone, FromRow)]
pub struct LocalAppSDKVersion {
    /// 当前 SDK 版本，如 "3.8.0"
    pub version: String,
    /// 是否已完成重装后的全量/同步加载
    pub installed: bool,
}

/// SQLite 行映射：installed 存为 INTEGER 0/1
#[derive(Debug, FromRow)]
struct LocalAppSDKVersionRow {
    version: String,
    installed: i32,
}

impl From<LocalAppSDKVersionRow> for LocalAppSDKVersion {
    fn from(r: LocalAppSDKVersionRow) -> Self {
        Self {
            version: r.version,
            installed: r.installed != 0,
        }
    }
}

/// 本地 App SDK 版本 DAO
#[derive(Clone)]
pub struct AppVersionDao {
    pool: Pool<Sqlite>,
}

const TABLE_NAME: &str = "local_app_sdk_version";

impl AppVersionDao {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self { pool }
    }

    /// 获取当前记录的 SDK 版本（表中通常只有一行，取第一条）
    /// 与 Go GetAppSDKVersion 一致，无记录时返回 None。
    pub async fn get_app_sdk_version(&self) -> Result<Option<LocalAppSDKVersion>> {
        let row: Option<LocalAppSDKVersionRow> = sqlx::query_as(&format!(
            "SELECT version, installed FROM {} LIMIT 1",
            TABLE_NAME
        ))
        .fetch_optional(&self.pool)
        .await?;
        Ok(row.map(LocalAppSDKVersion::from))
    }

    /// 设置 SDK 版本记录（有则更新，无则插入）
    /// 与 Go SetAppSDKVersion(ctx, appVersion *LocalAppSDKVersion) 一致，单参数。
    /// 更新时：若 app_version.version 为空则只更新 installed（对齐 Go GORM 零值忽略）。
    pub async fn set_app_sdk_version(&self, app_version: &LocalAppSDKVersion) -> Result<()> {
        let existing = self.get_app_sdk_version().await?;
        match existing {
            None => {
                let version = if app_version.version.is_empty() { "0" } else { app_version.version.as_str() };
                sqlx::query(&format!(
                    "INSERT INTO {} (version, installed) VALUES (?, ?)",
                    TABLE_NAME
                ))
                .bind(version)
                .bind(if app_version.installed { 1 } else { 0 })
                .execute(&self.pool)
                .await?;
            }
            Some(cur) => {
                let old_version = cur.version.clone();
                let version = if app_version.version.is_empty() {
                    old_version.clone()
                } else {
                    app_version.version.clone()
                };
                sqlx::query(&format!(
                    "UPDATE {} SET version = ?, installed = ? WHERE version = ?",
                    TABLE_NAME
                ))
                .bind(&version)
                .bind(if app_version.installed { 1 } else { 0 })
                .bind(&old_version)
                .execute(&self.pool)
                .await?;
            }
        }
        Ok(())
    }
}
