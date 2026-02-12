//! 好友 HTTP API 客户端
//!
//! 负责所有好友相关的 HTTP 请求

use crate::im::http::{make_client, HttpClient, HttpResponseExtractor};
use crate::im::model::friend::{AllFriendsResp, BlackList, FriendRequest, FriendRequestsResp, IncrementalFriendsResp};
use anyhow::Result;
use serde::Deserialize;
use tower::ServiceExt;
use tower_http_client::ServiceExt as _;
use uuid::Uuid;

/// 好友相关的 HTTP API 客户端
#[derive(Clone)]
pub struct FriendApi {
    client: HttpClient,
    api_base_url: String,
    user_id: String,
}

impl FriendApi {
    /// 创建新的好友 API 客户端
    ///
    /// `client` 应该已经在外部配置好认证拦截器
    pub fn new(client: reqwest::Client, api_base_url: String, user_id: String, token: &str) -> Self {
        Self {
            client: make_client(client, token),
            api_base_url,
            user_id,
        }
    }

    /// 从服务器获取增量好友
    pub async fn get_incremental_friends(&self, version: u64, version_id: &str) -> Result<IncrementalFriendsResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/friend/get_incremental_friends", self.api_base_url);

        let mut client = self.client.clone();
        let service = client.ready().await?;

        let req = service
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "version": version,
                "versionID": version_id,
            }))?;

        let resp: IncrementalFriendsResp = HttpResponseExtractor::send_data(req).await?;
        Ok(resp)
    }

    /// 从服务器获取全量好友 userID 列表
    pub async fn get_full_friend_user_ids(&self) -> Result<(u64, String, Vec<String>)> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/friend/get_full_friend_user_ids", self.api_base_url);

        #[derive(Deserialize)]
        struct FriendIdsData {
            version: u64,
            #[serde(rename = "versionID")]
            version_id: String,
            #[serde(rename = "userIDs")]
            user_ids: Vec<String>,
        }

        let mut client = self.client.clone();
        let service = client.ready().await?;
        let req = service
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "idHash": 0u64,
            }))?;

        let data: FriendIdsData = HttpResponseExtractor::send_data(req).await?;

        Ok((data.version, data.version_id, data.user_ids))
    }

    /// 从服务器获取全量好友列表
    pub async fn get_all_friends(&self) -> Result<AllFriendsResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/friend/get_friend_list", self.api_base_url);

        let mut client = self.client.clone();
        let service = client.ready().await?;
        let req = service
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "pagination": {
                    "pageNumber": 1,
                    "showNumber": 1000
                }
            }))?;

        let data: AllFriendsResp = HttpResponseExtractor::send_data(req).await?;

        Ok(data)
    }

    /// 从服务器获取黑名单列表（全量）
    pub async fn get_black_list(&self) -> Result<Vec<BlackList>> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/friend/get_black_list", self.api_base_url);
        #[derive(Deserialize)]
        struct BlackListData {
            #[serde(rename = "blacks")]
            #[serde(deserialize_with = "crate::im::model::friend::deserialize_vec_or_null")]
            blacks: Vec<BlackList>,
            #[serde(default)]
            total: Option<i32>,
        }

        let mut client = self.client.clone();
        let service = client.ready().await?;
        let req = service
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "pagination": {
                    "pageNumber": 1,
                    "showNumber": 1000
                }
            }))?;

        let data: BlackListData = HttpResponseExtractor::send_data(req).await?;
        Ok(data.blacks)
    }

    /// 从服务器获取好友申请列表（全量）
    pub async fn get_friend_requests(&self) -> Result<Vec<FriendRequest>> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/friend/get_friend_apply_list", self.api_base_url);
        let mut client = self.client.clone();
        let service = client.ready().await?;
        let req = service.post(&url).header("operationID", &operation_id).json(&serde_json::json!({
            "userID": self.user_id,
            "pagination": {
                "pageNumber": 1,
                "showNumber": 100
            }
        }))?;
        let resp: FriendRequestsResp = HttpResponseExtractor::send_data(req).await?;
        Ok(resp.friend_requests)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::im::http::login_async;
    use crate::im::logger::logger::init_logger;
    use test_context::test_context;
    use test_context::AsyncTestContext;
    use tokio::sync::OnceCell;
    use tracing::info;

    static APP_CTX: OnceCell<AppCtx> = OnceCell::const_new();

    #[derive(Clone)]
    pub struct AppCtx {
        pub api: FriendApi,
    }

    impl AsyncTestContext for AppCtx {
        async fn setup() -> Self {
            APP_CTX
                .get_or_init(|| async {
                    init_logger("debug,sqlx=debug,hyper_util::client=info,reqwest=info");
                    // 异步登录获取 token
                    let area_code = "+86".to_string();
                    let password = "284f3d09ea0695538e4ded1c1766d73a".to_string();
                    let platform = 5;

                    let token_info = login_async(area_code, "17764338283".to_string(), password, platform).await.expect("登录失败");
                    let api = FriendApi::new(reqwest::Client::new(), "http://localhost:10002".to_string(), token_info.user_id.clone(), &token_info.im_token);
                    AppCtx { api }
                })
                .await
                .clone()
        }

        async fn teardown(self) {
            // 如果需要，可以在这里做清理
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_friend_requests(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let requests = api.get_friend_requests().await.unwrap();
        info!("获取好友申请列表成功: {:?}", requests);
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_incremental_friends(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let resp = api.get_incremental_friends(0, "").await.unwrap();
        info!(
            "增量好友同步成功: version={}, version_id={}, full={}, count={}",
            resp.version,
            resp.version_id,
            resp.full,
            resp.insert.len() + resp.update.len() + resp.delete.len()
        );
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_full_friend_user_ids(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let (_ver, _ver_id, ids) = api.get_full_friend_user_ids().await.unwrap();
        info!("全量好友ID列表获取成功，数量: {}", ids.len());
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_all_friends(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let friends = api.get_all_friends().await.unwrap();
        info!("全量好友列表获取成功，数量: {}", friends.total);
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_black_list(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let blacks = api.get_black_list().await.unwrap();
        info!("黑名单列表获取成功，数量: {}", blacks.len());
    }
}
