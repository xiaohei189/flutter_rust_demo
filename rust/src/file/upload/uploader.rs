use crate::db::misc_dao::UploadDao;
use crate::error::SdkError;
use crate::file::callbacks::UploadFileCallback;
use crate::file::upload::dto::{PartLimitResp, ProgressCallback, UploadResult};
use crate::file::upload::session::HashLock;
use crate::http::client::HttpApiClient;
use std::collections::HashMap;
use std::path::Path;
use std::sync::Arc;
use tokio::fs;
use tracing::info;

// ============================================================================
// FileUploader — 文件上传器
// 支持 form-data（中小文件）和 multipart 分片上传（大文件）
// ============================================================================

pub struct FileUploader {
    pub(super) http_client: Arc<HttpApiClient>,
    login_user_id: std::sync::RwLock<String>,
    pub(super) upload_dao: Option<Arc<UploadDao>>,
    pub(super) part_limit: std::sync::RwLock<Option<PartLimitResp>>,
    pub(super) uploading: std::sync::RwLock<HashMap<String, Arc<HashLock>>>,
}

impl FileUploader {
    pub fn new(http_client: Arc<HttpApiClient>) -> Self {
        Self {
            http_client,
            login_user_id: std::sync::RwLock::new(String::new()),
            upload_dao: None,
            part_limit: std::sync::RwLock::new(None),
            uploading: std::sync::RwLock::new(HashMap::new()),
        }
    }

    pub fn with_upload_dao(mut self, dao: Arc<UploadDao>) -> Self {
        self.upload_dao = Some(dao);
        self
    }

    pub fn set_login_user_id(&self, user_id: String) {
        *self.login_user_id.write().unwrap() = user_id;
    }

    // ========================================================================
    // 公开 API — 无进度回调
    // ========================================================================

    pub async fn upload_file(&self, file_path: &str, name: &str, content_type: Option<String>) -> crate::error::Result<UploadResult> {
        self.upload_file_with_progress(file_path, name, content_type, None).await
    }

    // ========================================================================
    // 公开 API — 带简单进度回调（兼容旧接口）
    // ========================================================================

    pub async fn upload_file_with_progress(&self, file_path: &str, name: &str, content_type: Option<String>, progress: Option<ProgressCallback>) -> crate::error::Result<UploadResult> {
        let cb = progress.map(|p| SimpleProgressCallback { progress: p });
        self.upload_file_with_callback(file_path, name, content_type, cb.as_ref().map(|c| c as &dyn UploadFileCallback)).await
    }

    // ========================================================================
    // 公开 API — 带细粒度回调（对齐 Go SDK UploadFileCallback）
    // ========================================================================

    pub async fn upload_file_with_callback(&self, file_path: &str, name: &str, content_type: Option<String>, cb: Option<&dyn UploadFileCallback>) -> crate::error::Result<UploadResult> {
        let path = Path::new(file_path);
        if !path.exists() {
            return Err(SdkError::file_upload(format!("文件不存在: {}", file_path)));
        }

        let file_size = fs::metadata(path).await.map_err(|e| SdkError::file_upload(format!("获取文件信息失败: {}", e)))?.len() as i64;

        let detected_content_type = content_type.unwrap_or_else(|| self.detect_content_type(path.file_name().and_then(|n| n.to_str()).unwrap_or("")));

        let user_id = self.login_user_id.read().unwrap().clone();
        let prefixed_name = if user_id.is_empty() { name.to_string() } else { format!("{}/{}", user_id, name) };

        // 根据文件大小决定上传方式
        match self.get_part_limit().await {
            Ok(limit) => {
                let threshold = limit.min_part_size * limit.max_num_size as i64;
                if file_size > threshold {
                    // 大文件：使用分片上传
                    info!("文件 {} 大小 {} 超过阈值 {}，使用分片上传", prefixed_name, file_size, threshold);
                    self.upload_file_multipart(file_path, &prefixed_name, &detected_content_type, file_size, cb).await
                } else {
                    // 中小文件：使用 form-data 上传
                    info!("文件 {} 大小 {}，使用 form-data 上传", prefixed_name, file_size);
                    self.upload_file_form_data(file_path, &prefixed_name, &detected_content_type, file_size, cb).await
                }
            }
            Err(_) => {
                // 无法获取 part_limit 时，使用 form-data 上传
                info!("无法获取分片限制，使用 form-data 上传: {}", prefixed_name);
                self.upload_file_form_data(file_path, &prefixed_name, &detected_content_type, file_size, cb).await
            }
        }
    }

    pub async fn upload_image(&self, file_path: &str, progress: Option<ProgressCallback>) -> crate::error::Result<UploadResult> {
        let path = Path::new(file_path);
        let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("image.jpg").to_string();
        let content_type = self.detect_content_type(&name);
        self.upload_file_with_progress(file_path, &name, Some(content_type), progress).await
    }

    pub async fn upload_video(&self, file_path: &str, progress: Option<ProgressCallback>) -> crate::error::Result<UploadResult> {
        let path = Path::new(file_path);
        let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("video.mp4").to_string();
        self.upload_file_with_progress(file_path, &name, Some("video/mp4".to_string()), progress).await
    }

    pub async fn upload_audio(&self, file_path: &str, progress: Option<ProgressCallback>) -> crate::error::Result<UploadResult> {
        let path = Path::new(file_path);
        let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("audio.mp3").to_string();
        self.upload_file_with_progress(file_path, &name, Some("audio/mpeg".to_string()), progress).await
    }

    // ========================================================================
    // 并发锁（对齐 Go SDK lockHash/unlockHash）
    // ========================================================================

    pub(crate) async fn lock_hash(&self, hash: &str) -> Arc<HashLock> {
        let lock = {
            let mut map = self.uploading.write().unwrap();
            map.entry(hash.to_string())
                .or_insert_with(|| {
                    Arc::new(HashLock {
                        count: std::sync::atomic::AtomicI32::new(0),
                        mutex: tokio::sync::Mutex::new(()),
                    })
                })
                .clone()
        };
        lock.count.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
        let guard = lock.mutex.lock().await;
        // 为了保持锁的生命周期，我们需要泄漏 guard
        // 但这是 Rust，我们换一种方式：用 ManuallyDrop
        std::mem::forget(guard);
        lock
    }

    pub(crate) async fn unlock_hash(&self, hash: &str, lock: &Arc<HashLock>) {
        let count = lock.count.fetch_sub(1, std::sync::atomic::Ordering::SeqCst);
        if count <= 1 {
            let mut map = self.uploading.write().unwrap();
            map.remove(hash);
        }
    }

    // ========================================================================
    // 工具方法
    // ========================================================================

    fn detect_content_type(&self, file_name: &str) -> String {
        let extension = file_name.split('.').next_back().unwrap_or("").to_lowercase();
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

// ============================================================================
// 简单进度回调适配器
// ============================================================================

struct SimpleProgressCallback {
    progress: ProgressCallback,
}

impl UploadFileCallback for SimpleProgressCallback {
    fn open(&self, _size: i64) {}
    fn part_size(&self, _part_size: i64, _num: i32) {}
    fn hash_part_progress(&self, _index: i32, _size: i64, _part_hash: &str) {}
    fn hash_part_complete(&self, _parts_hash: &str, _file_hash: &str) {}
    fn upload_id(&self, _upload_id: &str) {}
    fn upload_part_complete(&self, _index: i32, _part_size: i64, _part_hash: &str) {}
    fn upload_complete(&self, file_size: i64, stream_size: i64, _storage_size: i64) {
        if file_size > 0 {
            let pct = ((stream_size as u64 * 100) / file_size as u64).min(100) as u8;
            (self.progress)(pct);
        }
    }
    fn complete(&self, _size: i64, _url: &str, _typ: i32) {
        (self.progress)(100);
    }
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_content_type() {
        let http_client = Arc::new(HttpApiClient::new("http://example.com".to_string(), "token".to_string(), "op_id".to_string()));
        let uploader = FileUploader::new(http_client);

        assert_eq!(uploader.detect_content_type("photo.jpg"), "image/jpeg");
        assert_eq!(uploader.detect_content_type("image.png"), "image/png");
        assert_eq!(uploader.detect_content_type("video.mp4"), "video/mp4");
        assert_eq!(uploader.detect_content_type("audio.mp3"), "audio/mpeg");
        assert_eq!(uploader.detect_content_type("document.pdf"), "application/pdf");
        assert_eq!(uploader.detect_content_type("unknown.xyz"), "application/octet-stream");
    }
}
