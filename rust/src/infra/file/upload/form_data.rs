use crate::domain::error::SdkError;
use crate::infra::file::callbacks::{EmptyUploadCallback, UploadFileCallback};
use crate::infra::file::upload::dto::{CompleteFormDataReq, CompleteFormDataResp, InitiateFormDataReq, InitiateFormDataResp, UploadResult};
use crate::infra::file::upload::uploader::FileUploader;
use crate::infra::http::routes::{COMPLETE_FORM_DATA, INITIATE_FORM_DATA};
use std::path::Path;
use tokio::fs;
use tracing::info;

// ============================================================================
// form-data 上传（中小文件）
// ============================================================================

impl FileUploader {
    pub(crate) async fn upload_file_form_data(&self, file_path: &str, name: &str, content_type: &str, file_size: i64, cb: Option<&dyn UploadFileCallback>) -> crate::domain::error::Result<UploadResult> {
        let cb_ref = cb.unwrap_or(&EmptyUploadCallback);
        cb_ref.open(file_size);

        let path = Path::new(file_path);
        let req = InitiateFormDataReq {
            name: name.to_string(),
            size: file_size,
            content_type: content_type.to_string(),
            group: String::new(),
            millisecond: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis() as i64,
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
        let file_data = fs::read(path).await.map_err(|e| SdkError::file_upload(format!("读取文件失败: {}", e)))?;

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
}
