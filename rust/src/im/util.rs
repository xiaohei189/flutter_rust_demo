use uuid::Uuid;

/// 生成操作 ID（时间戳）
pub fn make_operation_id() -> String {
    format!("{}", chrono::Utc::now().timestamp_millis())
}

/// 生成消息递增 ID（UUID）
pub fn make_msg_incr() -> String {
    Uuid::new_v4().to_string()
}

/// 将 content_type (i32) 转为语义化名称，用于日志与展示（与 openim protobuf MsgData.content_type 对应）
#[inline]
pub fn content_type_name(content_type: i32) -> &'static str {
    use openim_protocol::constant;
    match content_type {
        constant::TEXT => "文本",
        constant::PICTURE => "图片",
        constant::VOICE => "语音",
        constant::VIDEO => "视频",
        constant::FILE => "文件",
        constant::AT_TEXT => "@消息",
        constant::MERGER => "合并转发",
        constant::CARD => "名片",
        constant::LOCATION => "位置",
        constant::CUSTOM => "自定义",
        constant::REVOKE => "撤回",
        constant::TYPING => "输入状态",
        constant::QUOTE => "引用",
        constant::ADVANCED_TEXT => "高级文本",
        constant::MARKDOWN_TEXT => "Markdown",
        constant::CUSTOM_NOT_TRIGGER_CONVERSATION => "自定义(不触发会话)",
        constant::CUSTOM_ONLINE_ONLY => "自定义(仅在线)",
        constant::REACTION_MESSAGE_MODIFIER => "表情回应",
        constant::REACTION_MESSAGE_DELETER => "表情回应删除",
        constant::COMMON => "通用",
        constant::GROUP_MSG => "群消息",
        constant::SIGNAL_MSG => "信令",
        constant::CUSTOM_NOTIFICATION => "自定义通知",
        constant::FRIEND_APPLICATION_APPROVED_NOTIFICATION => "好友通过",
        constant::FRIEND_APPLICATION_REJECTED_NOTIFICATION => "好友拒绝",
        constant::FRIEND_APPLICATION_NOTIFICATION => "好友申请",
        constant::FRIEND_ADDED_NOTIFICATION => "好友添加",
        constant::FRIEND_DELETED_NOTIFICATION => "好友删除",
        constant::FRIEND_REMARK_SET_NOTIFICATION => "好友备注",
        constant::BLACK_ADDED_NOTIFICATION => "加入黑名单",
        constant::BLACK_DELETED_NOTIFICATION => "移除黑名单",
        constant::FRIEND_INFO_UPDATED_NOTIFICATION => "好友资料更新",
        constant::FRIENDS_INFO_UPDATE_NOTIFICATION => "好友列表更新",
        constant::CONVERSATION_CHANGE_NOTIFICATION => "会话变更",
        constant::USER_INFO_UPDATED_NOTIFICATION => "用户资料更新",
        constant::USER_STATUS_CHANGE_NOTIFICATION => "用户状态变更",
        constant::GROUP_CREATED_NOTIFICATION => "群创建",
        constant::GROUP_INFO_SET_NOTIFICATION => "群资料变更",
        constant::JOIN_GROUP_APPLICATION_NOTIFICATION => "加群申请",
        constant::MEMBER_QUIT_NOTIFICATION => "退群",
        constant::GROUP_APPLICATION_ACCEPTED_NOTIFICATION => "加群通过",
        constant::GROUP_APPLICATION_REJECTED_NOTIFICATION => "加群拒绝",
        constant::GROUP_OWNER_TRANSFERRED_NOTIFICATION => "群主转让",
        constant::MEMBER_KICKED_NOTIFICATION => "踢出群",
        constant::MEMBER_INVITED_NOTIFICATION => "邀请入群",
        constant::MEMBER_ENTER_NOTIFICATION => "入群",
        constant::GROUP_DISMISSED_NOTIFICATION => "群解散",
        constant::HAS_READ_RECEIPT => "已读回执",
        _ if content_type >= constant::NOTIFICATION_BEGIN && content_type <= constant::NOTIFICATION_END => "通知",
        _ if content_type >= constant::CONTENT_TYPE_BEGIN && content_type < constant::NOTIFICATION_BEGIN => "消息",
        _ => "未知",
    }
}
