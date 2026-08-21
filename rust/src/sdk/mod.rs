//! SDK 外观层：客户端入口与好友/群组等高阶服务。
//! 当前 re-export 扁平模块；逐步把 `client/ friend/ group/` 迁移到本目录。

pub use crate::{client, friend, group};
