//! 向后兼容层 — 委托给 ffi_init
//!
//! frb_generated 自动生成的代码通过 crate::api::simple:: 路径访问日志初始化函数。
//! 此文件保持向后兼容，所有实现委托给 fi_init 模块。
//! 运行 lutter_rust_bridge_codegen generate 重新生成后可删除此文件。

pub use super::ffi_init::*;
