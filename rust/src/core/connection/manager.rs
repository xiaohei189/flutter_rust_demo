use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::protocol::ws::{OpenIMReq, OpenIMResp};
use futures_util::stream::SplitSink;
use futures_util::{SinkExt, StreamExt};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::sync::{mpsc, oneshot, RwLock};
use tokio::time::timeout;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tokio_tungstenite::{connect_async, MaybeTlsStream, WebSocketStream};
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info, warn};

type WsWriter = SplitSink<WebSocketStream<MaybeTlsStream<TcpStream>>, WsMessage>;

/// 连接状态
#[derive(Clone, Debug, PartialEq)]
pub enum ConnectionState {
    Disconnected,
    Connecting,
    Connected,
    Reconnecting,
}

/// 连接管理器
pub struct ConnectionManager {
    /// WebSocket 写入端
    writer: Arc<RwLock<Option<WsWriter>>>,
    /// 连接状态
    state: Arc<RwLock<ConnectionState>>,
    /// 待处理的 RPC 请求
    pending_requests: Arc<RwLock<HashMap<String, oneshot::Sender<OpenIMResp>>>>,
    /// 事件总线
    event_bus: Arc<EventBus>,
    
    /// 取消令牌
    cancel_token: CancellationToken,
    /// 接收消息的通道
    msg_rx: Arc<RwLock<Option<mpsc::UnboundedReceiver<WsMessage>>>>,
}

impl ConnectionManager {
    pub fn new(event_bus: Arc<EventBus>, cancel_token: CancellationToken) -> Self {
        Self {
            writer: Arc::new(RwLock::new(None)),
            state: Arc::new(RwLock::new(ConnectionState::Disconnected)),
            pending_requests: Arc::new(RwLock::new(HashMap::new())),
            event_bus,
            cancel_token,
            msg_rx: Arc::new(RwLock::new(None)),
        }
    }

    /// 连接到 WebSocket 服务器
    pub async fn connect(&self, ws_url: &str) -> Result<()> {
        self.set_state(ConnectionState::Connecting).await;
        self.event_bus.publish(SdkEvent::Connecting);

        let (ws_stream, _) = connect_async(ws_url)
            .await
            .map_err(|e| SdkError::connection(format!("WebSocket 连接失败: {}", e)))?;

        let (write, read) = ws_stream.split();
        
        *self.writer.write().await = Some(write);
        self.set_state(ConnectionState::Connected).await;
        self.event_bus.publish(SdkEvent::Connected);

        info!("WebSocket 连接成功: {}", ws_url);

        Ok(())
    }

    /// 发送 WebSocket 消息
    pub async fn send(&self, message: WsMessage) -> Result<()> {
        let mut writer_guard = self.writer.write().await;
        if let Some(writer) = writer_guard.as_mut() {
            writer
                .send(message)
                .await
                .map_err(|e| SdkError::connection(format!("发送消息失败: {}", e)))?;
            Ok(())
        } else {
            Err(SdkError::connection("WebSocket 未连接"))
        }
    }

    /// 发送 RPC 请求并等待响应
    pub async fn send_rpc<T: serde::Serialize, R: for<'de> serde::Deserialize<'de>>(
        &self,
        req_identifier: i32,
        token: &str,
        send_id: &str,
        operation_id: &str,
        data: &T,
        timeout_duration: Duration,
    ) -> Result<R> {
        let data_bytes = serde_json::to_vec(data)
            .map_err(|e| SdkError::unknown(format!("序列化请求数据失败: {}", e)))?;

        let req = OpenIMReq {
            req_identifier,
            token: token.to_string(),
            send_id: send_id.to_string(),
            operation_id: operation_id.to_string(),
            msg_incr: format!("{}_{}", operation_id, req_identifier),
            data: data_bytes,
        };

        let (tx, rx) = oneshot::channel();
        self.pending_requests
            .write()
            .await
            .insert(req.msg_incr.clone(), tx);

        let message = WsMessage::Text(serde_json::to_string(&req).map_err(|e| {
            SdkError::unknown(format!("序列化请求失败: {}", e))
        })?);

        self.send(message).await?;

        match timeout(timeout_duration, rx).await {
            Ok(Ok(resp)) => {
                if resp.is_success() {
                    let result: R = serde_json::from_slice(&resp.data).map_err(|e| {
                        SdkError::unknown(format!("解析响应数据失败: {}", e))
                    })?;
                    Ok(result)
                } else {
                    Err(SdkError::api(resp.err_code, &resp.err_msg))
                }
            }
            Ok(Err(_)) => Err(SdkError::connection("响应通道已关闭")),
            Err(_) => Err(SdkError::timeout(format!(
                "RPC 请求超时 ({}s)",
                timeout_duration.as_secs()
            ))),
        }
    }

    /// 处理接收到的响应
    pub async fn handle_response(&self, resp: OpenIMResp) {
        if let Some(tx) = self.pending_requests.write().await.remove(&resp.msg_incr) {
            let _ = tx.send(resp);
        }
    }

    /// 获取当前连接状态
    pub async fn get_state(&self) -> ConnectionState {
        self.state.read().await.clone()
    }

    /// 设置连接状态
    async fn set_state(&self, state: ConnectionState) {
        *self.state.write().await = state;
    }

    /// 断开连接
    pub async fn disconnect(&self) {
        *self.writer.write().await = None;
        self.set_state(ConnectionState::Disconnected).await;
        self.event_bus.publish(SdkEvent::Disconnected {
            reason: "主动断开连接".to_string(),
        });
        info!("WebSocket 连接已断开");
    }

    /// 检查是否已连接
    pub async fn is_connected(&self) -> bool {
        matches!(
            self.get_state().await,
            ConnectionState::Connected
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_connection_manager_creation() {
        let event_bus = Arc::new(EventBus::new());
        let cancel_token = CancellationToken::new();
        let manager = ConnectionManager::new(event_bus, cancel_token);

        assert_eq!(
            manager.get_state().await,
            ConnectionState::Disconnected
        );
    }

    #[tokio::test]
    async fn test_connection_state_transitions() {
        let event_bus = Arc::new(EventBus::new());
        let cancel_token = CancellationToken::new();
        let manager = ConnectionManager::new(event_bus, cancel_token);

        manager.set_state(ConnectionState::Connecting).await;
        assert_eq!(
            manager.get_state().await,
            ConnectionState::Connecting
        );

        manager.set_state(ConnectionState::Connected).await;
        assert_eq!(manager.get_state().await, ConnectionState::Connected);

        manager.disconnect().await;
        assert_eq!(
            manager.get_state().await,
            ConnectionState::Disconnected
        );
    }

    #[tokio::test]
    async fn test_is_connected() {
        let event_bus = Arc::new(EventBus::new());
        let cancel_token = CancellationToken::new();
        let manager = ConnectionManager::new(event_bus, cancel_token);

        assert!(!manager.is_connected().await);

        manager.set_state(ConnectionState::Connected).await;
        assert!(manager.is_connected().await);
    }
}
