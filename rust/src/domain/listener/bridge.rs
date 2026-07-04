//! 每个 listener trait → 独立 SdkEvent mpsc channel
//!
//! 每个 stream 方法创建实现一个 listener trait 的 adapter，
//! 注册到对应模块，事件转 SdkEvent → mpsc → Dart。

use crate::domain::event::types::SdkEvent;
use std::sync::Arc;
use tokio::sync::mpsc;

macro_rules! impl_adapter {
    ($name:ident, $trait:path, $($method:ident($($arg:ident: $arg_ty:ty),*) => $event:expr),* $(,)?) => {
        pub struct $name { pub tx: mpsc::UnboundedSender<SdkEvent> }
        impl $trait for $name {
            $(fn $method(&self, $($arg: $arg_ty),*) { let _ = self.tx.send($event); })*
        }
    };
}

impl_adapter!(ConnAdapter, super::connection::ConnectionListener,
    on_connecting() => SdkEvent::Connecting,
    on_connected() => SdkEvent::Connected,
    on_disconnected(reason: &str) => SdkEvent::Disconnected { reason: reason.to_string() },
    on_kicked_offline(reason: &str) => SdkEvent::KickedOffline { reason: reason.to_string() },
    on_token_expired() => SdkEvent::TokenExpired,
    on_reconnecting(attempt: u32, max_attempts: u32) => SdkEvent::Reconnecting { attempt, max_attempts },
    on_login_success(user_id: &str) => SdkEvent::LoginSuccess { user_id: user_id.to_string() },
    on_logout() => SdkEvent::Logout,
);

impl_adapter!(ConvAdapter, super::conversation::ConversationListener,
    on_changed(c: &[crate::domain::model::conversation::Conversation]) => SdkEvent::ConversationChanged { conversations: c.to_vec() },
    on_deleted(ids: &[String]) => SdkEvent::ConversationDeleted { conversation_ids: ids.to_vec() },
    on_total_unread_count_changed(count: i64) => SdkEvent::TotalUnreadCountChanged { count },
    on_sync_started() => SdkEvent::SyncStarted,
    on_sync_finished() => SdkEvent::SyncFinished,
    on_sync_failed(error: &str) => SdkEvent::SyncFailed { error: error.to_string() },
    on_sync_progress(progress: i32, message: &str) => SdkEvent::SyncProgress { progress: progress as u8, message: message.to_string() },
    on_user_input_status_changed(conversation_id: &str, user_id: &str, platform_ids: &[i32]) =>
        SdkEvent::ConversationUserInputStatusChanged {
            data: crate::domain::event::types::InputStatusChangedData {
                conversation_id: conversation_id.to_string(), user_id: user_id.to_string(), platform_ids: platform_ids.to_vec(),
            },
        },
);

impl_adapter!(FriendAdapter, super::friend::FriendListener,
    on_added(fs: &[crate::domain::model::friend::FriendInfo]) => SdkEvent::FriendAdded { friends: fs.to_vec() },
    on_deleted(id: &str) => SdkEvent::FriendDeleted { friend_id: id.to_string() },
    on_black_added(id: &str) => SdkEvent::BlackAdded { user_id: id.to_string() },
    on_black_deleted(id: &str) => SdkEvent::BlackDeleted { black_id: id.to_string() },
);

impl_adapter!(GroupAdapter, super::group::GroupListener,
    on_group_info_changed(g: &crate::domain::model::group::GroupInfo) => SdkEvent::GroupInfoChanged { group_id: g.group_id.clone() },
    on_group_read_receipt(r: &[crate::domain::event::types::GroupReadReceipt]) => SdkEvent::GroupReadReceipt { receipts: r.to_vec() },
);

macro_rules! start_stream {
    ($fn_name:ident, $adapter:ident) => {
        pub fn $fn_name() -> (mpsc::UnboundedReceiver<SdkEvent>, Arc<$adapter>) {
            let (tx, rx) = mpsc::unbounded_channel();
            (rx, Arc::new($adapter { tx }))
        }
    };
}

start_stream!(start_connection_stream, ConnAdapter);
start_stream!(start_conversation_stream, ConvAdapter);
start_stream!(start_friend_stream, FriendAdapter);
start_stream!(start_group_stream, GroupAdapter);
