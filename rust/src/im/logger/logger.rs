use std::sync::Once;
use tracing_subscriber::prelude::*;
use tracing_subscriber::EnvFilter;

static INIT_LOGGER: Once = Once::new();

pub fn init_logger(log_level: &str) {
    INIT_LOGGER.call_once(|| {
        // 测试中默认打开当前 crate 和 sqlx 的 debug，关闭底层 HTTP 客户端的 debug 噪音
        let filter_layer = EnvFilter::new(log_level);

        let stdout_layer = tracing_subscriber::fmt::layer()
            .with_file(true) // 包含文件名
            .with_line_number(true) // 包含行号
            .with_target(false) // 不显示 target（可选，减少噪音）
            .with_ansi(true)
            .pretty()
            .with_test_writer();
        tracing_subscriber::registry().with(filter_layer).with(stdout_layer).init();
    });
}
