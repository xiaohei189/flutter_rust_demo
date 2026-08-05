use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;

// ============================================================================
// 上传 DTO 类型（form-data + multipart 分片上传的请求/响应）
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
