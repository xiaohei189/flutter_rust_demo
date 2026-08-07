//! OpenIM FFI 桥接层 - 全局 API
//!
//! 从 api/client.rs 拆出，职责：不属于特定客户端的全局函数
//! 包括：App 前后台切换、网络状态通知、SDK 版本查询等

use crate::client::core::OpenIMClient;
use crate::client::SdkApi;
use crate::frb_generated::StreamSink;
use anyhow::Result;
use std::sync::Arc;
use std::sync::OnceLock;

static CLIENT_HOLDER: OnceLock<Arc<dyn SdkApi>> = OnceLock::new();

pub(crate) fn client_holder() -> Result<&'static Arc<dyn SdkApi>> {
    CLIENT_HOLDER.get().ok_or_else(|| anyhow::anyhow!("SDK 客户端未初始化，请先调用 new"))
}

pub(crate) fn set_client(client: Arc<dyn SdkApi>) {
    let _ = CLIENT_HOLDER.set(client);
}

/// 设置 App 前后台状态（对齐 Go SDK SetAppBackgroundStatus）
#[flutter_rust_bridge::frb]
pub async fn set_app_background_status(is_background: bool) -> Result<()> {
    let client = client_holder()?;
    client
        .set_app_background_status(is_background)
        .await
        .map_err(|e| anyhow::anyhow!("{}", e))
}

/// 网络状态变化通知（对齐 Go SDK NetworkStatusChanged）
#[flutter_rust_bridge::frb]
pub async fn network_status_changed() -> Result<()> {
    let client = client_holder()?;
    client
        .network_status_changed()
        .await
        .map_err(|e| anyhow::anyhow!("{}", e))
}

/// 获取当前登录用户 ID（对齐 Go SDK GetLoginUserID）
#[flutter_rust_bridge::frb]
pub async fn get_login_user_id() -> Result<String> {
    let client = client_holder()?;
    Ok(client.login_user_id().to_string())
}

/// 获取 SDK 版本号（对齐 Go SDK GetSdkVersion）
#[flutter_rust_bridge::frb]
pub async fn get_sdk_version() -> Result<String> {
    Ok(env!("CARGO_PKG_VERSION").to_string())
}

/// 反初始化 SDK（对齐 Go SDK UnInitSDK）
#[flutter_rust_bridge::frb]
pub async fn un_init_sdk() -> Result<()> {
    let client = client_holder()?;
    client.logout().await.map_err(|e| anyhow::anyhow!("{}", e))?;
    Ok(())
}
