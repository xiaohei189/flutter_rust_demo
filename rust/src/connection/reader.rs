//! WebSocket 消息读取循环
//!
//! 从 manager.rs 提取，职责：持续读取 WS 消息，分发给 pending RPC 或 message_batcher

use crate::connection::manager::ConnectionManager;
use crate::connection::ws::OpenIMResp;
use crate::constant::{req_identifier_name, ws_push_identifier, ws_req_identifier};
use crate::event::events::connection::ConnectionListenerExt;
use crate::logger::decode_operation_id;
use futures_util::SinkExt;
use futures_util::StreamExt;
use openim_protocol::sdkws::PushMessages;
use opentelemetry::trace::{SpanContext, SpanId, TraceContextExt, TraceFlags, TraceId, TraceState};
use opentelemetry::Context;
use prost::Message;
use tokio::net::TcpStream;
use tokio_tungstenite::{MaybeTlsStream, WebSocketStream};
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tracing::{debug, info, warn, error, info_span, Instrument};

impl ConnectionManager {
    /// 启动消息读取循环
    pub(crate) fn spawn_read_loop(&self, read: futures_util::stream::SplitStream<WebSocketStream<MaybeTlsStream<TcpStream>>>) {
        let pending = self.pending_requests.clone();
        let cancel = self.cancel_token.clone();
        let state = self.state.clone();
        let writer = self.writer.clone();
        let compressor = self.compressor.clone();
        let message_batcher = self.message_batcher.clone();
        let is_manual_disconnect = self.is_manual_disconnect.clone();
        let listener = self.listener.clone();

        tokio::spawn(async move {
            let mut read = read;
            loop {
                tokio::select! {
                    _ = cancel.cancelled() => {
                        info!("read_loop: cancelled");
                        break;
                    }
                    msg = read.next() => {
                        match msg {
                            Some(Ok(WsMessage::Text(text))) => {
                                match serde_json::from_str::<OpenIMResp>(&text) {
                                    Ok(resp) => {
                                        if let Some(pending_req) = pending.write().await.remove(&resp.msg_incr) {
                                            let _ = pending_req.tx.send(resp);
                                        } else if resp.req_identifier == ws_push_identifier::PUSH_MSG {
                                            if let Ok(push_msgs) = PushMessages::decode(resp.data.as_slice()) {
                                                message_batcher.enqueue(resp.operation_id, push_msgs).await;
                                            }
                                        }
                                    }
                                    Err(e) => {
                                        warn!("failed to parse ws text as OpenIMResp: {}, text={}", e, &text[..text.len().min(100)]);
                                    }
                                }
                            }
                            Some(Ok(WsMessage::Binary(data))) => {
                                let data = match compressor.decompress(&data) {
                                    Ok(decompressed) => decompressed,
                                    Err(_) => data,
                                };
                                match serde_json::from_slice::<OpenIMResp>(&data) {
                                    Ok(resp) => {
                                        let (trace_id_str, _span_id_str) = decode_operation_id(&resp.operation_id);
                                        let span = {
                                            let _cx_guard = if let Ok(trace_id) = TraceId::from_hex(trace_id_str) {
                                                let parent_span_id = SpanId::from(1u64);
                                                let remote_sc = SpanContext::new(
                                                    trace_id, parent_span_id,
                                                    TraceFlags::SAMPLED, true, TraceState::default(),
                                                );
                                                Some(Context::new().with_remote_span_context(remote_sc).attach())
                                            } else { None };
                                            info_span!("ws_binary_resp")
                                        };
                                        let handle_resp = async {
                                            debug!("WebSocket received message: req_identifier={}({}), msg_incr={}, operation_id={}, err_code={}, err_msg={}, data_len={}",
                                                resp.req_identifier, req_identifier_name(resp.req_identifier),
                                                resp.msg_incr, resp.operation_id, resp.err_code, resp.err_msg, resp.data.len());
                                            let mut should_break = false;
                                            match resp.req_identifier {
                                                ws_push_identifier::PUSH_MSG => {
                                                    match PushMessages::decode(resp.data.as_slice()) {
                                                        Ok(push_msgs) => {
                                                            info!("received push messages: {} conversations with msgs, {} with notifications",
                                                                push_msgs.msgs.len(), push_msgs.notification_msgs.len());
                                                            message_batcher.enqueue(resp.operation_id, push_msgs).await;
                                                        }
                                                        Err(e) => error!("doWSPushMsg failed: {}", e),
                                                    }
                                                }
                                                ws_push_identifier::LOGOUT_MSG => {
                                                    info!("ws logout message");
                                                    if let Some(req) = pending.write().await.remove(&resp.msg_incr) {
                                                        let _ = req.tx.send(resp);
                                                    }
                                                    *is_manual_disconnect.write().await = true;
                                                    message_batcher.close().await;
                                                    listener.emit(crate::event::events::connection::ConnectionEvent::Logout);
                                                    cancel.cancel();
                                                    should_break = true;
                                                }
                                                ws_push_identifier::KICK_ONLINE_MSG => {
                                                    warn!("ws kick online message: err_msg={}", resp.err_msg);
                                                    *is_manual_disconnect.write().await = true;
                                                    *state.write().await = crate::connection::manager::ConnectionState::Kicked;
                                                    message_batcher.close().await;
                                                    listener.emit(crate::event::events::connection::ConnectionEvent::KickedOffline(resp.err_msg.to_string()));
                                                    cancel.cancel();
                                                    should_break = true;
                                                }
                                                ws_req_identifier::GET_NEWEST_SEQ
                                                | ws_req_identifier::PULL_MSG_BY_RANGE
                                                | ws_req_identifier::SEND_MSG
                                                | ws_req_identifier::SEND_SIGNAL_MSG
                                                | ws_req_identifier::PULL_MSG_BY_SEQ_LIST
                                                | ws_req_identifier::GET_CONV_MAX_READ_SEQ
                                                | ws_req_identifier::PULL_CONV_LAST_MESSAGE
                                                | ws_push_identifier::SET_BACKGROUND_STATUS => {
                                                    if let Some(req) = pending.write().await.remove(&resp.msg_incr) {
                                                        let _ = req.tx.send(resp);
                                                    }
                                                }
                                                ws_push_identifier::WS_SUB_USER_ONLINE_STATUS => {
                                                    warn!("WsSubUserOnlineStatus handler not yet implemented");
                                                }
                                                _ => {
                                                    error!("binary message type not support: req_identifier={}({})",
                                                        resp.req_identifier, req_identifier_name(resp.req_identifier));
                                                }
                                            }
                                            should_break
                                        };
                                        if handle_resp.instrument(span).await {
                                            break;
                                        }
                                    }
                                    Err(e) => {
                                        let preview: String = data.iter().take(200).map(|b| format!("{:02x}", b)).collect();
                                        warn!("failed to decode binary message as OpenIMResp: {}, len={}, hex[0:100]={}", e, data.len(), &preview[..preview.len().min(200)]);
                                    }
                                }
                            }
                            Some(Ok(WsMessage::Ping(data))) => {
                                if let Some(w) = writer.write().await.as_mut() {
                                    let _ = w.send(WsMessage::Pong(data)).await;
                                }
                            }
                            Some(Ok(WsMessage::Pong(_))) => {}
                            Some(Ok(WsMessage::Close(_))) => {
                                info!("ws closed by server");
                                *state.write().await = crate::connection::manager::ConnectionState::Disconnected;
                                break;
                            }
                            Some(Err(e)) => {
                                let manual = { *is_manual_disconnect.read().await };
                                if manual { info!("ws closed (manual disconnect): {}", e); }
                                else { error!("ws error: {}", e); }
                                *state.write().await = crate::connection::manager::ConnectionState::Disconnected;
                                break;
                            }
                            None => {
                                let manual = { *is_manual_disconnect.read().await };
                                if manual { info!("ws stream ended (manual disconnect)"); }
                                else { info!("ws stream ended"); }
                                *state.write().await = crate::connection::manager::ConnectionState::Disconnected;
                                break;
                            }
                            _ => {}
                        }
                    }
                }
            }
        });
    }
}
