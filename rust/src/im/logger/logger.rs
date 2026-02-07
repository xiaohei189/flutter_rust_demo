use std::fs::File;
use std::sync::Once;
use tracing_subscriber::prelude::*;
use tracing_subscriber::EnvFilter;

static INIT_LOGGER: Once = Once::new();

/// 当前项目目录下的日志文件名
const LOG_FILE_NAME: &str = "rust.log";

pub fn init_logger(log_level: &str) {
    INIT_LOGGER.call_once(|| {
        let filter_layer = EnvFilter::new(log_level);

        // 项目目录：当前工作目录，失败时 fallback 到临时目录
        let log_path = std::env::current_dir()
            .unwrap_or_else(|_| std::env::temp_dir())
            .join(LOG_FILE_NAME);

        // 删除之前的日志文件，本次运行重新写入
        let _ = std::fs::remove_file(&log_path);

        // 控制台：带文件名、行号，测试时用 test_writer 便于断言
        let stdout_layer = tracing_subscriber::fmt::layer()
            .with_file(true)
            .with_line_number(true)
            .with_target(false)
            .with_ansi(true)
            .pretty()
            .with_test_writer();

        let registry = tracing_subscriber::registry().with(filter_layer).with(stdout_layer);

        match File::create(&log_path) {
            Ok(file) => {
                // 文件：同样格式，不启用 ansi 颜色
                let file_layer = tracing_subscriber::fmt::layer()
                    .with_file(true)
                    .with_line_number(true)
                    .with_target(false)
                    .with_ansi(false)
                    .pretty()
                    .with_writer(file);
                registry.with(file_layer).init();
            }
            Err(e) => {
                eprintln!("[logger] 无法创建日志文件 {}: {}", log_path.display(), e);
                registry.init();
            }
        }
    });
}
