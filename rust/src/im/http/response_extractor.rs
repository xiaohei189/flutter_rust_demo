use crate::im::http::context::HttpRequestContext;
use crate::im::types::ApiResponse;
use anyhow::{Context as _, Result};
use http;
use serde::de::DeserializeOwned;
use tower::Service;
use tower_http_client::ResponseExt as _;
use tower_http_client::client::ClientRequest;

/// 基于 Response 的扩展信息输出通用日志（如果 Response 没有携带 RequestContext，会降级提醒）。
///
/// 注意：`Request.extensions()` 的内容不会“自动”出现在 `Response.extensions()` 中，
/// 是否能取到取决于你的 HTTP client / middleware 是否把上下文透传到了 Response。
#[derive(Debug, Clone, Default)]
pub struct HttpResponseExtractor;

impl HttpResponseExtractor {
    /// 已有 Response 场景：仅使用 `ClientRequestBuilder` 提供的请求元信息 + 现成 Response 做统一解析。
    /// 适用于：上层已调用 `send()` 拿到 Response，但仍希望在错误/日志中包含请求 method/uri/operationID。
    pub async fn send<T, S, Err, ReqBody>(
        req: ClientRequest<'_, S, Err, ReqBody, reqwest::Body>,
    ) -> Result<T>
    where
        T: DeserializeOwned,
        Err: Into<anyhow::Error> + Send + Sync + 'static,
        ReqBody: Send + 'static,
        reqwest::Body: From<ReqBody>,
        S: Service<http::Request<reqwest::Body>, Response = http::Response<reqwest::Body>, Error = Err>
            + Send,
        S::Future: Send + 'static,
    {
        // 强制将请求体转换为 reqwest::Body，以匹配 HttpClient 的 Service 约束
        let response = req.send().await.map_err(Into::into)?;

        // 取上下文；缺失则占位，保证任何错误都附带请求信息
        let (method, uri, operation_id) = match response.extensions().get::<HttpRequestContext>() {
            Some(ctx) => (ctx.method.clone(), ctx.uri.clone(), ctx.request_id.clone()),
            None => {
                tracing::warn!("HttpRequestContext missing in response, fallback placeholders");
                (
                    http::Method::from_bytes(b"UNKNOWN").unwrap(),
                    "unknown://unknown".parse().unwrap(),
                    "-".to_string(),
                )
            }
        };

        let status = response.status();

        // 先把 body 读成字节，便于错误场景输出原始文本
        let body_bytes = response
            .body_reader()
            .bytes()
            .await
            .map_err(|e| anyhow::anyhow!("read body failed: method={} url={} operation_id={} status={} err={}", method, uri, operation_id, status, e))?;
        let body_text = String::from_utf8_lossy(&body_bytes).to_string();

        tracing::debug!(
            "HTTP response: method={} url={} operation_id={} status={} body={}",
            method,
            uri,
            operation_id,
            status,
            body_text
        );

        if status != http::StatusCode::OK {
            anyhow::bail!(
                "HTTP status not ok: method={} url={} operation_id={} status={} body={}",
                method,
                uri,
                operation_id,
                status,
                body_text
            );
        }

        let api_resp: ApiResponse<T> = serde_json::from_slice(&body_bytes).map_err(|e| {
            anyhow::anyhow!(
                "Parse JSON failed: method={} url={} operation_id={} status={} body={} err={}",
                method,
                uri,
                operation_id,
                status,
                body_text,
                e
            )
        })?;

        if api_resp.err_code != 0 {
            // 已成功解析结构体，直接输出整个响应体，方便定位业务错误
            anyhow::bail!(
                "API biz error: method={} url={} operation_id={} status={} body={}",
                method,
                uri,
                operation_id,
                status,
                body_text
            );
        }

        api_resp
            .data
            .with_context(|| format!("API response missing data field (data==null): method={} url={} operation_id={} status={} body={}", method, uri, operation_id, status, body_text))
    }
}


