//! 对象存储 HTTP API，用于文件上传
//! 参考: openim-sdk-core internal/third/file/upload.go

use super::routes;
use super::{make_client, HttpClient};
use super::response_extractor::extract_data;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

// ===== PartLimit =====
#[derive(Debug, Serialize)]
pub struct PartLimitReq {}

#[derive(Debug, Deserialize)]
pub struct PartLimitResp {
    #[serde(rename = "minPartSize")]
    pub min_part_size: i64,
    #[serde(rename = "maxPartSize")]
    pub max_part_size: i64,
    #[serde(rename = "maxNumSize")]
    pub max_num_size: i32,
}

// ===== InitiateMultipartUpload =====
#[derive(Debug, Serialize)]
pub struct InitiateMultipartUploadReq {
    pub hash: String,
    pub size: i64,
    #[serde(rename = "partSize")]
    pub part_size: i64,
    #[serde(rename = "maxParts")]
    pub max_parts: i32,
    pub cause: String,
    pub name: String,
    #[serde(rename = "contentType")]
    pub content_type: String,
}

#[derive(Debug, Deserialize)]
pub struct InitiateMultipartUploadResp {
    #[serde(default)]
    pub url: String,
    #[serde(default)]
    pub upload: Option<UploadInfo>,
}

#[derive(Debug, Deserialize)]
pub struct UploadInfo {
    #[serde(rename = "uploadID", default)]
    pub upload_id: String,
    #[serde(rename = "partSize", default)]
    pub part_size: i64,
    #[serde(rename = "expireTime", default)]
    pub expire_time: i64,
    #[serde(default)]
    pub sign: Option<AuthSignParts>,
}

#[derive(Debug, Deserialize)]
pub struct AuthSignParts {
    #[serde(default)]
    pub url: String,
    #[serde(default)]
    pub header: Option<Vec<KeyValue>>,
    #[serde(default)]
    pub query: Option<Vec<KeyValue>>,
    #[serde(default)]
    pub parts: Vec<SignPart>,
}

#[derive(Debug, Deserialize)]
pub struct KeyValue {
    pub key: String,
    pub values: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct SignPart {
    #[serde(rename = "partNumber", default)]
    pub part_number: i32,
    #[serde(default)]
    pub url: String,
    #[serde(default)]
    pub header: Option<Vec<KeyValue>>,
    #[serde(default)]
    pub query: Option<Vec<KeyValue>>,
}

// ===== AuthSign =====
#[derive(Debug, Serialize)]
pub struct AuthSignReq {
    #[serde(rename = "uploadID")]
    pub upload_id: String,
    #[serde(rename = "partNumbers")]
    pub part_numbers: Vec<i32>,
}

#[derive(Debug, Deserialize)]
pub struct AuthSignResp {
    #[serde(default)]
    pub url: String,
    #[serde(default)]
    pub header: Option<Vec<KeyValue>>,
    #[serde(default)]
    pub query: Option<Vec<KeyValue>>,
    #[serde(default)]
    pub parts: Vec<SignPart>,
}

// ===== CompleteMultipartUpload =====
#[derive(Debug, Serialize)]
pub struct CompleteMultipartUploadReq {
    #[serde(rename = "uploadID")]
    pub upload_id: String,
    pub parts: Vec<String>,
    pub name: String,
    #[serde(rename = "contentType")]
    pub content_type: String,
    pub cause: String,
}

#[derive(Debug, Deserialize)]
pub struct CompleteMultipartUploadResp {
    pub url: String,
}

// ===== AccessURL =====
#[derive(Debug, Serialize)]
pub struct AccessUrlReq {
    pub name: String,
}

#[derive(Debug, Deserialize)]
pub struct AccessUrlResp {
    pub url: String,
    #[serde(rename = "expirationTime")]
    pub expiration_time: i64,
}

#[derive(Clone)]
pub struct ObjectApi {
    client: HttpClient,
    api_base_url: String,
}

impl ObjectApi {
    pub fn new(client: reqwest::Client, api_base_url: String, token: &str) -> Self {
        Self {
            client: make_client(client, token),
            api_base_url,
        }
    }

    /// POST /object/part_limit
    pub async fn part_limit(&self) -> Result<PartLimitResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, routes::OBJECT_PART_LIMIT);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&PartLimitReq {})
            .send()
            .await
            .context("part_limit request failed")?;

        let json: serde_json::Value = resp.json().await.context("parse part_limit response failed")?;
        let err_code = json["errCode"].as_i64().unwrap_or(-1);
        if err_code != 0 {
            let err_msg = json["errMsg"].as_str().unwrap_or("Unknown error");
            return Err(anyhow::anyhow!("API error: {} - {}", err_code, err_msg));
        }

        let data: PartLimitResp = serde_json::from_value(json["data"].clone())
            .context("deserialize part_limit data failed")?;
        Ok(data)
    }

    /// POST /object/initiate_multipart_upload
    pub async fn initiate_multipart_upload(
        &self,
        req: InitiateMultipartUploadReq,
    ) -> Result<InitiateMultipartUploadResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, routes::OBJECT_INITIATE_MULTIPART_UPLOAD);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&req)
            .send()
            .await
            .context("initiate_multipart_upload request failed")?;

        let json: serde_json::Value = resp.json().await.context("parse initiate_multipart_upload response failed")?;

        tracing::debug!("initiate_multipart_upload response: {:?}", json);

        let data: InitiateMultipartUploadResp = serde_json::from_value(json["data"].clone())
            .context(format!("deserialize initiate_multipart_upload data failed, data: {:?}", json["data"]))?;
        Ok(data)
    }

    /// POST /object/auth_sign
    pub async fn auth_sign(&self, req: AuthSignReq) -> Result<AuthSignResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, routes::OBJECT_AUTH_SIGN);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&req)
            .send()
            .await
            .context("auth_sign request failed")?;

        let json: serde_json::Value = resp.json().await.context("parse auth_sign response failed")?;
        let err_code = json["errCode"].as_i64().unwrap_or(-1);
        if err_code != 0 {
            let err_msg = json["errMsg"].as_str().unwrap_or("Unknown error");
            return Err(anyhow::anyhow!("API error: {} - {}", err_code, err_msg));
        }

        let data: AuthSignResp = serde_json::from_value(json["data"].clone())
            .context("deserialize auth_sign data failed")?;
        Ok(data)
    }

    /// POST /object/complete_multipart_upload
    pub async fn complete_multipart_upload(
        &self,
        req: CompleteMultipartUploadReq,
    ) -> Result<CompleteMultipartUploadResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, routes::OBJECT_COMPLETE_MULTIPART_UPLOAD);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&req)
            .send()
            .await
            .context("complete_multipart_upload request failed")?;

        let json: serde_json::Value = resp.json().await.context("parse complete_multipart_upload response failed")?;
        let err_code = json["errCode"].as_i64().unwrap_or(-1);
        if err_code != 0 {
            let err_msg = json["errMsg"].as_str().unwrap_or("Unknown error");
            return Err(anyhow::anyhow!("API error: {} - {}", err_code, err_msg));
        }

        let data: CompleteMultipartUploadResp = serde_json::from_value(json["data"].clone())
            .context("deserialize complete_multipart_upload data failed")?;
        Ok(data)
    }

    /// POST /object/access_url
    pub async fn access_url(&self, req: AccessUrlReq) -> Result<AccessUrlResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, routes::OBJECT_ACCESS_URL);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&req)
            .send()
            .await
            .context("access_url request failed")?;

        let json: serde_json::Value = resp.json().await.context("parse access_url response failed")?;
        let err_code = json["errCode"].as_i64().unwrap_or(-1);
        if err_code != 0 {
            let err_msg = json["errMsg"].as_str().unwrap_or("Unknown error");
            return Err(anyhow::anyhow!("API error: {} - {}", err_code, err_msg));
        }

        let data: AccessUrlResp = serde_json::from_value(json["data"].clone())
            .context("deserialize access_url data failed")?;
        Ok(data)
    }

    /// PUT 请求上传分块到对象存储（无 token）
    pub async fn put_part(
        &self,
        url: &str,
        headers: HashMap<String, String>,
        data: Vec<u8>,
    ) -> Result<()> {
        let client = reqwest::Client::new();

        // Android 模拟器需要将 localhost 替换为 10.0.2.2（宿主机地址）
        let adjusted_url = if url.starts_with("http://localhost:") {
            url.replacen("http://localhost:", "http://10.0.2.2:", 1)
        } else if url.starts_with("http://127.0.0.1:") {
            url.replacen("http://127.0.0.1:", "http://10.0.2.2:", 1)
        } else {
            url.to_string()
        };

        // 从原始 URL 中提取 host 头部（预签名 URL 验证使用）
        // 预签名 URL 中的 host 必须与请求头中的 host 匹配
        let original_host = if url.starts_with("http://") {
            url.split("://")
                .nth(1)
                .and_then(|s| s.split('/').next())
                .unwrap_or("localhost")
                .to_string()
        } else {
            "localhost".to_string()
        };

        tracing::debug!("[FileUpload] put_part adjusted_url: {}, original_host: {}", adjusted_url, original_host);

        let mut req = client.put(&adjusted_url);

        // 设置原始 host 头部（用于预签名验证）
        req = req.header("host", &original_host);

        for (key, value) in headers {
            req = req.header(&key, value);
        }

        let resp = req
            .body(data)
            .send()
            .await
            .context("put_part request failed")?;

        let status = resp.status();
        if status.as_u16() / 100 != 2 {
            let body = resp.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!("PUT failed: status={}, body={}", status, body));
        }

        Ok(())
    }
}
