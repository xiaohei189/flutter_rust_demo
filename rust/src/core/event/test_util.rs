//! 测试辅助：无操作 Listener（测试不关心事件时使用）
//!
//! 需要断言事件内容的测试直接使用 `EventHub`（它会把回调转发到 mpsc 通道）。

use crate::core::event::events::connection::ConnectionListener;
use crate::core::event::events::conversation::ConversationListener;
use crate::core::event::events::friend::FriendListener;
use crate::core::event::events::group::GroupListener;
use crate::core::event::events::message::MessageListener;
use crate::core::event::events::user::UserListener;
use std::sync::Arc;

pub(crate) fn noop_connection_listener() -> Arc<dyn ConnectionListener> {
    Arc::new(NoopConnectionListener)
}
pub(crate) fn noop_conversation_listener() -> Arc<dyn ConversationListener> {
    Arc::new(NoopConversationListener)
}
pub(crate) fn noop_friend_listener() -> Arc<dyn FriendListener> {
    Arc::new(NoopFriendListener)
}
pub(crate) fn noop_group_listener() -> Arc<dyn GroupListener> {
    Arc::new(NoopGroupListener)
}
pub(crate) fn noop_user_listener() -> Arc<dyn UserListener> {
    Arc::new(NoopUserListener)
}
pub(crate) fn noop_message_listener() -> Arc<dyn MessageListener> {
    Arc::new(NoopMessageListener)
}

pub(crate) struct NoopConnectionListener;
impl ConnectionListener for NoopConnectionListener {}

pub(crate) struct NoopConversationListener;
impl ConversationListener for NoopConversationListener {}

pub(crate) struct NoopFriendListener;
impl FriendListener for NoopFriendListener {}

pub(crate) struct NoopGroupListener;
impl GroupListener for NoopGroupListener {}

pub(crate) struct NoopUserListener;
impl UserListener for NoopUserListener {}

pub(crate) struct NoopMessageListener;
impl MessageListener for NoopMessageListener {}
