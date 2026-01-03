//! 好友相关模型，迁移自 `im/friend/models.rs` 与 `im/friend/types.rs`

use openim_protocol::sdkws;
use serde::{Deserialize, Deserializer, Serialize};

/// 黑名单数据结构（与好友结构类似）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BlackList {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "blockUserID")]
    pub block_user_id: String,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    #[serde(rename = "addSource")]
    pub add_source: i32,
    #[serde(rename = "operatorUserID")]
    pub operator_user_id: String,
    #[serde(rename = "nickname")]
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    #[serde(rename = "ex")]
    pub ex: String,
    #[serde(rename = "attachedInfo")]
    pub attached_info: String,
}

/// 好友同步器配置
pub struct FriendSyncerConfig {
    /// 用户 ID
    pub user_id: String,
    /// API 基础 URL
    pub api_base_url: String,
    /// Token
    pub token: String,
    /// 数据库路径（SQLite），与会话共用同一个文件即可
    pub db_path: String,
}

/// 反序列化数组字段，处理 null 值
pub(crate) fn deserialize_vec_or_null<'de, D, T>(deserializer: D) -> Result<Vec<T>, D::Error>
where
    D: Deserializer<'de>,
    T: Deserialize<'de>,
{
    let opt = Option::<Vec<T>>::deserialize(deserializer)?;
    Ok(opt.unwrap_or_default())
}

/// 增量好友响应（业务逻辑层结构体，可直接从 API 响应反序列化）
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct IncrementalFriendsResp {
    pub full: bool,
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub delete: Vec<String>,
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub insert: Vec<sdkws::FriendInfo>,
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub update: Vec<sdkws::FriendInfo>,
}

/// 全量好友响应（业务逻辑层结构体，可直接从 API 响应反序列化）
/// 现在直接使用 proto 生成的结构体，已配置好 serde 支持
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AllFriendsResp {
    #[serde(rename = "friendsInfo")]
    pub friends_info: Vec<sdkws::FriendInfo>,
    pub total: i32,
}

/// 好友申请信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FriendRequest {
    #[serde(rename = "fromUserID")]
    pub from_user_id: String,
    #[serde(rename = "fromNickname")]
    pub from_nickname: String,
    #[serde(rename = "fromFaceURL")]
    pub from_face_url: String,
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
    #[serde(rename = "toNickname")]
    pub to_nickname: String,
    #[serde(rename = "toFaceURL")]
    pub to_face_url: String,
    #[serde(rename = "handleResult")]
    pub handle_result: i32,
    #[serde(rename = "reqMsg")]
    pub req_msg: String,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    #[serde(rename = "handlerUserID")]
    pub handler_user_id: String,
    #[serde(rename = "handleMsg")]
    pub handle_msg: String,
    #[serde(rename = "handleTime")]
    pub handle_time: i64,
    pub ex: String,
}

/// 好友申请列表响应
#[derive(Debug, Clone, Deserialize)]
pub struct FriendRequestsResp {
    #[serde(rename = "FriendRequests")]
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub friend_requests: Vec<FriendRequest>,
    #[serde(default)]
    pub total: Option<i32>,
}

// 实体定义已迁移到 dao 层，保留文件用于兼容说明

