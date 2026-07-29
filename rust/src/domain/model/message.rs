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
