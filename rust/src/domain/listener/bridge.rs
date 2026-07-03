//! Listener → SdkEvent → mpsc channel → Dart Stream
//!
//! 聚合所有模块 listener 为单个 mpsc channel（SdkEvent 格式，兼容现有 Dart 协议）。
//! EventBus 完全移除后，这是唯一的 Dart 事件通道。

use super::connection::ConnectionListener;
use super::conversation::ConversationListener;
use super::friend::FriendListener;
use super::group::GroupListener;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::conversation::Conversation;
use std::sync::Arc;
use tokio::sync::mpsc;

pub fn start_event_stream(
    conn: &Arc<ConnectionListener>,
    conv: &Arc<ConversationListener>,
    friend: &Arc<FriendListener>,
    group: &Arc<GroupListener>,
) -> mpsc::UnboundedReceiver<SdkEvent> {
    let (tx, rx) = mpsc::unbounded_channel();

    // Connection events
    let t = tx.clone();
    conn.on_connected.register(move |_| { let _ = t.send(SdkEvent::Connected); });
    let t = tx.clone();
    conn.on_connecting.register(move |_| { let _ = t.send(SdkEvent::Connecting); });
    let t = tx.clone();
    conn.on_disconnected.register(move |r| { let _ = t.send(SdkEvent::Disconnected { reason: r.clone() }); });
    let t = tx.clone();
    conn.on_kicked_offline.register(move |r| { let _ = t.send(SdkEvent::KickedOffline { reason: r.clone() }); });
    let t = tx.clone();
    conn.on_token_expired.register(move |_| { let _ = t.send(SdkEvent::TokenExpired); });
    let t = tx.clone();
    conn.on_reconnecting.register(move |(a, m)| { let _ = t.send(SdkEvent::Reconnecting { attempt: *a, max_attempts: *m }); });
    let t = tx.clone();
    conn.on_login_success.register(move |uid| { let _ = t.send(SdkEvent::LoginSuccess { user_id: uid.clone() }); });
    let t = tx.clone();
    conn.on_logout.register(move |_| { let _ = t.send(SdkEvent::Logout); });

    // Conversation events
    let t = tx.clone();
    conv.on_changed.register(move |c| { let _ = t.send(SdkEvent::ConversationChanged { conversations: c.clone() }); });
    let t = tx.clone();
    conv.on_total_unread_count_changed.register(move |c| { let _ = t.send(SdkEvent::TotalUnreadCountChanged { count: *c }); });
    let t = tx.clone();
    conv.on_sync_started.register(move |_| { let _ = t.send(SdkEvent::SyncStarted); });
    let t = tx.clone();
    conv.on_sync_finished.register(move |_| { let _ = t.send(SdkEvent::SyncFinished); });
    let t = tx.clone();
    conv.on_sync_failed.register(move |e| { let _ = t.send(SdkEvent::SyncFailed { error: e.clone() }); });
    let t = tx.clone();
    conv.on_sync_progress.register(move |(p, msg)| { let _ = t.send(SdkEvent::SyncProgress { progress: (*p) as u8, message: msg.clone() }); });
    let t = tx.clone();
    conv.on_user_input_status_changed.register(move |(cid, uid, pids)| {
        let _ = t.send(SdkEvent::ConversationUserInputStatusChanged {
            data: crate::domain::event::types::InputStatusChangedData {
                conversation_id: cid.clone(),
                user_id: uid.clone(),
                platform_ids: pids.clone(),
            },
        });
    });

    // Friend events
    let t = tx.clone();
    friend.on_added.register(move |f| { let _ = t.send(SdkEvent::FriendAdded { friends: f.clone() }); });
    let t = tx.clone();
    friend.on_deleted.register(move |id| { let _ = t.send(SdkEvent::FriendDeleted { friend_id: id.clone() }); });
    let t = tx.clone();
    friend.on_black_added.register(move |id| { let _ = t.send(SdkEvent::BlackAdded { user_id: id.clone() }); });
    let t = tx.clone();
    friend.on_black_deleted.register(move |id| { let _ = t.send(SdkEvent::BlackDeleted { black_id: id.clone() }); });

    // Group events
    let t = tx.clone();
    group.on_group_info_changed.register(move |g| { let _ = t.send(SdkEvent::GroupInfoChanged { group_id: g.group_id.clone() }); });
    group.on_group_read_receipt.register(move |r| { let _ = tx.send(SdkEvent::GroupReadReceipt { receipts: r.clone() }); });

    rx
}
