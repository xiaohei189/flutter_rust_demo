//! 消息事件监听器

use crate::frb_generated::StreamSink;
use crate::im::message::types::{MsgStruct, MessageRevoked, TypingStatus};
use serde::{Deserialize, Serialize};

// 重新导出 Arc 和 Mutex，以便生成的代码通过 use crate::api::listeners::message::*; 可以访问
pub use std::sync::{Arc, Mutex};

/// 消息事件枚举，包含所有消息相关的回调事件
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum MessageEvent {
    /// 收到新消息（在线消息）
    RecvNewMessage {
        message: MsgStruct,
    },
    /// 收到 C2C 已读回执
    /// 参数 `msg_receipt_list` 是已读回执列表的 JSON 字符串表示（列表结构较复杂，暂用 String）
    RecvC2CReadReceipt {
        msg_receipt_list: String, // JSON 字符串，列表结构
    },
    /// 收到消息撤回通知
    NewRecvMessageRevoked {
        message_revoked: MessageRevoked,
    },
    /// 收到离线新消息
    RecvOfflineNewMessage {
        message: MsgStruct,
    },
    /// 消息被删除
    /// 参数 `message` 是删除消息信息的 JSON 字符串表示（可能是 MsgStruct 或删除信息）
    MsgDeleted {
        message: MsgStruct,
    },
    /// 收到仅在线消息（不存储到本地）
    RecvOnlineOnlyMessage {
        message: MsgStruct,
    },
    /// 被踢下线
    KickedOffline,
    /// 收到输入提示（typing）状态
    RecvTypingStatus {
        typing_status: TypingStatus,
    },
}

/// 消息事件监听器（桥接到 Dart）
pub struct DartMessageListener {
    pub sink: Arc<Mutex<Option<StreamSink<MessageEvent>>>>,
}

impl DartMessageListener {
    pub fn new() -> Self {
        Self {
            sink: Arc::new(Mutex::new(None)),
        }
    }

    /// 设置消息 sink
    pub fn set_sink(&self, sink: StreamSink<MessageEvent>) {
        *self.sink.lock().unwrap() = Some(sink);
    }

    /// 发送消息事件
    pub(crate) fn send_event(&self, event: MessageEvent) {
        if let Ok(sink) = self.sink.lock() {
            if let Some(ref s) = *sink {
                let _ = s.add(event);
            }
        }
    }
}

