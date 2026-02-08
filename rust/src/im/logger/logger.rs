use std::fs::File;
use std::io::{self, Write};
use std::sync::Once;
use tracing_subscriber::prelude::*;
use tracing_subscriber::EnvFilter;

static INIT_LOGGER: Once = Once::new();

/// 当前项目目录下的日志文件名
const LOG_FILE_NAME: &str = "rust.log";

/// 每次 write 后立即 flush，确保控制台 / Debug Console 能看到输出
struct FlushWriter<W: Write>(W);

impl<W: Write> Write for FlushWriter<W> {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        let n = self.0.write(buf)?;
        self.0.flush()?;
        Ok(n)
    }
    fn flush(&mut self) -> io::Result<()> {
        self.0.flush()
    }
}

pub fn init_logger(log_level: &str) {
    INIT_LOGGER.call_once(|| {
        let filter_layer = EnvFilter::new(log_level);

        let log_path = std::env::current_dir()
            .unwrap_or_else(|_| std::env::temp_dir())
            .join(LOG_FILE_NAME);
        let _ = std::fs::remove_file(&log_path);

        // 控制台：JSON 结构化输出，便于解析与日志采集
        let console_layer = tracing_subscriber::fmt::layer()
            .with_file(true)
            .with_line_number(true)
            .with_target(true)
            .with_thread_ids(true)
            .with_thread_names(true)
            .pretty() // 自动层级 + 彩色
            .with_writer(|| FlushWriter(io::stdout()));

        let registry = tracing_subscriber::registry()
            .with(filter_layer)
            .with(console_layer);

        match File::create(&log_path) {
            Ok(file) => {
                let file_layer = tracing_subscriber::fmt::layer()
                    .with_file(true)
                    .with_line_number(true)
                    .with_target(true)
                    .with_thread_ids(true)
                    .with_thread_names(true)
                    .with_ansi(false)
                    .pretty() // 自动层级 + 彩色
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
