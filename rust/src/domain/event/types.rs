use std::collections::HashMap;
use crate::domain::model::conversation::Conversation;
use crate::domain::model::friend::FriendInfo;
use crate::domain::model::message::ReceivedMessage;
use crate::domain::model::user::UserInfo;
use crate::protocol::sdkws::MsgData;

/// C2C 已读回执（对齐 Go SDK `sdkws.MessageReceipt`）
#[derive(Clone, Debug)]
pub struct MessageReceipt {
    pub user_id: String,
    pub msg_ids: Vec<String>,
    pub read_time: i64,
    pub session_type: i32,
}

#[derive(Clone, Debug)]
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
    PushMessages {
        conversation_id: String,
        msgs: Vec<MsgData>,
        is_end: bool,
        end_seq: i64,
    },
    PushNotificationMessages {
        conversation_id: String,
        msgs: Vec<MsgData>,
        is_end: bool,
        end_seq: i64,
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
        message: ReceivedMessage,
    },
    MessageSent {
        client_msg_id: String,
        server_msg_id: String,
        send_time: i64,
        status: i32,
        conversation_id: String,
        send_id: String,
        recv_id: String,
        group_id: String,
        session_type: i32,
        content_type: i32,
        content: String,
        sender_nickname: String,
        sender_face_url: String,
    },
    MessageSendFailed {
        client_msg_id: String,
        error: String,
    },
    UploadProgress {
        client_msg_id: String,
        progress: u8,
        total_size: u64,
        uploaded_size: u64,
    },
    MessageRevoked {
        conversation_id: String,
        seq: i64,
        client_msg_id: String,
    },
    /// C2C 已读回执（对齐 Go SDK `OnRecvC2CReadReceipt`）
    C2CReadReceipt {
        receipts: Vec<MessageReceipt>,
    },
    MessagesDeleted {
        conversation_id: String,
        client_msg_ids: Vec<String>,
    },
    ConversationChanged {
        conversations: Vec<Conversation>,
    },
    ConversationDeleted {
        conversation_ids: Vec<String>,
    },
    NewConversation {
        conversations: Vec<Conversation>,
    },
    TotalUnreadCountChanged {
        count: i64,
    },
    FriendApplicationAdded {
        application: String,
    },
    FriendApplicationApproved {
        application: String,
    },
    FriendApplicationRejected {
        application: String,
    },
    FriendAdded {
        friends: Vec<FriendInfo>,
    },
    FriendDeleted {
        friend_id: String,
    },
    BlackAdded {
        user_id: String,
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
        application: String,
    },
    GroupApplicationApproved {
        application: String,
    },
    GroupApplicationRejected {
        application: String,
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
        user: UserInfo,
    },
    UserStatusChanged {
        user_id: String,
        status: i32,
        platform_ids: Vec<i32>,
    },
    /// 批量推送消息（经 MessageBatcher 聚合后）
    BatchedPushMessages {
        msgs: HashMap<String, crate::protocol::sdkws::PullMsgs>,
        notification_msgs: HashMap<String, crate::protocol::sdkws::PullMsgs>,
    },
    KickedOffline {
        reason: String,
    },
    Reconnecting {
        attempt: u32,
        max_attempts: u32,
    },
    TokenExpired,
    LoginSuccess {
        user_id: String,
    },
    Logout,
    CustomEvent {
        event_type: String,
        data: String,
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
            SdkEvent::PushMessages { .. } => "push_messages",
            SdkEvent::PushNotificationMessages { .. } => "push_notification_messages",
            SdkEvent::SyncStarted => "sync_started",
            SdkEvent::SyncProgress { .. } => "sync_progress",
            SdkEvent::SyncFinished => "sync_finished",
            SdkEvent::SyncFailed { .. } => "sync_failed",
            SdkEvent::NewMessage { .. } => "new_message",
            SdkEvent::MessageSent { .. } => "message_sent",
            SdkEvent::MessageSendFailed { .. } => "message_send_failed",
            SdkEvent::UploadProgress { .. } => "upload_progress",
            SdkEvent::MessageRevoked { .. } => "message_revoked",
            SdkEvent::C2CReadReceipt { .. } => "c2c_read_receipt",
            SdkEvent::MessagesDeleted { .. } => "messages_deleted",
            SdkEvent::ConversationChanged { .. } => "conversation_changed",
            SdkEvent::ConversationDeleted { .. } => "conversation_deleted",
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
            SdkEvent::BatchedPushMessages { .. } => "batched_push_messages",
            SdkEvent::KickedOffline { .. } => "kicked_offline",
            SdkEvent::Reconnecting { .. } => "reconnecting",
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
    fn test_sdk_event_new_message() {
        use crate::domain::model::message::ReceivedMessage;
        let event = SdkEvent::NewMessage {
            message: ReceivedMessage {
                server_msg_id: "srv_1".into(),
                client_msg_id: "msg_1".into(),
                send_id: "user_1".into(),
                recv_id: "user_2".into(),
                sender_platform_id: 1,
                sender_nick_name: "User1".into(),
                sender_face_url: String::new(),
                session_type: 1,
                msg_from: 100,
                content_type: 101,
                content: "{\"text\":\"hello\"}".into(),
                seq: 1,
                send_time: 1000,
                create_time: 1000,
                conversation_id: "conv_1".into(),
                group_id: String::new(),
            },
        };
        assert_eq!(event.event_type(), "new_message");
    }
}
