use crate::im::logger::logger::init_logger as rust_init_logger;

#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

/// 初始化 Rust 日志，供 Dart 在应用启动时配置
#[flutter_rust_bridge::frb(sync)]
pub fn init_logger(log_level: String) {
    rust_init_logger(&log_level);
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
