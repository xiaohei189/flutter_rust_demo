//! OpenIM FFI bridge layer - client lifecycle

pub use crate::api::ffi::global::{get_login_user_id, get_sdk_version, network_status_changed, set_app_background_status, un_init_sdk};

use crate::sdk::client::config::ClientConfig;
use crate::sdk::client::core::OpenIMClient;
use crate::sdk::client::{ConnectionApi, MessageApi, SdkApi, UserApi};
use crate::core::event::events::message::MessageEvent;
use crate::core::event::events::user::UserEvent;
use crate::api::ffi::global::set_client;
use crate::frb_generated::StreamSink;
use anyhow::Result;
use std::sync::Arc;

#[flutter_rust_bridge::frb(opaque)]
pub struct OpenIMBridgeClient {
    pub(crate) inner: Arc<dyn SdkApi>,
}

impl OpenIMBridgeClient {
    #[flutter_rust_bridge::frb]
    pub async fn new(config: ClientConfig) -> Result<Self> {
        tracing::info!(
            "[Bridge] creating client instance, user_id={}, ws_url={:?}, api_url={:?}",
            config.user_id,
            config.ws_url,
            config.api_base_url
        );

        let client = OpenIMClient::new(config.clone()).await.map_err(|e| {
            tracing::error!("[Bridge] client creation failed: {}", e);
            anyhow::anyhow!("{}", e)
        })?;

        tracing::info!("[Bridge] client created, logging in...");

        client.login(&config.user_id, &config.token).await.map_err(|e| {
            tracing::error!("[Bridge] login failed: {}", e);
            anyhow::anyhow!("{}", e)
        })?;

        tracing::info!("[Bridge] login successful");

        let inner: Arc<dyn SdkApi> = Arc::new(client);
        set_client(inner.clone());

        Ok(Self { inner })
    }

    #[flutter_rust_bridge::frb]
    pub async fn disconnect(&self) -> Result<()> {
        tracing::info!("[Bridge] disconnecting");
        self.inner.disconnect().await;
        tracing::info!("[Bridge] disconnected");
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn logout(&self) -> Result<()> {
        tracing::info!("[Bridge] logging out");
        self.inner.logout().await.map_err(|e| {
            tracing::error!("[Bridge] logout failed: {}", e);
            anyhow::anyhow!("{}", e)
        })
    }

    #[flutter_rust_bridge::frb]
    pub async fn connection_stream(&self, sink: StreamSink<crate::core::event::events::connection::ConnectionEvent>) -> Result<()> {
        let mut rx = self.inner.take_conn_rx()?;
        tokio::spawn(async move {
            while let Some(e) = rx.recv().await {
                let _ = sink.add(e);
            }
            tracing::warn!("[Bridge] connection_stream closed");
        });
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn conversation_stream(&self, sink: StreamSink<crate::core::event::events::conversation::ConversationEvent>) -> Result<()> {
        let mut rx = self.inner.take_conv_rx()?;
        tokio::spawn(async move {
            while let Some(e) = rx.recv().await {
                let _ = sink.add(e);
            }
        });
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn friend_stream(&self, sink: StreamSink<crate::core::event::events::friend::FriendEvent>) -> Result<()> {
        let mut rx = self.inner.take_friend_rx()?;
        tokio::spawn(async move {
            while let Some(e) = rx.recv().await {
                let _ = sink.add(e);
            }
        });
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn group_stream(&self, sink: StreamSink<crate::core::event::events::group::GroupEvent>) -> Result<()> {
        let mut rx = self.inner.take_group_rx()?;
        tokio::spawn(async move {
            while let Some(e) = rx.recv().await {
                let _ = sink.add(e);
            }
        });
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn message_stream(&self, sink: StreamSink<MessageEvent>) -> Result<()> {
        let mut rx = MessageApi::take_message_rx(&*self.inner)?;
        tokio::spawn(async move {
            while let Some(e) = rx.recv().await {
                let _ = sink.add(e);
            }
        });
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn user_stream(&self, sink: StreamSink<UserEvent>) -> Result<()> {
        let mut rx = UserApi::take_user_rx(&*self.inner)?;
        tokio::spawn(async move {
            while let Some(e) = rx.recv().await {
                let _ = sink.add(e);
            }
        });
        Ok(())
    }
}
