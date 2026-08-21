//! WebSocket 连接握手与认证
//!
//! 从 manager.rs 提取，职责：建立 WebSocket 连接、完成服务端认证握手

use crate::connection::manager::ConnectionManager;
use crate::connection::ws::{GzipCompressor, WebSocketConnectResp};
use crate::domain::error::{Result, SdkError};
use crate::event::events::connection::ConnectionEvent;
use crate::infra::logger::extract_trace_id;
use futures_util::StreamExt;
use std::time::Duration;
use tokio::time::timeout;
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tokio_util::sync::CancellationToken;
use tracing::{error, info, warn};

impl ConnectionManager {
    /// 执行 WebSocket 连接 + 服务端认证握手
    #[tracing::instrument(level = "info", skip(self))]
    pub(crate) async fn do_connect(&self, conn_token: CancellationToken) -> Result<()> {
        const TOKEN_EXPIRED_ERR_CODE: i32 = 1501;
        const TOKEN_INVALID_ERR_CODES: [i32; 5] = [1502, 1503, 1504, 1505, 1507];
        const TOKEN_KICKED_ERR_CODE: i32 = 1506;

        self.set_state(crate::connection::manager::ConnectionState::Connecting).await;
        self.send(ConnectionEvent::Connecting);

        let ws_url = self.ws_url.read().await.clone();
        let token = self.token.read().await.clone();
        let send_id = self.send_id.read().await.clone();
        let platform_id = *self.platform_id.read().await;
        let trace_id = extract_trace_id();
        let operation_id = if trace_id.is_empty() {
            format!("conn_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())
        } else {
            trace_id
        };

        let full_url = format!(
            "{}/?token={}&sendID={}&platformID={}&operationID={}&isBackground=false&isMsgResp=true&sdkType=js&compression=gzip",
            ws_url, token, send_id, platform_id, operation_id
        );

        let (ws_stream, _) = timeout(Duration::from_secs(10), connect_async(&full_url))
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

        let compressor = GzipCompressor::new();
        let auth_result: std::result::Result<WebSocketConnectResp, SdkError> = match read.next().await {
            Some(Ok(WsMessage::Text(text))) => serde_json::from_str::<WebSocketConnectResp>(&text).map_err(|e| SdkError::connection(format!("auth parse error: {}", e))),
            Some(Ok(WsMessage::Binary(data))) => {
                let data = compressor.decompress(&data).unwrap_or(data);
                serde_json::from_slice::<WebSocketConnectResp>(&data).map_err(|e| SdkError::connection(format!("auth parse error: {}", e)))
            }
            Some(Ok(WsMessage::Close(_))) => Err(SdkError::connection("server closed during auth")),
            Some(Err(e)) => Err(SdkError::connection(format!("ws error during auth: {}", e))),
            None => Err(SdkError::connection("stream ended during auth")),
            _ => Err(SdkError::connection("unexpected message during auth")),
        };

        match auth_result {
            Ok(conn_resp) if conn_resp.err_code == 0 => {
                if conn_token.is_cancelled() {
                    warn!("do_connect: connection attempt cancelled during auth, discarding connection");
                    return Err(SdkError::connection("connection attempt cancelled"));
                }
                info!("WebSocket auth confirmed by server");
                *self.writer.write().await = Some(write);
                self.set_state(crate::connection::manager::ConnectionState::Connected).await;
                self.send(ConnectionEvent::Connected);
                if let Some(hook) = &*self.on_connected_hook.lock().expect("on_connected_hook mutex poisoned") {
                    hook();
                }
                self.reconnect_attempts.store(0, std::sync::atomic::Ordering::SeqCst);
                self.spawn_read_loop(read, conn_token.clone());
                self.spawn_heartbeat_internal(conn_token);
                Ok(())
            }
            Ok(conn_resp) if conn_resp.err_code == TOKEN_KICKED_ERR_CODE => {
                if conn_token.is_cancelled() {
                    return Err(SdkError::connection("connection attempt cancelled"));
                }
                warn!("TokenKickedError ({}): kicked by other device, stopping reconnect", conn_resp.err_code);
                conn_token.cancel();
                *self.is_manual_disconnect.write().await = true;
                *self.state.write().await = crate::connection::manager::ConnectionState::Kicked;
                self.message_batcher.close().await;
                self.send(ConnectionEvent::KickedOffline(conn_resp.err_msg.to_string()));
                Err(SdkError::api(conn_resp.err_code, &conn_resp.err_msg))
            }
            Ok(conn_resp) if conn_resp.err_code == TOKEN_EXPIRED_ERR_CODE => {
                if conn_token.is_cancelled() {
                    return Err(SdkError::connection("connection attempt cancelled"));
                }
                warn!("TokenExpiredError ({}): token expired, stopping reconnect", conn_resp.err_code);
                conn_token.cancel();
                *self.is_manual_disconnect.write().await = true;
                *self.state.write().await = crate::connection::manager::ConnectionState::Kicked;
                self.message_batcher.close().await;
                self.send(ConnectionEvent::TokenExpired);
                Err(SdkError::api(conn_resp.err_code, &conn_resp.err_msg))
            }
            Ok(conn_resp) if TOKEN_INVALID_ERR_CODES.contains(&conn_resp.err_code) => {
                if conn_token.is_cancelled() {
                    return Err(SdkError::connection("connection attempt cancelled"));
                }
                warn!("TokenInvalidError ({}): token invalid, stopping reconnect", conn_resp.err_code);
                conn_token.cancel();
                *self.is_manual_disconnect.write().await = true;
                *self.state.write().await = crate::connection::manager::ConnectionState::Kicked;
                self.message_batcher.close().await;
                self.send(ConnectionEvent::TokenInvalid { error: conn_resp.err_msg.to_string() });
                Err(SdkError::api(conn_resp.err_code, &conn_resp.err_msg))
            }
            Ok(conn_resp) => {
                if conn_token.is_cancelled() {
                    return Err(SdkError::connection("connection attempt cancelled"));
                }
                warn!("WebSocket auth failed: errCode={}, errMsg={}", conn_resp.err_code, conn_resp.err_msg);
                *self.state.write().await = crate::connection::manager::ConnectionState::Disconnected;
                self.send(ConnectionEvent::ConnectFailed {
                    err_code: conn_resp.err_code,
                    error: conn_resp.err_msg.to_string(),
                });
                Err(SdkError::api(conn_resp.err_code, &conn_resp.err_msg))
            }
            Err(e) => {
                if conn_token.is_cancelled() {
                    return Err(SdkError::connection("connection attempt cancelled"));
                }
                error!("WebSocket auth parse error: {:?}", e);
                *self.state.write().await = crate::connection::manager::ConnectionState::Disconnected;
                self.send(ConnectionEvent::ConnectFailed {
                    // 对齐 Go sdkerrs.NetworkError = 10000
                    err_code: 10000,
                    error: format!("auth parse error: {}", e),
                });
                Err(e)
            }
        }
    }
}
