use crate::domain::event::types::{GroupReadReceipt, MessageReceipt};
use crate::protocol::sdkws::MsgData;

/// message 事件（对齐 Go SDK MessageListener）
pub trait MessageListener: Send + Sync {
    fn on_new_message(&self, _message: &MsgData) {}
    fn on_recv_offline_new_message(&self, _messages: &[MsgData]) {}
    fn on_c2c_read_receipt(&self, _receipts: &[MessageReceipt]) {}
    fn on_group_read_receipt(&self, _receipts: &[GroupReadReceipt]) {}
    fn on_message_revoked(&self, _message: &MsgData) {}
    fn on_messages_deleted(&self, _conversation_id: &str, _client_msg_ids: &[String]) {}
    fn on_send_failed(&self, _client_msg_id: &str, _error: &str) {}
}

