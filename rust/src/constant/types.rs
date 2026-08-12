/// WebSocket 请求标识
pub mod ws_req_identifier {
    pub const GET_NEWEST_SEQ: i32 = 1001;
    pub const PULL_MSG_BY_RANGE: i32 = 1002;
    pub const SEND_MSG: i32 = 1003;
    pub const SEND_SIGNAL_MSG: i32 = 1004;
    pub const PULL_MSG_BY_SEQ_LIST: i32 = 1005;
    pub const GET_CONV_MAX_READ_SEQ: i32 = 1006;
    pub const PULL_CONV_LAST_MESSAGE: i32 = 1007;
}

/// WebSocket 推送标识
pub mod ws_push_identifier {
    pub const PUSH_MSG: i32 = 2001;
    pub const KICK_ONLINE_MSG: i32 = 2002;
    pub const LOGOUT_MSG: i32 = 2003;
    pub const SET_BACKGROUND_STATUS: i32 = 2004;
    pub const WS_SUB_USER_ONLINE_STATUS: i32 = 2005;
}

/// 将 req_identifier 数值转换为中文描述（同时覆盖请求/推送两类标识）
pub fn req_identifier_name(id: i32) -> &'static str {
    match id {
        // 请求标识 1001-1007
        ws_req_identifier::GET_NEWEST_SEQ => "获取最新序列号",
        ws_req_identifier::PULL_MSG_BY_RANGE => "按范围拉取消息",
        ws_req_identifier::SEND_MSG => "发送消息",
        ws_req_identifier::SEND_SIGNAL_MSG => "发送信号消息",
        ws_req_identifier::PULL_MSG_BY_SEQ_LIST => "按序列号列表拉取消息",
        ws_req_identifier::GET_CONV_MAX_READ_SEQ => "获取会话最大已读序列",
        ws_req_identifier::PULL_CONV_LAST_MESSAGE => "拉取会话最新消息",
        // 推送标识 2001-2005
        ws_push_identifier::PUSH_MSG => "推送消息",
        ws_push_identifier::KICK_ONLINE_MSG => "踢下线消息",
        ws_push_identifier::LOGOUT_MSG => "登出消息",
        ws_push_identifier::SET_BACKGROUND_STATUS => "设置后台状态",
        ws_push_identifier::WS_SUB_USER_ONLINE_STATUS => "订阅用户在线状态",
        _ => "未知指令",
    }
}

/// 消息内容类型
pub mod content_type {
    pub const TEXT: i32 = 101;
    pub const PICTURE: i32 = 102;
    pub const SOUND: i32 = 103;
    pub const VIDEO: i32 = 104;
    pub const FILE: i32 = 105;
    pub const AT_TEXT: i32 = 106;
    pub const MERGER: i32 = 107;
    pub const CARD: i32 = 108;
    pub const LOCATION: i32 = 109;
    pub const CUSTOM: i32 = 110;
    pub const TYPING: i32 = 113;
    pub const QUOTE: i32 = 114;
    pub const FACE: i32 = 115;
    pub const ADVANCED_TEXT: i32 = 117;
    pub const MARKDOWN_TEXT: i32 = 118;
    pub const CUSTOM_MSG_NOT_TRIGGER_CONVERSATION: i32 = 119;
    pub const CUSTOM_MSG_ONLINE_ONLY: i32 = 120;
    /// Reaction 消息修饰（对齐 Go SDK constant.ReactionMessageModifier）
    pub const REACTION_MESSAGE_MODIFIER: i32 = 121;
    /// Reaction 消息删除（对齐 Go SDK constant.ReactionMessageDeleter）
    pub const REACTION_MESSAGE_DELETER: i32 = 122;

    pub const NOTIFICATION_BEGIN: i32 = 1000;
    pub const NOTIFICATION_END: i32 = 5000;
}

/// 通知消息类型
pub mod notification_type {
    /// 好友通知 (1200-1299)
    pub const FRIEND_NOTIFICATION_BEGIN: i32 = 1200;
    pub const FRIEND_APPLICATION_APPROVED: i32 = 1201;
    pub const FRIEND_APPLICATION_REJECTED: i32 = 1202;
    pub const FRIEND_APPLICATION: i32 = 1203;
    pub const FRIEND_ADDED: i32 = 1204;
    pub const FRIEND_DELETED: i32 = 1205;
    pub const FRIEND_REMARK_SET: i32 = 1206;
    pub const BLACK_ADDED: i32 = 1207;
    pub const BLACK_DELETED: i32 = 1208;
    pub const FRIEND_INFO_UPDATED: i32 = 1209;
    pub const FRIENDS_INFO_UPDATE: i32 = 1210;
    pub const FRIEND_NOTIFICATION_END: i32 = 1299;

    /// 用户通知 (1301-1399)
    pub const USER_NOTIFICATION_BEGIN: i32 = 1301;
    pub const USER_INFO_UPDATED: i32 = 1303;
    pub const USER_STATUS_CHANGE: i32 = 1304;
    pub const USER_COMMAND_ADD: i32 = 1305;
    pub const USER_COMMAND_DELETE: i32 = 1306;
    pub const USER_COMMAND_UPDATE: i32 = 1307;
    pub const USER_NOTIFICATION_END: i32 = 1399;

    /// 群组通知 (1500-1599)
    pub const GROUP_NOTIFICATION_BEGIN: i32 = 1500;
    pub const GROUP_CREATED: i32 = 1501;
    pub const GROUP_INFO_SET: i32 = 1502;
    pub const JOIN_GROUP_APPLICATION: i32 = 1503;
    pub const MEMBER_QUIT: i32 = 1504;
    pub const GROUP_APPLICATION_ACCEPTED: i32 = 1505;
    pub const GROUP_APPLICATION_REJECTED: i32 = 1506;
    pub const GROUP_OWNER_TRANSFERRED: i32 = 1507;
    pub const MEMBER_KICKED: i32 = 1508;
    pub const MEMBER_INVITED: i32 = 1509;
    pub const MEMBER_ENTER: i32 = 1510;
    pub const GROUP_DISMISSED: i32 = 1511;
    pub const GROUP_MEMBER_MUTED: i32 = 1512;
    pub const GROUP_MEMBER_CANCEL_MUTED: i32 = 1513;
    pub const GROUP_MUTED: i32 = 1514;
    pub const GROUP_CANCEL_MUTED: i32 = 1515;
    pub const GROUP_MEMBER_INFO_SET: i32 = 1516;
    pub const GROUP_MEMBER_SET_TO_ADMIN: i32 = 1517;
    pub const GROUP_MEMBER_SET_TO_ORDINARY_USER: i32 = 1518;
    pub const GROUP_INFO_SET_ANNOUNCEMENT: i32 = 1519;
    pub const GROUP_INFO_SET_NAME: i32 = 1520;
    pub const GROUP_NOTIFICATION_END: i32 = 1599;

    /// 会话通知
    pub const CONVERSATION_CHANGE: i32 = 1300;

    /// 其他通知
    pub const CONVERSATION_PRIVATE_CHAT: i32 = 1701;
    pub const CLEAR_CONVERSATION: i32 = 1703;
    pub const BUSINESS_NOTIFICATION: i32 = 2001;
    pub const REVOKE: i32 = 2101;
    pub const DELETE_MSGS: i32 = 2102;
    pub const HAS_READ_RECEIPT: i32 = 2200;
}

/// 消息来源
pub mod msg_from {
    pub const USER_MSG: i32 = 100;
    pub const SYS_MSG: i32 = 200;
}

/// 会话类型
pub mod session_type {
    pub const SINGLE_CHAT: i32 = 1;
    pub const WRITE_GROUP_CHAT: i32 = 2;
    pub const READ_GROUP_CHAT: i32 = 3;
    pub const NOTIFICATION_CHAT: i32 = 4;
}

/// 消息状态
pub mod msg_status {
    pub const SENDING: i32 = 1;
    pub const SEND_SUCCESS: i32 = 2;
    pub const SEND_FAILED: i32 = 3;
    pub const HAS_DELETED: i32 = 4;
    pub const FILTERED: i32 = 5;
}

/// 群组状态
pub mod group_status {
    pub const OK: i32 = 0;
    pub const BAN_CHAT: i32 = 1;
    pub const DISMISSED: i32 = 2;
    pub const MUTED: i32 = 3;
}

/// 群组类型
pub mod group_type {
    pub const NORMAL: i32 = 0;
    pub const SUPER: i32 = 1;
    pub const WORKING: i32 = 2;
}

/// 群组角色
pub mod group_role {
    pub const OWNER: i32 = 100;
    pub const ADMIN: i32 = 60;
    pub const ORDINARY_USER: i32 = 20;
}

/// 好友/黑名单关系
pub mod relationship {
    pub const BLACK: i32 = 0;
    pub const FRIEND: i32 = 1;
}

/// 消息接收选项
pub mod msg_receive_opt {
    pub const RECEIVE_MESSAGE: i32 = 0;
    pub const NOT_RECEIVE_MESSAGE: i32 = 1;
    pub const RECEIVE_NOT_NOTIFY_MESSAGE: i32 = 2;
}

/// 在线状态
pub mod online_status {
    pub const ONLINE: i32 = 1;
    pub const OFFLINE: i32 = 0;
}

/// 群组申请响应
pub mod group_response {
    pub const AGREE: i32 = 1;
    pub const REFUSE: i32 = -1;
}

/// 好友申请响应
pub mod friend_response {
    pub const AGREE: i32 = 1;
    pub const REFUSE: i32 = -1;
    pub const DEFAULT: i32 = 0;
}

/// At 标记
pub mod at_type {
    pub const NORMAL: i32 = 0;
    pub const AT_ME: i32 = 1;
    pub const AT_ALL: i32 = 2;
    pub const AT_ALL_AT_ME: i32 = 3;
}

/// 消息同步状态
pub mod msg_sync_status {
    pub const BEGIN: i32 = 1001;
    pub const PROCESSING: i32 = 1002;
    pub const END: i32 = 1003;
    pub const FAILED: i32 = 1004;
    pub const APP_DATA_SYNC_START: i32 = 1005;
    pub const APP_DATA_SYNC_FINISH: i32 = 1006;
}

/// 拉取消息数量
pub mod pull_msg_num {
    pub const SPLIT_PULL_MSG_NUM: i32 = 100;
    pub const PULL_MSG_NUM_FOR_READ_DIFFUSION: i32 = 50;
    /// 连接成功后单会话单次拉取数量
    pub const CONNECT_PULL_NUMS: i64 = 1;
    /// 唤醒/手动触发时单会话单次拉取数量
    pub const DEFAULT_PULL_NUMS: i64 = 10;
}

/// 会话变更类型
pub mod conversation_change_type {
    pub const ADD_CON_OR_UP_LAT_MSG: i32 = 1;
    pub const TOTAL_UNREAD_MESSAGE_CHANGED: i32 = 2;
    pub const UPDATE_CON_FACE_URL_AND_NICK_NAME: i32 = 3;
    pub const UPDATE_LATEST_MESSAGE_READ_STATE: i32 = 4;
    pub const UPDATE_LATEST_MESSAGE_FACE_URL_AND_NICK_NAME: i32 = 5;
    pub const CON_CHANGE: i32 = 6;
    pub const NEW_CON: i32 = 7;
    pub const CON_CHANGE_DIRECT: i32 = 8;
    pub const NEW_CON_DIRECT: i32 = 9;
    pub const UPDATE_MSG_FACE_URL_AND_NICK_NAME: i32 = 10;
}

/// 已读状态
pub mod read_status {
    pub const HAS_READ: i32 = 1;
    pub const NOT_READ: i32 = 0;
}

/// 大版本号
pub const BIG_VERSION: &str = "v3";

/// 未初始化状态
pub const UNINITIALIZED: i32 = -1001;

/// Options Key
pub mod options_key {
    pub const IS_HISTORY: &str = "history";
    pub const IS_PERSISTENT: &str = "persistent";
    pub const IS_UNREAD_COUNT: &str = "unreadCount";
    pub const IS_CONVERSATION_UPDATE: &str = "conversationUpdate";
    pub const IS_OFFLINE_PUSH: &str = "offlinePush";
    pub const IS_SENDER_SYNC: &str = "senderSync";
    pub const IS_NOT_PRIVATE: &str = "notPrivate";
    pub const IS_SENDER_CONVERSATION_UPDATE: &str = "senderConversationUpdate";
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ws_req_identifier() {
        assert_eq!(ws_req_identifier::GET_NEWEST_SEQ, 1001);
        assert_eq!(ws_req_identifier::PULL_MSG_BY_RANGE, 1002);
        assert_eq!(ws_req_identifier::SEND_MSG, 1003);
        assert_eq!(ws_req_identifier::SEND_SIGNAL_MSG, 1004);
        assert_eq!(ws_req_identifier::PULL_MSG_BY_SEQ_LIST, 1005);
        assert_eq!(ws_req_identifier::GET_CONV_MAX_READ_SEQ, 1006);
        assert_eq!(ws_req_identifier::PULL_CONV_LAST_MESSAGE, 1007);
    }

    #[test]
    fn test_ws_push_identifier() {
        assert_eq!(ws_push_identifier::PUSH_MSG, 2001);
        assert_eq!(ws_push_identifier::KICK_ONLINE_MSG, 2002);
        assert_eq!(ws_push_identifier::LOGOUT_MSG, 2003);
        assert_eq!(ws_push_identifier::SET_BACKGROUND_STATUS, 2004);
        assert_eq!(ws_push_identifier::WS_SUB_USER_ONLINE_STATUS, 2005);
    }

    #[test]
    fn test_content_type() {
        assert_eq!(content_type::TEXT, 101);
        assert_eq!(content_type::PICTURE, 102);
        assert_eq!(content_type::SOUND, 103);
        assert_eq!(content_type::VIDEO, 104);
        assert_eq!(content_type::FILE, 105);
        assert_eq!(content_type::AT_TEXT, 106);
        assert_eq!(content_type::MERGER, 107);
        assert_eq!(content_type::CARD, 108);
        assert_eq!(content_type::LOCATION, 109);
        assert_eq!(content_type::CUSTOM, 110);
        assert_eq!(content_type::REACTION_MESSAGE_MODIFIER, 121);
        assert_eq!(content_type::REACTION_MESSAGE_DELETER, 122);
        assert_eq!(content_type::NOTIFICATION_BEGIN, 1000);
        assert_eq!(content_type::NOTIFICATION_END, 5000);
    }

    #[test]
    fn test_session_type() {
        assert_eq!(session_type::SINGLE_CHAT, 1);
        assert_eq!(session_type::WRITE_GROUP_CHAT, 2);
        assert_eq!(session_type::READ_GROUP_CHAT, 3);
        assert_eq!(session_type::NOTIFICATION_CHAT, 4);
    }

    #[test]
    fn test_group_role() {
        assert_eq!(group_role::OWNER, 100);
        assert_eq!(group_role::ADMIN, 60);
        assert_eq!(group_role::ORDINARY_USER, 20);
    }

    #[test]
    fn test_msg_sync_status() {
        assert_eq!(msg_sync_status::BEGIN, 1001);
        assert_eq!(msg_sync_status::PROCESSING, 1002);
        assert_eq!(msg_sync_status::END, 1003);
        assert_eq!(msg_sync_status::FAILED, 1004);
    }
}

/// SDK 本地安装版本（local_app_sdk_version 锚定行的 version，与 Go SDK 保持一致）
pub const SDK_LOCAL_VERSION: &str = "1.0.0";

/// 同步标志（对齐 Go SDK syncFlag）
pub mod sync_flag {
    /// 未同步
    pub const NO_SYNC: i32 = 0;
    /// 同步开始
    pub const SYNC_START: i32 = 1;
    /// 同步完成
    pub const SYNC_END: i32 = 2;
    /// 重装多阶段同步：好友
    pub const SYNC_STAGE_FRIENDS: i32 = 3;
    /// 重装多阶段同步：群组
    pub const SYNC_STAGE_GROUPS: i32 = 4;
    /// 重装多阶段同步：会话
    pub const SYNC_STAGE_CONVERSATIONS: i32 = 5;
    /// 重装多阶段同步：消息
    pub const SYNC_STAGE_MESSAGES: i32 = 6;
    /// 重装多阶段同步：完成
    pub const SYNC_STAGE_DONE: i32 = 7;
}
