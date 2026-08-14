//! HTTP 适配器 — impl ThirdServerApi for HttpThirdApi

use crate::error::Result;
use crate::http::client::HttpApiClient;
use crate::http::routes::{FCM_UPDATE_TOKEN, SET_APP_BADGE};
use crate::http::third::{FcmUpdateTokenReq, SetAppBadgeReq, ThirdServerApi};
use async_trait::async_trait;
use std::sync::Arc;

/// 基于 HTTP 的生产实现
pub struct HttpThirdApi {
    http_client: Arc<HttpApiClient>,
}

impl HttpThirdApi {
    pub fn new(http_client: Arc<HttpApiClient>) -> Self {
        Self { http_client }
    }
}

#[async_trait]
impl ThirdServerApi for HttpThirdApi {
    async fn update_fcm_token(&self, req: &FcmUpdateTokenReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(FCM_UPDATE_TOKEN, req).await?;
        Ok(())
    }

    async fn set_app_badge(&self, req: &SetAppBadgeReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(SET_APP_BADGE, req).await?;
        Ok(())
    }
}
