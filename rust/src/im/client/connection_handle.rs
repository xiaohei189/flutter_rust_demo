//! OpenIM 客户端核心实现模块
//!
//! 此模块包含 OpenIM 客户端的核心逻辑实现。

use crate::im::client::client::ClientConfig;
use crate::im::client::listeners::{ConnEvent, Listeners};
use crate::im::client::message_handle::{MsgSyncCommand, MsgSyncCommandKind};
use crate::im::client::reconnect::{ConnectFatalError, ReconnectStrategy};
use crate::im::client::FriendSyncer;
use crate::im::dao::MessageRepo;
use crate::im::model::conversation::ConversationSyncerConfig;
use crate::im::model::friend::FriendSyncerConfig;
use crate::im::model::message::{AtElem, AtInfo, CustomElem, FileElem, LocationElem, MarkdownTextElem, MsgStruct, PictureElem, QuoteElem, SeqRange as SeqRangeModel, SoundElem, VideoElem};
use crate::im::model::ws::WsRpcEnvelope;
use crate::im::model::{msg_type, LocalConversation, OpenIMReq, OpenIMResp};
use crate::im::serialization::{compress_gzip, decompress_gzip};
use crate::im::util;
use crate::im::WebSocketConnectResp;
use anyhow::{Context, Result};
use futures_util::future::select_all;
use futures_util::stream::{SplitSink, SplitStream};
use futures_util::StreamExt;
use openim_protocol::Message as ProtobufMessage;
use openim_protocol::{constant, sdkws};
use sqlx::{Pool, Sqlite};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::runtime::Runtime;
use tokio::sync::mpsc::{self, Receiver};
use tokio::sync::{oneshot, Mutex};
use tokio::time::interval;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tokio_tungstenite::WebSocketStream;
use tokio_tungstenite::{connect_async, MaybeTlsStream};
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, event, info, info_span, instrument, span, trace, warn, Level};
use tracing_opentelemetry::OpenTelemetrySpanExt;

/// WebSocket 写入端类型别名
pub type WsWriter = SplitSink<WebSocketStream<MaybeTlsStream<TcpStream>>, WsMessage>;

/// WebSocket 读取端类型别名
pub type WsReader = SplitStream<WebSocketStream<MaybeTlsStream<TcpStream>>>;

#[inline]
fn message_kind(msg: &WsMessage) -> &'static str {
    match msg {
        WsMessage::Text(_) => "text",
        WsMessage::Binary(_) => "binary",
        WsMessage::Close(_) => "close",
        WsMessage::Ping(_) => "ping",
        WsMessage::Pong(_) => "pong",
        WsMessage::Frame(_) => "frame",
    }
}

/// 核心 IM 逻辑实现
pub struct ConnectionHandle {
    config: ClientConfig,
    pending_rpc: HashMap<String, WsRpcEnvelope>,
    msg_sync_cmd_tx: mpsc::UnboundedSender<MsgSyncCommand>,
    cmd_rx: mpsc::UnboundedReceiver<WsRpcEnvelope>,
    reconnect_strategy: ReconnectStrategy,
    cancel_token: CancellationToken,
    /// 全局回调，直接调用各类型监听器，便于扩展
    callbacks: Option<Arc<Listeners>>,
}

impl ConnectionHandle {
    pub fn new(
        config: ClientConfig,
        cmd_rx: mpsc::UnboundedReceiver<WsRpcEnvelope>,
        msg_sync_cmd_tx: mpsc::UnboundedSender<MsgSyncCommand>,
        cancel_token: CancellationToken,
        callbacks: Option<Arc<Listeners>>,
    ) -> Self {
        let client = Self {
            config,
            reconnect_strategy: ReconnectStrategy::new(),
            pending_rpc: HashMap::new(),
            msg_sync_cmd_tx,
            cmd_rx,
            cancel_token,
            callbacks,
        };
        client
    }

    /// 构建 WebSocket 连接 URL
    pub(crate) fn connect_url(&self) -> String {
        let compression_param = if self.config.compression.is_empty() {
            String::new()
        } else {
            format!("&compression={}", self.config.compression)
        };

        format!(
            "{}/?token={}&sendID={}&platformID={}&operationID={}{}&isBackground={}&isMsgResp={}&sdkType={}",
            self.config.ws_url,
            self.config.token,
            self.config.user_id,
            self.config.platform_id,
            util::make_operation_id(),
            compression_param,
            self.config.is_background,
            self.config.is_msg_resp,
            self.config.sdk_type
        )
    }

    /// 通知 message_handle 长连已连接
    fn connected(&mut self) {
        let _guard = info_span!("ws.connected", "长连已连接").entered();
        info!("✅ 服务器连接鉴权成功");
        let cmd = MsgSyncCommand::new(MsgSyncCommandKind::Connected);
        if let Err(e) = self.msg_sync_cmd_tx.send(cmd) {
            warn!("[Client] 发送 Connected 到 message_handle 失败: {e}");
        }
    }

    pub async fn auto_connect(&mut self) -> Result<()> {
        let mut reconnect_count = 0;
        loop {
            let cancel = self.cancel_token.clone();
            tokio::select! {
                _ = cancel.cancelled() => {
                    info!("[Client] 收到取消信号，退出连接循环");
                    return Ok(());
                }
                res = self.do_connect() => {
                    if let Err(e) = res {
                        error!("[Client] 连接失败: {}", e);
                    }
                }
            }
            // 断线后按 Go 版逻辑进行带退避的重连
            let wait = self.reconnect_strategy.next_interval();
            reconnect_count += 1;
            info!("[Client] 尝试重连，等待 {:?} 后重试（指数退避），重连次数: {}", wait, reconnect_count);
            tokio::select! {
                _ = cancel.cancelled() => {
                    info!("[Client] 收到取消信号，退出重连等待");
                    return Ok(());
                }
                _ = tokio::time::sleep(wait) => {}
            }
        }
    }

    async fn do_connect(&mut self) -> Result<()> {
        let url = self.connect_url();
        info!("[Client] 🔗 WebSocket 连接 URL: {}", url);

        if let Some(ref cb) = self.callbacks {
            cb.try_emit_conn_event(ConnEvent::Connecting);
        }

        let (ws_stream, response) = match connect_async(&url).await {
            Ok(ws) => ws,
            Err(e) => {
                let err_msg = e.to_string();
                if let Some(ref cb) = self.callbacks {
                    cb.try_emit_conn_event(ConnEvent::ConnectFailed {
                        err_code: -1,
                        err_msg: err_msg.clone(),
                    });
                }
                return Err(anyhow::anyhow!("{}", err_msg));
            }
        };
        info!("✅ WebSocket 连接成功, 状态: {}", response.status());
        self.reconnect_strategy.reset();

        let (mut writer, mut reader) = ws_stream.split();

        let mut hb = tokio::time::interval(std::time::Duration::from_secs(25));

        if let Some(Ok(WsMessage::Text(text))) = reader.next().await {
            trace!(response_len = text.len(), "收到鉴权响应");
            match serde_json::from_str::<WebSocketConnectResp>(&text) {
                Ok(resp) => {
                    if resp.err_code == 0 {
                        if let Some(ref cb) = self.callbacks {
                            cb.try_emit_conn_event(ConnEvent::ConnectSuccess);
                        }
                        self.connected();
                    } else {
                        let error_msg = if !resp.err_dlt.is_empty() {
                            format!("{} (详情: {})", resp.err_msg, resp.err_dlt)
                        } else {
                            resp.err_msg.clone()
                        };
                        if let Some(ref cb) = self.callbacks {
                            cb.try_emit_conn_event(ConnEvent::ConnectFailed {
                                err_code: resp.err_code,
                                err_msg: error_msg.clone(),
                            });
                        }
                        error!("[Client] ❌ WebSocket 连接失败，错误码: {}, 错误信息: {}", resp.err_code, error_msg);
                        return Err(anyhow::anyhow!(error_msg));
                    }
                }
                Err(e) => {
                    let err_msg = format!("WebSocket 响应解析失败: {}", e);
                    if let Some(ref cb) = self.callbacks {
                        cb.try_emit_conn_event(ConnEvent::ConnectFailed {
                            err_code: -1,
                            err_msg: err_msg.clone(),
                        });
                    }
                    error!("[Client] ❌ {}", err_msg);
                    return Err(anyhow::anyhow!("{}", err_msg));
                }
            }
        } else {
            let err_msg = "未收到 WebSocket 连接响应".to_string();
            if let Some(ref cb) = self.callbacks {
                cb.try_emit_conn_event(ConnEvent::ConnectFailed {
                    err_code: -1,
                    err_msg: err_msg.clone(),
                });
            }
            error!("[Client] ❌ {}", err_msg);
            return Err(anyhow::anyhow!("{}", err_msg));
        }

        use futures_util::SinkExt;
        use tracing::Instrument;

        loop {
            tokio::select! {
                _ = self.cancel_token.cancelled() => {
                    info!("[Client] 收到取消信号，退出读写循环");
                    return Ok(());
                }
                _ = hb.tick() => {
                    trace!("发送心跳 Ping");
                    if let Err(e) = writer.send(WsMessage::Ping(vec![])).await {
                        error!("[Client] 心跳发送失败: {}", e);
                        return Err(anyhow::anyhow!("心跳发送失败: {e}"));
                    }
                }
                cmd = self.cmd_rx.recv() => {
                    if let Some((req, resp_tx)) = cmd {
                        let key = req.msg_incr.clone();
                        trace!(msg_incr = %key, req_identifier = req.req_identifier, "发送 RPC 请求");
                        let json = serde_json::to_vec(&req).map_err(anyhow::Error::from)?;
                        let data = if self.config.compression.eq_ignore_ascii_case("gzip") {
                            compress_gzip(&json).map_err(anyhow::Error::from)?
                        } else {
                            json
                        };
                        if let Some(tx) = resp_tx {
                            self.pending_rpc.insert(key.clone(), (req, Some(tx)));
                        }
                        if let Err(e) = writer.send(WsMessage::Binary(data)).await {
                            error!("[Client] 发送ws消息失败: {}", e);
                            self.pending_rpc.remove(&key);
                            return Err(anyhow::anyhow!("发送ws消息失败: {e}"));
                        }
                    }
                }
                msg = reader.next() => {
                    match msg {
                        Some(Ok(msg)) => {
                            if let Err(e) = self.handle_message(msg) {
                                error!("[Client] 处理ws消息失败: {}", e);
                                return Err(anyhow::anyhow!("处理ws消息失败: {e}"));
                            }
                        },
                        Some(Err(e)) => {
                            let msg = e.to_string();
                            if msg.contains("Connection reset without closing handshake") {
                                warn!("[Client] 连接被服务端重置（未关闭握手），将重连");
                            } else {
                                error!("[Client] 接收ws消息失败: {}", e);
                            }
                            self.pending_rpc.clear();
                            return Err(anyhow::anyhow!("接收ws消息失败: {e}"));
                        },
                        None => {
                            trace!("WebSocket 读端关闭");
                        },
                    }
                }
            }
        }
    }

    fn handle_message(&mut self, msg: WsMessage) -> Result<()> {
        match msg {
            WsMessage::Text(text) => {
                info!("[Client] 收到 WS 文本帧 len={}（推送通常为二进制，若仅见文本可检查服务端）", text.len());
                return Ok(());
            }
            WsMessage::Binary(data) => {
                let original_len = data.len();
                let data = if data.len() >= 2 && data[0] == 0x1f && data[1] == 0x8b {
                    trace!(compressed_len = original_len, "解压压缩的二进制消息");
                    match decompress_gzip(&data) {
                        Ok(d) => {
                            trace!(decompressed_len = d.len(), "解压完成");
                            d
                        }
                        Err(e) => {
                            error!(error = %e, "解压失败");
                            return Err(anyhow::anyhow!("解压失败: {}", e));
                        }
                    }
                } else {
                    trace!(original_len = original_len, "未压缩的二进制消息");
                    data
                };

                use crate::im::model::OpenIMResp;
                let im_resp = match serde_json::from_slice::<OpenIMResp>(&data) {
                    Ok(r) => r,
                    Err(e) => {
                        warn!("[Client] 解析 OpenIM 二进制消息失败 len={} err={}", data.len(), e);
                        return Err(anyhow::anyhow!("解析 OpenIM 响应失败: {}", e));
                    }
                };

                info!(
                    im_resp.req_identifier,
                    im_resp.msg_incr, im_resp.operation_id, im_resp.err_code, im_resp.err_msg, "[Client] 收到 WS 下行消息"
                );

                match im_resp.req_identifier {
                    msg_type::WS_GET_NEWEST_SEQ | msg_type::WS_PULL_MSG_BY_RANGE | msg_type::WS_PULL_MSG_BY_SEQ_LIST | msg_type::WS_SEND_MSG | msg_type::WS_SEND_MSG_NOT_OSS => {
                        match self.pending_rpc.remove(&im_resp.msg_incr) {
                            Some((_, Some(resp_tx))) => {
                                trace!(req_identifier = im_resp.req_identifier, msg_incr = %im_resp.msg_incr, "发送RPC响应");
                                resp_tx.send(im_resp).map_err(|_| anyhow::anyhow!("向 RPC 等待方发送响应失败（接收端已关闭）"))?;
                            }
                            _ => {
                                warn!(msg_incr = %im_resp.msg_incr, "msgIncr 不存在于 pending_rpc");
                            }
                        }
                        return Ok(());
                    }
                    msg_type::WS_PUSH_MSG => {
                        if let Err(e) = self.handle_push_message(&im_resp) {
                            error!("[Client] 处理推送消息失败: {}", e);
                            return Err(anyhow::anyhow!("处理推送消息失败: {}", e));
                        }
                        return Ok(());
                    }
                    msg_type::WS_KICK_ONLINE_MSG => {
                        warn!("[Client] ⚠️ 被踢下线");
                        return Err(anyhow::anyhow!("被踢下线"));
                    }
                    _ => {
                        warn!("[Client] 未知消息类型: {}", im_resp.req_identifier);
                        return Ok(());
                    }
                }
            }
            WsMessage::Close(_) => {
                debug!("处理 Close 帧");
                return Ok(());
            }
            WsMessage::Ping(_) => {
                trace!("处理 Ping 帧");
                return Ok(());
            }
            WsMessage::Pong(_) => {
                trace!("处理 Pong 帧");
                return Ok(());
            }
            WsMessage::Frame(frame) => {
                warn!("[Client] 收到 Frame 消息");
                return Ok(());
            }
        }
    }

    #[instrument(skip(self, im_resp), fields(msg_incr = im_resp.msg_incr,
        req_identifier = im_resp.req_identifier,
        operation_id = im_resp.operation_id,
        err_code = im_resp.err_code,
        data_len = im_resp.data.len(),
    ))]
    fn handle_push_message(&mut self, im_resp: &OpenIMResp) -> Result<()> {
        let push_msg = match sdkws::PushMessages::decode(im_resp.data.as_slice()) {
            Ok(pm) => pm,
            Err(e) => {
                warn!("[Client] Push 消息 Protobuf 解析失败 data_len={} err={}", im_resp.data.len(), e);
                return Err(anyhow::anyhow!("Protobuf 解析失败: {}", e));
            }
        };
        if let Err(e) = self.msg_sync_cmd_tx.send(MsgSyncCommand::new(MsgSyncCommandKind::Push { push: push_msg })) {
            error!("[Client] 发送推送命令到 message_handle 失败: {e}");
            return Err(anyhow::anyhow!("发送推送命令失败: {e}"));
        }
        Ok(())
    }
}
