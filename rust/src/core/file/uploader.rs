use crate::domain::error::{Result, SdkError};
use crate::infra::database::misc_dao::UploadDao;
use crate::domain::model::local::LocalUpload;
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::{
    routes::{AUTH_SIGN, COMPLETE_FORM_DATA, COMPLETE_MULTIPART_UPLOAD, INITIATE_FORM_DATA, INITIATE_MULTIPART_UPLOAD, PART_LIMIT},
};
use base64::Engine;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io::Read;
use std::path::Path;
use std::sync::Arc;
use tokio::fs;
use tokio::io::AsyncReadExt;
use tracing::{info, warn, error};

use crate::infra::file::bitmap::Bitmap;
use crate::infra::file::cb::{EmptyUploadCallback, UploadFileCallback};
use crate::infra::file::md5::parts_hash;

// ============================================================================
// 类型定义
// ============================================================================

/// 简单进度回调类型（兼容旧接口）：接收 0-100 的进度值
pub type ProgressCallback = Arc<dyn Fn(u8) + Send + Sync>;

// ============================================================================
// form-data 上传相关结构（适用于中小文件）
// ============================================================================

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

#[derive(Clone, Debug, Serialize)]
pub struct CompleteFormDataReq {
    pub id: String,
    #[serde(rename = "urlPrefix")]
    pub url_prefix: String,
}

#[derive(Clone, Debug, Deserialize, Default)]
pub struct CompleteFormDataResp {
    pub url: String,
}

// ============================================================================
// multipart 上传相关结构（适用于大文件，对齐 Go SDK）
// ============================================================================

/// /object/part_limit 请求/响应
#[derive(Clone, Debug, Serialize, Default)]
pub struct PartLimitReq {}

#[derive(Clone, Debug, Deserialize, Default)]
pub struct PartLimitResp {
    #[serde(rename = "minPartSize")]
    pub min_part_size: i64,
    #[serde(rename = "maxPartSize")]
    pub max_part_size: i64,
    #[serde(rename = "maxNumSize")]
    pub max_num_size: i32,
}

/// /object/initiate_multipart_upload 请求
#[derive(Clone, Debug, Serialize)]
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
    #[serde(rename = "urlPrefix")]
    pub url_prefix: String,
}

/// /object/initiate_multipart_upload 响应
#[derive(Clone, Debug, Deserialize, Default)]
pub struct InitiateMultipartUploadResp {
    pub url: String,
    pub upload: Option<UploadInfoResp>,
}

#[derive(Clone, Debug, Deserialize, Default)]
pub struct UploadInfoResp {
    #[serde(rename = "uploadID")]
    pub upload_id: String,
    #[serde(rename = "partSize")]
    pub part_size: i64,
    pub sign: Option<AuthSignPartsResp>,
    #[serde(rename = "expireTime")]
    pub expire_time: i64,
}

#[derive(Clone, Debug, Deserialize, Default)]
pub struct AuthSignPartsResp {
    pub url: String,
    #[serde(default)]
    pub query: Vec<QueryParam>,
    #[serde(default)]
    pub header: Vec<HeaderParam>,
    #[serde(default)]
    pub parts: Vec<SignPartResp>,
}

#[derive(Clone, Debug, Deserialize)]
pub struct SignPartResp {
    #[serde(rename = "partNumber")]
    pub part_number: i32,
    pub url: String,
    #[serde(default)]
    pub query: Vec<QueryParam>,
    #[serde(default)]
    pub header: Vec<HeaderParam>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct QueryParam {
    pub key: String,
    pub values: Vec<String>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct HeaderParam {
    pub key: String,
    pub values: Vec<String>,
}

/// /object/auth_sign 请求
#[derive(Clone, Debug, Serialize)]
pub struct AuthSignReq {
    #[serde(rename = "uploadID")]
    pub upload_id: String,
    #[serde(rename = "partNumbers")]
    pub part_numbers: Vec<i32>,
}

/// /object/auth_sign 响应
#[derive(Clone, Debug, Deserialize, Default)]
pub struct AuthSignResp {
    pub url: String,
    #[serde(default)]
    pub query: Vec<QueryParam>,
    #[serde(default)]
    pub header: Vec<HeaderParam>,
    #[serde(default)]
    pub parts: Vec<SignPartResp>,
}

/// /object/complete_multipart_upload 请求
#[derive(Clone, Debug, Serialize)]
pub struct CompleteMultipartUploadReq {
    #[serde(rename = "uploadID")]
    pub upload_id: String,
    pub parts: Vec<String>,
    pub name: String,
    #[serde(rename = "contentType")]
    pub content_type: String,
    pub cause: String,
    #[serde(rename = "urlPrefix")]
    pub url_prefix: String,
}

/// /object/complete_multipart_upload 响应
#[derive(Clone, Debug, Deserialize, Default)]
pub struct CompleteMultipartUploadResp {
    pub url: String,
}

// ============================================================================
// 上传结果
// ============================================================================

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UploadResult {
    pub url: String,
    pub file_id: String,
    pub size: u64,
    #[serde(rename = "contentType")]
    pub content_type: String,
}

// ============================================================================
// 分片信息（内部使用）
// ============================================================================

struct PartInfo {
    content_type: String,
    part_size: i64,
    part_num: i32,
    file_md5: String,
    parts_md5: String, // 所有分片 MD5 组合后的 hash
    part_sizes: Vec<i64>,
    part_md5s: Vec<String>,
}

// ============================================================================
// 上传信息（用于分片上传主流程）
// ============================================================================

struct UploadSession {
    part_num: usize,
    bitmap: Bitmap,
    db_info: Option<LocalUpload>,
    resp: InitiateMultipartUploadResp,
    create_time: std::time::Instant,
    batch_sign_num: i32,
}

impl UploadSession {
    fn get_sign_index(&self, part_number: i32) -> Option<usize> {
        let sign = self.resp.upload.as_ref()?.sign.as_ref()?;
        if self.create_time.elapsed() > std::time::Duration::from_secs(60) {
            return None;
        }
        sign.parts.iter().position(|p| p.part_number == part_number)
    }

    fn build_request(&self, index: usize) -> std::result::Result<(String, Vec<(String, Vec<String>)>), SdkError> {
        let sign = self.resp.upload.as_ref()
            .and_then(|u| u.sign.as_ref())
            .ok_or_else(|| SdkError::file_upload("签名信息为空"))?;
        let part = sign.parts.get(index)
            .ok_or_else(|| SdkError::file_upload("分片签名不存在"))?;

        let mut url = sign.url.clone();
        if !part.url.is_empty() {
            url = part.url.clone();
        }

        // 拼接 query 参数
        let mut query_pairs: Vec<(String, Vec<String>)> = Vec::new();
        for q in sign.query.iter().chain(part.query.iter()) {
            query_pairs.push((q.key.clone(), q.values.clone()));
        }

        Ok((url, query_pairs))
    }
}

// ============================================================================
// hash 并发锁
// ============================================================================

struct HashLock {
    count: std::sync::atomic::AtomicI32,
    mutex: tokio::sync::Mutex<()>,
}

/// FileUploader — 文件上传器
/// 支持 form-data（中小文件）和 multipart 分片上传（大文件）
pub struct FileUploader {
    http_client: Arc<HttpApiClient>,
    login_user_id: std::sync::RwLock<String>,
    upload_dao: Option<Arc<UploadDao>>,
    part_limit: std::sync::RwLock<Option<PartLimitResp>>,
    uploading: std::sync::RwLock<HashMap<String, Arc<HashLock>>>,
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

    pub async fn upload_file(&self, file_path: &str, name: &str, content_type: Option<String>) -> Result<UploadResult> {
        self.upload_file_with_progress(file_path, name, content_type, None).await
    }

    // ========================================================================
    // 公开 API — 带简单进度回调（兼容旧接口）
    // ========================================================================

    pub async fn upload_file_with_progress(
        &self,
        file_path: &str,
        name: &str,
        content_type: Option<String>,
        progress: Option<ProgressCallback>,
    ) -> Result<UploadResult> {
        let cb = progress.map(|p| SimpleProgressCallback { progress: p });
        self.upload_file_with_callback(file_path, name, content_type, cb.as_ref().map(|c| c as &dyn UploadFileCallback)).await
    }

    // ========================================================================
    // 公开 API — 带细粒度回调（对齐 Go SDK UploadFileCallback）
    // ========================================================================

    pub async fn upload_file_with_callback(
        &self,
        file_path: &str,
        name: &str,
        content_type: Option<String>,
        cb: Option<&dyn UploadFileCallback>,
    ) -> Result<UploadResult> {
        let path = Path::new(file_path);
        if !path.exists() {
            return Err(SdkError::file_upload(format!("文件不存在: {}", file_path)));
        }

        let file_size = fs::metadata(path).await
            .map_err(|e| SdkError::file_upload(format!("获取文件信息失败: {}", e)))?
            .len() as i64;

        let detected_content_type = content_type.unwrap_or_else(|| {
            self.detect_content_type(path.file_name().and_then(|n| n.to_str()).unwrap_or(""))
        });

        let user_id = self.login_user_id.read().unwrap().clone();
        let prefixed_name = if user_id.is_empty() {
            name.to_string()
        } else {
            format!("{}/{}", user_id, name)
        };

        // 根据文件大小决定上传方式
        match self.get_part_limit().await {
            Ok(limit) => {
                let threshold = limit.min_part_size * limit.max_num_size as i64;
                if file_size > threshold {
                    // 大文件：使用分片上传
                    info!("文件 {} 大小 {} 超过阈值 {}，使用分片上传",
                        prefixed_name, file_size, threshold);
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

    pub async fn upload_image(&self, file_path: &str, progress: Option<ProgressCallback>) -> Result<UploadResult> {
        let path = Path::new(file_path);
        let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("image.jpg").to_string();
        let content_type = self.detect_content_type(&name);
        self.upload_file_with_progress(file_path, &name, Some(content_type), progress).await
    }

    pub async fn upload_video(&self, file_path: &str, progress: Option<ProgressCallback>) -> Result<UploadResult> {
        let path = Path::new(file_path);
        let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("video.mp4").to_string();
        self.upload_file_with_progress(file_path, &name, Some("video/mp4".to_string()), progress).await
    }

    pub async fn upload_audio(&self, file_path: &str, progress: Option<ProgressCallback>) -> Result<UploadResult> {
        let path = Path::new(file_path);
        let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("audio.mp3").to_string();
        self.upload_file_with_progress(file_path, &name, Some("audio/mpeg".to_string()), progress).await
    }

    // ========================================================================
    // form-data 上传（中小文件）
    // ========================================================================

    async fn upload_file_form_data(
        &self,
        file_path: &str,
        name: &str,
        content_type: &str,
        file_size: i64,
        cb: Option<&dyn UploadFileCallback>,
    ) -> Result<UploadResult> {
        let cb_ref = cb.unwrap_or(&EmptyUploadCallback);
        cb_ref.open(file_size);

        let path = Path::new(file_path);
        let req = InitiateFormDataReq {
            name: name.to_string(),
            size: file_size,
            content_type: content_type.to_string(),
            group: String::new(),
            millisecond: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_millis() as i64,
            absolute: false,
        };

        let resp: InitiateFormDataResp = self.http_client.post(INITIATE_FORM_DATA, &req).await?;
        info!("initiate_form_data: id={}, url={}", resp.id, resp.url);

        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .map_err(|e| SdkError::file_upload(format!("创建 HTTP 客户端失败: {}", e)))?;
        let mut form = reqwest::multipart::Form::new();

        for (key, value) in &resp.form_data {
            form = form.text(key.clone(), value.clone());
        }

        // 读取文件内容，带进度跟踪
        let file_data = fs::read(path).await
            .map_err(|e| SdkError::file_upload(format!("读取文件失败: {}", e)))?;

        // 报告初始进度
        if file_size > 0 {
            cb_ref.upload_complete(file_size, 0, 0);
        }

        let body = reqwest::Body::from(file_data);
        let part = reqwest::multipart::Part::stream(body)
            .file_name(name.to_string())
            .mime_str(content_type)
            .map_err(|e| SdkError::file_upload(format!("MIME 类型错误: {}", e)))?;
        form = form.part(resp.file.clone(), part);

        let upload_url = resp.url.clone();
        let upload_resp = client
            .post(&upload_url)
            .multipart(form)
            .send()
            .await
            .map_err(|e| SdkError::file_upload(format!("上传请求失败: {}", e)))?;

        let status = upload_resp.status();
        let resp_body = upload_resp.text().await.unwrap_or_default();
        if !status.is_success() {
            return Err(SdkError::file_upload(format!("上传失败, 状态码: {}, body: {}", status, resp_body)));
        }

        // 报告完成进度
        cb_ref.upload_complete(file_size, file_size, file_size);

        let complete_req = CompleteFormDataReq {
            id: resp.id,
            url_prefix: String::new(),
        };
        let complete_resp: CompleteFormDataResp = self.http_client.post(COMPLETE_FORM_DATA, &complete_req).await?;

        cb_ref.complete(file_size, &complete_resp.url, 1);

        info!("form-data 上传完成: url={}", complete_resp.url);
        Ok(UploadResult {
            url: complete_resp.url.clone(),
            file_id: complete_resp.url,
            size: file_size as u64,
            content_type: content_type.to_string(),
        })
    }

    // ========================================================================
    // multipart 分片上传（大文件，对齐 Go SDK upload.go）
    // ========================================================================

    async fn upload_file_multipart(
        &self,
        file_path: &str,
        name: &str,
        content_type: &str,
        file_size: i64,
        cb: Option<&dyn UploadFileCallback>,
    ) -> Result<UploadResult> {
        let cb_ref = cb.unwrap_or(&EmptyUploadCallback);
        cb_ref.open(file_size);

        // 阶段 1: 打开文件 & 计算分片信息（Hash）
        let info = self.get_part_info(file_path, file_size, cb_ref).await?;
        let part_md5_val = info.parts_md5.clone();

        // 阶段 2: 基于 hash 的并发去重锁
        let lock = self.lock_hash(&part_md5_val).await;

        // 阶段 3: 初始化上传（含断点续传恢复）
        let max_parts = std::cmp::min(20, info.part_num);
        let upload_session = self.get_upload(
            &part_md5_val,
            file_size,
            info.part_size,
            max_parts,
            name,
            content_type,
        ).await?;

        // 秒传：服务端已有完整文件
        if upload_session.resp.upload.is_none() {
            let url = upload_session.resp.url.clone();
            cb_ref.complete(file_size, &url, 1);
            self.unlock_hash(&part_md5_val, &lock).await;
            return Ok(UploadResult {
                url: url.clone(),
                file_id: url,
                size: file_size as u64,
                content_type: content_type.to_string(),
            });
        }

        // 校验 part_size 一致性
        let server_part_size = upload_session.resp.upload.as_ref().unwrap().part_size;
        if server_part_size != info.part_size {
            self.clean_part_limit();
            self.unlock_hash(&part_md5_val, &lock).await;
            return Err(SdkError::file_upload(format!(
                "分片大小不匹配: 期望 {}, 实际 {}", info.part_size, server_part_size
            )));
        }

        cb_ref.upload_id(&upload_session.resp.upload.as_ref().unwrap().upload_id);

        // 计算已上传的字节数（用于进度回调）
        let mut uploaded_size = file_size;
        for i in 0..info.part_sizes.len() {
            if !upload_session.bitmap.get(i) {
                uploaded_size -= info.part_sizes[i];
            }
        }
        let continue_upload = uploaded_size > 0;

        // 阶段 4: 逐片上传
        let mut session = upload_session;
        let file = fs::File::open(file_path).await
            .map_err(|e| SdkError::file_upload(format!("打开文件失败: {}", e)))?;
        let mut file_reader = tokio::io::BufReader::new(file);

        for i in 0..info.part_sizes.len() {
            let current_part_size = info.part_sizes[i] as usize;

            if session.bitmap.get(i) {
                // 已上传的分片，跳过（断点续传）
                let mut discard = vec![0u8; 65536];
                let mut remaining = current_part_size;
                while remaining > 0 {
                    let to_read = std::cmp::min(remaining, discard.len());
                    let n = file_reader.read(&mut discard[..to_read]).await
                        .map_err(|e| SdkError::file_upload(format!("跳过分片失败: {}", e)))?;
                    if n == 0 { break; }
                    remaining -= n;
                }
            } else {
                // 获取签名
                let part_number = (i + 1) as i32;
                let (sign_url, query_pairs) = session.get_or_fetch_sign(&self.http_client, part_number).await?;

                // 读取分片数据并计算 MD5
                let mut data = vec![0u8; current_part_size];
                let mut read_total = 0;
                use md5::Digest;
                let mut part_hasher = md5::Md5::new();

                while read_total < current_part_size {
                    let to_read = std::cmp::min(current_part_size - read_total, 65536);
                    let n = file_reader.read(&mut data[read_total..read_total + to_read]).await
                        .map_err(|e| SdkError::file_upload(format!("读取分片失败: {}", e)))?;
                    if n == 0 { break; }
                    part_hasher.update(&data[read_total..read_total + n]);
                    read_total += n;

                    // 进度回调
                    cb_ref.upload_complete(file_size, uploaded_size + read_total as i64, uploaded_size);
                }

                let md5_val = hex::encode(part_hasher.finalize());

                // 构建 PUT 请求 URL（拼接 query 参数）
                let mut url_with_query = sign_url.clone();
                if !query_pairs.is_empty() {
                    let mut parsed = url::Url::parse(&sign_url)
                        .map_err(|e| SdkError::file_upload(format!("URL 解析失败: {}", e)))?;
                    {
                        let mut q = parsed.query_pairs_mut();
                        for (key, values) in &query_pairs {
                            for v in values {
                                q.append_pair(key, v);
                            }
                        }
                    }
                    url_with_query = parsed.to_string();
                }

                let http_client = reqwest::Client::new();
                let mut req_builder = http_client.put(&url_with_query)
                    .header("Content-Length", current_part_size);

                // 添加签名 headers
                for (key, values) in session.get_sign_headers(part_number) {
                    req_builder = req_builder.header(&key, &values.join(","));
                }

                let resp = req_builder
                    .body(data)
                    .send()
                    .await
                    .map_err(|e| SdkError::file_upload(format!("PUT 上传分片 {} 失败: {}", i + 1, e)))?;

                let status = resp.status();
                let resp_body = resp.text().await.unwrap_or_default();
                if !status.is_success() {
                    error!("PUT 分片 {} 失败: status={}, body={}", i + 1, status, resp_body);
                    self.unlock_hash(&part_md5_val, &lock).await;
                    return Err(SdkError::file_upload(format!(
                        "上传分片 {} 失败, 状态码: {}, body: {}", i + 1, status, resp_body
                    )));
                }

                // MD5 校验
                if md5_val != info.part_md5s[i] {
                    self.unlock_hash(&part_md5_val, &lock).await;
                    return Err(SdkError::file_upload(format!(
                        "分片 {} MD5 校验失败: 期望 {}, 实际 {}", i + 1, info.part_md5s[i], md5_val
                    )));
                }

                uploaded_size += info.part_sizes[i];

                // 更新 Bitmap 并持久化
                session.bitmap.set(i);
                if let Some(ref db_info) = session.db_info {
                    if let Some(ref dao) = self.upload_dao {
                        let mut updated = db_info.clone();
                        updated.upload_info = base64::engine::general_purpose::STANDARD
                            .encode(session.bitmap.serialize());
                        if let Err(e) = dao.update_upload(&updated).await {
                            warn!("持久化上传状态失败: {}", e);
                        }
                    }
                }
            }

            cb_ref.upload_part_complete(i as i32, info.part_sizes[i], &info.part_md5s[i]);
            info!("分片 {} 上传成功", i + 1);
        }

        // 阶段 5: 完成上传
        let upload_id = session.resp.upload.as_ref().unwrap().upload_id.clone();
        let complete_resp = self.complete_multipart_upload(
            &upload_id, &info.part_md5s, name, content_type,
        ).await?;

        let typ = if continue_upload { 2 } else { 1 };
        cb_ref.complete(file_size, &complete_resp.url, typ);

        // 清理本地上传记录
        if session.db_info.is_some() {
            if let Some(ref dao) = self.upload_dao {
                if let Err(e) = dao.delete_upload(&part_md5_val).await {
                    warn!("删除上传记录失败: {}", e);
                }
            }
        }

        // 阶段 6: 释放并发锁
        self.unlock_hash(&part_md5_val, &lock).await;

        info!("分片上传完成: url={}, typ={}", complete_resp.url, typ);
        Ok(UploadResult {
            url: complete_resp.url.clone(),
            file_id: complete_resp.url,
            size: file_size as u64,
            content_type: content_type.to_string(),
        })
    }

    // ========================================================================
    // 分片信息计算（对齐 Go SDK getPartInfo）
    // ========================================================================

    async fn get_part_info(&self, file_path: &str, file_size: i64, cb: &dyn UploadFileCallback) -> Result<PartInfo> {
        let part_size = self.part_size(file_size).await?;
        let part_num = ((file_size + part_size - 1) / part_size) as usize;

        cb.part_size(part_size, part_num as i32);

        // 计算每个分片的大小
        let mut part_sizes = vec![part_size; part_num];
        part_sizes[part_num - 1] = file_size - part_size * (part_num as i64 - 1);

        // 逐片计算 MD5
        use md5::Digest;
        let file = std::fs::File::open(file_path)
            .map_err(|e| SdkError::file_upload(format!("打开文件失败: {}", e)))?;
        let mut reader = std::io::BufReader::new(file);

        let mut part_md5s = Vec::with_capacity(part_num);
        let mut file_hasher = md5::Md5::new();
        let mut content_type = String::new();
        let mut buf = vec![0u8; 8192];

        for i in 0..part_num {
            let mut part_hasher = md5::Md5::new();
            let remaining = part_sizes[i] as usize;
            let mut read_total = 0;

            while read_total < remaining {
                let to_read = std::cmp::min(buf.len(), remaining - read_total);
                let n = reader.read(&mut buf[..to_read])
                    .map_err(|e| SdkError::file_upload(format!("读取文件失败: {}", e)))?;
                if n == 0 {
                    break;
                }
                part_hasher.update(&buf[..n]);
                file_hasher.update(&buf[..n]);
                read_total += n;

                // 检测 content_type（使用第一个分片的第一个 chunk）
                if content_type.is_empty() && n > 0 {
                    content_type = mime_from_bytes(&buf[..n]);
                }
            }

            let md5_hex = hex::encode(part_hasher.finalize());
            cb.hash_part_progress(i as i32, part_sizes[i], &md5_hex);
            part_md5s.push(md5_hex);
        }

        let parts_md5_val = parts_hash(&part_md5s);
        let file_md5_val = hex::encode(file_hasher.finalize());
        cb.hash_part_complete(&parts_md5_val, &file_md5_val);

        if content_type.is_empty() {
            content_type = "application/octet-stream".to_string();
        }

        Ok(PartInfo {
            content_type,
            part_size,
            part_num: part_num as i32,
            file_md5: file_md5_val,
            parts_md5: parts_md5_val,
            part_sizes,
            part_md5s,
        })
    }

    // ========================================================================
    // 分片大小计算（对齐 Go SDK partSize）
    // ========================================================================

    async fn part_size(&self, size: i64) -> Result<i64> {
        let limit = self.get_part_limit().await?;
        if size <= 0 {
            return Err(SdkError::file_upload("文件大小必须大于 0"));
        }
        if size > limit.max_part_size * limit.max_num_size as i64 {
            return Err(SdkError::file_upload(format!(
                "文件大小超过限制: {} > {}",
                size, limit.max_part_size * limit.max_num_size as i64
            )));
        }
        if size <= limit.min_part_size * limit.max_num_size as i64 {
            return Ok(limit.min_part_size);
        }
        let mut ps = size / limit.max_num_size as i64;
        if size % limit.max_num_size as i64 != 0 {
            ps += 1;
        }
        Ok(ps)
    }

    async fn get_part_limit(&self) -> Result<PartLimitResp> {
        {
            let guard = self.part_limit.read().unwrap();
            if let Some(ref limit) = *guard {
                return Ok(limit.clone());
            }
        }
        let resp: PartLimitResp = self.http_client.post(PART_LIMIT, &PartLimitReq {}).await?;
        info!("获取分片限制: min={}, max={}, maxNum={}", resp.min_part_size, resp.max_part_size, resp.max_num_size);
        *self.part_limit.write().unwrap() = Some(resp.clone());
        Ok(resp)
    }

    fn clean_part_limit(&self) {
        *self.part_limit.write().unwrap() = None;
    }

    // ========================================================================
    // 服务端交互（对齐 Go SDK）
    // ========================================================================

    async fn initiate_multipart_upload(
        &self,
        req: &InitiateMultipartUploadReq,
    ) -> Result<InitiateMultipartUploadResp> {
        self.http_client.post(INITIATE_MULTIPART_UPLOAD, req).await
    }

    async fn auth_sign(&self, upload_id: &str, part_numbers: Vec<i32>) -> Result<AuthSignResp> {
        if part_numbers.is_empty() {
            return Err(SdkError::file_upload("part_numbers 为空"));
        }
        let req = AuthSignReq {
            upload_id: upload_id.to_string(),
            part_numbers,
        };
        self.http_client.post(AUTH_SIGN, &req).await
    }

    async fn complete_multipart_upload(
        &self,
        upload_id: &str,
        parts: &[String],
        name: &str,
        content_type: &str,
    ) -> Result<CompleteMultipartUploadResp> {
        let req = CompleteMultipartUploadReq {
            upload_id: upload_id.to_string(),
            parts: parts.to_vec(),
            name: name.to_string(),
            content_type: content_type.to_string(),
            cause: String::new(),
            url_prefix: String::new(),
        };
        self.http_client.post(COMPLETE_MULTIPART_UPLOAD, &req).await
    }

    // ========================================================================
    // 上传会话管理（含断点续传恢复，对齐 Go SDK getUpload）
    // ========================================================================

    async fn get_upload(
        &self,
        part_md5_val: &str,
        file_size: i64,
        part_size: i64,
        max_parts: i32,
        name: &str,
        content_type: &str,
    ) -> Result<UploadSession> {
        let part_num = ((file_size + part_size - 1) / part_size) as usize;

        // 尝试从本地数据库恢复
        if let Some(local_info) = self.get_local_upload_info(part_md5_val, part_num, part_size, max_parts).await {
            return Ok(local_info);
        }

        // 调用服务端初始化上传
        let resp = self.initiate_multipart_upload(&InitiateMultipartUploadReq {
            hash: part_md5_val.to_string(),
            size: file_size,
            part_size,
            max_parts,
            cause: String::new(),
            name: name.to_string(),
            content_type: content_type.to_string(),
            url_prefix: String::new(),
        }).await?;

        if resp.upload.is_none() {
            // 秒传
            return Ok(UploadSession {
                part_num,
                bitmap: Bitmap::new(0),
                db_info: None,
                resp,
                create_time: std::time::Instant::now(),
                batch_sign_num: max_parts,
            });
        }

        let bitmap = Bitmap::new(part_num);
        let mut db_info = None;

        // 持久化到数据库（仅多分片）
        if part_num > 1 {
            if let Some(ref dao) = self.upload_dao {
                let info = LocalUpload {
                    part_hash: part_md5_val.to_string(),
                    upload_id: resp.upload.as_ref().unwrap().upload_id.clone(),
                    upload_info: base64::engine::general_purpose::STANDARD.encode(bitmap.serialize()),
                    expire_time: resp.upload.as_ref().unwrap().expire_time,
                    create_time: chrono::Utc::now().timestamp_millis(),
                };
                // 先删除旧记录再插入
                if let Err(e) = dao.delete_upload(part_md5_val).await {
                    warn!("删除旧上传记录失败: {}", e);
                }
                if let Err(e) = dao.insert_upload(&info).await {
                    warn!("插入上传记录失败: {}", e);
                }
                db_info = Some(info);
            }
        }

        Ok(UploadSession {
            part_num,
            bitmap,
            db_info,
            resp,
            create_time: std::time::Instant::now(),
            batch_sign_num: max_parts,
        })
    }

    async fn get_local_upload_info(
        &self,
        part_md5_val: &str,
        part_num: usize,
        part_size: i64,
        max_parts: i32,
    ) -> Option<UploadSession> {
        if part_num <= 1 {
            return None;
        }
        let dao = self.upload_dao.as_ref()?;
        let local = dao.get_upload(part_md5_val).await.ok()??;

        // 检查是否过期（提前 1 小时）
        let now_ms = chrono::Utc::now().timestamp_millis();
        if local.upload_id.is_empty() || local.expire_time - 3600 * 1000 < now_ms {
            let _ = dao.delete_upload(part_md5_val).await;
            return None;
        }

        let bitmap_bytes = base64::engine::general_purpose::STANDARD
            .decode(&local.upload_info)
            .ok()?;
        let bitmap = Bitmap::parse(&bitmap_bytes, part_num);

        Some(UploadSession {
            part_num,
            bitmap,
            db_info: Some(local.clone()),
            resp: InitiateMultipartUploadResp {
                url: String::new(),
                upload: Some(UploadInfoResp {
                    upload_id: local.upload_id,
                    part_size,
                    sign: None, // 签名需要重新获取
                    expire_time: local.expire_time,
                }),
            },
            create_time: std::time::Instant::now(),
            batch_sign_num: max_parts,
        })
    }

    // ========================================================================
    // 并发锁（对齐 Go SDK lockHash/unlockHash）
    // ========================================================================

    async fn lock_hash(&self, hash: &str) -> Arc<HashLock> {
        let lock = {
            let mut map = self.uploading.write().unwrap();
            map.entry(hash.to_string())
                .or_insert_with(|| Arc::new(HashLock {
                    count: std::sync::atomic::AtomicI32::new(0),
                    mutex: tokio::sync::Mutex::new(()),
                }))
                .clone()
        };
        lock.count.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
        let guard = lock.mutex.lock().await;
        // 为了保持锁的生命周期，我们需要泄漏 guard
        // 但这是 Rust，我们换一种方式：用 ManuallyDrop
        std::mem::forget(guard);
        lock
    }

    async fn unlock_hash(&self, hash: &str, lock: &Arc<HashLock>) {
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

// ============================================================================
// UploadSession 方法（签名管理，对齐 Go SDK UploadInfo.GetPartSign）
// ============================================================================

impl UploadSession {
    async fn get_or_fetch_sign(
        &mut self,
        http_client: &Arc<HttpApiClient>,
        part_number: i32,
    ) -> Result<(String, Vec<(String, Vec<String>)>)> {
        // 尝试使用缓存签名
        if let Some(index) = self.get_sign_index(part_number) {
            return self.build_request(index);
        }

        // 批量获取签名
        let mut part_numbers = Vec::with_capacity(self.batch_sign_num as usize);
        for i in 0..self.batch_sign_num {
            if part_number + i > self.part_num as i32 {
                break;
            }
            part_numbers.push(part_number + i);
        }

        let upload_id = self.resp.upload.as_ref().unwrap().upload_id.clone();
        let auth_resp: AuthSignResp = http_client.post(AUTH_SIGN, &AuthSignReq {
            upload_id,
            part_numbers,
        }).await?;

        // 更新缓存
        if let Some(ref mut upload) = self.resp.upload {
            upload.sign = Some(AuthSignPartsResp {
                url: auth_resp.url,
                query: auth_resp.query,
                header: auth_resp.header,
                parts: auth_resp.parts,
            });
        }
        self.create_time = std::time::Instant::now();

        let index = self.get_sign_index(part_number)
            .ok_or_else(|| SdkError::file_upload("服务端返回的签名无效"))?;
        self.build_request(index)
    }

    fn get_sign_headers(&self, part_number: i32) -> Vec<(String, Vec<String>)> {
        let sign = match self.resp.upload.as_ref().and_then(|u| u.sign.as_ref()) {
            Some(s) => s,
            None => return Vec::new(),
        };

        let mut headers = Vec::new();
        for h in &sign.header {
            headers.push((h.key.clone(), h.values.clone()));
        }
        if let Some(part) = sign.parts.iter().find(|p| p.part_number == part_number) {
            for h in &part.header {
                headers.push((h.key.clone(), h.values.clone()));
            }
        }
        headers
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
// 工具函数
// ============================================================================

/// 根据文件头检测 MIME 类型
fn mime_from_bytes(data: &[u8]) -> String {
    if data.len() < 4 {
        return "application/octet-stream".to_string();
    }
    match data {
        [0xFF, 0xD8, 0xFF, ..] => "image/jpeg".to_string(),
        [0x89, 0x50, 0x4E, 0x47, ..] => "image/png".to_string(),
        [0x47, 0x49, 0x46, 0x38, ..] => "image/gif".to_string(),
        [0x52, 0x49, 0x46, 0x46] => {
            // RIFF container - check for WEBP or AVI
            if data.len() >= 12 && &data[8..12] == b"WEBP" {
                "image/webp".to_string()
            } else if data.len() >= 12 && &data[8..12] == b"AVI " {
                "video/avi".to_string()
            } else {
                "application/octet-stream".to_string()
            }
        }
        [0x1A, 0x45, 0xDF, 0xA3] => "video/webm".to_string(),
        [0x00, 0x00, 0x00, _, ..] => {
            // ftyp box - MP4/MOV
            if data.len() >= 8 && &data[4..8] == b"ftyp" {
                "video/mp4".to_string()
            } else {
                "application/octet-stream".to_string()
            }
        }
        _ => "application/octet-stream".to_string(),
    }
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::file::bitmap::Bitmap;

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
    fn test_mime_from_bytes() {
        assert_eq!(mime_from_bytes(&[0xFF, 0xD8, 0xFF, 0xE0]), "image/jpeg");
        assert_eq!(mime_from_bytes(&[0x89, 0x50, 0x4E, 0x47]), "image/png");
        assert_eq!(mime_from_bytes(&[0x47, 0x49, 0x46, 0x38]), "image/gif");
        assert_eq!(mime_from_bytes(&[0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70]), "video/mp4");
    }

    #[test]
    fn test_bitmap_roundtrip() {
        let mut bm = Bitmap::new(128);
        bm.set(0);
        bm.set(63);
        bm.set(64);
        bm.set(127);
        let bytes = bm.serialize();
        let bm2 = Bitmap::parse(&bytes, 128);
        assert!(bm2.get(0));
        assert!(bm2.get(63));
        assert!(bm2.get(64));
        assert!(bm2.get(127));
        assert!(!bm2.get(1));
    }
}


