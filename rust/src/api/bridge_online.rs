//! 在线状态 FFI 桥接层
//!
//! 通过 flutter_rust_bridge 暴露在线状态功能给 Flutter

use crate::api::bridge_client::get_current_client;
use anyhow::Result;
use serde::{Deserialize, Serialize};

/// 在线状态（Bridge 版本）
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OnlineStatusBridge {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "platformIDs")]
    pub platform_ids: Vec<i32>,
    pub status: i32,
}

/// 订阅用户在线状态
#[flutter_rust_bridge::frb]
pub async fn subscribe_users_status(user_ids: Vec<String>) -> Result<Vec<OnlineStatusBridge>> {
    let client = get_current_client().await?;
    let statuses = client.read().await.subscribe_users_status(user_ids).await?;
    Ok(statuses.into_iter().map(|s| OnlineStatusBridge {
        user_id: s.user_id,
        platform_ids: s.platform_ids,
        status: s.status,
    }).collect())
}

/// 取消订阅用户在线状态
#[flutter_rust_bridge::frb]
pub async fn unsubscribe_users_status(user_ids: Vec<String>) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.unsubscribe_users_status(user_ids).await;
    result
}

/// 获取已订阅用户的在线状态
#[flutter_rust_bridge::frb]
pub async fn get_subscribe_users_status() -> Result<Vec<OnlineStatusBridge>> {
    let client = get_current_client().await?;
    let statuses = client.read().await.get_subscribe_users_status().await?;
    Ok(statuses.into_iter().map(|s| OnlineStatusBridge {
        user_id: s.user_id,
        platform_ids: s.platform_ids,
        status: s.status,
    }).collect())
}

/// 获取已订阅用户数量
#[flutter_rust_bridge::frb]
pub async fn get_subscribed_count() -> Result<usize> {
    let client = get_current_client().await?;
    Ok(client.read().await.get_subscribed_count().await)
}

/// 检查用户是否已订阅
#[flutter_rust_bridge::frb]
pub async fn is_subscribed(user_id: String) -> Result<bool> {
    let client = get_current_client().await?;
    client.read().await.is_subscribed(&user_id).await
}

/// 清空所有订阅
#[flutter_rust_bridge::frb]
pub async fn clear_subscriptions() -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.clear_subscriptions().await;
    result
}
