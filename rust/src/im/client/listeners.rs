//! 事件订阅：所有原回调改为 Stream 订阅，事件负载使用结构体（与 Go SDK 的字符串可不一致）。

use std::sync::Arc;

use openim_protocol::sdkws;
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc;

use crate::im::dao::user::LocalUser;
use crate::im::model::conversation::LocalConversation;
use crate::im::model::friend::{BlackList, FriendRequest};
use crate::im::model::message::{MsgStruct, TypingStatus};

// ============== ConnEvent（已有） ==============

/// 连接状态事件
#[derive(Clone, Debug)]
pub enum ConnEvent {
    Connecting,
    ConnectSuccess,
    ConnectFailed { err_code: i32, err_msg: String },
    KickedOffline,
    UserTokenExpired,
    UserTokenInvalid { err_msg: String },
}

pub type ConnEventTx = Arc<std::sync::RwLock<Option<mpsc::UnboundedSender<ConnEvent>>>>;

// ============== ConversationEvent ==============

/// 会话同步/变更事件，负载为结构体
#[derive(Clone, Debug)]
pub enum ConversationEvent {
    SyncServerStart { reinstalled: bool },
    SyncServerFinish { reinstalled: bool },
    SyncServerProgress { progress: i32 },
    SyncServerFailed { reinstalled: bool },
    NewConversation { list: Vec<LocalConversation> },
    ConversationChanged { list: Vec<LocalConversation> },
    /// 清空会话时下发的会话 ID 列表
    ConversationsCleared { conversation_ids: Vec<String> },
    TotalUnreadMessageCountChanged { total_unread_count: i32 },
    ConversationUserInputStatusChanged(TypingStatus),
}

pub type ConversationEventTx = Arc<std::sync::RwLock<Option<mpsc::UnboundedSender<ConversationEvent>>>>;

// ============== AdvancedMsgEvent ==============

/// 单条已读回执（与 Go 回调 JSON 一致）
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReadReceiptItem {
    pub user_id: String,
    pub msg_id_list: Vec<String>,
    pub session_type: i32,
    pub read_time: i64,
}

/// 消息撤回通知内容
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MessageRevokedInfo {
    pub conversation_id: String,
    pub seq: i64,
    pub revoke_time: i64,
    #[serde(rename = "sourceMessageSendTime")]
    pub source_message_send_time: i64,
    #[serde(rename = "sourceMessageSendID")]
    pub source_message_send_id: String,
    #[serde(rename = "sourceMessageSenderNickname")]
    pub source_message_sender_nickname: String,
    pub ex: String,
    pub is_admin_revoke: bool,
}

/// 高级消息事件，负载为结构体
#[derive(Clone, Debug)]
pub enum AdvancedMsgEvent {
    RecvNewMessage(MsgStruct),
    RecvC2CReadReceipt(Vec<ReadReceiptItem>),
    NewRecvMessageRevoked(MessageRevokedInfo),
    RecvOfflineNewMessage(MsgStruct),
    MsgDeleted(MsgStruct),
    RecvOnlineOnlyMessage(MsgStruct),
}

pub type AdvancedMsgEventTx = Arc<std::sync::RwLock<Option<mpsc::UnboundedSender<AdvancedMsgEvent>>>>;

// ============== UserEvent ==============

#[derive(Clone, Debug)]
pub enum UserEvent {
    SelfInfoUpdated(LocalUser),
    UserStatusChanged { user_online_status: String },
}

pub type UserEventTx = Arc<std::sync::RwLock<Option<mpsc::UnboundedSender<UserEvent>>>>;

// ============== FriendEvent ==============

#[derive(Clone, Debug)]
pub enum FriendEvent {
    FriendListChanged(Vec<sdkws::FriendInfo>),
    BlackListChanged(Vec<BlackList>),
    FriendRequestListChanged(Vec<FriendRequest>),
}

pub type FriendEventTx = Arc<std::sync::RwLock<Option<mpsc::UnboundedSender<FriendEvent>>>>;

// ============== GroupEvent ==============

/// 群组通知：当前仅群信息变更由服务端下发的 JSON 内容
#[derive(Clone, Debug)]
pub enum GroupEvent {
    GroupInfoChanged { content: String },
}

pub type GroupEventTx = Arc<std::sync::RwLock<Option<mpsc::UnboundedSender<GroupEvent>>>>;

// ============== Listeners ==============

/// 客户端全局事件发送端，仅通过 Stream 订阅；克隆时共享同一 Arc
#[derive(Clone, Default)]
pub struct Listeners {
    pub conn_event_tx: Option<ConnEventTx>,
    pub conversation_event_tx: Option<ConversationEventTx>,
    pub advanced_msg_event_tx: Option<AdvancedMsgEventTx>,
    pub user_event_tx: Option<UserEventTx>,
    pub friend_event_tx: Option<FriendEventTx>,
    pub group_event_tx: Option<GroupEventTx>,
}

impl Listeners {
    #[inline]
    pub fn try_emit_conn_event(&self, event: ConnEvent) {
        try_emit(&self.conn_event_tx, event);
    }

    #[inline]
    pub fn try_emit_conversation_event(&self, event: ConversationEvent) {
        try_emit(&self.conversation_event_tx, event);
    }

    #[inline]
    pub fn try_emit_advanced_msg_event(&self, event: AdvancedMsgEvent) {
        try_emit(&self.advanced_msg_event_tx, event);
    }

    #[inline]
    pub fn try_emit_user_event(&self, event: UserEvent) {
        try_emit(&self.user_event_tx, event);
    }

    #[inline]
    pub fn try_emit_friend_event(&self, event: FriendEvent) {
        try_emit(&self.friend_event_tx, event);
    }

    #[inline]
    pub fn try_emit_group_event(&self, event: GroupEvent) {
        try_emit(&self.group_event_tx, event);
    }
}

#[inline]
fn try_emit<T: Send>(tx: &Option<Arc<std::sync::RwLock<Option<mpsc::UnboundedSender<T>>>>>, event: T) {
    if let Some(ref guard) = tx {
        if let Ok(r) = guard.read() {
            if let Some(ref sender) = *r {
                let _ = sender.send(event);
            }
        }
    }
}
