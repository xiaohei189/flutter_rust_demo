//! HTTP 适配器 — impl UserServerApi for HttpUserApi
//!
//! trait 定义在 `domain::ports::user`

use crate::domain::error::Result;
use crate::domain::ports::user::{GetUsersInfoReq, GetUsersInfoResp, UpdateUserInfoReq, UpdateUserInfoResp, UserServerApi};
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{GET_USERS_INFO, SET_GLOBAL_MSG_RECV_OPT, UPDATE_USER_INFO};
use async_trait::async_trait;
use std::sync::Arc;

/// 基于 HTTP 的生产实现
pub struct HttpUserApi {
    http_client: Arc<HttpApiClient>,
}

impl HttpUserApi {
    pub fn new(http_client: Arc<HttpApiClient>) -> Self {
        Self { http_client }
    }
}

#[async_trait]
impl UserServerApi for HttpUserApi {
    async fn get_users_info(&self, req: &GetUsersInfoReq) -> Result<GetUsersInfoResp> {
        Ok(self.http_client.post(GET_USERS_INFO, req).await?)
    }

    async fn update_user_info(&self, req: &UpdateUserInfoReq) -> Result<UpdateUserInfoResp> {
        Ok(self.http_client.post(UPDATE_USER_INFO, req).await?)
    }

    async fn set_global_msg_recv_opt(&self, user_id: &str, global_recv_opt: i32) -> Result<()> {
        let req = serde_json::json!({
            "userID": user_id,
            "globalRecvMsgOpt": global_recv_opt,
        });
        let _: serde_json::Value = self.http_client.post(SET_GLOBAL_MSG_RECV_OPT, &req).await?;
        Ok(())
    }
}