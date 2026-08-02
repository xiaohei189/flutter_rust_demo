//! WebSocket 连接握手与认证
//!
//! 从 manager.rs 提取，职责：建立 WebSocket 连接、完成服务端认证握手

use crate::core::connection::manager::ConnectionManager;
use crate::core::connection::ws::{GzipCompressor, WebSocketConnectResp};
use crate::domain::error::{Result, SdkError};
use crate::event::events::connection::ConnectionEvent;
use crate::infra::logger::extract_trace_id;
use futures_util::StreamExt;
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::time::timeout;
use tokio_tungstenite::{connect_async, MaybeTlsStream, WebSocketStream};
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tracing::{info, error, warn};

impl ConnectionManager {
    /// 执行 WebSocket 连接 + 服务端认证握手
    #[tracing::instrument(level = "info", skip(self))]
    pub(crate) async fn do_connect(&self) -> Result<()> {
        const TOKEN_KICKED_ERR_CODE: i32 = 1506;
        const TOKEN_NOT_EXIST_ERR_CODE: i32 = 1507;

        self.set_state(crate::core::connection::manager::ConnectionState::Connecting).await;
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
            Some(Ok(WsMessage::Text(text))) => serde_json::from_str::<WebSocketConnectResp>(&text)
                .map_err(|e| SdkError::connection(format!("auth parse error: {}", e))),
            Some(Ok(WsMessage::Binary(data))) => {
                let data = compressor.decompress(&data).unwrap_or(data);
                serde_json::from_slice::<WebSocketConnectResp>(&data)
                    .map_err(|e| SdkError::connection(format!("auth parse error: {}", e)))
            }
            Some(Ok(WsMessage::Close(_))) => Err(SdkError::connection("server closed during auth")),
            Some(Err(e)) => Err(SdkError::connection(format!("ws error during auth: {}", e))),
            None => Err(SdkError::connection("stream ended during auth")),
            _ => Err(SdkError::connection("unexpected message during auth")),
        };

        match auth_result {
            Ok(conn_resp) if conn_resp.err_code == 0 => {
                info!("WebSocket auth confirmed by server");
                *self.writer.write().await = Some(write);
                self.set_state(crate::core::connection::manager::ConnectionState::Connected).await;
                self.send(ConnectionEvent::Connected);
                if let Some(hook) = &*self.on_connected_hook.lock().expect("on_connected_hook mutex poisoned") {
                    hook();
                }
                self.reconnect_attempts.store(0, std::sync::atomic::Ordering::SeqCst);
                self.spawn_read_loop(read);
                self.spawn_heartbeat_internal();
                Ok(())
            }
            Ok(conn_resp) if conn_resp.err_code == TOKEN_KICKED_ERR_CODE => {
                warn!("TokenKickedError ({}): kicked by other device, stopping reconnect", conn_resp.err_code);
                self.cancel_token.cancel();
                *self.is_manual_disconnect.write().await = true;
                *self.state.write().await = crate::core::connection::manager::ConnectionState::Kicked;
                self.message_batcher.close().await;
                self.send(ConnectionEvent::KickedOffline(conn_resp.err_msg.to_string()));
                Err(SdkError::api(conn_resp.err_code, &conn_resp.err_msg))
            }
            Ok(conn_resp) if conn_resp.err_code == TOKEN_NOT_EXIST_ERR_CODE => {
                warn!("TokenNotExistError ({}): token invalid or expired, stopping reconnect", conn_resp.err_code);
                self.cancel_token.cancel();
                *self.is_manual_disconnect.write().await = true;
                *self.state.write().await = crate::core::connection::manager::ConnectionState::Kicked;
                self.message_batcher.close().await;
                self.send(ConnectionEvent::TokenExpired);
                Err(SdkError::api(conn_resp.err_code, &conn_resp.err_msg))
            }
            Ok(conn_resp) => {
                warn!("WebSocket auth failed: errCode={}, errMsg={}", conn_resp.err_code, conn_resp.err_msg);
                *self.state.write().await = crate::core::connection::manager::ConnectionState::Disconnected;
                self.send(ConnectionEvent::Disconnected(conn_resp.err_msg.to_string()));
                Err(SdkError::api(conn_resp.err_code, &conn_resp.err_msg))
            }
            Err(e) => {
                error!("WebSocket auth parse error: {:?}", e);
                *self.state.write().await = crate::core::connection::manager::ConnectionState::Disconnected;
                self.send(ConnectionEvent::Disconnected(format!("auth parse error: {}", e)));
                Err(e)
            }
        }
    }
}
