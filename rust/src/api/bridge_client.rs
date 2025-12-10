use crate::im::auth::LoginResponse;
use crate::im::types::MessageEvent;
use crate::im::client::{OpenIMClient, ClientConfig};
use crate::im::conversation::LocalConversation;
use crate::im::friend::LocalFriend;
use crate::api::listeners::{BridgeConversationListener, BridgeFriendListener};
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
    // login
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
    /// 
    /// 注意：此方法已废弃，请使用 `set_advanced_msg_listener` 设置回调监听器
    #[deprecated(note = "请使用 set_advanced_msg_listener 设置回调监听器")]
    pub fn subscribe_messages(&self, _sink: StreamSink<MessageEvent>) {
        // 已移除 subscribe_messages，请使用 AdvancedMsgListener 回调方式
        // TODO: 如果需要 Dart 桥接，可以通过 AdvancedMsgListener 实现
    }

    /// 注册会话监听（回调流）
    ///
    /// - `conv_sink`: 会话相关事件（JSON 字符串），包括同步进度、新会话、会话变更、输入状态等
    /// - `unread_sink`: 总未读数变化（整型）
    pub fn register_conversation_listener(
        &mut self,
        conv_sink: Option<StreamSink<String>>,
        unread_sink: Option<StreamSink<i32>>,
    ) {
        use crate::im::conversation::ConversationSyncerConfig;
        use crate::im::conversation::ConversationSyncer;
        use std::sync::Arc;

        let cfg = ConversationSyncerConfig {
            user_id: self.inner.config.user_id.clone(),
            api_base_url: self.inner.config.api_base_url.clone(),
            token: self.inner.config.token.clone(),
            db_path: self.inner.config.conversation_db_url.clone(),
        };
        let listener = Arc::new(BridgeConversationListener::new(conv_sink, unread_sink));

        // 重建会话同步器并替换监听器
        let rt = tokio::runtime::Handle::current();
        let client = &mut self.inner;
        rt.block_on(async {
            if let Ok(syncer) = ConversationSyncer::with_listener(cfg, listener).await {
                client.conversation_syncer = Some(Arc::new(syncer));
            }
        });
    }

    /// 注册好友监听（回调流）
    ///
    /// - `friend_sink`: 好友列表变化（JSON 数组）
    /// - `black_sink`: 黑名单列表变化（JSON 数组）
    /// - `request_sink`: 好友申请列表变化（JSON 数组）
    pub fn register_friend_listener(
        &mut self,
        friend_sink: Option<StreamSink<String>>,
        black_sink: Option<StreamSink<String>>,
        request_sink: Option<StreamSink<String>>,
    ) {
        use crate::im::friend::{FriendSyncer, FriendSyncerConfig};
        use std::sync::Arc;

        let cfg = FriendSyncerConfig {
            user_id: self.inner.config.user_id.clone(),
            api_base_url: self.inner.config.api_base_url.clone(),
            token: self.inner.config.token.clone(),
            db_path: self.inner.config.conversation_db_url.clone(),
        };
        let listener =
            Arc::new(BridgeFriendListener::new(friend_sink, black_sink, request_sink));

        let rt = tokio::runtime::Handle::current();
        let client = &mut self.inner;
        rt.block_on(async {
            if let Ok(syncer) = FriendSyncer::with_listener(cfg, listener).await {
                client.friend_syncer = Some(Arc::new(syncer));
            }
        });
    }

    /// 获取会话列表（分页）
    pub async fn get_conversation_list(
        &self,
        offset: i64,
        count: i64,
    ) -> Result<Vec<LocalConversation>> {
        self.inner
            .get_conversation_list(offset as usize, count as usize)
            .await
    }

    /// 获取所有会话列表
    pub async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        self.inner.get_all_conversations().await
    }

    /// 获取所有好友列表
    pub async fn get_all_friends(&self) -> Result<Vec<LocalFriend>> {
        self.inner.get_all_friends().await
    }

    // ===================== 消息发送（多媒体） =====================

    /// 发送图片消息
    pub async fn send_picture_message(
        &self,
        recv_id: String,
        picture: crate::im::msg::PictureElem,
        session_type: i32,
    ) -> Result<()> {
        self.inner
            .send_picture_message(recv_id, picture, session_type)
            .await
    }

    /// 发送语音消息
    pub async fn send_sound_message(
        &self,
        recv_id: String,
        sound: crate::im::msg::SoundElem,
        session_type: i32,
    ) -> Result<()> {
        self.inner
            .send_sound_message(recv_id, sound, session_type)
            .await
    }

    /// 发送视频消息
    pub async fn send_video_message(
        &self,
        recv_id: String,
        video: crate::im::msg::VideoElem,
        session_type: i32,
    ) -> Result<()> {
        self.inner
            .send_video_message(recv_id, video, session_type)
            .await
    }

    /// 发送文件消息
    pub async fn send_file_message(
        &self,
        recv_id: String,
        file: crate::im::msg::FileElem,
        session_type: i32,
    ) -> Result<()> {
        self.inner
            .send_file_message(recv_id, file, session_type)
            .await
    }

    // ===================== 消息管理（HTTP） =====================

    /// 撤回消息
    pub async fn revoke_message(
        &self,
        conversation_id: String,
        seq: i64,
    ) -> Result<()> {
        self.inner.revoke_message(conversation_id, seq).await
    }

    /// 删除消息
    pub async fn delete_messages(
        &self,
        conversation_id: String,
        seqs: Vec<i64>,
    ) -> Result<()> {
        self.inner.delete_messages(conversation_id, seqs).await
    }

    /// 清空会话消息
    pub async fn clear_conversation_msgs(
        &self,
        conversation_ids: Vec<String>,
    ) -> Result<()> {
        self.inner.clear_conversation_msgs(conversation_ids).await
    }

    /// 标记会话为已读
    pub async fn mark_conversation_as_read(
        &self,
        conversation_id: String,
        has_read_seq: i64,
        seqs: Vec<i64>,
    ) -> Result<()> {
        self.inner
            .mark_conversation_as_read(conversation_id, has_read_seq, seqs)
            .await
    }
}

