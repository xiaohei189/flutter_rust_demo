use crate::core::connection::message_batcher::MessageBatcher;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::listener::connection::{ConnectionEvent, ConnectionListener};
use crate::infra::logger::extract_trace_id;
use crate::protocol::compressor::GzipCompressor;
use crate::protocol::sdkws::PushMessages;
use crate::protocol::ws::{OpenIMReq, OpenIMResp, WebSocketConnectResp};
use futures_util::stream::SplitSink;
use futures_util::{SinkExt, StreamExt};
use prost::Message;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::sync::{oneshot, RwLock};
use tokio::time::{interval, sleep, timeout, MissedTickBehavior};
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tokio_tungstenite::{connect_async, MaybeTlsStream, WebSocketStream};
use opentelemetry::trace::{SpanContext, SpanId, TraceContextExt, TraceFlags, TraceId, TraceState};
use opentelemetry::Context;
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info, info_span, warn};
use tracing_opentelemetry::OpenTelemetrySpanExt;

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
    cancel_token: CancellationToken,

    msg_incr: AtomicU64,
    token: RwLock<String>,
    send_id: RwLock<String>,
    ws_url: RwLock<String>,
    platform_id: RwLock<i32>,

    reconnect_attempts: Arc<AtomicU32>,
    is_manual_disconnect: Arc<RwLock<bool>>,

    /// Gzip 压缩器（对齐 Go SDK compressor.go）
    compressor: GzipCompressor,
    /// 推送消息批处理器（对齐 Go SDK message_batcher.go）
    message_batcher: MessageBatcher,
    /// 内部消息通道（对齐 Go SDK 直接分发的模式，不走 EventBus）
    /// 携带 Span 以便跨 task 传递 trace context
    push_tx: Arc<std::sync::Mutex<Option<tokio::sync::mpsc::UnboundedSender<(PushMessages, tracing::Span)>>>>,
    pub(crate) event_tx: Arc<std::sync::Mutex<Option<tokio::sync::mpsc::UnboundedSender<ConnectionEvent>>>>,
    pub(crate) on_connected_hook: Arc<std::sync::Mutex<Option<Box<dyn Fn() + Send + Sync>>>>,
}

impl ConnectionManager {
    pub fn set_event_sender(&self, tx: tokio::sync::mpsc::UnboundedSender<ConnectionEvent>) {
        *self.event_tx.lock().unwrap() = Some(tx);
    }

    pub(crate) fn send(&self, e: ConnectionEvent) {
        let has_tx = self.event_tx.lock().unwrap().is_some();
        tracing::info!("[SEND] {:?}, has_subscriber={}", &e, has_tx);
        if let Some(tx) = &*self.event_tx.lock().unwrap() {
            let _ = tx.send(e);
        }
    }

    pub fn new(cancel_token: CancellationToken) -> Self {
        let push_tx: Arc<std::sync::Mutex<Option<tokio::sync::mpsc::UnboundedSender<(PushMessages, tracing::Span)>>>> = Arc::new(std::sync::Mutex::new(None));
        let push_tx_clone = push_tx.clone();
        let compressor = GzipCompressor::new();
        let message_batcher = MessageBatcher::new(move |_operation_ids, batch| {
            // 聚合后通过内部通道发送（对齐 Go SDK 直接调用，不走 EventBus）
            // 携带当前 span context 以便跨 task 传递
            if !batch.msgs.is_empty() || !batch.notification_msgs.is_empty() {
                if let Some(tx) = push_tx_clone.lock().unwrap().as_ref() {
                    let span = tracing::Span::current();
                    let _ = tx.send((batch, span));
                }
            }
        });

        Self {
            writer: Arc::new(RwLock::new(None)),
            state: Arc::new(RwLock::new(ConnectionState::Disconnected)),
            pending_requests: Arc::new(RwLock::new(HashMap::new())),
            cancel_token,
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
            event_tx: Arc::new(std::sync::Mutex::new(None)),
            on_connected_hook: Arc::new(std::sync::Mutex::new(None)),
        }
    }

    /// 设置内部消息通道发送端（由 client.rs 在 login 后调用）
    pub fn set_push_sender(&self, tx: tokio::sync::mpsc::UnboundedSender<(PushMessages, tracing::Span)>) {
        *self.push_tx.lock().unwrap() = Some(tx);
    }

    #[tracing::instrument(level = "info", skip(self), fields(user_id = %user_id, platform_id = platform_id))]
    pub async fn connect(&self, ws_url: &str, token: &str, user_id: &str, platform_id: i32) -> Result<()> {
        // 关闭已有连接（热重启或重复登录场景），避免旧连接残留导致新连接被踢
        {
            let current_state = self.state.read().await.clone();
            if current_state != ConnectionState::Disconnected {
                info!("[Connection] connect: 关闭已有连接（状态: {:?}）", current_state);
                *self.is_manual_disconnect.write().await = true;
                *self.writer.write().await = None;
                *self.state.write().await = ConnectionState::Disconnected;
                self.message_batcher.close().await;
                // 给旧的 reconnect_loop 和 read_loop 一点时间退出
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
        }

        *self.token.write().await = token.to_string();
        *self.send_id.write().await = user_id.to_string();
        *self.ws_url.write().await = ws_url.to_string();
        *self.platform_id.write().await = platform_id;
        *self.is_manual_disconnect.write().await = false;
        self.reconnect_attempts.store(0, Ordering::SeqCst);

        self.do_connect().await?;
        // 仅在上层主动 connect 时 spawn 一次 reconnect_loop，
        // 避免 do_connect 被多次调用时产生多个并发的重连循环
        self.spawn_reconnect_loop();
        Ok(())
    }

    async fn do_connect(&self) -> Result<()> {
        // 令牌错误码（重连无意义）
        const TOKEN_KICKED_ERR_CODE: i32 = 1506;
        const TOKEN_NOT_EXIST_ERR_CODE: i32 = 1507;

        self.set_state(ConnectionState::Connecting).await;
        self.send(ConnectionEvent::Connecting);

        let ws_url = self.ws_url.read().await;
        let token = self.token.read().await;
        let send_id = self.send_id.read().await;
        let platform_id = self.platform_id.read().await;
        let trace_id = extract_trace_id();
        let operation_id = if trace_id.is_empty() {
            format!("conn_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())
        } else {
            trace_id
        };

        let full_url = format!(
            "{}/?token={}&sendID={}&platformID={}&operationID={}&isBackground=false&isMsgResp=true&sdkType=js&compression=gzip",
            *ws_url, *token, *send_id, *platform_id, operation_id
        );

        let (ws_stream, _) = tokio::time::timeout(Duration::from_secs(10), connect_async(&full_url))
            .await
            .map_err(|_| {
                error!("WebSocket connect timeout after 10s, url={}", full_url);
                SdkError::connection("WebSocket connect timeout (10s)")
            })?
            .map_err(|e| {
                error!("WebSocket connect failed: {}, url={}", e, full_url);
                SdkError::connection(format!("WebSocket connect failed: {}", e))
            })?;

        let (write, mut read) = ws_stream.split();
        info!("WebSocket handshake done: {}", full_url);

        // 对齐 Go SDK reConn(): 预读首条消息进行认证
        // Go 在 HTTP 握手阶段通过 response body 获取认证结果
        // Rust 侧 tokio_tungstenite 握手成功后服务端首条消息即为认证响应
        let auth_result: std::result::Result<WebSocketConnectResp, SdkError> = match read.next().await {
            Some(Ok(WsMessage::Text(text))) => serde_json::from_str::<WebSocketConnectResp>(&text).map_err(|e| SdkError::connection(format!("auth parse error: {}", e))),
            Some(Ok(WsMessage::Binary(data))) => {
                // 尝试解压后解析
                let data = self.compressor.decompress(&data).unwrap_or(data);
                serde_json::from_slice::<WebSocketConnectResp>(&data).map_err(|e| SdkError::connection(format!("auth parse error: {}", e)))
            }
            Some(Ok(WsMessage::Close(_))) => Err(SdkError::connection("server closed during auth")),
            Some(Err(e)) => Err(SdkError::connection(format!("ws error during auth: {}", e))),
            None => Err(SdkError::connection("stream ended during auth")),
            _ => Err(SdkError::connection("unexpected message during auth")),
        };

        match auth_result {
            Ok(conn_resp) if conn_resp.err_code == 0 => {
                // 认证通过 → 发布 Connected，启动读写循环
                info!("WebSocket auth confirmed by server");
                *self.writer.write().await = Some(write);
                self.set_state(ConnectionState::Connected).await;
                self.send(ConnectionEvent::Connected);
                if let Some(hook) = &*self.on_connected_hook.lock().unwrap() {
                    hook();
                }
                self.reconnect_attempts.store(0, Ordering::SeqCst);
                self.spawn_read_loop(read);
                self.spawn_heartbeat();
                Ok(())
            }
            Ok(conn_resp) if conn_resp.err_code == TOKEN_KICKED_ERR_CODE => {
                // 被踢下线：取消所有后台任务，不再重连
                warn!("TokenKickedError ({}): 同账号在其他设备登录，停止重连", conn_resp.err_code);
                self.cancel_token.cancel();
                *self.is_manual_disconnect.write().await = true;
                *self.state.write().await = ConnectionState::Kicked;
                self.message_batcher.close().await;
                self.send(ConnectionEvent::KickedOffline(conn_resp.err_msg.to_string()));
                Err(SdkError::api(conn_resp.err_code, &conn_resp.err_msg))
            }
            Ok(conn_resp) if conn_resp.err_code == TOKEN_NOT_EXIST_ERR_CODE => {
                // Token 无效/过期：取消所有后台任务，不再重连
                warn!("TokenNotExistError ({}): token 无效或已过期，停止重连", conn_resp.err_code);
                self.cancel_token.cancel();
                *self.is_manual_disconnect.write().await = true;
                *self.state.write().await = ConnectionState::Kicked;
                self.message_batcher.close().await;
                self.send(ConnectionEvent::TokenExpired);
                Err(SdkError::api(conn_resp.err_code, &conn_resp.err_msg))
            }
            Ok(conn_resp) => {
                // 其他服务端错误：短暂断开后允许重连
                warn!("WebSocket auth failed: errCode={}, errMsg={}", conn_resp.err_code, conn_resp.err_msg);
                *self.state.write().await = ConnectionState::Disconnected;
                let reason = format!("server rejected: {}", conn_resp.err_msg);
                self.send(ConnectionEvent::Disconnected(reason.to_string()));
                Err(SdkError::api(conn_resp.err_code, &conn_resp.err_msg))
            }
            Err(e) => {
                // 解析认证消息失败
                error!("WebSocket auth parse error: {:?}", e);
                *self.state.write().await = ConnectionState::Disconnected;
                let reason = format!("auth parse error: {}", e);
                self.send(ConnectionEvent::Disconnected(reason.to_string()));
                Err(e)
            }
        }
    }

    fn spawn_reconnect_loop(&self) {
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
                        if manual {
                            break;
                        }

                        {
                            *state.write().await = ConnectionState::Reconnecting;
                        }

                        match self_clone.do_connect().await {
                            Ok(_) => {
                                // 认证已在 do_connect() 中完成，Connected 事件已发布
                                info!("reconnected successfully");
                                self_clone.reconnect_attempts.store(0, Ordering::SeqCst);
                            }
                            Err(e) => {
                                warn!("reconnect failed: {:?}", e);
                                // 令牌致命错误已在 do_connect() 中设置 is_manual_disconnect，
                                // 检查并直接退出重连循环
                                let manual = { *is_manual.read().await };
                                if manual {
                                    break;
                                }
                                {
                                    *state.write().await = ConnectionState::Disconnected;
                                }
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
            cancel_token: self.cancel_token.clone(),
            msg_incr: AtomicU64::new(self.msg_incr.load(Ordering::SeqCst)),
            token: RwLock::new(self.token.try_read().map(|t| t.clone()).unwrap_or_default()),
            send_id: RwLock::new(self.send_id.try_read().map(|s| s.clone()).unwrap_or_default()),
            ws_url: RwLock::new(self.ws_url.try_read().map(|u| u.clone()).unwrap_or_default()),
            platform_id: RwLock::new(self.platform_id.try_read().ok().map(|g| *g).unwrap_or(0)),
            reconnect_attempts: self.reconnect_attempts.clone(),
            is_manual_disconnect: self.is_manual_disconnect.clone(),
            compressor: GzipCompressor::new(),
            // 浅克隆用于重连，不共享 batcher（重连后原始 batcher 继续工作）
            message_batcher: MessageBatcher::new(|_, _| {}),
            push_tx: self.push_tx.clone(),
            event_tx: self.event_tx.clone(),
            on_connected_hook: self.on_connected_hook.clone(),
        }
    }

    fn spawn_read_loop(&self, read: futures_util::stream::SplitStream<WebSocketStream<MaybeTlsStream<TcpStream>>>) {
        let pending = self.pending_requests.clone();
        let cancel = self.cancel_token.clone();
        let state = self.state.clone();
        let writer = self.writer.clone();
        let compressor = self.compressor.clone();
        let message_batcher = self.message_batcher.clone();
        let is_manual_disconnect = self.is_manual_disconnect.clone();
        let event_tx = self.event_tx.clone();

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
                                // 解析 OpenIMResp（推送消息或 RPC 响应）
                                // 认证已在 do_connect() 中通过首条消息完成，无需再次处理 WebSocketConnectResp
                                match serde_json::from_str::<OpenIMResp>(&text) {
                                    Ok(resp) => {
                                        if let Some(pending_req) =
                                            pending.write().await.remove(&resp.msg_incr)
                                        {
                                            let _ = pending_req.tx.send(resp);
                                        } else if resp.err_code == 0 && !resp.data.is_empty() {
                                            // 推送消息：对齐 Go SDK 直接分发，不走 EventBus
                                            if let Ok(push_msgs) = PushMessages::decode(resp.data.as_slice()) {
                                                message_batcher.enqueue(resp.operation_id, push_msgs).await;
                                            }
                                        }
                                    }
                                    Err(e) => {
                                        warn!("failed to parse ws text as OpenIMResp: {}, text={}", e, &text[..text.len().min(100)]);
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
                                    let span = if let Ok(trace_id) = TraceId::from_hex(&resp.operation_id) {
                                            let remote_sc = SpanContext::new(
                                                trace_id,
                                                SpanId::INVALID,
                                                TraceFlags::SAMPLED,
                                                true,
                                                TraceState::default(),
                                            );
                                            let parent_cx = Context::new().with_remote_span_context(remote_sc);
                                            let span = info_span!("ws_binary_resp");
                                            span.set_parent(parent_cx);
                                            span
                                        } else {
                                            info_span!("ws_binary_resp")
                                        };
                                    let _enter = span.enter();
                                    info!("ws binary response: req_identifier={}, operation_id={}", resp.req_identifier, resp.operation_id);

                                    use crate::domain::constant::types::{ws_push_identifier, ws_req_identifier};
                                    match resp.req_identifier {
                                        // PushMsg (2001) — 对齐 Go case constant.PushMsg
                                        ws_push_identifier::PUSH_MSG => {
                                            match PushMessages::decode(resp.data.as_slice()) {
                                                Ok(push_msgs) => {
                                                    info!("received push messages: {} conversations with msgs, {} with notifications",
                                                        push_msgs.msgs.len(), push_msgs.notification_msgs.len());
                                                    message_batcher.enqueue(resp.operation_id, push_msgs).await;
                                                }
                                                Err(e) => {
                                                    error!("doWSPushMsg failed: {}", e);
                                                }
                                            }
                                        }
                                        // LogoutMsg (2003) — 对齐 Go case constant.LogoutMsg
                                        ws_push_identifier::LOGOUT_MSG => {
                                            info!("ws logout message: operation_id={}", resp.operation_id);
                                            if let Some(req) = pending.write().await.remove(&resp.msg_incr) {
                                                let _ = req.tx.send(resp);
                                            }
                                            *is_manual_disconnect.write().await = true;
                                            message_batcher.close().await;
                                            if let Some(tx) = &*event_tx.lock().unwrap() {
                                                let _ = tx.send(ConnectionEvent::Logout);
                                            }
                                            cancel.cancel();
                                            break;
                                        }
                                        // KickOnlineMsg (2002) — 对齐 Go case constant.KickOnlineMsg
                                        // 被踢一定是服务端推送，无对应 pending，无需 NotifyResp
                                        ws_push_identifier::KICK_ONLINE_MSG => {
                                            warn!("ws kick online message: operation_id={}", resp.operation_id);
                                            *is_manual_disconnect.write().await = true;
                                            *state.write().await = ConnectionState::Kicked;
                                            message_batcher.close().await;
                                            if let Some(tx) = &*event_tx.lock().unwrap() {
                                                let _ = tx.send(ConnectionEvent::KickedOffline(resp.err_msg.to_string()));
                                            }
                                            cancel.cancel();
                                            break;
                                        }
                                        // GetNewestSeq / PullMsgByRange / SendMsg / SendSignalMsg
                                        // PullMsgBySeqList / GetConvMaxReadSeq / PullConvLastMessage
                                        // SetBackgroundStatus — 对齐 Go case fallthrough: NotifyResp
                                        ws_req_identifier::GET_NEWEST_SEQ
                                        | ws_req_identifier::PULL_MSG_BY_RANGE
                                        | ws_req_identifier::SEND_MSG
                                        | ws_req_identifier::SEND_SIGNAL_MSG
                                        | ws_req_identifier::PULL_MSG_BY_SEQ_LIST
                                        | ws_req_identifier::GET_CONV_MAX_READ_SEQ
                                        | ws_req_identifier::PULL_CONV_LAST_MESSAGE
                                        | ws_push_identifier::SET_BACKGROUND_STATUS => {
                                            info!("ws notify response: req_identifier={}, msg_incr={}, operation_id={}",
                                                resp.req_identifier, resp.msg_incr, resp.operation_id);
                                            if let Some(req) = pending.write().await.remove(&resp.msg_incr) {
                                                let _ = req.tx.send(resp);
                                            }
                                        }
                                        // WsSubUserOnlineStatus (2005) — 对齐 Go case constant.WsSubUserOnlineStatus
                                        ws_push_identifier::WS_SUB_USER_ONLINE_STATUS => {
                                            warn!("WsSubUserOnlineStatus handler not yet implemented, operation_id={}", resp.operation_id);
                                        }
                                        // 未知类型 — 对齐 Go default: return sdkerrs.ErrMsgBinaryTypeNotSupport
                                        _ => {
                                            error!("binary message type not support: req_identifier={}, operation_id={}",
                                                resp.req_identifier, resp.operation_id);
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
                                break;
                            }
                            Some(Err(e)) => {
                                let manual = { *is_manual_disconnect.read().await };
                                if manual {
                                    info!("ws closed (manual disconnect): {}", e);
                                } else {
                                    error!("ws error: {}", e);
                                }
                                {
                                    *state.write().await = ConnectionState::Disconnected;
                                }
                                if !manual {
                                }
                                break;
                            }
                            None => {
                                let manual = { *is_manual_disconnect.read().await };
                                if manual {
                                    info!("ws stream ended (manual disconnect)");
                                } else {
                                    info!("ws stream ended");
                                }
                                {
                                    *state.write().await = ConnectionState::Disconnected;
                                }
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
                            break;
                        }
                    }
                }
            }
        });
    }

    #[tracing::instrument(level = "info", skip(self, data), fields(req_identifier = req_identifier))]
    pub async fn send_rpc<T: prost::Message, R: prost::Message + Default>(&self, req_identifier: i32, data: &T) -> Result<R> {
        let data_bytes = data.encode_to_vec();

        let msg_incr = format!("rpc_{}", self.msg_incr.fetch_add(1, Ordering::SeqCst));
        let token = self.token.read().await.clone();
        let send_id = self.send_id.read().await.clone();
        let trace_id = extract_trace_id();
        let operation_id = if trace_id.is_empty() {
            format!("op_{}_{}", req_identifier, msg_incr)
        } else {
            trace_id
        };

        tracing::Span::current().record("operationID", &operation_id);

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

        let req_json = serde_json::to_string(&req).map_err(|e| SdkError::unknown(format!("serialize rpc request: {}", e)))?;

        // Gzip 压缩（对齐 Go SDK compressor.go CompressWithPool）
        let compressed = self.compressor.compress(req_json.as_bytes()).map_err(|e| SdkError::unknown(format!("compress rpc request: {}", e)))?;

        let send_result = {
            let mut w = self.writer.write().await;
            if let Some(writer) = w.as_mut() {
                writer.send(WsMessage::Binary(compressed)).await.map_err(|e| SdkError::connection(format!("send failed: {}", e)))
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
                    R::decode(resp.data.as_slice()).map_err(|e| SdkError::unknown(format!("decode response: {}", e)))
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
        self.send(ConnectionEvent::Disconnected("manual disconnect".into()));
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
        let manager = ConnectionManager::new(cancel_token);

        assert_eq!(manager.get_state().await, ConnectionState::Disconnected);
    }

    #[tokio::test]
    async fn test_connection_state_transitions() {
        let event_bus = Arc::new(EventBus::new());
        let cancel_token = CancellationToken::new();
        let manager = ConnectionManager::new(cancel_token);

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
        let manager = ConnectionManager::new(cancel_token);

        assert!(!manager.is_connected().await);

        manager.set_state(ConnectionState::Connected).await;
        assert!(manager.is_connected().await);
    }
}
