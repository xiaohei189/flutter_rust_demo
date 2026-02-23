use crate::im::logger::logger::{init_logger as rust_init_logger, set_log_directory as rust_set_log_directory};

#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

/// 设置日志目录（应在 init_logger 前调用）。Dart 侧可用 path_provider 的 getTemporaryDirectory 等传入。
#[flutter_rust_bridge::frb(sync)]
pub fn set_log_directory(path: String) {
    rust_set_log_directory(path);
}

/// 初始化 Rust 日志，供 Dart 在 client 初始化时配置
#[flutter_rust_bridge::frb]
pub async fn init_logger(log_level: String) {
    rust_init_logger(&log_level);
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
