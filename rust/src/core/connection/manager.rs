use crate::core::connection::message_batcher::MessageBatcher;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::protocol::compressor::GzipCompressor;
use crate::protocol::sdkws::PushMessages;
use crate::protocol::ws::{OpenIMReq, OpenIMResp, WebSocketConnectResp};
use futures_util::stream::SplitSink;
use futures_util::{SinkExt, StreamExt};
use prost::Message;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, AtomicU32, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::sync::{oneshot, RwLock};
use tokio::time::{interval, timeout, sleep, MissedTickBehavior};
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tokio_tungstenite::{connect_async, MaybeTlsStream, WebSocketStream};
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info, warn};

type WsWriter = SplitSink<WebSocketStream<MaybeTlsStream<TcpStream>>, WsMessage>;

const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(30);
const PONG_TIMEOUT: Duration = Duration::from_secs(60);
const RECONNECT_BASE_DELAY: Duration = Duration::from_secs(1);
const RECONNECT_MAX_DELAY: Duration = Duration::from_secs(60);
const MAX_RECONNECT_ATTEMPTS: u32 = 300;
const RPC_TIMEOUT: Duration = Duration::from_secs(30);
const CHANNEL_SIZE: usize = 256;

#[derive(Clone, Debug, PartialEq, serde::Serialize, serde::Deserialize)]
pub enum ConnectionState {
    Disconnected,
    Connecting,
    Connected,
    Reconnecting,
    Kicked,
}

struct PendingRequest {
    tx: oneshot::Sender<OpenIMResp>,
    timer: tokio::time::Instant,
}

pub struct ConnectionManager {
    writer: Arc<RwLock<Option<WsWriter>>>,
    state: Arc<RwLock<ConnectionState>>,
    pending_requests: Arc<RwLock<HashMap<String, PendingRequest>>>,
    event_bus: Arc<EventBus>,
    cancel_token: CancellationToken,

    msg_incr: AtomicU64,
    token: RwLock<String>,
    send_id: RwLock<String>,
    ws_url: RwLock<String>,
    platform_id: RwLock<i32>,

    reconnect_attempts: AtomicU32,
    is_manual_disconnect: Arc<RwLock<bool>>,

    /// Gzip 压缩器（对齐 Go SDK compressor.go）
    compressor: GzipCompressor,
    /// 推送消息批处理器（对齐 Go SDK message_batcher.go）
    message_batcher: MessageBatcher,
}

impl ConnectionManager {
    pub fn new(event_bus: Arc<EventBus>, cancel_token: CancellationToken) -> Self {
        let event_bus_clone = event_bus.clone();
        let compressor = GzipCompressor::new();
        let message_batcher = MessageBatcher::new(move |operation_ids, batch| {
            // 聚合后的推送消息统一发布到 EventBus
            if !batch.msgs.is_empty() || !batch.notification_msgs.is_empty() {
                event_bus_clone.publish(SdkEvent::BatchedPushMessages {
                    msgs: batch.msgs,
                    notification_msgs: batch.notification_msgs,
                });
            }
        });

        Self {
            writer: Arc::new(RwLock::new(None)),
            state: Arc::new(RwLock::new(ConnectionState::Disconnected)),
            pending_requests: Arc::new(RwLock::new(HashMap::new())),
            event_bus,
            cancel_token,
            msg_incr: AtomicU64::new(0),
            token: RwLock::new(String::new()),
            send_id: RwLock::new(String::new()),
            ws_url: RwLock::new(String::new()),
            platform_id: RwLock::new(1),
            reconnect_attempts: AtomicU32::new(0),
            is_manual_disconnect: Arc::new(RwLock::new(false)),
            compressor,
            message_batcher,
        }
    }

    pub async fn connect(&self, ws_url: &str, token: &str, user_id: &str, platform_id: i32) -> Result<()> {
        *self.token.write().await = token.to_string();
        *self.send_id.write().await = user_id.to_string();
        *self.ws_url.write().await = ws_url.to_string();
        *self.platform_id.write().await = platform_id;
        *self.is_manual_disconnect.write().await = false;
        self.reconnect_attempts.store(0, Ordering::SeqCst);

        self.do_connect().await
    }

    async fn do_connect(&self) -> Result<()> {
        self.set_state(ConnectionState::Connecting).await;
        self.event_bus.publish(SdkEvent::Connecting);

        let ws_url = self.ws_url.read().await;
        let token = self.token.read().await;
        let send_id = self.send_id.read().await;
        let platform_id = self.platform_id.read().await;
        let operation_id = format!("conn_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis());

        let full_url = format!(
            "{}/?token={}&sendID={}&platformID={}&operationID={}&isBackground=false&isMsgResp=true&sdkType=js&compression=gzip",
            *ws_url, *token, *send_id, *platform_id, operation_id
        );

        let (ws_stream, _) = connect_async(&full_url)
            .await
            .map_err(|e| {
                error!("WebSocket connect failed: {}, url={}", e, full_url);
                SdkError::connection(format!("WebSocket connect failed: {}", e))
            })?;

        let (write, read) = ws_stream.split();
        
        *self.writer.write().await = Some(write);
        self.set_state(ConnectionState::Connected).await;
        self.event_bus.publish(SdkEvent::Connected);
        self.reconnect_attempts.store(0, Ordering::SeqCst);
        info!("WebSocket connected: {}", full_url);

        self.spawn_read_loop(read);
        self.spawn_heartbeat();
        self.spawn_reconnect_loop();

        Ok(())
    }

    fn spawn_reconnect_loop(&self) {
        let event_bus = self.event_bus.clone();
        let cancel = self.cancel_token.clone();
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
                            let current_state = state.read().await.clone();
                            let manual = { *is_manual.read().await };
                            
                            if manual {
                                info!("reconnect_loop: manual disconnect, stopping");
                                return;
                            }
                            
                            if current_state == ConnectionState::Disconnected || current_state == ConnectionState::Reconnecting {
                                break;
                            }
                            
                            tokio::time::sleep(Duration::from_secs(1)).await;
                        }
                    } => {
                        let manual = { *is_manual.read().await };
                        if manual {
                            break;
                        }

                        let attempts = self_clone.reconnect_attempts.fetch_add(1, Ordering::SeqCst);
                        if attempts >= MAX_RECONNECT_ATTEMPTS {
                            error!("max reconnect attempts reached ({})", MAX_RECONNECT_ATTEMPTS);
                            event_bus.publish(SdkEvent::Disconnected {
                                reason: "max reconnect attempts".into(),
                            });
                            break;
                        }

                        let delay = self_clone.calculate_reconnect_delay(attempts);
                        info!("reconnecting in {:?} (attempt {}/{})", delay, attempts + 1, MAX_RECONNECT_ATTEMPTS);
                        event_bus.publish(SdkEvent::Reconnecting {
                            attempt: attempts + 1,
                            max_attempts: MAX_RECONNECT_ATTEMPTS,
                        });

                        tokio::select! {
                            _ = cancel.cancelled() => break,
                            _ = sleep(delay) => {}
                        }

                        let manual = { *is_manual.read().await };
                        if manual {
                            break;
                        }

                        {
                            *state.write().await = ConnectionState::Reconnecting;
                        }

                        match self_clone.do_connect().await {
                            Ok(_) => {
                                // 等待短暂时间，让 read_loop 有机会处理服务器的连接响应
                                tokio::time::sleep(Duration::from_millis(200)).await;
                                // 检查是否被踢下线（read_loop 会设置 is_manual_disconnect）
                                let manual = { *is_manual.read().await };
                                let current_state = { state.read().await.clone() };
                                if manual || current_state == ConnectionState::Kicked {
                                    info!("reconnected but kicked by server, stopping reconnect");
                                    break;
                                }
                                info!("reconnected successfully");
                                self_clone.reconnect_attempts.store(0, Ordering::SeqCst);
                            }
                            Err(e) => {
                                warn!("reconnect failed: {:?}", e);
                                {
                                    *state.write().await = ConnectionState::Disconnected;
                                }
                                event_bus.publish(SdkEvent::Disconnected {
                                    reason: format!("reconnect failed: {}", e),
                                });
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
        
        let delay = Duration::from_secs(delay_secs as u64);
        delay.min(RECONNECT_MAX_DELAY)
    }

    fn clone_shallow(&self) -> ConnectionManager {
        ConnectionManager {
            writer: self.writer.clone(),
            state: self.state.clone(),
            pending_requests: self.pending_requests.clone(),
            event_bus: self.event_bus.clone(),
            cancel_token: self.cancel_token.clone(),
            msg_incr: AtomicU64::new(self.msg_incr.load(Ordering::SeqCst)),
            token: RwLock::new(self.token.try_read().map(|t| t.clone()).unwrap_or_default()),
            send_id: RwLock::new(self.send_id.try_read().map(|s| s.clone()).unwrap_or_default()),
            ws_url: RwLock::new(self.ws_url.try_read().map(|u| u.clone()).unwrap_or_default()),
            platform_id: RwLock::new(self.platform_id.try_read().ok().map(|g| *g).unwrap_or(0)),
            reconnect_attempts: AtomicU32::new(0),
            is_manual_disconnect: self.is_manual_disconnect.clone(),
            compressor: GzipCompressor::new(),
            // 浅克隆用于重连，不共享 batcher（重连后原始 batcher 继续工作）
            message_batcher: MessageBatcher::new(|_, _| {}),
        }
    }

    fn spawn_read_loop(
        &self,
        read: futures_util::stream::SplitStream<WebSocketStream<MaybeTlsStream<TcpStream>>>,
    ) {
        let pending = self.pending_requests.clone();
        let event_bus = self.event_bus.clone();
        let cancel = self.cancel_token.clone();
        let state = self.state.clone();
        let writer = self.writer.clone();
        let compressor = self.compressor.clone();
        let message_batcher = self.message_batcher.clone();
        let is_manual_disconnect = self.is_manual_disconnect.clone();

        // TokenKickedError 错误码（同账号在其他设备登录被踢）
        const TOKEN_KICKED_ERR_CODE: i32 = 1506;

        tokio::spawn(async move {
            let mut read = read;
            loop {
                tokio::select! {
                    _ = cancel.cancelled() => {
                        info!("read_loop: cancelled");
                        break;
                    }
                    msg = read.next() => {
                        match msg {
                            Some(Ok(WsMessage::Text(text))) => {
                                // 先尝试解析为 OpenIMResp（推送消息或 RPC 响应）
                                match serde_json::from_str::<OpenIMResp>(&text) {
                                    Ok(resp) => {
                                        if let Some(pending_req) =
                                            pending.write().await.remove(&resp.msg_incr)
                                        {
                                            let _ = pending_req.tx.send(resp);
                                        } else {
                                            // 推送消息
                                            event_bus.publish(
                                                SdkEvent::PushMessage {
                                                    req_identifier: resp.req_identifier,
                                                    data: resp.data,
                                                },
                                            );
                                        }
                                    }
                                    Err(_) => {
                                        // 尝试解析为 WebSocketConnectResp（连接响应）
                                        match serde_json::from_str::<WebSocketConnectResp>(&text) {
                                            Ok(conn_resp) => {
                                                if conn_resp.err_code == 0 {
                                                    info!("WebSocket connection confirmed by server");
                                                } else if conn_resp.err_code == TOKEN_KICKED_ERR_CODE {
                                                    // 被踢下线：停止重连，通知上层
                                                    warn!("TokenKickedError: 同账号在其他设备登录，停止重连");
                                                    *is_manual_disconnect.write().await = true;
                                                    *writer.write().await = None;
                                                    *state.write().await = ConnectionState::Kicked;
                                                    message_batcher.close().await;
                                                    event_bus.publish(SdkEvent::KickedOffline {
                                                        reason: conn_resp.err_msg.clone(),
                                                    });
                                                    break;
                                                } else {
                                                    warn!("WebSocket connection failed: errCode={}, errMsg={}",
                                                        conn_resp.err_code, conn_resp.err_msg);
                                                    *state.write().await = ConnectionState::Disconnected;
                                                    event_bus.publish(SdkEvent::Disconnected {
                                                        reason: format!("server rejected: {}", conn_resp.err_msg),
                                                    });
                                                    break;
                                                }
                                            }
                                            Err(e) => {
                                                warn!("failed to parse ws message as OpenIMResp or WebSocketConnectResp: {}, text={}", e, &text[..text.len().min(100)]);
                                            }
                                        }
                                    }
                                }
                            }
                            Some(Ok(WsMessage::Binary(data))) => {
                            // Gzip 解压（对齐 Go SDK compressor.go DecompressWithPool）
                            let data = match compressor.decompress(&data) {
                                Ok(decompressed) => decompressed,
                                Err(_) => data, // 非压缩数据直接使用原始数据
                            };
                            // 尝试 JSON 解码为 OpenIMResp
                            match serde_json::from_slice::<OpenIMResp>(&data) {
                                Ok(resp) => {
                                    info!("decoded binary message as OpenIMResp, req_identifier={}, err_code={}", 
                                        resp.req_identifier, resp.err_code);
                                    
                                    // 根据 req_identifier 判断消息类型
                                    if resp.req_identifier == crate::domain::constant::types::ws_push_identifier::PUSH_MSG && resp.err_code == 0 {
                                        // data 字段是 protobuf 编码的 PushMessages → 通过 MessageBatcher 聚合
                                        match PushMessages::decode(resp.data.as_slice()) {
                                            Ok(push_msgs) => {
                                                info!("received push messages: {} conversations with msgs, {} with notifications", 
                                                    push_msgs.msgs.len(), push_msgs.notification_msgs.len());
                                                message_batcher.enqueue(resp.operation_id, push_msgs).await;
                                            }
                                            Err(e) => {
                                                warn!("failed to decode push messages from protobuf: {}", e);
                                            }
                                        }
                                    } else {
                                        // RPC 响应（包括错误响应），通知等待的通道
                                        if resp.err_code != 0 {
                                            warn!("server error response: req_identifier={}, err_code={}, err_msg={}", 
                                                resp.req_identifier, resp.err_code, resp.err_msg);
                                        }
                                        if let Some(req) = pending.write().await.remove(&resp.msg_incr) {
                                            let _ = req.tx.send(resp);
                                        }
                                    }
                                }
                                Err(e) => {
                                    // 打印前200字节的hex用于调试编码格式
                                    let preview: String = data.iter().take(200)
                                        .map(|b| format!("{:02x}", b))
                                        .collect();
                                    warn!("failed to decode binary message as OpenIMResp: {}, len={}, hex[0:100]={}", e, data.len(), &preview[..preview.len().min(200)]);
                                }
                            }
                        }
                            Some(Ok(WsMessage::Ping(data))) => {
                                if let Some(w) = writer.write().await.as_mut() {
                                    let _ = w.send(WsMessage::Pong(data)).await;
                                }
                            }
                            Some(Ok(WsMessage::Pong(_))) => {
                            }
                            Some(Ok(WsMessage::Close(_))) => {
                                info!("ws closed by server");
                                {
                                    *state.write().await = ConnectionState::Disconnected;
                                }
                                event_bus.publish(SdkEvent::Disconnected {
                                    reason: "server closed".into(),
                                });
                                break;
                            }
                            Some(Err(e)) => {
                                error!("ws error: {}", e);
                                {
                                    *state.write().await = ConnectionState::Disconnected;
                                }
                                event_bus.publish(SdkEvent::Disconnected {
                                    reason: format!("ws error: {}", e),
                                });
                                break;
                            }
                            None => {
                                info!("ws stream ended");
                                {
                                    *state.write().await = ConnectionState::Disconnected;
                                }
                                event_bus.publish(SdkEvent::Disconnected {
                                    reason: "stream ended".into(),
                                });
                                break;
                            }
                            _ => {}
                        }
                    }
                }
            }
        });
    }

    fn spawn_heartbeat(&self) {
        let writer = self.writer.clone();
        let state = self.state.clone();
        let event_bus = self.event_bus.clone();
        let cancel = self.cancel_token.clone();

        tokio::spawn(async move {
            let mut ticker = interval(HEARTBEAT_INTERVAL);
            ticker.set_missed_tick_behavior(MissedTickBehavior::Delay);

            loop {
                tokio::select! {
                    _ = cancel.cancelled() => break,
                    _ = ticker.tick() => {
                        let is_connected = {
                            *state.read().await == ConnectionState::Connected
                        };
                        if !is_connected {
                            continue;
                        }

                        let ping_result = {
                            let mut w = writer.write().await;
                            if let Some(writer) = w.as_mut() {
                                writer.send(WsMessage::Ping(vec![])).await
                            } else {
                                continue;
                            }
                        };

                        if let Err(e) = ping_result {
                            warn!("heartbeat ping failed: {}", e);
                            *state.write().await = ConnectionState::Disconnected;
                            event_bus.publish(SdkEvent::Disconnected {
                                reason: format!("ping failed: {}", e),
                            });
                            break;
                        }
                    }
                }
            }
        });
    }

    pub async fn send_rpc<T: prost::Message, R: prost::Message + Default>(
        &self,
        req_identifier: i32,
        data: &T,
    ) -> Result<R> {
        let data_bytes = data.encode_to_vec();

        let msg_incr = format!("rpc_{}", self.msg_incr.fetch_add(1, Ordering::SeqCst));
        let token = self.token.read().await.clone();
        let send_id = self.send_id.read().await.clone();
        let operation_id = format!("op_{}_{}", req_identifier, msg_incr);

        let req = OpenIMReq {
            req_identifier,
            token,
            send_id,
            operation_id,
            msg_incr: msg_incr.clone(),
            data: data_bytes,
        };

        let (tx, rx) = oneshot::channel();
        self.pending_requests.write().await.insert(
            msg_incr,
            PendingRequest {
                tx,
                timer: tokio::time::Instant::now(),
            },
        );

        let req_json = serde_json::to_string(&req)
            .map_err(|e| SdkError::unknown(format!("serialize rpc request: {}", e)))?;

        // Gzip 压缩（对齐 Go SDK compressor.go CompressWithPool）
        let compressed = self.compressor.compress(req_json.as_bytes())
            .map_err(|e| SdkError::unknown(format!("compress rpc request: {}", e)))?;

        let send_result = {
            let mut w = self.writer.write().await;
            if let Some(writer) = w.as_mut() {
                writer
                    .send(WsMessage::Binary(compressed))
                    .await
                    .map_err(|e| SdkError::connection(format!("send failed: {}", e)))
            } else {
                Err(SdkError::connection("not connected"))
            }
        };

        if let Err(e) = send_result {
            self.pending_requests.write().await.remove(&req.msg_incr);
            return Err(e);
        }

        match timeout(RPC_TIMEOUT, rx).await {
            Ok(Ok(resp)) => {
                if resp.is_success() {
                    R::decode(resp.data.as_slice())
                        .map_err(|e| SdkError::unknown(format!("decode response: {}", e)))
                } else {
                    Err(SdkError::api(resp.err_code, &resp.err_msg))
                }
            }
            Ok(Err(_)) => Err(SdkError::connection("rpc channel closed")),
            Err(_) => Err(SdkError::timeout("rpc timeout")),
        }
    }

    pub async fn disconnect(&self) {
        *self.is_manual_disconnect.write().await = true;
        *self.writer.write().await = None;
        {
            *self.state.write().await = ConnectionState::Disconnected;
        }
        // 关闭 MessageBatcher，flush 剩余缓冲消息
        self.message_batcher.close().await;
        self.event_bus.publish(SdkEvent::Disconnected {
            reason: "manual disconnect".into(),
        });
        info!("WebSocket disconnected (manual)");
    }

    pub async fn handle_kicked(&self, reason: String) {
        *self.is_manual_disconnect.write().await = true;
        *self.writer.write().await = None;
        {
            *self.state.write().await = ConnectionState::Kicked;
        }
        // 关闭 MessageBatcher，flush 剩余缓冲消息
        self.message_batcher.close().await;
        self.event_bus.publish(SdkEvent::KickedOffline {
            reason: reason.clone(),
        });
        warn!("kicked offline: {}", reason);
    }

    pub fn message_batcher(&self) -> &MessageBatcher {
        &self.message_batcher
    }

    pub async fn get_state(&self) -> ConnectionState {
        self.state.read().await.clone()
    }

    async fn set_state(&self, state: ConnectionState) {
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
        let event_bus = Arc::new(EventBus::new());
        let cancel_token = CancellationToken::new();
        let manager = ConnectionManager::new(event_bus, cancel_token);

        assert_eq!(manager.get_state().await, ConnectionState::Disconnected);
    }

    #[tokio::test]
    async fn test_connection_state_transitions() {
        let event_bus = Arc::new(EventBus::new());
        let cancel_token = CancellationToken::new();
        let manager = ConnectionManager::new(event_bus, cancel_token);

        manager.set_state(ConnectionState::Connecting).await;
        assert_eq!(manager.get_state().await, ConnectionState::Connecting);

        manager.set_state(ConnectionState::Connected).await;
        assert_eq!(manager.get_state().await, ConnectionState::Connected);

        manager.disconnect().await;
        assert_eq!(manager.get_state().await, ConnectionState::Disconnected);
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
