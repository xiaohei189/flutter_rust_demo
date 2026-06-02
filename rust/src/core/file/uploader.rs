use crate::domain::error::types::{Result, SdkError};
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{INITIATE_FORM_DATA, COMPLETE_FORM_DATA};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;
use std::sync::Arc;
use tokio::fs;
use tracing::info;

/// POST /object/initiate_form_data 请求
#[derive(Clone, Debug, Serialize)]
pub struct InitiateFormDataReq {
    pub name: String,
    pub size: i64,
    #[serde(rename = "contentType")]
    pub content_type: String,
    pub group: String,
    pub millisecond: i64,
    pub absolute: bool,
}

/// POST /object/initiate_form_data 响应
#[derive(Clone, Debug, Deserialize, Default)]
pub struct InitiateFormDataResp {
    pub id: String,
    pub url: String,
    pub file: String,
    #[serde(default)]
    pub header: Option<Vec<KeyValue>>,
    #[serde(rename = "formData")]
    #[serde(default)]
    pub form_data: HashMap<String, String>,
    pub expires: i64,
    #[serde(rename = "successCodes")]
    #[serde(default)]
    pub success_codes: Vec<i32>,
}

#[derive(Clone, Debug, Deserialize)]
pub struct KeyValue {
    pub key: String,
    pub values: Vec<String>,
}

/// POST /object/complete_form_data 请求
#[derive(Clone, Debug, Serialize)]
pub struct CompleteFormDataReq {
    pub id: String,
    #[serde(rename = "urlPrefix")]
    pub url_prefix: String,
}

/// POST /object/complete_form_data 响应
#[derive(Clone, Debug, Deserialize, Default)]
pub struct CompleteFormDataResp {
    pub url: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UploadResult {
    pub url: String,
    pub file_id: String,
    pub size: u64,
    #[serde(rename = "contentType")]
    pub content_type: String,
}

pub struct FileUploader {
    http_client: Arc<HttpApiClient>,
    login_user_id: std::sync::RwLock<String>,
}

impl FileUploader {
    pub fn new(http_client: Arc<HttpApiClient>) -> Self {
        Self {
            http_client,
            login_user_id: std::sync::RwLock::new(String::new()),
        }
    }

    pub fn set_login_user_id(&self, user_id: String) {
        *self.login_user_id.write().unwrap() = user_id;
    }

    /// 使用 form-data 接口上传文件（适用于中小文件）
    pub async fn upload_file(&self, file_path: &str, name: &str, content_type: Option<String>) -> Result<UploadResult> {
        let path = Path::new(file_path);
        if !path.exists() {
            return Err(SdkError::unknown(format!("文件不存在: {}", file_path)));
        }

        let file_data = fs::read(path).await
            .map_err(|e| SdkError::unknown(format!("读取文件失败: {}", e)))?;

        let file_size = file_data.len() as i64;
        let detected_content_type = content_type.unwrap_or_else(|| {
            self.detect_content_type(path.file_name().and_then(|n| n.to_str()).unwrap_or(""))
        });

        // 服务端要求文件名以用户 ID 为前缀
        let user_id = self.login_user_id.read().unwrap().clone();
        let prefixed_name = if user_id.is_empty() {
            name.to_string()
        } else {
            format!("{}/{}", user_id, name)
        };

        info!("开始上传文件: name={}, size={}, type={}", prefixed_name, file_size, detected_content_type);

        // 1. 调用 initiate_form_data 获取上传信息
        let req = InitiateFormDataReq {
            name: prefixed_name,
            size: file_size,
            content_type: detected_content_type.clone(),
            group: String::new(),
            millisecond: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_millis() as i64,
            absolute: false,
        };

        let resp: InitiateFormDataResp = self.http_client.post(INITIATE_FORM_DATA, &req).await?;
        info!("initiate_form_data 响应: id={}, url={}", resp.id, resp.url);

        // 2. 使用 multipart/form-data 上传文件
        let client = reqwest::Client::new();
        let mut form = reqwest::multipart::Form::new();

        // 添加 form_data 中的隐藏字段
        for (key, value) in &resp.form_data {
            form = form.text(key.clone(), value.clone());
        }

        // 添加文件字段（file 字段名从响应中获取）
        let part = reqwest::multipart::Part::bytes(file_data)
            .file_name(name.to_string())
            .mime_str(&detected_content_type)
            .map_err(|e| SdkError::unknown(format!("MIME 类型错误: {}", e)))?;
        form = form.part(resp.file.clone(), part);

        let upload_url = resp.url.clone();
        info!("上传到: {}", upload_url);

        let upload_resp = client
            .post(&upload_url)
            .multipart(form)
            .send()
            .await
            .map_err(|e| SdkError::unknown(format!("上传请求失败: {}", e)))?;

        let status = upload_resp.status();
        let resp_body = upload_resp.text().await.unwrap_or_default();
        info!("上传响应: status={}, body={:.200}", status, resp_body);

        if !status.is_success() {
            return Err(SdkError::unknown(format!("上传失败, 状态码: {}, body: {}", status, resp_body)));
        }

        // 3. 调用 complete_form_data 获取最终 URL
        let complete_req = CompleteFormDataReq {
            id: resp.id,
            url_prefix: String::new(),
        };

        let complete_resp: CompleteFormDataResp = self.http_client.post(COMPLETE_FORM_DATA, &complete_req).await?;
        info!("文件上传完成: url={}", complete_resp.url);

        Ok(UploadResult {
            url: complete_resp.url.clone(),
            file_id: complete_resp.url,
            size: file_size as u64,
            content_type: detected_content_type,
        })
    }

    pub async fn upload_image(&self, file_path: &str) -> Result<UploadResult> {
        let path = Path::new(file_path);
        let name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("image.jpg")
            .to_string();
        let content_type = self.detect_content_type(&name);
        self.upload_file(file_path, &name, Some(content_type)).await
    }

    pub async fn upload_video(&self, file_path: &str) -> Result<UploadResult> {
        let path = Path::new(file_path);
        let name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("video.mp4")
            .to_string();
        self.upload_file(file_path, &name, Some("video/mp4".to_string())).await
    }

    pub async fn upload_audio(&self, file_path: &str) -> Result<UploadResult> {
        let path = Path::new(file_path);
        let name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("audio.mp3")
            .to_string();
        self.upload_file(file_path, &name, Some("audio/mpeg".to_string())).await
    }

    fn detect_content_type(&self, file_name: &str) -> String {
        let extension = file_name.split('.').last().unwrap_or("").to_lowercase();
        match extension.as_str() {
            "jpg" | "jpeg" => "image/jpeg".to_string(),
            "png" => "image/png".to_string(),
            "gif" => "image/gif".to_string(),
            "webp" => "image/webp".to_string(),
            "mp4" => "video/mp4".to_string(),
            "mov" => "video/quicktime".to_string(),
            "mp3" => "audio/mpeg".to_string(),
            "wav" => "audio/wav".to_string(),
            "pdf" => "application/pdf".to_string(),
            "doc" => "application/msword".to_string(),
            "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document".to_string(),
            "txt" => "text/plain".to_string(),
            _ => "application/octet-stream".to_string(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_content_type() {
        let http_client = Arc::new(HttpApiClient::new(
            "http://example.com".to_string(),
            "token".to_string(),
            "op_id".to_string(),
        ));
        let uploader = FileUploader::new(http_client);

        assert_eq!(uploader.detect_content_type("photo.jpg"), "image/jpeg");
        assert_eq!(uploader.detect_content_type("image.png"), "image/png");
        assert_eq!(uploader.detect_content_type("video.mp4"), "video/mp4");
        assert_eq!(uploader.detect_content_type("audio.mp3"), "audio/mpeg");
        assert_eq!(uploader.detect_content_type("document.pdf"), "application/pdf");
        assert_eq!(uploader.detect_content_type("unknown.xyz"), "application/octet-stream");
    }
}
