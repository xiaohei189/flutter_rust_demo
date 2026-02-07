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
   


    /// 生成操作 ID（时间戳）
    pub fn make_operation_id() -> String {
        format!("{}", chrono::Utc::now().timestamp_millis())
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
