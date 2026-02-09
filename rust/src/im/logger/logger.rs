//! Trace 导出参考：<https://github.com/tokio-rs/tracing-opentelemetry/tree/v0.1.x/examples>
//! 特别是 opentelemetry-otlp.rs：OtelGuard + shutdown、Resource、Sampler。

use std::fmt;
use std::fs::File;
use std::io::{self, Write};
use std::sync::{Once, OnceLock};
use opentelemetry::trace::{TraceContextExt, TracerProvider};
use opentelemetry_sdk::trace::{Sampler, SdkTracerProvider};
use opentelemetry::KeyValue;
use opentelemetry_otlp::Protocol;
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::error::OTelSdkResult;
use opentelemetry_sdk::trace::{SpanData, SpanExporter as OtelSpanExporter};
use opentelemetry_sdk::Resource;
use tracing_core::{Event, Subscriber};
use tracing_opentelemetry::OpenTelemetryLayer;
use tracing_subscriber::fmt::format::{FormatEvent, Writer};
use tracing_subscriber::fmt::FmtContext;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::prelude::*;
use tracing_subscriber::registry::LookupSpan;
use tracing_subscriber::EnvFilter;

static INIT_LOGGER: Once = Once::new();

/// 保存 TracerProvider，以便程序退出前可 force_flush，确保 span 上报到 Tempo
static TRACER_PROVIDER: OnceLock<SdkTracerProvider> = OnceLock::new();

/// 不导出到后端的 SpanExporter，仅用于让 SdkTracerProvider 生成有效 trace_id/span_id
#[derive(Debug)]
struct NoopSpanExporter;

impl OtelSpanExporter for NoopSpanExporter {
    fn export(&self, _batch: Vec<SpanData>) -> std::pin::Pin<Box<dyn std::future::Future<Output = OTelSdkResult> + Send>> {
        Box::pin(async { Ok(()) })
    }
}

/// 包装原有 Format：先输出级别与事件内容，最后追加 OpenTelemetry trace_id/span_id
struct WithTraceId<F>(F);

impl<S, N, F> FormatEvent<S, N> for WithTraceId<F>
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
        // 将事件内容（含 level，保持原有顺序）格式到 buffer，再在最后面追加 trace_id/span_id
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
    let version = std::env::var("OTEL_SERVICE_VERSION")
        .unwrap_or_else(|_| env!("CARGO_PKG_VERSION", "CARGO_PKG_VERSION not set").to_string());
    Resource::builder_empty()
        .with_attributes([
            KeyValue::new("service.name", service_name),
            KeyValue::new("service.version", version),
        ])
        .build()
}

/// 当前项目目录下的日志文件名（内容为每行一条 JSON，便于检索）
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

        // OpenTelemetry tracer：优先上报到 Tempo（OTLP HTTP），失败则仅本地日志带 trace_id
        let endpoint = std::env::var("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
            .unwrap_or_else(|_| "http://localhost:4318/v1/traces".to_string());
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
        let otel_layer = OpenTelemetryLayer::new(tracer);

        // 控制台：保持原有格式（含 level 位置），最后追加 trace_id/span_id
        let console_fmt = WithTraceId(
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
                .with(otel_layer)
                .with(console_layer)
                .with(fmt_layer);
            match File::create(&log_path) {
                Ok(file) => {
                    // 不用 format().json()：与 console 的 Pretty 混用时，span 的 fields 可能为空或非 JSON，会触发 "malformed fields" panic
                    let file_fmt = tracing_subscriber::fmt::format()
                        .with_target(true)
                        .with_thread_ids(true)
                        .with_ansi(false);
                    let file_layer = tracing_subscriber::fmt::layer()
                        .event_format(file_fmt)
                        .with_writer(std::sync::Mutex::new(FlushWriter(file)));
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
                .with(otel_layer)
                .with(fmt_layer);
            match File::create(&log_path) {
                Ok(file) => {
                    let file_fmt = tracing_subscriber::fmt::format()
                        .with_target(true)
                        .with_thread_ids(true)
                        .with_file(true)
                        .with_line_number(true)
                        .with_thread_names(true)
                        .with_ansi(false);
                    let file_layer = tracing_subscriber::fmt::layer()
                        .event_format(file_fmt)
                        .with_writer(std::sync::Mutex::new(FlushWriter(file)));
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
