use std::time::Duration;
use tracing::info;

/// 重连策略
pub struct ReconnectStrategy {
    /// 当前重试次数
    attempt: u32,
    /// 初始延迟（毫秒）
    initial_delay_ms: u64,
    /// 最大延迟（毫秒）
    max_delay_ms: u64,
    /// 退避因子（指数退避的基数）
    backoff_factor: u64,
    /// 抖动范围（毫秒）
    jitter_ms: u64,
}

impl ReconnectStrategy {
    pub fn new() -> Self {
        Self {
            attempt: 0,
            initial_delay_ms: 1000,
            max_delay_ms: 30000,
            backoff_factor: 2,
            jitter_ms: 500,
        }
    }

    /// 创建自定义重连策略
    pub fn with_params(initial_delay_ms: u64, max_delay_ms: u64, backoff_factor: u64, jitter_ms: u64) -> Self {
        Self {
            attempt: 0,
            initial_delay_ms,
            max_delay_ms,
            backoff_factor,
            jitter_ms,
        }
    }

    /// 获取下次重连的等待时间
    pub fn next_interval(&mut self) -> Duration {
        self.attempt += 1;

        let exponential_delay = self.initial_delay_ms * self.backoff_factor.pow(self.attempt - 1);
        let delay_ms = exponential_delay.min(self.max_delay_ms);

        let jitter = if self.jitter_ms > 0 { rand::random::<u64>() % self.jitter_ms } else { 0 };
        let final_delay = delay_ms + jitter;

        info!("重连策略: 第 {} 次重试，延迟 {:?} (指数退避 + 抖动)", self.attempt, Duration::from_millis(final_delay));

        Duration::from_millis(final_delay)
    }

    /// 重置重连策略（连接成功后调用）
    pub fn reset(&mut self) {
        self.attempt = 0;
        info!("重连策略已重置");
    }

    /// 获取当前重试次数
    pub fn attempt(&self) -> u32 {
        self.attempt
    }
}

impl Default for ReconnectStrategy {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_reconnect_strategy_initial() {
        let strategy = ReconnectStrategy::new();
        assert_eq!(strategy.attempt(), 0);
    }

    #[test]
    fn test_reconnect_strategy_exponential_backoff() {
        let mut strategy = ReconnectStrategy::with_params(1000, 30000, 2, 0);

        let delay1 = strategy.next_interval();
        assert_eq!(delay1, Duration::from_millis(1000));

        let delay2 = strategy.next_interval();
        assert_eq!(delay2, Duration::from_millis(2000));

        let delay3 = strategy.next_interval();
        assert_eq!(delay3, Duration::from_millis(4000));
    }

    #[test]
    fn test_reconnect_strategy_max_delay() {
        let mut strategy = ReconnectStrategy::with_params(1000, 10000, 2, 0);

        strategy.next_interval();
        strategy.next_interval();
        strategy.next_interval();
        strategy.next_interval();
        strategy.next_interval();

        let delay = strategy.next_interval();
        assert!(delay <= Duration::from_millis(10000 + 500));
    }

    #[test]
    fn test_reconnect_strategy_reset() {
        let mut strategy = ReconnectStrategy::new();

        strategy.next_interval();
        strategy.next_interval();
        assert_eq!(strategy.attempt(), 2);

        strategy.reset();
        assert_eq!(strategy.attempt(), 0);
    }
}
