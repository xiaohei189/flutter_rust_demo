use serde::{Deserialize, Serialize};

/// 会话类型
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum SessionType {
    SingleChat = 1,
    WriteGroupChat = 2,
    ReadGroupChat = 3,
    NotificationChat = 4,
}

impl SessionType {
    pub fn from_i32(v: i32) -> Self {
        match v {
            1 => SessionType::SingleChat,
            2 => SessionType::WriteGroupChat,
            3 => SessionType::ReadGroupChat,
            4 => SessionType::NotificationChat,
            _ => SessionType::SingleChat,
        }
    }
}

impl From<SessionType> for i32 {
    fn from(s: SessionType) -> i32 {
        s as i32
    }
}

impl sqlx::Type<sqlx::Sqlite> for SessionType {
    fn type_info() -> <sqlx::Sqlite as sqlx::Database>::TypeInfo {
        <i32 as sqlx::Type<sqlx::Sqlite>>::type_info()
    }
}



/// 消息内容类型
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum ContentType {
    Text = 101,
    Picture = 102,
    Sound = 103,
    Video = 104,
    File = 105,
    AtText = 106,
    Merger = 107,
    Card = 108,
    Location = 109,
    Custom = 110,
    Typing = 113,
    Quote = 114,
    Face = 115,
    AdvancedText = 117,
    MarkdownText = 118,
    CustomNoTrigger = 119,
    CustomOnlineOnly = 120,
}

impl ContentType {
    pub fn from_i32(v: i32) -> Self {
        match v {
            101 => ContentType::Text,
            102 => ContentType::Picture,
            103 => ContentType::Sound,
            104 => ContentType::Video,
            105 => ContentType::File,
            106 => ContentType::AtText,
            107 => ContentType::Merger,
            108 => ContentType::Card,
            109 => ContentType::Location,
            110 => ContentType::Custom,
            113 => ContentType::Typing,
            114 => ContentType::Quote,
            115 => ContentType::Face,
            117 => ContentType::AdvancedText,
            118 => ContentType::MarkdownText,
            119 => ContentType::CustomNoTrigger,
            120 => ContentType::CustomOnlineOnly,
            _ => ContentType::Text,
        }
    }
}

impl From<ContentType> for i32 {
    fn from(c: ContentType) -> i32 {
        c as i32
    }
}

impl sqlx::Type<sqlx::Sqlite> for ContentType {
    fn type_info() -> <sqlx::Sqlite as sqlx::Database>::TypeInfo {
        <i32 as sqlx::Type<sqlx::Sqlite>>::type_info()
    }
}



/// 消息来源
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum MsgFrom {
    UserMsg = 100,
    SysMsg = 200,
}

impl MsgFrom {
    pub fn from_i32(v: i32) -> Self {
        match v {
            100 => MsgFrom::UserMsg,
            200 => MsgFrom::SysMsg,
            _ => MsgFrom::UserMsg,
        }
    }
}

impl From<MsgFrom> for i32 {
    fn from(m: MsgFrom) -> i32 {
        m as i32
    }
}

/// 群组类型
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum GroupType {
    Normal = 0,
    Super = 1,
    Working = 2,
}

impl GroupType {
    pub fn from_i32(v: i32) -> Self {
        match v {
            0 => GroupType::Normal,
            1 => GroupType::Super,
            2 => GroupType::Working,
            _ => GroupType::Normal,
        }
    }
}

impl From<GroupType> for i32 {
    fn from(g: GroupType) -> i32 {
        g as i32
    }
}


/// 消息发送状态（对齐 Go SDK 的 MsgStatus）
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum MessageSendStatus {
    Sending = 1,
    SendSuccess = 2,
    SendFailed = 3,
    HasDeleted = 4,
}

impl MessageSendStatus {
    pub fn from_i32(v: i32) -> Self {
        match v {
            1 => MessageSendStatus::Sending,
            2 => MessageSendStatus::SendSuccess,
            3 => MessageSendStatus::SendFailed,
            4 => MessageSendStatus::HasDeleted,
            _ => MessageSendStatus::Sending,
        }
    }
}

impl From<MessageSendStatus> for i32 {
    fn from(s: MessageSendStatus) -> i32 {
        s as i32
    }
}

impl sqlx::Type<sqlx::Sqlite> for MessageSendStatus {
    fn type_info() -> <sqlx::Sqlite as sqlx::Database>::TypeInfo {
        <i32 as sqlx::Type<sqlx::Sqlite>>::type_info()
    }
}

/// 连接状态（SDK 对外可见的连接生命周期状态）
#[derive(Clone, Copy, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum ConnectionState {
    Disconnected,
    Connecting,
    Connected,
    Reconnecting,
    Kicked,
}
