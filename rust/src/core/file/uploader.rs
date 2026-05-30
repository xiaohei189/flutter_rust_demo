use crate::domain::error::types::{Result, SdkError};
use crate::infra::http::client::HttpApiClient;
use serde::{Deserialize, Serialize};
use std::path::Path;
use std::sync::Arc;
use tokio::fs;
use tracing::{debug, info};

/// 文件上传结果
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UploadResult {
    /// 文件 URL
    pub url: String,
    /// 文件 ID
    pub file_id: String,
    /// 文件大小（字节）
    pub size: u64,
    /// 文件类型
    pub content_type: String,
}

/// 文件上传服务
pub struct FileUploader {
    /// HTTP 客户端
    http_client: Arc<HttpApiClient>,
    /// 上传 API 基础 URL
    upload_base_url: String,
}

impl FileUploader {
    pub fn new(http_client: Arc<HttpApiClient>, upload_base_url: String) -> Self {
        Self {
            http_client,
            upload_base_url,
        }
    }

    /// 上传文件
    pub async fn upload_file(&self, file_path: &str) -> Result<UploadResult> {
        let path = Path::new(file_path);
        
        if !path.exists() {
            return Err(SdkError::unknown(format!("文件不存在: {}", file_path)));
        }

        let file_data = fs::read(path).await
            .map_err(|e| SdkError::unknown(format!("读取文件失败: {}", e)))?;

        let file_size = file_data.len() as u64;
        let file_name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown");

        let content_type = self.detect_content_type(file_name);

        debug!("开始上传文件: name={}, size={}, type={}", file_name, file_size, content_type);

        // 构建 multipart 表单上传
        let upload_url = format!("{}/upload", self.upload_base_url);
        
        // 这里简化处理，使用 JSON 上传
        let body = serde_json::json!({
            "file_name": file_name,
            "content_type": content_type,
            "file_size": file_size,
        });

        let result: UploadResult = self.http_client.post(&upload_url, &body).await?;

        info!("文件上传成功: url={}", result.url);

        Ok(result)
    }

    /// 上传图片
    pub async fn upload_image(&self, file_path: &str) -> Result<UploadResult> {
        self.upload_file(file_path).await
    }

    /// 上传视频
    pub async fn upload_video(&self, file_path: &str) -> Result<UploadResult> {
        self.upload_file(file_path).await
    }

    /// 上传音频
    pub async fn upload_audio(&self, file_path: &str) -> Result<UploadResult> {
        self.upload_file(file_path).await
    }

    /// 检测文件类型
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
    use crate::domain::event::EventBus;

    #[test]
    fn test_detect_content_type() {
        let event_bus = Arc::new(EventBus::new());
        let http_client = Arc::new(HttpApiClient::new(
            "http://example.com".to_string(),
            "token".to_string(),
            "op_id".to_string(),
        ));
        let uploader = FileUploader::new(http_client, "http://upload.example.com".to_string());

        assert_eq!(uploader.detect_content_type("photo.jpg"), "image/jpeg");
        assert_eq!(uploader.detect_content_type("image.png"), "image/png");
        assert_eq!(uploader.detect_content_type("video.mp4"), "video/mp4");
        assert_eq!(uploader.detect_content_type("audio.mp3"), "audio/mpeg");
        assert_eq!(uploader.detect_content_type("document.pdf"), "application/pdf");
        assert_eq!(uploader.detect_content_type("unknown.xyz"), "application/octet-stream");
    }
}
