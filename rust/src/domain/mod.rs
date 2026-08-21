//! 领域层：数据模型、枚举、错误、常量。
//! 当前 re-export 扁平模块；逐步把 `model/ constant/ error/` 迁移到本目录。

pub use crate::{constant, error, model};
