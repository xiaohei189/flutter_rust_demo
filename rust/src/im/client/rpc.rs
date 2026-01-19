//! WebSocket RPC 核心模块
//!
//! 提供核心的 WebSocket RPC 交互逻辑，包括请求发送、响应处理和超时管理

use std::time::{Duration, Instant};

use crate::im::client::client::PendingRpc;
use crate::im::model::OpenIMReq;
use crate::im::model::OpenIMResp;
use crate::im::serialization::compress_gzip;
use crate::OpenIMClient;
use anyhow::Result;
use openim_protocol::prost;
use openim_protocol::Message;
use tokio::sync::oneshot;
use tokio::time::timeout;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tracing::debug;
use uuid::Uuid;

impl OpenIMClient {
    /// 核心方法：发送请求并等待响应
    ///
    /// 这是 WebSocket RPC 的核心方法，负责：
    /// 1. 创建请求并分配唯一 ID
    /// 2. 注册 pending 请求
    /// 3. 通过 WebSocket 发送请求
    /// 4. 等待响应或超时
    /// 5. 清理 pending 请求
    pub async fn send_request_and_wait(&self, req_identifier: i32, data: Vec<u8>, timeout_duration: Option<Duration>) -> Result<OpenIMResp> {
        // 仅支持有回执的 reqIdentifier，其它类型直接返回错误
        match req_identifier {
            crate::im::model::msg_type::WS_GET_NEWEST_SEQ
            | crate::im::model::msg_type::WS_PULL_MSG_BY_RANGE
            | crate::im::model::msg_type::WS_PULL_MSG_BY_SEQ_LIST
            | crate::im::model::msg_type::WS_SEND_MSG
            | crate::im::model::msg_type::WS_SEND_MSG_NOT_OSS => {}
            other => return Err(anyhow::anyhow!("reqIdentifier={} 不支持等待回执，使用 send_raw_req 发送", other)),
        }
        let req: OpenIMReq = self.make_req(req_identifier, data);

        let req_id = req.msg_incr.clone();
        debug!(req_id = req_id, req_identifier = req_identifier, "ws_rpc request sent");

        let (tx, rx) = oneshot::channel();
        let sent_at = Instant::now();
        {
            let mut pending = self.pending_rpc.lock().await;
            pending.insert(req_id.clone(), PendingRpc { tx, sent_at });
        }

        if let Err(e) = self.send_raw_req(req) {
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

    /// 发送 RPC 请求并等待响应，m 为 Protobuf 消息体
    /// 返回解包后的 OpenIMResp
    pub async fn send_req_wait_resp<M: prost::Message>(&self, m: &M, req_identifier: i32) -> Result<OpenIMResp> {
        // 1. 尝试序列化 Protobuf
        let data = match prost::Message::encode_to_vec(m) {
            v if !v.is_empty() => v,
            _ => return Err(anyhow::anyhow!("SendReqWaitResp: Protobuf marshal失败")),
        };

        // 2. 创建 OpenIMReq
        let req = self.make_req(req_identifier, data);

        tracing::debug!("send message to send channel success, req_identifier={req_identifier}, msg_incr={}", req.msg_incr);

        // 3. 发送请求并等待响应
        let resp = self.send_request_and_wait(req_identifier, req.data.clone(), None).await?;

        // 4. 返回响应（如需解反序列化可在调用方进行）
        Ok(resp)
    }

    /// 发送裸请求（无等待），调用方需自行管理 pending
    pub(crate) fn send_raw_req(&self, req: OpenIMReq) -> Result<()> {
        let json = serde_json::to_vec(&req)?;
        let compressed = compress_gzip(&json)?;

        // 通过消息通道发送（非阻塞）
        // 使用阻塞方式获取 tx（因为 send 是同步的）
        let tx = {
            let guard = self.ws_message_tx.blocking_lock();
            guard.clone()
        };

        if let Some(tx) = tx {
            // 使用 try_send 做非阻塞发送；若通道关闭或队列已满，返回错误
            tx.try_send(WsMessage::Binary(compressed)).map_err(|_| anyhow::anyhow!("WebSocket 消息通道已关闭或队列已满"))?;
            Ok(())
        } else {
            Err(anyhow::anyhow!("WebSocket 未连接"))
        }
    }

    /// 创建 WebSocket 请求对象
    pub(crate) fn make_req(&self, req_identifier: i32, data: Vec<u8>) -> OpenIMReq {
        OpenIMReq {
            req_identifier,
            token: self.config.token.clone(),
            send_id: self.config.user_id.clone(),
            operation_id: OpenIMClient::make_operation_id(),
            msg_incr: self.make_msg_incr(),
            data,
        }
    }

    /// 生成操作 ID（时间戳）
    pub fn make_operation_id() -> String {
        format!("{}", chrono::Utc::now().timestamp_millis())
    }

    /// 生成消息递增 ID（UUID）
    pub(crate) fn make_msg_incr(&self) -> String {
        Uuid::new_v4().to_string()
    }

    /// 处理 RPC 响应（从 WebSocket 消息处理器调用）
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
