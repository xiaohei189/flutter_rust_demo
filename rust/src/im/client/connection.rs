//! OpenIM 客户端核心实现模块
//!
//! 此模块包含 OpenIM 客户端的核心逻辑实现。

use crate::im::client::api::OpenIMClientApi;
use crate::im::client::client::ClientConfig;
use crate::im::client::reconnect::{ConnectFatalError, ReconnectStrategy};
use crate::im::client::seq_cache::ConversationSeqContextCache;
use crate::im::conversation::service::ConversationSyncer;
use crate::im::dao::MessageRepo;
use crate::im::db::db::create_sqlite_pool_with_migration;
use crate::im::friend::{FriendListener, FriendSyncer, FriendSyncerConfig};
use crate::im::listener::{AdvancedMsgListener, ConversationListener};
use crate::im::model::conversation::ConversationSyncerConfig;
use crate::im::model::message::{AtElem, AtInfo, CustomElem, FileElem, LocationElem, MarkdownTextElem, MsgStruct, PictureElem, QuoteElem, SeqRange as SeqRangeModel, SoundElem, VideoElem};
use crate::im::model::ws::ConnectionCommand;
use crate::im::model::{msg_type, LocalConversation, OpenIMResp};
use crate::im::serialization::{decompress_gzip, generate_msg_id};
use crate::im::{util, WebSocketConnectResp};
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
use tracing::{debug, error, info, warn};
/// WebSocket 写入端类型别名
pub type WsWriter = SplitSink<WebSocketStream<MaybeTlsStream<TcpStream>>, WsMessage>;

/// WebSocket 读取端类型别名
pub type WsReader = SplitStream<WebSocketStream<MaybeTlsStream<TcpStream>>>;

/// 核心 IM 逻辑实现
pub struct Connection {
    config: ClientConfig,
    pending_rpc: HashMap<String, ConnectionCommand>,
    push_msg_tx: mpsc::UnboundedSender<sdkws::PushMessages>,
    cmd_rx: mpsc::UnboundedReceiver<ConnectionCommand>,
    reconnect_strategy: ReconnectStrategy,
}

impl Connection {
    pub fn new(config: ClientConfig, cmd_rx: mpsc::UnboundedReceiver<ConnectionCommand>, push_msg_tx: mpsc::UnboundedSender<sdkws::PushMessages>) -> Self {
        let client = Self {
            config,
            reconnect_strategy: ReconnectStrategy::new(),
            pending_rpc: HashMap::new(),
            push_msg_tx,
            cmd_rx,
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

    /// 启动消息处理和重连任务
    pub async fn run(&mut self) -> Result<()> {
        let mut reconnect_count = 0;
        loop {
            if let Err(e) = self.connect().await {
                error!("[Client] 连接失败: {}", e);
            }
            // 断线后按 Go 版逻辑进行带退避的重连
            let wait = self.reconnect_strategy.next_interval();
            reconnect_count += 1;
            info!("[Client] 尝试重连，等待 {:?} 后重试（指数退避），重连次数: {}", wait, reconnect_count);
            tokio::time::sleep(wait).await;
        }
    }

    async fn connect(&mut self) -> Result<()> {
        let url = self.connect_url();
        debug!("[Client] 🔗 WebSocket 连接 URL: {}", url);
        let (ws_stream, response) = connect_async(&url).await?;
        info!("[Client] ✅ WebSocket 连接成功, 状态: {}", response.status());
        self.reconnect_strategy.reset();

        let (mut writer, mut reader) = ws_stream.split();

        let mut hb = tokio::time::interval(std::time::Duration::from_secs(25));

        if let Some(Ok(WsMessage::Text(text))) = reader.next().await {
            match serde_json::from_str::<WebSocketConnectResp>(&text) {
                Ok(resp) => {
                    if resp.err_code == 0 {
                        info!("[Client] ✅ 服务器连接鉴权成功");
                    } else {
                        let error_msg = if !resp.err_dlt.is_empty() {
                            format!("{} (详情: {})", resp.err_msg, resp.err_dlt)
                        } else {
                            resp.err_msg.clone()
                        };
                        error!("[Client] ❌ WebSocket 连接失败，错误码: {}, 错误信息: {}", resp.err_code, error_msg);
                        return Err(anyhow::anyhow!(error_msg));
                    }
                }
                Err(e) => {
                    error!("[Client] ❌ WebSocket 响应解析失败: {}, 原始响应: {}", e, text);
                    return Err(anyhow::anyhow!("WebSocket 响应解析失败: {}, 原始响应: {}", e, text));
                }
            }
        } else {
            error!("[Client] ❌ 未收到 WebSocket 连接响应");
            return Err(anyhow::anyhow!("未收到 WebSocket 连接响应"));
        }
        use futures_util::SinkExt;

        loop {
            tokio::select! {
                _ = hb.tick() => {
                    if let Err(e) = writer.send(WsMessage::Ping(vec![])).await {
                        error!("[Client] 心跳发送失败: {}", e);
                        return Err(anyhow::anyhow!("心跳发送失败: {e}"));
                    }
                }
                cmd = self.cmd_rx.recv() => {
                    match cmd {
                        Some(cmd) => {
                            match cmd {
                                ConnectionCommand::Text(t) => writer.send(WsMessage::Text(t)).await?,
                                ConnectionCommand::Binary(b) => writer.send(WsMessage::Binary(b)).await?,
                                ConnectionCommand::Ping => writer.send(WsMessage::Ping(vec![])).await?,
                                ConnectionCommand::Disconnect(_) => return Ok(()),
                                ConnectionCommand::Rpc { req, resp } => {
                                    let req = req.unwrap();
                                    // let resp = resp.send(Ok(OpenIMResp::default())).await?;
                                }
                            }
                        }
                        None => {
                            debug!("[Client] ws消息mpsc通道已关闭，发送任务退出");
                            return Ok(());
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
                            error!("[Client] 接收ws消息失败: {}", e);
                            return Err(anyhow::anyhow!("接收ws消息失败: {e}"));
                        },
                        None => {},
                    }

                }
            }
        }
    }

    fn handle_message(&mut self, msg: WsMessage) -> Result<()> {
        match msg {
            WsMessage::Text(text) => {
                info!("[Client] 收到文本消息: {}", text);
            }
            WsMessage::Binary(data) => {
                // 解压 gzip 数据
                let data = if data.len() >= 2 && data[0] == 0x1f && data[1] == 0x8b {
                    match decompress_gzip(&data) {
                        Ok(d) => d,
                        Err(e) => {
                            return Err(anyhow::anyhow!("解压失败: {}", e));
                        }
                    }
                } else {
                    data
                };
                // 将二进制消息尝试转为字符串后输出日志
                info!("[Client] 收到二进制消息: {}", String::from_utf8_lossy(&data));

                use crate::im::model::OpenIMResp;
                // 解析 JSON 响应
                let im_resp = serde_json::from_slice::<OpenIMResp>(&data)?;

                // 根据 req_identifier 分发处理
                match im_resp.req_identifier {
                    msg_type::WS_GET_NEWEST_SEQ | msg_type::WS_PULL_MSG_BY_RANGE | msg_type::WS_PULL_MSG_BY_SEQ_LIST | msg_type::WS_SEND_MSG | msg_type::WS_SEND_MSG_NOT_OSS => {
                        // RPC 响应：调用 RPC 响应处理器
                        let cmd = self.pending_rpc.remove(&im_resp.operation_id);
                        if let Some(cmd) = cmd {
                            match cmd {
                                ConnectionCommand::Rpc { req, resp } => {
                                    if let Err(e) = resp.send(im_resp) {
                                        error!("[Client] 发送RPC响应失败: {:?}", e);
                                        return Err(anyhow::anyhow!("发送RPC响应失败: {:?}", e));
                                    }
                                }
                                _ => {
                                    warn!("[Client] 未知消息类型: {}", im_resp.req_identifier);
                                    return Err(anyhow::anyhow!("未知消息类型: {}", im_resp.req_identifier));
                                }
                            }
                        } else {
                            warn!("[Client] 操作ID不存在: {}", im_resp.operation_id);

                            return Ok(());
                        }
                    }
                    msg_type::WS_PUSH_MSG => {
                        error!("[Client] 未知消息类型: {}", im_resp.req_identifier);
                        if data.is_empty() {
                            return Err(anyhow::anyhow!("推送消息为空"));
                        }
                        // 解析 protobuf PushMessages
                        let push_msg = match sdkws::PushMessages::decode(im_resp.data.as_slice()) {
                            Ok(pm) => pm,
                            Err(e) => {
                                return Err(anyhow::anyhow!("Protobuf 解析失败: {}", e));
                            }
                        };
                        info!(
                            "[BinaryMessageHandler] push_msg (pretty):\n{}",
                            serde_json::to_string_pretty(&push_msg).unwrap_or_else(|e| format!("JSON序列化失败: {}", e))
                        );
                        if let Err(e) = self.push_msg_tx.send(push_msg) {
                            error!("[Client] 发送推送消息失败: {e}");
                            return Err(anyhow::anyhow!("发送推送消息失败: {e}"));
                        }
                    }
                    msg_type::WS_KICK_ONLINE_MSG => {
                        // 踢下线消息：触发监听器回调
                        warn!("[Client] ⚠️ 被踢下线");
                        return Err(anyhow::anyhow!("被踢下线"));
                    }
                    _ => {
                        error!("[Client] 未知消息类型: {}", im_resp.req_identifier);
                        return Err(anyhow::anyhow!("未知消息类型: {}", im_resp.req_identifier));
                    }
                }
            }
            WsMessage::Ping(_) => {
                info!("[Client] 收到Ping消息");
            }
            WsMessage::Pong(_) => {
                info!("[Client] 收到Pong消息");
            }
            WsMessage::Close(_) => {
                warn!("[Client] 收到Close消息");
                return Ok(());
            }
            _ => {
                warn!("[Client] 收到未知消息: {:?}", msg);
            }
        }
        Ok(())
    }
}
// 允许未使用的辅助方法（日志解析/调试）
#[allow(dead_code, clippy::manual_range_contains, clippy::single_match)]
#[cfg(test)]
mod tests {
    use test_context::{test_context, AsyncTestContext};
    use tokio::sync::OnceCell;
    use tracing::{error, info, warn};

    use super::{ClientConfig, Connection};
    use crate::im::auth::login_async;
    use crate::im::friend::FriendListener;
    use crate::im::listener::{AdvancedMsgListener, ConversationListener};
    use crate::im::logger::logger::init_logger;
    use crate::im::model::SeqRange;
    use std::sync::Arc;
    use std::time::{self, Duration};

    static APP_CTX: OnceCell<AppCtx> = OnceCell::const_new();

    #[derive(Clone)]
    struct AppCtx {
        im_token: String,
        user_id: String,
    }

    impl AsyncTestContext for AppCtx {
        async fn setup() -> Self {
            APP_CTX
                .get_or_init(|| async {
                    init_logger("info,rust_lib_flutter_rust_demo=debug,hyper_util::client=info,reqwest=info");
                    let area_code = "+86".to_string();
                    let password = "284f3d09ea0695538e4ded1c1766d73a".to_string();
                    let platform = 5;
                    let token_info = login_async(area_code, "17764338283".to_string(), password, platform).await.expect("登录失败");

                    // 解析 token（如果登录成功）
                    let (user_id, im_token) = (token_info.user_id.clone(), token_info.im_token.clone());

                    AppCtx { im_token, user_id }
                })
                .await
                .clone()
        }
        async fn teardown(self) {
            let _ = self;
        }
    }
    #[test_context(AppCtx)]
    #[tokio::test]
    #[ignore]
    async fn connect(ctx: &mut AppCtx) {
        let config = ClientConfig::new(ctx.user_id.clone(), ctx.im_token.clone(), 5);

        let (tx, rx) = tokio::sync::mpsc::unbounded_channel();
        let (push_msg_tx, push_msg_rx) = tokio::sync::mpsc::unbounded_channel();
        let mut client = Connection::new(config, rx, push_msg_tx);

        // 连接到服务器（内部会自动启动消息处理）
        client.run().await.unwrap_or_else(|e| {
            error!("连接失败: {}", e);
            return;
        });
    }
}
