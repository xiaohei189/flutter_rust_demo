use std::time::Duration;

/// WebSocket 连接致命错误（如 token 失效），用于通知重连逻辑“不要再重连”
#[derive(Debug)]
pub struct ConnectFatalError {
    pub code: i32,
    pub message: String,
}

impl std::fmt::Display for ConnectFatalError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "fatal ws connect error code={}, msg={}", self.code, self.message)
    }
}

impl std::error::Error for ConnectFatalError {}

/// Go 版重连策略的 Rust 实现：指数退避
/// 单实例持有，无并发，无需 Mutex
#[derive(Debug)]
pub struct ReconnectStrategy {
    attempts: Vec<u64>,
    index: i32,
}

impl ReconnectStrategy {
    pub fn new() -> Self {
        Self {
            attempts: vec![1, 2, 4, 8, 16],
            index: -1,
        }
    }

    /// 获取下一次重连前的等待时间
    pub fn next_interval(&mut self) -> Duration {
        self.index += 1;
        let i = (self.index as usize) % self.attempts.len();
        Duration::from_secs(self.attempts[i])
    }

    /// 重置重连计数（在连接成功后调用）
    pub fn reset(&mut self) {
        self.index = -1;
    }
}
