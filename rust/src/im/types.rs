use serde::{Deserialize, Serialize};

/// WebSocket 消息类型标识符
pub mod msg_type {
    pub const WS_GET_NEWEST_SEQ: i32 = 1001;
    pub const WS_SEND_MSG: i32 = 1003;
    pub const WS_PUSH_MSG: i32 = 2001;
    pub const WS_KICK_ONLINE_MSG: i32 = 2002;
    pub const WS_LOGOUT_MSG: i32 = 2003;
}


/// OpenIM 请求结构
#[derive(Debug, Serialize, Deserialize)]
pub struct OpenIMReq {
    #[serde(rename = "reqIdentifier")]
    pub req_identifier: i32,
    pub token: String,
    #[serde(rename = "sendID")]
    pub send_id: String,
    #[serde(rename = "operationID")]
    pub operation_id: String,
    #[serde(rename = "msgIncr")]
    pub msg_incr: String,
    #[serde(default)]
    pub data: Vec<u8>,
}

/// OpenIM 响应结构
#[derive(Debug, Deserialize, Serialize)]
pub struct OpenIMResp {
    #[serde(rename = "reqIdentifier")]
    pub req_identifier: i32,
    #[serde(rename = "msgIncr")]
    pub msg_incr: String,
    #[serde(rename = "operationID")]
    pub operation_id: String,
    #[serde(rename = "errCode")]
    pub err_code: i32,
    #[serde(rename = "errMsg")]
    pub err_msg: String,
    #[serde(default, deserialize_with = "crate::im::serialization::deserialize_base64")]
    pub data: Vec<u8>,
}

/// 服务器响应结构
#[derive(Debug, Deserialize)]
pub struct ServerResponse {
    #[serde(rename = "errCode")]
    pub err_code: i32,
    #[serde(rename = "errMsg")]
    pub err_msg: String,
}

/// 消息事件类型
#[derive(Debug, Clone)]
#[flutter_rust_bridge::frb(opaque)]
pub enum MessageEvent {
    /// 收到新消息
    NewMessage {
        /// 会话 ID
        conversation_id: String,
        /// 完整的消息数据（直接使用 openim_protocol::sdkws::MsgData）
        message: openim_protocol::sdkws::MsgData,
        /// 是否为通知消息
        is_notification: bool,
    },
    /// 消息发送响应
    SendMessageResponse {
        success: bool,
        err_msg: String,
        server_msg_id: String,
        client_msg_id: String,
    },
    /// 被踢下线
    KickedOffline,
    /// 连接状态变化
    ConnectionStatus {
        connected: bool,
        message: String,
    },
    /// 其他消息
    Other {
        req_identifier: i32,
        message: String,
    },
}

impl MessageEvent {
    /// 获取事件类型名称
    #[flutter_rust_bridge::frb(sync)]
    pub fn event_type(&self) -> String {
        match self {
            MessageEvent::NewMessage { .. } => "NewMessage".to_string(),
            MessageEvent::SendMessageResponse { .. } => "SendMessageResponse".to_string(),
            MessageEvent::KickedOffline => "KickedOffline".to_string(),
            MessageEvent::ConnectionStatus { .. } => "ConnectionStatus".to_string(),
            MessageEvent::Other { .. } => "Other".to_string(),
        }
    }

    /// 如果是 NewMessage，获取会话 ID
    #[flutter_rust_bridge::frb(sync)]
    pub fn get_conversation_id(&self) -> Option<String> {
        match self {
            MessageEvent::NewMessage { conversation_id, .. } => Some(conversation_id.clone()),
            _ => None,
        }
    }

    /// 如果是 NewMessage，获取发送者 ID
    #[flutter_rust_bridge::frb(sync)]
    pub fn get_send_id(&self) -> Option<String> {
        match self {
            MessageEvent::NewMessage { message, .. } => message.send_id.clone(),
            _ => None,
        }
    }

    /// 如果是 NewMessage，获取接收者 ID
    #[flutter_rust_bridge::frb(sync)]
    pub fn get_recv_id(&self) -> Option<String> {
        match self {
            MessageEvent::NewMessage { message, .. } => message.recv_id.clone(),
            _ => None,
        }
    }

    /// 如果是 NewMessage，获取消息内容（文本）
    #[flutter_rust_bridge::frb(sync)]
    pub fn get_content(&self) -> Option<String> {
        match self {
            MessageEvent::NewMessage { message, .. } => {
                if message.content.is_empty() {
                    return None;
                }
                match String::from_utf8(message.content.clone()) {
                    Ok(s) => {
                        // 尝试解析 JSON 格式的内容
                        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&s) {
                            if let Some(text) = json.get("content").and_then(|v| v.as_str()) {
                                return Some(text.to_string());
                            }
                        }
                        Some(s)
                    }
                    Err(_) => None,
                }
            }
            _ => None,
        }
    }

    /// 如果是 NewMessage，获取消息时间戳
    #[flutter_rust_bridge::frb(sync)]
    pub fn get_send_time(&self) -> Option<i64> {
        match self {
            MessageEvent::NewMessage { message, .. } => Some(message.send_time),
            _ => None,
        }
    }

    /// 如果是 NewMessage，获取消息类型
    #[flutter_rust_bridge::frb(sync)]
    pub fn get_content_type(&self) -> Option<i32> {
        match self {
            MessageEvent::NewMessage { message, .. } => Some(message.content_type),
            _ => None,
        }
    }

    /// 如果是 SendMessageResponse，获取响应信息
    #[flutter_rust_bridge::frb(sync)]
    pub fn get_send_response(&self) -> Option<(bool, String, String, String)> {
        match self {
            MessageEvent::SendMessageResponse {
                success,
                err_msg,
                server_msg_id,
                client_msg_id,
            } => Some((
                *success,
                err_msg.clone(),
                server_msg_id.clone(),
                client_msg_id.clone(),
            )),
            _ => None,
        }
    }

    /// 如果是 ConnectionStatus，获取连接状态
    #[flutter_rust_bridge::frb(sync)]
    pub fn get_connection_status(&self) -> Option<(bool, String)> {
        match self {
            MessageEvent::ConnectionStatus { connected, message } => {
                Some((*connected, message.clone()))
            }
            _ => None,
        }
    }
}

