use crate::domain::error::types::Result;
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info};

/// 在线状态
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum OnlineStatus {
    /// 在线
    Online,
    /// 离线
    Offline,
    /// 忙碌
    Busy,
    /// 离开
    Away,
}

/// 用户在线状态信息
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UserOnlineStatus {
    /// 用户 ID
    pub user_id: String,
    /// 在线状态
    pub status: OnlineStatus,
    /// 平台列表 (PC, Mobile, Web 等)
    pub platforms: Vec<String>,
    /// 最后在线时间
    pub last_seen: i64,
}

/// 在线状态管理器
pub struct OnlineStatusManager {
    /// 用户在线状态缓存
    statuses: Arc<RwLock<HashMap<String, UserOnlineStatus>>>,
    /// 事件总线
    event_bus: Arc<EventBus>,
}

impl OnlineStatusManager {
    pub fn new(event_bus: Arc<EventBus>) -> Self {
        Self {
            statuses: Arc::new(RwLock::new(HashMap::new())),
            event_bus,
        }
    }

    /// 更新用户在线状态
    pub async fn update_status(&self, user_id: String, status: OnlineStatus, platforms: Vec<String>) {
        let now = chrono::Utc::now().timestamp_millis();
        
        let user_status = UserOnlineStatus {
            user_id: user_id.clone(),
            status: status.clone(),
            platforms,
            last_seen: now,
        };

        self.statuses.write().await.insert(user_id.clone(), user_status);

        let status_i32 = Self::status_to_i32(&status);
        self.event_bus.publish(SdkEvent::UserStatusChanged {
            user_id: user_id.clone(),
            status: status_i32,
            platform_ids: vec![],
        });

        info!("用户在线状态已更新: user={}, status={:?}", user_id, status);
    }

    /// 将 OnlineStatus 转换为 i32
    fn status_to_i32(status: &OnlineStatus) -> i32 {
        match status {
            OnlineStatus::Online => 1,
            OnlineStatus::Offline => 0,
            OnlineStatus::Busy => 2,
            OnlineStatus::Away => 3,
        }
    }

    /// 获取用户在线状态
    pub async fn get_status(&self, user_id: &str) -> Option<UserOnlineStatus> {
        self.statuses.read().await.get(user_id).cloned()
    }

    /// 检查用户是否在线
    pub async fn is_online(&self, user_id: &str) -> bool {
        if let Some(status) = self.statuses.read().await.get(user_id) {
            status.status == OnlineStatus::Online
        } else {
            false
        }
    }

    /// 批量获取用户在线状态
    pub async fn get_statuses(&self, user_ids: Vec<String>) -> Vec<UserOnlineStatus> {
        let guard = self.statuses.read().await;
        user_ids
            .into_iter()
            .filter_map(|id| guard.get(&id).cloned())
            .collect()
    }

    /// 设置用户为在线
    pub async fn set_online(&self, user_id: String, platform: String) {
        self.update_status(user_id, OnlineStatus::Online, vec![platform]).await;
    }

    /// 设置用户为离线
    pub async fn set_offline(&self, user_id: &str) {
        if let Some(mut status) = self.statuses.write().await.get(user_id).cloned() {
            status.status = OnlineStatus::Offline;
            status.last_seen = chrono::Utc::now().timestamp_millis();
            self.statuses.write().await.insert(user_id.to_string(), status);
            
            self.event_bus.publish(SdkEvent::UserStatusChanged {
                user_id: user_id.to_string(),
                status: 0,
                platform_ids: vec![],
            });
            
            info!("用户已设置为离线: {}", user_id);
        }
    }

    /// 清除所有状态
    pub async fn clear(&self) {
        self.statuses.write().await.clear();
        info!("在线状态已清空");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_online_status_manager_creation() {
        let event_bus = Arc::new(EventBus::new());
        let manager = OnlineStatusManager::new(event_bus);

        assert!(!manager.is_online("user_1").await);
    }

    #[tokio::test]
    async fn test_online_status_manager_update() {
        let event_bus = Arc::new(EventBus::new());
        let manager = OnlineStatusManager::new(event_bus);

        manager.set_online("user_1".to_string(), "PC".to_string()).await;
        assert!(manager.is_online("user_1").await);

        let status = manager.get_status("user_1").await;
        assert!(status.is_some());
        assert_eq!(status.unwrap().status, OnlineStatus::Online);
    }

    #[tokio::test]
    async fn test_online_status_manager_set_offline() {
        let event_bus = Arc::new(EventBus::new());
        let manager = OnlineStatusManager::new(event_bus);

        manager.set_online("user_1".to_string(), "PC".to_string()).await;
        assert!(manager.is_online("user_1").await);

        manager.set_offline("user_1").await;
        assert!(!manager.is_online("user_1").await);
    }

    #[tokio::test]
    async fn test_online_status_manager_batch() {
        let event_bus = Arc::new(EventBus::new());
        let manager = OnlineStatusManager::new(event_bus);

        manager.set_online("user_1".to_string(), "PC".to_string()).await;
        manager.set_online("user_2".to_string(), "Mobile".to_string()).await;

        let statuses = manager.get_statuses(vec!["user_1".to_string(), "user_2".to_string()]).await;
        assert_eq!(statuses.len(), 2);
    }
}
