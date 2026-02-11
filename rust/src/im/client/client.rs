use tokio::time::Duration;
#[derive(Clone, Debug)]
pub struct ClientConfig {
    /// 用户 ID
    pub user_id: String,
    /// 认证 token
    pub token: String,
    /// 平台 ID
    pub platform_id: i32,
    /// WebSocket 服务器 URL
    pub ws_url: String,
    /// 压缩方式，例如 "gzip" 或空字符串表示不压缩
    pub compression: String,
    /// 是否为后台模式
    pub is_background: bool,
    /// 是否需要消息响应
    pub is_msg_resp: bool,
    /// SDK 类型，例如 "js" 或 "go"
    pub sdk_type: String,
    /// HTTP API 基础地址（用于会话同步）
    pub api_base_url: String,
    /// 会话同步使用的本地 SQLite 数据库 URL
    ///
    /// 例如：`sqlite://conversations.db?mode=rwc`
    pub conversation_db_url: String,
    /// 消息响应超时时间
    pub msg_resp_timeout: Duration,
}

impl ClientConfig {
    /// 创建默认配置
    pub fn new(user_id: String, token: String, platform_id: i32) -> Self {
        Self {
            user_id,
            token,
            platform_id,
            ws_url: "ws://localhost:10001".to_string(),
            compression: "gzip".to_string(),
            is_background: false,
            is_msg_resp: true,
            sdk_type: "js".to_string(),
            api_base_url: "http://localhost:10002".to_string(),
            conversation_db_url: "sqlite://conversations.db?mode=rwc".to_string(),
            msg_resp_timeout: Duration::from_secs(10),
        }
    }
}

pub struct Client {
    config: ClientConfig,
}

impl Client {
    pub fn new(config: ClientConfig) -> Self {
        Self { config }
    }
}

use crate::im::client::connection_handle::ConnectionHandle;
use crate::im::client::conversation_handle::ConversationHandle;
use crate::im::client::message_handle::{MessageHandle, MsgSyncCommand};
use crate::im::dao::repository::Repository;
use crate::im::friend::FriendListener;
use crate::im::listener::{AdvancedMsgListener, ConversationListener};
use crate::im::model::conversation::ConversationSyncerConfig;
use crate::im::model::ws::WsRpcEnvelope;
use anyhow::{Context, Result};
use openim_protocol::constant;
use openim_protocol::sdkws;
use std::sync::Arc;
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;
use tracing::{error, info};



/// 核心 IM 逻辑实现
#[derive(Clone)]
pub struct OpenIMClient {
    pub(crate) config: ClientConfig,
    
    // 会话监听器（可由调用方注册）
    conversation_listener: Option<Arc<dyn ConversationListener>>,
    // 好友监听器（可由调用方注册）
    friend_listener: Option<Arc<dyn FriendListener>>,
    // 高级消息监听器（可由调用方注册，参考 Go 版本的 OnAdvancedMsgListener）
    pub(crate) advanced_msg_listener: Option<Arc<dyn AdvancedMsgListener>>,
}

impl OpenIMClient {
    /// 创建新的客户端
    /// - `config`: 客户端配置
    pub fn new(config: ClientConfig) -> Self {
        let client = Self {
            config,
            conversation_listener: None,
            friend_listener: None,
            advanced_msg_listener: None,
        };
        client
    }

    /// 建立一次 WebSocket 连接并完成鉴权握手（不包含 DB/同步器初始化）
    // connect_ws_once 已迁移至 connection.rs

    /// 创建带认证的 HTTP 客户端
    fn create_http_client(config: &ClientConfig) -> Result<reqwest::Client> {
        reqwest::Client::builder()
            .default_headers({
                let mut headers = reqwest::header::HeaderMap::new();
                headers.insert(
                    reqwest::header::HeaderName::from_static("token"),
                    reqwest::header::HeaderValue::from_str(&config.token).context("无效的 token")?,
                );
                headers
            })
            .build()
            .context("创建 HTTP 客户端失败")
    }

    /// 初始化并运行客户端（WebSocket 连接、消息/会话同步），阻塞直到退出或取消
    pub async fn init(&mut self) -> Result<()> {
        let repo = Repository::create(&self.config.conversation_db_url).await?;
        let (connection_tx, connection_rx) = mpsc::unbounded_channel();
        let (msg_sync_cmd_tx, msg_sync_cmd_rx) = mpsc::unbounded_channel();
        let cancel_token = CancellationToken::new();
        let mut connection = ConnectionHandle::new(
            self.config.clone(),
            connection_rx,
            msg_sync_cmd_tx.clone(),
            cancel_token.clone(),
        );
        let mut connection_handle = tokio::spawn(async move {
            if let Err(e) = connection.auto_connect().await {
                error!("连接失败: {}", e);
            }
        });
        let (msg_sync_event_tx, _msg_sync_event_rx) = mpsc::unbounded_channel();
        let (conv_cmd_tx, conv_cmd_rx) = mpsc::unbounded_channel();
        let http_client_for_conv = Self::create_http_client(&self.config)?;
        let conv_cfg = ConversationSyncerConfig {
            user_id: self.config.user_id.clone(),
            api_base_url: self.config.api_base_url.clone(),
            token: self.config.token.clone(),
            db_path: self.config.conversation_db_url.clone(),
        };
        let mut conversation_handle = ConversationHandle::with_listener_and_db_and_client(
            conv_cfg,
            self.conversation_listener.clone(),
            repo.pool.clone(),
            http_client_for_conv,
            conv_cmd_rx,
            cancel_token.clone(),
        )
        .await?;
        let mut conversation_handle_task = tokio::spawn(async move {
            if let Err(e) = conversation_handle.run().await {
                error!("会话处理器运行失败: {}", e);
            }
        });
        let mut message_syncer = MessageHandle::new(
            self.config.user_id.clone(),
            repo,
            connection_tx,
            cancel_token.clone(),
            msg_sync_event_tx,
            msg_sync_cmd_rx,
            conv_cmd_tx,
        );
        let mut message_syncer_handle = tokio::spawn(async move {
            if let Err(e) = message_syncer.load_seq().await {
                return Err(anyhow::anyhow!("运行消息同步器失败: {}", e));
            }
            if let Err(e) = message_syncer.run().await {
                return Err(anyhow::anyhow!("运行消息同步器失败: {}", e));
            }
            Ok(())
        });
        tokio::select! {
            _ = &mut connection_handle => {
                info!("连接器运行完成，退出客户端");
            }
            _ = &mut message_syncer_handle => {
                info!("消息同步器运行完成，退出客户端");
            }
            _ = &mut conversation_handle_task => {
                info!("会话处理器运行完成，退出客户端");
            }
        }
        cancel_token.cancel();
        Ok(())
    }

    /// 注册会话监听器
    pub fn set_conversation_listener(&mut self, listener: Arc<dyn ConversationListener>) {
        self.conversation_listener = Some(listener.clone());
    }

    /// 注册好友监听器
    pub fn set_friend_listener(&mut self, listener: Arc<dyn FriendListener>) {
        self.friend_listener = Some(listener.clone());
        // FriendSyncer 当前不再重建，沿用已有实例
    }

    /// 注册高级消息监听器（参考 Go 版本的 SetAdvancedMsgListener）
    pub fn set_advanced_msg_listener(&mut self, listener: Arc<dyn AdvancedMsgListener>) {
        self.advanced_msg_listener = Some(listener.clone());
    }
    /// 处理接收消息（事件循环） -> ws_handlers 模块实现

    // handle_binary_message 迁移至 ws_handlers

    // handle_push_message 迁移至 ws_handlers

    /// 处理单个消息，返回是否已处理
    ///
    /// - `conv_id`: 会话 ID
    /// - `msg`: 消息数据
    /// - `_is_notification`: 是否为通知消息（保留用于后续扩展）
    /// - 返回: `true` 表示已处理，`false` 表示未处理（需要 warn）
    pub async fn handle_single_message(&self, conv_id: &str, msg: &openim_protocol::sdkws::MsgData, _is_notification: bool) -> bool {
        // 撤回消息
        if msg.content_type == constant::REVOKE {
            let revoked_json = serde_json::json!({
                "clientMsgID": msg.client_msg_id,
                "revokerID": msg.send_id,
                "revokeTime": msg.send_time,
                "seq": msg.seq,
                "conversationID": conv_id,
            });

            info!("receive message: revoked_json: {:?}", revoked_json);
            let revoked_json_str = serde_json::to_string(&revoked_json).unwrap_or_default();
            let listener = self.advanced_msg_listener.clone();
            tokio::spawn(async move {
                if let Some(listener) = &listener {
                    listener.on_new_recv_message_revoked(revoked_json_str).await;
                }
            });
            return true;
        }

        // 已读回执
        if msg.content_type == constant::HAS_READ_RECEIPT {
            let mut seqs: Vec<i64> = Vec::new();
            let mut receipt_list = Vec::new();
            if let Ok(json) = serde_json::from_slice::<serde_json::Value>(&msg.content) {
                if let Some(detail) = json.get("detail") {
                    if let Some(list) = detail.get("seqList").and_then(|v| v.as_array()) {
                        seqs = list.iter().filter_map(|x| x.as_i64()).collect();
                    }
                }
                receipt_list.push(serde_json::json!({
                    "userID": msg.send_id,
                    "msgIDList": seqs.iter().map(|s| format!("seq_{}", s)).collect::<Vec<_>>(),
                    "sessionType": msg.session_type,
                    "readTime": msg.send_time,
                }));
            }
            let receipt_json_str = serde_json::to_string(&receipt_list).unwrap_or_default();
            let listener = self.advanced_msg_listener.clone();
            tokio::spawn(async move {
                if let Some(listener) = &listener {
                    listener.on_recv_c2c_read_receipt(receipt_json_str).await;
                }
            });
            return true;
        }

        // Reaction 事件（已处理，但暂不通过回调）
        if msg.content_type == constant::REACTION_MESSAGE_MODIFIER || msg.content_type == constant::REACTION_MESSAGE_DELETER {
            // Reaction 事件：目前不通过回调处理（可后续扩展）
            return true;
        }

        // 输入提示（typing）
        if msg.content_type == constant::TYPING {
            let mut msg_tip = String::new();
            if let Ok(json) = serde_json::from_slice::<serde_json::Value>(&msg.content) {
                if let Some(v) = json.get("msgTip").and_then(|v| v.as_str()) {
                    msg_tip = v.to_string();
                }
            }
            let typing_json = serde_json::json!({
                "conversationID": conv_id,
                "sendID": msg.send_id,
                "msgTip": msg_tip,
            });
            info!("receive message: typing: {:?}", msg);
            let typing_json_str = serde_json::to_string(&typing_json).unwrap_or_default();
            let listener = self.advanced_msg_listener.clone();
            tokio::spawn(async move {
                if let Some(listener) = &listener {
                    listener.on_recv_typing_status(typing_json_str).await;
                }
            });
            return true;
        }

        // 普通消息类型（CONTENT_TYPE_BEGIN 到 NOTIFICATION_BEGIN 之间的所有类型）
        // 包括：TEXT, PICTURE, VOICE, VIDEO, FILE, AT_TEXT, MERGER, CARD, LOCATION, CUSTOM,
        // REVOKE, TYPING, QUOTE, ADVANCED_TEXT, MARKDOWN_TEXT, CUSTOM_NOT_TRIGGER_CONVERSATION,
        // CUSTOM_ONLINE_ONLY, REACTION_MESSAGE_MODIFIER, REACTION_MESSAGE_DELETER 等
        // 注意：REVOKE, HAS_READ_RECEIPT, REACTION, TYPING 已在上面处理，这里处理其他普通消息
        if msg.content_type >= constant::CONTENT_TYPE_BEGIN && msg.content_type < constant::NOTIFICATION_BEGIN {
            // 排除已特殊处理的消息类型
            if msg.content_type != constant::REVOKE
                && msg.content_type != constant::HAS_READ_RECEIPT
                && msg.content_type != constant::REACTION_MESSAGE_MODIFIER
                && msg.content_type != constant::REACTION_MESSAGE_DELETER
                && msg.content_type != constant::TYPING
            {
                // let msg_json = self.msg_data_to_json(msg);
                // let listener = self.advanced_msg_listener.clone();
                // tokio::spawn(async move {
                //     if let Some(listener) = &listener {
                //         listener.on_recv_new_message(msg_json).await;
                //     }
                // });
                return true;
            }
        }

        // 通用消息类型（COMMON, GROUP_MSG, SIGNAL_MSG, CUSTOM_NOTIFICATION）
        if msg.content_type == constant::COMMON || msg.content_type == constant::GROUP_MSG || msg.content_type == constant::SIGNAL_MSG || msg.content_type == constant::CUSTOM_NOTIFICATION {
            return true;
        }

        // 通知消息类型（NOTIFICATION_BEGIN 到 NOTIFICATION_END 之间的所有类型）
        // 包括：好友通知、用户通知、群组通知、会话通知等
        if msg.content_type >= constant::NOTIFICATION_BEGIN && msg.content_type <= constant::NOTIFICATION_END {
            // 排除已特殊处理的通知类型（HAS_READ_RECEIPT）
            if msg.content_type != constant::HAS_READ_RECEIPT {
                return true;
            }
        }

        // 未处理的消息类型（会触发 warn 日志）
        false
    }

    /// 标记所有会话为已读
    pub async fn mark_all_conversation_message_as_read(&self) -> Result<()> {
        let url = format!("{}/msg/mark_all_conversation_as_read", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        info!("[Client] 📡 标记所有会话已读");

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&serde_json::json!({
                "userID": self.config.user_id,
            }))
            .send()
            .await?;

        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            error!("[Client] 标记所有会话已读请求失败，HTTP状态: {}, 响应: {}", status, text);
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }

        let json_value: serde_json::Value = serde_json::from_str(&text)?;
        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value.get("errMsg").and_then(|v| v.as_str()).unwrap_or("未知错误");
                error!("[Client] 标记所有会话已读服务器错误，错误码: {}, 错误信息: {}", err_code, err_msg);
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client] ✅ 标记所有会话已读成功");
        Ok(())
    }

    // ===================== 消息管理相关 HTTP 能力 =====================

    /// 删除消息（按会话 ID + 多个 seq）
    pub async fn delete_messages(&self, conversation_id: String, seqs: Vec<i64>) -> Result<()> {
        let url = format!("{}/msg/delete_msgs", self.config.api_base_url);
        let operation_id = format!("{}", chrono::Utc::now().timestamp_millis());

        let req_json = serde_json::json!({
            "conversationID": conversation_id,
            "seqs": seqs,
            "userID": self.config.user_id,
        });

        info!("[Client] 📡 删除消息: conversationID={}", conversation_id);

        let resp = reqwest::Client::new()
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await?;

        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            error!("[Client] 删除消息请求失败，HTTP状态: {}, 响应: {}", status, text);
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }

        let json_value: serde_json::Value = serde_json::from_str(&text)?;
        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value.get("errMsg").and_then(|v| v.as_str()).unwrap_or("未知错误");
                error!("[Client] 删除消息服务器错误，错误码: {}, 错误信息: {}", err_code, err_msg);
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        info!("[Client] ✅ 删除消息成功");
        Ok(())
    }
}