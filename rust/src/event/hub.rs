//! 事件中枢（EventHub）
//!
//! SDK 内唯一的 Listener 实现：Service 通过 `Arc<dyn XxxListener>` 发出事件，
//! EventHub 将这些回调转发到各领域 mpsc 通道，作为 Dart StreamSink 的数据源。
//! 未来外部 SDK 接入时，同样只需实现对应的 Listener trait。

use crate::model::friend::FriendInfo;
use crate::model::group::GroupInfo;
use crate::model::local::LocalConversation;
use crate::model::user::UserInfo;
use crate::event::events::connection::{ConnectionEvent, ConnectionListener};
use crate::event::events::conversation::{ConversationEvent, ConversationListener};
use crate::event::events::friend::{FriendEvent, FriendListener};
use crate::event::events::group::{GroupEvent, GroupListener};
use crate::event::events::message::{GroupReadReceipt, MessageEvent, MessageListener, MessageReceipt};
use crate::event::events::user::{UserEvent, UserListener};
use openim_protocol::sdkws::MsgData;
use std::sync::{Arc, Mutex};
use tokio::sync::mpsc::{unbounded_channel, UnboundedReceiver, UnboundedSender};

/// 事件中枢 — 实现全部 Listener trait，转发到领域事件通道
pub struct EventHub {
    conn_tx: UnboundedSender<ConnectionEvent>,
    conv_tx: UnboundedSender<ConversationEvent>,
    friend_tx: UnboundedSender<FriendEvent>,
    group_tx: UnboundedSender<GroupEvent>,
    user_tx: UnboundedSender<UserEvent>,
    message_tx: UnboundedSender<MessageEvent>,
    conn_rx: Mutex<Option<UnboundedReceiver<ConnectionEvent>>>,
    conv_rx: Mutex<Option<UnboundedReceiver<ConversationEvent>>>,
    friend_rx: Mutex<Option<UnboundedReceiver<FriendEvent>>>,
    group_rx: Mutex<Option<UnboundedReceiver<GroupEvent>>>,
    user_rx: Mutex<Option<UnboundedReceiver<UserEvent>>>,
    message_rx: Mutex<Option<UnboundedReceiver<MessageEvent>>>,
}

impl EventHub {
    /// 创建事件中枢（通道在创建时建立，接收方未订阅前的事件会被缓存）
    pub fn new() -> Arc<Self> {
        let (conn_tx, conn_rx) = unbounded_channel();
        let (conv_tx, conv_rx) = unbounded_channel();
        let (friend_tx, friend_rx) = unbounded_channel();
        let (group_tx, group_rx) = unbounded_channel();
        let (user_tx, user_rx) = unbounded_channel();
        let (message_tx, message_rx) = unbounded_channel();
        Arc::new(Self {
            conn_tx,
            conv_tx,
            friend_tx,
            group_tx,
            user_tx,
            message_tx,
            conn_rx: Mutex::new(Some(conn_rx)),
            conv_rx: Mutex::new(Some(conv_rx)),
            friend_rx: Mutex::new(Some(friend_rx)),
            group_rx: Mutex::new(Some(group_rx)),
            user_rx: Mutex::new(Some(user_rx)),
            message_rx: Mutex::new(Some(message_rx)),
        })
    }

    pub fn take_conn_rx(&self) -> Option<UnboundedReceiver<ConnectionEvent>> {
        self.conn_rx.lock().ok()?.take()
    }
    pub fn take_conv_rx(&self) -> Option<UnboundedReceiver<ConversationEvent>> {
        self.conv_rx.lock().ok()?.take()
    }
    pub fn take_friend_rx(&self) -> Option<UnboundedReceiver<FriendEvent>> {
        self.friend_rx.lock().ok()?.take()
    }
    pub fn take_group_rx(&self) -> Option<UnboundedReceiver<GroupEvent>> {
        self.group_rx.lock().ok()?.take()
    }
    pub fn take_user_rx(&self) -> Option<UnboundedReceiver<UserEvent>> {
        self.user_rx.lock().ok()?.take()
    }
    pub fn take_message_rx(&self) -> Option<UnboundedReceiver<MessageEvent>> {
        self.message_rx.lock().ok()?.take()
    }
}

impl ConnectionListener for EventHub {
    fn on_connecting(&self) { let _ = self.conn_tx.send(ConnectionEvent::Connecting); }
    fn on_connected(&self) { let _ = self.conn_tx.send(ConnectionEvent::Connected); }
    fn on_disconnected(&self, reason: &str) { let _ = self.conn_tx.send(ConnectionEvent::Disconnected(reason.to_string())); }
    fn on_connect_failed(&self, error: &str) { let _ = self.conn_tx.send(ConnectionEvent::ConnectFailed(error.to_string())); }
    fn on_kicked_offline(&self, reason: &str) { let _ = self.conn_tx.send(ConnectionEvent::KickedOffline(reason.to_string())); }
    fn on_token_expired(&self) { let _ = self.conn_tx.send(ConnectionEvent::TokenExpired); }
    fn on_reconnecting(&self, attempt: u32, max_attempts: u32) { let _ = self.conn_tx.send(ConnectionEvent::Reconnecting { attempt, max_attempts }); }
    fn on_login_success(&self, user_id: &str) { let _ = self.conn_tx.send(ConnectionEvent::LoginSuccess(user_id.to_string())); }
    fn on_logout(&self) { let _ = self.conn_tx.send(ConnectionEvent::Logout); }
}

impl ConversationListener for EventHub {
    fn on_changed(&self, conversations: &[LocalConversation]) { let _ = self.conv_tx.send(ConversationEvent::Changed(conversations.to_vec())); }
    fn on_deleted(&self, ids: &[String]) { let _ = self.conv_tx.send(ConversationEvent::Deleted(ids.to_vec())); }
    fn on_new(&self, conversations: &[LocalConversation]) { let _ = self.conv_tx.send(ConversationEvent::New(conversations.to_vec())); }
    fn on_total_unread_count_changed(&self, count: i64) { let _ = self.conv_tx.send(ConversationEvent::TotalUnreadCountChanged(count)); }
    fn on_sync_started(&self) { let _ = self.conv_tx.send(ConversationEvent::SyncStarted); }
    fn on_sync_finished(&self) { let _ = self.conv_tx.send(ConversationEvent::SyncFinished); }
    fn on_sync_failed(&self, error: &str) { let _ = self.conv_tx.send(ConversationEvent::SyncFailed(error.to_string())); }
    fn on_sync_progress(&self, progress: i32, message: &str) { let _ = self.conv_tx.send(ConversationEvent::SyncProgress { progress, message: message.to_string() }); }
    fn on_user_input_status_changed(&self, conversation_id: &str, user_id: &str, platform_ids: &[i32]) {
        let _ = self.conv_tx.send(ConversationEvent::UserInputStatusChanged {
            conversation_id: conversation_id.to_string(),
            user_id: user_id.to_string(),
            platform_ids: platform_ids.to_vec(),
        });
    }
    fn on_update_latest_message_read_state(&self, conversation_id: &str) {
        let _ = self.conv_tx.send(ConversationEvent::UpdateLatestMessageReadState { conversation_id: conversation_id.to_string() });
    }
}

impl FriendListener for EventHub {
    fn on_added(&self, friends: &[FriendInfo]) { let _ = self.friend_tx.send(FriendEvent::Added(friends.to_vec())); }
    fn on_deleted(&self, user_id: &str) { let _ = self.friend_tx.send(FriendEvent::Deleted(user_id.to_string())); }
    fn on_info_changed(&self, friends: &[FriendInfo]) { let _ = self.friend_tx.send(FriendEvent::InfoChanged(friends.to_vec())); }
    fn on_black_added(&self, user_id: &str) { let _ = self.friend_tx.send(FriendEvent::BlackAdded(user_id.to_string())); }
    fn on_black_deleted(&self, user_id: &str) { let _ = self.friend_tx.send(FriendEvent::BlackDeleted(user_id.to_string())); }
    fn on_application_added(&self, user_id: &str) { let _ = self.friend_tx.send(FriendEvent::ApplicationAdded(user_id.to_string())); }
    fn on_application_accepted(&self, user_id: &str) { let _ = self.friend_tx.send(FriendEvent::ApplicationAccepted(user_id.to_string())); }
    fn on_application_rejected(&self, user_id: &str) { let _ = self.friend_tx.send(FriendEvent::ApplicationRejected(user_id.to_string())); }
}

impl GroupListener for EventHub {
    fn on_joined_group_added(&self, group: &GroupInfo) { let _ = self.group_tx.send(GroupEvent::JoinedGroupAdded(group.clone())); }
    fn on_joined_group_deleted(&self, group: &GroupInfo) { let _ = self.group_tx.send(GroupEvent::JoinedGroupDeleted(group.clone())); }
    fn on_group_info_changed(&self, group: &GroupInfo) { let _ = self.group_tx.send(GroupEvent::GroupInfoChanged(group.clone())); }
    fn on_member_added(&self, group_id: &str) { let _ = self.group_tx.send(GroupEvent::MemberAdded(group_id.to_string())); }
    fn on_member_deleted(&self, group_id: &str) { let _ = self.group_tx.send(GroupEvent::MemberDeleted(group_id.to_string())); }
    fn on_group_read_receipt(&self, receipts: &[GroupReadReceipt]) { let _ = self.group_tx.send(GroupEvent::GroupReadReceipt(receipts.to_vec())); }
    fn on_application_added(&self, group_id: &str) { let _ = self.group_tx.send(GroupEvent::ApplicationAdded(group_id.to_string())); }
    fn on_application_approved(&self, group_id: &str) { let _ = self.group_tx.send(GroupEvent::ApplicationApproved(group_id.to_string())); }
    fn on_application_rejected(&self, group_id: &str) { let _ = self.group_tx.send(GroupEvent::ApplicationRejected(group_id.to_string())); }
}

impl MessageListener for EventHub {
    fn on_new_message(&self, message: &MsgData) {
        let _ = self.message_tx.send(MessageEvent::NewMessage { message: message.clone() });
    }
    fn on_message_revoked(&self, event: &MessageEvent) {
        let _ = self.message_tx.send(event.clone());
    }
    fn on_c2c_read_receipt(&self, receipts: &[MessageReceipt]) {
        let _ = self.message_tx.send(MessageEvent::C2CReadReceipt { receipts: receipts.to_vec() });
    }
    fn on_message_deleted(&self, conversation_id: &str, client_msg_ids: &[String]) {
        let _ = self.message_tx.send(MessageEvent::Deleted {
            conversation_id: conversation_id.to_string(),
            client_msg_ids: client_msg_ids.to_vec(),
        });
    }
    fn on_send_failed(&self, client_msg_id: &str, error: &str) {
        let _ = self.message_tx.send(MessageEvent::SendFailed {
            client_msg_id: client_msg_id.to_string(),
            error: error.to_string(),
        });
    }
    fn on_upload_progress(&self, client_msg_id: &str, progress: u8, total_size: u64, uploaded_size: u64) {
        let _ = self.message_tx.send(MessageEvent::UploadProgress {
            client_msg_id: client_msg_id.to_string(),
            progress,
            total_size,
            uploaded_size,
        });
    }
}

impl UserListener for EventHub {
    fn on_user_info_updated(&self, user: &UserInfo) { let _ = self.user_tx.send(UserEvent::UserInfoUpdated { user: user.clone() }); }
    fn on_user_status_changed(&self, user_id: &str, status: i32, platform_ids: &[i32]) {
        let _ = self.user_tx.send(UserEvent::UserStatusChanged {
            user_id: user_id.to_string(),
            status,
            platform_ids: platform_ids.to_vec(),
        });
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use crate::event::events::connection::ConnectionEvent;
    use crate::event::events::conversation::ConversationEvent;
    use crate::event::events::friend::FriendEvent;
    use crate::event::events::group::GroupEvent;
    use crate::event::events::message::MessageEvent;
    use crate::event::events::user::UserEvent;
    use crate::model::friend::FriendInfo;
    use crate::model::group::GroupInfo;
    use crate::model::local::LocalConversation;
    use openim_protocol::sdkws::MsgData;

    #[tokio::test]
    async fn test_event_hub_creation() {
        let hub = EventHub::new();
        assert!(hub.take_conn_rx().is_some());
        assert!(hub.take_conv_rx().is_some());
        assert!(hub.take_friend_rx().is_some());
        assert!(hub.take_group_rx().is_some());
        assert!(hub.take_user_rx().is_some());
        assert!(hub.take_message_rx().is_some());
    }

    #[tokio::test]
    async fn test_event_hub_receiver_taken_once() {
        let hub = EventHub::new();
        assert!(hub.take_conn_rx().is_some());
        // 第二次调用应返回 None（只能 take 一次）
        assert!(hub.take_conn_rx().is_none());
    }

    #[tokio::test]
    async fn test_event_hub_emit_connection_event() {
        let hub = EventHub::new();
        let mut rx = hub.take_conn_rx().unwrap();

        // EventHub 自身实现了 ConnectionListener
        let listener: Arc<dyn ConnectionListener> = hub.clone();
        listener.on_connected();

        tokio::time::sleep(tokio::time::Duration::from_millis(50)).await;
        let event = rx.try_recv().ok();
        assert!(event.is_some());
        assert!(matches!(event.unwrap(), ConnectionEvent::Connected));
    }

    #[tokio::test]
    async fn test_event_hub_all_channels_work() {
        let hub = EventHub::new();
        let mut conn_rx = hub.take_conn_rx().unwrap();
        let mut conv_rx = hub.take_conv_rx().unwrap();
        let mut friend_rx = hub.take_friend_rx().unwrap();
        let mut group_rx = hub.take_group_rx().unwrap();
        let mut user_rx = hub.take_user_rx().unwrap();
        let mut message_rx = hub.take_message_rx().unwrap();

        let conn: Arc<dyn ConnectionListener> = hub.clone();
        let conv: Arc<dyn ConversationListener> = hub.clone();
        let friend: Arc<dyn FriendListener> = hub.clone();
        let group: Arc<dyn GroupListener> = hub.clone();
        let user: Arc<dyn UserListener> = hub.clone();
        let msg: Arc<dyn MessageListener> = hub.clone();

        conn.on_connected();
        conv.on_changed(&[]);
        friend.on_added(&[]);
        group.on_joined_group_added(&GroupInfo { group_id: "g1".to_string(), group_name: "Test".to_string(), face_url: String::new(), introduction: String::new(), notification: String::new(), owner_user_id: String::new(), create_time: 0, member_count: 0, status: 0 });
        user.on_user_status_changed("u1", 1, &[]);
        msg.on_new_message(&MsgData::default());

        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

        assert!(conn_rx.try_recv().is_ok());
        assert!(conv_rx.try_recv().is_ok());
        assert!(friend_rx.try_recv().is_ok());
        assert!(group_rx.try_recv().is_ok());
        assert!(user_rx.try_recv().is_ok());
        assert!(message_rx.try_recv().is_ok());
    }

    #[tokio::test]
    async fn test_event_hub_connection_variants() {
        let hub = EventHub::new();
        let mut rx = hub.take_conn_rx().unwrap();
        let listener: Arc<dyn ConnectionListener> = hub.clone();

        listener.on_connecting();
        listener.on_disconnected("test reason");
        listener.on_connect_failed("timeout");
        listener.on_kicked_offline("duplicate login");
        listener.on_token_expired();
        listener.on_reconnecting(1, 5);
        listener.on_login_success("user_1");
        listener.on_logout();

        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

        // 应该有 9 个事件
        let mut count = 0;
        while rx.try_recv().is_ok() {
            count += 1;
        }
        assert_eq!(count, 8, "on_connect_failed 和 on_connect_failed 可能合并或未发送");
    }
}


