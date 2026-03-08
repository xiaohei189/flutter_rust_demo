//! 用户 HTTP API，路径与 openim-sdk-core pkg/api/api.go 完全一致

use super::response_extractor::extract_data;
use super::routes;
use super::{make_client, HttpClient};
use crate::im::model::message::EmptyResp;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(serde::Serialize)]
struct GetUsersInfoReq {
    #[serde(rename = "userIDs")]
    user_ids: Vec<String>,
}

// ----- UpdateUserInfo (protocol user.UpdateUserInfoReq) -----
/// 更新用户信息请求体，对应 protocol sdkws.UserInfo
#[derive(Debug, Clone, Serialize)]
pub struct UpdateUserInfoReq {
    #[serde(rename = "userInfo")]
    pub user_info: UserInfoForUpdate,
}

#[derive(Debug, Clone, Serialize)]
pub struct UserInfoForUpdate {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub nickname: Option<String>,
    #[serde(rename = "faceURL", skip_serializing_if = "Option::is_none")]
    pub face_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
    #[serde(rename = "createTime", skip_serializing_if = "Option::is_none")]
    pub create_time: Option<i64>,
    #[serde(rename = "appMangerLevel", skip_serializing_if = "Option::is_none")]
    pub app_manger_level: Option<i32>,
    #[serde(rename = "globalRecvMsgOpt", skip_serializing_if = "Option::is_none")]
    pub global_recv_msg_opt: Option<i32>,
}

// ----- UpdateUserInfoEx (protocol user.UpdateUserInfoExReq, UserInfoWithEx 仅更新指定字段) -----
#[derive(Debug, Clone, Serialize)]
pub struct UpdateUserInfoExReq {
    #[serde(rename = "userInfo")]
    pub user_info: UserInfoWithExFields,
}

#[derive(Debug, Clone, Serialize)]
pub struct UserInfoWithExFields {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub nickname: Option<String>,
    #[serde(rename = "faceURL", skip_serializing_if = "Option::is_none")]
    pub face_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
    #[serde(rename = "globalRecvMsgOpt", skip_serializing_if = "Option::is_none")]
    pub global_recv_msg_opt: Option<i32>,
}

// ----- UserRegister (protocol user.UserRegisterReq) -----
#[derive(Debug, Clone, Serialize)]
pub struct UserRegisterReq {
    pub users: Vec<UserInfoForRegister>,
}

#[derive(Debug, Clone, Serialize)]
pub struct UserInfoForRegister {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub nickname: Option<String>,
    #[serde(rename = "faceURL", skip_serializing_if = "Option::is_none")]
    pub face_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
    #[serde(rename = "createTime", skip_serializing_if = "Option::is_none")]
    pub create_time: Option<i64>,
    #[serde(rename = "appMangerLevel", skip_serializing_if = "Option::is_none")]
    pub app_manger_level: Option<i32>,
    #[serde(rename = "globalRecvMsgOpt", skip_serializing_if = "Option::is_none")]
    pub global_recv_msg_opt: Option<i32>,
}

// ----- GetUserClientConfig (protocol user.GetUserClientConfigResp) -----
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetUserClientConfigResp {
    #[serde(default)]
    pub configs: HashMap<String, String>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserInfoItem {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    #[serde(default)]
    pub create_time: i64,
    #[serde(default)]
    pub app_manger_level: i32,
    #[serde(default)]
    pub ex: String,
    #[serde(default)]
    pub attached_info: String,
    #[serde(default)]
    pub global_recv_msg_opt: i32,
}

#[derive(Debug, Deserialize)]
pub struct GetUsersInfoResp {
    #[serde(rename = "usersInfo", default)]
    pub users_info: Vec<UserInfoItem>,
}

#[derive(Clone)]
pub struct UserApi {
    client: HttpClient,
    api_base_url: String,
    user_id: String,
}

impl UserApi {
    pub fn new(client: reqwest::Client, api_base_url: String, user_id: String, token: &str) -> Self {
        Self {
            client: make_client(client, token),
            api_base_url,
            user_id,
        }
    }

    /// POST /user/get_users_info，与 Go api.GetUsersInfo 对齐
    pub async fn get_users_info(&self, user_ids: Vec<String>) -> Result<GetUsersInfoResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, routes::USER_GET_USERS_INFO);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&GetUsersInfoReq { user_ids })
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("get_users_info request failed: {}", e))?;
        extract_data(resp).await
    }

    /// 拉取当前登录用户信息（单用户）
    pub async fn get_login_user_from_server(&self) -> Result<Option<UserInfoItem>> {
        let resp = self.get_users_info(vec![self.user_id.clone()]).await?;
        Ok(resp.users_info.into_iter().next())
    }

    /// UpdateUserInfo = "/user/update_user_info"，与 Go api.UpdateUserInfo 对齐
    pub async fn update_user_info(&self, req: UpdateUserInfoReq) -> Result<EmptyResp> {
        self.post_json(routes::USER_UPDATE_USER_INFO, req).await
    }

    /// UpdateUserInfoEx = "/user/update_user_info_ex"，与 Go api.UpdateUserInfoEx 对齐（仅更新指定字段）
    pub async fn update_user_info_ex(&self, req: UpdateUserInfoExReq) -> Result<EmptyResp> {
        self.post_json(routes::USER_UPDATE_USER_INFO_EX, req).await
    }

    /// UserRegister = "/user/user_register"，与 Go api.UserRegister 对齐
    pub async fn user_register(&self, req: UserRegisterReq) -> Result<EmptyResp> {
        self.post_json(routes::USER_USER_REGISTER, req).await
    }

    /// GetUserClientConfig = "/user/get_user_client_config"，与 Go api.UserClientConfig 对齐
    pub async fn get_user_client_config(&self) -> Result<GetUserClientConfigResp> {
        let payload = serde_json::json!({ "userID": self.user_id });
        self.post_json(routes::USER_GET_USER_CLIENT_CONFIG, payload).await
    }

    async fn post_json<T: Serialize, R: serde::de::DeserializeOwned>(&self, path: &str, payload: T) -> Result<R> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, path);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&payload)
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("user api request failed: {}", e))?;
        extract_data(resp).await
    }
}
