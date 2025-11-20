use crate::im::auth::LoginResponse;
use crate::im::types::MessageEvent;
use crate::im::client::{OpenIMClient, ClientConfig};
use crate::frb_generated::StreamSink;
use anyhow::Result;

/// OpenIM 客户端桥接器
/// 
/// 这是一个面向 Dart 的桥接客户端，通过 flutter_rust_bridge 暴露给 Flutter/Dart。
/// 内部封装了 OpenIMClient 核心逻辑，提供简洁的 API。
#[derive(Clone)]
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
    pub async fn login_async(area_code: String, phone_number: String, password: String, platform: i32) -> Result<LoginResponse, String> {
        crate::im::auth::login_async(area_code, phone_number, password, platform).await
    }
    /// 连接到服务器
    /// 
    /// 建立 WebSocket 连接并启动消息监听。
    /// 连接成功后会自动启动心跳和消息处理任务。
    pub async fn connect(&mut self) -> Result<()> {
        self.inner.connect().await
    }

    /// 发送文本消息
    /// 
    /// # 参数
    /// - `recv_id`: 接收者 ID
    /// - `text`: 消息文本内容
    /// - `session_type`: 会话类型（1=单聊, 2=群聊）
    pub async fn send_text_message(
        &self,
        recv_id: String,
        text: String,
        session_type: i32,
    ) -> Result<()> {
        self.inner.send_text_message(recv_id, text, session_type).await
    }

    /// 订阅消息事件
    /// 
    /// 订阅客户端内部的消息事件流。
    /// 在 Dart 端会返回一个 Stream<MessageEvent>，持续接收事件直到连接断开。
    /// 
    /// # 事件类型
    /// - `NewMessage`: 收到新消息，包含完整的 MessageData
    /// - `SendMessageResponse`: 消息发送响应
    /// - `KickedOffline`: 被踢下线
    /// - `ConnectionStatus`: 连接状态变化
    /// - `Other`: 其他消息
    /// 
    /// # Dart 使用示例
    /// ```dart
    /// final stream = client.subscribeMessages();
    /// stream.listen((event) {
    ///   if (event is NewMessage) {
    ///     print('收到消息: ${event.message.sendId} -> ${event.message.recvId}');
    ///   }
    /// });
    /// ```
    pub fn subscribe_messages(&self, _sink: StreamSink<MessageEvent>) {
       
        // 这里只是个示例，假设 self.inner 有 subscribe_messages() 返回 Receiver<MessageEvent>
        // 实际使用时应该考虑跨线程/跨运行时的处理方式并且避免阻塞
        // 此桥接简单示意如何把内部消息通过 sink 推送到 Dart 层
        // 目前假设 sink: StreamSink<MessageEvent> + Send + 'static
        let mut receiver = self.inner.subscribe_messages();
        // 这里假定你在外部用 tokio runtime 启了环境
        tokio::spawn(async move {
            while let Some(event) = receiver.recv().await {
                // 忽略 send 错误（比如 Dart 端 Stream 已关闭）
                let _ = _sink.add(event);
            }
        });

    }
}

