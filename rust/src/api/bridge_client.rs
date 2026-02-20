//! IM 客户端 Flutter 桥接层
//!
//! 按 flutter_rust_bridge_codegen 要求将 IMClient 暴露为 Flutter API。
//! 使用 RustOpaque 包装 IMClient，通过 #[frb] 注解暴露方法。

use crate::im::client::client::{ClientConfig, IMClient};
use crate::im::http_client::auth::LoginData;
use crate::im::model::conversation::LocalConversation;
use crate::im::model::message::{
    GetAdvancedHistoryMessageListCallback, GetAdvancedHistoryMessageListParams,
};
use anyhow::Result;
use openim_protocol::constant;
use std::sync::Arc;
use tokio::sync::RwLock;

/// 登录接口
///
/// 参考 openim-cli 的实现，先登录获取 token 信息
#[flutter_rust_bridge::frb]
pub async fn login_async(
    area_code: String,
    phone_number: String,
    password: String,
    platform: i32,
) -> Result<LoginData> {
    crate::im::http_client::auth::login_async(area_code, phone_number, password, platform).await
}

/// OpenIM 桥接客户端，包装 IMClient 供 Flutter 使用
///
/// 使用 #[frb(opaque)] 使该结构体在 Dart 端为不透明句柄，
/// 仅能通过暴露的方法进行操作。
#[flutter_rust_bridge::frb(opaque)]
pub struct OpenIMBridgeClient {
    inner: Arc<RwLock<IMClient>>,
}

impl OpenIMBridgeClient {
    /// 创建新的客户端实例
    ///
    /// # 参数
    /// - `user_id`: 用户 ID
    /// - `token`: 认证 token（从登录接口获取）
    /// - `platform_id`: 平台 ID（例如：5 表示 Web）
    /// - `ws_url`: WebSocket 服务器 URL（可选，默认使用 localhost:10001）
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(
        user_id: String,
        token: String,
        platform_id: i32,
        ws_url: Option<String>,
    ) -> Result<Self> {
        let mut config = ClientConfig::new(user_id, token, platform_id);
        if let Some(url) = ws_url {
            config.ws_url = url;
        }
        config.conversation_db_url = format!(
            "sqlite://{}/conversations_{}.db?mode=rwc",
            std::env::temp_dir().as_path().to_string_lossy(),
            config.user_id
        );
        let client = tokio::task::block_in_place(|| {
            tokio::runtime::Handle::current().block_on(IMClient::new(config))
        })?;
        Ok(Self {
            inner: Arc::new(RwLock::new(client)),
        })
    }

    /// 连接到服务器
    ///
    /// 建立 WebSocket 连接并启动消息监听。
    #[flutter_rust_bridge::frb]
    pub async fn connect(&self) -> Result<()> {
        self.inner.write().await.start().await
    }

    /// 获取所有会话列表
    #[flutter_rust_bridge::frb]
    pub async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        self.inner.read().await.get_all_conversations().await
    }

    /// 获取高级历史消息列表（完全参考 Go SDK 的 GetAdvancedHistoryMessageList）
    #[flutter_rust_bridge::frb]
    pub async fn get_advanced_history_message_list(
        &self,
        req: GetAdvancedHistoryMessageListParams,
    ) -> Result<GetAdvancedHistoryMessageListCallback> {
        self.inner
            .read()
            .await
            .get_advanced_history_message_list(req)
            .await
    }

    /// 获取高级历史消息列表（反向，完全参考 Go SDK 的 GetAdvancedHistoryMessageListReverse）
    #[flutter_rust_bridge::frb]
    pub async fn get_advanced_history_message_list_reverse(
        &self,
        req: GetAdvancedHistoryMessageListParams,
    ) -> Result<GetAdvancedHistoryMessageListCallback> {
        self.inner
            .read()
            .await
            .get_advanced_history_message_list_reverse(req)
            .await
    }

    /// 发送文本消息
    /// - `recv_id`: 接收者 ID（单聊为用户 ID，群聊为群组 ID）
    /// - `text`: 消息内容
    /// - `session_type`: 会话类型，1=单聊，3=群聊
    #[flutter_rust_bridge::frb]
    pub async fn send_text_message(
        &self,
        recv_id: String,
        text: String,
        session_type: i32,
    ) -> Result<()> {
        let client = self.inner.read().await;
        if session_type == constant::READ_GROUP_CHAT_TYPE {
            client.send_text_to_group(recv_id, text).await?;
        } else {
            client.send_text_message(recv_id, text).await?;
        }
        Ok(())
    }
}
