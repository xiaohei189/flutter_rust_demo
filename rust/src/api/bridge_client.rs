use crate::api::listeners::{
    ConnectionStatusEvent, ConversationChangedEvent, DartAdvancedMsgListener,
    DartConversationListener, MessageEvent,
};
use crate::frb_generated::StreamSink;
use crate::im::auth::LoginResponse;
use crate::im::client::{ClientConfig, OpenIMClient};
use anyhow::Result;
use std::sync::Arc;

/// OpenIM 客户端桥接器
///
/// 这是一个面向 Dart 的桥接客户端，通过 flutter_rust_bridge 暴露给 Flutter/Dart。
/// 内部封装了 OpenIMClient 核心逻辑，提供简洁的 API。
pub struct OpenIMBridgeClient {
    inner: OpenIMClient,
    // 维护高级消息监听器，以便可以分别设置两个 sink
    advanced_listener: Option<Arc<DartAdvancedMsgListener>>,
}

impl OpenIMBridgeClient {
    /// 创建新的客户端实例
    ///
    /// # 参数
    /// - `user_id`: 用户 ID
    /// - `token`: 认证 token（从登录接口获取）
    /// - `platform_id`: 平台 ID（例如：5 表示 Web）
    /// - `ws_url`: WebSocket 服务器 URL（可选，默认使用 localhost:10001）
    ///
    /// # 返回
    /// 返回客户端实例
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(user_id: String, token: String, platform_id: i32, ws_url: Option<String>) -> Self {
        let mut config = ClientConfig::new(user_id, token, platform_id);
        if let Some(url) = ws_url {
            config.ws_url = url;
        }

        Self {
            inner: OpenIMClient::new(config),
            advanced_listener: None,
        }
    }

    /// 连接到服务器
    ///
    /// 建立 WebSocket 连接并启动消息监听。
    /// 连接成功后会自动启动心跳和消息处理任务。
    pub async fn connect(&mut self) -> Result<()> {
        self.inner.connect().await
    }

    /// 设置会话监听器
    ///
    /// 监听会话变更事件，通过 StreamSink 发送到 Dart
    pub fn conversation_event(
        &mut self,
        #[allow(unused)] sink: StreamSink<ConversationChangedEvent>,
    ) {
        let listener = Arc::new(DartConversationListener::new(sink));
        self.inner.set_conversation_listener(listener);
    }

    /// 设置消息监听器
    ///
    /// 监听消息事件，通过 StreamSink 发送到 Dart
    pub fn message_event(&mut self, message_sink: StreamSink<MessageEvent>) {
        // 获取或创建 listener
        let listener = if let Some(ref listener) = self.advanced_listener {
            listener.clone()
        } else {
            let new_listener = Arc::new(DartAdvancedMsgListener::new());
            self.advanced_listener = Some(new_listener.clone());
            self.inner.set_advanced_msg_listener(new_listener.clone());
            new_listener
        };

        // 设置消息 sink
        listener.set_message_sink(message_sink);
    }

    /// 设置连接状态监听器
    ///
    /// 监听连接状态变更事件，通过 StreamSink 发送到 Dart
    pub fn connection_event(&mut self, connection_sink: StreamSink<ConnectionStatusEvent>) {
        // 获取或创建 listener
        let listener = if let Some(ref listener) = self.advanced_listener {
            listener.clone()
        } else {
            let new_listener = Arc::new(DartAdvancedMsgListener::new());
            self.advanced_listener = Some(new_listener.clone());
            self.inner.set_advanced_msg_listener(new_listener.clone());
            new_listener
        };

        // 设置连接状态 sink
        listener.set_connection_sink(connection_sink);
    }

    /// 获取所有会话列表
    pub async fn get_all_conversations(&self) -> Result<Vec<crate::im::types::LocalConversation>> {
        self.inner.get_all_conversations().await
    }
}

/// 登录接口
///
/// 参考 openim-cli.rs 的实现，先登录获取 token 信息
/// 直接使用本地 im 模块的类型，无需包装
pub async fn login_async(
    area_code: String,
    phone_number: String,
    password: String,
    platform: i32,
) -> Result<LoginResponse, String> {
    crate::im::auth::login_async(area_code, phone_number, password, platform).await
}
