use tokio::time::Duration;
#[derive(Clone, Debug)]
pub struct ClientConfig {
    /// 用户 ID
    pub user_id: String,
    /// 认证 token
    pub token: String,
    /// 平台 ID
    pub platform_id: i32,
    /// WebSocket 服务器 URL
    pub ws_url: String,
    /// 压缩方式，例如 "gzip" 或空字符串表示不压缩
    pub compression: String,
    /// 是否为后台模式
    pub is_background: bool,
    /// 是否需要消息响应
    pub is_msg_resp: bool,
    /// SDK 类型，例如 "js" 或 "go"
    pub sdk_type: String,
    /// HTTP API 基础地址（用于会话同步）
    pub api_base_url: String,
    /// 会话同步使用的本地 SQLite 数据库 URL
    ///
    /// 例如：`sqlite://conversations.db?mode=rwc`
    pub conversation_db_url: String,
    /// 消息响应超时时间
    pub msg_resp_timeout: Duration,
}

impl ClientConfig {
    /// 创建默认配置
    pub fn new(user_id: String, token: String, platform_id: i32) -> Self {
        Self {
            user_id,
            token,
            platform_id,
            ws_url: "ws://localhost:10001".to_string(),
            compression: "gzip".to_string(),
            is_background: false,
            is_msg_resp: true,
            sdk_type: "js".to_string(),
            api_base_url: "http://localhost:10002".to_string(),
            conversation_db_url: "sqlite://conversations.db?mode=rwc".to_string(),
            msg_resp_timeout: Duration::from_secs(10),
        }
    }
}

