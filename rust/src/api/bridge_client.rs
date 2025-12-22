use anyhow::Result;
use crate::im::client::{ClientConfig, OpenIMClient};
use crate::im::auth::LoginResponse;
use crate::api::listeners::{
    DartConversationListener, DartAdvancedMsgListener,
    ConnectionStatusEvent, MessageEvent, ConversationChangedEvent,
};
use crate::frb_generated::StreamSink;
use std::sync::Arc;

/// OpenIM 客户端桥接器
/// 
/// 这是一个面向 Dart 的桥接客户端，通过 flutter_rust_bridge 暴露给 Flutter/Dart。
/// 内部封装了 OpenIMClient 核心逻辑，提供简洁的 API。
pub struct OpenIMBridgeClient {
    inner: OpenIMClient,
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
    pub fn new(
        user_id: String,
        token: String,
        platform_id: i32,
        ws_url: Option<String>,
    ) -> Self {
        let mut config = ClientConfig::new(user_id, token, platform_id);
        if let Some(url) = ws_url {
            config.ws_url = url;
        }
        
        Self {
            inner: OpenIMClient::new(config),
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
    /// 监听消息和连接状态事件，通过 StreamSink 发送到 Dart
    pub fn message_event(
        &mut self,
        message_sink: StreamSink<MessageEvent>,
    ) {
        let listener = Arc::new(DartAdvancedMsgListener::new(message_sink));
        self.inner.set_advanced_msg_listener(listener);
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

