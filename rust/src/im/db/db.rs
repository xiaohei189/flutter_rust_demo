//! SQLite 数据库工具
//!
//! 迁移与脚本执行已集中到 `im::dao`：请使用 `Repository::create(db_url).await` 创建仓库（内部会立即执行迁移），
//! 或使用 `dao::create_pool_and_migrate(db_url).await` 仅建池并执行迁移。

pub use crate::im::dao::create_pool_and_migrate as create_sqlite_pool_with_migration;
