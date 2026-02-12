//! Trace 导出参考：<https://github.com/tokio-rs/tracing-opentelemetry/tree/v0.1.x/examples>
//! 特别是 opentelemetry-otlp.rs：OtelGuard + shutdown、Resource、Sampler。
//! 日志文件接入 <https://crates.io/crates/tracing-appender>：rolling + non_blocking。

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

/// 保存 TracerProvider，以便程序退出前可 force_flush，确保 span 上报到 Tempo
static TRACER_PROVIDER: OnceLock<SdkTracerProvider> = OnceLock::new();

/// 保存文件日志的 WorkerGuard，进程退出时 drop 会刷新缓冲（tracing-appender non_blocking）
static FILE_APPENDER_GUARD: OnceLock<WorkerGuard> = OnceLock::new();

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

/// 日志文件：按天滚动，目录与文件名前缀（tracing-appender rolling::daily）
const LOG_DIR: &str = "logs";
const LOG_FILE_PREFIX: &str = "rust.log";

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

        // 文件滚动（按天），guard 必须持有否则日志会丢
        let file_appender = RollingFileAppender::new(Rotation::DAILY, LOG_DIR, LOG_FILE_PREFIX);
        let (file_writer, guard) = tracing_appender::non_blocking(file_appender);
        let _ = FILE_APPENDER_GUARD.set(guard);

        // OpenTelemetry tracer：优先上报到 Tempo（OTLP gRPC/tonic），失败则仅本地日志带 trace_id
        // 注意：gRPC 默认端口通常是 4317；HTTP/protobuf 默认端口通常是 4318。
        let endpoint = std::env::var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
            .unwrap_or_else(|_| "http://localhost:4317".to_string());
        let service_name = std::env::var("OTEL_SERVICE_NAME").unwrap_or_else(|_| "rust_lib".to_string());
        let resource = otel_resource(service_name.clone());
        let provider = match opentelemetry_otlp::SpanExporter::builder()
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
        };
        let _ = TRACER_PROVIDER.set(provider);
        let tracer = TRACER_PROVIDER.get().unwrap().tracer("rust_lib");
        opentelemetry::global::set_tracer_provider(
            TRACER_PROVIDER.get().unwrap().clone()
        );
        let otel_layer = OpenTelemetryLayer::new(tracer);

        // 使用自定义 formatter：console 开 ANSI，file 关 ANSI（格式一致）
        // CustomFormatter 包装官方的 Format，自动获取所有配置
        // 使用原生 API，配置会自动传递，无需单独设置
        let console_layer = tracing_subscriber::fmt::layer()
            .with_writer(io::stdout)
            .with_ansi(true)
            .with_file(true)
            .with_target(false)
            .with_line_number(true)
            .with_thread_names(true)
            .with_thread_ids(true)
            .event_format(CustomFormatter::new());

        let file_layer = tracing_subscriber::fmt::layer()
            .with_writer(file_writer)
            .with_ansi(false)
            .with_file(true)
            .with_target(false)
            .with_line_number(true)
            .with_thread_names(true)
            .with_thread_ids(true)
            .event_format(CustomFormatter::new());

        #[cfg(tokio_unstable)]
        {
            let tokio_console = console_subscriber::spawn();
            tracing_subscriber::registry()
                .with(filter_layer)
                .with(otel_layer)
                .with(tokio_console)
                .with(console_layer)
                .with(file_layer)
                .init();
        }

        #[cfg(not(tokio_unstable))]
        {
            tracing_subscriber::registry()
                .with(filter_layer)
                .with(otel_layer)
                .with(console_layer)
                .with(file_layer)
                .init();
        }
    });
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
