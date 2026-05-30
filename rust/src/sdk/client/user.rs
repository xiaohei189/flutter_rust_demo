use crate::domain::error::types::Result;
use crate::domain::model::user::UserInfo;
use crate::sdk::client::OpenIMClient;

impl OpenIMClient {
    pub async fn get_users_info(&self, user_ids: &[String]) -> Result<Vec<UserInfo>> {
        self.user.get_users_info(user_ids.to_vec()).await
    }

    pub async fn update_user_profile(
        &self,
        nickname: Option<&str>,
        face_url: Option<&str>,
        ex: Option<&str>,
    ) -> Result<()> {
        let updates = crate::core::user::manager::UpdateUserFields {
            nickname: nickname.map(|s| s.to_string()),
            face_url: face_url.map(|s| s.to_string()),
            gender: None,
            email: ex.map(|s| s.to_string()),
        };
        self.user.update_self_user_info(updates).await
    }
}