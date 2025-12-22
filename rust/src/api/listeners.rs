use async_trait::async_trait;
use crate::im::conversation::listener::ConversationListener;
use crate::im::message::listener::AdvancedMsgListener;
use crate::frb_generated::StreamSink;
use serde::{Deserialize, Serialize};

/// 连接状态事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectionStatusEvent {
    pub connected: bool,
    pub message: String,
}

/// 新消息事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NewMessageEvent {
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
        let event = ConversationChangedEvent {
            conversation_list,
        };
        let _ = self.sink.add(event);
    }

    async fn on_conversation_changed(&self, conversation_list: String) {
        let event = ConversationChangedEvent {
            conversation_list,
        };
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
pub struct DartAdvancedMsgListener {
    pub message_sink: StreamSink<NewMessageEvent>,
    pub connection_sink: StreamSink<ConnectionStatusEvent>,
}

impl DartAdvancedMsgListener {
    pub fn new(
        message_sink: StreamSink<NewMessageEvent>,
        connection_sink: StreamSink<ConnectionStatusEvent>,
    ) -> Self {
        Self {
            message_sink,
            connection_sink,
        }
    }
}

#[async_trait]
impl AdvancedMsgListener for DartAdvancedMsgListener {
    async fn on_recv_new_message(&self, message: String) {
        let event = NewMessageEvent { message };
        let _ = self.message_sink.add(event);
    }

    async fn on_recv_c2c_read_receipt(&self, _msg_receipt_list: String) {
        // 可以发送已读回执事件
    }

    async fn on_new_recv_message_revoked(&self, _message_revoked: String) {
        // 可以发送消息撤回事件
    }

    async fn on_recv_offline_new_message(&self, message: String) {
        let event = NewMessageEvent { message };
        let _ = self.message_sink.add(event);
    }

    async fn on_msg_deleted(&self, _message: String) {
        // 可以发送消息删除事件
    }

    async fn on_recv_online_only_message(&self, message: String) {
        let event = NewMessageEvent { message };
        let _ = self.message_sink.add(event);
    }

    async fn on_kicked_offline(&self) {
        let event = ConnectionStatusEvent {
            connected: false,
            message: "被踢下线".to_string(),
        };
        let _ = self.connection_sink.add(event);
    }

    async fn on_connection_status_changed(&self, connected: bool, message: String) {
        let event = ConnectionStatusEvent { connected, message };
        let _ = self.connection_sink.add(event);
    }

    async fn on_recv_typing_status(&self, _typing_info: String) {
        // 可以发送输入状态事件
    }
}

