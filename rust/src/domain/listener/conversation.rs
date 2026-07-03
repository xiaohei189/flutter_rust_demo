use crate::domain::model::conversation::Conversation;
use super::ListenerSet;

/// 会话事件（替代 SdkEvent::ConversationChanged/NewConversation/...）
pub struct ConversationListener {
    pub on_changed: ListenerSet<Vec<Conversation>>,
    pub on_deleted: ListenerSet<Vec<String>>,
    pub on_new: ListenerSet<Vec<Conversation>>,
    pub on_total_unread_count_changed: ListenerSet<i64>,
    pub on_sync_started: ListenerSet<()>,
    pub on_sync_finished: ListenerSet<()>,
    pub on_sync_failed: ListenerSet<String>,
    pub on_sync_progress: ListenerSet<(i32, String)>,
    pub on_user_input_status_changed: ListenerSet<(String, String, Vec<i32>)>,
}

impl ConversationListener {
    pub fn new() -> Self {
        Self {
            on_changed: ListenerSet::new(),
            on_deleted: ListenerSet::new(),
            on_new: ListenerSet::new(),
            on_total_unread_count_changed: ListenerSet::new(),
            on_sync_started: ListenerSet::new(),
            on_sync_finished: ListenerSet::new(),
            on_sync_failed: ListenerSet::new(),
            on_sync_progress: ListenerSet::new(),
            on_user_input_status_changed: ListenerSet::new(),
        }
    }
}
