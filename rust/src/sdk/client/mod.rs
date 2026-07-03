mod client;
mod message;
mod conversation;
mod friend;
mod group;

use crate::domain::listener::connection::ConnectionListener;
use crate::domain::listener::conversation::ConversationListener;
use crate::domain::listener::friend::FriendListener;
use crate::domain::listener::group::GroupListener;
mod online_status;
pub mod types;
mod user;

pub use self::client::*;
pub use self::message::*;
pub use self::conversation::*;
pub use self::friend::*;
pub use self::group::*;
pub use self::online_status::*;
pub use self::user::*;

use crate::core::connection::manager::ConnectionManager;
use crate::core::conversation::manager::ConversationManager;
use crate::core::conversation::syncer::ConversationSyncer;
use crate::core::file::uploader::FileUploader;
use crate::core::friend::manager::FriendManager;
use crate::core::group::manager::GroupManager;
use crate::core::message::handler::MessageHandler;
use crate::core::message::send_queue::MessageSendQueue;
use crate::core::message::service::MessageService;
use crate::core::message::syncer::MessageSyncer;
use crate::core::notification::handler::NotificationHandler;
use crate::core::online::manager::OnlineStatusManager;
use crate::core::user::manager::UserManager;
use crate::domain::event::EventBus;
use crate::infra::cache::memory::CacheManager;
use crate::sdk::context::RuntimeContext;
use serde::{Deserialize, Serialize};
use std::sync::Arc;

// ============================================================================
// SDK API 类型定义
// ============================================================================

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FriendApplyInfo {
    pub user_id: String,
    pub nickname: String,
    pub face_url: String,
    pub create_time: i64,
    pub req_msg: Option<String>,
    pub handle_result: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupApplyInfo {
    pub group_id: String,
    pub user_id: String,
    pub nickname: String,
    pub face_url: String,
    pub reason: String,
    pub handle_result: i32,
}

pub struct OpenIMClient {
    pub(crate) context: Arc<RuntimeContext>,
    pub(crate) connection: Arc<ConnectionManager>,
    pub(crate) user: Arc<UserManager>,
    pub(crate) friend: Arc<FriendManager>,
    pub(crate) group: Arc<GroupManager>,
    pub(crate) conversation: Arc<ConversationManager>,
    pub(crate) message_syncer: Arc<MessageSyncer>,
    pub(crate) message_handler: Arc<MessageHandler>,
    pub(crate) notification_handler: Arc<NotificationHandler>,
    pub(crate) conversation_syncer: Arc<ConversationSyncer>,
    pub(crate) online_status: Arc<OnlineStatusManager>,
    pub(crate) file_uploader: Arc<FileUploader>,
    pub(crate) message_service: Arc<MessageService>,
    pub(crate) event_bus: Arc<EventBus>,
    pub(crate) cache: Arc<CacheManager>,
    pub(crate) send_queue: Arc<MessageSendQueue>,
}

impl OpenIMClient {
    pub fn connection_listener(&self) -> &Arc<ConnectionListener> {
        self.connection.connection_listener()
    }
    pub fn conversation_listener(&self) -> &Arc<ConversationListener> {
        self.message_handler.conversation_listener()
    }
    pub fn friend_listener(&self) -> &Arc<FriendListener> {
        self.friend.friend_listener()
    }
    pub fn group_listener(&self) -> &Arc<GroupListener> {
        self.group.group_listener()
    }
}
