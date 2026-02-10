//! 通过 trace_id/span_id 串联 OTel 上下文的工具（用于 WS 请求/响应通过 operation_id 传递）

use opentelemetry::trace::{SpanContext, TraceContextExt, TraceFlags, TraceState};
use tracing_opentelemetry::OpenTelemetrySpanExt;

/// operation_id 中 trace_id 与 span_id 的分隔符；格式为 "trace_id_32hex:span_id_16hex"
const TRACE_SPAN_SEP: char = ':';

/// 从当前 OTel 上下文生成 operation_id（trace_id:span_id 十六进制），便于响应时用 trace_id 创建子 span。
pub fn operation_id_from_otel() -> String {
    let ctx = tracing::Span::current().context();
    let span_ref = ctx.span();
    let span_ctx = span_ref.span_context();
    if span_ctx.is_valid() {
        format!(
            "{}{}{}",
            span_ctx.trace_id(),
            TRACE_SPAN_SEP,
            span_ctx.span_id()
        )
    } else {
        String::new()
    }
}

/// 从 operation_id 解析出 OTel 父上下文（格式须为 "trace_id_32hex:span_id_16hex"）。
/// 用于响应处理时以该 context 为父创建新 span（`span.set_parent(...)`）。
pub fn otel_context_from_operation_id(operation_id: &str) -> Option<opentelemetry::Context> {
    let parts: [&str; 2] = operation_id.splitn(2, TRACE_SPAN_SEP).collect::<Vec<_>>().try_into().ok()?;
    let (trace_id_str, span_id_str) = (parts[0].trim(), parts[1].trim());
    if trace_id_str.len() != 32 || span_id_str.len() != 16 {
        return None;
    }
    let trace_id = opentelemetry::trace::TraceId::from_hex(trace_id_str).ok()?;
    let span_id = opentelemetry::trace::SpanId::from_hex(span_id_str).ok()?;
    let span_ctx = SpanContext::new(
        trace_id,
        span_id,
        TraceFlags::default(),
        true,
        TraceState::default(),
    );
    if !span_ctx.is_valid() {
        return None;
    }
    Some(opentelemetry::Context::current().with_remote_span_context(span_ctx))
}
