use crate::api::LoginData;
use crate::api::listeners::{
    ConnectionStatusEvent, conversation::ConversationEvent, DartConnectionStatusListener,
    DartConversationListener, DartMessageListener, MessageEvent,
};
use crate::frb_generated::StreamSink;
use crate::im::auth::LoginResponse;
use crate::im::client::{ClientConfig, OpenIMClient};
use crate::im::message::listener::AdvancedMsgListener;
use crate::im::message::types::{MsgStruct, MessageRevoked, TypingStatus};
use anyhow::Result;
use async_trait::async_trait;
use serde_json;
use std::sync::Arc;

/// 内部监听器包装器，实现 AdvancedMsgListener trait
/// 直接使用最小颗粒度的监听器，不暴露给 Dart
struct ListenerWrapper {
    message_listener: Option<Arc<DartMessageListener>>,
    connection_listener: Option<Arc<DartConnectionStatusListener>>,
}

#[async_trait]
impl AdvancedMsgListener for ListenerWrapper {
    async fn on_recv_new_message(&self, message: String) {
        if let Some(ref listener) = self.message_listener {
            if let Ok(msg) = serde_json::from_str::<MsgStruct>(&message) {
                listener.send_event(MessageEvent::RecvNewMessage { message: msg });
            }
        }
    }

    async fn on_recv_c2c_read_receipt(&self, msg_receipt_list: String) {
        if let Some(ref listener) = self.message_listener {
            listener.send_event(MessageEvent::RecvC2CReadReceipt {
                msg_receipt_list,
            });
        }
    }

    async fn on_new_recv_message_revoked(&self, message_revoked: String) {
        if let Some(ref listener) = self.message_listener {
            if let Ok(revoked) = serde_json::from_str::<MessageRevoked>(&message_revoked) {
                listener.send_event(MessageEvent::NewRecvMessageRevoked {
                    message_revoked: revoked,
                });
            }
        }
    }

    async fn on_recv_offline_new_message(&self, message: String) {
        if let Some(ref listener) = self.message_listener {
            if let Ok(msg) = serde_json::from_str::<MsgStruct>(&message) {
                listener.send_event(MessageEvent::RecvOfflineNewMessage { message: msg });
            }
        }
    }

    async fn on_msg_deleted(&self, message: String) {
        if let Some(ref listener) = self.message_listener {
            if let Ok(msg) = serde_json::from_str::<MsgStruct>(&message) {
                listener.send_event(MessageEvent::MsgDeleted { message: msg });
            }
        }
    }

    async fn on_recv_online_only_message(&self, message: String) {
        if let Some(ref listener) = self.message_listener {
            if let Ok(msg) = serde_json::from_str::<MsgStruct>(&message) {
                listener.send_event(MessageEvent::RecvOnlineOnlyMessage { message: msg });
            }
        }
    }

    async fn on_kicked_offline(&self) {
        if let Some(ref listener) = self.message_listener {
            listener.send_event(MessageEvent::KickedOffline);
        }
    }

    async fn on_connection_status_changed(&self, connected: bool, message: String) {
        if let Some(ref listener) = self.connection_listener {
            listener.send_event(ConnectionStatusEvent { connected, message });
        }
    }

    async fn on_recv_typing_status(&self, typing_info: String) {
        if let Some(ref listener) = self.message_listener {
            if let Ok(typing_status) = serde_json::from_str::<TypingStatus>(&typing_info) {
                listener.send_event(MessageEvent::RecvTypingStatus {
                    typing_status,
                });
            }
        }
    }
}

/// OpenIM 客户端桥接器
///
/// 这是一个面向 Dart 的桥接客户端，通过 flutter_rust_bridge 暴露给 Flutter/Dart。
/// 内部封装了 OpenIMClient 核心逻辑，提供简洁的 API。
pub struct OpenIMBridgeClient {
    inner: OpenIMClient,
    // 维护独立的监听器
    message_listener: Option<Arc<DartMessageListener>>,
    connection_listener: Option<Arc<DartConnectionStatusListener>>,
    // 内部监听器包装器，用于实现 AdvancedMsgListener trait
    listener_wrapper: Option<Arc<ListenerWrapper>>,
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
            message_listener: None,
            connection_listener: None,
            listener_wrapper: None,
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
        #[allow(unused)] sink: StreamSink<ConversationEvent>,
    ) {
        let listener = Arc::new(DartConversationListener::new(sink));
        self.inner.set_conversation_listener(listener);
    }

    /// 设置消息监听器
    ///
    /// 监听消息事件，通过 StreamSink 发送到 Dart
    pub fn message_event(&mut self, message_sink: StreamSink<MessageEvent>) {
        // 获取或创建 listener
        let listener = if let Some(ref listener) = self.message_listener {
            listener.clone()
        } else {
            let new_listener = Arc::new(DartMessageListener::new());
            self.message_listener = Some(new_listener.clone());
            new_listener
        };

        // 设置消息 sink
        listener.set_sink(message_sink);

        // 更新内部监听器包装器
        self.update_listener_wrapper();
    }

    /// 设置连接状态监听器
    ///
    /// 监听连接状态变更事件，通过 StreamSink 发送到 Dart
    pub fn connection_event(&mut self, connection_sink: StreamSink<ConnectionStatusEvent>) {
        // 获取或创建 listener
        let listener = if let Some(ref listener) = self.connection_listener {
            listener.clone()
        } else {
            let new_listener = Arc::new(DartConnectionStatusListener::new());
            self.connection_listener = Some(new_listener.clone());
            new_listener
        };

        // 设置连接状态 sink
        listener.set_sink(connection_sink);

        // 更新内部监听器包装器
        self.update_listener_wrapper();
    }

    /// 更新内部监听器包装器
    fn update_listener_wrapper(&mut self) {
        let wrapper = Arc::new(ListenerWrapper {
            message_listener: self.message_listener.clone(),
            connection_listener: self.connection_listener.clone(),
        });
        self.listener_wrapper = Some(wrapper.clone());
        self.inner.set_advanced_msg_listener(wrapper);
    }

    /// 获取所有会话列表
    pub async fn get_all_conversations(&self) -> Result<Vec<crate::im::types::LocalConversation>> {
        self.inner.get_all_conversations().await
    }

    /// 获取高级历史消息列表（完全参考 Go SDK 的 GetAdvancedHistoryMessageList）
    ///
    /// 参数和返回值完全匹配 Go SDK
    pub async fn get_advanced_history_message_list(
        &self,
        req: crate::im::message::types::GetAdvancedHistoryMessageListParams,
    ) -> Result<crate::im::message::types::GetAdvancedHistoryMessageListCallback> {
        self.inner.get_advanced_history_message_list(req, false).await
    }

    /// 获取高级历史消息列表（反向，完全参考 Go SDK 的 GetAdvancedHistoryMessageListReverse）
    ///
    /// 参数和返回值完全匹配 Go SDK
    pub async fn get_advanced_history_message_list_reverse(
        &self,
        req: crate::im::message::types::GetAdvancedHistoryMessageListParams,
    ) -> Result<crate::im::message::types::GetAdvancedHistoryMessageListCallback> {
        self.inner.get_advanced_history_message_list(req, true).await
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
) -> Result<LoginData> {
    crate::im::auth::login_async(area_code, phone_number, password, platform).await
}
