//! ConnectionApi — SDK 对外 API 契约（分域特征）
//!
//! 由 OpenIMClient 实现，pi/ 层依赖组合特征 SdkApi。

use crate::error::{Result, SdkError};
use crate::event::events::connection::ConnectionEvent;
use async_trait::async_trait;

#[async_trait]
pub trait ConnectionApi: Send + Sync {
    fn take_conn_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<ConnectionEvent>, SdkError>;
    async fn connect(&self, ws_url: &str, token: &str, user_id: &str) -> Result<()>;
    async fn disconnect(&self);
    async fn login(&self, user_id: &str, token: &str) -> Result<()>;
    async fn logout(&self) -> Result<()>;
    fn login_user_id(&self) -> String;
    async fn get_connection_state(&self) -> crate::connection::manager::ConnectionState;
    async fn is_connected(&self) -> bool;
    async fn set_app_background_status(&self, is_background: bool) -> Result<()>;
    async fn network_status_changed(&self) -> Result<()>;
}
