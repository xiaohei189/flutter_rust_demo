//! HTTP 中间件：为请求添加 x-request-id、operationid、token，并将 HttpRequestContext 注入响应
use crate::im::http::context::HttpRequestContext;
use async_trait::async_trait;
use http::{Method, Uri};
use reqwest::{Request, Response};
use reqwest_middleware::{Middleware, Next, Result as MwResult};
use std::time::Instant;

/// 统一的请求头中间件：注入 x-request-id、operationid、token，并在响应中附加 HttpRequestContext
#[derive(Clone)]
pub struct RequestHeadersMiddleware {
    token: Option<String>,
}

impl RequestHeadersMiddleware {
    pub fn new(token: &str) -> Self {
        let token = if token.trim().is_empty() { None } else { Some(token.to_string()) };
        Self { token }
    }
}

#[async_trait]
impl Middleware for RequestHeadersMiddleware {
    async fn handle(&self, req: Request, extensions: &mut http::Extensions, next: Next<'_>) -> MwResult<Response> {
        let mut req = req;
        let request_id = uuid::Uuid::new_v4().to_string();
        let started_at = Instant::now();
        let method = req.method().clone();
        let uri: Uri = req.url().as_str().parse().unwrap_or_else(|_| "unknown://unknown".parse().unwrap());

        req.headers_mut()
            .insert("x-request-id", request_id.parse().expect("uuid is valid header"));
        req.headers_mut()
            .insert("operationid", request_id.parse().expect("uuid is valid header"));

        if let Some(ref token) = self.token {
            if let Ok(v) = token.parse::<http::HeaderValue>() {
                req.headers_mut().insert("token", v);
            }
        }

        let mut resp = next.run(req, extensions).await?;

        let ctx = HttpRequestContext {
            method,
            uri,
            request_id,
            started_at,
        };
        resp.extensions_mut().insert(ctx);

        Ok(resp)
    }
}
