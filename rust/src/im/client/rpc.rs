//! WebSocket RPC 核心模块
//!
//! 提供核心的 WebSocket RPC 交互逻辑，包括请求发送、响应处理和超时管理

use crate::im::client::client::PendingRpc;
use crate::im::model::OpenIMReq;
use crate::im::model::OpenIMResp;
use crate::im::serialization::compress_gzip;
use crate::OpenIMClient;
use anyhow::Result;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tracing::debug;
use uuid::Uuid;

impl OpenIMClient {
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
