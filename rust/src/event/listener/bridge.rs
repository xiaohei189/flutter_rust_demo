//! 每个 listener trait → 独立 typed event mpsc channel
//!
//! Adapter 直接发模块事件 enum，不在 bridge 层转 SdkEvent。

use super::connection::ConnectionEvent;
use super::conversation::ConversationEvent;
use super::friend::FriendEvent;
use super::group::GroupEvent;
use std::sync::Arc;
use tokio::sync::mpsc;

macro_rules! impl_adapter {
    ($name:ident, $event:ty, $trait:path, $($method:ident($($arg:ident: $arg_ty:ty),*) => $ev:expr),* $(,)?) => {
        pub struct $name { pub tx: mpsc::UnboundedSender<$event> }
        impl $trait for $name {
            $(fn $method(&self, $($arg: $arg_ty),*) { let _ = self.tx.send($ev); })*
        }
    };
}

impl_adapter!(ConnAdapter, ConnectionEvent, super::connection::ConnectionListener,
    on_connecting() => ConnectionEvent::Connecting,
    on_connected() => ConnectionEvent::Connected,
    on_disconnected(r: &str) => ConnectionEvent::Disconnected(r.to_string()),
    on_kicked_offline(r: &str) => ConnectionEvent::KickedOffline(r.to_string()),
    on_token_expired() => ConnectionEvent::TokenExpired,
    on_reconnecting(a: u32, m: u32) => ConnectionEvent::Reconnecting { attempt: a, max_attempts: m },
    on_login_success(id: &str) => ConnectionEvent::LoginSuccess(id.to_string()),
    on_logout() => ConnectionEvent::Logout,
);

impl_adapter!(ConvAdapter, ConversationEvent, super::conversation::ConversationListener,
    on_changed(c: &[crate::domain::model::local::LocalConversation]) => ConversationEvent::Changed(c.to_vec()),
    on_deleted(ids: &[String]) => ConversationEvent::Deleted(ids.to_vec()),
    on_total_unread_count_changed(count: i64) => ConversationEvent::TotalUnreadCountChanged(count),
    on_sync_started() => ConversationEvent::SyncStarted,
    on_sync_finished() => ConversationEvent::SyncFinished,
    on_sync_failed(e: &str) => ConversationEvent::SyncFailed(e.to_string()),
    on_sync_progress(p: i32, m: &str) => ConversationEvent::SyncProgress { progress: p, message: m.to_string() },
    on_user_input_status_changed(cid: &str, uid: &str, pids: &[i32]) =>
        ConversationEvent::UserInputStatusChanged { conversation_id: cid.to_string(), user_id: uid.to_string(), platform_ids: pids.to_vec() },
);

impl_adapter!(FriendAdapter, FriendEvent, super::friend::FriendListener,
    on_added(fs: &[crate::domain::model::friend::FriendInfo]) => FriendEvent::Added(fs.to_vec()),
    on_deleted(id: &str) => FriendEvent::Deleted(id.to_string()),
    on_black_added(id: &str) => FriendEvent::BlackAdded(id.to_string()),
    on_black_deleted(id: &str) => FriendEvent::BlackDeleted(id.to_string()),
);

impl_adapter!(GroupAdapter, GroupEvent, super::group::GroupListener,
    on_group_info_changed(g: &crate::domain::model::group::GroupInfo) => GroupEvent::GroupInfoChanged(g.clone()),
    on_group_read_receipt(r: &[crate::event::types::GroupReadReceipt]) => GroupEvent::GroupReadReceipt(r.to_vec()),
);

macro_rules! start_stream {
    ($fn_name:ident, $event:ty, $adapter:ident) => {
        pub fn $fn_name() -> (mpsc::UnboundedReceiver<$event>, Arc<$adapter>) {
            let (tx, rx) = mpsc::unbounded_channel();
            (rx, Arc::new($adapter { tx }))
        }
    };
}

start_stream!(start_connection_stream, ConnectionEvent, ConnAdapter);
start_stream!(start_conversation_stream, ConversationEvent, ConvAdapter);
start_stream!(start_friend_stream, FriendEvent, FriendAdapter);
start_stream!(start_group_stream, GroupEvent, GroupAdapter);

