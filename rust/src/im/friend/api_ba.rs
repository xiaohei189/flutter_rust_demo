//! 好友 HTTP API 客户端
//!
//! 负责所有好友相关的 HTTP 请求

use crate::im::{
    friend::types::FriendRequestsResp,
    http::{make_client, HttpClient, HttpResponseExtractor},
};
use anyhow::Result;
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
    pub fn new(
        client: reqwest::Client,
        api_base_url: String,
        user_id: String,
        token: String,
    ) -> Self {
        Self {
            client: make_client(client, token),
            api_base_url,
            user_id,
        }
    }

    // /// 从服务器获取好友申请列表（全量）
    pub async fn get_friend_requests(
        &mut self,
    ) -> Result<Vec<crate::im::friend::types::FriendRequest>> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/friend/get_friend_apply_list", self.api_base_url);
        let mut client = self.client.clone();
        let service = client.ready().await?;

        // 使用 ServiceExt 的 post 方法
        let req = service
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "pagination": {
                    "pageNumber": 1,
                    "showNumber": 100
                }
            }))?;

        let data: FriendRequestsResp = HttpResponseExtractor::send(req).await?;

        Ok(data.friend_requests)
    }
}

#[cfg(test)]
mod tests {
  
    use tracing::info;
    use test_context::test_context;
    use test_context::AsyncTestContext;
    use crate::api::LoginResponse;
    use crate::im::auth::login_async;
    use crate::im::friend::api_ba::FriendApi;
    use crate::im::logger::logger::init_logger;

    #[derive(Clone)]
    pub struct AppCtx {
        pub token: LoginResponse,
    }

    impl AsyncTestContext for AppCtx {
        async fn setup() -> Self {
            init_logger(
                "debug,sqlx=debug,hyper_util::client=info,reqwest=info",
            );
            // 异步登录获取 token
            let area_code = "+86".to_string();
            let password = "284f3d09ea0695538e4ded1c1766d73a".to_string();
            let platform = 5;

            let token_info = login_async(area_code, "17764338283".to_string(), password, platform)
                .await
                .expect("登录失败");

            AppCtx { token: token_info }
        }

        async fn teardown(self) {
            // 如果需要，可以在这里做清理
        }
    }
  
    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_incremental_friends(ctx: &mut AppCtx) {
        info!("--------------------------------");
        info!("token: {:?}", ctx.token);

        let mut friend_api = FriendApi::new(
            reqwest::Client::new(),
            "http://localhost:10002".to_string(),
            ctx.token.data.as_ref().unwrap().user_id.clone(),
            ctx.token.data.as_ref().unwrap().im_token.clone(),
        );
        let resp = friend_api.get_friend_requests().await.unwrap();
        info!("获取好友申请列表成功: {:?}", resp);
    }
}
