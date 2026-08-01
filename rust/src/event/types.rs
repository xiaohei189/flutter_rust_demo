//! 事件类型与数据 DTO
//!
//! - [`SdkEvent`]：内部事件总线统一入口（包装各领域事件，SDK 内部广播/订阅用）
//! - 领域事件枚举定义于 `event::events/*`（连接/会话/好友/群组同时作为 Dart 流事件）
//! - 数据 DTO：已读回执等事件载荷

use crate::event::events::connection::ConnectionEvent;
use crate::event::events::conversation::ConversationEvent;
use crate::event::events::friend::FriendEvent;
use crate::event::events::group::GroupEvent;
use crate::event::events::message::MessageEvent;
use crate::event::events::user::UserEvent;

/// C2C 已读回执（对齐 Go SDK `sdkws.MessageReceipt`）
#[derive(Clone, Debug)]
pub struct MessageReceipt {
    pub user_id: String,
    pub msg_ids: Vec<String>,
    pub read_time: i64,
    pub session_type: i32,
}

/// 群聊已读回执（对齐 Go SDK `OnRecvGroupReadReceipt`）
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct GroupReadReceipt {
    pub group_id: String,
    pub msg_id: String,
    pub has_read_user_id_list: Vec<String>,
    pub has_read_count: i32,
    pub group_member_count: i32,
    pub read_time: i64,
}

/// 内部事件总线统一事件 —— 包装各领域事件，供 SDK 内部广播/订阅
///
/// Dart 侧实时事件通过各领域 `*_stream`（`api::client`）直接下发，
/// 内部总线只承载 SDK 内部的协调事件；连接域事件纯走流，不设包装臂。
#[derive(Clone, Debug)]
pub enum SdkEvent {
    Connection(ConnectionEvent),
    Message(MessageEvent),
    Conversation(ConversationEvent),
    User(UserEvent),
    Friend(FriendEvent),
    Group(GroupEvent),
}

impl SdkEvent {
    /// 事件类型字符串（用于日志与测试）
    pub fn as_str(&self) -> &'static str {
        match self {
            SdkEvent::Connection(e) => e.as_str(),
            SdkEvent::Message(e) => e.as_str(),
            SdkEvent::Conversation(e) => e.as_str(),
            SdkEvent::User(e) => e.as_str(),
            SdkEvent::Friend(e) => e.as_str(),
            SdkEvent::Group(e) => e.as_str(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
use crate::event::events::conversation::ConversationEvent;
    use crate::event::events::friend::FriendEvent;
    use crate::event::events::group::GroupEvent;
    use crate::event::events::message::MessageEvent;
    use crate::event::events::user::UserEvent;

    #[test]
    fn test_domain_event_as_str() {
        assert_eq!(ConnectionEvent::Connecting.as_str(), "connecting");
        assert_eq!(ConnectionEvent::ConnectFailed("e".into()).as_str(), "connect_failed");
        assert_eq!(ConversationEvent::SyncStarted.as_str(), "sync_started");
        assert_eq!(ConversationEvent::UpdateLatestMessageReadState { conversation_id: "c".into() }.as_str(), "update_latest_message_read_state");
        assert_eq!(FriendEvent::Added(vec![]).as_str(), "added");
        assert_eq!(FriendEvent::ApplicationAccepted("u".into()).as_str(), "application_accepted");
        assert_eq!(GroupEvent::ApplicationAdded("g".into()).as_str(), "application_added");
        assert_eq!(GroupEvent::GroupReadReceipt(vec![]).as_str(), "group_read_receipt");
        assert_eq!(MessageEvent::SendFailed { client_msg_id: "m".into(), error: "e".into() }.as_str(), "send_failed");
        assert_eq!(UserEvent::UserStatusChanged { user_id: "u".into(), status: 1, platform_ids: vec![] }.as_str(), "user_status_changed");
    }

    #[test]
    fn test_sdk_event_wrapper_as_str() {
        assert_eq!(SdkEvent::Message(MessageEvent::SendFailed { client_msg_id: "m".into(), error: "e".into() }).as_str(), "send_failed");
        assert_eq!(SdkEvent::Conversation(ConversationEvent::Changed(vec![])).as_str(), "changed");
        assert_eq!(SdkEvent::Friend(FriendEvent::Added(vec![])).as_str(), "added");
        assert_eq!(SdkEvent::Group(GroupEvent::ApplicationApproved("g".into())).as_str(), "application_approved");
        assert_eq!(SdkEvent::User(UserEvent::UserStatusChanged { user_id: "u".into(), status: 1, platform_ids: vec![] }).as_str(), "user_status_changed");
    }

    #[test]
    fn test_group_read_receipt_serde() {
        let receipt = GroupReadReceipt {
            group_id: "g".into(),
            msg_id: "m".into(),
            has_read_user_id_list: vec!["u1".into()],
            has_read_count: 1,
            group_member_count: 2,
            read_time: 1000,
        };
        let json = serde_json::to_string(&receipt).unwrap();
        let back: GroupReadReceipt = serde_json::from_str(&json).unwrap();
        assert_eq!(back.group_id, "g");
        assert_eq!(back.has_read_count, 1);
    }
}