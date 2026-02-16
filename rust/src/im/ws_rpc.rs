//! WebSocket RPC 公共工具：发送请求并等待响应、解析响应体

use crate::im::model::ws::{OpenIMReq, OpenIMResp, WsRpcEnvelope};
use anyhow::{anyhow, Result};
use openim_protocol::prost::Message;
use tokio::sync::{mpsc, oneshot};
use tokio::time::{timeout, Duration};

/// 通过 WS 发送 OpenIMReq 并等待 OpenIMResp（带超时）
pub async fn send_ws_req_wait(
    tx: &mpsc::UnboundedSender<WsRpcEnvelope>,
    req: OpenIMReq,
    timeout_dur: Duration,
) -> Result<OpenIMResp> {
    let (resp_tx, resp_rx) = oneshot::channel();
    tx.send((req, Some(resp_tx))).map_err(|_| anyhow!("ws rpc channel closed"))?;
    match timeout(timeout_dur, resp_rx).await {
        Ok(Ok(resp)) => Ok(resp),
        Ok(Err(e)) => Err(anyhow!("ws response channel dropped: {:?}", e)),
        Err(_) => Err(anyhow!("ws rpc timeout")),
    }
}

/// 从 OpenIMResp 解析业务错误并解码 protobuf 体
pub fn decode_ws_resp<T: Message + Default>(resp: &OpenIMResp) -> Result<T> {
    if resp.err_code != 0 {
        return Err(anyhow!("ws rpc err code={}, msg={}", resp.err_code, resp.err_msg));
    }
    T::decode(resp.data.as_slice()).map_err(|e| anyhow!("decode ws resp: {}", e))
}
