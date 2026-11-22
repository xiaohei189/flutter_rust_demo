use crate::domain::model::local::LocalChatLog;
use crate::domain::model::msg_struct::MsgStruct;
use openim_protocol::sdkws::MsgData;
use serde::{Deserialize, Serialize};

/// 消息信息（FFI 桥接用，将 protobuf MsgData 转换为 Dart 友好的结构体）
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MessageInfo {
    pub client_msg_id: String,
    pub server_msg_id: String,
    pub send_id: String,
    pub recv_id: String,
    pub group_id: String,
    pub sender_platform_id: i32,
    pub sender_nickname: String,
    pub sender_face_url: String,
    pub session_type: i32,
    pub msg_from: i32,
    pub content_type: i32,
    pub content: String,
    pub seq: i64,
    pub send_time: i64,
    pub create_time: i64,
    pub status: i32,
    pub is_read: bool,
    pub attached_info: String,
    pub ex: String,
}

impl From<MsgData> for MessageInfo {
    fn from(msg: MsgData) -> Self {
        Self {
            client_msg_id: msg.client_msg_id,
            server_msg_id: msg.server_msg_id,
            send_id: msg.send_id,
            recv_id: msg.recv_id,
            group_id: msg.group_id,
            sender_platform_id: msg.sender_platform_id,
            sender_nickname: msg.sender_nickname,
            sender_face_url: msg.sender_face_url,
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: String::from_utf8_lossy(&msg.content).to_string(),
            seq: msg.seq,
            send_time: msg.send_time,
            create_time: msg.create_time,
            status: msg.status,
            is_read: msg.is_read,
            attached_info: msg.attached_info,
            ex: msg.ex,
        }
    }
}

/// 本地构造的发送消息 → 事件消息（本地消息上屏事件用）
impl From<&MsgStruct> for MessageInfo {
    fn from(msg: &MsgStruct) -> Self {
        Self {
            client_msg_id: msg.client_msg_id.clone(),
            server_msg_id: msg.server_msg_id.clone(),
            send_id: msg.send_id.clone(),
            recv_id: msg.recv_id.clone(),
            group_id: msg.group_id.clone(),
            sender_platform_id: msg.sender_platform_id,
            sender_nickname: msg.sender_nickname.clone(),
            sender_face_url: msg.sender_face_url.clone(),
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: msg.content.clone(),
            seq: msg.seq,
            send_time: msg.send_time,
            create_time: msg.create_time,
            status: msg.status,
            is_read: msg.is_read,
            attached_info: msg.attached_info.clone(),
            ex: msg.ex.clone(),
        }
    }
}

/// 本地库消息 → 事件消息（发送结果事件用，携带最新状态/服务端字段）
impl From<&LocalChatLog> for MessageInfo {
    fn from(log: &LocalChatLog) -> Self {
        Self {
            client_msg_id: log.client_msg_id.clone(),
            server_msg_id: log.server_msg_id.clone(),
            send_id: log.send_id.clone(),
            recv_id: log.recv_id.clone(),
            group_id: log.group_id.clone(),
            sender_platform_id: log.sender_platform_id,
            sender_nickname: log.sender_nick_name.clone(),
            sender_face_url: log.sender_face_url.clone(),
            session_type: log.session_type,
            msg_from: log.msg_from,
            content_type: log.content_type,
            content: log.content.clone(),
            seq: log.seq,
            send_time: log.send_time,
            create_time: log.create_time,
            status: log.status,
            is_read: log.is_read != 0,
            attached_info: log.attached_info.clone(),
            ex: log.ex.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_message_info_creation() {
        let info = MessageInfo {
            client_msg_id: "msg_1".to_string(),
            server_msg_id: String::new(),
            send_id: "user_a".to_string(),
            recv_id: "user_b".to_string(),
            sender_platform_id: 1,
            sender_nickname: "Test".to_string(),
            sender_face_url: String::new(),
            session_type: 1,
            msg_from: 0,
            content_type: 101,
            content: String::new(),
            status: 1,
            seq: 0,
            send_time: 1000,
            create_time: 1000,
            is_read: false,
            ex: String::new(),
            attached_info: String::new(),
            group_id: String::new(),
        };
        assert_eq!(info.client_msg_id, "msg_1");
        assert_eq!(info.status, 1);
    }
}
