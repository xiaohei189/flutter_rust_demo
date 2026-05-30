use crate::domain::error::types::Result;
use crate::domain::error::types::SdkError;
use crate::domain::model::group::{GroupInfo, GroupMember, SetGroupInfoFields};
use crate::sdk::client::{GroupApplyInfo, OpenIMClient};

impl OpenIMClient {
    /// 获取群组列表
    pub async fn get_group_list(&self) -> Vec<GroupInfo> {
        self.group.get_joined_group_list().await
    }

    /// 创建群组
    pub async fn create_group(
        &self,
        group_name: String,
        group_type: i32,
        member_ids: Vec<String>,
    ) -> Result<GroupInfo> {
        let user_id = self.context.user_id.lock().unwrap().clone();
        self.group.create_group(
            group_name,
            None,
            None,
            None,
            member_ids,
            vec![],
            user_id,
        ).await
    }

    /// 加入群组
    pub async fn join_group(&self, group_id: String, req_msg: Option<String>) -> Result<()> {
        self.group.join_group(group_id, req_msg).await
    }

    /// 退出群组
    pub async fn quit_group(&self, group_id: String) -> Result<()> {
        self.group.quit_group(group_id).await
    }

    /// 获取群组成员
    pub async fn get_group_members(&self, group_id: String) -> Result<Vec<GroupMember>> {
        self.group.get_group_member_list(group_id, 0, 0, 1000).await
    }

    /// 邀请成员
    pub async fn invite_group_members(&self, group_id: String, member_ids: Vec<String>, reason: Option<String>) -> Result<()> {
        self.group.invite_user_to_group(group_id, member_ids, reason).await
    }

    /// 踢出成员
    pub async fn kick_group_members(&self, group_id: String, member_ids: Vec<String>, reason: Option<String>) -> Result<()> {
        self.group.kick_group_member(group_id, member_ids, reason).await
    }

    /// 获取群组信息
    pub async fn get_groups_info(&self, group_ids: Vec<String>) -> std::result::Result<Vec<GroupInfo>, SdkError> {
        self.group.get_groups_info(group_ids).await
    }

    /// 设置群组信息
    pub async fn set_group_info(&self, group_id: String, group_name: Option<String>, face_url: Option<String>) -> Result<()> {
        self.group.set_group_info(SetGroupInfoFields {
            group_id,
            group_name,
            face_url,
            introduction: None,
            notification: None,
            ex: None,
        }).await
    }

    /// 获取群组成员信息
    pub async fn get_group_members_info(&self, group_id: String, user_ids: Vec<String>) -> Result<Vec<GroupMember>> {
        self.group.get_group_members_info(group_id, user_ids).await
    }

    /// 解散群组
    pub async fn dismiss_group(&self, group_id: String) -> Result<()> {
        self.group.dismiss_group(group_id).await
    }

    /// 获取群申请列表
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

    /// 接受群申请
    pub async fn accept_group_application(&self, group_id: String, user_id: String) -> Result<()> {
        self.group.accept_group_application(group_id, user_id).await
    }

    /// 拒绝群申请
    pub async fn refuse_group_application(&self, group_id: String, user_id: String) -> Result<()> {
        self.group.refuse_group_application(group_id, user_id).await
    }
}
