/// WebSocket 请求和推送标识常量定义
pub const GET_NEWEST_SEQ: i32 = 1001;
pub const PULL_MSG_BY_RANGE: i32 = 1002;
pub const PULL_MSG_BY_SEQ_LIST: i32 = 1005;
pub const SEND_MSG: i32 = 1003;
pub const PUSH_MSG: i32 = 2001;
pub const KICK_ONLINE_MSG: i32 = 2002;
pub const LOGOUT_MSG: i32 = 2003;
pub const SEND_MSG_NOT_OSS: i32 = 3001;

/// 收件选项（对齐 Go pkg/constant RecvMsgOpt）
pub const RECEIVE_MESSAGE: i32 = 0;
pub const NOT_RECEIVE_MESSAGE: i32 = 1;
/// 不接收消息（Go ReceiveNotNotifyMessage = 2）；总未读数只统计 recv_msg_opt < 2 的会话
pub const RECEIVE_NOT_NOTIFY_MESSAGE: i32 = 2;

/// 更新会话动作（对齐 Go pkg/constant UpdateConNode Action）
pub mod update_con_action {
    /// 新增会话或更新最新消息（batchUpdateMessageList 中 seq 回填后更新会话 LatestMsg）
    pub const ADD_CON_OR_UP_LAT_MSG: i32 = 1;
    /// 总未读数变更
    pub const TOTAL_UNREAD_MESSAGE_CHANGED: i32 = 2;
    /// 会话直接变更（有变更的会话列表）
    pub const CON_CHANGE_DIRECT: i32 = 8;
    /// 新会话直接（新会话列表）
    pub const NEW_CON_DIRECT: i32 = 9;
}

/// 同步阶段标记（对齐 Go pkg/constant MsgSync* / AppDataSync*）
pub mod sync_flag {
    /// 消息同步开始
    pub const MSG_SYNC_BEGIN: i32 = 1001;
    /// 消息同步进行中
    pub const MSG_SYNC_PROCESSING: i32 = 1002;
    /// 消息同步结束
    pub const MSG_SYNC_END: i32 = 1003;
    /// 消息同步失败
    pub const MSG_SYNC_FAILED: i32 = 1004;
    /// 应用数据同步开始
    pub const APP_DATA_SYNC_START: i32 = 1005;
    /// 应用数据同步结束
    pub const APP_DATA_SYNC_FINISH: i32 = 1006;
}
