use crate::frb_generated::StreamSink;
use crate::im::conversation::listener::ConversationListener;
use crate::im::message::listener::AdvancedMsgListener;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};

/// 连接状态事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectionStatusEvent {
    pub connected: bool,
    pub message: String,
}

/// 新消息事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageEvent {
    pub message: String, // JSON 字符串
}

/// 会话变更事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConversationChangedEvent {
    pub conversation_list: String, // JSON 字符串
}

/// 会话监听器（桥接到 Dart）
pub struct DartConversationListener {
    pub sink: StreamSink<ConversationChangedEvent>,
}

impl DartConversationListener {
    pub fn new(sink: StreamSink<ConversationChangedEvent>) -> Self {
        Self { sink }
    }
}

#[async_trait]
impl ConversationListener for DartConversationListener {
    async fn on_sync_server_start(&self, _reinstalled: bool) {
        // 可以发送同步开始事件
    }

    async fn on_sync_server_finish(&self, _reinstalled: bool) {
        // 可以发送同步完成事件
    }

    async fn on_sync_server_progress(&self, _progress: i32) {
        // 可以发送同步进度事件
    }

    async fn on_sync_server_failed(&self, _reinstalled: bool) {
        // 可以发送同步失败事件
    }

    async fn on_new_conversation(&self, conversation_list: String) {
        let event = ConversationChangedEvent { conversation_list };
        let _ = self.sink.add(event);
    }

    async fn on_conversation_changed(&self, conversation_list: String) {
        let event = ConversationChangedEvent { conversation_list };
        let _ = self.sink.add(event);
    }

    async fn on_total_unread_message_count_changed(&self, _total_unread_count: i32) {
        // 可以发送未读数变更事件
    }

    async fn on_conversation_user_input_status_changed(&self, _change: String) {
        // 可以发送输入状态变更事件
    }
}

/// 消息监听器（桥接到 Dart）
/// 使用 Arc<Mutex<Option<StreamSink>>> 以便可以分别设置两个 sink
pub struct DartAdvancedMsgListener {
    pub message_sink: Arc<Mutex<Option<StreamSink<MessageEvent>>>>,
    pub connection_sink: Arc<Mutex<Option<StreamSink<ConnectionStatusEvent>>>>,
}

impl DartAdvancedMsgListener {
    pub fn new() -> Self {
        Self {
            message_sink: Arc::new(Mutex::new(None)),
            connection_sink: Arc::new(Mutex::new(None)),
        }
    }

    /// 设置消息 sink
    pub fn set_message_sink(&self, sink: StreamSink<MessageEvent>) {
        *self.message_sink.lock().unwrap() = Some(sink);
    }

    /// 设置连接状态 sink
    pub fn set_connection_sink(&self, sink: StreamSink<ConnectionStatusEvent>) {
        *self.connection_sink.lock().unwrap() = Some(sink);
    }
}

#[async_trait]
impl AdvancedMsgListener for DartAdvancedMsgListener {
    async fn on_recv_new_message(&self, message: String) {
        let event = MessageEvent { message };
        if let Ok(sink) = self.message_sink.lock() {
            if let Some(ref s) = *sink {
                let _ = s.add(event);
            }
        }
    }

    async fn on_recv_c2c_read_receipt(&self, msg_receipt_list: String) {
        let event = MessageEvent {
            message: msg_receipt_list,
        };
        if let Ok(sink) = self.message_sink.lock() {
            if let Some(ref s) = *sink {
                let _ = s.add(event);
            }
        }
    }

    async fn on_new_recv_message_revoked(&self, message_revoked: String) {
        let event = MessageEvent {
            message: message_revoked,
        };
        if let Ok(sink) = self.message_sink.lock() {
            if let Some(ref s) = *sink {
                let _ = s.add(event);
            }
        }
    }

    async fn on_recv_offline_new_message(&self, message: String) {
        let event = MessageEvent { message };
        if let Ok(sink) = self.message_sink.lock() {
            if let Some(ref s) = *sink {
                let _ = s.add(event);
            }
        }
    }

    async fn on_msg_deleted(&self, message: String) {
        let event = MessageEvent { message };
        if let Ok(sink) = self.message_sink.lock() {
            if let Some(ref s) = *sink {
                let _ = s.add(event);
            }
        }
    }

    async fn on_recv_online_only_message(&self, message: String) {
        let event = MessageEvent { message };
        if let Ok(sink) = self.message_sink.lock() {
            if let Some(ref s) = *sink {
                let _ = s.add(event);
            }
        }
    }

    async fn on_kicked_offline(&self) {
        let event = MessageEvent {
            message: "kicked_offline".to_string(),
        };
        if let Ok(sink) = self.message_sink.lock() {
            if let Some(ref s) = *sink {
                let _ = s.add(event);
            }
        }
    }

    async fn on_connection_status_changed(&self, connected: bool, message: String) {
        let event = ConnectionStatusEvent { connected, message };
        if let Ok(sink) = self.connection_sink.lock() {
            if let Some(ref s) = *sink {
                let _ = s.add(event);
            }
        }
    }

    async fn on_recv_typing_status(&self, typing_info: String) {
        let event = MessageEvent {
            message: typing_info,
        };
        if let Ok(sink) = self.message_sink.lock() {
            if let Some(ref s) = *sink {
                let _ = s.add(event);
            }
        }
    }
}
