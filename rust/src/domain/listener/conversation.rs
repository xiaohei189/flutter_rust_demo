use crate::domain::model::conversation::Conversation;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum ConversationEvent {
    Changed(Vec<Conversation>),
    Deleted(Vec<String>),
    New(Vec<Conversation>),
    TotalUnreadCountChanged(i64),
    SyncStarted,
    SyncFinished,
    SyncFailed(String),
    SyncProgress { progress: i32, message: String },
    UserInputStatusChanged { conversation_id: String, user_id: String, platform_ids: Vec<i32> },
}

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

