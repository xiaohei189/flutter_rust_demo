//! ThirdApi — SDK 对外 API 契约（FCM Token / App 角标）
//!
//! 对齐 Go SDK open_im_sdk/third.go：UpdateFcmToken / SetAppBadge

use crate::client::OpenIMClient;
use crate::domain::error::Result;
use crate::http::third::{FcmUpdateTokenReq, SetAppBadgeReq};
use crate::http::third_api::HttpThirdApi;
use crate::http::ThirdServerApi;
use async_trait::async_trait;

#[async_trait]
pub trait ThirdApi: Send + Sync {
    /// 更新 FCM Token（对齐 Go SDK `UpdateFcmToken` third/api.go L11-18）
    async fn update_fcm_token(&self, fcm_token: &str, expire_time: i64) -> Result<()>;

    /// 设置 App 角标未读数（对齐 Go SDK `SetAppBadge` third/api.go L20-25）
    async fn set_app_badge(&self, app_unread_count: i32) -> Result<()>;
}

#[async_trait]
impl ThirdApi for OpenIMClient {
    #[tracing::instrument(skip_all)]
    async fn update_fcm_token(&self, fcm_token: &str, expire_time: i64) -> Result<()> {
        let api = HttpThirdApi::new(self.context.infra.http_client.clone());
        let req = FcmUpdateTokenReq {
            platform_id: self.context.config.platform_id,
            fcm_token: fcm_token.to_string(),
            account: self.context.get_user_id(),
            expire_time,
        };
        api.update_fcm_token(&req).await
    }

    #[tracing::instrument(skip_all)]
    async fn set_app_badge(&self, app_unread_count: i32) -> Result<()> {
        let api = HttpThirdApi::new(self.context.infra.http_client.clone());
        let req = SetAppBadgeReq {
            user_id: self.context.get_user_id(),
            app_unread_count,
        };
        api.set_app_badge(&req).await
    }
}
