use crate::event::events::user::UserEvent;
use crate::domain::ports::online::OnlineStatus;
use crate::domain::sdk_api::UserApi;
use async_trait::async_trait;
use crate::domain::error::{Result, SdkError};
use crate::domain::model::user::UserInfo;
use crate::sdk::client::OpenIMClient;


#[async_trait]
impl UserApi for OpenIMClient {
    #[tracing::instrument(skip_all)]
    async fn get_users_info(&self, user_ids: &[String]) -> Result<Vec<UserInfo>> {
        self.user.get_users_info(user_ids.to_vec()).await
    }

    /// 获取当前登录用户的信息
    #[tracing::instrument(skip_all)]
    async fn get_self_user_info(&self) -> Result<UserInfo> {
        self.user.get_self_user_info().await
    }

    #[tracing::instrument(skip_all)]
    async fn update_user_profile(
        &self,
        nickname: Option<&str>,
        face_url: Option<&str>,
        ex: Option<&str>,
    ) -> Result<()> {
        let updates = crate::domain::ports::user::UpdateUserFields {
            nickname: nickname.map(|s| s.to_string()),
            face_url: face_url.map(|s| s.to_string()),
            gender: None,
            email: ex.map(|s| s.to_string()),
        };
        self.user.update_self_user_info(updates).await
    }

    /// 设置全局消息接收选项
    #[tracing::instrument(skip_all, fields(global_recv_opt = %global_recv_opt))]
    async fn set_global_msg_recv_opt(&self, global_recv_opt: i32) -> Result<()> {
        self.user.set_global_msg_recv_opt(global_recv_opt).await
    }


    async fn get_user_status(&self, user_ids: &[String]) -> Result<Vec<OnlineStatus>> {
        self.online_status.get_user_status(user_ids.to_vec()).await
    }

    async fn subscribe_users_status(&self, user_ids: Vec<String>) -> Result<Vec<OnlineStatus>> {
        self.online_status.subscribe_users_status(user_ids).await
    }

    async fn unsubscribe_users_status(&self, user_ids: Vec<String>) -> Result<()> {
        self.online_status.unsubscribe_users_status(user_ids).await
    }

    /// 获取用户事件接收器（只能调用一次，重复调用返回错误）
    fn take_user_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<UserEvent>, SdkError> {
        self.listeners.take_user_rx().ok_or_else(|| SdkError::unknown("user receiver already taken"))
    }
}