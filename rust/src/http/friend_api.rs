//! HTTP 适配器 — impl FriendServerApi for HttpFriendApi
//!
//! trait 定义在 `domain::ports::friend`

use crate::domain::error::Result;
use crate::http::client::HttpApiClient;
use crate::http::friend::{
    AcceptFriendApplicationReq, AddBlackReq, AddFriendReq, CheckFriendResult, DeleteFriendReq, FriendServerApi, GetBlackListResp, GetDesignatedFriendsReq, GetDesignatedFriendsResp,
    GetFriendApplyListReq, GetFriendApplyListResp, GetFriendApplyListServerResp, GetFriendListReq, GetFriendListResp, GetIncrementalFriendsReq, GetIncrementalFriendsResp, RefuseFriendApplicationReq,
    RemoveBlackReq, UpdateFriendsReq,
};
use crate::http::routes::{
    ACCEPT_FRIEND_APPLICATION, ADD_BLACK, ADD_FRIEND, CHECK_FRIEND, DELETE_FRIEND, GET_BLACK_LIST, GET_DESIGNATED_FRIENDS, GET_FRIEND_APPLY_LIST, GET_FRIEND_LIST, GET_INCREMENTAL_FRIENDS,
    GET_SELF_FRIEND_APPLY_LIST, GET_SELF_UNHANDLED_APPLY_COUNT, REFUSE_FRIEND_APPLICATION, REMOVE_BLACK, UPDATE_FRIENDS,
};
use crate::http::types::Pagination;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::sync::Arc;

/// 基于 HTTP 的生产实现
pub struct HttpFriendApi {
    http_client: Arc<HttpApiClient>,
}

impl HttpFriendApi {
    pub fn new(http_client: Arc<HttpApiClient>) -> Self {
        Self { http_client }
    }
}

#[async_trait]
impl FriendServerApi for HttpFriendApi {
    async fn get_friend_list(&self, req: &GetFriendListReq) -> Result<GetFriendListResp> {
        Ok(self.http_client.post(GET_FRIEND_LIST, req).await?)
    }

    async fn get_incremental_friends(&self, req: &GetIncrementalFriendsReq) -> Result<GetIncrementalFriendsResp> {
        Ok(self.http_client.post(GET_INCREMENTAL_FRIENDS, req).await?)
    }

    async fn get_designated_friends(&self, req: &GetDesignatedFriendsReq) -> Result<GetDesignatedFriendsResp> {
        Ok(self.http_client.post(GET_DESIGNATED_FRIENDS, req).await?)
    }

    async fn update_friends(&self, req: &UpdateFriendsReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(UPDATE_FRIENDS, req).await?;
        Ok(())
    }

    async fn add_friend(&self, req: &AddFriendReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(ADD_FRIEND, req).await?;
        Ok(())
    }

    async fn delete_friend(&self, req: &DeleteFriendReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(DELETE_FRIEND, req).await?;
        Ok(())
    }

    async fn check_friend(&self, user_ids: &[String]) -> Result<Vec<CheckFriendResult>> {
        #[derive(Serialize)]
        struct CheckFriendReq {
            #[serde(rename = "userIDList")]
            user_ids: Vec<String>,
        }
        #[derive(Deserialize, Default)]
        struct CheckFriendResp {
            #[serde(rename = "resultInfo")]
            result_info: Vec<CheckFriendResult>,
        }
        let req = CheckFriendReq { user_ids: user_ids.to_vec() };
        let resp: CheckFriendResp = self.http_client.post(CHECK_FRIEND, &req).await?;
        Ok(resp.result_info)
    }

    async fn get_black_list(&self, user_id: &str) -> Result<GetBlackListResp> {
        #[derive(Serialize)]
        struct GetBlackListReq {
            #[serde(rename = "userID")]
            user_id: String,
            pagination: Pagination,
        }
        let req = GetBlackListReq {
            user_id: user_id.to_string(),
            pagination: Pagination { page_number: 1, show_number: 1000 },
        };
        Ok(self.http_client.post(GET_BLACK_LIST, &req).await?)
    }

    async fn add_black(&self, req: &AddBlackReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(ADD_BLACK, req).await?;
        Ok(())
    }

    async fn remove_black(&self, req: &RemoveBlackReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(REMOVE_BLACK, req).await?;
        Ok(())
    }

    async fn get_friend_apply_list(&self, req: &GetFriendApplyListReq) -> Result<GetFriendApplyListResp> {
        let raw: serde_json::Value = self.http_client.post(GET_FRIEND_APPLY_LIST, req).await?;
        let server: GetFriendApplyListServerResp = serde_json::from_value(raw).map_err(|e| crate::domain::error::SdkError::unknown(format!("解析好友申请列表失败: {}", e)))?;
        Ok(server.into())
    }

    async fn get_self_friend_apply_list(&self, req: &GetFriendApplyListReq) -> Result<GetFriendApplyListResp> {
        let raw: serde_json::Value = self.http_client.post(GET_SELF_FRIEND_APPLY_LIST, req).await?;
        let server: GetFriendApplyListServerResp = serde_json::from_value(raw).map_err(|e| crate::domain::error::SdkError::unknown(format!("解析好友申请列表失败: {}", e)))?;
        Ok(server.into())
    }

    async fn get_self_unhandled_apply_count(&self, user_id: &str) -> Result<i32> {
        #[derive(Serialize)]
        struct UnhandledCountReq {
            user_id: String,
        }
        #[derive(Deserialize, Default)]
        struct UnhandledCountResp {
            count: i32,
        }
        let req = UnhandledCountReq { user_id: user_id.to_string() };
        let resp: UnhandledCountResp = self.http_client.post(GET_SELF_UNHANDLED_APPLY_COUNT, &req).await?;
        Ok(resp.count)
    }

    async fn accept_friend_application(&self, req: &AcceptFriendApplicationReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(ACCEPT_FRIEND_APPLICATION, req).await?;
        Ok(())
    }

    async fn refuse_friend_application(&self, req: &RefuseFriendApplicationReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(REFUSE_FRIEND_APPLICATION, req).await?;
        Ok(())
    }
}
