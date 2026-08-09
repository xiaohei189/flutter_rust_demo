//! 消息监听 trait 与消息事件。
//!
//! `MessageEvent` 承载消息域事件，经 `MessageListener` 分发（对齐 Go SDK `MsgListener`），
//! EventHub 将其转发到消息通道，供 Dart 流 / 外部 SDK / 集成测试消费。

use serde::{Deserialize, Serialize};

use crate::model::message::MessageInfo;

/// C2C 已读回执（对齐 Go SDK sdkws.MessageReceipt）
#[derive(Clone, Debug, PartialEq)]
pub struct MessageReceipt {
    pub user_id: String,
    pub msg_ids: Vec<String>,
    pub read_time: i64,
    pub session_type: i32,
}

/// 群聊已读回执（对齐 Go SDK OnRecvGroupReadReceipt）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GroupReadReceipt {
    pub group_id: String,
    pub msg_id: String,
    pub has_read_user_id_list: Vec<String>,
    pub has_read_count: i32,
    pub group_member_count: i32,
    pub read_time: i64,
}

/// 消息域事件
#[derive(Clone, Debug)]
pub enum MessageEvent {
    /// 新消息（服务端推送/同步，对齐 Go SDK `OnRecvNewMessage`）
    NewMessage {
        conversation_id: String,
        message: MessageInfo,
    },
    /// 离线新消息（对齐 Go SDK `OnRecvOfflineNewMessage`）
    OfflineNewMessage {
        conversation_id: String,
        message: MessageInfo,
    },
    /// 在线-only 消息（对齐 Go SDK `OnRecvOnlineOnlyMessage`）
    OnlineOnlyMessage {
        conversation_id: String,
        message: MessageInfo,
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
    /// C2C 已读回执
    C2CReadReceipt { receipts: Vec<MessageReceipt> },
    /// 消息被删除
    Deleted { conversation_id: String, client_msg_ids: Vec<String> },
    /// 消息发送失败
    SendFailed { client_msg_id: String, error: String },
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
            MessageEvent::NewMessage { .. } => "new_message",
            MessageEvent::OfflineNewMessage { .. } => "offline_new_message",
            MessageEvent::OnlineOnlyMessage { .. } => "online_only_message",
            MessageEvent::Revoked { .. } => "revoked",
            MessageEvent::C2CReadReceipt { .. } => "c2c_read_receipt",
            MessageEvent::Deleted { .. } => "deleted",
            MessageEvent::SendFailed { .. } => "send_failed",
            MessageEvent::UploadProgress { .. } => "upload_progress",
        }
    }
}

/// 消息监听 trait（对齐 Go SDK `MsgListener`）
pub trait MessageListener: Send + Sync {
    fn on_new_message(&self, _conversation_id: &str, _message: &MessageInfo) {}
    fn on_offline_new_message(&self, _conversation_id: &str, _message: &MessageInfo) {}
    fn on_online_only_message(&self, _conversation_id: &str, _message: &MessageInfo) {}
    fn on_message_revoked(&self, _event: &MessageEvent) {}
    fn on_c2c_read_receipt(&self, _receipts: &[MessageReceipt]) {}
    fn on_message_deleted(&self, _conversation_id: &str, _client_msg_ids: &[String]) {}
    fn on_send_failed(&self, _client_msg_id: &str, _error: &str) {}
    fn on_upload_progress(&self, _client_msg_id: &str, _progress: u8, _total_size: u64, _uploaded_size: u64) {}
}

/// 事件 → 回调 的统一分发（Service 通过它把领域事件交给 Listener）
pub trait MessageListenerExt: MessageListener {
    fn emit(&self, event: MessageEvent) {
        match event {
            MessageEvent::NewMessage {
                conversation_id,
                message,
            } => self.on_new_message(&conversation_id, &message),
            MessageEvent::OfflineNewMessage {
                conversation_id,
                message,
            } => self.on_offline_new_message(&conversation_id, &message),
            MessageEvent::OnlineOnlyMessage {
                conversation_id,
                message,
            } => self.on_online_only_message(&conversation_id, &message),
            MessageEvent::Revoked { .. } => self.on_message_revoked(&event),
            MessageEvent::C2CReadReceipt { receipts } => self.on_c2c_read_receipt(&receipts),
            MessageEvent::Deleted { conversation_id, client_msg_ids } => self.on_message_deleted(&conversation_id, &client_msg_ids),
            MessageEvent::SendFailed { client_msg_id, error } => self.on_send_failed(&client_msg_id, &error),
            MessageEvent::UploadProgress {
                client_msg_id,
                progress,
                total_size,
                uploaded_size,
            } => self.on_upload_progress(&client_msg_id, progress, total_size, uploaded_size),
        }
    }
}
impl<T: MessageListener + ?Sized> MessageListenerExt for T {}
