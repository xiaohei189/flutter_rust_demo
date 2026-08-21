use crate::domain::error::{Result, SdkError};
use crate::infra::file::bitmap::Bitmap;
use crate::infra::file::upload::dto::{AuthSignPartsResp, AuthSignReq, AuthSignResp};
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::AUTH_SIGN;
use crate::domain::model::local::LocalUpload;
use std::sync::Arc;

// ============================================================================
// 分片信息（内部使用）
// ============================================================================

pub struct PartInfo {
    pub content_type: String,
    pub part_size: i64,
    pub part_num: i32,
    pub file_md5: String,
    pub parts_md5: String, // 所有分片 MD5 组合后的 hash
    pub part_sizes: Vec<i64>,
    pub part_md5s: Vec<String>,
}

// ============================================================================
// 上传信息（用于分片上传主流程）
// ============================================================================

pub struct UploadSession {
    pub part_num: usize,
    pub bitmap: Bitmap,
    pub db_info: Option<LocalUpload>,
    pub resp: crate::infra::file::upload::dto::InitiateMultipartUploadResp,
    pub create_time: std::time::Instant,
    pub batch_sign_num: i32,
}

impl UploadSession {
    pub fn get_sign_index(&self, part_number: i32) -> Option<usize> {
        let sign = self.resp.upload.as_ref()?.sign.as_ref()?;
        if self.create_time.elapsed() > std::time::Duration::from_secs(60) {
            return None;
        }
        sign.parts.iter().position(|p| p.part_number == part_number)
    }

    pub fn build_request(&self, index: usize) -> std::result::Result<(String, Vec<(String, Vec<String>)>), SdkError> {
        let sign = self.resp.upload.as_ref().and_then(|u| u.sign.as_ref()).ok_or_else(|| SdkError::file_upload("签名信息为空"))?;
        let part = sign.parts.get(index).ok_or_else(|| SdkError::file_upload("分片签名不存在"))?;

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
// UploadSession 签名管理（对齐 Go SDK UploadInfo.GetPartSign）
// ============================================================================

impl UploadSession {
    pub async fn get_or_fetch_sign(&mut self, http_client: &Arc<HttpApiClient>, part_number: i32) -> Result<(String, Vec<(String, Vec<String>)>)> {
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
        let auth_resp: AuthSignResp = http_client.post(AUTH_SIGN, &AuthSignReq { upload_id, part_numbers }).await?;

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

        let index = self.get_sign_index(part_number).ok_or_else(|| SdkError::file_upload("服务端返回的签名无效"))?;
        self.build_request(index)
    }

    pub fn get_sign_headers(&self, part_number: i32) -> Vec<(String, Vec<String>)> {
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
// hash 并发锁（对齐 Go SDK lockHash/unlockHash）
// ============================================================================

pub struct HashLock {
    pub count: std::sync::atomic::AtomicI32,
    pub mutex: tokio::sync::Mutex<()>,
}
