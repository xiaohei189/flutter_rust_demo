use anyhow::Result;
use futures_util::{StreamExt, SinkExt};
use tokio::time::{interval, Duration};
use tokio_tungstenite::{connect_async, tungstenite::Message as WsMessage};
use tracing::{debug, error, info};

use super::OpenIMClient;
use crate::im::client::client::WsReader;
use crate::im::model::WebSocketConnectResp;

impl OpenIMClient {
    /// 建立一次 WebSocket 连接并完成鉴权握手（不包含 DB/同步器初始化）
    pub(crate) async fn connect_ws_once(&self) -> Result<WsReader> {
        let operation_id = self.make_operation_id();
        let url = self.build_url(&operation_id);
        debug!("[Client] 🔗 WebSocket 连接 URL: {}", url);
        let (ws_stream, response) = connect_async(&url).await?;
        info!(
            "[Client] ✅ WebSocket 连接成功, 状态: {}",
            response.status()
        );

        let (write, mut read) = ws_stream.split();

        {
            let mut guard = self.writer.lock().await;
            *guard = Some(write);
        }

        if let Some(Ok(WsMessage::Text(text))) = read.next().await {
            debug!("[Client] 📥 WebSocket 连接响应: {}", text);
            match serde_json::from_str::<WebSocketConnectResp>(&text) {
                Ok(resp) => {
                    if resp.err_code == 0 {
                        info!("[Client] ✅ 服务器连接鉴权成功");
                        let listener = self.advanced_msg_listener.clone();
                        tokio::spawn(async move {
                            if let Some(listener) = &listener {
                                listener.on_connection_status_changed(true, "连接成功".to_string())
                                    .await;
                            }
                        });
                    } else {
                        let error_msg = if !resp.err_dlt.is_empty() {
                            format!("{} (详情: {})", resp.err_msg, resp.err_dlt)
                        } else {
                            resp.err_msg.clone()
                        };
                        error!(
                            "[Client] ❌ WebSocket 连接失败，错误码: {}, 错误信息: {}",
                            resp.err_code, error_msg
                        );

                        let listener = self.advanced_msg_listener.clone();
                        let msg_for_cb = format!(
                            "WebSocket 鉴权失败, code={}, msg={}",
                            resp.err_code, error_msg
                        );
                        tokio::spawn(async move {
                            if let Some(listener) = &listener {
                                listener.on_connection_status_changed(false, msg_for_cb)
                                    .await;
                            }
                        });

                        return Err(anyhow::anyhow!(error_msg));
                    }
                }
                Err(e) => {
                    error!(
                        "[Client] ❌ WebSocket 响应解析失败: {}, 原始响应: {}",
                        e, text
                    );
                    return Err(anyhow::anyhow!(
                        "WebSocket 响应解析失败: {}, 原始响应: {}",
                        e,
                        text
                    ));
                }
            }
        } else {
            error!("[Client] ❌ 未收到 WebSocket 连接响应");
            return Err(anyhow::anyhow!("未收到 WebSocket 连接响应"));
        }

        Ok(read)
    }

    pub(crate) fn spawn_heartbeat(&self) {
        let writer_for_heartbeat = self.writer.clone();
        tokio::spawn(async move {
            let mut ticker = interval(Duration::from_secs(25));
            loop {
                ticker.tick().await;
                let mut guard = writer_for_heartbeat.lock().await;
                if let Some(w) = guard.as_mut() {
                    if w.send(WsMessage::Ping(vec![])).await.is_err() {
                        break;
                    }
                } else {
                    break;
                }
            }
        });
    }
}

