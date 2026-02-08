use std::fmt;
use std::fs::File;
use std::io::{self, Write};
use std::sync::Once;
use tracing_core::{Event, Subscriber};
use tracing_subscriber::fmt::format::{FormatEvent, Writer};
use tracing_subscriber::fmt::FmtContext;
use tracing_subscriber::prelude::*;
use tracing_subscriber::registry::LookupSpan;
use tracing_subscriber::EnvFilter;

static INIT_LOGGER: Once = Once::new();

/// 包装原有 Format，在每行日志前输出从根到当前的 span_id 链（含父 span id），便于串联整条处理链
struct WithSpanId<F>(F);

impl<S, N, F> FormatEvent<S, N> for WithSpanId<F>
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> tracing_subscriber::fmt::format::FormatFields<'a> + 'static,
    F: FormatEvent<S, N>,
{
    fn format_event(
        &self,
        ctx: &FmtContext<'_, S, N>,
        mut writer: Writer<'_>,
        event: &Event<'_>,
    ) -> fmt::Result {
        if let Some(scope) = ctx.event_scope() {
            let ids: Vec<u64> = scope.from_root().map(|s| s.id().into_u64()).collect();
            if !ids.is_empty() {
                // 从根到当前：第一个为根 span_id，最后一个为当前 span_id，中间为各层父 span_id
                let ids_str = ids.iter().map(|n| n.to_string()).collect::<Vec<_>>().join(":");
                write!(writer, "span_ids={} ", ids_str)?;
            }
        }
        self.0.format_event(ctx, writer, event)
    }
}

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

        // 控制台：带 span_id 的 pretty 输出，便于按 span 串联整条处理链
        let console_fmt = WithSpanId(
            tracing_subscriber::fmt::format()
                .with_file(true)
                .with_line_number(true)
                .with_target(true)
                .with_thread_ids(true)
                .with_thread_names(true)
                .pretty(),
        );
        let fmt_layer = tracing_subscriber::fmt::layer()
            .event_format(console_fmt)
            .with_writer(|| FlushWriter(io::stdout()));

        #[cfg(tokio_unstable)]
        {
            let console_layer = console_subscriber::spawn();
            let registry = tracing_subscriber::registry()
                .with(filter_layer)
                .with(console_layer)
                .with(fmt_layer);
            match File::create(&log_path) {
                Ok(file) => {
                    let file_fmt = WithSpanId(
                        tracing_subscriber::fmt::format()
                            .with_file(true)
                            .with_line_number(true)
                            .with_target(true)
                            .with_thread_ids(true)
                            .with_thread_names(true)
                            .with_ansi(false)
                            .pretty(),
                    );
                    let file_layer = tracing_subscriber::fmt::layer()
                        .event_format(file_fmt)
                        .with_writer(file);
                    registry.with(file_layer).init();
                }
                Err(e) => {
                    eprintln!("[logger] 无法创建日志文件 {}: {}", log_path.display(), e);
                    registry.init();
                }
            }
        }

        #[cfg(not(tokio_unstable))]
        {
            let registry = tracing_subscriber::registry()
                .with(filter_layer)
                .with(fmt_layer);
            match File::create(&log_path) {
                Ok(file) => {
                    let file_fmt = WithSpanId(
                        tracing_subscriber::fmt::format()
                            .with_file(true)
                            .with_line_number(true)
                            .with_target(true)
                            .with_thread_ids(true)
                            .with_thread_names(true)
                            .with_ansi(false)
                            .pretty(),
                    );
                    let file_layer = tracing_subscriber::fmt::layer()
                        .event_format(file_fmt)
                        .with_writer(file);
                    registry.with(file_layer).init();
                }
                Err(e) => {
                    eprintln!("[logger] 无法创建日志文件 {}: {}", log_path.display(), e);
                    registry.init();
                }
            }
        }
    });
}
