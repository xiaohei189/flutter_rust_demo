//! API 桥接层：FFI 适配，供 flutter_rust_bridge 调用。
//! 当前 re-export `ffi`；迁移完成后只保留对外 FFI 函数。

pub use crate::ffi;
