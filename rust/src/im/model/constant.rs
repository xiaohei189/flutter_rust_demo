/// WebSocket 请求和推送标识常量定义
pub const GET_NEWEST_SEQ: i32 = 1001;
pub const PULL_MSG_BY_RANGE: i32 = 1002;
pub const PULL_MSG_BY_SEQ_LIST: i32 = 1005;
pub const SEND_MSG: i32 = 1003;
pub const PUSH_MSG: i32 = 2001;
pub const KICK_ONLINE_MSG: i32 = 2002;
pub const LOGOUT_MSG: i32 = 2003;
pub const SEND_MSG_NOT_OSS: i32 = 3001;

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
