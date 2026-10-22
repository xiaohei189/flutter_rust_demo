//! 会话模型转换器 - ServerConversation -> LocalConversation（对齐 Go SDK `ServerConversationToLocal`）

use crate::domain::model::local::{LocalChatLog, LocalConversation};
use crate::domain::model::msg_struct::MsgStruct;

use crate::infra::http::conversation::ServerConversation;

/// 会话列表 `latest_msg` 的标准内容：**完整消息信封 JSON**（camelCase，对齐 Go SDK
/// `Conversation.latestMsg`）。
///
/// 为什么不能只存裸 content：客户端预览靠信封里的 `contentType` 分类（103 → `[语音]`、
/// 102 → `[图片]`），并在信封的 `content` 字段里取文本。历史实现存的是裸 content，
/// 文本消息恰好也有 `content` 字段所以看起来正常，媒体消息则一律退化成「暂无消息」。
pub(crate) fn latest_msg_envelope(log: &LocalChatLog) -> String {
    serde_json::to_string(&MsgStruct::from(log)).unwrap_or_else(|_| log.content.clone())
}

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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::model::msg_struct::MsgStruct;

    /// 会话预览必须带 `contentType`：客户端靠它渲染「[语音]」「[图片]」。
    #[test]
    fn latest_msg_envelope_carries_content_type_for_media() {
        let mut msg = MsgStruct::default();
        msg.client_msg_id = "c1".to_string();
        msg.send_id = "u1".to_string();
        msg.recv_id = "u2".to_string();
        msg.session_type = 1;
        msg.content_type = 103;
        msg.sender_nickname = "张三".to_string();
        msg.content = r#"{"soundPath":"/tmp/a.aac","duration":3,"dataSize":1024}"#.to_string();

        let log = LocalChatLog::from(&msg);
        let envelope: serde_json::Value = serde_json::from_str(&latest_msg_envelope(&log)).unwrap();

        assert_eq!(envelope["contentType"], 103);
        assert_eq!(envelope["senderNickname"], "张三");
        assert!(envelope["content"].as_str().unwrap().contains("a.aac"));
    }
}
