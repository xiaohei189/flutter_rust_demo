//! 群组相关 FFI 桥接

use crate::api::client::client_holder;
use crate::core::group::manager::GroupApplyInfo;
use crate::api::client::OpenIMBridgeClient;
use crate::domain::model::group::GroupInfo;
use anyhow::{Result, anyhow};

impl OpenIMBridgeClient {
    // ========== 群组操作 ==========

    #[flutter_rust_bridge::frb]
    pub async fn get_group_list(&self) -> Result<Vec<crate::domain::model::group::GroupInfo>> {
        Ok(self.inner.get_group_list().await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn create_group(
        &self,
        group_name: String,
        group_type: i32,
        member_ids: Vec<String>,
    ) -> Result<crate::domain::model::group::GroupInfo> {
        self.inner.create_group(&group_name, crate::domain::constant::GroupType::from_i32(group_type), &member_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn join_group(&self, group_id: String, req_msg: String) -> Result<()> {
        self.inner.join_group(&group_id, Some(&req_msg)).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn quit_group(&self, group_id: String) -> Result<()> {
        self.inner.quit_group(&group_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn is_in_group(&self, group_id: String) -> Result<bool> {
        Ok(self.inner.is_in_group(&group_id).await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_members(&self, group_id: String) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        self.inner.get_group_members(&group_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn invite_group_members(&self, group_id: String, member_ids: Vec<String>) -> Result<()> {
        self.inner.invite_group_members(&group_id, &member_ids, None).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn kick_group_members(&self, group_id: String, member_ids: Vec<String>) -> Result<()> {
        self.inner.kick_group_members(&group_id, &member_ids, None).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_groups_info(&self, group_ids: Vec<String>) -> Result<Vec<crate::domain::model::group::GroupInfo>> {
        self.inner.get_groups_info(&group_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_group_info(&self, group_id: String, group_name: Option<String>, face_url: Option<String>) -> Result<()> {
        self.inner.set_group_info(&group_id, group_name.as_deref(), face_url.as_deref()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_members_info(&self, group_id: String, user_ids: Vec<String>) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        self.inner.get_group_members_info(&group_id, &user_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn dismiss_group(&self, group_id: String) -> Result<()> {
        self.inner.dismiss_group(&group_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_application_list(&self) -> Result<Vec<GroupApplyInfo>> {
        self.inner.get_group_application_list().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_application_list_as_recipient(&self) -> Result<Vec<GroupApplyInfo>> {
        self.inner.get_group_application_list_as_recipient().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_application_list_as_applicant(&self) -> Result<Vec<GroupApplyInfo>> {
        self.inner.get_group_application_list_as_applicant().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_application_unhandled_count(&self) -> Result<i32> {
        self.inner.get_group_application_unhandled_count().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn accept_group_application(&self, group_id: String, user_id: String, handle_msg: Option<String>) -> Result<()> {
        self.inner.accept_group_application(&group_id, &user_id, handle_msg.as_deref()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn refuse_group_application(&self, group_id: String, user_id: String, handle_msg: Option<String>) -> Result<()> {
        self.inner.refuse_group_application(&group_id, &user_id, handle_msg.as_deref()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn transfer_group_owner(&self, group_id: String, new_owner_user_id: String) -> Result<()> {
        self.inner.transfer_group_owner(&group_id, &new_owner_user_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn mute_group(&self, group_id: String, is_mute: bool) -> Result<()> {
        self.inner.mute_group(&group_id, is_mute).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn mute_group_member(&self, group_id: String, user_id: String, muted_seconds: i64) -> Result<()> {
        self.inner.mute_group_member(&group_id, &user_id, muted_seconds).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 设置群成员信息（对齐 Go SDK `SetGroupMemberInfo`）
    #[flutter_rust_bridge::frb]
    pub async fn set_group_member_info(
        &self,
        group_id: String,
        user_id: String,
        nickname: Option<String>,
        face_url: Option<String>,
        role_level: Option<i32>,
        ex: Option<String>,
    ) -> Result<()> {
        self.inner.set_group_member_info(
            &group_id,
            &user_id,
            nickname.as_deref(),
            face_url.as_deref(),
            role_level,
            ex.as_deref(),
        ).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 分页获取已加入群组列表（对齐 Go SDK `GetJoinedGroupListPage`）
    #[flutter_rust_bridge::frb]
    pub async fn get_joined_group_list_page(&self, offset: i32, count: i32) -> Result<Vec<crate::domain::model::group::GroupInfo>> {
        self.inner.get_joined_group_list_page(offset, count).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 搜索群组（对齐 Go SDK `SearchGroups`）
    #[flutter_rust_bridge::frb]
    pub async fn search_groups(&self, keyword: String) -> Result<Vec<crate::domain::model::group::GroupInfo>> {
        Ok(self.inner.search_groups(&keyword).await)
    }

    /// 获取群主和管理员列表（对齐 Go SDK `GetGroupMemberOwnerAndAdmin`）
    #[flutter_rust_bridge::frb]
    pub async fn get_group_member_owner_and_admin(&self, group_id: String) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        self.inner.get_group_member_owner_and_admin(&group_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 按加入时间筛选群成员（对齐 Go SDK `GetGroupMemberListByJoinTimeFilter`）
    #[flutter_rust_bridge::frb]
    pub async fn get_group_member_list_by_join_time_filter(
        &self,
        group_id: String,
        offset: i32,
        count: i32,
        join_time_begin: i64,
        join_time_end: i64,
        filter_user_ids: Vec<String>,
    ) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        self.inner.get_group_member_list_by_join_time_filter(
            &group_id,
            offset,
            count,
            join_time_begin,
            join_time_end,
            filter_user_ids,
        ).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 搜索群成员（对齐 Go SDK `SearchGroupMembers`）
    #[flutter_rust_bridge::frb]
    pub async fn search_group_members(&self, group_id: String, keyword: String) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        Ok(self.inner.search_group_members(&group_id, &keyword).await)
    }

    /// 获取指定用户在群组中的存在情况（对齐 Go SDK `GetUsersInGroup`）
    #[flutter_rust_bridge::frb]
    pub async fn get_users_in_group(&self, group_id: String, user_ids: Vec<String>) -> Result<Vec<String>> {
        Ok(self.inner.get_users_in_group(&group_id, user_ids).await)
    }

    /// 检查本地群组是否已全量同步（对齐 Go SDK `CheckLocalGroupFullSync`）
    #[flutter_rust_bridge::frb]
    pub async fn check_local_group_full_sync(&self) -> Result<bool> {
        Ok(self.inner.check_local_group_full_sync().await)
    }

    /// 检查群成员是否已全量同步（对齐 Go SDK `CheckGroupMemberFullSync`）
    #[flutter_rust_bridge::frb]
    pub async fn check_group_member_full_sync(&self, group_id: String) -> Result<bool> {
        Ok(self.inner.check_group_member_full_sync(&group_id).await)
    }

    /// 增量同步群组列表（对齐 Go SDK IncrSyncJoinGroup）
    #[flutter_rust_bridge::frb]
    pub async fn sync_groups_incremental(&self) -> Result<()> {
        self.inner.sync_groups_incremental().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }
}
