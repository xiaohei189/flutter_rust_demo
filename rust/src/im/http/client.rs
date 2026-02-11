//! 基于 reqwest-middleware 构建的 HTTP 客户端
//!
//! 参考: https://docs.rs/reqwest-middleware/latest/reqwest_middleware/

use async_trait::async_trait;
use reqwest_middleware::{ClientBuilder, Middleware, Next, Result as MiddlewareResult};

/// HTTP 客户端类型（reqwest-middleware 的 ClientWithMiddleware）
pub type HttpClient = reqwest_middleware::ClientWithMiddleware;

/// Token 中间件：为所有请求添加 token 请求头
#[derive(Clone)]
struct TokenMiddleware {
    token: Option<String>,
}

#[async_trait]
impl Middleware for TokenMiddleware {
    async fn handle(
        &self,
        req: reqwest::Request,
        extensions: &mut http::Extensions,
        next: Next<'_>,
    ) -> MiddlewareResult<reqwest::Response> {
        let mut req = req;
        if let Some(ref token) = self.token {
            if !token.is_empty() {
                if let Ok(v) = http::HeaderValue::from_str(token) {
                    req.headers_mut().insert(http::header::HeaderName::from_static("token"), v);
                }
            }
        }
        next.run(req, extensions).await
    }
}

/// 请求 ID 中间件：添加 x-request-id 和 operationid 请求头
#[derive(Clone, Default)]
struct RequestIdMiddleware;

#[async_trait]
impl Middleware for RequestIdMiddleware {
    async fn handle(
        &self,
        req: reqwest::Request,
        extensions: &mut http::Extensions,
        next: Next<'_>,
    ) -> MiddlewareResult<reqwest::Response> {
        let mut req = req;
        let request_id = uuid::Uuid::new_v4().to_string();

        if let Ok(v) = http::HeaderValue::from_str(&request_id) {
            req.headers_mut().insert(
                http::header::HeaderName::from_static("x-request-id"),
                v.clone(),
            );
            // 若未设置 operationid，则使用 x-request-id 的值
            if !req.headers().contains_key("operationid") {
                req.headers_mut().insert(
                    http::header::HeaderName::from_static("operationid"),
                    v,
                );
            }
        }

        next.run(req, extensions).await
    }
}

/// 使用 reqwest-middleware 构建带中间件的 HTTP 客户端
pub fn make_client(client: reqwest::Client, token: &str) -> HttpClient {
    let token = token.trim();
    let token_value = if token.is_empty() {
        None
    } else {
        Some(token.to_string())
    };

    let base = reqwest_middleware::ClientWithMiddleware::from(client);
    ClientBuilder::from_client(base)
        .with(RequestIdMiddleware)
        .with(TokenMiddleware { token: token_value })
        .build()
}

/// 创建不带 token 的客户端（用于登录等公开接口）
pub fn make_client_without_token(client: reqwest::Client) -> HttpClient {
    make_client(client, "")
}
