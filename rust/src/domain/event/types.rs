use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
#[serde(tag = "type", content = "data", rename_all = "camelCase")]
pub enum SdkEvent {
    Connecting,
    Connected,
    Disconnected {
        reason: String,
    },
    ConnectFailed {
        error: String,
    },
    PushMessage {
        req_identifier: i32,
        data: Vec<u8>,
    },
    SyncStarted,
    SyncProgress {
        progress: u8,
        message: String,
    },
    SyncFinished,
    SyncFailed {
        error: String,
    },
    NewMessage {
        message: serde_json::Value,
    },
    MessageSent {
        client_msg_id: String,
        server_msg_id: String,
        send_time: i64,
    },
    MessageSendFailed {
        client_msg_id: String,
        error: String,
    },
    MessageRevoked {
        client_msg_id: String,
        revoker_user_id: String,
    },
    ConversationChanged {
        conversations: Vec<serde_json::Value>,
    },
    NewConversation {
        conversations: Vec<serde_json::Value>,
    },
    TotalUnreadCountChanged {
        count: i64,
    },
    FriendApplicationAdded {
        application: serde_json::Value,
    },
    FriendApplicationApproved {
        application: serde_json::Value,
    },
    FriendApplicationRejected {
        application: serde_json::Value,
    },
    FriendAdded {
        friend: serde_json::Value,
    },
    FriendDeleted {
        friend_id: String,
    },
    BlackAdded {
        black: serde_json::Value,
    },
    BlackDeleted {
        black_id: String,
    },
    FriendInfoUpdated {
        user_id: String,
    },
    GroupCreated {
        group_id: String,
    },
    GroupInfoChanged {
        group_id: String,
    },
    GroupMemberAdded {
        group_id: String,
        member_ids: Vec<String>,
    },
    GroupMemberDeleted {
        group_id: String,
        member_ids: Vec<String>,
    },
    GroupApplicationAdded {
        application: serde_json::Value,
    },
    GroupApplicationApproved {
        application: serde_json::Value,
    },
    GroupApplicationRejected {
        application: serde_json::Value,
    },
    GroupDismissed {
        group_id: String,
    },
    GroupMuted {
        group_id: String,
    },
    GroupCancelMuted {
        group_id: String,
    },
    GroupMemberMuted {
        group_id: String,
        user_id: String,
    },
    GroupMemberCancelMuted {
        group_id: String,
        user_id: String,
    },
    GroupMemberInfoChanged {
        group_id: String,
        user_id: String,
    },
    GroupOwnerTransferred {
        group_id: String,
        new_owner_id: String,
    },
    UserInfoUpdated {
        user: serde_json::Value,
    },
    UserStatusChanged {
        user_id: String,
        status: i32,
        platform_ids: Vec<i32>,
    },
    KickedOffline {
        reason: String,
    },
    TokenExpired,
    LoginSuccess {
        user_id: String,
    },
    Logout,
    CustomEvent {
        event_type: String,
        data: serde_json::Value,
    },
}

impl SdkEvent {
    pub fn event_type(&self) -> &'static str {
        match self {
            SdkEvent::Connecting => "connecting",
            SdkEvent::Connected => "connected",
            SdkEvent::Disconnected { .. } => "disconnected",
            SdkEvent::ConnectFailed { .. } => "connect_failed",
            SdkEvent::PushMessage { .. } => "push_message",
            SdkEvent::SyncStarted => "sync_started",
            SdkEvent::SyncProgress { .. } => "sync_progress",
            SdkEvent::SyncFinished => "sync_finished",
            SdkEvent::SyncFailed { .. } => "sync_failed",
            SdkEvent::NewMessage { .. } => "new_message",
            SdkEvent::MessageSent { .. } => "message_sent",
            SdkEvent::MessageSendFailed { .. } => "message_send_failed",
            SdkEvent::MessageRevoked { .. } => "message_revoked",
            SdkEvent::ConversationChanged { .. } => "conversation_changed",
            SdkEvent::NewConversation { .. } => "new_conversation",
            SdkEvent::TotalUnreadCountChanged { .. } => "total_unread_count_changed",
            SdkEvent::FriendApplicationAdded { .. } => "friend_application_added",
            SdkEvent::FriendApplicationApproved { .. } => "friend_application_approved",
            SdkEvent::FriendApplicationRejected { .. } => "friend_application_rejected",
            SdkEvent::FriendAdded { .. } => "friend_added",
            SdkEvent::FriendDeleted { .. } => "friend_deleted",
            SdkEvent::BlackAdded { .. } => "black_added",
            SdkEvent::BlackDeleted { .. } => "black_deleted",
            SdkEvent::FriendInfoUpdated { .. } => "friend_info_updated",
            SdkEvent::GroupCreated { .. } => "group_created",
            SdkEvent::GroupInfoChanged { .. } => "group_info_changed",
            SdkEvent::GroupMemberAdded { .. } => "group_member_added",
            SdkEvent::GroupMemberDeleted { .. } => "group_member_deleted",
            SdkEvent::GroupApplicationAdded { .. } => "group_application_added",
            SdkEvent::GroupApplicationApproved { .. } => "group_application_approved",
            SdkEvent::GroupApplicationRejected { .. } => "group_application_rejected",
            SdkEvent::GroupDismissed { .. } => "group_dismissed",
            SdkEvent::GroupMuted { .. } => "group_muted",
            SdkEvent::GroupCancelMuted { .. } => "group_cancel_muted",
            SdkEvent::GroupMemberMuted { .. } => "group_member_muted",
            SdkEvent::GroupMemberCancelMuted { .. } => "group_member_cancel_muted",
            SdkEvent::GroupMemberInfoChanged { .. } => "group_member_info_changed",
            SdkEvent::GroupOwnerTransferred { .. } => "group_owner_transferred",
            SdkEvent::UserInfoUpdated { .. } => "user_info_updated",
            SdkEvent::UserStatusChanged { .. } => "user_status_changed",
            SdkEvent::KickedOffline { .. } => "kicked_offline",
            SdkEvent::TokenExpired => "token_expired",
            SdkEvent::LoginSuccess { .. } => "login_success",
            SdkEvent::Logout => "logout",
            SdkEvent::CustomEvent { .. } => "custom_event",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sdk_event_event_type() {
        assert_eq!(SdkEvent::Connecting.event_type(), "connecting");
        assert_eq!(SdkEvent::Connected.event_type(), "connected");
        assert_eq!(SdkEvent::Disconnected { reason: "test".into() }.event_type(), "disconnected");
        assert_eq!(SdkEvent::ConnectFailed { error: "err".into() }.event_type(), "connect_failed");
        assert_eq!(SdkEvent::SyncStarted.event_type(), "sync_started");
        assert_eq!(SdkEvent::SyncFinished.event_type(), "sync_finished");
        assert_eq!(SdkEvent::TokenExpired.event_type(), "token_expired");
        assert_eq!(SdkEvent::LoginSuccess { user_id: "u1".into() }.event_type(), "login_success");
        assert_eq!(SdkEvent::Logout.event_type(), "logout");
    }

    #[test]
    fn test_sdk_event_serialization() {
        let event = SdkEvent::LoginSuccess { user_id: "user_123".into() };
        let json = serde_json::to_string(&event).unwrap();
        assert!(json.contains("login_success"));
        assert!(json.contains("user_123"));
    }

    #[test]
    fn test_sdk_event_user_status_changed() {
        let event = SdkEvent::UserStatusChanged {
            user_id: "user_1".into(),
            status: 1,
            platform_ids: vec![1, 2],
        };
        assert_eq!(event.event_type(), "user_status_changed");
        let json = serde_json::to_string(&event).unwrap();
        assert!(json.contains("user_1"));
        assert!(json.contains("platform_ids"));
    }

    #[test]
    fn test_sdk_event_new_message() {
        let event = SdkEvent::NewMessage {
            message: serde_json::json!({"content": "hello", "type": 101}),
        };
        assert_eq!(event.event_type(), "new_message");
        let json = serde_json::to_string(&event).unwrap();
        assert!(json.contains("hello"));
    }
}
