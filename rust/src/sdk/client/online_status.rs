use crate::core::user::online::manager::OnlineStatus;
use crate::domain::error::Result;
use crate::sdk::client::OpenIMClient;

impl OpenIMClient {
    pub async fn get_user_status(&self, user_ids: &[String]) -> Result<Vec<OnlineStatus>> {
        self.online_status.get_user_status(user_ids.to_vec()).await
    }
}