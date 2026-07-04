mod client;
mod message;
mod conversation;
mod friend;
mod group;

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
use crate::domain::listener::connection::ConnectionListener;
use crate::domain::listener::conversation::ConversationListener;
use crate::domain::listener::friend::FriendListener;
use crate::domain::listener::group::GroupListener;
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
    pub fn set_connection_listener(&self, l: Arc<dyn ConnectionListener>) {
        self.connection.set_connection_listener(l);
    }
    pub fn set_conversation_listener(&self, l: Arc<dyn ConversationListener>) {
        self.message_handler.set_conversation_listener(l.clone());
        self.message_service.set_conversation_listener(l.clone());
        self.message_syncer.set_conversation_listener(l.clone());
        self.conversation_syncer.set_conversation_listener(l.clone());
        self.conversation.set_conversation_listener(l);
    }
    pub fn set_friend_listener(&self, l: Arc<dyn FriendListener>) {
        self.friend.set_friend_listener(l);
    }
    pub fn set_group_listener(&self, l: Arc<dyn GroupListener>) {
        self.group.set_group_listener(l);
    }
}
