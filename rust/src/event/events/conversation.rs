use crate::model::local::LocalConversation;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum ConversationEvent {
    Changed(Vec<LocalConversation>),
    Deleted(Vec<String>),
    New(Vec<LocalConversation>),
    TotalUnreadCountChanged(i64),
    SyncStarted,
    SyncFinished,
    SyncFailed(String),
    SyncProgress { progress: i32, message: String },
    UserInputStatusChanged { conversation_id: String, user_id: String, platform_ids: Vec<i32> },
    /// 最新消息已读状态变更（对齐 Go SDK `UpdateLatestMessageReadState`）
    UpdateLatestMessageReadState { conversation_id: String },
}

impl ConversationEvent {
    /// 事件类型字符串（用于日志与测试）
    pub fn as_str(&self) -> &'static str {
        match self {
            ConversationEvent::Changed(_) => "changed",
            ConversationEvent::Deleted(_) => "deleted",
            ConversationEvent::New(_) => "new",
            ConversationEvent::TotalUnreadCountChanged(_) => "total_unread_count_changed",
            ConversationEvent::SyncStarted => "sync_started",
            ConversationEvent::SyncFinished => "sync_finished",
            ConversationEvent::SyncFailed(_) => "sync_failed",
            ConversationEvent::SyncProgress { .. } => "sync_progress",
            ConversationEvent::UserInputStatusChanged { .. } => "user_input_status_changed",
            ConversationEvent::UpdateLatestMessageReadState { .. } => "update_latest_message_read_state",
        }
    }
}

/// conversation 事件（对齐 Go SDK ConversationListener）
pub trait ConversationListener: Send + Sync {
    fn on_changed(&self, _conversations: &[LocalConversation]) {}
    fn on_deleted(&self, _ids: &[String]) {}
    fn on_new(&self, _conversations: &[LocalConversation]) {}
    fn on_total_unread_count_changed(&self, _count: i64) {}
    fn on_sync_started(&self) {}
    fn on_sync_finished(&self) {}
    fn on_sync_failed(&self, _error: &str) {}
    fn on_sync_progress(&self, _progress: i32, _message: &str) {}
    fn on_user_input_status_changed(&self, _conversation_id: &str, _user_id: &str, _platform_ids: &[i32]) {}
    fn on_update_latest_message_read_state(&self, _conversation_id: &str) {}
}

/// 事件 → 回调 的统一分发（Service 通过它把领域事件交给 Listener）
pub trait ConversationListenerExt: ConversationListener {
    fn emit(&self, event: ConversationEvent) {
        match event {
            ConversationEvent::Changed(convs) => self.on_changed(&convs),
            ConversationEvent::Deleted(ids) => self.on_deleted(&ids),
            ConversationEvent::New(convs) => self.on_new(&convs),
            ConversationEvent::TotalUnreadCountChanged(count) => self.on_total_unread_count_changed(count),
            ConversationEvent::SyncStarted => self.on_sync_started(),
            ConversationEvent::SyncFinished => self.on_sync_finished(),
            ConversationEvent::SyncFailed(error) => self.on_sync_failed(&error),
            ConversationEvent::SyncProgress { progress, message } => self.on_sync_progress(progress, &message),
            ConversationEvent::UserInputStatusChanged { conversation_id, user_id, platform_ids } => self.on_user_input_status_changed(&conversation_id, &user_id, &platform_ids),
            ConversationEvent::UpdateLatestMessageReadState { conversation_id } => self.on_update_latest_message_read_state(&conversation_id),
        }
    }
}
impl<T: ConversationListener + ?Sized> ConversationListenerExt for T {}