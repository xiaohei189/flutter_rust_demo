use crate::im::model::ApiResponse;
use anyhow::{Context as _, Result};
use http;
use serde::de::DeserializeOwned;
use tracing::debug;

/// 基于 Response 的扩展信息输出通用日志
#[derive(Debug, Clone, Default)]
pub struct HttpResponseExtractor;

impl HttpResponseExtractor {
    /// 使用 reqwest-middleware 的 RequestBuilder 发送请求并解析 JSON 响应
    pub async fn send_data<T>(
        req: reqwest_middleware::RequestBuilder,
        method: http::Method,
        uri: &str,
        operation_id: &str,
    ) -> Result<T>
    where
        T: DeserializeOwned,
    {
        let api_resp = Self::send_response::<T>(req, method, uri, operation_id).await?;
        api_resp
            .data
            .with_context(|| {
                format!(
                    "API response missing data field (data==null): errCode={} errMsg={}",
                    api_resp.err_code, api_resp.err_msg
                )
            })
    }

    /// 发送请求并返回完整的 ApiResponse
    pub async fn send_response<T>(
        req: reqwest_middleware::RequestBuilder,
        method: http::Method,
        uri: &str,
        operation_id: &str,
    ) -> Result<ApiResponse<T>>
    where
        T: DeserializeOwned,
    {
        let response = req.send().await.map_err(anyhow::Error::from)?;
        let status = response.status();

        let body_bytes = response
            .bytes()
            .await
            .map_err(|e| anyhow::anyhow!("read body failed: err={}", e))?;
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

        match serde_json::from_slice::<serde_json::Value>(&body_bytes)
            .and_then(|v| serde_json::to_string_pretty(&v))
        {
            Ok(_) => debug!(method = %method, uri = %uri, status = %status, "HttpResponseExtractor"),
            Err(_) => debug!(method = %method, uri = %uri, status = %status, "HttpResponseExtractor"),
        }

        if api_resp.err_code != 0 {
            anyhow::bail!("API biz error: status={} body={}", status, body_text);
        }

        Ok(api_resp)
    }
}
