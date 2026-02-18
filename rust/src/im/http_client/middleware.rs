//! HTTP 中间件：按职责划分的拦截器
use async_trait::async_trait;
use reqwest::{Request, Response};
use reqwest_middleware::{Middleware, Next, Result as MwResult};
use std::time::Instant;
use tracing::debug;

/// 请求 ID 中间件：注入 x-request-id、operationid
#[derive(Clone, Default)]
pub struct RequestIdMiddleware;

#[async_trait]
impl Middleware for RequestIdMiddleware {
    async fn handle(&self, req: Request, extensions: &mut http::Extensions, next: Next<'_>) -> MwResult<Response> {
        let mut req = req;
        let request_id = uuid::Uuid::new_v4().to_string();
        req.headers_mut()
            .insert("x-request-id", request_id.parse().expect("uuid is valid header"));
        req.headers_mut()
            .insert("operationid", request_id.parse().expect("uuid is valid header"));
        next.run(req, extensions).await
    }
}

/// Token 中间件：注入 token 请求头
#[derive(Clone)]
pub struct TokenMiddleware {
    token: Option<String>,
}

impl TokenMiddleware {
    pub fn new(token: &str) -> Self {
        let token = if token.trim().is_empty() { None } else { Some(token.to_string()) };
        Self { token }
    }
}

#[async_trait]
impl Middleware for TokenMiddleware {
    async fn handle(&self, req: Request, extensions: &mut http::Extensions, next: Next<'_>) -> MwResult<Response> {
        let mut req = req;
        if let Some(ref token) = self.token {
            if let Ok(v) = token.parse::<http::HeaderValue>() {
                req.headers_mut().insert("token", v);
            }
        }
        next.run(req, extensions).await
    }
}

/// 请求日志中间件：打印请求和响应信息
#[derive(Clone, Default)]
pub struct LoggingMiddleware;

#[async_trait]
impl Middleware for LoggingMiddleware {
    async fn handle(&self, req: Request, extensions: &mut http::Extensions, next: Next<'_>) -> MwResult<Response> {
        let method = req.method().clone();
        let uri = req.url().clone();
        let started_at = Instant::now();

        let resp = next.run(req, extensions).await?;

        let latency_ms = started_at.elapsed().as_millis();
        debug!(method = %method, uri = %uri, status = %resp.status(), latency_ms = latency_ms, "HTTP response");

        Ok(resp)
    }
}
