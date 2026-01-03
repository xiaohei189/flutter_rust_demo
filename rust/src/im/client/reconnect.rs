use std::time::Duration;

/// WebSocket 连接致命错误（如 token 失效），用于通知重连逻辑“不要再重连”
#[derive(Debug)]
pub struct ConnectFatalError {
    pub code: i32,
    pub message: String,
}

impl std::fmt::Display for ConnectFatalError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "fatal ws connect error code={}, msg={}",
            self.code, self.message
        )
    }
}

impl std::error::Error for ConnectFatalError {}

/// Go 版重连策略的 Rust 实现：指数退避
#[derive(Debug)]
pub struct ReconnectStrategy {
    attempts: Vec<u64>,
    index: std::sync::Mutex<i32>,
}

impl ReconnectStrategy {
    pub fn new() -> Self {
        Self {
            // 对齐 Go 版的 {1,2,4,8,16} 秒，之后循环
            attempts: vec![1, 2, 4, 8, 16],
            index: std::sync::Mutex::new(-1),
        }
    }

    /// 获取下一次重连前的等待时间
    pub fn next_interval(&self) -> Duration {
        let mut idx = self.index.lock().unwrap();
        *idx += 1;
        let i = (*idx as usize) % self.attempts.len();
        Duration::from_secs(self.attempts[i])
    }

    /// 重置重连计数（在连接成功后调用）
    pub fn reset(&self) {
        let mut idx = self.index.lock().unwrap();
        *idx = -1;
    }
}

