//! 好友 HTTP API，路径与 openim-sdk-core pkg/api/api.go 完全一致

use super::response_extractor::extract_data;
use super::routes;
use super::{make_client, HttpClient};
use crate::im::model::conversation::RequestPagination;
use crate::im::model::friend::{AllFriendsResp, BlackList, FriendRequest, FriendRequestsResp, IncrementalFriendsResp};
use crate::im::model::message::EmptyResp;
use anyhow::Result;
use openim_protocol::sdkws;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ----- 与 Go api 对齐的请求/响应（camelCase） -----

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct GetSelfFriendApplicationListReq {
    user_id: String,
    pagination: RequestPagination,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    handle_results: Vec<i32>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GetSelfFriendApplicationListResp {
    #[serde(rename = "friendRequests", default)]
    friend_requests: Vec<FriendRequest>,
    #[serde(default)]
    total: Option<i32>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct GetSelfUnhandledApplyCountReq {
    user_id: String,
    time: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GetSelfUnhandledApplyCountResp {
    count: i64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct ImportFriendReq {
    owner_user_id: String,
    #[serde(rename = "friendUserIDs")]
    friend_user_i_ds: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct GetDesignatedFriendsApplyReq {
    from_user_id: String,
    to_user_id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GetDesignatedFriendsApplyResp {
    #[serde(rename = "friendRequests", default)]
    friend_requests: Vec<FriendRequest>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct GetDesignatedFriendsReq {
    owner_user_id: String,
    #[serde(rename = "friendUserIDs")]
    friend_user_i_ds: Vec<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GetDesignatedFriendsResp {
    #[serde(rename = "friendsInfo", default)]
    friends_info: Vec<sdkws::FriendInfo>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct AddFriendResponseReq {
    from_user_id: String,
    to_user_id: String,
    handle_result: i32,
    handle_msg: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct UpdateFriendsReq {
    owner_user_id: String,
    #[serde(rename = "friendUserIDs")]
    friend_user_i_ds: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    is_pinned: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    remark: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    ex: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct AddBlackReq {
    owner_user_id: String,
    black_user_id: String,
    #[serde(skip_serializing_if = "String::is_empty")]
    ex: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct RemoveBlackReq {
    owner_user_id: String,
    black_user_id: String,
}

/// GetRecvFriendApplicationList 请求（GetPaginationFriendsApplyToReq）
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct GetRecvFriendApplicationListReq {
    user_id: String,
    pagination: RequestPagination,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    handle_results: Vec<i32>,
}

/// GetFriendList 请求（GetPaginationFriendsReq）
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct GetFriendListReq {
    pagination: RequestPagination,
    user_id: String,
}

/// GetBlackList 请求（GetPaginationBlacksReq）
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct GetBlackListReq {
    user_id: String,
    pagination: RequestPagination,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GetBlackListData {
    #[serde(deserialize_with = "crate::im::model::friend::deserialize_vec_or_null")]
    blacks: Vec<BlackList>,
    #[serde(default)]
    total: Option<i32>,
}

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
        let url = format!("{}{}", self.api_base_url, routes::FRIEND_GET_INCREMENTAL_FRIENDS);

        let resp = self
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
            .map_err(|e| anyhow::anyhow!("HTTP request failed: {}", e))?;

        extract_data(resp).await
    }

    /// 从服务器获取全量好友 userID 列表
    pub async fn get_full_friend_user_ids(&self) -> Result<(u64, String, Vec<String>)> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, routes::FRIEND_GET_FULL_FRIEND_USER_IDS);

        #[derive(Deserialize)]
        struct FriendIdsData {
            version: u64,
            #[serde(rename = "versionID")]
            version_id: String,
            #[serde(rename = "userIDs")]
            user_ids: Vec<String>,
        }

        let resp = self
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
            .map_err(|e| anyhow::anyhow!("HTTP request failed: {}", e))?;

        let data: FriendIdsData = extract_data(resp).await?;

        Ok((data.version, data.version_id, data.user_ids))
    }

    /// GetFriendList：从服务器获取好友列表（分页，与 Go 对齐）
    pub async fn get_friend_list(&self, pagination: RequestPagination) -> Result<AllFriendsResp> {
        let req = GetFriendListReq {
            pagination,
            user_id: self.user_id.clone(),
        };
        self.post_json(routes::FRIEND_GET_FRIEND_LIST, req).await
    }

    /// 从服务器获取全量好友列表（默认分页的便捷方法）
    pub async fn get_all_friends(&self) -> Result<AllFriendsResp> {
        self.get_friend_list(RequestPagination {
            page_number: 1,
            show_number: 1000,
        })
        .await
    }

    /// GetBlackList：从服务器获取黑名单列表（分页，与 Go 对齐）
    pub async fn get_black_list_paginated(&self, pagination: RequestPagination) -> Result<Vec<BlackList>> {
        let req = GetBlackListReq {
            user_id: self.user_id.clone(),
            pagination,
        };
        let data: GetBlackListData = self.post_json(routes::FRIEND_GET_BLACK_LIST, req).await?;
        Ok(data.blacks)
    }

    /// 从服务器获取黑名单列表（默认分页的便捷方法）
    pub async fn get_black_list(&self) -> Result<Vec<BlackList>> {
        self.get_black_list_paginated(RequestPagination {
            page_number: 1,
            show_number: 1000,
        })
        .await
    }

    /// 申请添加好友（与 Go AddFriend / api.AddFriend 对齐），POST /friend/add_friend
    pub async fn add_friend(&self, to_user_id: &str, req_msg: &str) -> Result<()> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, routes::FRIEND_ADD_FRIEND);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "fromUserID": self.user_id,
                "toUserID": to_user_id,
                "reqMsg": req_msg,
                "ex": "",
            }))
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("add_friend request failed: {}", e))?;
        let body = resp.bytes().await?;
        let api: crate::im::model::ApiResponse<Option<serde_json::Value>> = serde_json::from_slice(&body)
            .map_err(|e| anyhow::anyhow!("add_friend parse response failed: {}", e))?;
        if api.err_code != 0 {
            anyhow::bail!("add_friend API error: errCode={} errMsg={}", api.err_code, api.err_msg);
        }
        Ok(())
    }

    /// 删除好友（与 Go DeleteFriend / api.DeleteFriend 对齐），POST /friend/delete_friend，成功后需本地删库
    pub async fn delete_friend(&self, friend_user_id: &str) -> Result<()> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}{}", self.api_base_url, routes::FRIEND_DELETE_FRIEND);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "ownerUserID": self.user_id,
                "friendUserID": friend_user_id,
            }))
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("delete_friend request failed: {}", e))?;
        let body = resp.bytes().await?;
        let api: crate::im::model::ApiResponse<Option<serde_json::Value>> = serde_json::from_slice(&body)
            .map_err(|e| anyhow::anyhow!("delete_friend parse response failed: {}", e))?;
        if api.err_code != 0 {
            anyhow::bail!("delete_friend API error: errCode={} errMsg={}", api.err_code, api.err_msg);
        }
        Ok(())
    }

    /// GetRecvFriendApplicationList：获取收到的好友申请列表（分页 + handleResults 筛选，与 Go 对齐）
    pub async fn get_recv_friend_application_list(
        &self,
        pagination: RequestPagination,
        handle_results: Vec<i32>,
    ) -> Result<Vec<FriendRequest>> {
        let req = GetRecvFriendApplicationListReq {
            user_id: self.user_id.clone(),
            pagination,
            handle_results,
        };
        let resp: FriendRequestsResp = self.post_json(routes::FRIEND_GET_FRIEND_APPLY_LIST, req).await?;
        Ok(resp.friend_requests)
    }

    /// 从服务器获取好友申请列表（默认分页的便捷方法）
    pub async fn get_friend_requests(&self) -> Result<Vec<FriendRequest>> {
        self.get_recv_friend_application_list(
            RequestPagination {
                page_number: 1,
                show_number: 100,
            },
            vec![],
        )
        .await
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
            .map_err(|e| anyhow::anyhow!("friend api request failed: {}", e))?;
        extract_data(resp).await
    }

    /// GetSelfFriendApplicationList：获取自己发出的好友申请列表（分页）
    pub async fn get_self_friend_application_list(
        &self,
        pagination: RequestPagination,
        handle_results: Vec<i32>,
    ) -> Result<Vec<FriendRequest>> {
        let req = GetSelfFriendApplicationListReq {
            user_id: self.user_id.clone(),
            pagination,
            handle_results,
        };
        let r: GetSelfFriendApplicationListResp =
            self.post_json(routes::FRIEND_GET_SELF_FRIEND_APPLY_LIST, req).await?;
        Ok(r.friend_requests)
    }

    /// GetSelfUnhandledApplyCount：获取自己发出的未处理申请数量
    pub async fn get_self_unhandled_apply_count(&self, time: i64) -> Result<i64> {
        let req = GetSelfUnhandledApplyCountReq {
            user_id: self.user_id.clone(),
            time,
        };
        let r: GetSelfUnhandledApplyCountResp =
            self.post_json(routes::FRIEND_GET_SELF_UNHANDLED_APPLY_COUNT, req).await?;
        Ok(r.count)
    }

    /// ImportFriendList：批量导入好友
    pub async fn import_friend_list(&self, friend_user_ids: Vec<String>) -> Result<EmptyResp> {
        let req = ImportFriendReq {
            owner_user_id: self.user_id.clone(),
            friend_user_i_ds: friend_user_ids,
        };
        self.post_json(routes::FRIEND_IMPORT_FRIEND, req).await
    }

    /// GetDesignatedFriendsApply：获取指定 from/to 的好友申请
    pub async fn get_designated_friends_apply(
        &self,
        from_user_id: &str,
        to_user_id: &str,
    ) -> Result<Vec<FriendRequest>> {
        let req = GetDesignatedFriendsApplyReq {
            from_user_id: from_user_id.to_string(),
            to_user_id: to_user_id.to_string(),
        };
        let r: GetDesignatedFriendsApplyResp =
            self.post_json(routes::FRIEND_GET_DESIGNATED_FRIEND_APPLY, req).await?;
        Ok(r.friend_requests)
    }

    /// GetDesignatedFriends：获取指定好友信息
    pub async fn get_designated_friends(&self, friend_user_ids: Vec<String>) -> Result<Vec<sdkws::FriendInfo>> {
        let req = GetDesignatedFriendsReq {
            owner_user_id: self.user_id.clone(),
            friend_user_i_ds: friend_user_ids,
        };
        let r: GetDesignatedFriendsResp =
            self.post_json(routes::FRIEND_GET_DESIGNATED_FRIENDS, req).await?;
        Ok(r.friends_info)
    }

    /// AddFriendResponse：通过/拒绝好友申请
    pub async fn add_friend_response(
        &self,
        from_user_id: &str,
        to_user_id: &str,
        handle_result: i32,
        handle_msg: &str,
    ) -> Result<EmptyResp> {
        let req = AddFriendResponseReq {
            from_user_id: from_user_id.to_string(),
            to_user_id: to_user_id.to_string(),
            handle_result,
            handle_msg: handle_msg.to_string(),
        };
        self.post_json(routes::FRIEND_ADD_FRIEND_RESPONSE, req).await
    }

    /// UpdateFriends：更新好友备注/置顶等
    pub async fn update_friends(
        &self,
        friend_user_ids: Vec<String>,
        is_pinned: Option<bool>,
        remark: Option<String>,
        ex: Option<String>,
    ) -> Result<EmptyResp> {
        let req = UpdateFriendsReq {
            owner_user_id: self.user_id.clone(),
            friend_user_i_ds: friend_user_ids,
            is_pinned,
            remark,
            ex,
        };
        self.post_json(routes::FRIEND_UPDATE_FRIENDS, req).await
    }

    /// AddBlack：拉黑用户
    pub async fn add_black(&self, black_user_id: &str, ex: &str) -> Result<EmptyResp> {
        let req = AddBlackReq {
            owner_user_id: self.user_id.clone(),
            black_user_id: black_user_id.to_string(),
            ex: ex.to_string(),
        };
        self.post_json(routes::FRIEND_ADD_BLACK, req).await
    }

    /// RemoveBlack：移除黑名单
    pub async fn remove_black(&self, black_user_id: &str) -> Result<EmptyResp> {
        let req = RemoveBlackReq {
            owner_user_id: self.user_id.clone(),
            black_user_id: black_user_id.to_string(),
        };
        self.post_json(routes::FRIEND_REMOVE_BLACK, req).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::im::http_client::auth::login_async;
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
                    init_logger("debug,sqlx=trace,hyper_util::client=info,reqwest=info");
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
