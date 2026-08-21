//! 连接管理器（核心）
//!
//! 职责：连接状态管理、生命周期控制。子模块 handler 分布在:
//! - connector.rs: do_connect() WebSocket 连接与认证
//! - reader.rs: spawn_read_loop() 消息读取循环
//! - rpc.rs: send_rpc() RPC 请求发送
//! - heartbeat.rs: HeartbeatManager 心跳状态管理
//! - reconnect.rs: ReconnectStrategy 重连策略

use crate::core::connection::message_batcher::MessageBatcher;
use crate::core::connection::ws::GzipCompressor;
use crate::core::connection::ws::OpenIMResp;
use crate::domain::error::Result;
use crate::core::event::events::connection::{ConnectionEvent, ConnectionListener, ConnectionListenerExt};
use crate::core::event::events::user::UserEvent;
use futures_util::stream::SplitSink;
use futures_util::SinkExt;
use openim_protocol::sdkws::PushMessages;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::sync::{oneshot, RwLock};
use tokio::time::{interval, sleep, MissedTickBehavior};
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tokio_tungstenite::{MaybeTlsStream, WebSocketStream};
use tokio_util::sync::CancellationToken;
use tracing::{error, info, warn};

pub type WsWriter = SplitSink<WebSocketStream<MaybeTlsStream<TcpStream>>, WsMessage>;

pub const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(30);
pub const RECONNECT_BASE_DELAY: Duration = Duration::from_secs(1);
pub const RECONNECT_MAX_DELAY: Duration = Duration::from_secs(60);
pub const MAX_RECONNECT_ATTEMPTS: u32 = 300;

pub use crate::domain::constant::ConnectionState;

pub(crate) struct PendingRequest {
    pub(crate) tx: oneshot::Sender<OpenIMResp>,
}

pub struct ConnectionManager {
    pub(crate) writer: Arc<RwLock<Option<WsWriter>>>,
    pub(crate) state: Arc<RwLock<ConnectionState>>,
    pub(crate) pending_requests: Arc<RwLock<HashMap<String, PendingRequest>>>,
    pub(crate) cancel_token: CancellationToken,
    /// 当前连接级取消令牌：disconnect/kick 只取消它，SDK 销毁才取消 cancel_token
    pub(crate) connection_token: RwLock<Option<CancellationToken>>,
    pub(crate) msg_incr: AtomicU64,
    pub(crate) token: RwLock<String>,
    pub(crate) send_id: RwLock<String>,
    pub(crate) ws_url: RwLock<String>,
    pub(crate) platform_id: RwLock<i32>,
    pub(crate) reconnect_attempts: Arc<AtomicU32>,
    pub(crate) is_manual_disconnect: Arc<RwLock<bool>>,
    pub(crate) compressor: GzipCompressor,
    pub(crate) message_batcher: MessageBatcher,
    pub(crate) push_tx: Arc<std::sync::Mutex<Option<tokio::sync::mpsc::UnboundedSender<(PushMessages, String)>>>>,
    pub(crate) user_push_tx: Arc<std::sync::Mutex<Option<tokio::sync::mpsc::UnboundedSender<UserEvent>>>>,
    pub(crate) listener: Arc<dyn ConnectionListener>,
    pub(crate) on_connected_hook: Arc<std::sync::Mutex<Option<Box<dyn Fn() + Send + Sync>>>>,
}

impl ConnectionManager {
    pub(crate) fn send(&self, e: ConnectionEvent) {
        self.listener.emit(e);
    }

    pub fn new(cancel_token: CancellationToken, listener: Arc<dyn ConnectionListener>) -> Self {
        let push_tx: Arc<std::sync::Mutex<Option<tokio::sync::mpsc::UnboundedSender<(PushMessages, String)>>>> = Arc::new(std::sync::Mutex::new(None));
        let push_tx_clone = push_tx.clone();
        let compressor = GzipCompressor::new();
        let message_batcher = MessageBatcher::new(move |operation_ids, batch| {
            if !batch.msgs.is_empty() || !batch.notification_msgs.is_empty() {
                if let Some(tx) = push_tx_clone.lock().expect("push_tx mutex poisoned").as_ref() {
                    let operation_id = operation_ids.into_iter().next().unwrap_or_default();
                    let _ = tx.send((batch, operation_id));
                }
            }
        });

        Self {
            writer: Arc::new(RwLock::new(None)),
            state: Arc::new(RwLock::new(ConnectionState::Disconnected)),
            pending_requests: Arc::new(RwLock::new(HashMap::new())),
            cancel_token,
            connection_token: RwLock::new(None),
            msg_incr: AtomicU64::new(0),
            token: RwLock::new(String::new()),
            send_id: RwLock::new(String::new()),
            ws_url: RwLock::new(String::new()),
            platform_id: RwLock::new(1),
            reconnect_attempts: Arc::new(AtomicU32::new(0)),
            is_manual_disconnect: Arc::new(RwLock::new(false)),
            compressor,
            message_batcher,
            push_tx,
            user_push_tx: Arc::new(std::sync::Mutex::new(None)),
            listener,
            on_connected_hook: Arc::new(std::sync::Mutex::new(None)),
        }
    }

    pub fn set_push_sender(&self, tx: tokio::sync::mpsc::UnboundedSender<(PushMessages, String)>) {
        *self.push_tx.lock().expect("push_tx mutex poisoned") = Some(tx);
    }

    pub fn set_user_push_sender(&self, tx: tokio::sync::mpsc::UnboundedSender<UserEvent>) {
        *self.user_push_tx.lock().expect("user_push_tx mutex poisoned") = Some(tx);
    }

    #[tracing::instrument(level = "info", skip(self), fields(user_id = %user_id, platform_id = platform_id))]
    pub async fn connect(&self, ws_url: &str, token: &str, user_id: &str, platform_id: i32) -> Result<()> {
        // 无论当前状态如何，先终止上一次连接的所有循环（read/heartbeat/reconnect）
        if let Some(prev) = self.connection_token.write().await.take() {
            prev.cancel();
        }
        {
            let current_state = *self.state.read().await;
            if current_state != ConnectionState::Disconnected {
                info!("[Connection] connect: closing existing connection (state: {:?})", current_state);
                *self.is_manual_disconnect.write().await = true;
                *self.writer.write().await = None;
                *self.state.write().await = ConnectionState::Disconnected;
                self.message_batcher.close().await;
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
        }

        *self.token.write().await = token.to_string();
        *self.send_id.write().await = user_id.to_string();
        *self.ws_url.write().await = ws_url.to_string();
        *self.platform_id.write().await = platform_id;
        *self.is_manual_disconnect.write().await = false;
        self.reconnect_attempts.store(0, Ordering::SeqCst);

        // 每次连接使用独立的取消令牌：断线/重连/踢下线互不影响，SDK 实例可反复连接
        let conn_token = CancellationToken::new();
        *self.connection_token.write().await = Some(conn_token.clone());

        self.do_connect(conn_token.clone()).await?;
        self.spawn_reconnect_loop(conn_token);
        Ok(())
    }

    fn spawn_reconnect_loop(&self, conn_token: CancellationToken) {
        let cancel = conn_token.clone();
        let state = self.state.clone();
        let is_manual = self.is_manual_disconnect.clone();
        let self_clone = Arc::new(self.clone_shallow());

        tokio::spawn(async move {
            loop {
                tokio::select! {
                    _ = cancel.cancelled() => {
                        info!("reconnect_loop: cancelled");
                        break;
                    }
                    _ = async {
                        loop {
                            let current_state = *state.read().await;
                            let manual = { *is_manual.read().await };
                            if manual { info!("reconnect_loop: manual disconnect, stopping"); return; }
                            if current_state == ConnectionState::Disconnected || current_state == ConnectionState::Reconnecting { break; }
                            tokio::time::sleep(Duration::from_secs(1)).await;
                        }
                    } => {
                        let manual = { *is_manual.read().await };
                        if manual { break; }

                        let attempts = self_clone.reconnect_attempts.fetch_add(1, Ordering::SeqCst);
                        if attempts >= MAX_RECONNECT_ATTEMPTS {
                            error!("max reconnect attempts reached ({})", MAX_RECONNECT_ATTEMPTS);
                            break;
                        }

                        let delay = self_clone.calculate_reconnect_delay(attempts);
                        info!("reconnecting in {:?} (attempt {}/{})", delay, attempts + 1, MAX_RECONNECT_ATTEMPTS);
                        self_clone.send(ConnectionEvent::Reconnecting { attempt: attempts + 1, max_attempts: MAX_RECONNECT_ATTEMPTS });

                        tokio::select! {
                            _ = cancel.cancelled() => break,
                            _ = sleep(delay) => {}
                        }

                        let manual = { *is_manual.read().await };
                        if manual { break; }

                        *state.write().await = ConnectionState::Reconnecting;
                        match self_clone.do_connect(conn_token.clone()).await {
                            Ok(_) => {
                                info!("reconnected successfully");
                                self_clone.reconnect_attempts.store(0, Ordering::SeqCst);
                            }
                            Err(e) => {
                                warn!("reconnect failed: {:?}", e);
                                let manual = { *is_manual.read().await };
                                if manual { break; }
                                *state.write().await = ConnectionState::Disconnected;
                            }
                        }
                    }
                }
            }
        });
    }

    fn calculate_reconnect_delay(&self, attempt: u32) -> Duration {
        let delay_secs = if attempt < 5 {
            1 << attempt
        } else if attempt < 10 {
            16 + (attempt - 5) * 4
        } else {
            60
        };
        Duration::from_secs(delay_secs as u64).min(RECONNECT_MAX_DELAY)
    }

    fn clone_shallow(&self) -> ConnectionManager {
        ConnectionManager {
            writer: self.writer.clone(),
            state: self.state.clone(),
            pending_requests: self.pending_requests.clone(),
            cancel_token: self.cancel_token.clone(),
            connection_token: RwLock::new(self.connection_token.try_read().map(|t| t.clone()).unwrap_or(None)),
            msg_incr: AtomicU64::new(self.msg_incr.load(Ordering::SeqCst)),
            token: RwLock::new(self.token.try_read().map(|t| t.clone()).unwrap_or_default()),
            send_id: RwLock::new(self.send_id.try_read().map(|s| s.clone()).unwrap_or_default()),
            ws_url: RwLock::new(self.ws_url.try_read().map(|u| u.clone()).unwrap_or_default()),
            platform_id: RwLock::new(self.platform_id.try_read().ok().map(|g| *g).unwrap_or(0)),
            reconnect_attempts: self.reconnect_attempts.clone(),
            is_manual_disconnect: self.is_manual_disconnect.clone(),
            compressor: GzipCompressor::new(),
            message_batcher: self.message_batcher.clone(),
            push_tx: self.push_tx.clone(),
            user_push_tx: self.user_push_tx.clone(),
            listener: self.listener.clone(),
            on_connected_hook: self.on_connected_hook.clone(),
        }
    }

    /// 内部心跳循环（由 do_connect 在连接成功后调用）
    pub(crate) fn spawn_heartbeat_internal(&self, conn_token: CancellationToken) {
        let writer = self.writer.clone();
        let state = self.state.clone();
        let cancel = conn_token;

        tokio::spawn(async move {
            let mut ticker = interval(HEARTBEAT_INTERVAL);
            ticker.set_missed_tick_behavior(MissedTickBehavior::Delay);
            loop {
                tokio::select! {
                    _ = cancel.cancelled() => break,
                    _ = ticker.tick() => {
                        let is_connected = *state.read().await == ConnectionState::Connected;
                        if !is_connected { continue; }
                        let ping_result = {
                            let mut w = writer.write().await;
                            if let Some(writer) = w.as_mut() {
                                writer.send(WsMessage::Ping(vec![])).await
                            } else { continue; }
                        };
                        if let Err(e) = ping_result {
                            warn!("heartbeat ping failed: {}", e);
                            *state.write().await = ConnectionState::Disconnected;
                            break;
                        }
                    }
                }
            }
        });
    }

    pub async fn disconnect(&self) {
        *self.is_manual_disconnect.write().await = true;
        if let Some(conn_token) = self.connection_token.write().await.take() {
            conn_token.cancel();
        }
        *self.writer.write().await = None;
        *self.state.write().await = ConnectionState::Disconnected;
        self.message_batcher.close().await;
        self.send(ConnectionEvent::Disconnected("manual disconnect".into()));
        info!("WebSocket disconnected (manual)");
    }

    pub async fn handle_kicked(&self, reason: String) {
        *self.is_manual_disconnect.write().await = true;
        if let Some(conn_token) = self.connection_token.write().await.take() {
            conn_token.cancel();
        }
        *self.writer.write().await = None;
        *self.state.write().await = ConnectionState::Kicked;
        self.message_batcher.close().await;
        warn!("kicked offline: {}", reason);
    }

    pub fn message_batcher(&self) -> &MessageBatcher {
        &self.message_batcher
    }
    pub async fn get_state(&self) -> ConnectionState {
        *self.state.read().await
    }
    pub(crate) async fn set_state(&self, state: ConnectionState) {
        *self.state.write().await = state;
    }
    pub async fn is_connected(&self) -> bool {
        matches!(*self.state.read().await, ConnectionState::Connected)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_connection_manager_creation() {
        let cancel_token = CancellationToken::new();
        let manager = ConnectionManager::new(cancel_token, crate::core::event::test_util::noop_connection_listener());
        assert_eq!(manager.get_state().await, ConnectionState::Disconnected);
    }

    #[tokio::test]
    async fn test_connection_state_transitions() {
        let cancel_token = CancellationToken::new();
        let manager = ConnectionManager::new(cancel_token, crate::core::event::test_util::noop_connection_listener());
        manager.set_state(ConnectionState::Connecting).await;
        assert_eq!(manager.get_state().await, ConnectionState::Connecting);
        manager.set_state(ConnectionState::Connected).await;
        assert_eq!(manager.get_state().await, ConnectionState::Connected);
        manager.disconnect().await;
        assert_eq!(manager.get_state().await, ConnectionState::Disconnected);
    }

    #[tokio::test]
    async fn test_is_connected() {
        let cancel_token = CancellationToken::new();
        let manager = ConnectionManager::new(cancel_token, crate::core::event::test_util::noop_connection_listener());
        assert!(!manager.is_connected().await);
        manager.set_state(ConnectionState::Connected).await;
        assert!(manager.is_connected().await);
    }
}

#[tokio::test]
async fn test_clone_shallow_copies_all_fields() {
    let cancel_token = CancellationToken::new();
    let original = ConnectionManager::new(cancel_token.clone(), crate::core::event::test_util::noop_connection_listener());
    let cloned = original.clone_shallow();
    assert!(!cloned.cancel_token.is_cancelled());
    assert_eq!(original.state.try_read().map(|s| *s).unwrap_or(ConnectionState::Disconnected), ConnectionState::Disconnected);
    assert_eq!(cloned.state.try_read().map(|s| *s).unwrap_or(ConnectionState::Disconnected), ConnectionState::Disconnected);
    assert_eq!(original.reconnect_attempts.load(Ordering::SeqCst), 0);
    assert_eq!(cloned.reconnect_attempts.load(Ordering::SeqCst), 0);
    assert!(original.writer.try_read().unwrap().is_none());
    assert!(cloned.writer.try_read().unwrap().is_none());
    assert!(Arc::ptr_eq(&original.push_tx, &cloned.push_tx));
    assert!(Arc::ptr_eq(&original.on_connected_hook, &cloned.on_connected_hook));
    assert!(original.connection_token.try_read().unwrap().is_none());
    assert!(cloned.connection_token.try_read().unwrap().is_none());
}

#[tokio::test]
async fn test_clone_shallow_preserves_message_batcher_handler() {
    let cancel_token = CancellationToken::new();
    let mut original = ConnectionManager::new(cancel_token, crate::core::event::test_util::noop_connection_listener());
    let (tx, mut rx) = tokio::sync::mpsc::channel::<usize>(1);
    original.message_batcher = MessageBatcher::new(move |_operation_ids, batch| {
        let count = batch.msgs.values().map(|pulls| pulls.msgs.len()).sum::<usize>();
        let tx = tx.clone();
        tokio::spawn(async move {
            let _ = tx.send(count).await;
        });
    });

    let cloned = original.clone_shallow();

    let mut msgs = std::collections::HashMap::new();
    msgs.insert(
        "conv_1".to_string(),
        openim_protocol::sdkws::PullMsgs {
            msgs: vec![openim_protocol::sdkws::MsgData::default()],
            ..Default::default()
        },
    );
    cloned
        .message_batcher
        .enqueue(
            "op_1".to_string(),
            openim_protocol::sdkws::PushMessages {
                msgs,
                notification_msgs: std::collections::HashMap::new(),
            },
        )
        .await;

    let received = tokio::time::timeout(std::time::Duration::from_secs(1), rx.recv())
        .await
        .expect("message batcher handler should run after clone_shallow")
        .expect("handler channel should not close");
    assert_eq!(received, 1);
}
