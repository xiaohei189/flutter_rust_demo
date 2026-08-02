use crate::domain::error::Result;
use crate::domain::model::user::UserInfo;
use crate::sdk::client::OpenIMClient;

impl OpenIMClient {
    #[tracing::instrument(skip_all)]
    pub async fn get_users_info(&self, user_ids: &[String]) -> Result<Vec<UserInfo>> {
        self.user.get_users_info(user_ids.to_vec()).await
    }

    /// 获取当前登录用户的信息
    #[tracing::instrument(skip_all)]
    pub async fn get_self_user_info(&self) -> Result<UserInfo> {
        self.user.get_self_user_info().await
    }

    #[tracing::instrument(skip_all)]
    pub async fn update_user_profile(
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
    pub async fn set_global_msg_recv_opt(&self, global_recv_opt: i32) -> Result<()> {
        self.user.set_global_msg_recv_opt(global_recv_opt).await
    }
}