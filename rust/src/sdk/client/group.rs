use crate::domain::constant::GroupType;
use crate::domain::error::Result;
use crate::domain::error::SdkError;
use crate::domain::model::group::{GroupInfo, GroupMember};
use crate::core::group::manager::GroupApplyInfo;
use crate::sdk::client::OpenIMClient;

impl OpenIMClient {
    #[tracing::instrument(skip_all)]
    pub async fn get_group_list(&self) -> Vec<GroupInfo> {
        self.group.get_joined_group_list().await
    }

    #[tracing::instrument(skip_all, fields(group_name = %group_name))]
    pub async fn create_group(
        &self,
        group_name: &str,
        group_type: GroupType,
        member_ids: &[String],
    ) -> Result<GroupInfo> {
        let user_id = self.context.user_id.get_blocking();
        self.group.create_group(
            group_name.to_string(),
            None,
            None,
            None,
            member_ids.to_vec(),
            vec![],
            user_id,
        ).await
    }

    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn join_group(&self, group_id: &str, req_msg: Option<&str>) -> Result<()> {
        self.group.join_group(group_id.to_string(), req_msg.map(|s| s.to_string())).await
    }

    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn quit_group(&self, group_id: &str) -> Result<()> {
        self.group.quit_group(group_id.to_string()).await
    }

    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn get_group_members(&self, group_id: &str) -> Result<Vec<GroupMember>> {
        self.group.get_group_member_list(group_id.to_string(), 0, 0, 1000).await
    }

    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn invite_group_members(&self, group_id: &str, member_ids: &[String], reason: Option<&str>) -> Result<()> {
        self.group.invite_user_to_group(
            group_id.to_string(),
            member_ids.to_vec(),
            reason.map(|s| s.to_string()),
        ).await
    }

    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn kick_group_members(&self, group_id: &str, member_ids: &[String], reason: Option<&str>) -> Result<()> {
        self.group.kick_group_member(
            group_id.to_string(),
            member_ids.to_vec(),
            reason.map(|s| s.to_string()),
        ).await
    }

    #[tracing::instrument(skip_all)]
    pub async fn get_groups_info(&self, group_ids: &[String]) -> std::result::Result<Vec<GroupInfo>, SdkError> {
        self.group.get_groups_info(group_ids.to_vec()).await
    }

    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn set_group_info(
        &self,
        group_id: &str,
        group_name: Option<&str>,
        face_url: Option<&str>,
    ) -> Result<()> {
        self.group.set_group_info(crate::domain::model::group::SetGroupInfoFields {
            group_id: group_id.to_string(),
            group_name: group_name.map(|s| s.to_string()),
            face_url: face_url.map(|s| s.to_string()),
            introduction: None,
            notification: None,
            ex: None,
        }).await
    }

    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn get_group_members_info(&self, group_id: &str, user_ids: &[String]) -> Result<Vec<GroupMember>> {
        self.group.get_group_members_info(group_id.to_string(), user_ids.to_vec()).await
    }

    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn dismiss_group(&self, group_id: &str) -> Result<()> {
        self.group.dismiss_group(group_id.to_string()).await
    }

    #[tracing::instrument(skip_all)]
    pub async fn get_group_application_list(&self) -> std::result::Result<Vec<GroupApplyInfo>, SdkError> {
        let resp = self.group.get_group_application_list().await?;
        Ok(resp.group_requests.unwrap_or_default())
    }

    /// 获取管理员收到的群组申请列表
    #[tracing::instrument(skip_all)]
    pub async fn get_group_application_list_as_recipient(&self) -> std::result::Result<Vec<GroupApplyInfo>, SdkError> {
        let resp = self.group.get_group_application_list_as_recipient().await?;
        Ok(resp.group_requests.unwrap_or_default())
    }

    /// 获取自己发出的群组申请列表
    #[tracing::instrument(skip_all)]
    pub async fn get_group_application_list_as_applicant(&self) -> std::result::Result<Vec<GroupApplyInfo>, SdkError> {
        let resp = self.group.get_group_application_list_as_applicant().await?;
        Ok(resp.group_requests.unwrap_or_default())
    }

    /// 获取未处理的群组申请数量
    #[tracing::instrument(skip_all)]
    pub async fn get_group_application_unhandled_count(&self) -> Result<i32> {
        self.group.get_group_application_unhandled_count().await
    }

    #[tracing::instrument(skip_all, fields(group_id = %group_id, user_id = %user_id))]
    pub async fn accept_group_application(&self, group_id: &str, user_id: &str, handle_msg: Option<&str>) -> Result<()> {
        self.group.accept_group_application(group_id.to_string(), user_id.to_string(), handle_msg.map(|s| s.to_string())).await
    }

    #[tracing::instrument(skip_all, fields(group_id = %group_id, user_id = %user_id))]
    pub async fn refuse_group_application(&self, group_id: &str, user_id: &str, handle_msg: Option<&str>) -> Result<()> {
        self.group.refuse_group_application(group_id.to_string(), user_id.to_string(), handle_msg.map(|s| s.to_string())).await
    }

    /// 检查当前用户是否在群组中
    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn is_in_group(&self, group_id: &str) -> bool {
        self.group.is_in_group(group_id).await
    }

    /// 转让群主
    #[tracing::instrument(skip_all, fields(group_id = %group_id, new_owner = %new_owner_user_id))]
    pub async fn transfer_group_owner(&self, group_id: &str, new_owner_user_id: &str) -> Result<()> {
        self.group.transfer_group_owner(group_id.to_string(), new_owner_user_id.to_string()).await
    }

    /// 全局禁言/解除禁言群组
    #[tracing::instrument(skip_all, fields(group_id = %group_id, is_mute = %is_mute))]
    pub async fn mute_group(&self, group_id: &str, is_mute: bool) -> Result<()> {
        self.group.mute_group(group_id.to_string(), is_mute).await
    }

    /// 禁言/解除禁言群成员
    #[tracing::instrument(skip_all, fields(group_id = %group_id, user_id = %user_id))]
    pub async fn mute_group_member(&self, group_id: &str, user_id: &str, muted_seconds: i64) -> Result<()> {
        self.group.mute_group_member(group_id.to_string(), user_id.to_string(), muted_seconds).await
    }

    /// 增量同步群组列表（对齐 Go SDK IncrSyncJoinGroup）
    #[tracing::instrument(skip_all)]
    pub async fn sync_groups_incremental(&self) -> Result<()> {
        self.group.sync_groups_incremental().await
    }

    /// 设置群成员信息（对齐 Go SDK `SetGroupMemberInfo`）
    #[tracing::instrument(skip_all, fields(group_id = %group_id, user_id = %user_id))]
    pub async fn set_group_member_info(
        &self,
        group_id: &str,
        user_id: &str,
        nickname: Option<&str>,
        face_url: Option<&str>,
        role_level: Option<i32>,
        ex: Option<&str>,
    ) -> Result<()> {
        self.group.set_group_member_info(crate::core::group::manager::SetGroupMemberFields {
            group_id: group_id.to_string(),
            user_id: user_id.to_string(),
            nickname: nickname.map(|s| s.to_string()),
            face_url: face_url.map(|s| s.to_string()),
            role_level,
            ex: ex.map(|s| s.to_string()),
        }).await
    }

    /// 分页获取已加入群组列表（对齐 Go SDK `GetJoinedGroupListPage`）
    #[tracing::instrument(skip_all, fields(offset = %offset, count = %count))]
    pub async fn get_joined_group_list_page(&self, offset: i32, count: i32) -> Result<Vec<GroupInfo>> {
        self.group.get_joined_group_list_page(offset, count).await
    }

    /// 搜索群组（对齐 Go SDK `SearchGroups`）
    #[tracing::instrument(skip_all, fields(keyword = %keyword))]
    pub async fn search_groups(&self, keyword: &str) -> Vec<GroupInfo> {
        self.group.search_groups(keyword).await
    }

    /// 获取群主和管理员列表（对齐 Go SDK `GetGroupMemberOwnerAndAdmin`）
    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn get_group_member_owner_and_admin(&self, group_id: &str) -> Result<Vec<GroupMember>> {
        self.group.get_group_member_owner_and_admin(group_id.to_string()).await
    }

    /// 按加入时间筛选群成员（对齐 Go SDK `GetGroupMemberListByJoinTimeFilter`）
    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn get_group_member_list_by_join_time_filter(
        &self,
        group_id: &str,
        offset: i32,
        count: i32,
        join_time_begin: i64,
        join_time_end: i64,
        filter_user_ids: Vec<String>,
    ) -> Result<Vec<GroupMember>> {
        self.group.get_group_member_list_by_join_time_filter(
            group_id.to_string(),
            offset,
            count,
            join_time_begin,
            join_time_end,
            filter_user_ids,
        ).await
    }

    /// 搜索群成员（对齐 Go SDK `SearchGroupMembers`）
    #[tracing::instrument(skip_all, fields(group_id = %group_id, keyword = %keyword))]
    pub async fn search_group_members(&self, group_id: &str, keyword: &str) -> Vec<GroupMember> {
        self.group.search_group_members(group_id, keyword).await
    }

    /// 获取指定用户在群组中的存在情况（对齐 Go SDK `GetUsersInGroup`）
    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn get_users_in_group(&self, group_id: &str, user_ids: Vec<String>) -> Vec<String> {
        self.group.get_users_in_group(group_id, user_ids).await
    }

    /// 检查本地群组是否已全量同步（对齐 Go SDK `CheckLocalGroupFullSync`）
    #[tracing::instrument(skip_all)]
    pub async fn check_local_group_full_sync(&self) -> bool {
        self.group.check_local_group_full_sync().await
    }

    /// 检查群成员是否已全量同步（对齐 Go SDK `CheckGroupMemberFullSync`）
    #[tracing::instrument(skip_all, fields(group_id = %group_id))]
    pub async fn check_group_member_full_sync(&self, group_id: &str) -> bool {
        self.group.check_group_member_full_sync(group_id).await
    }
}