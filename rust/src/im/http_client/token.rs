//! Auth HTTP API：GetAdminToken、GetUserToken，与 openim-sdk-core pkg/api/api.go 对齐

use super::response_extractor::extract_data;
use super::routes;
use super::{make_client, make_client_without_token, HttpClient};
use anyhow::Result;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ----- GetAdminToken（protocol auth.getAdminTokenReq/Resp） -----

/// 获取管理员 Token 请求，对应 protocol auth.getAdminTokenReq
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GetAdminTokenReq {
    pub secret: String,
    #[serde(rename = "userID")]
    pub user_id: String,
}

/// 获取管理员 Token 响应，对应 protocol auth.getAdminTokenResp
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetAdminTokenResp {
    pub token: String,
    pub expire_time_seconds: i64,
}

// ----- GetUserToken（protocol auth.getUserTokenReq/Resp） -----

/// 获取用户 Token 请求，对应 protocol auth.getUserTokenReq
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GetUserTokenReq {
    #[serde(rename = "platformID")]
    pub platform_id: i32,
    #[serde(rename = "userID")]
    pub user_id: String,
}

/// 获取用户 Token 响应，对应 protocol auth.getUserTokenResp
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetUserTokenResp {
    pub token: String,
    pub expire_time_seconds: i64,
}

#[derive(Clone)]
pub struct AuthApi {
    inner_client: reqwest::Client,
    api_base_url: String,
}

impl AuthApi {
    /// 创建 Auth API：不绑定用户 token，用于 get_admin_token（无 token）和 get_user_token（需传入 admin token）
    pub fn new(inner_client: reqwest::Client, api_base_url: String) -> Self {
        Self {
            inner_client,
            api_base_url,
        }
    }

    /// GetAdminToken = "/auth/get_admin_token"，使用 secret 换取 admin token（不携带请求头 token）
    pub async fn get_admin_token(&self, req: GetAdminTokenReq) -> Result<GetAdminTokenResp> {
        let client: HttpClient = make_client_without_token(self.inner_client.clone());
        self.post_json(routes::AUTH_GET_ADMIN_TOKEN, &req, &client).await
    }

    /// GetUserToken = "/auth/get_user_token"，使用 admin token 换取指定用户的 token
    pub async fn get_user_token(&self, req: GetUserTokenReq, admin_token: &str) -> Result<GetUserTokenResp> {
        let client: HttpClient = make_client(self.inner_client.clone(), admin_token);
        self.post_json(routes::AUTH_GET_USER_TOKEN, &req, &client).await
    }

    async fn post_json<T: Serialize, R: serde::de::DeserializeOwned>(
        &self,
        path: &str,
        payload: &T,
        client: &HttpClient,
    ) -> Result<R> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, path);
        let resp = client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(payload)
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("auth api request failed: {}", e))?;
        extract_data(resp).await
    }
}
