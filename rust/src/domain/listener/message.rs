use crate::domain::event::types::{GroupReadReceipt, MessageReceipt};
use crate::domain::model::message::ReceivedMessage;
use super::ListenerSet;

/// 消息生命周期事件（NewMessage, RecvOfflineNewMessage, C2CReadReceipt, MessageRevoked 等）
pub struct MessageListener {
    pub on_new_message: ListenerSet<ReceivedMessage>,
    pub on_recv_offline_new_message: ListenerSet<Vec<ReceivedMessage>>,
    pub on_c2c_read_receipt: ListenerSet<Vec<MessageReceipt>>,
    pub on_group_read_receipt: ListenerSet<Vec<GroupReadReceipt>>,
    pub on_message_revoked: ListenerSet<ReceivedMessage>,
    pub on_messages_deleted: ListenerSet<Vec<String>>, // client_msg_ids
    pub on_send_failed: ListenerSet<(String, String)>, // (client_msg_id, error)
}

impl MessageListener {
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
