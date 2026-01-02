use crate::im::http::{make_client_without_token, HttpResponseExtractor};
use serde::{Deserialize, Serialize};
use tower::ServiceExt;
use tower_http_client::ServiceExt as _;
use tracing::info;
use anyhow::Result;
#[derive(Debug, Serialize, Deserialize)]
pub struct LoginRequest {
    #[serde(rename = "areaCode")]
    pub area_code: String,
    #[serde(rename = "phoneNumber")]
    pub phone_number: String,
    pub password: String,
    pub platform: i32,
}

/// 登录响应（暴露给 Dart）
/// 
/// 添加 Serialize 和 Clone trait 以支持 flutter_rust_bridge
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct LoginResponse {
    #[serde(rename = "errCode")]
    pub err_code: i32,
    #[serde(rename = "errMsg")]
    pub err_msg: String,
    pub data: Option<LoginData>,
}

/// 登录数据（暴露给 Dart）
/// 
/// 添加 Serialize 和 Clone trait 以支持 flutter_rust_bridge
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct LoginData {
    #[serde(rename = "imToken")]
    pub im_token: String,
    #[serde(rename = "chatToken")]
    pub chat_token: String,
    #[serde(rename = "userID")]
    pub user_id: String,
}

pub async fn login_async(
    area_code: String,
    phone_number: String,
    password: String,
    platform: i32,
) -> Result<LoginData> {
    let url = "http://localhost:10008/account/login".to_string();

    let login_req = LoginRequest {
        area_code,
        phone_number,
        password,
        platform,
    };

    // 创建不带 token 的 HTTP 客户端
    let base_client = reqwest::Client::builder()
        .build()?;
    let http_client = make_client_without_token(base_client);

    // 使用新的客户端封装发送请求
    let mut client = http_client.clone();
    let service = client.ready().await?;

    let req = service
        .post(url.as_str())
        .json(&login_req)?;

    let data: LoginData = HttpResponseExtractor::send(req).await?;

    Ok(data)
}

