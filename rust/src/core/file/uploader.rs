use crate::domain::error::types::{Result, SdkError};
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{INITIATE_UPLOAD, COMPLETE_UPLOAD};
use serde::{Deserialize, Serialize};
use std::path::Path;
use std::sync::Arc;
use tokio::fs;
use tokio::sync::RwLock;
use tracing::info;

#[derive(Clone, Debug, Serialize, Deserialize)]
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

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SignPart {
    #[serde(rename = "partNumber")]
    pub part_number: i32,
    pub url: String,
    pub query: Vec<QueryParam>,
    pub header: Vec<HeaderParam>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct QueryParam {
    pub key: String,
    pub values: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HeaderParam {
    pub key: String,
    pub values: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AuthSignParts {
    pub url: String,
    pub query: Vec<QueryParam>,
    pub header: Vec<HeaderParam>,
    pub parts: Vec<SignPart>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UploadInfo {
    #[serde(rename = "uploadID")]
    pub upload_id: String,
    #[serde(rename = "partSize")]
    pub part_size: i64,
    #[serde(rename = "sign")]
    pub sign: AuthSignParts,
    #[serde(rename = "expireTime")]
    pub expire_time: i64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct InitiateMultipartUploadResp {
    pub url: String,
    pub upload: Option<UploadInfo>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AuthSignReq {
    #[serde(rename = "uploadID")]
    pub upload_id: String,
    #[serde(rename = "partNumbers")]
    pub part_numbers: Vec<i32>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AuthSignResp {
    pub url: String,
    pub query: Vec<QueryParam>,
    pub header: Vec<HeaderParam>,
    pub parts: Vec<SignPart>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CompleteMultipartUploadReq {
    #[serde(rename = "uploadID")]
    pub upload_id: String,
    pub parts: Vec<String>,
    pub name: String,
    #[serde(rename = "contentType")]
    pub content_type: String,
    pub cause: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CompleteMultipartUploadResp {
    pub url: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PartLimitResp {
    #[serde(rename = "minPartSize")]
    pub min_part_size: i64,
    #[serde(rename = "maxPartSize")]
    pub max_part_size: i64,
    #[serde(rename = "maxNumSize")]
    pub max_num_size: i64,
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
    login_user_id: Arc<RwLock<String>>,
    part_limit: Arc<RwLock<Option<PartLimitResp>>>,
}

impl FileUploader {
    pub fn new(http_client: Arc<HttpApiClient>) -> Self {
        Self {
            http_client,
            login_user_id: Arc::new(RwLock::new(String::new())),
            part_limit: Arc::new(RwLock::new(None)),
        }
    }

    pub fn set_login_user_id(&self, user_id: String) {
        let mut guard = self.login_user_id.try_write().unwrap();
        *guard = user_id;
    }

    pub async fn upload_file(&self, file_path: &str, name: &str, content_type: Option<String>) -> Result<UploadResult> {
        let path = Path::new(file_path);
        if !path.exists() {
            return Err(SdkError::unknown(format!("文件不存在: {}", file_path)));
        }

        let file_data = fs::read(path).await
            .map_err(|e| SdkError::unknown(format!("读取文件失败: {}", e)))?;

        let file_size = file_data.len() as i64;
        let file_name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown");

        let detected_content_type = content_type.unwrap_or_else(|| self.detect_content_type(file_name));

        let user_id = self.login_user_id.read().await.clone();
        let prefix = format!("{}/", user_id);
        let full_name = if name.starts_with(&prefix) {
            name.to_string()
        } else {
            format!("{}{}", prefix, name)
        };

        let file_md5 = Self::calculate_md5(&file_data);
        let part_md5 = file_md5.clone();

        info!("开始上传文件: name={}, size={}, md5={}", full_name, file_size, file_md5);

        let part_size = self.get_part_size(file_size).await?;
        let part_num = self.get_part_num(file_size, part_size);

        let req = InitiateMultipartUploadReq {
            hash: part_md5.clone(),
            size: file_size,
            part_size,
            max_parts: std::cmp::min(20, part_num as i32),
            cause: String::new(),
            name: full_name.clone(),
            content_type: detected_content_type.clone(),
        };

        let resp: InitiateMultipartUploadResp = self.http_client.post(INITIATE_UPLOAD, &req).await?;

        if resp.upload.is_none() {
            info!("文件已存在，直接返回 URL");
            return Ok(UploadResult {
                url: resp.url,
                file_id: part_md5,
                size: file_size as u64,
                content_type: detected_content_type,
            });
        }

        let upload_info = resp.upload.unwrap();

        if part_num <= 1 {
            let url = self.upload_single_part(&file_data, &upload_info).await?;
            return Ok(UploadResult {
                url,
                file_id: part_md5,
                size: file_size as u64,
                content_type: detected_content_type,
            });
        }

        let part_md5s = self.calculate_part_md5s(&file_data, part_size, part_num);

        let complete_req = CompleteMultipartUploadReq {
            upload_id: upload_info.upload_id,
            parts: part_md5s,
            name: full_name,
            content_type: detected_content_type.clone(),
            cause: String::new(),
        };

        let complete_resp: CompleteMultipartUploadResp = self.http_client.post(COMPLETE_UPLOAD, &complete_req).await?;

        info!("文件上传成功: url={}", complete_resp.url);

        Ok(UploadResult {
            url: complete_resp.url,
            file_id: part_md5,
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
        self.upload_file(file_path, &name, Some("image/jpeg".to_string())).await
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

    async fn get_part_size(&self, file_size: i64) -> Result<i64> {
        let mut guard = self.part_limit.write().await;
        if guard.is_none() {
            let resp: PartLimitResp = self.http_client.post("/object/part_limit", &()).await?;
            *guard = Some(resp);
        }

        let limit = guard.as_ref().unwrap();

        if file_size <= 0 {
            return Err(SdkError::unknown("文件大小必须大于 0"));
        }

        let max_total = limit.max_part_size * limit.max_num_size;
        if file_size > max_total {
            return Err(SdkError::unknown(format!("文件大小不能超过 {} 字节", max_total)));
        }

        if file_size <= limit.min_part_size * limit.max_num_size {
            Ok(limit.min_part_size)
        } else {
            let part_size = file_size / limit.max_num_size;
            if file_size % limit.max_num_size != 0 {
                Ok(part_size + 1)
            } else {
                Ok(part_size)
            }
        }
    }

    fn get_part_num(&self, file_size: i64, part_size: i64) -> usize {
        let part_num = (file_size / part_size) as usize;
        if file_size % part_size != 0 {
            part_num + 1
        } else {
            part_num
        }
    }

    fn calculate_md5(data: &[u8]) -> String {
        use md5::{Md5, Digest};
        let mut hasher = Md5::new();
        hasher.update(data);
        format!("{:x}", hasher.finalize())
    }

    fn calculate_part_md5s(&self, data: &[u8], part_size: i64, part_num: usize) -> Vec<String> {
        use md5::{Md5, Digest};
        let mut part_md5s = Vec::with_capacity(part_num);

        for i in 0..part_num {
            let start = (i as i64 * part_size) as usize;
            let end = std::cmp::min(start + part_size as usize, data.len());
            let part_data = &data[start..end];

            let mut hasher = Md5::new();
            hasher.update(part_data);
            let md5 = format!("{:x}", hasher.finalize());
            part_md5s.push(md5);
        }

        part_md5s
    }

    async fn upload_single_part(&self, data: &[u8], upload_info: &UploadInfo) -> Result<String> {
        let sign = &upload_info.sign;
        let url = if sign.parts.is_empty() {
            &sign.url
        } else {
            &sign.parts[0].url
        };

        let client = reqwest::Client::new();
        let resp = client
            .put(url)
            .body(data.to_vec())
            .send()
            .await
            .map_err(|e| SdkError::unknown(format!("上传失败: {}", e)))?;

        if !resp.status().is_success() {
            return Err(SdkError::unknown(format!("上传失败, 状态码: {}", resp.status())));
        }

        Ok(upload_info.sign.url.clone())
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

    #[test]
    fn test_calculate_md5() {
        let data = b"hello world";
        let md5 = FileUploader::calculate_md5(data);
        assert_eq!(md5.len(), 32);
    }

    #[test]
    fn test_get_part_num() {
        let http_client = Arc::new(HttpApiClient::new(
            "http://example.com".to_string(),
            "token".to_string(),
            "op_id".to_string(),
        ));
        let uploader = FileUploader::new(http_client);

        assert_eq!(uploader.get_part_num(1000, 500), 2);
        assert_eq!(uploader.get_part_num(1000, 1000), 1);
        assert_eq!(uploader.get_part_num(1001, 1000), 2);
    }

    #[test]
    fn test_initiate_multipart_upload_req_serialization() {
        let req = InitiateMultipartUploadReq {
            hash: "abc123".to_string(),
            size: 1000000,
            part_size: 100000,
            max_parts: 10,
            cause: String::new(),
            name: "user123/test.jpg".to_string(),
            content_type: "image/jpeg".to_string(),
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("partSize"));
        assert!(json.contains("maxParts"));
        assert!(json.contains("contentType"));
    }
}
