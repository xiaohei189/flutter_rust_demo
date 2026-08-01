//! 会话模型转换器 - ServerConversation -> LocalConversation（对齐 Go SDK `ServerConversationToLocal`）

use crate::domain::model::local::LocalConversation;

use crate::domain::ports::conversation::ServerConversation;

/// 服务端模型 -> 本地持久化模型（对齐 Go SDK `ServerConversationToLocal`）
///
/// 通过 `From` trait 实现，可用 `s.into()` 或 `LocalConversation::from(s)` 调用。
impl From<ServerConversation> for LocalConversation {
    fn from(s: ServerConversation) -> Self {
        LocalConversation {
            conversation_id: s.conversation_id,
            conversation_type: s.conversation_type,
            user_id: s.user_id,
            group_id: s.group_id,
            show_name: String::new(),
            face_url: String::new(),
            latest_msg: String::new(),
            latest_msg_send_time: 0,
            unread_count: 0,
            recv_msg_opt: s.recv_msg_opt,
            is_pinned: s.is_pinned,
            is_private_chat: s.is_private_chat,
            burn_duration: s.burn_duration,
            group_at_type: s.group_at_type,
            is_not_in_group: false,
            update_unread_count_time: 0,
            attached_info: s.attached_info,
            ex: s.ex,
            draft_text: String::new(),
            draft_text_time: 0,
            max_seq: s.max_seq,
            min_seq: s.min_seq,
            is_msg_destruct: s.is_msg_destruct,
            msg_destruct_time: s.msg_destruct_time,
        }
    }
}
