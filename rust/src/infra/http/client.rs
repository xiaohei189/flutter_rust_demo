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
    pub fn into_result(self) -> Result<T> {
        if self.err_code == 0 {
            self.data.ok_or_else(|| SdkError::unknown("响应数据为空"))
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

    pub async fn post<T: Serialize, R: for<'de> Deserialize<'de>>(
        &self,
        route: &str,
        body: &T,
    ) -> Result<R> {
        let url = format!("{}{}", *self.base_url, route);

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
            return Err(SdkError::http(status, format!("HTTP 错误: {}", body)));
        }

        let api_resp: ApiResponse<R> = response.json().await?;
        api_resp.into_result()
    }

    pub async fn post_no_auth<T: Serialize, R: for<'de> Deserialize<'de>>(
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

    pub async fn get<R: for<'de> Deserialize<'de>>(&self, route: &str) -> Result<R> {
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
