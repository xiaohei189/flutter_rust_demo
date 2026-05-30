use crate::domain::error::types::{Result, SdkError};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::Duration;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ApiResponse<T> {
    #[serde(rename = "errCode")]
    pub err_code: i32,
    #[serde(rename = "errMsg")]
    pub err_msg: String,
    pub data: Option<T>,
}

impl<T> ApiResponse<T> {
    pub fn into_result(self) -> Result<T> 
    where
        T: Default,
    {
        if self.err_code == 0 {
            Ok(self.data.unwrap_or_default())
        } else {
            Err(SdkError::api(self.err_code, &self.err_msg))
        }
    }
}

#[derive(Clone)]
pub struct HttpApiClient {
    client: Client,
    base_url: Arc<String>,
    token: Arc<String>,
    operation_id: Arc<String>,
    timeout: Duration,
}

impl HttpApiClient {
    pub fn new(base_url: String, token: String, operation_id: String) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .expect("Failed to create HTTP client");

        Self {
            client,
            base_url: Arc::new(base_url),
            token: Arc::new(token),
            operation_id: Arc::new(operation_id),
            timeout: Duration::from_secs(30),
        }
    }

    pub fn with_timeout(mut self, timeout: Duration) -> Self {
        self.timeout = timeout;
        self
    }

    pub async fn post<T: Serialize, R: for<'de> Deserialize<'de> + Default>(
        &self,
        route: &str,
        body: &T,
    ) -> Result<R> {
        let url = format!("{}{}", *self.base_url, route);

        // 调试：打印请求信息
        let body_json = serde_json::to_string(body).unwrap_or_default();
        tracing::debug!("HTTP POST {} - Body: {}", route, body_json);

        let response = self
            .client
            .post(&url)
            .header("token", &*self.token)
            .header("operationID", &*self.operation_id)
            .timeout(self.timeout)
            .json(body)
            .send()
            .await?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            tracing::error!("HTTP POST {} failed - Status: {}, Body: {}", route, status, body);
            return Err(SdkError::http(status, format!("HTTP 错误: {}", body)));
        }

        // 先读取原始响应，再解析
        let raw_bytes = response.bytes().await?;
        let raw_str = String::from_utf8_lossy(&raw_bytes);
        tracing::debug!("HTTP POST {} - Raw Response: {}", route, raw_str);

        let api_resp: ApiResponse<R> = serde_json::from_slice(&raw_bytes)
            .map_err(|e| {
                tracing::error!("Failed to parse response: {} - Raw: {}", e, raw_str);
                SdkError::unknown(&format!("响应解析错误: {}", e))
            })?;
        api_resp.into_result()
    }

    pub async fn post_no_auth<T: Serialize, R: for<'de> Deserialize<'de> + Default>(
        &self,
        route: &str,
        body: &T,
    ) -> Result<R> {
        let url = format!("{}{}", *self.base_url, route);

        let response = self
            .client
            .post(&url)
            .timeout(self.timeout)
            .json(body)
            .send()
            .await?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(SdkError::http(status, format!("HTTP 错误: {}", body)));
        }

        let api_resp: ApiResponse<R> = response.json().await?;
        api_resp.into_result()
    }

    pub async fn get<R: for<'de> Deserialize<'de> + Default>(&self, route: &str) -> Result<R> {
        let url = format!("{}{}", *self.base_url, route);

        let response = self
            .client
            .get(&url)
            .header("token", &*self.token)
            .header("operationID", &*self.operation_id)
            .timeout(self.timeout)
            .send()
            .await?;

        let status = response.status().as_u16();
        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(SdkError::http(status, format!("HTTP 错误: {}", body)));
        }

        let api_resp: ApiResponse<R> = response.json().await?;
        api_resp.into_result()
    }

    pub fn update_token(&mut self, token: String) {
        self.token = Arc::new(token);
    }

    pub fn update_operation_id(&mut self, operation_id: String) {
        self.operation_id = Arc::new(operation_id);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_api_response_success() {
        let resp: ApiResponse<String> = ApiResponse {
            err_code: 0,
            err_msg: String::new(),
            data: Some("hello".into()),
        };
        assert!(resp.into_result().is_ok());
    }

    #[test]
    fn test_api_response_error() {
        let resp: ApiResponse<String> = ApiResponse {
            err_code: 10001,
            err_msg: "user not found".into(),
            data: None,
        };
        let result = resp.into_result();
        assert!(result.is_err());
    }

    #[test]
    fn test_api_response_no_data() {
        let resp: ApiResponse<String> = ApiResponse {
            err_code: 0,
            err_msg: String::new(),
            data: None,
        };
        let result = resp.into_result();
        assert!(result.is_err());
    }
}
