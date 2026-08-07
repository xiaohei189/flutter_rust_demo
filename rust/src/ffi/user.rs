//! 用户相关 FFI 桥接

use crate::client::SdkApi;
use crate::ffi::client::OpenIMBridgeClient;
use crate::ffi::global::client_holder;
use crate::model::user::UserInfo;
use anyhow::{anyhow, Result};

impl OpenIMBridgeClient {
    // ========== 用户操作 ==========

    #[flutter_rust_bridge::frb]
    pub async fn get_users_info(&self, user_ids: Vec<String>) -> Result<Vec<crate::model::user::UserInfo>> {
        self.inner.get_users_info(&user_ids).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_self_user_info(&self) -> Result<crate::model::user::UserInfo> {
        self.inner.get_self_user_info().await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn update_user_profile(&self, nickname: Option<String>, face_url: Option<String>, ex: Option<String>) -> Result<()> {
        self.inner
            .update_user_profile(nickname.as_deref(), face_url.as_deref(), ex.as_deref())
            .await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_user_status(&self, user_ids: Vec<String>) -> Result<Vec<crate::http::online::OnlineStatus>> {
        self.inner.get_user_status(&user_ids).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn subscribe_users_status(&self, user_ids: Vec<String>) -> Result<Vec<crate::http::online::OnlineStatus>> {
        self.inner.subscribe_users_status(user_ids).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn unsubscribe_users_status(&self, user_ids: Vec<String>) -> Result<()> {
        self.inner.unsubscribe_users_status(user_ids).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_subscribe_users_status(&self) -> Result<Vec<crate::http::online::OnlineStatus>> {
        self.inner.get_subscribe_users_status().await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_global_msg_recv_opt(&self, global_recv_opt: i32) -> Result<()> {
        self.inner.set_global_msg_recv_opt(global_recv_opt).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_connection_state(&self) -> Result<crate::connection::manager::ConnectionState> {
        Ok(self.inner.get_connection_state().await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn is_connected(&self) -> Result<bool> {
        Ok(self.inner.is_connected().await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn sync_friends(&self) -> Result<()> {
        self.inner.sync_friends().await.map_err(|e| anyhow::anyhow!("{}", e))
    }
}
