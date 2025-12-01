use crate::im::conversation::ConversationListener;
use crate::im::friend::FriendListener;
use crate::frb_generated::StreamSink;
use async_trait::async_trait;
use tracing::debug;

/// 桥接到 Dart 的会话监听器实现
pub struct BridgeConversationListener {
    /// Dart 侧的会话事件流（JSON 字符串）
    pub conv_sink: Option<StreamSink<String>>,
    /// Dart 侧的总未读数事件流（整型）
    pub unread_sink: Option<StreamSink<i32>>,
}

impl BridgeConversationListener {
    pub fn new(
        conv_sink: Option<StreamSink<String>>,
        unread_sink: Option<StreamSink<i32>>,
    ) -> Self {
        Self {
            conv_sink,
            unread_sink,
        }
    }
}

#[async_trait]
impl ConversationListener for BridgeConversationListener {
    async fn on_sync_server_start(&self, reinstalled: bool) {
        if let Some(sink) = &self.conv_sink {
            let _ = sink.add(format!(r#"{{"type":"sync_start","reinstalled":{}}}"#, reinstalled));
        }
    }

    async fn on_sync_server_finish(&self, reinstalled: bool) {
        if let Some(sink) = &self.conv_sink {
            let _ = sink.add(format!(r#"{{"type":"sync_finish","reinstalled":{}}}"#, reinstalled));
        }
    }

    async fn on_sync_server_progress(&self, progress: i32) {
        if let Some(sink) = &self.conv_sink {
            let _ = sink.add(format!(r#"{{"type":"sync_progress","progress":{}}}"#, progress));
        }
    }

    async fn on_sync_server_failed(&self, reinstalled: bool) {
        if let Some(sink) = &self.conv_sink {
            let _ = sink.add(format!(r#"{{"type":"sync_failed","reinstalled":{}}}"#, reinstalled));
        }
    }

    async fn on_new_conversation(&self, conversation_list: String) {
        if let Some(sink) = &self.conv_sink {
            // 直接把服务端传来的 JSON 包一层 type，避免再次解析
            let payload = format!(
                r#"{{"type":"new_conversation","conversations":{}}}"#,
                conversation_list
            );
            let _ = sink.add(payload);
        }
    }

    async fn on_conversation_changed(&self, conversation_list: String) {
        if let Some(sink) = &self.conv_sink {
            let payload = format!(
                r#"{{"type":"conversation_changed","conversations":{}}}"#,
                conversation_list
            );
            let _ = sink.add(payload);
        }
    }

    async fn on_total_unread_message_count_changed(&self, total_unread_count: i32) {
        if let Some(sink) = &self.unread_sink {
            let _ = sink.add(total_unread_count);
        } else if let Some(conv_sink) = &self.conv_sink {
            // 如果没有单独的 unread sink，就通过会话事件流透出
            let payload = format!(
                r#"{{"type":"total_unread_changed","totalUnread":{}}}"#,
                total_unread_count
            );
            let _ = conv_sink.add(payload);
        }
    }

    async fn on_conversation_user_input_status_changed(&self, change: String) {
        if let Some(sink) = &self.conv_sink {
            let payload = format!(
                r#"{{"type":"input_status_changed","data":{}}}"#,
                change
            );
            let _ = sink.add(payload);
        }
    }
}

/// 桥接到 Dart 的好友监听器实现
pub struct BridgeFriendListener {
    /// 好友列表变更事件流（JSON 数组）
    pub friend_sink: Option<StreamSink<String>>,
    /// 黑名单变更事件流（JSON 数组）
    pub black_sink: Option<StreamSink<String>>,
    /// 好友申请变更事件流（JSON 数组）
    pub request_sink: Option<StreamSink<String>>,
}

impl BridgeFriendListener {
    pub fn new(
        friend_sink: Option<StreamSink<String>>,
        black_sink: Option<StreamSink<String>>,
        request_sink: Option<StreamSink<String>>,
    ) -> Self {
        Self {
            friend_sink,
            black_sink,
            request_sink,
        }
    }
}

#[async_trait]
impl FriendListener for BridgeFriendListener {
    async fn on_friend_list_changed(&self, friends_json: String) {
        if let Some(sink) = &self.friend_sink {
            debug!("[BridgeFriendListener] on_friend_list_changed");
            let _ = sink.add(friends_json);
        }
    }

    async fn on_black_list_changed(&self, blacks_json: String) {
        if let Some(sink) = &self.black_sink {
            debug!("[BridgeFriendListener] on_black_list_changed");
            let _ = sink.add(blacks_json);
        }
    }

    async fn on_friend_request_list_changed(&self, requests_json: String) {
        if let Some(sink) = &self.request_sink {
            debug!("[BridgeFriendListener] on_friend_request_list_changed");
            let _ = sink.add(requests_json);
        }
    }
}


