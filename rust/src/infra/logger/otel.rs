//! OpenTelemetry 集成：trace_id 提取、remote span 重建、subscriber 初始化

use opentelemetry::propagation::TextMapPropagator;
use opentelemetry::trace::{SpanContext, SpanId, TraceContextExt, TraceFlags, TraceId, TraceState, TracerProvider as _};
use opentelemetry::Context;
use opentelemetry_sdk::propagation::TraceContextPropagator;
use opentelemetry_sdk::trace::TracerProvider;
use std::collections::HashMap;
use std::fmt;
use tracing::Span;
use tracing_opentelemetry::OpenTelemetrySpanExt;
use tracing_subscriber::fmt::format::Writer;
use tracing_subscriber::fmt::{FmtContext, FormatEvent};
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::registry::LookupSpan;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::Registry;

use super::config::LogConfig;

/// 自定义 FormatEvent：手动控制每一行输出（去掉 target/module path，强制文件:行号）
///
/// 格式：
///   `<ts> <LEVEL> <span_name>{trace_id=... span_id=... field=val}: <message> <file:line>`
///
/// 与之前 `TraceIdFormatter<F>` 的关键区别：
/// - **完全不用 `Format::<Full, _>`**，自己写每一段，避免 `Full` 模式输出 target
/// - **不输出 target/module path**（原 `Full` 会输出 `rust_lib_...::manager`）
/// - **强制输出文件:行号**（直接读 `event.metadata()`）
/// - **按 `with_ansi` 决定是否给级别加颜色**（formatter 自管 ANSI）
struct CompactFormatter {
    with_ansi: bool,
}

impl<S, N> FormatEvent<S, N> for CompactFormatter
where
    S: tracing::Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> tracing_subscriber::fmt::FormatFields<'a> + 'static,
{
    fn format_event(
        &self,
        ctx: &FmtContext<'_, S, N>,
        mut writer: Writer<'_>,
        event: &tracing::Event<'_>,
    ) -> fmt::Result {
        // 颜色码
        const GREY: &str = "\x1b[90m";  // 暗灰：时间、文件
        const CYAN: &str = "\x1b[36m";  // 青色：span 链
        const DIM: &str = "\x1b[2m";    // 暗色：trace/span
        const RESET: &str = "\x1b[0m";

        // 1) 时间戳
        let ts = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%S%.3fZ");
        if self.with_ansi {
            write!(writer, "{}{}{} ", GREY, ts, RESET)?;
        } else {
            write!(writer, "{} ", ts)?;
        }

        // 2) 级别
        let level = event.metadata().level();
        if self.with_ansi {
            let color = match *level {
                tracing::Level::ERROR => "\x1b[31m",
                tracing::Level::WARN  => "\x1b[33m",
                tracing::Level::INFO  => "\x1b[32m",
                tracing::Level::DEBUG => "\x1b[34m",
                tracing::Level::TRACE => "\x1b[35m",
            };
            write!(writer, "{}{:<5}{} ", color, *level, RESET)?;
        } else {
            write!(writer, "{:<5} ", *level)?;
        }

        // 3) 文件:行号（紧跟 level）
        if let (Some(file), Some(line)) = (event.metadata().file(), event.metadata().line()) {
            let file = shorten_cargo_path(file);
            if self.with_ansi {
                write!(writer, "{}{}:{}{} ", GREY, file, line, RESET)?;
            } else {
                write!(writer, "{}:{} ", file, line)?;
            }
        }

        // 4) span_name{fields, trace_id, span_id}
        let span = Span::current();
        let cx = span.context();
        let otel_span = cx.span();
        let sc = otel_span.span_context();

        if let Some(scope) = ctx.event_scope() {
            for span_ref in scope.from_root() {
                let name = span_ref.metadata().name();
                let extensions = span_ref.extensions();
                let fields_str = extensions
                    .get::<tracing_subscriber::fmt::FormattedFields<N>>()
                    .map(|f| f.as_str())
                    .unwrap_or("");

                if self.with_ansi {
                    write!(writer, "{}{}{}", CYAN, name, RESET)?;
                    // 构建 {fields, trace_id, span_id}
                    let mut inner = String::new();
                    if !fields_str.is_empty() {
                        // fields_str 是 "key1=v1 key2=v2" 格式，转为 "key1=v1, key2=v2"
                        inner.push_str(&fields_str.replace(' ', ", "));
                    }
                    if sc.is_valid() {
                        if !inner.is_empty() {
                            inner.push_str(", ");
                        }
                        inner.push_str(&format!("trace_id={}, span_id={}", sc.trace_id(), sc.span_id()));
                    }
                    if !inner.is_empty() {
                        write!(writer, "{}{{{}}}{}", DIM, inner, RESET)?;
                    }
                    write!(writer, " ")?;
                } else if fields_str.is_empty() && !sc.is_valid() {
                    write!(writer, "{} ", name)?;
                } else {
                    write!(writer, "{}", name)?;
                    let mut inner = String::new();
                    if !fields_str.is_empty() {
                        inner.push_str(&fields_str.replace(' ', ", "));
                    }
                    if sc.is_valid() {
                        if !inner.is_empty() {
                            inner.push_str(", ");
                        }
                        inner.push_str(&format!("trace_id={}, span_id={}", sc.trace_id(), sc.span_id()));
                    }
                    if !inner.is_empty() {
                        write!(writer, "{{{}}}", inner)?;
                    }
                    write!(writer, " ")?;
                }
            }
        } else if sc.is_valid() {
            // 没有 span，但有 trace_id
            if self.with_ansi {
                write!(writer, "{}{{trace_id={}, span_id={}}}{} ", DIM, sc.trace_id(), sc.span_id(), RESET)?;
            } else {
                write!(writer, "{{trace_id={}, span_id={}}} ", sc.trace_id(), sc.span_id())?;
            }
        }

        // 5) 消息内容
        ctx.field_format().format_fields(writer.by_ref(), event)?;

        writeln!(writer)?;

        Ok(())
    }
}

/// 把 `/home/user/.cargo/registry/src/xx/crate-1.0/src/lib.rs` 缩短为 `crate/src/lib.rs`
fn shorten_cargo_path(file: &str) -> String {
    let marker = ".cargo/registry/src/";
    if !file.contains(marker) {
        return file.to_string();
    }
    if let Some(idx) = file.find(marker) {
        let after = &file[idx + marker.len()..];
        if let Some(slash1) = after.find('/') {
            let crate_path = &after[slash1 + 1..];
            if let Some(slash2) = crate_path.find('/') {
                let cv = &crate_path[..slash2];
                let dash = cv
                    .as_bytes()
                    .iter()
                    .enumerate()
                    .rev()
                    .find(|(i, &b)| {
                        b == b'-'
                            && i + 1 < cv.len()
                            && cv.as_bytes()[i + 1].is_ascii_digit()
                    })
                    .map(|(i, _)| i);
                let cn = dash.map_or(cv, |d| &cv[..d]);
                return format!("{}{}", cn, &crate_path[slash2..]);
            }
            return crate_path.to_string();
        }
    }
    file.to_string()
}

/// 从当前 tracing span 的 OTel 上下文中提取 trace_id 字符串
pub fn extract_trace_id() -> String {
    let span = Span::current();
    let cx = span.context();
    let span_ref = cx.span(); let sc = span_ref.span_context();
    if sc.is_valid() {
        sc.trace_id().to_string()
    } else {
        String::new()
    }
}

/// 从服务端回传的 trace_id 字符串重建 tracing span（带 remote parent）
pub fn span_from_remote_trace_id(
    name: &str,
    trace_id_hex: &str,
    parent_span_id_hex: Option<&str>,
) -> Span {
    let trace_id = TraceId::from_hex(trace_id_hex).unwrap_or(TraceId::INVALID);
    if trace_id == TraceId::INVALID {
        return tracing::info_span!("{}", name);
    }

    let parent_span_id = parent_span_id_hex
        .and_then(|s| SpanId::from_hex(s).ok())
        .unwrap_or(SpanId::INVALID);

    let remote_sc = SpanContext::new(
        trace_id,
        if parent_span_id == SpanId::INVALID { SpanId::INVALID } else { parent_span_id },
        TraceFlags::SAMPLED,
        true,
        TraceState::default(),
    );

    let parent_cx = Context::new().with_remote_span_context(remote_sc);
    let span = tracing::info_span!("{}", name);
    span.set_parent(parent_cx);
    span
}

/// 构建 W3C traceparent header
pub fn build_w3c_traceparent(trace_id_hex: &str, span_id_hex: &str) -> String {
    format!("00-{}-{}-01", trace_id_hex, span_id_hex)
}

/// 从 W3C traceparent 字符串提取 Context
pub fn context_from_traceparent(traceparent: &str) -> Context {
    let mut carrier = HashMap::new();
    carrier.insert("traceparent".to_string(), traceparent.to_string());
    let propagator = TraceContextPropagator::new();
    propagator.extract(&carrier)
}

/// 初始化 OTel subscriber（文件 + OTel + 可选控制台）
pub fn init_otel_subscriber(config: &LogConfig) -> anyhow::Result<()> {
    use tracing_subscriber::fmt::format::FmtSpan;

    // --- EnvFilter ---
    let mut env_filter = tracing_subscriber::EnvFilter::builder()
        .with_default_directive(config.level_filter().into())
        .from_env_lossy();
    env_filter = env_filter
        .add_directive("hyper=warn".parse().unwrap())
        .add_directive("reqwest=warn".parse().unwrap())
        .add_directive("tower=warn".parse().unwrap())
        .add_directive("hyper_util=warn".parse().unwrap())
        .add_directive("sqlx=warn".parse().unwrap());

    // --- 文件层 ---
    let _ = std::fs::create_dir_all(&config.log_file_path);
    let file_appender = tracing_appender::rolling::daily(&config.log_file_path, "sdk.log");
    let (non_blocking_file, _file_guard) = tracing_appender::non_blocking(file_appender);
    std::mem::forget(_file_guard);

    let file_layer = tracing_subscriber::fmt::layer()
        .with_writer(non_blocking_file)
        .with_ansi(false)
        .event_format(CompactFormatter { with_ansi: false });

    // --- OTel 层 ---
    let provider = TracerProvider::builder().build();
    let tracer = provider.tracer("openim-rust-sdk");
    let otel_layer = tracing_opentelemetry::layer().with_tracer(tracer);

    // --- 控制台层（禁用时写入 sink） ---
    #[cfg(not(target_os = "android"))]
    let (console_writer, _console_guard) = if config.is_log_standard_output {
        tracing_appender::non_blocking(std::io::stdout())
    } else {
        tracing_appender::non_blocking(std::io::sink())
    };
    #[cfg(not(target_os = "android"))]
    std::mem::forget(_console_guard);

    #[cfg(target_os = "android")]
    let console_writer = {
        let (nc, _cg) = tracing_appender::non_blocking(std::io::stdout());
        std::mem::forget(_cg);
        nc
    };

    let console_layer = tracing_subscriber::fmt::layer()
        .with_writer(console_writer)
        .with_ansi(!cfg!(target_os = "android"))
        .event_format(CompactFormatter {
            with_ansi: !cfg!(target_os = "android"),
        });

    // --- 组装 subscriber ---
    tracing_subscriber::registry()
        .with(env_filter)
        .with(file_layer)
        .with(otel_layer)
        .with(console_layer)
        .try_init()?;

    tracing::info!(
        otel.name = "sdk.init",
        sdk.version = %config.sdk_version,
        system.type = %config.system_type,
        platform.name = %config.platform_name,
        "[SDK] 日志已初始化 level={} json={} stdout={}",
        config.log_level, config.is_log_json, config.is_log_standard_output,
    );

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_build_w3c_traceparent() {
        let tp = build_w3c_traceparent("0af7651916cd43dd8448eb211c80319c", "b7ad6b7169203331");
        assert_eq!(tp, "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01");
    }

    #[test]
    fn test_span_from_invalid_trace_id() {
        let span = span_from_remote_trace_id("test", "invalid", None);
        let _guard = span.enter();
        tracing::info!("test message");
    }
}
