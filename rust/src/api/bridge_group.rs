//! 群组管理 FFI 桥接层
//!
//! 通过 flutter_rust_bridge 暴露群组管理功能给 Flutter

use crate::api::bridge_client::get_current_client;
use crate::im::client::listeners::GroupEvent;
use crate::im::dao::group::LocalGroup;
use crate::im::dao::group_member::LocalGroupMember;
use anyhow::Result;
use crate::frb_generated::StreamSink;
use serde::{Deserialize, Serialize};
use tokio_stream::StreamExt;

/// 群组信息（Bridge 版本）
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupInfo {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "groupName")]
    pub group_name: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    #[serde(rename = "memberCount")]
    pub member_count: i32,
    pub status: i32,
    #[serde(rename = "creatorUserID")]
    pub creator_user_id: String,
    #[serde(rename = "groupType")]
    pub group_type: i32,
    #[serde(rename = "needVerification")]
    pub need_verification: i32,
    pub notification: String,
    pub introduction: String,
    pub ex: String,
}

impl From<LocalGroup> for GroupInfo {
    fn from(g: LocalGroup) -> Self {
        Self {
            group_id: g.group_id,
            group_name: g.group_name,
            face_url: g.face_url,
            owner_user_id: g.owner_user_id,
            create_time: g.create_time,
            member_count: g.member_count,
            status: g.status,
            creator_user_id: g.creator_user_id,
            group_type: g.group_type,
            need_verification: g.need_verification,
            notification: g.notification,
            introduction: g.introduction,
            ex: g.ex,
        }
    }
}

/// 群成员信息（Bridge 版本）
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupMemberInfo {
    #[serde(rename = "groupID")]
    pub group_id: String,
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "roleLevel")]
    pub role_level: i32,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    #[serde(rename = "joinTime")]
    pub join_time: i64,
    #[serde(rename = "muteEndTime")]
    pub mute_end_time: i64,
    pub ex: String,
}

impl From<LocalGroupMember> for GroupMemberInfo {
    fn from(m: LocalGroupMember) -> Self {
        Self {
            group_id: m.group_id,
            user_id: m.user_id,
            role_level: m.role_level,
            nickname: m.nickname,
            face_url: m.face_url,
            join_time: m.join_time,
            mute_end_time: m.mute_end_time,
            ex: m.ex,
        }
    }
}

/// 创建群组请求
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateGroupReq {
    #[serde(rename = "groupName")]
    pub group_name: String,
    #[serde(rename = "faceURL")]
    pub face_url: Option<String>,
    pub introduction: Option<String>,
    pub notification: Option<String>,
    #[serde(rename = "memberUserIDs")]
    pub member_user_ids: Vec<String>,
    #[serde(rename = "adminUserIDs")]
    pub admin_user_ids: Option<Vec<String>>,
    #[serde(rename = "needVerification")]
    pub need_verification: Option<i32>,
}

/// 群组事件流。需在 connect() 之前调用。
#[flutter_rust_bridge::frb]
pub async fn group_event_stream(sink: StreamSink<GroupEvent>) -> Result<()> {
    let client = get_current_client().await?;
    let stream = client.write().await.subscribe_group_events();
    tokio::spawn(async move {
        let mut stream = stream;
        while let Some(ev) = stream.next().await {
            let _ = sink.add(ev);
        }
    });
    Ok(())
}

/// 创建群组
#[flutter_rust_bridge::frb]
pub async fn create_group(req: CreateGroupReq) -> Result<GroupInfo> {
    let client = get_current_client().await?;
    let group = client.read().await.create_group(
        req.group_name,
        req.face_url,
        req.introduction,
        req.notification,
        req.member_user_ids,
        req.admin_user_ids,
        req.need_verification,
    ).await?;
    Ok(GroupInfo::from(group))
}

/// 加入群组
#[flutter_rust_bridge::frb]
pub async fn join_group(group_id: String, req_msg: String, join_source: i32, ex: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.join_group(group_id, req_msg, join_source, ex).await;
    result
}

/// 退出群组
#[flutter_rust_bridge::frb]
pub async fn quit_group(group_id: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.quit_group(group_id).await;
    result
}

/// 解散群组
#[flutter_rust_bridge::frb]
pub async fn dismiss_group(group_id: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.dismiss_group(group_id).await;
    result
}

/// 转让群组
#[flutter_rust_bridge::frb]
pub async fn transfer_group_owner(group_id: String, new_owner_id: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.transfer_group_owner(group_id, new_owner_id).await;
    result
}

/// 获取群组信息
#[flutter_rust_bridge::frb]
pub async fn get_groups_info(group_ids: Vec<String>) -> Result<Vec<GroupInfo>> {
    let client = get_current_client().await?;
    let groups = client.read().await.get_groups_info(group_ids).await?;
    Ok(groups.into_iter().map(GroupInfo::from).collect())
}

/// 搜索群组
#[flutter_rust_bridge::frb]
pub async fn search_groups(keyword: String, is_search_group_id: bool, is_search_group_name: bool) -> Result<Vec<GroupInfo>> {
    let client = get_current_client().await?;
    let groups = client.read().await.search_groups(keyword, is_search_group_id, is_search_group_name).await?;
    Ok(groups.into_iter().map(GroupInfo::from).collect())
}

/// 获取已加入的群组列表
#[flutter_rust_bridge::frb]
pub async fn get_joined_group_list() -> Result<Vec<GroupInfo>> {
    let client = get_current_client().await?;
    let groups = client.read().await.get_joined_group_list().await?;
    Ok(groups.into_iter().map(GroupInfo::from).collect())
}

/// 分页获取已加入的群组列表
#[flutter_rust_bridge::frb]
pub async fn get_joined_group_list_split(offset: i32, count: i32) -> Result<Vec<GroupInfo>> {
    let client = get_current_client().await?;
    let groups = client.read().await.get_joined_group_list_split(offset, count).await?;
    Ok(groups.into_iter().map(GroupInfo::from).collect())
}

/// 邀请用户加入群组
#[flutter_rust_bridge::frb]
pub async fn invite_users_to_group(group_id: String, user_ids: Vec<String>, reason: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.invite_users_to_group(group_id, user_ids, reason).await;
    result
}

/// 踢出群组成员
#[flutter_rust_bridge::frb]
pub async fn kick_group_member(group_id: String, user_ids: Vec<String>, reason: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.kick_group_member(group_id, user_ids, reason).await;
    result
}

/// 获取群组成员列表（分页）
#[flutter_rust_bridge::frb]
pub async fn get_group_member_list_page(group_id: String, filter: i32, offset: i32, count: i32) -> Result<Vec<GroupMemberInfo>> {
    let client = get_current_client().await?;
    let members = client.read().await.get_group_member_list_page(group_id, filter, offset, count).await?;
    Ok(members.into_iter().map(GroupMemberInfo::from).collect())
}

/// 获取指定群组成员信息
#[flutter_rust_bridge::frb]
pub async fn get_group_members_info(group_id: String, user_ids: Vec<String>) -> Result<Vec<GroupMemberInfo>> {
    let client = get_current_client().await?;
    let members = client.read().await.get_group_members_info(group_id, user_ids).await?;
    Ok(members.into_iter().map(GroupMemberInfo::from).collect())
}

/// 设置群成员角色
#[flutter_rust_bridge::frb]
pub async fn set_group_member_role(group_id: String, user_id: String, role_level: i32) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.set_group_member_role(group_id, user_id, role_level).await;
    result
}

/// 禁言群成员
#[flutter_rust_bridge::frb]
pub async fn set_group_member_mute(group_id: String, user_id: String, mute_seconds: u32) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.set_group_member_mute(group_id, user_id, mute_seconds).await;
    result
}

/// 禁言群组
#[flutter_rust_bridge::frb]
pub async fn set_group_mute(group_id: String, mute: bool) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.set_group_mute(group_id, mute).await;
    result
}

/// 更新群组信息
#[flutter_rust_bridge::frb]
pub async fn set_group_info(
    group_id: String,
    group_name: Option<String>,
    face_url: Option<String>,
    introduction: Option<String>,
    notification: Option<String>,
    ex: Option<String>,
    need_verification: Option<i32>,
) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.set_group_info(
        group_id,
        group_name,
        notification,
        introduction,
        face_url,
        ex,
        need_verification,
    ).await;
    result
}

/// 获取群组申请列表（作为接收者）
#[flutter_rust_bridge::frb]
pub async fn get_group_application_list_as_recipient() -> Result<Vec<serde_json::Value>> {
    let client = get_current_client().await?;
    let list = client.read().await.get_group_application_list_as_recipient().await?;
    Ok(list.into_iter().map(|a| serde_json::to_value(a).unwrap_or_default()).collect())
}

/// 获取群组申请列表（作为申请者）
#[flutter_rust_bridge::frb]
pub async fn get_group_application_list_as_applicant() -> Result<Vec<serde_json::Value>> {
    let client = get_current_client().await?;
    let list = client.read().await.get_group_application_list_as_applicant().await?;
    Ok(list.into_iter().map(|a| serde_json::to_value(a).unwrap_or_default()).collect())
}

/// 接受群组申请
#[flutter_rust_bridge::frb]
pub async fn accept_group_application(group_id: String, user_id: String, handle_msg: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.accept_group_application(group_id, user_id, handle_msg).await;
    result
}

/// 拒绝群组申请
#[flutter_rust_bridge::frb]
pub async fn refuse_group_application(group_id: String, user_id: String, handle_msg: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.refuse_group_application(group_id, user_id, handle_msg).await;
    result
}
