use uuid::Uuid;

/// 生成操作 ID（时间戳）
pub fn make_operation_id() -> String {
    format!("{}", chrono::Utc::now().timestamp_millis())
}

/// 生成消息递增 ID（UUID）
pub fn make_msg_incr() -> String {
    Uuid::new_v4().to_string()
}
