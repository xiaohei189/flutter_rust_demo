use crate::domain::error::types::{Result, SdkError};
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{INITIATE_FORM_DATA, COMPLETE_FORM_DATA};
use futures_util::TryStreamExt;
use http_body_util::BodyExt;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;
use std::sync::Arc;
use tokio::fs;
use tokio::io::{AsyncReadExt, BufReader};
use tracing::info;

/// 进度回调类型：接收 0-100 的进度值（使用 Arc 以便在异步流中共享）
pub type ProgressCallback = std::sync::Arc<dyn Fn(u8) + Send + Sync>;

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
        self.upload_file_with_progress(file_path, name, content_type, None).await
    }

    /// 使用 form-data 接口上传文件，支持真实字节级进度回调
    ///
    /// `progress` 为可选的回调函数，每读取一个 chunk（64KB）后调用一次，
    /// 传入 0-100 的进度百分比。为避免频繁回调，至少间隔 5% 或 80ms。
    pub async fn upload_file_with_progress(
        &self,
        file_path: &str,
        name: &str,
        content_type: Option<String>,
        progress: Option<ProgressCallback>,
    ) -> Result<UploadResult> {
        let path = Path::new(file_path);
        if !path.exists() {
            return Err(SdkError::unknown(format!("文件不存在: {}", file_path)));
        }

        let file_size = fs::metadata(path).await
            .map_err(|e| SdkError::unknown(format!("获取文件信息失败: {}", e)))?
            .len();

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
            size: file_size as i64,
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

        // 2. 使用 multipart/form-data 上传文件，带进度跟踪
        let client = reqwest::Client::new();
        let mut form = reqwest::multipart::Form::new();

        // 添加 form_data 中的隐藏字段
        for (key, value) in &resp.form_data {
            form = form.text(key.clone(), value.clone());
        }

        // 添加文件字段：分块读取 + 进度回调
        let file = fs::File::open(path).await
            .map_err(|e| SdkError::unknown(format!("打开文件失败: {}", e)))?;
        let mut reader = BufReader::with_capacity(65536, file); // 64KB buffer

        let total_size = file_size;
        let mut uploaded: u64 = 0;
        let mut last_reported_pct: u8 = 0;
        let mut last_reported_time = std::time::Instant::now();

        // 使用 unfold 创建带进度追踪的字节流
        let progress_cb = progress.clone();
        let stream = futures_util::stream::unfold(
            (reader, uploaded, last_reported_pct, last_reported_time),
            move |(mut reader, mut uploaded, mut last_pct, mut last_time)| {
                let cb = progress_cb.clone();
                async move {
                let mut buf = vec![0u8; 65536]; // 64KB chunk
                match reader.read(&mut buf).await {
                    Ok(0) => None, // EOF
                    Ok(n) => {
                        uploaded += n as u64;
                        if total_size > 0 {
                            let pct = ((uploaded * 100) / total_size).min(100) as u8;
                            let now = std::time::Instant::now();
                            if pct >= last_pct + 5
                                || (pct > last_pct && now.duration_since(last_time) >= std::time::Duration::from_millis(80))
                            {
                                if let Some(ref cb) = cb {
                                    cb(pct);
                                }
                                last_pct = pct;
                                last_time = now;
                            }
                        }
                        buf.truncate(n);
                        Some((Ok(bytes::Bytes::from(buf)), (reader, uploaded, last_pct, last_time)))
                    }
                    Err(e) => Some((Err(e), (reader, uploaded, last_pct, last_time))),
                }
                }
            },
        );

        let stream_body = http_body_util::StreamBody::new(
            stream.map_ok(|b| http_body::Frame::data(b))
        );
        let body = reqwest::Body::wrap(stream_body);
        let part = reqwest::multipart::Part::stream(body)
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

        // 上传完成，确保进度回调到 100%
        if let Some(ref cb) = progress {
            cb(100);
        }
        info!("文件上传完成: url={}", complete_resp.url);

        Ok(UploadResult {
            url: complete_resp.url.clone(),
            file_id: complete_resp.url,
            size: file_size,
            content_type: detected_content_type,
        })
    }

    pub async fn upload_image(&self, file_path: &str, progress: Option<ProgressCallback>) -> Result<UploadResult> {
        let path = Path::new(file_path);
        let name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("image.jpg")
            .to_string();
        let content_type = self.detect_content_type(&name);
        self.upload_file_with_progress(file_path, &name, Some(content_type), progress).await
    }

    pub async fn upload_video(&self, file_path: &str, progress: Option<ProgressCallback>) -> Result<UploadResult> {
        let path = Path::new(file_path);
        let name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("video.mp4")
            .to_string();
        self.upload_file_with_progress(file_path, &name, Some("video/mp4".to_string()), progress).await
    }

    pub async fn upload_audio(&self, file_path: &str, progress: Option<ProgressCallback>) -> Result<UploadResult> {
        let path = Path::new(file_path);
        let name = path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("audio.mp3")
            .to_string();
        self.upload_file_with_progress(file_path, &name, Some("audio/mpeg".to_string()), progress).await
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
