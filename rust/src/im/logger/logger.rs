//! Trace 导出参考：<https://github.com/tokio-rs/tracing-opentelemetry/tree/v0.1.x/examples>
//! 特别是 opentelemetry-otlp.rs：OtelGuard + shutdown、Resource、Sampler。
//! 日志文件接入 <https://crates.io/crates/tracing-appender>：rolling + non_blocking。
//! Android 下控制台输出通过 android_log-sys 写入 logcat。

#[cfg(target_os = "android")]
mod android_log {
    use std::ffi::CString;
    use std::io::{self, Write};
    use std::sync::{Arc, Mutex};

    use android_log_sys::{__android_log_write, LogPriority};
    use tracing_subscriber::fmt::MakeWriter;

    const LOG_TAG: &str = "Rust";

    /// 根据日志行开头的 level 文本推断 Android 优先级（格式中 level 在时间戳后）
    fn priority_from_line(line: &str) -> i32 {
        let rest = line.trim_start();
        if rest.starts_with("ERROR") {
            LogPriority::ERROR as i32
        } else if rest.starts_with("WARN") {
            LogPriority::WARN as i32
        } else if rest.starts_with("INFO") {
            LogPriority::INFO as i32
        } else if rest.starts_with("DEBUG") {
            LogPriority::DEBUG as i32
        } else if rest.starts_with("TRACE") {
            LogPriority::VERBOSE as i32
        } else {
            LogPriority::INFO as i32
        }
    }

    /// 实现 io::Write，将内容按行写入 Android logcat（__android_log_write）
    struct AndroidLogWriterInner {
        buffer: Vec<u8>,
    }

    impl AndroidLogWriterInner {
        fn new() -> Self {
            Self { buffer: Vec::new() }
        }

        fn flush_line(&mut self, line: &[u8]) {
            if line.is_empty() {
                return;
            }
            let Ok(s) = std::str::from_utf8(line) else { return };
            let s = s.trim_end_matches(|c| c == '\r' || c == '\n');
            if s.is_empty() {
                return;
            }
            if let (Ok(tag), Ok(msg)) = (CString::new(LOG_TAG), CString::new(s)) {
                let prio = priority_from_line(s);
                unsafe {
                    __android_log_write(prio, tag.as_ptr(), msg.as_ptr());
                }
            }
        }
    }

    impl Write for AndroidLogWriterInner {
        fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
            let mut start = 0;
            for (i, &b) in buf.iter().enumerate() {
                if b == b'\n' {
                    self.buffer.extend_from_slice(&buf[start..=i]);
                    let line = std::mem::take(&mut self.buffer);
                    self.flush_line(&line);
                    start = i + 1;
                }
            }
            self.buffer.extend_from_slice(&buf[start..]);
            Ok(buf.len())
        }

        fn flush(&mut self) -> io::Result<()> {
            if !self.buffer.is_empty() {
                let line = std::mem::take(&mut self.buffer);
                self.flush_line(&line);
            }
            Ok(())
        }
    }

    /// 供 MakeWriter 使用的 Writer 句柄（持有一个 Arc 引用，Write 时加锁写入）
    pub struct AndroidLogWriterHandle(pub Arc<Mutex<AndroidLogWriterInner>>);

    impl Write for AndroidLogWriterHandle {
        fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
            self.0
                .lock()
                .map_err(|_| io::ErrorKind::Other.into())
                .and_then(|mut w| w.write(buf))
        }
        fn flush(&mut self) -> io::Result<()> {
            self.0
                .lock()
                .map_err(|_| io::ErrorKind::Other.into())
                .and_then(|mut w| w.flush())
        }
    }

    /// 实现 MakeWriter，供 tracing_subscriber::fmt::layer().with_writer() 在 Android 上使用
    pub struct AndroidLogMakeWriter(pub Arc<Mutex<AndroidLogWriterInner>>);

    impl AndroidLogMakeWriter {
        pub fn new() -> Self {
            Self(Arc::new(Mutex::new(AndroidLogWriterInner::new())))
        }
    }

    impl Default for AndroidLogMakeWriter {
        fn default() -> Self {
            Self::new()
        }
    }

    impl<'a> MakeWriter<'a> for AndroidLogMakeWriter {
        type Writer = AndroidLogWriterHandle;

        fn make_writer(&'a self) -> Self::Writer {
            AndroidLogWriterHandle(Arc::clone(&self.0))
        }
    }
}

use opentelemetry::trace::{TraceContextExt, TracerProvider};
use opentelemetry::KeyValue;
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::error::OTelSdkResult;
use opentelemetry_sdk::trace::{Sampler, SdkTracerProvider};
use opentelemetry_sdk::trace::{SpanData, SpanExporter as OtelSpanExporter};
use opentelemetry_sdk::Resource;
use std::fmt;
use std::io;
use std::sync::{Once, OnceLock};
use tracing_appender::non_blocking::WorkerGuard;
use tracing_appender::rolling::{RollingFileAppender, Rotation};
use tracing_core::{Event, Subscriber};
use tracing_opentelemetry::OpenTelemetryLayer;
use tracing_subscriber::fmt::format::{FormatEvent, FormatFields, Writer};
use tracing_subscriber::fmt::{FmtContext, FormattedFields};
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::prelude::*;
use tracing_subscriber::registry::LookupSpan;
use tracing_subscriber::EnvFilter;

static INIT_LOGGER: Once = Once::new();

/// 由 Dart 传入的日志目录（path_provider），在 init_logger 前设置；Android 上设置后才会写文件日志
static LOG_DIR_OVERRIDE: OnceLock<String> = OnceLock::new();

/// 保存 TracerProvider，以便程序退出前可 force_flush，确保 span 上报到 Tempo
static TRACER_PROVIDER: OnceLock<SdkTracerProvider> = OnceLock::new();

/// 保存文件日志的 WorkerGuard，进程退出时 drop 会刷新缓冲（tracing-appender non_blocking）
static FILE_APPENDER_GUARD: OnceLock<WorkerGuard> = OnceLock::new();

/// 由 Dart 在 init_logger 前调用，传入 path_provider 得到的可写目录（如 getTemporaryDirectory）
pub fn set_log_directory(path: String) {
    let _ = LOG_DIR_OVERRIDE.set(path);
}

/// 不导出到后端的 SpanExporter，仅用于让 SdkTracerProvider 生成有效 trace_id/span_id
#[derive(Debug)]
struct NoopSpanExporter;

impl OtelSpanExporter for NoopSpanExporter {
    fn export(&self, _batch: Vec<SpanData>) -> std::pin::Pin<Box<dyn std::future::Future<Output = OTelSdkResult> + Send>> {
        Box::pin(async { Ok(()) })
    }
}

/// 构建 OpenTelemetry Resource（与 tracing-opentelemetry 示例一致）
fn otel_resource(service_name: String) -> Resource {
    let version = std::env::var("OTEL_SERVICE_VERSION")
        .unwrap_or_else(|_| env!("CARGO_PKG_VERSION").to_string());
    Resource::builder_empty()
        .with_attributes([KeyValue::new("service.name", service_name), KeyValue::new("service.version", version)])
        .build()
}

/// 日志文件名前缀（tracing-appender rolling::daily）
const LOG_FILE_PREFIX: &str = "rust.log";

/// 日志目录：若 Dart 已通过 set_log_directory 传入则用该路径，否则用 temp_dir（Android 上未传入时不写文件）
fn log_dir() -> std::path::PathBuf {
    LOG_DIR_OVERRIDE
        .get()
        .map(|s| std::path::PathBuf::from(s.as_str()))
        .unwrap_or_else(|| std::env::temp_dir().join("rust_logs"))
}

/// 是否启用文件日志：非 Android 始终启用；Android 仅在已设置 LOG_DIR_OVERRIDE 时启用
fn use_file_appender() -> bool {
    if cfg!(target_os = "android") {
        LOG_DIR_OVERRIDE.get().is_some()
    } else {
        true
    }
}

/// 自定义 formatter：自己记录配置属性，并在末尾追加 trace_id/span_id
/// 实现与 Format 相同的方法，让 layer 的配置能自动传递
#[derive(Debug, Clone, Copy)]
struct CustomFormatter {
    with_file: bool,
    with_target: bool,
    with_line_number: bool,
    with_thread_names: bool,
    with_thread_ids: bool,
}

impl CustomFormatter {
    /// 创建默认的 CustomFormatter
    fn new() -> Self {
        Self {
            with_file: true,
            with_target: false,
            with_line_number: true,
            with_thread_names: false,
            with_thread_ids: false,
        }
    }

    /// 设置是否显示文件路径
    pub fn with_file(self, display_filename: bool) -> Self {
        Self {
            with_file: display_filename,
            ..self
        }
    }

    /// 设置是否显示模块路径
    pub fn with_target(self, display_target: bool) -> Self {
        Self {
            with_target: display_target,
            ..self
        }
    }

    /// 设置是否显示行号
    pub fn with_line_number(self, display_line_number: bool) -> Self {
        Self {
            with_line_number: display_line_number,
            ..self
        }
    }

    /// 设置是否显示线程名
    pub fn with_thread_names(self, display_thread_name: bool) -> Self {
        Self {
            with_thread_names: display_thread_name,
            ..self
        }
    }

    /// 设置是否显示线程 ID
    pub fn with_thread_ids(self, display_thread_id: bool) -> Self {
        Self {
            with_thread_ids: display_thread_id,
            ..self
        }
    }
}

impl<S, N> FormatEvent<S, N> for CustomFormatter
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> FormatFields<'a> + 'static,
{
    fn format_event(
        &self,
        ctx: &FmtContext<'_, S, N>,
        mut writer: Writer<'_>,
        event: &Event<'_>,
    ) -> fmt::Result {
        let metadata = event.metadata();
        let has_ansi = writer.has_ansi_escapes();
        
        // ANSI 颜色代码：dim (浅色) = \x1b[2m, reset = \x1b[0m
        let dim_start = if has_ansi { "\x1b[2m" } else { "" };
        let dim_end = if has_ansi { "\x1b[0m" } else { "" };

        // 时间戳（浅色）
        write!(&mut writer, "{}{}{} ", dim_start, chrono::Utc::now().format("%Y-%m-%dT%H:%M:%S%.6fZ"), dim_end)?;

        // Level（带 ANSI 颜色，如果支持）
        let level = *metadata.level();
        if has_ansi {
            let (prefix, suffix) = match level {
                tracing_core::Level::ERROR => ("\x1b[31m", "\x1b[0m"),
                tracing_core::Level::WARN => ("\x1b[33m", "\x1b[0m"),
                tracing_core::Level::INFO => ("\x1b[32m", "\x1b[0m"),
                tracing_core::Level::DEBUG => ("\x1b[34m", "\x1b[0m"),
                tracing_core::Level::TRACE => ("\x1b[35m", "\x1b[0m"),
            };
            write!(&mut writer, "{}{:>5}{} ", prefix, level.as_str(), suffix)?;
        } else {
            write!(&mut writer, "{:>5} ", level.as_str())?;
        }

        // trace_id:span_id（放在 LEVEL 后面，添加中括号）
        let otel_ctx = opentelemetry::Context::current();
        let span = otel_ctx.span();
        let span_ctx = span.span_context();
        if span_ctx.is_valid() {
            write!(
                writer,
                "{}{}[{}:{}]{} ",
                dim_start,
                "",
                span_ctx.trace_id(),
                span_ctx.span_id(),
                dim_end
            )?;
        }

        // Thread name/ID（浅色）
        if self.with_thread_names || self.with_thread_ids {
            let current_thread = std::thread::current();
            if self.with_thread_names {
                if let Some(name) = current_thread.name() {
                    write!(&mut writer, "{}{}{} ", dim_start, name, dim_end)?;
                }
            }
            if self.with_thread_ids {
                write!(&mut writer, "{}{:0>2?}{} ", dim_start, current_thread.id(), dim_end)?;
            }
        }

        // 不打印 span 名字（根据用户要求）

        // Target (module path)（浅色）
        if self.with_target {
            write!(writer, "{}{}:{}", dim_start, metadata.target(), dim_end)?;
        }

        // File:line（浅色，直接输出文件地址，移除宽度限制和链接）
        if self.with_file || self.with_line_number {
            if let Some(file) = metadata.file() {
                let line = metadata.line();
                
                // 直接输出文件地址，不添加链接，不限制宽度
                write!(writer, " {}{}", dim_start, file)?;
                
                if self.with_line_number {
                    if let Some(line) = line {
                        write!(writer, ":{}", line)?;
                    } else {
                        write!(writer, ":?")?;
                    }
                }
                write!(writer, "{}", dim_end)?;
            } else if self.with_line_number {
                // 只显示 line number，不显示 file
                if let Some(line) = metadata.line() {
                    write!(writer, " {}{}:{}{}", dim_start, "?", line, dim_end)?;
                }
            }
        }
        write!(writer, " ")?;

        // Write fields on the event（保持原色，不添加 dim）
        ctx.field_format().format_fields(writer.by_ref(), event)?;

        writeln!(writer)
    }
}

pub fn init_logger(log_level: &str) {
    INIT_LOGGER.call_once(|| {
        let filter_layer = EnvFilter::new(log_level);

        // 当 use_file_appender() 为 true 时写文件（非 Android 或 Android 且 Dart 已传入日志目录）
        let (file_writer, _guard) = if use_file_appender() {
            let dir = log_dir();
            let dir_str = dir.to_string_lossy().into_owned();
            let file_appender = RollingFileAppender::new(Rotation::DAILY, &dir_str, LOG_FILE_PREFIX);
            let (w, g) = tracing_appender::non_blocking(file_appender);
            let _ = FILE_APPENDER_GUARD.set(g);
            (Some(w), ())
        } else {
            (None, ())
        };

        // OpenTelemetry tracer：仅用于在日志中带 trace_id；上报到 Tempo 为可选，且必须不阻塞、不影响主程序。
        // Android 上未显式配置 OTEL_EXPORTER_OTLP_TRACES_ENDPOINT 时不做上报，避免 BatchSpanProcessor 连不通时干扰主流程。
        let service_name = std::env::var("OTEL_SERVICE_NAME").unwrap_or_else(|_| "rust_lib".to_string());
        let resource = otel_resource(service_name.clone());
        #[cfg(target_os = "android")]
        let use_otlp = std::env::var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT").is_ok();
        #[cfg(not(target_os = "android"))]
        let use_otlp = true;

        let provider = if use_otlp {
            let default_otel_endpoint = {
                #[cfg(target_os = "android")]
                { "http://10.0.2.2:4317".to_string() }
                #[cfg(not(target_os = "android"))]
                { "http://localhost:4317".to_string() }
            };
            let endpoint = std::env::var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
                .unwrap_or_else(|_| default_otel_endpoint);
            match opentelemetry_otlp::SpanExporter::builder()
                .with_tonic()
                .with_endpoint(endpoint.clone())
                .build()
            {
                Ok(otlp_exporter) => {
                    eprintln!("[logger] Trace 上报到 Tempo: endpoint={}", endpoint);
                    opentelemetry_sdk::trace::SdkTracerProvider::builder()
                        .with_sampler(Sampler::ParentBased(Box::new(Sampler::TraceIdRatioBased(1.0))))
                        .with_batch_exporter(otlp_exporter)
                        .with_resource(resource)
                        .build()
                }
                Err(e) => {
                    eprintln!("[logger] OTLP/Tempo 未配置或不可用 ({})，仅本地日志带 trace_id", e);
                    opentelemetry_sdk::trace::SdkTracerProvider::builder()
                        .with_simple_exporter(NoopSpanExporter)
                        .with_resource(resource)
                        .build()
                }
            }
        } else {
            #[cfg(target_os = "android")]
            {
                eprintln!("[logger] Android 未设置 OTEL_EXPORTER_OTLP_TRACES_ENDPOINT，仅本地日志带 trace_id，上报不影响主程序");
                opentelemetry_sdk::trace::SdkTracerProvider::builder()
                    .with_simple_exporter(NoopSpanExporter)
                    .with_resource(resource)
                    .build()
            }
            #[cfg(not(target_os = "android"))]
            {
                unreachable!()
            }
        };
        let _ = TRACER_PROVIDER.set(provider);
        let tracer = TRACER_PROVIDER.get().unwrap().tracer("rust_lib");
        opentelemetry::global::set_tracer_provider(
            TRACER_PROVIDER.get().unwrap().clone()
        );
        let otel_layer = OpenTelemetryLayer::new(tracer);

        // 使用自定义 formatter：console 开 ANSI，file 关 ANSI（格式一致）
        // Android 下控制台输出到 logcat（android_log-sys），非 Android 用 stdout
        let console_layer = {
            #[cfg(target_os = "android")]
            let w = android_log::AndroidLogMakeWriter::new();
            #[cfg(not(target_os = "android"))]
            let w = io::stdout;
            tracing_subscriber::fmt::layer()
                .with_writer(w)
                .with_ansi(!cfg!(target_os = "android")) // Android logcat 不需要 ANSI
                .with_file(true)
                .with_target(false)
                .with_line_number(true)
                .with_thread_names(true)
                .with_thread_ids(true)
                .event_format(CustomFormatter::new())
        };

        let file_layer = file_writer.map(|w| {
            tracing_subscriber::fmt::layer()
                .with_writer(w)
                .with_ansi(false)
                .with_file(true)
                .with_target(false)
                .with_line_number(true)
                .with_thread_names(true)
                .with_thread_ids(true)
                .event_format(CustomFormatter::new())
        });

        #[cfg(tokio_unstable)]
        let init_result = {
            let tokio_console = console_subscriber::spawn();
            let reg = tracing_subscriber::registry()
                .with(filter_layer)
                .with(otel_layer)
                .with(tokio_console)
                .with(console_layer);
            match file_layer {
                Some(fl) => reg.with(fl).try_init(),
                None => reg.try_init(),
            }
        };

        #[cfg(not(tokio_unstable))]
        let init_result = {
            let reg = tracing_subscriber::registry()
                .with(filter_layer)
                .with(otel_layer)
                .with(console_layer);
            match file_layer {
                Some(fl) => reg.with(fl).try_init(),
                None => reg.try_init(),
            }
        };

        if let Err(e) = init_result {
            eprintln!("[logger] 设置 global subscriber 失败（可能已被其他组件设置），跳过: {:?}", e);
        }

        // 控制 log 库输出：flutter_rust_bridge 会先注册 android_logger，我们无法替换。
        // 通过 set_max_level 限制传给 android_logger 的级别，避免 tokio-tungstenite 等依赖的 trace/debug 刷屏。
        let log_max = log_level_to_filter(log_level);
        log::set_max_level(log_max);
    });
}

/// 将 init_logger 的 log_level 字符串映射为 log 库的 LevelFilter，用于 set_max_level
fn log_level_to_filter(s: &str) -> log::LevelFilter {
    match s.to_lowercase().as_str() {
        "trace" => log::LevelFilter::Trace,
        "debug" => log::LevelFilter::Debug,
        "info" | "information" => log::LevelFilter::Info,
        "warn" | "warning" => log::LevelFilter::Warn,
        "error" => log::LevelFilter::Error,
        "off" => log::LevelFilter::Off,
        _ => log::LevelFilter::Info, // 默认只显示 info 及以上，屏蔽依赖的 trace/debug
    }
}

/// 在程序退出前调用：先 force_flush 再 shutdown，与官方示例 OtelGuard::drop 行为一致。
/// 参考：<https://github.com/tokio-rs/tracing-opentelemetry/blob/v0.1.x/examples/opentelemetry-otlp.rs>
pub fn flush_tracer_provider() {
    if let Some(provider) = TRACER_PROVIDER.get() {
        let _ = provider.force_flush();
        if let Err(e) = provider.shutdown() {
            eprintln!("[logger] tracer_provider.shutdown 失败: {:?}", e);
        }
    }
}
