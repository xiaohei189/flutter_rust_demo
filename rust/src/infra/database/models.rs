use crate::domain::constant::enums::SessionType;
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

#[derive(Debug, Clone, FromRow)]
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
    pub is_pinned: i32,
    pub is_private_chat: i32,
    pub burn_duration: i32,
    pub group_at_type: i32,
    pub is_not_in_group: i32,
    pub update_unread_count_time: i64,
    pub attached_info: String,
    pub ex: String,
    pub draft_text: String,
    pub draft_text_time: i64,
    pub max_seq: i64,
    pub min_seq: i64,
    pub is_msg_destruct: i32,
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
