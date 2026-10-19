//! OpenIM FFI bridge layer - client lifecycle

pub use crate::api::ffi::global::{get_login_user_id, get_sdk_version, network_status_changed, set_app_background_status, un_init_sdk};

use crate::api::ffi::global::set_client;
use crate::core::event::events::message::MessageEvent;
use crate::core::event::events::user::UserEvent;
use crate::frb_generated::{SseEncode, StreamSink};
use crate::sdk::client::config::ClientConfig;
use crate::sdk::client::core::OpenIMClient;
use crate::sdk::client::{ConnectionApi, MessageApi, SdkApi, UserApi};
use anyhow::Result;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::sync::Mutex;

type SinkSlot<T> = Arc<Mutex<Option<StreamSink<T>>>>;

fn install_sink<T>(name: &'static str, slot: &SinkSlot<T>, sink: StreamSink<T>) {
    if let Ok(mut guard) = slot.lock() {
        *guard = Some(sink);
    }
    tracing::info!("[Bridge] {} 订阅已接入", name);
}

/// 把事件泵到「当前订阅者」的 sink。
///
/// frb 的 StreamSink 只在订阅期间有效：Dart 侧取消订阅 / 热重载后，
/// 旧 sink 的 `add` 会失败。这里把 sink 放进可替换槽位，泵只取一次
/// 底层 mpsc 接收端，之后换订阅只是替换 sink，不会再触发
/// `receiver already taken`。
fn spawn_event_pump<T: Send + 'static + SseEncode>(name: &'static str, slot: SinkSlot<T>, mut rx: tokio::sync::mpsc::UnboundedReceiver<T>) {
    tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            let sink = slot.lock().ok().and_then(|mut guard| guard.take());
            let Some(sink) = sink else {
                // 当前没有订阅者（例如热重载窗口内），丢弃该事件。
                tracing::warn!("[Bridge] {} 事件无订阅者，已丢弃", name);
                continue;
            };
            match sink.add(event) {
                Ok(()) => {
                    if let Ok(mut guard) = slot.lock() {
                        // 期间可能有新订阅写入，优先保留新 sink。
                        if guard.is_none() {
                            *guard = Some(sink);
                        }
                    }
                }
                // add 失败说明订阅端已关闭，丢弃旧 sink，等待下一次订阅。
                Err(e) => tracing::warn!("[Bridge] {} 事件推送失败: {:?}", name, e),
            }
        }
    });
}

#[flutter_rust_bridge::frb(opaque)]
pub struct OpenIMBridgeClient {
    pub(crate) inner: Arc<dyn SdkApi>,
    conn_sink: SinkSlot<crate::core::event::events::connection::ConnectionEvent>,
    conv_sink: SinkSlot<crate::core::event::events::conversation::ConversationEvent>,
    friend_sink: SinkSlot<crate::core::event::events::friend::FriendEvent>,
    group_sink: SinkSlot<crate::core::event::events::group::GroupEvent>,
    message_sink: SinkSlot<MessageEvent>,
    user_sink: SinkSlot<UserEvent>,
    conn_pump_started: AtomicBool,
    conv_pump_started: AtomicBool,
    friend_pump_started: AtomicBool,
    group_pump_started: AtomicBool,
    message_pump_started: AtomicBool,
    user_pump_started: AtomicBool,
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

        Ok(Self {
            inner,
            conn_sink: Arc::new(Mutex::new(None)),
            conv_sink: Arc::new(Mutex::new(None)),
            friend_sink: Arc::new(Mutex::new(None)),
            group_sink: Arc::new(Mutex::new(None)),
            message_sink: Arc::new(Mutex::new(None)),
            user_sink: Arc::new(Mutex::new(None)),
            conn_pump_started: AtomicBool::new(false),
            conv_pump_started: AtomicBool::new(false),
            friend_pump_started: AtomicBool::new(false),
            group_pump_started: AtomicBool::new(false),
            message_pump_started: AtomicBool::new(false),
            user_pump_started: AtomicBool::new(false),
        })
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
        install_sink("connection", &self.conn_sink, sink);
        if !self.conn_pump_started.swap(true, Ordering::SeqCst) {
            spawn_event_pump("connection", self.conn_sink.clone(), self.inner.take_conn_rx()?);
        }
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn conversation_stream(&self, sink: StreamSink<crate::core::event::events::conversation::ConversationEvent>) -> Result<()> {
        install_sink("conversation", &self.conv_sink, sink);
        if !self.conv_pump_started.swap(true, Ordering::SeqCst) {
            spawn_event_pump("conversation", self.conv_sink.clone(), self.inner.take_conv_rx()?);
        }
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn friend_stream(&self, sink: StreamSink<crate::core::event::events::friend::FriendEvent>) -> Result<()> {
        install_sink("friend", &self.friend_sink, sink);
        if !self.friend_pump_started.swap(true, Ordering::SeqCst) {
            spawn_event_pump("friend", self.friend_sink.clone(), self.inner.take_friend_rx()?);
        }
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn group_stream(&self, sink: StreamSink<crate::core::event::events::group::GroupEvent>) -> Result<()> {
        install_sink("group", &self.group_sink, sink);
        if !self.group_pump_started.swap(true, Ordering::SeqCst) {
            spawn_event_pump("group", self.group_sink.clone(), self.inner.take_group_rx()?);
        }
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn message_stream(&self, sink: StreamSink<MessageEvent>) -> Result<()> {
        install_sink("message", &self.message_sink, sink);
        if !self.message_pump_started.swap(true, Ordering::SeqCst) {
            spawn_event_pump("message", self.message_sink.clone(), MessageApi::take_message_rx(&*self.inner)?);
        }
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn user_stream(&self, sink: StreamSink<UserEvent>) -> Result<()> {
        install_sink("user", &self.user_sink, sink);
        if !self.user_pump_started.swap(true, Ordering::SeqCst) {
            spawn_event_pump("user", self.user_sink.clone(), UserApi::take_user_rx(&*self.inner)?);
        }
        Ok(())
    }
}
