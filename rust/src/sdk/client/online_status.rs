use crate::domain::error::types::Result;
use crate::core::online::manager::OnlineStatus;
use crate::sdk::client::OpenIMClient;

impl OpenIMClient {
    /// 获取用户在线状态
    pub async fn get_user_status(&self, user_ids: Vec<String>) -> Result<Vec<OnlineStatus>> {
        self.online_status.get_user_status(user_ids).await
    }
}
