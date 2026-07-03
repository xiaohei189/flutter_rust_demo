use crate::domain::event::types::{GroupReadReceipt, MessageReceipt};
use crate::domain::model::message::ReceivedMessage;
use super::ListenerSet;

/// message 事件（对齐 Go SDK MessageListener）
pub trait MessageListener: Send + Sync {
    fn on_new_message(&self, _message: &ReceivedMessage) {}
    fn on_recv_offline_new_message(&self, _messages: &[ReceivedMessage]) {}
    fn on_c2c_read_receipt(&self, _receipts: &[MessageReceipt]) {}
    fn on_group_read_receipt(&self, _receipts: &[GroupReadReceipt]) {}
    fn on_message_revoked(&self, _message: &ReceivedMessage) {}
    fn on_messages_deleted(&self, _conversation_id: &str, _client_msg_ids: &[String]) {}
    fn on_send_failed(&self, _client_msg_id: &str, _error: &str) {}
}

// === 以下为旧 ListenerSet 模式，逐步迁移后删除 ===

pub struct MessageListeners {
    pub pub on_new_message: ListenerSet<ReceivedMessage>,
    pub on_recv_offline_new_message: ListenerSet<Vec<ReceivedMessage>>,
    pub on_c2c_read_receipt: ListenerSet<Vec<MessageReceipt>>,
    pub on_group_read_receipt: ListenerSet<Vec<GroupReadReceipt>>,
    pub on_message_revoked: ListenerSet<ReceivedMessage>,
    pub on_messages_deleted: ListenerSet<(String, Vec<String>)>,
    pub on_send_failed: ListenerSet<(String, String)>,
}

impl MessageListeners {
    pub fn new() -> Self {
        Self {
            on_new_message: ListenerSet::new(),
            on_recv_offline_new_message: ListenerSet::new(),
            on_c2c_read_receipt: ListenerSet::new(),
            on_group_read_receipt: ListenerSet::new(),
            on_message_revoked: ListenerSet::new(),
            on_messages_deleted: ListenerSet::new(),
            on_send_failed: ListenerSet::new(),
        }
    }
}
