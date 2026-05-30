//! 用户管理 FFI 桥接层
//!
//! 通过 flutter_rust_bridge 暴露用户管理功能给 Flutter

use crate::api::bridge_client::get_current_client;
use crate::api::bridge_client::UserProfile;
use anyhow::Result;
use serde::{Deserialize, Serialize};

/// 搜索用户
#[flutter_rust_bridge::frb]
pub async fn search_users(keyword: String, is_search_user_id: bool, is_search_nickname: bool) -> Result<Vec<UserProfile>> {
    let client = get_current_client().await?;
    let users = client.read().await.search_users(keyword, is_search_user_id, is_search_nickname).await?;
    Ok(users.into_iter().map(UserProfile::from).collect())
}

/// 获取单个用户资料
#[flutter_rust_bridge::frb]
pub async fn get_user_info(user_id: String) -> Result<Option<UserProfile>> {
    let client = get_current_client().await?;
    let user = client.read().await.get_user_info(user_id).await?;
    Ok(user.map(UserProfile::from))
}

/// 获取当前登录用户资料
#[flutter_rust_bridge::frb]
pub async fn get_login_user_info() -> Result<Option<UserProfile>> {
    let client = get_current_client().await?;
    let user = client.read().await.get_login_user_info().await?;
    Ok(user.map(UserProfile::from))
}

/// 更新用户资料
#[flutter_rust_bridge::frb]
pub async fn update_user_info(
    nickname: Option<String>,
    face_url: Option<String>,
    ex: Option<String>,
    global_recv_msg_opt: Option<i32>,
) -> Result<UserProfile> {
    let client = get_current_client().await?;
    let user = client.read().await.update_user_info(nickname, face_url, ex, global_recv_msg_opt).await?;
    Ok(UserProfile::from(user))
}
