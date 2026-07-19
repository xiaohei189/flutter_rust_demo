//! SDK 日志模块
//!
//! 集成 tracing + OpenTelemetry，提供：
//! - 文件/控制台/JSON 三层输出
//! - OTel trace_id 即 operation_id，分布式追踪
//! - span 跨 channel / tokio::spawn 传播
//!
//! 日志宏（`#[macro_export]`，在 crate root 可用）：
//! - `sdk_info!` / `sdk_debug!` / `sdk_warn!` / `sdk_error!`
//! - `sdk_span!`

pub mod config;
mod otel;
mod macros_;

pub use config::LogConfig;
pub use otel::{
    extract_trace_id,
    span_from_remote_trace_id,
    build_w3c_traceparent, context_from_traceparent,
    init_otel_subscriber,
};
