use crate::domain::constant::ws_req_identifier;
use crate::domain::error::{Result, SdkError};
use crate::protocol::ws::OpenIMResp;
use serde::{Deserialize, Serialize};
use std::time::Duration;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tracing::{debug, warn};

/// 心跳管理器
pub struct HeartbeatManager {
    /// 心跳间隔
    interval: Duration,
    /// 心跳超时时间
    timeout: Duration,
    /// 连续失败次数
    failure_count: u32,
    /// 最大失败次数
    max_failures: u32,
}

impl HeartbeatManager {
    pub fn new(interval: Duration, timeout: Duration, max_failures: u32) -> Self {
        Self {
            interval,
            timeout,
            failure_count: 0,
            max_failures,
        }
    }

    /// 创建默认心跳管理器（30 秒间隔，10 秒超时，最多 3 次失败）
    pub fn default() -> Self {
        Self::new(
            Duration::from_secs(30),
            Duration::from_secs(10),
            3,
        )
    }

    /// 发送心跳
    pub async fn send_heartbeat<F, Fut>(&mut self, send_fn: F) -> Result<()>
    where
        F: FnOnce(WsMessage) -> Fut,
        Fut: std::future::Future<Output = Result<()>>,
    {
        let ping_msg = WsMessage::Ping(vec![]);
        send_fn(ping_msg).await?;
        debug!("心跳已发送");
        Ok(())
    }

    /// 处理心跳响应
    pub fn handle_pong(&mut self) {
        self.failure_count = 0;
        debug!("心跳响应正常");
    }

    /// 记录心跳失败
    pub fn record_failure(&mut self) -> bool {
        self.failure_count += 1;
        warn!("心跳失败，连续失败次数: {}/{}", self.failure_count, self.max_failures);
        self.failure_count >= self.max_failures
    }

    /// 获取心跳间隔
    pub fn interval(&self) -> Duration {
        self.interval
    }

    /// 重置失败计数
    pub fn reset(&mut self) {
        self.failure_count = 0;
    }

    /// 检查是否应该触发重连
    pub fn should_reconnect(&self) -> bool {
        self.failure_count >= self.max_failures
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_heartbeat_manager_default() {
        let manager = HeartbeatManager::default();
        assert_eq!(manager.interval(), Duration::from_secs(30));
        assert!(!manager.should_reconnect());
    }

    #[test]
    fn test_heartbeat_manager_failure_count() {
        let mut manager = HeartbeatManager::new(
            Duration::from_secs(10),
            Duration::from_secs(5),
            3,
        );

        assert!(!manager.should_reconnect());
        
        manager.record_failure();
        assert!(!manager.should_reconnect());
        
        manager.record_failure();
        assert!(!manager.should_reconnect());
        
        manager.record_failure();
        assert!(manager.should_reconnect());
    }

    #[test]
    fn test_heartbeat_manager_reset() {
        let mut manager = HeartbeatManager::new(
            Duration::from_secs(10),
            Duration::from_secs(5),
            3,
        );

        manager.record_failure();
        manager.record_failure();
        assert_eq!(manager.failure_count, 2);

        manager.reset();
        assert_eq!(manager.failure_count, 0);
        assert!(!manager.should_reconnect());
    }

    #[test]
    fn test_heartbeat_manager_handle_pong() {
        let mut manager = HeartbeatManager::new(
            Duration::from_secs(10),
            Duration::from_secs(5),
            3,
        );

        manager.record_failure();
        manager.record_failure();
        assert_eq!(manager.failure_count, 2);

        manager.handle_pong();
        assert_eq!(manager.failure_count, 0);
    }
}
