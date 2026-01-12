use anyhow::Result;
use futures_util::StreamExt;
use openim_protocol::sdkws;
use serde_json;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tracing::{debug, error, warn};

use super::OpenIMClient;
use crate::im::client::client::WsReader;

impl OpenIMClient {
    /// 处理接收消息（事件循环）
    pub(crate) async fn handle_messages(&self, mut read: WsReader) -> Result<()> {
        while let Some(msg_result) = read.next().await {
            match msg_result {
                Ok(WsMessage::Text(text)) => {
                    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text) {
                        if let Some(req_id) = json.get("reqIdentifier") {
                            debug!("[Client] 文本响应: reqId={}", req_id);
                        }
                    }
                }
                Ok(WsMessage::Binary(data)) => {
                    if let Err(e) = self.handle_binary_message(data).await {
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
        Ok(())
    }

    async fn handle_binary_message(&self, data: Vec<u8>) -> Result<()> {
        use crate::im::message::binary_handler::{
            BinaryMessageHandler, BinaryMessageHandlerCallbacks,
        };
        use std::sync::Arc;

        // 获取或创建二进制消息处理器回调
        let callbacks: Arc<BinaryMessageHandlerCallbacks> = {
            let mut callbacks_guard = self.binary_message_handler_callbacks.lock().await;
            if let Some(ref callbacks) = *callbacks_guard {
                callbacks.clone()
            } else {
                // 如果不存在，创建一个新的
                let self_arc = Arc::new(self.clone());
                let new_callbacks = Arc::new(BinaryMessageHandlerCallbacks {
                    handle_rpc_response: Box::new({
                        let client = self_arc.clone();
                        move |resp| {
                            let client = client.clone();
                            Box::pin(async move {
                                OpenIMClient::handle_rpc_response(&client, resp).await
                            })
                        }
                    }),
                    get_push_message_handler_context: Box::new({
                        let client = self_arc.clone();
                        move || OpenIMClient::get_push_message_handler_context(&client)
                    }),
                    advanced_msg_listener: Box::new({
                        let client = self_arc.clone();
                        move || client.advanced_msg_listener.clone()
                    }),
                });
                *callbacks_guard = Some(new_callbacks.clone());
                new_callbacks
            }
        };

        BinaryMessageHandler::handle_binary_message(&callbacks, data).await
    }

    /// 处理推送消息（已迁移到消息模块，保留此方法以保持兼容性）
    #[deprecated(note = "此方法已迁移到 message::handler::MessageHandler::handle_push_message")]
    pub(crate) async fn handle_push_message(&self, _data: &[u8]) -> Result<()> {
        // 此方法已不再使用，实际处理逻辑在 binary_handler.rs 中
        // 保留此方法仅用于 trait 实现
        Ok(())
    }

    /// 检查消息是否重复（WebSocket 层去重）
    pub(crate) fn is_duplicate_message(&self, msg_id: &str) -> bool {
        let mut set = self.received_msg_ids.lock().unwrap();
        !set.insert(msg_id.to_string())
    }

    /// 将 MsgData 转换为 JSON 字符串（用于日志和调试）
    pub(crate) fn msg_data_to_json(&self, msg: &sdkws::MsgData) -> String {
        use crate::im::message::handler::MessageHandler;
        MessageHandler::msg_data_to_json(msg)
    }
}
