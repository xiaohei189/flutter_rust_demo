//! WebSocket 二进制消息处理器模块
//!
//! 负责处理从 WebSocket 接收到的二进制消息，包括解压、解析和分发

use anyhow::Result;
use tracing::{debug, error, warn};

use crate::im::conversation::service::ConversationSyncer;
use crate::im::listener::AdvancedMsgListener;
use crate::im::message::handler::MessageHandlerContext;
use crate::im::model::{msg_type, OpenIMResp};
use crate::im::serialization::decompress_gzip;
use std::sync::Arc;

/// 推送消息处理器上下文
pub struct PushMessageHandlerContext {
    /// 消息处理器上下文
    pub message_handler_ctx: MessageHandlerContext,
    /// 消息去重检查器
    pub is_duplicate_message: Box<dyn Fn(&str) -> bool + Send + Sync>,
    /// 会话同步器（用于触发增量同步）
    pub conversation_syncer: Option<Arc<ConversationSyncer>>,
}

/// 二进制消息处理器回调函数
pub struct BinaryMessageHandlerCallbacks {
    /// 处理 RPC 响应
    pub handle_rpc_response: Box<
        dyn Fn(
                OpenIMResp,
            )
                -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<()>> + Send>>
            + Send
            + Sync,
    >,
    /// 获取推送消息处理器上下文
    pub get_push_message_handler_context:
        Box<dyn Fn() -> Result<PushMessageHandlerContext> + Send + Sync>,
    /// 获取高级消息监听器
    pub advanced_msg_listener: Box<dyn Fn() -> Option<Arc<dyn AdvancedMsgListener>> + Send + Sync>,
}

/// WebSocket 二进制消息处理器（无状态）
pub struct BinaryMessageHandler;

impl BinaryMessageHandler {
    /// 处理二进制消息
    ///
    /// 负责：
    /// 1. 解压 gzip 数据（如果适用）
    /// 2. 解析 JSON 响应
    /// 3. 根据 req_identifier 分发到不同的处理函数
    pub async fn handle_binary_message(
        callbacks: &BinaryMessageHandlerCallbacks,
        data: Vec<u8>,
    ) -> Result<()> {
        // 解压 gzip 数据
        let decompressed = if data.len() >= 2 && data[0] == 0x1f && data[1] == 0x8b {
            match decompress_gzip(&data) {
                Ok(d) => d,
                Err(e) => {
                    return Err(anyhow::anyhow!("解压失败: {}", e));
                }
            }
        } else {
            data
        };

        // 解析 JSON 响应
        let resp = serde_json::from_slice::<OpenIMResp>(&decompressed)?;

        // 根据 req_identifier 分发处理
        match resp.req_identifier {
            msg_type::WS_GET_NEWEST_SEQ
            | msg_type::WS_PULL_MSG_BY_RANGE
            | msg_type::WS_PULL_MSG_BY_SEQ_LIST
            | msg_type::WS_SEND_MSG
            | msg_type::WS_SEND_MSG_NOT_OSS => {
                // RPC 响应：调用 RPC 响应处理器
                (callbacks.handle_rpc_response)(resp).await?;
            }

            msg_type::WS_PUSH_MSG => {
                // 推送消息：使用消息处理器处理
                let push_ctx = (callbacks.get_push_message_handler_context)()?;
                let message_handler =
                    crate::im::message::handler::MessageHandler::new(push_ctx.message_handler_ctx);

                let need_conv_sync = message_handler
                    .handle_push_message(&resp.data, |msg_id| {
                        (push_ctx.is_duplicate_message)(msg_id)
                    })
                    .await?;

                // 收到会话相关通知后，触发会话增量同步以覆盖本地占位数据（名称/头像/未读等）
                if need_conv_sync {
                    if let Some(syncer) = push_ctx.conversation_syncer {
                        tokio::spawn(async move {
                            if let Err(e) = syncer.incr_sync_conversations().await {
                                error!("[Client] ❌ 会话增量同步失败: {e}");
                            }
                        });
                    }
                }
            }

            msg_type::WS_KICK_ONLINE_MSG => {
                // 踢下线消息：触发监听器回调
                warn!("[Client] ⚠️ 被踢下线");
                let listener = (callbacks.advanced_msg_listener)();
                if let Some(listener) = listener {
                    tokio::spawn(async move {
                        listener.on_kicked_offline().await;
                    });
                }
            }

            _ => {
                debug!("[Client] 未知消息类型: {}", resp.req_identifier);
            }
        }

        Ok(())
    }
}
