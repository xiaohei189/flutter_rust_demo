//! 会话监听器

use crate::frb_generated::StreamSink;
use crate::im::conversation::listener::ConversationListener;
use crate::im::types::LocalConversation;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json;

/// 会话事件枚举，包含所有会话相关的回调事件
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ConversationEvent {
    /// 同步服务器开始
    SyncServerStart {
        reinstalled: bool,
    },
    /// 同步服务器完成
    SyncServerFinish {
        reinstalled: bool,
    },
    /// 同步服务器进度
    SyncServerProgress {
        progress: i32,
    },
    /// 同步服务器失败
    SyncServerFailed {
        reinstalled: bool,
    },
    /// 新会话
    NewConversation {
        conversation_list: Vec<LocalConversation>,
    },
    /// 会话变更
    ConversationChanged {
        conversation_list: Vec<LocalConversation>,
    },
    /// 总未读消息数变更
    TotalUnreadMessageCountChanged {
        total_unread_count: i32,
    },
    /// 会话用户输入状态变更
    ConversationUserInputStatusChanged {
        change: String, // JSON 字符串
    },
}

/// 会话监听器（桥接到 Dart）
pub struct DartConversationListener {
    pub sink: StreamSink<ConversationEvent>,
}

impl DartConversationListener {
    pub fn new(sink: StreamSink<ConversationEvent>) -> Self {
        Self { sink }
    }
}

#[async_trait]
impl ConversationListener for DartConversationListener {
    async fn on_sync_server_start(&self, reinstalled: bool) {
        let event = ConversationEvent::SyncServerStart { reinstalled };
        let _ = self.sink.add(event);
    }

    async fn on_sync_server_finish(&self, reinstalled: bool) {
        let event = ConversationEvent::SyncServerFinish { reinstalled };
        let _ = self.sink.add(event);
    }

    async fn on_sync_server_progress(&self, progress: i32) {
        let event = ConversationEvent::SyncServerProgress { progress };
        let _ = self.sink.add(event);
    }

    async fn on_sync_server_failed(&self, reinstalled: bool) {
        let event = ConversationEvent::SyncServerFailed { reinstalled };
        let _ = self.sink.add(event);
    }

    async fn on_new_conversation(&self, conversation_list: String) {
        // 解析 JSON 字符串为 Vec<LocalConversation>
        let conversations: Vec<LocalConversation> = serde_json::from_str(&conversation_list)
            .unwrap_or_default();
        let event = ConversationEvent::NewConversation {
            conversation_list: conversations,
        };
        let _ = self.sink.add(event);
    }

    async fn on_conversation_changed(&self, conversation_list: String) {
        // 解析 JSON 字符串为 Vec<LocalConversation>
        let conversations: Vec<LocalConversation> = serde_json::from_str(&conversation_list)
            .unwrap_or_default();
        let event = ConversationEvent::ConversationChanged {
            conversation_list: conversations,
        };
        let _ = self.sink.add(event);
    }

    async fn on_total_unread_message_count_changed(&self, total_unread_count: i32) {
        let event = ConversationEvent::TotalUnreadMessageCountChanged {
            total_unread_count,
        };
        let _ = self.sink.add(event);
    }

    async fn on_conversation_user_input_status_changed(&self, change: String) {
        let event = ConversationEvent::ConversationUserInputStatusChanged { change };
        let _ = self.sink.add(event);
    }
}

