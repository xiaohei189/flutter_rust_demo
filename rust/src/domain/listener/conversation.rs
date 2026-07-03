use crate::domain::model::conversation::Conversation;
use super::ListenerSet;

/// conversation 事件（对齐 Go SDK ConversationListener）
pub trait ConversationListener: Send + Sync {
    fn on_changed(&self, _conversations: &[Conversation]) {}
    fn on_deleted(&self, _ids: &[String]) {}
    fn on_new(&self, _conversations: &[Conversation]) {}
    fn on_total_unread_count_changed(&self, _count: i64) {}
    fn on_sync_started(&self) {}
    fn on_sync_finished(&self) {}
    fn on_sync_failed(&self, _error: &str) {}
    fn on_sync_progress(&self, _progress: i32, _message: &str) {}
    fn on_user_input_status_changed(&self, _conversation_id: &str, _user_id: &str, _platform_ids: &[i32]) {}
}

// === 以下为旧 ListenerSet 模式，逐步迁移后删除 ===

pub struct ConversationListeners {
    pub pub on_changed: ListenerSet<Vec<Conversation>>,
    pub on_deleted: ListenerSet<Vec<String>>,
    pub on_new: ListenerSet<Vec<Conversation>>,
    pub on_total_unread_count_changed: ListenerSet<i64>,
    pub on_sync_started: ListenerSet<()>,
    pub on_sync_finished: ListenerSet<()>,
    pub on_sync_failed: ListenerSet<String>,
    pub on_sync_progress: ListenerSet<(i32, String)>,
    pub on_user_input_status_changed: ListenerSet<(String, String, Vec<i32>)>,
}

impl ConversationListeners {
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
