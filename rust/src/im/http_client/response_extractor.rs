use crate::im::model::ApiResponse;
use anyhow::{Context as _, Result};
use http;
use reqwest::Response;
use serde::de::DeserializeOwned;

/// 从 reqwest::Response 解析并返回 data 字段
pub async fn extract_data<T: DeserializeOwned>(response: Response) -> Result<T> {
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

    if api_resp.err_code != 0 {
        anyhow::bail!("API biz error: status={} body={}", status, body_text);
    }

    api_resp
        .data
        .with_context(|| format!("API response missing data field (data==null): errCode={} errMsg={}", api_resp.err_code, api_resp.err_msg))
}
