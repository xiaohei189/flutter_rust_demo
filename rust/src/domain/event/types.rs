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

/// 用户输入状态变化数据（对齐 Go SDK `OnConversationUserInputStatusChanged`）
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct InputStatusChangedData {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "platformIDs")]
    pub platform_ids: Vec<i32>,
}

/// 消息扩展（Reaction）变更数据（对齐 Go SDK `OnRecvMessageExtensionsChanged` 等）
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct MessageExtensionData {
    pub client_msg_id: String,
    pub reaction_extension_list: String,
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
        revoker_id: String,
        revoker_role: i32,
        revoker_nickname: String,
        revoke_time: i64,
        source_message_send_time: i64,
        source_message_send_id: String,
        source_message_sender_nickname: String,
        session_type: i32,
        is_admin_revoke: bool,
    },
    /// C2C 已读回执（对齐 Go SDK `OnRecvC2CReadReceipt`）
    C2CReadReceipt {
        receipts: Vec<MessageReceipt>,
    },
    /// 群聊已读回执（对齐 Go SDK `OnRecvGroupReadReceipt`）
    GroupReadReceipt {
        receipts: Vec<GroupReadReceipt>,
    },
    /// 用户输入状态变化（对齐 Go SDK `OnConversationUserInputStatusChanged`）
    ConversationUserInputStatusChanged {
        data: InputStatusChangedData,
    },
    /// 离线新消息通知（对齐 Go SDK `OnRecvOfflineNewMessage`）
    RecvOfflineNewMessage {
        messages: Vec<ReceivedMessage>,
    },
    /// 消息被编辑通知（对齐 Go SDK `OnMsgEdited` / `OnRecvMessageModified`）
    MsgEdited {
        message: ReceivedMessage,
    },
    /// 消息扩展（Reaction）新增（对齐 Go SDK `OnRecvMessageExtensionsAdded`）
    MessageExtensionsAdded {
        data: MessageExtensionData,
    },
    /// 消息扩展（Reaction）变更（对齐 Go SDK `OnRecvMessageExtensionsChanged`）
    MessageExtensionsChanged {
        data: MessageExtensionData,
    },
    /// 消息扩展（Reaction）删除（对齐 Go SDK `OnRecvMessageExtensionsDeleted`）
    MessageExtensionsDeleted {
        data: MessageExtensionData,
    },
    MessagesDeleted {
        conversation_id: String,
        client_msg_ids: Vec<String>,
    },
    ConversationChanged {
        conversations: Vec<Conversation>,
    },
    /// 最新消息已读状态变更（对齐 Go SDK `UpdateLatestMessageReadState`）
    UpdateLatestMessageReadState {
        conversation_id: String,
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
            SdkEvent::GroupReadReceipt { .. } => "group_read_receipt",
            SdkEvent::ConversationUserInputStatusChanged { .. } => "conversation_user_input_status_changed",
            SdkEvent::RecvOfflineNewMessage { .. } => "recv_offline_new_message",
            SdkEvent::MsgEdited { .. } => "msg_edited",
            SdkEvent::MessageExtensionsAdded { .. } => "message_extensions_added",
            SdkEvent::MessageExtensionsChanged { .. } => "message_extensions_changed",
            SdkEvent::MessageExtensionsDeleted { .. } => "message_extensions_deleted",
            SdkEvent::MessagesDeleted { .. } => "messages_deleted",
            SdkEvent::ConversationChanged { .. } => "conversation_changed",
            SdkEvent::UpdateLatestMessageReadState { .. } => "update_latest_message_read_state",
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
                is_online_only: false,
            },
        };
        assert_eq!(event.event_type(), "new_message");
    }

    // ========== 第四批：事件回调完整性测试 ==========

    #[test]
    fn test_sync_progress_event_type() {
        let event = SdkEvent::SyncProgress {
            progress: 50,
            message: "同步中".to_string(),
        };
        assert_eq!(event.event_type(), "sync_progress");
    }

    #[test]
    fn test_sync_failed_event_type() {
        let event = SdkEvent::SyncFailed {
            error: "网络断开".to_string(),
        };
        assert_eq!(event.event_type(), "sync_failed");
    }

    #[test]
    fn test_group_read_receipt_event_type() {
        let event = SdkEvent::GroupReadReceipt {
            receipts: vec![GroupReadReceipt {
                group_id: "g_123".into(),
                msg_id: "msg_1".into(),
                has_read_user_id_list: vec!["user_1".into(), "user_2".into()],
                has_read_count: 2,
                group_member_count: 10,
                read_time: 1700000000,
            }],
        };
        assert_eq!(event.event_type(), "group_read_receipt");
    }

    #[test]
    fn test_group_read_receipt_data_structure() {
        let receipt = GroupReadReceipt {
            group_id: "g_abc".into(),
            msg_id: "msg_xyz".into(),
            has_read_user_id_list: vec!["u1".into(), "u2".into(), "u3".into()],
            has_read_count: 3,
            group_member_count: 20,
            read_time: 1700000000,
        };
        assert_eq!(receipt.group_id, "g_abc");
        assert_eq!(receipt.has_read_count, 3);
        assert_eq!(receipt.has_read_user_id_list.len(), 3);

        // 验证序列化/反序列化
        let json = serde_json::to_string(&receipt).unwrap();
        let deserialized: GroupReadReceipt = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.group_id, receipt.group_id);
        assert_eq!(deserialized.has_read_count, receipt.has_read_count);
    }

    #[test]
    fn test_input_status_changed_event_type() {
        let event = SdkEvent::ConversationUserInputStatusChanged {
            data: InputStatusChangedData {
                conversation_id: "si_u1_u2".into(),
                user_id: "user_1".into(),
                platform_ids: vec![1],
            },
        };
        assert_eq!(event.event_type(), "conversation_user_input_status_changed");
    }

    #[test]
    fn test_input_status_changed_data_structure() {
        let data = InputStatusChangedData {
            conversation_id: "si_u1_u2".into(),
            user_id: "user_1".into(),
            platform_ids: vec![1, 2],
        };
        let json = serde_json::to_string(&data).unwrap();
        assert!(json.contains("conversationID"));
        assert!(json.contains("userID"));
        assert!(json.contains("platformIDs"));

        let deserialized: InputStatusChangedData = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.conversation_id, "si_u1_u2");
        assert_eq!(deserialized.user_id, "user_1");
        assert_eq!(deserialized.platform_ids, vec![1, 2]);
    }

    #[test]
    fn test_input_status_stopped_has_empty_platforms() {
        let data = InputStatusChangedData {
            conversation_id: "si_u1_u2".into(),
            user_id: "user_1".into(),
            platform_ids: vec![], // 空表示停止输入
        };
        assert!(data.platform_ids.is_empty());
    }

    #[test]
    fn test_recv_offline_new_message_event_type() {
        use crate::domain::model::message::ReceivedMessage;
        let event = SdkEvent::RecvOfflineNewMessage {
            messages: vec![ReceivedMessage {
                server_msg_id: "srv_off".into(),
                client_msg_id: "msg_off".into(),
                send_id: "user_1".into(),
                recv_id: "user_2".into(),
                sender_platform_id: 1,
                sender_nick_name: String::new(),
                sender_face_url: String::new(),
                session_type: 1,
                msg_from: 100,
                content_type: 101,
                content: "{\"text\":\"offline msg\"}".into(),
                seq: 5,
                send_time: 1700000000,
                create_time: 1700000000,
                conversation_id: "si_u1_u2".into(),
                group_id: String::new(),
                is_online_only: false,
            }],
        };
        assert_eq!(event.event_type(), "recv_offline_new_message");
    }

    #[test]
    fn test_msg_edited_event_type() {
        use crate::domain::model::message::ReceivedMessage;
        let event = SdkEvent::MsgEdited {
            message: ReceivedMessage {
                server_msg_id: "srv_edit".into(),
                client_msg_id: "msg_edit".into(),
                send_id: "user_1".into(),
                recv_id: "user_2".into(),
                sender_platform_id: 1,
                sender_nick_name: String::new(),
                sender_face_url: String::new(),
                session_type: 1,
                msg_from: 100,
                content_type: 101,
                content: "{\"text\":\"edited\"}".into(),
                seq: 10,
                send_time: 1700000000,
                create_time: 1700000000,
                conversation_id: "si_u1_u2".into(),
                group_id: String::new(),
                is_online_only: false,
            },
        };
        assert_eq!(event.event_type(), "msg_edited");
    }

    #[test]
    fn test_message_extensions_added_event_type() {
        let event = SdkEvent::MessageExtensionsAdded {
            data: MessageExtensionData {
                client_msg_id: "msg_1".into(),
                reaction_extension_list: "[{\"type\":\"👍\"}]".into(),
            },
        };
        assert_eq!(event.event_type(), "message_extensions_added");
    }

    #[test]
    fn test_message_extensions_changed_event_type() {
        let event = SdkEvent::MessageExtensionsChanged {
            data: MessageExtensionData {
                client_msg_id: "msg_1".into(),
                reaction_extension_list: "[{\"type\":\"❤️\",\"count\":3}]".into(),
            },
        };
        assert_eq!(event.event_type(), "message_extensions_changed");
    }

    #[test]
    fn test_message_extensions_deleted_event_type() {
        let event = SdkEvent::MessageExtensionsDeleted {
            data: MessageExtensionData {
                client_msg_id: "msg_1".into(),
                reaction_extension_list: "[\"👍\"]".into(),
            },
        };
        assert_eq!(event.event_type(), "message_extensions_deleted");
    }

    #[test]
    fn test_message_extension_data_structure() {
        let data = MessageExtensionData {
            client_msg_id: "msg_abc".into(),
            reaction_extension_list: "[{\"type\":\"👍\",\"count\":5}]".into(),
        };
        let json = serde_json::to_string(&data).unwrap();
        let deserialized: MessageExtensionData = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.client_msg_id, "msg_abc");
        assert!(deserialized.reaction_extension_list.contains("👍"));
    }
}
