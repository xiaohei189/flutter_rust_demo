//! HTTP 适配器 — impl OnlineStatusServerApi for HttpOnlineStatusApi
//!
//! trait 定义在 `domain::ports::online`

use crate::error::Result;
use crate::http::client::HttpApiClient;
use crate::http::online::{GetSubscribeUsersStatusResp, GetUserStatusReq, GetUserStatusResp, OnlineStatusServerApi, SubscribeUsersStatusReq, SubscribeUsersStatusResp, UnsubscribeUsersStatusReq};
use crate::http::routes::{GET_SUBSCRIBE_USERS_STATUS, GET_USER_STATUS, SUBSCRIBE_USERS_STATUS, UNSUBSCRIBE_USERS_STATUS};
use async_trait::async_trait;
use std::sync::Arc;

/// 基于 HTTP 的生产实现
pub struct HttpOnlineStatusApi {
    http_client: Arc<HttpApiClient>,
}

impl HttpOnlineStatusApi {
    pub fn new(http_client: Arc<HttpApiClient>) -> Self {
        Self { http_client }
    }
}

#[async_trait]
impl OnlineStatusServerApi for HttpOnlineStatusApi {
    async fn get_user_status(&self, req: &GetUserStatusReq) -> Result<GetUserStatusResp> {
        Ok(self.http_client.post(GET_USER_STATUS, req).await?)
    }

    async fn subscribe_users_status(&self, req: &SubscribeUsersStatusReq) -> Result<SubscribeUsersStatusResp> {
        Ok(self.http_client.post(SUBSCRIBE_USERS_STATUS, req).await?)
    }

    async fn unsubscribe_users_status(&self, req: &UnsubscribeUsersStatusReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(UNSUBSCRIBE_USERS_STATUS, req).await?;
        Ok(())
    }

    async fn get_subscribe_users_status(&self) -> Result<GetSubscribeUsersStatusResp> {
        Ok(self.http_client.post(GET_SUBSCRIBE_USERS_STATUS, &()).await?)
    }
}
