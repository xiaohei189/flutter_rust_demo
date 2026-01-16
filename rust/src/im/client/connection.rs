use anyhow::Result;
use futures_util::future::select_all;
use futures_util::stream::{SplitSink, SplitStream};
use futures_util::StreamExt;
use tokio::net::TcpStream;
use tokio::sync::mpsc::Receiver;
use tokio::time::{interval, Duration};
use tokio_tungstenite::{
    connect_async, tungstenite::Message as WsMessage, MaybeTlsStream, WebSocketStream,
};
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info, warn};

use super::OpenIMClient;
use crate::im::client::client::{WsReader, WsWriter};
use crate::im::message::binary_handler::BinaryMessageHandler;
use crate::im::model::ws::{AppState, CommandMessage};
use crate::im::model::WebSocketConnectResp;

impl OpenIMClient {
    pub(crate) async fn connect_ws_once_v2(
        &self,
        tx: tokio::sync::mpsc::Sender<CommandMessage>,
        mut rx: Receiver<CommandMessage>,
    ) -> Result<()> {
        let operation_id = self.make_operation_id();
        let url = self.build_url(&operation_id);
        debug!("[Client] 🔗 WebSocket 连接 URL: {}", url);
        let (ws_stream, response) = connect_async(&url).await?;
        info!(
            "[Client] ✅ WebSocket 连接成功, 状态: {}",
            response.status()
        );
        let (mut writer, mut read) = ws_stream.split();

        if let Some(Ok(WsMessage::Text(text))) = read.next().await {
            debug!("[Client] 📥 WebSocket 连接响应: {}", text);
            match serde_json::from_str::<WebSocketConnectResp>(&text) {
                Ok(resp) => {
                    if resp.err_code == 0 {
                        info!("[Client] ✅ 服务器连接鉴权成功");
                        let listener = self.advanced_msg_listener.clone();
                        tokio::spawn(async move {
                            if let Some(listener) = &listener {
                                listener
                                    .on_connection_status_changed(true, "连接成功".to_string())
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
                                listener
                                    .on_connection_status_changed(false, msg_for_cb)
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

        // 创建统一的取消令牌，用于协调所有任务的退出
        let cancel_token = CancellationToken::new();

        // 发送任务：从通道接收消息并写入 socket
        let send_task = self.send_task_with_cancel(cancel_token.clone(), writer, rx);
        // 接收任务：从 socket 读取消息并处理
        let recv_task = self.recv_task_with_cancel(cancel_token.clone(), read);
        // 心跳任务：定期通过 tx 发送 Ping 消息
        let heartbeat_task = self.heartbeat_task_with_cancel(tx.clone(), cancel_token.clone());

        //             // 重连后触发一次会话增量同步，确保会话名/头像/未读等被服务端数据覆盖
        //             if let Some(syncer) = client.conversation_syncer.clone() {
        //                 tokio::spawn(async move {
        //                     info!("[Client] 🔄 重连后触发会话增量同步");
        //                     if let Err(e) = syncer.incr_sync_conversations().await {
        //                         error!("[Client] ❌ 会话增量同步失败: {e}");
        //                     }
        //                 });
        //             }
        // 使用 select_all 等待三个任务，任何一个退出时取消所有任务
        let tasks = vec![send_task, recv_task, heartbeat_task];
        let (result, index, remaining) = select_all(tasks).await;

        // 取消所有任务（通过 cancel_token）
        debug!(
            "[Client] 任务 {} 退出，取消所有任务",
            match index {
                0 => "发送",
                1 => "接收",
                2 => "心跳",
                _ => "未知",
            }
        );
        cancel_token.cancel();

        // 等待所有任务完成清理
        for task in remaining {
            let _ = task.await;
        }
        let _ = result;

        Ok(())
    }
    fn recv_task_with_cancel(
        &self,
        recv_cancel_token: CancellationToken,
        mut read: SplitStream<WebSocketStream<MaybeTlsStream<TcpStream>>>,
    ) -> tokio::task::JoinHandle<()> {
        tokio::spawn(async move {
            loop {
                tokio::select! {
                    // 检查取消信号
                    _ = recv_cancel_token.cancelled() => {
                        debug!("[Client] 接收任务收到取消信号，退出循环");

                        break;
                    }
                    // 接收消息
                    msg_result_opt = read.next() => {
                        match msg_result_opt {
                            Some(msg_result) => {
                                match msg_result {
                                    Ok(WsMessage::Text(text)) => {
                                        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text) {
                                            if let Some(req_id) = json.get("reqIdentifier") {
                                                debug!("[Client] 文本响应: reqId={}", req_id);
                                            }
                                        }
                                    }
                                    Ok(WsMessage::Binary(data)) => {
                                        // 临时占位：创建空的 BinaryMessageHandlerCallbacks（重构中）
                                        let app_state = AppState::default();
                                        if let Err(e) = BinaryMessageHandler::handle_binary_message_v2(
                                            app_state,
                                            data,
                                        )
                                        .await
                                        {
                                            error!("[Client] handle_binary_message 处理二进制消息失败: {}", e);
                                        }
                                    }
                                    Ok(WsMessage::Ping(_)) | Ok(WsMessage::Pong(_)) => {}
                                    Ok(WsMessage::Close(frame)) => {
                                        warn!("[Client] 👋 连接关闭: {:?}", frame);
                                        break;
                                    }
                                    Err(e) => {
                                        error!("[Client] WebSocket 错误: {}", e);
                                        break;
                                    }
                                    _ => {}
                                }
                            }
                            None => {
                                debug!("[Client] WebSocket 流结束");
                                break;
                            }
                        }
                    }
                }
            }
            debug!("[Client] ws消息接收循环退出");
        })
    }
    fn send_task_with_cancel(
        &self,
        send_cancel_token: CancellationToken,
        mut writer: WsWriter,
        mut rx: Receiver<CommandMessage>,
    ) -> tokio::task::JoinHandle<()> {
        tokio::spawn(async move {
            use futures_util::SinkExt;
            loop {
                tokio::select! {
                    // 检查取消信号
                    _ = send_cancel_token.cancelled() => {
                        debug!("[Client] 发送任务收到取消信号，退出循环");
                        break;
                    }
                    // 接收消息
                    msg_opt = rx.recv() => {
                        match msg_opt {
                            Some(msg) => {
                                match msg {
                                    CommandMessage::Text(text) => {
                                        if let Err(e) = writer.send(WsMessage::Text(text)).await {
                                            error!("[Client] ws消息发送失败: {}", e);
                                            break;
                                        }
                                    }
                                    CommandMessage::Binary(data) => {
                                        if let Err(e) = writer.send(WsMessage::Binary(data)).await {
                                            error!("[Client] ws消息发送失败: {}", e);
                                            break;
                                        }
                                    }
                                    CommandMessage::Ping => {
                                        if let Err(e) = writer.send(WsMessage::Ping(vec![])).await {
                                            error!("[Client] ws心跳发送失败: {}", e);
                                            break;
                                        }
                                    }
                                    CommandMessage::Disconnect(_reason) => {
                                        // 断开连接请求，退出发送循环
                                        debug!("[Client] 收到断开连接请求");
                                        break;
                                    }
                                }
                            }
                            None => {
                                debug!("[Client] ws消息mpsc通道已关闭，发送任务退出");
                                break;
                            }
                        }
                    }
                }
            }
            debug!("[Client] ws消息发送循环退出");
        })
    }
    fn heartbeat_task_with_cancel(
        &self,
        tx: tokio::sync::mpsc::Sender<CommandMessage>,
        cancel_token: CancellationToken,
    ) -> tokio::task::JoinHandle<()> {
        tokio::spawn(async move {
            let mut ticker = interval(Duration::from_secs(25));
            loop {
                tokio::select! {
                    // 检查取消信号
                    _ = cancel_token.cancelled() => {
                        debug!("[Client] 💓 心跳任务收到取消信号，退出循环");
                        break;
                    }
                    // 发送心跳
                    _ = ticker.tick() => {
                        if let Err(e) = tx.send(CommandMessage::Ping).await {
                            error!("[Client] 💓 心跳任务：消息通道发送失败: {}", e);
                            break;
                        }
                    }
                }
            }
            debug!("[Client] 💓 心跳任务退出");
        })
    }
}
