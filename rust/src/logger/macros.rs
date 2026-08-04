//! SDK 专用日志宏
//!
//! 对 tracing 宏的薄封装，统一入口。
//! 所有宏自动继承当前 span 的 OTel trace_id / span_id。
//!
//! 用法：
//! ```ignore
//! sdk_info!("收到推送消息"; "conv_id" => &conv_id, "msg_count" => n);
//! sdk_debug!("开始同步好友");
//! sdk_warn!("同步失败"; "error" => %e);
//! sdk_error!("连接断开"; "error" => %e);
//! ```

/// SDK INFO 级别日志，自动带 trace_id
#[macro_export]
macro_rules! sdk_info {
    ($($arg:tt)*) => {
        $crate::tracing::info!($($arg)*)
    };
}

/// SDK DEBUG 级别日志
#[macro_export]
macro_rules! sdk_debug {
    ($($arg:tt)*) => {
        $crate::tracing::debug!($($arg)*)
    };
}

/// SDK WARN 级别日志
#[macro_export]
macro_rules! sdk_warn {
    ($($arg:tt)*) => {
        $crate::tracing::warn!($($arg)*)
    };
}

/// SDK ERROR 级别日志
#[macro_export]
macro_rules! sdk_error {
    ($($arg:tt)*) => {
        $crate::tracing::error!($($arg)*)
    };
}

/// 创建带 operation_id 的 span（自动填充 trace_id 字段）
#[macro_export]
macro_rules! sdk_span {
    ($name:expr, operation_id = $op_id:expr) => {
        $crate::tracing::info_span!($name, operation_id = $op_id)
    };
    ($name:expr, operation_id = $op_id:expr, $($field:tt)*) => {
        $crate::tracing::info_span!($name, operation_id = $op_id, $($field)*)
    };
    ($name:expr) => {
        $crate::tracing::info_span!($name)
    };
}
