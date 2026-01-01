//! 好友 HTTP API 客户端
//!
//! 负责所有好友相关的 HTTP 请求

use crate::im::friend::models::BlackList;
use crate::im::friend::types::{FriendRequestsResp, IncrementalFriendsResp};
use crate::im::types::ApiResponse;
use anyhow::{Context, Result};
use serde::Deserialize;
use tracing::{debug, error, info};
use uuid::Uuid;

/// 好友相关的 HTTP API 客户端
pub struct FriendApi {
    client: reqwest::Client,
    api_base_url: String,
    user_id: String,
}

impl FriendApi {
    /// 创建新的好友 API 客户端
    ///
    /// `client` 应该已经在外部配置好认证拦截器
    pub fn new(client: reqwest::Client, api_base_url: String, user_id: String) -> Self {
        Self {
            client,
            api_base_url,
            user_id,
        }
    }

    /// 从服务器获取增量好友
    pub async fn get_incremental_friends(
        &self,
        version: u64,
        version_id: &str,
    ) -> Result<IncrementalFriendsResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/friend/get_incremental_friends", self.api_base_url);

        info!("[FriendAPI] 📡 请求增量好友同步");
        debug!("[FriendAPI]   请求URL: {}", url);
        debug!(
            "[FriendAPI]   用户ID: {}, 操作ID: {}",
            self.user_id, operation_id
        );

        let response = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "version": version,
                "versionID": version_id,
            }))
            .send()
            .await
            .context("请求失败")?;

        let status = response.status();
        let body_bytes = response.bytes().await.context("读取响应 body 失败")?;
        let body_str = String::from_utf8_lossy(&body_bytes);
        info!("[FriendAPI] 增量好友同步响应 Body: {}", body_str);

        if !status.is_success() {
            error!(
                "[FriendAPI] 增量好友同步请求失败，HTTP状态: {}, 响应: {}",
                status, body_str
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, body_str));
        }

        let api_resp: ApiResponse<IncrementalFriendsResp> = serde_json::from_slice(&body_bytes)
            .map_err(|e| {
                error!(
                    "[FriendAPI] 增量好友同步反序列化失败: {:?}\n原始响应: {}",
                    e, body_str
                );
                anyhow::anyhow!("反序列化响应失败: {:?}", e)
            })?;

        if api_resp.err_code != 0 {
            error!(
                "[FriendAPI] 增量好友同步服务器错误，错误码: {}, 错误信息: {}",
                api_resp.err_code, api_resp.err_msg
            );
            return Err(anyhow::anyhow!(
                "服务器错误 {}: {}",
                api_resp.err_code,
                api_resp.err_msg
            ));
        }

        let resp = api_resp
            .data
            .ok_or_else(|| anyhow::anyhow!("响应中缺少 data 字段"))?;

        Ok(resp)
    }

    /// 从服务器获取全量好友 userID 列表
    pub async fn get_full_friend_user_ids(&self) -> Result<(u64, String, Vec<String>)> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/friend/get_full_friend_user_ids", self.api_base_url);

        debug!("[API] 📡 请求全量好友ID列表   请求URL: {}, 操作ID: {}", url, operation_id);

        #[derive(Deserialize)]
        struct FriendIdsData {
            version: u64,
            #[serde(rename = "versionID")]
            version_id: String,
            #[serde(rename = "userIDs")]
            user_ids: Vec<String>,
        }

        let response = match self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "idHash": 0u64,
            }))
            .send()
            .await
        {
            Ok(resp) => resp,
            Err(e) => {
                error!("[FriendAPI] 全量好友ID列表请求失败: {:?}", e);
                return Err(anyhow::anyhow!("请求失败: {:?}", e));
            }
        };

        let status = response.status();
        let body_bytes = response.bytes().await.context("读取响应 body 失败")?;
        let body_str = String::from_utf8_lossy(&body_bytes);
        info!("[FriendAPI] 全量好友ID列表响应 Body: {}", body_str);

        if !status.is_success() {
            error!(
                "[FriendAPI] 全量好友ID列表请求失败，HTTP状态: {}, 响应: {}",
                status, body_str
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, body_str));
        }

        let api_resp: ApiResponse<FriendIdsData> =
            serde_json::from_slice(&body_bytes).map_err(|e| {
                error!(
                    "[FriendAPI] 全量好友ID列表反序列化失败: {:?}\n原始响应: {}",
                    e, body_str
                );
                anyhow::anyhow!("反序列化响应失败: {:?}", e)
            })?;

        if api_resp.err_code != 0 {
            error!(
                "[FriendAPI] 全量好友ID列表服务器错误，错误码: {}, 错误信息: {}",
                api_resp.err_code, api_resp.err_msg
            );
            return Err(anyhow::anyhow!(
                "服务器错误 {}: {}",
                api_resp.err_code,
                api_resp.err_msg
            ));
        }

        let data = api_resp
            .data
            .ok_or_else(|| anyhow::anyhow!("响应中缺少 data 字段"))?;

        info!(
            "[FriendAPI] ✅ 全量好友ID列表响应，版本: {}, 版本ID: {}，好友数: {}",
            data.version,
            data.version_id,
            data.user_ids.len()
        );

        Ok((data.version, data.version_id, data.user_ids))
    }

    /// 从服务器获取全量好友列表
    pub async fn get_all_friends(&self) -> Result<Vec<crate::im::friend::models::LocalFriend>> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/friend/get_friend_list", self.api_base_url);

        info!("[FriendAPI] 📡 请求全量好友列表");
        debug!("[FriendAPI]   请求URL: {}", url);
        debug!(
            "[FriendAPI]   用户ID: {}, 操作ID: {}",
            self.user_id, operation_id
        );

        #[derive(Deserialize)]
        struct AllFriendsData {
            #[serde(rename = "friendsInfo")]
            friends_info: Vec<crate::im::friend::models::LocalFriend>,
        }

        let response = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "pagination": {
                    "pageNumber": 1,
                    "showNumber": 1000
                }
            }))
            .send()
            .await
            .context("请求失败")?;

        let status = response.status();
        let body_bytes = response.bytes().await.context("读取响应 body 失败")?;
        let body_str = String::from_utf8_lossy(&body_bytes);
        info!("[FriendAPI] 全量好友列表响应 Body: {}", body_str);

        if !status.is_success() {
            error!(
                "[FriendAPI] 全量好友列表请求失败，HTTP状态: {}, 响应: {}",
                status, body_str
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, body_str));
        }

        let api_resp: ApiResponse<AllFriendsData> =
            serde_json::from_slice(&body_bytes).map_err(|e| {
                error!(
                    "[FriendAPI] 全量好友列表反序列化失败: {:?}\n原始响应: {}",
                    e, body_str
                );
                anyhow::anyhow!("反序列化响应失败: {:?}", e)
            })?;

        if api_resp.err_code != 0 {
            error!(
                "[FriendAPI] 全量好友列表服务器错误，错误码: {}, 错误信息: {}",
                api_resp.err_code, api_resp.err_msg
            );
            return Err(anyhow::anyhow!(
                "服务器错误 {}: {}",
                api_resp.err_code,
                api_resp.err_msg
            ));
        }

        let data = api_resp
            .data
            .ok_or_else(|| anyhow::anyhow!("响应中缺少 data 字段"))?;

        info!(
            "[FriendAPI] ✅ 全量好友列表响应，好友数: {}",
            data.friends_info.len()
        );

        Ok(data.friends_info)
    }

    /// 从服务器获取黑名单列表（全量）
    pub async fn get_black_list(&self) -> Result<Vec<BlackList>> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/friend/get_black_list", self.api_base_url);

        info!("[FriendAPI] 📡 请求黑名单列表");
        debug!("[FriendAPI]   请求URL: {}", url);
        debug!(
            "[FriendAPI]   用户ID: {}, 操作ID: {}",
            self.user_id, operation_id
        );

        #[derive(Deserialize)]
        struct BlackListData {
            #[serde(rename = "blacks")]
            #[serde(deserialize_with = "crate::im::friend::types::deserialize_vec_or_null")]
            blacks: Vec<BlackList>,
            #[serde(default)]
            total: Option<i32>,
        }

        let response = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "pagination": {
                    "pageNumber": 1,
                    "showNumber": 1000
                }
            }))
            .send()
            .await
            .context("请求失败")?;

        let status = response.status();
        let body_bytes = response.bytes().await.context("读取响应 body 失败")?;
        let body_str = String::from_utf8_lossy(&body_bytes);
        info!("[FriendAPI] 黑名单列表响应 Body: {}", body_str);

        if !status.is_success() {
            error!(
                "[FriendAPI] 黑名单列表请求失败，HTTP状态: {}, 响应: {}",
                status, body_str
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, body_str));
        }

        let api_resp: ApiResponse<BlackListData> =
            serde_json::from_slice(&body_bytes).map_err(|e| {
                error!(
                    "[FriendAPI] 黑名单列表反序列化失败: {:?}\n原始响应: {}",
                    e, body_str
                );
                anyhow::anyhow!("反序列化响应失败: {:?}", e)
            })?;

        if api_resp.err_code != 0 {
            error!(
                "[FriendAPI] 黑名单列表服务器错误，错误码: {}, 错误信息: {}",
                api_resp.err_code, api_resp.err_msg
            );
            return Err(anyhow::anyhow!(
                "服务器错误 {}: {}",
                api_resp.err_code,
                api_resp.err_msg
            ));
        }

        let data = api_resp
            .data
            .ok_or_else(|| anyhow::anyhow!("响应中缺少 data 字段"))?;

        info!(
            "[FriendAPI] ✅ 黑名单列表响应，条目数: {}",
            data.blacks.len()
        );

        Ok(data.blacks)
    }

    /// 从服务器获取好友申请列表（全量）
    pub async fn get_friend_requests(
        &self,
    ) -> Result<Vec<crate::im::friend::types::FriendRequest>> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/friend/get_friend_apply_list", self.api_base_url);

        info!("[FriendAPI] 📡 请求好友申请列表");
        debug!("[FriendAPI]   请求URL: {}", url);
        debug!(
            "[FriendAPI]   用户ID: {}, 操作ID: {}",
            self.user_id, operation_id
        );

        let response = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "pagination": {
                    "pageNumber": 1,
                    "showNumber": 100
                }
            }))
            .send()
            .await
            .context("请求失败")?;

        let status = response.status();
        let body_bytes = response.bytes().await.context("读取响应 body 失败")?;
        let body_str = String::from_utf8_lossy(&body_bytes);
        info!("[FriendAPI] 好友申请列表响应 Body: {}", body_str);

        if !status.is_success() {
            error!(
                "[FriendAPI] 好友申请列表请求失败，HTTP状态: {}, 响应: {}",
                status, body_str
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, body_str));
        }

        let api_resp: ApiResponse<FriendRequestsResp> = serde_json::from_slice(&body_bytes)
            .map_err(|e| {
                error!(
                    "[FriendAPI] 好友申请列表反序列化失败: {:?}\n原始响应: {}",
                    e, body_str
                );
                anyhow::anyhow!("反序列化响应失败: {:?}", e)
            })?;

        if api_resp.err_code != 0 {
            error!(
                "[FriendAPI] 好友申请列表服务器错误，错误码: {}, 错误信息: {}",
                api_resp.err_code, api_resp.err_msg
            );
            return Err(anyhow::anyhow!(
                "服务器错误 {}: {}",
                api_resp.err_code,
                api_resp.err_msg
            ));
        }

        let resp = api_resp
            .data
            .ok_or_else(|| anyhow::anyhow!("响应中缺少 data 字段"))?;

        info!(
            "[FriendAPI] ✅ 好友申请列表响应，条目数: {}",
            resp.friend_requests.len()
        );

        Ok(resp.friend_requests)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::im::auth::login_async;
    #[tokio::test]
    async fn test_get_incremental_friends() {
        let area_code = "+86".to_string();
        let password = "284f3d09ea0695538e4ded1c1766d73a".to_string(); // 测试密码
        let platform = 5;
    
        let token_info = login_async(area_code, "17764338283".to_string(), password, platform)
            .await.unwrap();
    
        let (user_id, im_token) = if let Some(data) = &token_info.data {
            (data.user_id.clone(), data.im_token.clone())
        } else {
            panic!("登录失败：服务器返回数据为空");
        };
        let api = FriendApi::new(reqwest::Client::new(), "http://localhost:10002".to_string(), "1234567890".to_string());
        let resp = api.get_incremental_friends(0, "").await.unwrap();
        println!("{:?}", resp);
    }
}