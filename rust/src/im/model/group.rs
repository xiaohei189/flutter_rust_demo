//! 群组 API 请求/响应模型（与 Go GetIncrementalJoinGroupResp / GetIncrementalGroupMemberResp 对齐）
//! 服务端返回的 GroupInfo / GroupMemberFullInfo 使用 camelCase 字段名。

use crate::im::dao::group::LocalGroup;
use crate::im::dao::group_member::LocalGroupMember;
use crate::im::model::common::deserialize_vec_or_null;
use serde::Deserialize;

/// 服务端群组信息（API JSON），与 sdkws.GroupInfo 字段对应。
/// OpenIM API 使用 groupID/faceURL/ownerUserID 等（大写 ID/URL），serde alias 兼容。
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServerGroupInfo {
    #[serde(alias = "groupID")]
    pub group_id: String,
    pub group_name: String,
    pub notification: String,
    pub introduction: String,
    #[serde(alias = "faceURL")]
    pub face_url: String,
    pub create_time: i64,
    pub status: i32,
    #[serde(alias = "creatorUserID")]
    pub creator_user_id: String,
    pub group_type: i32,
    #[serde(alias = "ownerUserID")]
    pub owner_user_id: String,
    pub member_count: i32,
    pub ex: String,
    pub need_verification: i32,
    pub look_member_info: i32,
    pub apply_member_friend: i32,
    pub notification_update_time: i64,
    #[serde(alias = "notificationUserID")]
    pub notification_user_id: String,
    #[serde(default)]
    pub attached_info: String,
}

/// 服务端群成员信息（API JSON），与 sdkws.GroupMemberFullInfo 对应。
/// OpenIM API 使用 groupID/userID/faceURL 等（大写 ID/URL），serde alias 兼容。
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServerGroupMemberFullInfo {
    #[serde(alias = "groupID")]
    pub group_id: String,
    #[serde(alias = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(alias = "faceURL")]
    pub face_url: String,
    pub role_level: i32,
    pub join_time: i64,
    pub join_source: i32,
    #[serde(alias = "inviterUserID")]
    pub inviter_user_id: String,
    pub mute_end_time: i64,
    #[serde(alias = "operatorUserID")]
    pub operator_user_id: String,
    pub ex: String,
    #[serde(default)]
    pub attached_info: String,
}

/// 增量加入群响应（与 Go GetIncrementalJoinGroupResp 对齐）。服务端 full 时可能返回 delete/insert/update 为 null，用 deserialize_vec_or_null 兼容。
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct IncrementalJoinGroupResp {
    pub full: bool,
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub delete: Vec<String>,
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub insert: Vec<ServerGroupInfo>,
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub update: Vec<ServerGroupInfo>,
}

/// 单群增量成员响应（与 Go GetIncrementalGroupMemberResp 对齐）。服务端可能返回 delete/insert/update 为 null。
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct IncrementalGroupMemberResp {
    pub full: bool,
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub delete: Vec<String>,
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub insert: Vec<ServerGroupMemberFullInfo>,
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub update: Vec<ServerGroupMemberFullInfo>,
    /// 可选，部分接口会带回群信息
    pub group: Option<ServerGroupInfo>,
}

/// 服务端群组信息 -> 本地 LocalGroup（与 Go ServerGroupToLocalGroup 一致）
pub fn server_group_to_local(g: &ServerGroupInfo) -> LocalGroup {
    LocalGroup {
        group_id: g.group_id.clone(),
        group_name: g.group_name.clone(),
        notification: g.notification.clone(),
        introduction: g.introduction.clone(),
        face_url: g.face_url.clone(),
        create_time: g.create_time,
        status: g.status,
        creator_user_id: g.creator_user_id.clone(),
        group_type: g.group_type,
        owner_user_id: g.owner_user_id.clone(),
        member_count: g.member_count,
        ex: g.ex.clone(),
        attached_info: g.attached_info.clone(),
        need_verification: g.need_verification,
        look_member_info: g.look_member_info,
        apply_member_friend: g.apply_member_friend,
        notification_update_time: g.notification_update_time,
        notification_user_id: g.notification_user_id.clone(),
    }
}

/// 服务端群成员 -> 本地 LocalGroupMember（与 Go ServerGroupMemberToLocalGroupMember 一致）
pub fn server_group_member_to_local(m: &ServerGroupMemberFullInfo) -> LocalGroupMember {
    LocalGroupMember {
        group_id: m.group_id.clone(),
        user_id: m.user_id.clone(),
        nickname: m.nickname.clone(),
        face_url: m.face_url.clone(),
        role_level: m.role_level,
        join_time: m.join_time,
        join_source: m.join_source,
        inviter_user_id: m.inviter_user_id.clone(),
        mute_end_time: m.mute_end_time,
        operator_user_id: m.operator_user_id.clone(),
        ex: m.ex.clone(),
        attached_info: m.attached_info.clone(),
    }
}
