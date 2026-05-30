use crate::core::user::manager::UpdateUserFields;
use crate::domain::error::types::Result;
use crate::domain::model::user::UserInfo;
use crate::sdk::client::OpenIMClient;

impl OpenIMClient {
    /// 获取用户信息
    pub async fn get_users_info(&self, user_ids: Vec<String>) -> Result<Vec<UserInfo>> {
        self.user.get_users_info(user_ids).await
    }

    /// 更新用户资料
    pub async fn update_user_profile(
        &self,
        nickname: Option<String>,
        face_url: Option<String>,
        ex: Option<String>,
    ) -> Result<()> {
        let updates = UpdateUserFields {
            nickname,
            face_url,
            gender: None,
            email: ex,
        };
        self.user.update_self_user_info(updates).await
    }
}
