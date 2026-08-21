//! WebSocket RPC 请求发送
//!
//! 从 manager.rs 提取，职责：发送 RPC 请求、等待响应、超时处理

use crate::connection::manager::ConnectionManager;
use crate::connection::ws::{OpenIMReq, OpenIMResp};
use crate::domain::constant::req_identifier_name;
use crate::domain::error::{Result, SdkError};
use crate::logger::{encode_operation_id, extract_span_id, extract_trace_id};
use futures_util::SinkExt;
use std::time::{Duration, Instant};
use tokio::time::timeout;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tracing::{error, trace, warn};

const RPC_TIMEOUT: Duration = Duration::from_secs(30);

impl ConnectionManager {
    /// 发送 RPC 请求并等待响应
    #[tracing::instrument(level = "trace", skip(self, data))]
    pub async fn send_rpc<T, R>(&self, req_identifier: i32, data: &T) -> Result<R>
    where
        T: prost::Message + std::fmt::Debug,
        R: prost::Message + Default + std::fmt::Debug,
    {
        let start = Instant::now();
        let data_bytes = data.encode_to_vec();
        let req_name = req_identifier_name(req_identifier);
        let msg_incr = format!("rpc_{}", self.msg_incr.fetch_add(1, std::sync::atomic::Ordering::SeqCst));
        let token = self.token.read().await.clone();
        let send_id = self.send_id.read().await.clone();
        let trace_id = extract_trace_id();
        let span_id = extract_span_id();
        let operation_id = encode_operation_id(&trace_id, span_id);
        let operation_id = if operation_id.is_empty() { format!("op_{}_{}", req_identifier, msg_incr) } else { operation_id };

        tracing::Span::current().record("operationID", &operation_id);

        trace!(
            req_identifier,
            req_name = %req_name,
            msg_incr = %msg_incr,
            operation_id = %operation_id,
            payload_len = data_bytes.len(),
            "ws rpc request"
        );

        let req = OpenIMReq {
            req_identifier,
            token,
            send_id,
            operation_id: operation_id.clone(),
            msg_incr: msg_incr.clone(),
            data: data_bytes,
        };

        let req_json = serde_json::to_string(&req).map_err(|e| {
            error!(req_name = %req_name, msg_incr = %msg_incr, error = %e, "ws rpc serialize failed");
            SdkError::unknown(format!("serialize rpc request: {}", e))
        })?;

        let (tx, rx) = tokio::sync::oneshot::channel();
        self.pending_requests.write().await.insert(msg_incr.clone(), crate::connection::manager::PendingRequest { tx });

        let compressed = self.compressor.compress(req_json.as_bytes()).map_err(|e| {
            error!(req_name = %req_name, msg_incr = %msg_incr, error = %e, "ws rpc compress failed");
            SdkError::unknown(format!("compress rpc request: {}", e))
        })?;

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
            error!(
                req_name = %req_name,
                msg_incr = %msg_incr,
                elapsed_ms = start.elapsed().as_millis() as u64,
                error = %e,
                "ws rpc send failed"
            );
            return Err(e);
        }

        match timeout(RPC_TIMEOUT, rx).await {
            Ok(Ok(resp)) => decode_rpc_response::<R>(resp).await,
            Ok(Err(_)) => {
                warn!(
                    req_name = %req_name,
                    msg_incr = %msg_incr,
                    elapsed_ms = start.elapsed().as_millis() as u64,
                    "ws rpc channel closed"
                );
                Err(SdkError::connection("rpc channel closed"))
            }
            Err(_) => {
                // 超时后清理 pending 条目，避免请求表无限增长
                self.pending_requests.write().await.remove(&msg_incr);
                warn!(
                    req_name = %req_name,
                    msg_incr = %msg_incr,
                    elapsed_ms = RPC_TIMEOUT.as_millis() as u64,
                    "ws rpc timeout"
                );
                Err(SdkError::timeout("rpc timeout"))
            }
        }
    }
}

/// 将 WS RPC 响应解码为业务响应；成功码之外统一返回 SdkError::api。
async fn decode_rpc_response<R>(resp: OpenIMResp) -> Result<R>
where
    R: prost::Message + Default + std::fmt::Debug,
{
    if resp.is_success() {
        match R::decode(resp.data.as_slice()) {
            Ok(r) => Ok(r),
            Err(e) => Err(SdkError::unknown(format!("decode response: {}", e))),
        }
    } else {
        Err(SdkError::api(resp.err_code, &resp.err_msg))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use openim_protocol::sdkws::UserSendMsgResp;
    use prost::Message as _;

    fn resp_with(data: Vec<u8>, err_code: i32, err_msg: &str, msg_incr: &str) -> OpenIMResp {
        OpenIMResp {
            req_identifier: 1003,
            msg_incr: msg_incr.to_string(),
            operation_id: String::new(),
            err_code,
            err_msg: err_msg.to_string(),
            data,
        }
    }

    #[tokio::test]
    async fn test_decode_rpc_response_success() {
        let payload = UserSendMsgResp {
            server_msg_id: "srv_1".to_string(),
            client_msg_id: "cli_1".to_string(),
            send_time: 123,
        };
        let decoded: UserSendMsgResp = decode_rpc_response(resp_with(payload.encode_to_vec(), 0, "", "rpc_1")).await.unwrap();

        assert_eq!(decoded.server_msg_id, "srv_1");
        assert_eq!(decoded.client_msg_id, "cli_1");
        assert_eq!(decoded.send_time, 123);
    }

    #[tokio::test]
    async fn test_decode_rpc_response_business_error() {
        let err = decode_rpc_response::<UserSendMsgResp>(resp_with(vec![], 1506, "token kicked", "rpc_1")).await.unwrap_err();

        match err {
            SdkError::ApiError { code, message } => {
                assert_eq!(code, 1506);
                assert_eq!(message, "token kicked");
            }
            other => panic!("expected ApiError, got: {:?}", other),
        }
    }

    #[tokio::test]
    async fn test_decode_rpc_response_invalid_payload() {
        let err = decode_rpc_response::<UserSendMsgResp>(resp_with(b"not a protobuf".to_vec(), 0, "", "rpc_1")).await.unwrap_err();

        assert!(err.to_string().contains("decode response"));
    }
}
