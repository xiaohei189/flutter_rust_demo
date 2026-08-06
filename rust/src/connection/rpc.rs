//! WebSocket RPC 请求发送
//!
//! 从 manager.rs 提取，职责：发送 RPC 请求、等待响应、超时处理

use crate::connection::manager::ConnectionManager;
use crate::connection::ws::OpenIMReq;
use crate::constant::req_identifier_name;
use crate::error::{Result, SdkError};
use crate::logger::{encode_operation_id, extract_span_id, extract_trace_id};
use futures_util::SinkExt;
use std::time::Duration;
use tokio::time::timeout;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tracing::{debug, info};

const RPC_TIMEOUT: Duration = Duration::from_secs(30);

impl ConnectionManager {
    /// 发送 RPC 请求并等待响应
    #[tracing::instrument(level = "info", skip(self, data))]
    pub async fn send_rpc<T, R>(&self, req_identifier: i32, data: &T) -> Result<R>
    where
        T: prost::Message + std::fmt::Debug,
        R: prost::Message + Default + std::fmt::Debug,
    {
        let data_bytes = data.encode_to_vec();
        let msg_incr = format!("rpc_{}", self.msg_incr.fetch_add(1, std::sync::atomic::Ordering::SeqCst));
        let token = self.token.read().await.clone();
        let send_id = self.send_id.read().await.clone();
        let trace_id = extract_trace_id();
        let span_id = extract_span_id();
        let operation_id = encode_operation_id(&trace_id, span_id);
        let operation_id = if operation_id.is_empty() { format!("op_{}_{}", req_identifier, msg_incr) } else { operation_id };

        tracing::Span::current().record("operationID", &operation_id);

        debug!(msg_incr = %msg_incr, req_name = req_identifier_name(req_identifier), "ws rpc request");

        let req = OpenIMReq {
            req_identifier,
            token,
            send_id,
            operation_id: operation_id.clone(),
            msg_incr: msg_incr.clone(),
            data: data_bytes,
        };

        let req_json = serde_json::to_string(&req).map_err(|e| SdkError::unknown(format!("serialize rpc request: {}", e)))?;

        let (tx, rx) = tokio::sync::oneshot::channel();
        self.pending_requests.write().await.insert(
            msg_incr.clone(),
            crate::connection::manager::PendingRequest { tx },
        );

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
                    match R::decode(resp.data.as_slice()) {
                        Ok(r) => {
                            debug!(msg_incr = %resp.msg_incr, req_name = req_identifier_name(resp.req_identifier), "ws rpc response ok");
                            Ok(r)
                        }
                        Err(e) => Err(SdkError::unknown(format!("decode response: {}", e))),
                    }
                } else {
                    info!(msg_incr = %resp.msg_incr, req_name = req_identifier_name(resp.req_identifier), err_code = resp.err_code, err_msg = %resp.err_msg, "ws rpc response error");
                    Err(SdkError::api(resp.err_code, &resp.err_msg))
                }
            }
            Ok(Err(_)) => Err(SdkError::connection("rpc channel closed")),
            Err(_) => {
                // 超时后清理 pending 条目，避免请求表无限增长
                self.pending_requests.write().await.remove(&msg_incr);
                Err(SdkError::timeout("rpc timeout"))
            }
        }
    }
}
