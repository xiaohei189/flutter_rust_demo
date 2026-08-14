//! Third 服务契约（FCM Token / App Badge / 日志上传）
//!
//! 对齐 Go SDK internal/third/api.go 与 pkg/api/api.go L102-103：
//! - FcmUpdateToken → POST /third/fcm_update_token
//! - SetAppBadge → POST /third/set_app_badge

use crate::error::Result;
use serde::{Deserialize, Serialize};

/// 更新 FCM Token 请求（对齐 protocol/third FcmUpdateTokenReq）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FcmUpdateTokenReq {
    pub platform_id: i32,
    pub fcm_token: String,
    pub account: String,
    pub expire_time: i64,
}

/// 设置 App 角标请求（对齐 protocol/third SetAppBadgeReq）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SetAppBadgeReq {
    pub user_id: String,
    pub app_unread_count: i32,
}

/// Third 服务端 API 契约（对齐 Go SDK Third 模块）
#[async_trait::async_trait]
pub trait ThirdServerApi: Send + Sync {
    async fn update_fcm_token(&self, req: &FcmUpdateTokenReq) -> Result<()>;
    async fn set_app_badge(&self, req: &SetAppBadgeReq) -> Result<()>;
}
