use crate::im::http::middleware::{LoggingMiddleware, RequestIdMiddleware, TokenMiddleware};
use reqwest_middleware::ClientBuilder;

/// 基于 reqwest-middleware 的 HTTP 客户端（带 request-id、token、logging 等中间件）
pub type HttpClient = reqwest_middleware::ClientWithMiddleware;

/// 创建带 token 的 HTTP 客户端
pub fn make_client(client: reqwest::Client, token: &str) -> HttpClient {
    ClientBuilder::new(client)
        .with(RequestIdMiddleware)
        .with(TokenMiddleware::new(token))
        .with(LoggingMiddleware)
        .build()
}

/// 创建不带 token 的 HTTP 客户端（用于登录等公开接口）
pub fn make_client_without_token(client: reqwest::Client) -> HttpClient {
    make_client(client, "")
}
