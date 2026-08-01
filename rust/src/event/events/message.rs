//! 消息监听 trait 与消息事件。
//!
//! 说明：`MessageEvent` 为内部事件总线承载的消息域事件（经 `SdkEvent::Message` 分发），
//! Dart 侧暂未开放消息流——新消息通过会话变更事件与历史拉取呈现，
//! 后续如需消息流可基于此枚举扩展。

use crate::event::types::{GroupReadReceipt, MessageReceipt};
use openim_protocol::sdkws::MsgData;

/// 消息域事件（内部事件总线使用）
#[derive(Clone, Debug)]
pub enum MessageEvent {
    /// 服务端推送（通知类消息，供内部通知处理器消费）
    PushNotificationMessages {
        conversation_id: String,
        msgs: Vec<MsgData>,
        is_end: bool,
        end_seq: i64,
    },
    /// 消息发送失败
    SendFailed {
        client_msg_id: String,
        error: String,
    },
    /// 消息被撤回
    Revoked {
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
    /// 新消息（服务端推送/同步）
    NewMessage {
        message: MsgData,
    },
    /// C2C 已读回执
    C2CReadReceipt {
        receipts: Vec<MessageReceipt>,
    },
    /// 消息被删除
    Deleted {
        conversation_id: String,
        client_msg_ids: Vec<String>,
    },
    /// 上传进度
    UploadProgress {
        client_msg_id: String,
        progress: u8,
        total_size: u64,
        uploaded_size: u64,
    },
}

impl MessageEvent {
    /// 事件类型字符串（用于日志与测试）
    pub fn as_str(&self) -> &'static str {
        match self {
            MessageEvent::PushNotificationMessages { .. } => "push_notification_messages",
            MessageEvent::SendFailed { .. } => "send_failed",
            MessageEvent::Revoked { .. } => "revoked",
            MessageEvent::NewMessage { .. } => "new_message",
            MessageEvent::C2CReadReceipt { .. } => "c2c_read_receipt",
            MessageEvent::Deleted { .. } => "deleted",
            MessageEvent::UploadProgress { .. } => "upload_progress",
        }
    }
}

/// 消息监听 trait（对齐 Go SDK MessageListener）
pub trait MessageListener: Send + Sync {
    fn on_new_message(&self, _message: &MsgData) {}
    fn on_recv_offline_new_message(&self, _messages: &[MsgData]) {}
    fn on_c2c_read_receipt(&self, _receipts: &[MessageReceipt]) {}
    fn on_group_read_receipt(&self, _receipts: &[GroupReadReceipt]) {}
    fn on_message_revoked(&self, _message: &MsgData) {}
    fn on_messages_deleted(&self, _conversation_id: &str, _client_msg_ids: &[String]) {}
    fn on_send_failed(&self, _client_msg_id: &str, _error: &str) {}
}