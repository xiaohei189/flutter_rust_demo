//! 会话模型转换器 - 集中管理 Server/Domain/Local 三层模型互转

use crate::domain::model::conversation::Conversation;
use crate::infra::database::models::LocalConversation;

use super::types::ServerConversation;

/// 服务端模型 -> 领域模型
pub fn server_to_domain(s: ServerConversation) -> Conversation {
    Conversation {
        conversation_id: s.conversation_id,
        conversation_type: s.conversation_type,
        user_id: s.user_id,
        group_id: s.group_id,
        show_name: String::new(),
        face_url: String::new(),
        recv_msg_opt: s.recv_msg_opt,
        unread_count: 0,
        group_at_type: s.group_at_type,
        latest_msg_seq: s.max_seq,
        latest_msg: String::new(),
        latest_msg_send_time: 0,
        draft_text: String::new(),
        draft_text_time: 0,
        is_pinned: s.is_pinned,
        is_private_chat: s.is_private_chat,
        is_not_in_group: false,
        update_flag: 0,
        sync_action: None,
        update_unread_count_time: 0,
        max_seq: s.max_seq,
        min_seq: s.min_seq,
        is_msg_destruct: s.is_msg_destruct,
        msg_destruct_time: s.msg_destruct_time,
        is_private: s.is_private_chat,
        burn_duration: s.burn_duration,
        ex: s.ex,
    }
}

/// 持久化模型 -> 领域模型
pub fn local_to_domain(lc: LocalConversation) -> Conversation {
    Conversation {
        conversation_id: lc.conversation_id,
        conversation_type: lc.conversation_type,
        user_id: lc.user_id,
        group_id: lc.group_id,
        show_name: lc.show_name,
        face_url: lc.face_url,
        recv_msg_opt: lc.recv_msg_opt,
        unread_count: lc.unread_count,
        group_at_type: lc.group_at_type,
        latest_msg_seq: lc.max_seq,
        latest_msg: lc.latest_msg,
        latest_msg_send_time: lc.latest_msg_send_time,
        draft_text: lc.draft_text,
        draft_text_time: lc.draft_text_time,
        is_pinned: lc.is_pinned != 0,
        is_private_chat: lc.is_private_chat != 0,
        is_not_in_group: lc.is_not_in_group != 0,
        update_flag: 0,
        sync_action: None,
        update_unread_count_time: lc.update_unread_count_time,
        max_seq: lc.max_seq,
        min_seq: lc.min_seq,
        is_msg_destruct: lc.is_msg_destruct != 0,
        msg_destruct_time: lc.msg_destruct_time,
        is_private: lc.is_private_chat != 0,
        burn_duration: lc.burn_duration,
        ex: lc.ex,
    }
}

/// 领域模型 -> 持久化模型
pub fn domain_to_local(conv: Conversation) -> LocalConversation {
    LocalConversation {
        conversation_id: conv.conversation_id,
        conversation_type: conv.conversation_type,
        user_id: conv.user_id,
        group_id: conv.group_id,
        show_name: conv.show_name,
        face_url: conv.face_url,
        latest_msg: conv.latest_msg,
        latest_msg_send_time: conv.latest_msg_send_time,
        unread_count: conv.unread_count,
        recv_msg_opt: conv.recv_msg_opt,
        is_pinned: if conv.is_pinned { 1 } else { 0 },
        is_private_chat: if conv.is_private_chat { 1 } else { 0 },
        burn_duration: 0,
        group_at_type: conv.group_at_type,
        is_not_in_group: if conv.is_not_in_group { 1 } else { 0 },
        update_unread_count_time: 0,
        attached_info: String::new(),
        ex: String::new(),
        draft_text: conv.draft_text,
        draft_text_time: conv.draft_text_time,
        max_seq: conv.latest_msg_seq,
        min_seq: 0,
        is_msg_destruct: 0,
        msg_destruct_time: 0,
    }
}
