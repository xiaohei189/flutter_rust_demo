use http::{Method, Uri};
use std::time::Instant;

/// HTTP 请求上下文（用于日志、链路追踪、错误上下文补充等）
#[derive(Debug, Clone)]
pub struct HttpRequestContext {
    pub method: Method,
    pub uri: Uri,
    pub request_id: String,
    pub started_at: Instant,
}
