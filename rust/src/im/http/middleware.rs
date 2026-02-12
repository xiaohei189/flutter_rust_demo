//! HTTP 中间件：为请求添加 x-request-id、operationid、token
use async_trait::async_trait;
use reqwest::{Request, Response};
use reqwest_middleware::{Middleware, Next, Result as MwResult};

/// 统一的请求头中间件：注入 x-request-id、operationid、token
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

        req.headers_mut()
            .insert("x-request-id", request_id.parse().expect("uuid is valid header"));
        req.headers_mut()
            .insert("operationid", request_id.parse().expect("uuid is valid header"));

        if let Some(ref token) = self.token {
            if let Ok(v) = token.parse::<http::HeaderValue>() {
                req.headers_mut().insert("token", v);
            }
        }

        next.run(req, extensions).await
    }
}
