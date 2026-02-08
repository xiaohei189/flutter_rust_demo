use std::fs::File;
use std::io::{self, Write};
use std::sync::Once;
use tracing_subscriber::fmt::format::Writer;
use tracing_subscriber::fmt::time::FormatTime;
use tracing_subscriber::prelude::*;
use tracing_subscriber::EnvFilter;

static INIT_LOGGER: Once = Once::new();

/// 当前项目目录下的日志文件名
const LOG_FILE_NAME: &str = "rust.log";

/// 中国时区 (UTC+8) 时间格式，精度到微秒
struct ChinaTime;

impl FormatTime for ChinaTime {
    fn format_time(&self, w: &mut Writer<'_>) -> std::fmt::Result {
        let now = chrono::Utc::now();
        let china = chrono::FixedOffset::east_opt(8 * 3600).unwrap();
        let t = now.with_timezone(&china);
        write!(w, "{}", t.format("%Y-%m-%d %H:%M:%S%.6f"))
    }
}

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
        let timer = ChinaTime;

        let log_path = std::env::current_dir()
            .unwrap_or_else(|_| std::env::temp_dir())
            .join(LOG_FILE_NAME);
        let _ = std::fs::remove_file(&log_path);

        // 控制台：stdout + 中国时区 + 每次 flush
        let console_layer = tracing_subscriber::fmt::layer()
            .with_timer(timer)
            .with_file(true)
            .with_line_number(true)
            .with_target(false)
            .with_ansi(true)
            .pretty()
            .with_writer(|| FlushWriter(io::stdout()));

        let registry = tracing_subscriber::registry()
            .with(filter_layer)
            .with(console_layer);

        match File::create(&log_path) {
            Ok(file) => {
                let file_layer = tracing_subscriber::fmt::layer()
                    .with_timer(ChinaTime)
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
