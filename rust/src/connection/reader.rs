//! WebSocket 消息读取循环
//!
//! 从 manager.rs 提取，职责：持续读取 WS 消息，分发给 pending RPC 或 message_batcher

use crate::connection::manager::ConnectionManager;
use crate::connection::manager::PendingRequest;
use crate::connection::ws::OpenIMResp;
use crate::domain::constant::{req_identifier_name, ws_push_identifier, ws_req_identifier};
use crate::event::events::connection::ConnectionListenerExt;
use crate::event::events::user::UserEvent;
use crate::logger::decode_operation_id;
use futures_util::SinkExt;
use futures_util::StreamExt;
use openim_protocol::sdkws::{PushMessages, SubUserOnlineStatusTips};
use opentelemetry::trace::{SpanContext, SpanId, TraceContextExt, TraceFlags, TraceId, TraceState};
use opentelemetry::Context;
use prost::Message;
use std::collections::HashMap;
use std::sync::Mutex as StdMutex;
use tokio::net::TcpStream;
use tokio::sync::{mpsc, RwLock};
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tokio_tungstenite::{MaybeTlsStream, WebSocketStream};
use tokio_util::sync::CancellationToken;
use tracing::{error, info, info_span, trace, warn, Instrument};

impl ConnectionManager {
    /// 启动消息读取循环
    pub(crate) fn spawn_read_loop(&self, read: futures_util::stream::SplitStream<WebSocketStream<MaybeTlsStream<TcpStream>>>, conn_token: CancellationToken) {
        let pending = self.pending_requests.clone();
        let cancel = conn_token;
        let state = self.state.clone();
        let writer = self.writer.clone();
        let compressor = self.compressor.clone();
        let message_batcher = self.message_batcher.clone();
        let user_push_tx = self.user_push_tx.clone();
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
                                            trace!("WebSocket received message: req_identifier={}({}), msg_incr={}, operation_id={}, err_code={}, err_msg={}, data_len={}",
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
                                                    route_sub_user_online_status(resp, &pending, &user_push_tx).await;
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

/// 订阅请求的响应 msg_incr 与请求一致，命中 pending 则交给 send_rpc 返回；
/// 未命中则是服务端推送的状态变更（PushUserOnlineStatus 不带 msg_incr）。
async fn route_sub_user_online_status(resp: OpenIMResp, pending: &RwLock<HashMap<String, PendingRequest>>, user_push_tx: &StdMutex<Option<mpsc::UnboundedSender<UserEvent>>>) {
    if let Some(req) = pending.write().await.remove(&resp.msg_incr) {
        let _ = req.tx.send(resp);
        return;
    }
    match parse_online_status_push(&resp.data) {
        Ok(events) => {
            let tx = user_push_tx.lock().expect("user_push_tx mutex poisoned");
            if let Some(tx) = tx.as_ref() {
                for event in events {
                    let _ = tx.send(event);
                }
            }
        }
        Err(e) => error!("decode SubUserOnlineStatusTips failed: {}", e),
    }
}

fn parse_online_status_push(data: &[u8]) -> std::result::Result<Vec<UserEvent>, prost::DecodeError> {
    let tips = SubUserOnlineStatusTips::decode(data)?;
    Ok(tips
        .subscribers
        .into_iter()
        .map(|elem| {
            let status = if elem.online_platform_i_ds.is_empty() { 0 } else { 1 };
            UserEvent::UserStatusChanged {
                user_id: elem.user_id,
                status,
                platform_ids: elem.online_platform_i_ds,
            }
        })
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::constant::ws_push_identifier::WS_SUB_USER_ONLINE_STATUS;
    use crate::event::events::user::UserEvent;
    use openim_protocol::sdkws::{SubUserOnlineStatusElem, SubUserOnlineStatusTips};
    use tokio::sync::oneshot;

    #[test]
    fn test_parse_online_status_push_empty() {
        let data = SubUserOnlineStatusTips { subscribers: vec![] }.encode_to_vec();
        assert!(parse_online_status_push(&data).unwrap().is_empty());
    }

    #[test]
    fn test_parse_online_status_push_online_and_offline() {
        let tips = SubUserOnlineStatusTips {
            subscribers: vec![
                SubUserOnlineStatusElem {
                    user_id: "u1".into(),
                    online_platform_i_ds: vec![1, 2],
                },
                SubUserOnlineStatusElem {
                    user_id: "u2".into(),
                    online_platform_i_ds: vec![],
                },
            ],
        };
        let events = parse_online_status_push(&tips.encode_to_vec()).unwrap();
        assert_eq!(events.len(), 2);
        match &events[0] {
            UserEvent::UserStatusChanged { user_id, status, platform_ids } => {
                assert_eq!(user_id, "u1");
                assert_eq!(*status, 1);
                assert_eq!(platform_ids, &vec![1, 2]);
            }
            _ => panic!("expected user status changed"),
        }
        match &events[1] {
            UserEvent::UserStatusChanged { user_id, status, platform_ids } => {
                assert_eq!(user_id, "u2");
                assert_eq!(*status, 0);
                assert!(platform_ids.is_empty());
            }
            _ => panic!("expected user status changed"),
        }
    }

    #[tokio::test]
    async fn test_route_online_status_rpc_response_wins_over_push() {
        let (tx, rx) = oneshot::channel();
        let mut pending_map = HashMap::new();
        pending_map.insert("rpc_1".to_string(), PendingRequest { tx });
        let pending = RwLock::new(pending_map);
        let (user_tx, mut user_rx) = mpsc::unbounded_channel();
        let user_push_tx = StdMutex::new(Some(user_tx));

        let resp = OpenIMResp {
            req_identifier: WS_SUB_USER_ONLINE_STATUS,
            msg_incr: "rpc_1".to_string(),
            operation_id: String::new(),
            err_code: 0,
            err_msg: String::new(),
            data: SubUserOnlineStatusTips {
                subscribers: vec![SubUserOnlineStatusElem {
                    user_id: "u1".to_string(),
                    online_platform_i_ds: vec![1],
                }],
            }
            .encode_to_vec(),
        };

        route_sub_user_online_status(resp, &pending, &user_push_tx).await;

        let routed = rx.await.expect("pending RPC should receive response");
        assert_eq!(routed.msg_incr, "rpc_1");
        assert!(user_rx.try_recv().is_err(), "matching RPC response must not be pushed as user status");
    }

    #[tokio::test]
    async fn test_route_online_status_push_without_msg_incr() {
        let pending = RwLock::new(HashMap::new());
        let (user_tx, mut user_rx) = mpsc::unbounded_channel();
        let user_push_tx = StdMutex::new(Some(user_tx));

        let resp = OpenIMResp {
            req_identifier: WS_SUB_USER_ONLINE_STATUS,
            msg_incr: String::new(),
            operation_id: String::new(),
            err_code: 0,
            err_msg: String::new(),
            data: SubUserOnlineStatusTips {
                subscribers: vec![SubUserOnlineStatusElem {
                    user_id: "u1".to_string(),
                    online_platform_i_ds: vec![1],
                }],
            }
            .encode_to_vec(),
        };

        route_sub_user_online_status(resp, &pending, &user_push_tx).await;

        match user_rx.try_recv() {
            Ok(UserEvent::UserStatusChanged { user_id, status, platform_ids }) => {
                assert_eq!(user_id, "u1");
                assert_eq!(status, 1);
                assert_eq!(platform_ids, vec![1]);
            }
            Ok(other) => panic!("unexpected event: {:?}", other),
            Err(e) => panic!("expected user status push, got: {:?}", e),
        }
    }

    #[tokio::test]
    async fn test_route_online_status_invalid_push_is_ignored() {
        let pending = RwLock::new(HashMap::new());
        let (user_tx, mut user_rx) = mpsc::unbounded_channel();
        let user_push_tx = StdMutex::new(Some(user_tx));

        let resp = OpenIMResp {
            req_identifier: WS_SUB_USER_ONLINE_STATUS,
            msg_incr: String::new(),
            operation_id: String::new(),
            err_code: 0,
            err_msg: String::new(),
            data: b"not a valid protobuf".to_vec(),
        };

        route_sub_user_online_status(resp, &pending, &user_push_tx).await;

        assert!(user_rx.try_recv().is_err(), "invalid push must be ignored");
    }
}
