use crate::im::http::context::HttpRequestContext;
use crate::im::model::ApiResponse;
use anyhow::{Context as _, Result};
use http;
use reqwest::Response;
use serde::de::DeserializeOwned;
use tracing::debug;

/// 基于 Response 的扩展信息输出通用日志（如果 Response 没有携带 RequestContext，会降级提醒）。
///
/// 注意：是否能取到 RequestContext 取决于 HTTP middleware 是否把上下文透传到了 Response。
#[derive(Debug, Clone, Default)]
pub struct HttpResponseExtractor;

impl HttpResponseExtractor {
    /// 从 reqwest::Response 解析 ApiResponse<T>
    pub async fn extract_response<T: DeserializeOwned>(response: Response) -> Result<ApiResponse<T>> {
        let (method, uri, _operation_id) = match response.extensions().get::<HttpRequestContext>() {
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
        let body_bytes = response.bytes().await.map_err(|e| anyhow::anyhow!("read body failed: err={}", e))?;
        let body_text = String::from_utf8_lossy(&body_bytes).to_string();

        if status != http::StatusCode::OK {
            anyhow::bail!("HTTP status not ok: status={} body={}", status, body_text);
        }

        let api_resp: ApiResponse<T> = serde_json::from_slice(&body_bytes).map_err(|e| {
            anyhow::anyhow!(
                "Parse JSON failed: status={} body={} err={}",
                status,
                body_text,
                e
            )
        })?;

        match serde_json::from_slice::<serde_json::Value>(&body_bytes).and_then(|v| serde_json::to_string_pretty(&v)) {
            Ok(_) => debug!(method = %method, uri = %uri, status = %status, "HttpResponseExtractor"),
            Err(_) => debug!(method = %method, uri = %uri, status = %status, "HttpResponseExtractor"),
        }

        if api_resp.err_code != 0 {
            anyhow::bail!("API biz error: status={} body={}", status, body_text);
        }

        Ok(api_resp)
    }

    /// 从 reqwest::Response 解析并返回 data 字段
    pub async fn extract_data<T: DeserializeOwned>(response: Response) -> Result<T> {
        let api_resp = Self::extract_response(response).await?;

        api_resp
            .data
            .with_context(|| format!("API response missing data field (data==null): errCode={} errMsg={}", api_resp.err_code, api_resp.err_msg))
    }
}
