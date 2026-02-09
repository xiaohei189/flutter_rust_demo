//! Trace 导出参考：<https://github.com/tokio-rs/tracing-opentelemetry/tree/v0.1.x/examples>
//! 特别是 opentelemetry-otlp.rs：OtelGuard + shutdown、Resource、Sampler。
//! 日志文件接入 <https://crates.io/crates/tracing-appender>：rolling + non_blocking。

use chrono::Utc;
use opentelemetry::trace::{TraceContextExt, TracerProvider};
use opentelemetry::KeyValue;
use opentelemetry_otlp::Protocol;
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::error::OTelSdkResult;
use opentelemetry_sdk::trace::{Sampler, SdkTracerProvider};
use opentelemetry_sdk::trace::{SpanData, SpanExporter as OtelSpanExporter};
use opentelemetry_sdk::Resource;
use serde_json::json;
use std::fmt;
use std::io::{self, Write};
use std::sync::{Once, OnceLock};
use tracing_appender::non_blocking::WorkerGuard;
use tracing_appender::rolling::{RollingFileAppender, Rotation};
use tracing_core::{Event, Subscriber};
use tracing_opentelemetry::OpenTelemetryLayer;
use tracing_subscriber::fmt::format::{FormatEvent, FormatFields, Writer};
use tracing_subscriber::fmt::FmtContext;
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

/// 控制台用：在原有格式后追加 trace_id/span_id
struct WithTraceId<F>(F);

impl<S, N, F> FormatEvent<S, N> for WithTraceId<F>
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> tracing_subscriber::fmt::format::FormatFields<'a> + 'static,
    F: FormatEvent<S, N>,
{
    fn format_event(&self, ctx: &FmtContext<'_, S, N>, mut writer: Writer<'_>, event: &Event<'_>) -> fmt::Result {
        let otel_ctx = opentelemetry::Context::current();
        let span = otel_ctx.span();
        let span_ctx = span.span_context();
        let suffix = if span_ctx.is_valid() {
            format!(" trace_id={} span_id={}\n", span_ctx.trace_id(), span_ctx.span_id())
        } else {
            String::new()
        };
        let mut buf = String::new();
        self.0.format_event(ctx, Writer::new(&mut buf), event)?;
        write!(writer, "{}", buf)?;
        if !suffix.is_empty() {
            write!(writer, "{}", suffix)?;
        }
        Ok(())
    }
}

/// 构建 OpenTelemetry Resource（与 tracing-opentelemetry 示例一致）
fn otel_resource(service_name: String) -> Resource {
    let version = std::env::var("OTEL_SERVICE_VERSION").unwrap_or_else(|_| env!("CARGO_PKG_VERSION", "CARGO_PKG_VERSION not set").to_string());
    Resource::builder_empty()
        .with_attributes([KeyValue::new("service.name", service_name), KeyValue::new("service.version", version)])
        .build()
}

/// 日志文件：按天滚动，目录与文件名前缀（tracing-appender rolling::daily）
const LOG_DIR: &str = "logs";
const LOG_FILE_PREFIX: &str = "rust.log";

/// 文件用 JSON：与默认 json 格式同结构，但不解析 span fields，避免空 span 导致 malformed fields panic
struct JsonFileFormat;

impl<S, N> FormatEvent<S, N> for JsonFileFormat
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> tracing_subscriber::fmt::format::FormatFields<'a> + 'static,
{
    fn format_event(&self, ctx: &FmtContext<'_, S, N>, mut writer: Writer<'_>, event: &Event<'_>) -> fmt::Result {
        let ts = Utc::now().format("%Y-%m-%dT%H:%M:%S%.3fZ").to_string();
        let level = event.metadata().level().as_str();
        let target = event.metadata().target();
        let mut msg_buf = String::new();
        let _ = ctx.format_fields(Writer::new(&mut msg_buf), event);
        let msg = msg_buf.trim();
        let otel_ctx = opentelemetry::Context::current();
        let span = otel_ctx.span();
        let span_ctx = span.span_context();
        let obj = if span_ctx.is_valid() {
            json!({
                "ts": ts,
                "level": level,
                "target": target,
                "msg": msg,
                "trace_id": span_ctx.trace_id().to_string(),
                "span_id": span_ctx.span_id().to_string()
            })
        } else {
            json!({ "ts": ts, "level": level, "target": target, "msg": msg })
        };
        if let Ok(line) = serde_json::to_string(&obj) {
            let _ = writeln!(writer, "{}", line);
        }
        Ok(())
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

        // 文件滚动（按天），guard 必须持有否则日志会丢
        let file_appender = RollingFileAppender::new(Rotation::DAILY, LOG_DIR, LOG_FILE_PREFIX);
        let (file_writer, guard) = tracing_appender::non_blocking(file_appender);
        let _ = FILE_APPENDER_GUARD.set(guard);

        // OpenTelemetry tracer：优先上报到 Tempo（OTLP HTTP），失败则仅本地日志带 trace_id
        let endpoint = std::env::var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT").unwrap_or_else(|_| "http://localhost:4318/v1/traces".to_string());
        let service_name = std::env::var("OTEL_SERVICE_NAME").unwrap_or_else(|_| "rust_lib".to_string());
        let resource = otel_resource(service_name.clone());
        let provider = match opentelemetry_otlp::SpanExporter::builder()
            .with_http()
            .with_protocol(Protocol::HttpBinary)
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

        // 控制台：人类可读（pretty），末尾带 trace_id/span_id
        // 控制台：人类可读
        let console_layer = tracing_subscriber::fmt::layer()
        .with_file(true)
                .with_line_number(true)
                .compact() 
               ; // 或 compact()


        // 文件：JSON
        let file_layer = tracing_subscriber::fmt::layer()
        .with_writer(file_writer)
        .with_ansi(false)
        .compact();

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
            tracing_subscriber::registry().with(filter_layer).with(otel_layer).with(console_layer).with(file_layer).init();
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
