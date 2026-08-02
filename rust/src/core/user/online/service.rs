use crate::domain::error::{Result, SdkError};
use crate::event::events::user::{UserEvent, UserListener, UserListenerExt};
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{GET_USER_STATUS, SUBSCRIBE_USERS_STATUS, UNSUBSCRIBE_USERS_STATUS, GET_SUBSCRIBE_USERS_STATUS};
use crate::domain::ports::online::*;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::info;









pub mod status {
    pub const OFFLINE: i32 = 0;
    pub const ONLINE: i32 = 1;
}

pub struct OnlineStatusService {
    http_client: Arc<HttpApiClient>,
    listener: Arc<dyn UserListener>,
    subscribed_users: Arc<RwLock<HashSet<String>>>,
    status_cache: Arc<RwLock<Vec<OnlineStatus>>>,
}

impl OnlineStatusService {
    pub fn new(http_client: Arc<HttpApiClient>, listener: Arc<dyn UserListener>) -> Self {
        Self {
            http_client,
            listener,
            subscribed_users: Arc::new(RwLock::new(HashSet::new())),
            status_cache: Arc::new(RwLock::new(Vec::new())),
        }
    }

    pub async fn get_user_status(&self, user_ids: Vec<String>) -> Result<Vec<OnlineStatus>> {
        if user_ids.is_empty() {
            return Ok(vec![]);
        }

        let req = GetUserStatusReq {
            user_ids: user_ids.clone(),
        };

        let resp: GetUserStatusResp = self.http_client.post(GET_USER_STATUS, &req).await?;

        let statuses: Vec<OnlineStatus> = resp
            .users_status
            .into_iter()
            .map(|s| OnlineStatus {
                user_id: s.user_id,
                status: s.status,
                platform_ids: s.platform_ids,
            })
            .collect();

        Ok(statuses)
    }

    pub async fn subscribe_users_status(&self, user_ids: Vec<String>) -> Result<Vec<OnlineStatus>> {
        if user_ids.is_empty() {
            return Ok(vec![]);
        }

        let req = SubscribeUsersStatusReq {
            user_ids: user_ids.clone(),
        };

        let resp: SubscribeUsersStatusResp = self.http_client.post(SUBSCRIBE_USERS_STATUS, &req).await?;

        let statuses: Vec<OnlineStatus> = resp
            .users_status
            .into_iter()
            .map(|s| OnlineStatus {
                user_id: s.user_id,
                status: s.status,
                platform_ids: s.platform_ids,
            })
            .collect();

        {
            let mut subscribed = self.subscribed_users.write().await;
            for user_id in &user_ids {
                subscribed.insert(user_id.clone());
            }
        }

        self.update_cache(&statuses).await;

        for status in &statuses {
            self.listener.emit(UserEvent::UserStatusChanged {
                user_id: status.user_id.clone(),
                status: status.status,
                platform_ids: status.platform_ids.clone(),
            });
        }

        info!("已订阅用户在线状态, count={}", user_ids.len());
        Ok(statuses)
    }

    pub async fn unsubscribe_users_status(&self, user_ids: Vec<String>) -> Result<()> {
        if user_ids.is_empty() {
            return Ok(());
        }

        let req = UnsubscribeUsersStatusReq {
            user_ids: user_ids.clone(),
        };

        let _resp: serde_json::Value = self.http_client.post(UNSUBSCRIBE_USERS_STATUS, &req).await?;

        {
            let mut subscribed = self.subscribed_users.write().await;
            for user_id in &user_ids {
                subscribed.remove(user_id);
            }
        }

        self.remove_from_cache(&user_ids).await;

        info!("已取消订阅用户在线状态, count={}", user_ids.len());
        Ok(())
    }

    pub async fn get_subscribe_users_status(&self) -> Result<Vec<OnlineStatus>> {
        let resp: GetSubscribeUsersStatusResp = self.http_client.post(GET_SUBSCRIBE_USERS_STATUS, &()).await?;

        let statuses: Vec<OnlineStatus> = resp
            .users_status
            .into_iter()
            .map(|s| OnlineStatus {
                user_id: s.user_id,
                status: s.status,
                platform_ids: s.platform_ids,
            })
            .collect();

        self.update_cache(&statuses).await;

        Ok(statuses)
    }

    pub async fn get_subscribed_count(&self) -> usize {
        self.subscribed_users.read().await.len()
    }

    pub async fn is_subscribed(&self, user_id: &str) -> bool {
        self.subscribed_users.read().await.contains(user_id)
    }

    pub async fn clear_subscriptions(&self) -> Result<()> {
        let user_ids: Vec<String> = {
            let subscribed = self.subscribed_users.read().await;
            subscribed.iter().cloned().collect()
        };

        if !user_ids.is_empty() {
            self.unsubscribe_users_status(user_ids).await?;
        }

        self.status_cache.write().await.clear();
        Ok(())
    }

    async fn update_cache(&self, statuses: &[OnlineStatus]) {
        let mut cache = self.status_cache.write().await;
        for status in statuses {
            if let Some(existing) = cache.iter_mut().find(|s| s.user_id == status.user_id) {
                *existing = status.clone();
            } else {
                cache.push(status.clone());
            }
        }
    }

    async fn remove_from_cache(&self, user_ids: &[String]) {
        let mut cache = self.status_cache.write().await;
        cache.retain(|s| !user_ids.contains(&s.user_id));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_user_status_req_serialization() {
        let req = GetUserStatusReq {
            user_ids: vec!["user_1".to_string(), "user_2".to_string()],
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("userIDs"));
        assert!(json.contains("user_1"));
    }

    #[test]
    fn test_subscribe_users_status_req_serialization() {
        let req = SubscribeUsersStatusReq {
            user_ids: vec!["user_3".to_string()],
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("userIDs"));
    }

    #[test]
    fn test_user_status_item_deserialization() {
        let json = r#"{"userID":"user_1","status":1,"platformIDs":[1,2]}"#;
        let item: UserStatusItem = serde_json::from_str(json).unwrap();

        assert_eq!(item.user_id, "user_1");
        assert_eq!(item.status, 1);
        assert_eq!(item.platform_ids, vec![1, 2]);
    }

    #[test]
    fn test_online_status_constants() {
        assert_eq!(status::OFFLINE, 0);
        assert_eq!(status::ONLINE, 1);
    }
}


