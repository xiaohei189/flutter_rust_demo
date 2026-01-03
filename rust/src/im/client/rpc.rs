use std::time::{Duration, Instant};

use crate::im::client::client::PendingRpc;
use crate::im::model::OpenIMReq;
use crate::im::model::OpenIMResp;
use crate::im::serialization::compress_gzip;
use crate::OpenIMClient;
use anyhow::Result;
use futures_util::SinkExt;
use openim_protocol::Message as ProtobufMessage;
use tokio::sync::oneshot;
use tokio::time::timeout;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tracing::debug;
use uuid::Uuid;

// 通过ws调用protobuf请求，通用方法
impl OpenIMClient {
   
    pub async fn send_request_and_wait(
        &self,
        req_identifier: i32,
        data: Vec<u8>,
        timeout_duration: Option<Duration>,
    ) -> Result<OpenIMResp> {
        // 仅支持有回执的 reqIdentifier，其它类型直接返回错误
        match req_identifier {
            crate::im::model::msg_type::WS_GET_NEWEST_SEQ
            | crate::im::model::msg_type::WS_PULL_MSG_BY_RANGE
            | crate::im::model::msg_type::WS_PULL_MSG_BY_SEQ_LIST
            | crate::im::model::msg_type::WS_SEND_MSG
            | crate::im::model::msg_type::WS_SEND_MSG_NOT_OSS => {}
            other => {
                return Err(anyhow::anyhow!(
                    "reqIdentifier={} 不支持等待回执，使用 send_raw_req 发送",
                    other
                ))
            }
        }
        let req: OpenIMReq = self.make_req(req_identifier, data);

        let req_id = req.msg_incr.clone();
        debug!(
            req_id = req_id,
            req_identifier = req_identifier,
            "ws_rpc request sent"
        );

        let (tx, rx) = oneshot::channel();
        let sent_at = Instant::now();
        {
            let mut pending = self.pending_rpc.lock().await;
            pending.insert(req_id.clone(), PendingRpc { tx, sent_at });
        }

        if let Err(e) = self.send_raw_req(req).await {
            let mut pending = self.pending_rpc.lock().await;
            pending.remove(&req_id);
            return Err(e);
        }

        let timeout_duration = timeout_duration.unwrap_or(self.config.msg_resp_timeout);
        // 等待回执：超时或通道关闭时清理 pending，避免残留
        match timeout(timeout_duration, rx).await {
            Ok(Ok(resp)) => Ok(resp),
            Ok(Err(e)) => {
                let mut pending = self.pending_rpc.lock().await;
                pending.remove(&req_id);
                Err(anyhow::anyhow!("ws rpc 通道已关闭: {e}"))
            }
            Err(e_timeout) => {
                let mut pending = self.pending_rpc.lock().await;
                pending.remove(&req_id);
                Err(anyhow::anyhow!("ws rpc 超时: {e_timeout}"))
            }
        }
    }
    /// 通用：发送 protobuf 请求并解析回执为 protobuf 响应
    pub async fn proto_call_by_ws<Req, Resp>(&self, msg_type: i32, req: Req) -> Result<Resp>
    where
        Req: ProtobufMessage,
        Resp: ProtobufMessage + Default,
    {
        let req_data = req.encode_to_vec();
        let resp = self.send_request_and_wait(msg_type, req_data, None).await?;
        let resp_data = resp.data;
        let decoded = Resp::decode(resp_data.as_slice())?;
        Ok(decoded)
    }
    /// 发送裸请求（无等待），调用方需自行管理 pending
    async fn send_raw_req(&self, req: OpenIMReq) -> Result<()> {
        let json = serde_json::to_vec(&req)?;
        let compressed = compress_gzip(&json)?;
        let mut guard = self.writer.lock().await;
        let writer = guard.as_mut().ok_or_else(|| anyhow::anyhow!("未连接"))?;
        writer.send(WsMessage::Binary(compressed)).await?;
        Ok(())
    }

    fn make_req(&self, req_identifier: i32, data: Vec<u8>) -> OpenIMReq {
        OpenIMReq {
            req_identifier,
            token: self.config.token.clone(),
            send_id: self.config.user_id.clone(),
            operation_id: self.make_operation_id(),
            msg_incr: self.make_msg_incr(),
            data,
        }
    }

    pub fn make_operation_id(&self) -> String {
        format!("{}", chrono::Utc::now().timestamp_millis())
    }
    fn make_msg_incr(&self) -> String {
        Uuid::new_v4().to_string()
    }
    pub async fn handle_rpc_response(&self, resp: OpenIMResp) -> Result<()> {
        let mut pending = self.pending_rpc.lock().await;
        if let Some(pending_rpc) = pending.remove(&resp.msg_incr) {
            let elapsed = pending_rpc.sent_at.elapsed();
            debug!(
                req_id = resp.msg_incr,
                req_identifier = resp.req_identifier,
                elapsed_ms = elapsed.as_millis(),
                "ws_rpc response received"
            );
            let _ = pending_rpc.tx.send(resp);
        };

        Ok(())
    }
}
