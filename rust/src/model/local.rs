//! 本地持久化模型（Local*，对齐 Go SDK `pkg/db/model_struct/data_model_struct.go`）
//!
//! 数据库行模型，由 sqlx `FromRow` 映射；被 DAO 与 Repository trait 共同使用。
//! 原位于 `infra/database/models.rs`，收归 domain 后与领域模型同层。
use crate::constant::{msg_status, session_type, MessageSendStatus, SessionType};
use openim_protocol::sdkws::MsgData;
use sqlx::FromRow;

#[derive(Debug, Clone, FromRow)]
pub struct LocalChatLog {
    pub conversation_id: String,
    pub client_msg_id: String,
    pub server_msg_id: String,
    pub send_id: String,
    pub recv_id: String,
    pub sender_platform_id: i32,
    pub sender_nick_name: String,
    pub sender_face_url: String,
    pub session_type: i32,
    pub msg_from: i32,
    pub content_type: i32,
    pub content: String,
    pub is_read: i32,
    pub status: i32,
    pub seq: i64,
    pub send_time: i64,
    pub create_time: i64,
    pub attached_info: String,
    pub ex: String,
    pub local_ex: String,
    pub group_id: String,
}

impl LocalChatLog {
    pub fn send_status(&self) -> MessageSendStatus {
        MessageSendStatus::from_i32(self.status)
    }

    /// 协议消息 → 本地消息（对齐 Go SDK `MsgDataToLocalChatLog`）
    pub fn from_msg_data(conv_id: &str, msg: &MsgData) -> Self {
        // 群聊消息：RecvID 使用 GroupID（对齐 Go SDK）
        let recv_id = if msg.session_type == session_type::WRITE_GROUP_CHAT
            || msg.session_type == session_type::READ_GROUP_CHAT
        {
            msg.group_id.clone()
        } else {
            msg.recv_id.clone()
        };
        // status >= HAS_DELETED 保持原值，否则置为发送成功（对齐 Go SDK）
        let status = if msg.status >= msg_status::HAS_DELETED {
            msg.status
        } else {
            msg_status::SEND_SUCCESS
        };
        Self {
            conversation_id: conv_id.to_string(),
            client_msg_id: msg.client_msg_id.clone(),
            server_msg_id: msg.server_msg_id.clone(),
            send_id: msg.send_id.clone(),
            recv_id,
            sender_platform_id: msg.sender_platform_id,
            sender_nick_name: msg.sender_nickname.clone(),
            sender_face_url: msg.sender_face_url.clone(),
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: String::from_utf8_lossy(&msg.content).to_string(),
            is_read: 0,
            status,
            seq: msg.seq,
            send_time: msg.send_time,
            create_time: msg.create_time,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            group_id: msg.group_id.clone(),
        }
    }
}

#[derive(Debug, Clone, FromRow, serde::Serialize, serde::Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct LocalConversation {
    pub conversation_id: String,
    pub conversation_type: i32,
    pub user_id: String,
    pub group_id: String,
    pub show_name: String,
    pub face_url: String,
    pub latest_msg: String,
    pub latest_msg_send_time: i64,
    pub unread_count: i32,
    pub recv_msg_opt: i32,
    pub is_pinned: bool,
    pub is_private_chat: bool,
    pub burn_duration: i32,
    pub group_at_type: i32,
    pub is_not_in_group: bool,
    pub update_unread_count_time: i64,
    pub attached_info: String,
    pub ex: String,
    pub draft_text: String,
    pub draft_text_time: i64,
    pub max_seq: i64,
    pub min_seq: i64,
    pub is_msg_destruct: bool,
    pub msg_destruct_time: i64,
}

impl LocalConversation {
    pub fn session_type(&self) -> SessionType {
        SessionType::from_i32(self.conversation_type)
    }
}

#[derive(Debug, Clone, FromRow)]
pub struct LocalUser {
    pub user_id: String,
    pub name: String,
    pub face_url: String,
    pub create_time: i64,
    pub app_manger_level: i32,
    pub ex: String,
    pub attached_info: String,
    pub global_recv_msg_opt: i32,
}

#[derive(Debug, Clone, FromRow)]
pub struct LocalFriend {
    pub owner_user_id: String,
    pub friend_user_id: String,
    pub remark: String,
    pub create_time: i64,
    pub add_source: i32,
    pub operator_user_id: String,
    pub nickname: String,
    pub face_url: String,
    pub ex: String,
    pub attached_info: String,
    pub is_pinned: i32,
}

#[derive(Debug, Clone, FromRow)]
pub struct LocalGroup {
    pub group_id: String,
    pub name: String,
    pub notification: String,
    pub introduction: String,
    pub face_url: String,
    pub create_time: i64,
    pub status: i32,
    pub creator_user_id: String,
    pub group_type: i32,
    pub owner_user_id: String,
    pub member_count: i32,
    pub ex: String,
    pub attached_info: String,
    pub need_verification: i32,
    pub look_member_info: i32,
    pub apply_member_friend: i32,
    pub notification_update_time: i64,
    pub notification_user_id: String,
}

#[derive(Debug, Clone, FromRow)]
pub struct LocalGroupMember {
    pub group_id: String,
    pub user_id: String,
    pub nickname: String,
    pub user_group_face_url: String,
    pub role_level: i32,
    pub join_time: i64,
    pub join_source: i32,
    pub inviter_user_id: String,
    pub mute_end_time: i64,
    pub operator_user_id: String,
    pub ex: String,
    pub attached_info: String,
}

#[derive(Debug, Clone, FromRow)]
pub struct LocalBlack {
    pub owner_user_id: String,
    pub block_user_id: String,
    pub nickname: String,
    pub face_url: String,
    pub create_time: i64,
    pub add_source: i32,
    pub operator_user_id: String,
    pub ex: String,
    pub attached_info: String,
}

#[derive(Debug, Clone, FromRow)]
pub struct LocalSendingMessage {
    pub conversation_id: String,
    pub client_msg_id: String,
    pub ex: String,
}

/// 通知会话 seq 追踪
/// 对齐 Go SDK `pkg/db/model_struct/data_model_struct.go` 的 NotificationSeqs
/// 用于存储通知类型会话（conversationID 以 `n_` 开头）已同步到的最大 seq
#[derive(Debug, Clone, FromRow)]
pub struct LocalNotificationSeq {
    pub conversation_id: String,
    pub seq: i64,
}

/// 分片上传断点续传记录
/// 对齐 Go SDK `pkg/db/model_struct/data_model_struct.go` 的 LocalUpload
#[derive(Debug, Clone, FromRow)]
pub struct LocalUpload {
    pub part_hash: String,
    pub upload_id: String,
    pub upload_info: String,
    pub expire_time: i64,
    pub create_time: i64,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_msg(session_type: i32, status: i32) -> MsgData {
        MsgData {
            client_msg_id: "c1".into(),
            server_msg_id: "s1".into(),
            send_id: "u1".into(),
            recv_id: "u2".into(),
            group_id: "g1".into(),
            session_type,
            status,
            ..Default::default()
        }
    }

    #[test]
    fn from_msg_data_group_chat_uses_group_id_as_recv_id() {
        let log = LocalChatLog::from_msg_data("conv", &make_msg(session_type::WRITE_GROUP_CHAT, 0));
        assert_eq!(log.recv_id, "g1");
        let log = LocalChatLog::from_msg_data("conv", &make_msg(session_type::READ_GROUP_CHAT, 0));
        assert_eq!(log.recv_id, "g1");
    }

    #[test]
    fn from_msg_data_single_chat_keeps_recv_id() {
        let log = LocalChatLog::from_msg_data("conv", &make_msg(session_type::SINGLE_CHAT, 0));
        assert_eq!(log.recv_id, "u2");
    }

    #[test]
    fn from_msg_data_status_preserved_when_deleted() {
        let log = LocalChatLog::from_msg_data("conv", &make_msg(session_type::SINGLE_CHAT, msg_status::HAS_DELETED));
        assert_eq!(log.status, msg_status::HAS_DELETED);
        let log = LocalChatLog::from_msg_data("conv", &make_msg(session_type::SINGLE_CHAT, 0));
        assert_eq!(log.status, msg_status::SEND_SUCCESS);
    }
}
