//! Listener → SdkEvent → mpsc channel → Dart Stream
//!
//! 实现所有 listener trait，注册到各模块的 set_xxx_listener()。

use super::connection::ConnectionListener;
use super::conversation::ConversationListener;
use super::friend::FriendListener;
use super::group::GroupListener;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::conversation::Conversation;
use std::sync::Arc;
use tokio::sync::mpsc;

/// bridge 实现者：实现所有 listener trait，事件转 SdkEvent → mpsc
pub struct BridgeImpl {
    tx: mpsc::UnboundedSender<SdkEvent>,
}

impl BridgeImpl {
    fn new(tx: mpsc::UnboundedSender<SdkEvent>) -> Self { Self { tx } }
}

impl ConnectionListener for BridgeImpl {
    fn on_connecting(&self) { let _ = self.tx.send(SdkEvent::Connecting); }
    fn on_connected(&self) { let _ = self.tx.send(SdkEvent::Connected); }
    fn on_disconnected(&self, reason: &str) { let _ = self.tx.send(SdkEvent::Disconnected { reason: reason.to_string() }); }
    fn on_kicked_offline(&self, reason: &str) { let _ = self.tx.send(SdkEvent::KickedOffline { reason: reason.to_string() }); }
    fn on_token_expired(&self) { let _ = self.tx.send(SdkEvent::TokenExpired); }
    fn on_reconnecting(&self, attempt: u32, max_attempts: u32) { let _ = self.tx.send(SdkEvent::Reconnecting { attempt, max_attempts }); }
    fn on_login_success(&self, user_id: &str) { let _ = self.tx.send(SdkEvent::LoginSuccess { user_id: user_id.to_string() }); }
    fn on_logout(&self) { let _ = self.tx.send(SdkEvent::Logout); }
}

impl ConversationListener for BridgeImpl {
    fn on_changed(&self, c: &[Conversation]) { let _ = self.tx.send(SdkEvent::ConversationChanged { conversations: c.to_vec() }); }
    fn on_deleted(&self, ids: &[String]) { let _ = self.tx.send(SdkEvent::ConversationDeleted { conversation_ids: ids.to_vec() }); }
    fn on_total_unread_count_changed(&self, count: i64) { let _ = self.tx.send(SdkEvent::TotalUnreadCountChanged { count }); }
    fn on_sync_started(&self) { let _ = self.tx.send(SdkEvent::SyncStarted); }
    fn on_sync_finished(&self) { let _ = self.tx.send(SdkEvent::SyncFinished); }
    fn on_sync_failed(&self, error: &str) { let _ = self.tx.send(SdkEvent::SyncFailed { error: error.to_string() }); }
    fn on_sync_progress(&self, progress: i32, message: &str) { let _ = self.tx.send(SdkEvent::SyncProgress { progress: progress as u8, message: message.to_string() }); }
    fn on_user_input_status_changed(&self, conversation_id: &str, user_id: &str, platform_ids: &[i32]) {
        let _ = self.tx.send(SdkEvent::ConversationUserInputStatusChanged {
            data: crate::domain::event::types::InputStatusChangedData {
                conversation_id: conversation_id.to_string(),
                user_id: user_id.to_string(),
                platform_ids: platform_ids.to_vec(),
            },
        });
    }
}

impl FriendListener for BridgeImpl {
    fn on_added(&self, fs: &[crate::domain::model::friend::FriendInfo]) { let _ = self.tx.send(SdkEvent::FriendAdded { friends: fs.to_vec() }); }
    fn on_deleted(&self, id: &str) { let _ = self.tx.send(SdkEvent::FriendDeleted { friend_id: id.to_string() }); }
    fn on_black_added(&self, id: &str) { let _ = self.tx.send(SdkEvent::BlackAdded { user_id: id.to_string() }); }
    fn on_black_deleted(&self, id: &str) { let _ = self.tx.send(SdkEvent::BlackDeleted { black_id: id.to_string() }); }
}

impl GroupListener for BridgeImpl {
    fn on_joined_group_added(&self, g: &crate::domain::model::group::GroupInfo) { let _ = self.tx.send(SdkEvent::JoinedGroupAdded { group: g.clone() }); }
    fn on_joined_group_deleted(&self, g: &crate::domain::model::group::GroupInfo) { let _ = self.tx.send(SdkEvent::JoinedGroupDeleted { group: g.clone() }); }
    fn on_group_info_changed(&self, g: &crate::domain::model::group::GroupInfo) { let _ = self.tx.send(SdkEvent::GroupInfoChanged { group_id: g.group_id.clone() }); }
    fn on_group_read_receipt(&self, r: &[crate::domain::event::types::GroupReadReceipt]) { let _ = self.tx.send(SdkEvent::GroupReadReceipt { receipts: r.to_vec() }); }
}

/// 创建 bridge，通过 mpsc → Dart stream
pub fn start_event_stream() -> (mpsc::UnboundedReceiver<SdkEvent>, Arc<BridgeImpl>) {
    let (tx, rx) = mpsc::unbounded_channel();
    let bridge = Arc::new(BridgeImpl::new(tx));
    (rx, bridge)
}
