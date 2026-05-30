use serde::{Deserialize, Serialize};

/// 会话模型
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Conversation {
    /// 会话 ID
    pub conversation_id: String,
    /// 会话类型 (1:单聊, 2:群聊, 3:超级群, 4:通知)
    pub conversation_type: i32,
    /// 用户 ID
    pub user_id: String,
    /// 群组 ID
    pub group_id: String,
    /// 显示名称
    pub show_name: String,
    /// 头像 URL
    pub face_url: String,
    /// 接收消息选项 (0:接收, 1:不接收, 2:接收在线消息)
    pub recv_msg_opt: i32,
    /// 未读消息数
    pub unread_count: i32,
    /// 群组最新 seq
    pub group_at_type: i32,
    /// 最新消息 seq
    pub latest_msg_seq: i64,
    /// 最新消息
    pub latest_msg: String,
    /// 最新消息发送时间
    pub latest_msg_send_time: i64,
    /// 草稿
    pub draft_text: String,
    /// 草稿修改时间
    pub draft_text_time: i64,
    /// 是否置顶
    pub is_pinned: bool,
    /// 是否免打扰
    pub is_private_chat: bool,
    /// 群聊是否已销毁
    pub is_not_in_group: bool,
    /// 更新标志
    pub update_flag: i32,
    /// 同步操作 (insert/update/delete)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sync_action: Option<String>,
}
