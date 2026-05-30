use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::friend::FriendInfo;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info};

/// 好友管理器
pub struct FriendManager {
    /// 好友列表缓存
    friends: Arc<RwLock<HashMap<String, FriendInfo>>>,
    /// 黑名单列表
    blacks: Arc<RwLock<HashMap<String, String>>>,
    /// 事件总线
    event_bus: Arc<EventBus>,
}

impl FriendManager {
    pub fn new(event_bus: Arc<EventBus>) -> Self {
        Self {
            friends: Arc::new(RwLock::new(HashMap::new())),
            blacks: Arc::new(RwLock::new(HashMap::new())),
            event_bus,
        }
    }

    /// 获取所有好友
    pub async fn get_friend_list(&self) -> Vec<FriendInfo> {
        self.friends.read().await.values().cloned().collect()
    }

    /// 获取单个好友信息
    pub async fn get_friend(&self, user_id: &str) -> Option<FriendInfo> {
        self.friends.read().await.get(user_id).cloned()
    }

    /// 添加好友
    pub async fn add_friend(&self, friend: FriendInfo) {
        let user_id = friend.user_id.clone();
        let friend_json = serde_json::to_value(&friend).unwrap_or_default();
        self.friends.write().await.insert(user_id.clone(), friend);
        
        self.event_bus.publish(SdkEvent::FriendAdded {
            friend: friend_json,
        });
        
        info!("好友已添加");
    }

    /// 批量添加好友
    pub async fn add_friends(&self, friends: Vec<FriendInfo>) {
        let mut guard = self.friends.write().await;
        for friend in friends {
            guard.insert(friend.user_id.clone(), friend);
        }
    }

    /// 删除好友
    pub async fn delete_friend(&self, user_id: &str) -> bool {
        let removed = self.friends.write().await.remove(user_id);
        if removed.is_some() {
            self.event_bus.publish(SdkEvent::FriendDeleted {
                friend_id: user_id.to_string(),
            });
            info!("好友已删除: {}", user_id);
            true
        } else {
            false
        }
    }

    /// 更新好友信息
    pub async fn update_friend(&self, user_id: &str, updates: FriendInfoUpdate) -> Result<()> {
        if let Some(friend) = self.friends.write().await.get_mut(user_id) {
            if let Some(remark) = updates.remark {
                friend.remark = remark;
            }
            if let Some(ex) = updates.ex {
                friend.ex = ex;
            }
            
            self.event_bus.publish(SdkEvent::FriendInfoUpdated {
                user_id: user_id.to_string(),
            });
            
            info!("好友信息已更新: {}", user_id);
            Ok(())
        } else {
            Err(SdkError::unknown(format!("好友不存在: {}", user_id)))
        }
    }

    /// 检查是否为好友
    pub async fn is_friend(&self, user_id: &str) -> bool {
        self.friends.read().await.contains_key(user_id)
    }

    /// 获取好友数量
    pub async fn friend_count(&self) -> usize {
        self.friends.read().await.len()
    }

    /// 添加到黑名单
    pub async fn add_to_blacklist(&self, user_id: String) {
        let black_json = serde_json::json!({"user_id": user_id});
        self.blacks.write().await.insert(user_id.clone(), user_id.clone());
        self.event_bus.publish(SdkEvent::BlackAdded {
            black: black_json,
        });
        info!("已添加到黑名单");
    }

    /// 从黑名单移除
    pub async fn remove_from_blacklist(&self, user_id: &str) -> bool {
        let removed = self.blacks.write().await.remove(user_id);
        if removed.is_some() {
            self.event_bus.publish(SdkEvent::BlackDeleted {
                black_id: user_id.to_string(),
            });
            info!("已从黑名单移除: {}", user_id);
            true
        } else {
            false
        }
    }

    /// 检查是否在黑名单中
    pub async fn is_in_blacklist(&self, user_id: &str) -> bool {
        self.blacks.read().await.contains_key(user_id)
    }

    /// 获取黑名单列表
    pub async fn get_blacklist(&self) -> Vec<String> {
        self.blacks.read().await.keys().cloned().collect()
    }

    /// 清空所有数据
    pub async fn clear(&self) {
        self.friends.write().await.clear();
        self.blacks.write().await.clear();
        info!("好友数据已清空");
    }
}

/// 好友信息更新
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct FriendInfoUpdate {
    pub remark: Option<String>,
    pub ex: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_friend(user_id: &str) -> FriendInfo {
        FriendInfo {
            user_id: user_id.to_string(),
            nickname: format!("Friend {}", user_id),
            face_url: String::new(),
            gender: 0,
            remark: String::new(),
            create_time: 0,
            add_source: String::new(),
            ex: String::new(),
        }
    }

    #[tokio::test]
    async fn test_friend_manager_creation() {
        let event_bus = Arc::new(EventBus::new());
        let manager = FriendManager::new(event_bus);

        assert_eq!(manager.friend_count().await, 0);
    }

    #[tokio::test]
    async fn test_friend_manager_add_and_get() {
        let event_bus = Arc::new(EventBus::new());
        let manager = FriendManager::new(event_bus);

        let friend = create_test_friend("user_1");
        manager.add_friend(friend).await;

        assert_eq!(manager.friend_count().await, 1);
        assert!(manager.is_friend("user_1").await);

        let retrieved = manager.get_friend("user_1").await;
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().user_id, "user_1");
    }

    #[tokio::test]
    async fn test_friend_manager_delete() {
        let event_bus = Arc::new(EventBus::new());
        let manager = FriendManager::new(event_bus);

        let friend = create_test_friend("user_1");
        manager.add_friend(friend).await;
        assert!(manager.is_friend("user_1").await);

        let deleted = manager.delete_friend("user_1").await;
        assert!(deleted);
        assert!(!manager.is_friend("user_1").await);
    }

    #[tokio::test]
    async fn test_friend_manager_blacklist() {
        let event_bus = Arc::new(EventBus::new());
        let manager = FriendManager::new(event_bus);

        manager.add_to_blacklist("user_1".to_string()).await;
        assert!(manager.is_in_blacklist("user_1").await);

        let removed = manager.remove_from_blacklist("user_1").await;
        assert!(removed);
        assert!(!manager.is_in_blacklist("user_1").await);
    }

    #[tokio::test]
    async fn test_friend_manager_update() {
        let event_bus = Arc::new(EventBus::new());
        let manager = FriendManager::new(event_bus);

        let friend = create_test_friend("user_1");
        manager.add_friend(friend).await;

        manager
            .update_friend("user_1", FriendInfoUpdate {
                remark: Some("My Friend".to_string()),
                ..Default::default()
            })
            .await
            .unwrap();

        let retrieved = manager.get_friend("user_1").await.unwrap();
        assert_eq!(retrieved.remark, "My Friend");
    }
}
