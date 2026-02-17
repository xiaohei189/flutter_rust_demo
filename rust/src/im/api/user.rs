//! 用户 HTTP API（与 Go SDK pkg/api/api.go GetUsersInfo、服务端 POST /user/get_users_info 对齐）
//!
//! - Go: api.GetUsersInfo.Invoke(GetDesignateUsersReq) → GetDesignateUsersResp.UsersInfo
//! - 服务端: internal/api/user.go GetUsersPublicInfo → user.UserClient.GetDesignateUsers
//! 请求 JSON: { "userIDs": ["id1", "id2"] }
//! 响应 data: { "usersInfo": [ { "userID", "nickname", "faceURL", ... } ] }

use crate::im::http::{extract_data, make_client, HttpClient};
use anyhow::Result;
use serde::Deserialize;
use uuid::Uuid;

#[derive(serde::Serialize)]
struct GetUsersInfoReq {
    #[serde(rename = "userIDs")]
    user_ids: Vec<String>,
}

#[derive(Debug, Deserialize)]
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
        let url = format!("{}/user/get_users_info", self.api_base_url);
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
}
