//! Third 全局 FFI —— FCM Token / App 角标
//!
//! 对齐 Go SDK open_im_sdk/third.go：UpdateFcmToken / SetAppBadge

use crate::ffi::global::client_holder;
use anyhow::Result;

/// 更新 FCM Token（对齐 Go SDK `UpdateFcmToken`）
#[flutter_rust_bridge::frb]
pub async fn update_fcm_token(fcm_token: String, expire_time: i64) -> Result<()> {
    let client = client_holder()?;
    client.update_fcm_token(&fcm_token, expire_time).await.map_err(|e| anyhow::anyhow!("{}", e))
}

/// 设置 App 角标未读数（对齐 Go SDK `SetAppBadge`）
#[flutter_rust_bridge::frb]
pub async fn set_app_badge(app_unread_count: i32) -> Result<()> {
    let client = client_holder()?;
    client.set_app_badge(app_unread_count).await.map_err(|e| anyhow::anyhow!("{}", e))
}
