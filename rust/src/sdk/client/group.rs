use crate::domain::constant::enums::GroupType;
use crate::domain::error::types::Result;
use crate::domain::error::types::SdkError;
use crate::domain::model::group::{GroupInfo, GroupMember};
use crate::sdk::client::{GroupApplyInfo, OpenIMClient};

impl OpenIMClient {
    pub async fn get_group_list(&self) -> Vec<GroupInfo> {
        self.group.get_joined_group_list().await
    }

    pub async fn create_group(
        &self,
        group_name: &str,
        group_type: GroupType,
        member_ids: &[String],
    ) -> Result<GroupInfo> {
        let user_id = self.context.user_id.lock().unwrap().clone();
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

    pub async fn join_group(&self, group_id: &str, req_msg: Option<&str>) -> Result<()> {
        self.group.join_group(group_id.to_string(), req_msg.map(|s| s.to_string())).await
    }

    pub async fn quit_group(&self, group_id: &str) -> Result<()> {
        self.group.quit_group(group_id.to_string()).await
    }

    pub async fn get_group_members(&self, group_id: &str) -> Result<Vec<GroupMember>> {
        self.group.get_group_member_list(group_id.to_string(), 0, 0, 1000).await
    }

    pub async fn invite_group_members(&self, group_id: &str, member_ids: &[String], reason: Option<&str>) -> Result<()> {
        self.group.invite_user_to_group(
            group_id.to_string(),
            member_ids.to_vec(),
            reason.map(|s| s.to_string()),
        ).await
    }

    pub async fn kick_group_members(&self, group_id: &str, member_ids: &[String], reason: Option<&str>) -> Result<()> {
        self.group.kick_group_member(
            group_id.to_string(),
            member_ids.to_vec(),
            reason.map(|s| s.to_string()),
        ).await
    }

    pub async fn get_groups_info(&self, group_ids: &[String]) -> std::result::Result<Vec<GroupInfo>, SdkError> {
        self.group.get_groups_info(group_ids.to_vec()).await
    }

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

    pub async fn get_group_members_info(&self, group_id: &str, user_ids: &[String]) -> Result<Vec<GroupMember>> {
        self.group.get_group_members_info(group_id.to_string(), user_ids.to_vec()).await
    }

    pub async fn dismiss_group(&self, group_id: &str) -> Result<()> {
        self.group.dismiss_group(group_id.to_string()).await
    }

    pub async fn get_group_application_list(&self) -> std::result::Result<Vec<GroupApplyInfo>, SdkError> {
        let resp = self.group.get_group_application_list().await?;
        Ok(resp.group_requests.unwrap_or_default().into_iter().map(|a| GroupApplyInfo {
            group_id: a.group_id,
            user_id: a.user_id,
            nickname: a.nickname,
            face_url: a.face_url,
            reason: a.reason,
            handle_result: a.handle_result,
        }).collect())
    }

    /// 获取管理员收到的群组申请列表
    pub async fn get_group_application_list_as_recipient(&self) -> std::result::Result<Vec<GroupApplyInfo>, SdkError> {
        let resp = self.group.get_group_application_list_as_recipient().await?;
        Ok(resp.group_requests.unwrap_or_default().into_iter().map(|a| GroupApplyInfo {
            group_id: a.group_id,
            user_id: a.user_id,
            nickname: a.nickname,
            face_url: a.face_url,
            reason: a.reason,
            handle_result: a.handle_result,
        }).collect())
    }

    /// 获取自己发出的群组申请列表
    pub async fn get_group_application_list_as_applicant(&self) -> std::result::Result<Vec<GroupApplyInfo>, SdkError> {
        let resp = self.group.get_group_application_list_as_applicant().await?;
        Ok(resp.group_requests.unwrap_or_default().into_iter().map(|a| GroupApplyInfo {
            group_id: a.group_id,
            user_id: a.user_id,
            nickname: a.nickname,
            face_url: a.face_url,
            reason: a.reason,
            handle_result: a.handle_result,
        }).collect())
    }

    /// 获取未处理的群组申请数量
    pub async fn get_group_application_unhandled_count(&self) -> Result<i32> {
        self.group.get_group_application_unhandled_count().await
    }

    pub async fn accept_group_application(&self, group_id: &str, user_id: &str, handle_msg: Option<&str>) -> Result<()> {
        self.group.accept_group_application(group_id.to_string(), user_id.to_string(), handle_msg.map(|s| s.to_string())).await
    }

    pub async fn refuse_group_application(&self, group_id: &str, user_id: &str, handle_msg: Option<&str>) -> Result<()> {
        self.group.refuse_group_application(group_id.to_string(), user_id.to_string(), handle_msg.map(|s| s.to_string())).await
    }

    /// 检查当前用户是否在群组中
    pub async fn is_in_group(&self, group_id: &str) -> bool {
        self.group.is_in_group(group_id).await
    }

    /// 转让群主
    pub async fn transfer_group_owner(&self, group_id: &str, new_owner_user_id: &str) -> Result<()> {
        self.group.transfer_group_owner(group_id.to_string(), new_owner_user_id.to_string()).await
    }

    /// 全局禁言/解除禁言群组
    pub async fn mute_group(&self, group_id: &str, is_mute: bool) -> Result<()> {
        self.group.mute_group(group_id.to_string(), is_mute).await
    }

    /// 禁言/解除禁言群成员
    pub async fn mute_group_member(&self, group_id: &str, user_id: &str, muted_seconds: i64) -> Result<()> {
        self.group.mute_group_member(group_id.to_string(), user_id.to_string(), muted_seconds).await
    }
}