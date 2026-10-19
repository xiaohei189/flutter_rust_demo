//! OpenIM FFI 桥接层 - 全局 API
//!
//! 从 api/client.rs 拆出，职责：不属于特定客户端的全局函数
//! 包括：App 前后台切换、网络状态通知、SDK 版本查询等

use crate::sdk::client::SdkApi;
use anyhow::Result;
use std::sync::Arc;
use std::sync::RwLock;

/// 当前 SDK 客户端。
///
/// 必须是「可替换」的：热重启 / 切换账号会创建新的 OpenIMClient，
/// 旧的 OnceLock 只保留第一次创建的实例，导致 sendMessage 等全局 FFI
/// 继续走旧客户端——旧实例的事件没有订阅者，表现为「消息发出去了但不上屏」。
static CLIENT_HOLDER: RwLock<Option<Arc<dyn SdkApi>>> = RwLock::new(None);

pub(crate) fn client_holder() -> Result<Arc<dyn SdkApi>> {
    CLIENT_HOLDER.read().ok().and_then(|guard| guard.clone()).ok_or_else(|| anyhow::anyhow!("SDK 客户端未初始化，请先调用 new"))
}

pub(crate) fn set_client(client: Arc<dyn SdkApi>) {
    if let Ok(mut guard) = CLIENT_HOLDER.write() {
        *guard = Some(client);
    }
}

/// 设置 App 前后台状态（对齐 Go SDK SetAppBackgroundStatus）
#[flutter_rust_bridge::frb]
pub async fn set_app_background_status(is_background: bool) -> Result<()> {
    let client = client_holder()?;
    client.set_app_background_status(is_background).await.map_err(|e| anyhow::anyhow!("{}", e))
}

/// 网络状态变化通知（对齐 Go SDK NetworkStatusChanged）
#[flutter_rust_bridge::frb]
pub async fn network_status_changed() -> Result<()> {
    let client = client_holder()?;
    client.network_status_changed().await.map_err(|e| anyhow::anyhow!("{}", e))
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
