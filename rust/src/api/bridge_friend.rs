//! 好友管理 FFI 桥接层
//!
//! 通过 flutter_rust_bridge 暴露好友管理功能给 Flutter

use crate::api::bridge_client::get_current_client;
use crate::im::client::listeners::FriendEvent;
use crate::im::dao::black::LocalBlack;
use openim_protocol::sdkws;
use anyhow::Result;
use crate::frb_generated::StreamSink;
use serde::{Deserialize, Serialize};
use tokio_stream::StreamExt;

/// 好友信息（Bridge 版本）
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FriendInfoBridge {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "friendUserID")]
    pub friend_user_id: String,
    pub remark: String,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    #[serde(rename = "addSource")]
    pub add_source: i32,
    #[serde(rename = "operatorUserID")]
    pub operator_user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    pub ex: String,
    #[serde(rename = "isPinned")]
    pub is_pinned: bool,
}

impl From<sdkws::FriendInfo> for FriendInfoBridge {
    fn from(f: sdkws::FriendInfo) -> Self {
        let friend_user = f.friend_user.unwrap_or_default();
        Self {
            owner_user_id: f.owner_user_id,
            friend_user_id: friend_user.user_id,
            remark: f.remark,
            create_time: f.create_time,
            add_source: f.add_source,
            operator_user_id: f.operator_user_id,
            nickname: friend_user.nickname,
            face_url: friend_user.face_url,
            ex: friend_user.ex,
            is_pinned: f.is_pinned,
        }
    }
}

/// 黑名单信息（Bridge 版本）
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BlackInfo {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "blackUserID")]
    pub black_user_id: String,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    pub ex: String,
}

impl From<LocalBlack> for BlackInfo {
    fn from(b: LocalBlack) -> Self {
        Self {
            owner_user_id: b.owner_user_id,
            black_user_id: b.block_user_id,
            create_time: b.create_time,
            ex: b.ex,
        }
    }
}

/// 好友事件流。需在 connect() 之前调用。
#[flutter_rust_bridge::frb]
pub async fn friend_event_stream(sink: StreamSink<FriendEvent>) -> Result<()> {
    let client = get_current_client().await?;
    let stream = client.write().await.subscribe_friend_events();
    tokio::spawn(async move {
        let mut stream = stream;
        while let Some(ev) = stream.next().await {
            let _ = sink.add(ev);
        }
    });
    Ok(())
}

/// 添加好友
#[flutter_rust_bridge::frb]
pub async fn add_friend(user_id: String, req_msg: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.add_friend(&user_id, &req_msg).await;
    result
}

/// 删除好友
#[flutter_rust_bridge::frb]
pub async fn delete_friend(user_id: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.delete_friend(&user_id).await;
    result
}

/// 获取好友列表
#[flutter_rust_bridge::frb]
pub async fn get_friend_list(filter_black: bool) -> Result<Vec<FriendInfoBridge>> {
    let client = get_current_client().await?;
    let friends = client.read().await.get_friend_list(filter_black).await?;
    Ok(friends.into_iter().map(FriendInfoBridge::from).collect())
}

/// 分页获取好友列表
#[flutter_rust_bridge::frb]
pub async fn get_friend_list_page(offset: i32, count: i32, filter_black: bool) -> Result<Vec<FriendInfoBridge>> {
    let client = get_current_client().await?;
    let friends = client.read().await.get_friend_list_page(offset, count, filter_black).await?;
    Ok(friends.into_iter().map(FriendInfoBridge::from).collect())
}

/// 获取指定好友信息
#[flutter_rust_bridge::frb]
pub async fn get_specified_friends_info(user_ids: Vec<String>) -> Result<Vec<FriendInfoBridge>> {
    let client = get_current_client().await?;
    let friends = client.read().await.get_users_info_with_cache(user_ids).await?;
    Ok(friends.into_iter().map(|u| FriendInfoBridge {
        owner_user_id: String::new(),
        friend_user_id: u.user_id,
        remark: String::new(),
        create_time: u.create_time,
        add_source: 0,
        operator_user_id: String::new(),
        nickname: u.nickname,
        face_url: u.face_url,
        ex: u.ex,
        is_pinned: false,
    }).collect())
}

/// 获取好友申请列表（作为接收者）
#[flutter_rust_bridge::frb]
pub async fn get_friend_application_list_as_recipient() -> Result<Vec<serde_json::Value>> {
    let client = get_current_client().await?;
    let list = client.read().await.get_friend_requests().await?;
    Ok(list.into_iter().map(|a| serde_json::to_value(a).unwrap_or_default()).collect())
}

/// 获取好友申请列表（作为申请者）
#[flutter_rust_bridge::frb]
pub async fn get_friend_application_list_as_applicant() -> Result<Vec<serde_json::Value>> {
    let client = get_current_client().await?;
    let list = client.read().await.get_self_friend_application_list().await?;
    Ok(list.into_iter().map(|a| serde_json::to_value(a).unwrap_or_default()).collect())
}

/// 接受好友申请
#[flutter_rust_bridge::frb]
pub async fn accept_friend_application(user_id: String, handle_msg: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.accept_friend_application(user_id, handle_msg).await;
    result
}

/// 拒绝好友申请
#[flutter_rust_bridge::frb]
pub async fn refuse_friend_application(user_id: String, handle_msg: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.refuse_friend_application(user_id, handle_msg).await;
    result
}

/// 获取未处理的好友申请数量
#[flutter_rust_bridge::frb]
pub async fn get_friend_application_unhandled_count() -> Result<i64> {
    let client = get_current_client().await?;
    let result = client.read().await.get_friend_application_unhandled_count().await;
    result
}

/// 添加黑名单
#[flutter_rust_bridge::frb]
pub async fn add_black(user_id: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.add_black(user_id).await;
    result
}

/// 移除黑名单
#[flutter_rust_bridge::frb]
pub async fn remove_black(user_id: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.remove_black(user_id).await;
    result
}

/// 获取黑名单列表
#[flutter_rust_bridge::frb]
pub async fn get_black_list() -> Result<Vec<BlackInfo>> {
    let client = get_current_client().await?;
    let blacks = client.read().await.get_black_list().await?;
    Ok(blacks.into_iter().map(BlackInfo::from).collect())
}

/// 检查是否在黑名单中
#[flutter_rust_bridge::frb]
pub async fn is_in_black_list(user_id: String) -> Result<bool> {
    let client = get_current_client().await?;
    let result = client.read().await.is_in_black_list(&user_id).await;
    result
}
