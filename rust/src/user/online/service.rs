use crate::connection::manager::ConnectionManager;
use crate::constant::ws_push_identifier::WS_SUB_USER_ONLINE_STATUS;
use crate::error::{Result, SdkError};
use crate::event::events::user::{UserEvent, UserListener, UserListenerExt};
use crate::http::OnlineStatusServerApi;

use crate::http::online::*;
use crate::model::UserId;
use openim_protocol::sdkws::{SubUserOnlineStatus, SubUserOnlineStatusTips};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn};

pub mod status {
    pub const OFFLINE: i32 = 0;
    pub const ONLINE: i32 = 1;
    pub const SUBSCRIBE: i32 = 1;
    pub const UNSUBSCRIBE: i32 = 2;
}

pub struct OnlineStatusService {
    api: Arc<dyn OnlineStatusServerApi>,
    connection: Arc<ConnectionManager>,
    user_id: UserId,
    listener: Arc<dyn UserListener>,
    subscribed_users: Arc<RwLock<HashSet<String>>>,
    status_cache: Arc<RwLock<Vec<OnlineStatus>>>,
}

impl OnlineStatusService {
    pub fn new(api: Arc<dyn OnlineStatusServerApi>, connection: Arc<ConnectionManager>, user_id: UserId, listener: Arc<dyn UserListener>) -> Self {
        Self {
            api,
            connection,
            user_id,
            listener,
            subscribed_users: Arc::new(RwLock::new(HashSet::new())),
            status_cache: Arc::new(RwLock::new(Vec::new())),
        }
    }

    pub async fn get_user_status(&self, user_ids: Vec<String>) -> Result<Vec<OnlineStatus>> {
        if user_ids.is_empty() {
            return Ok(vec![]);
        }

        let req = GetUserStatusReq { user_ids: user_ids.clone() };

        let resp = self.api.get_user_status(&req).await?;

        let statuses: Vec<OnlineStatus> = resp
            .users_status
            .unwrap_or_default()
            .into_iter()
            .map(|s| OnlineStatus {
                user_id: s.user_id,
                status: s.status,
                platform_ids: s.platform_ids,
            })
            .collect();

        Ok(statuses)
    }

    /// 订阅用户在线状态。
    ///
    /// 主通道为 WS 消息 2005（返回初始状态快照），与 Go SDK 行为一致；
    /// 服务端 HTTP 接口 `/user/subscribe_users_status` 在新版为 stub 空实现，仅作 fallback。
    pub async fn subscribe_users_status(&self, user_ids: Vec<String>) -> Result<Vec<OnlineStatus>> {
        if user_ids.is_empty() {
            return Ok(vec![]);
        }

        let statuses = match self.ws_subscribe(&user_ids).await {
            Ok(statuses) => statuses,
            Err(e) => {
                warn!("[OnlineStatus] WS 订阅失败, fallback HTTP: {}", e);
                self.http_subscribe(&user_ids).await?
            }
        };

        {
            let mut subscribed = self.subscribed_users.write().await;
            for user_id in &user_ids {
                subscribed.insert(user_id.clone());
            }
        }

        self.apply_statuses(&statuses).await;

        info!("已订阅用户在线状态, count={}", user_ids.len());
        Ok(statuses)
    }

    pub async fn unsubscribe_users_status(&self, user_ids: Vec<String>) -> Result<()> {
        if user_ids.is_empty() {
            return Ok(());
        }

        if let Err(e) = self.ws_unsubscribe(&user_ids).await {
            warn!("[OnlineStatus] WS 退订失败, fallback HTTP: {}", e);
            let req = UnsubscribeUsersStatusReq {
                user_id: self.user_id.get().await,
                user_ids: user_ids.clone(),
                genre: status::UNSUBSCRIBE,
            };
            self.api.unsubscribe_users_status(&req).await?;
        }

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

    /// 连接恢复后重新订阅（WS 订阅关系随连接销毁，重连后需恢复）。
    pub async fn resubscribe_all(&self) {
        let user_ids: Vec<String> = {
            let subscribed = self.subscribed_users.read().await;
            subscribed.iter().cloned().collect()
        };
        if user_ids.is_empty() {
            return;
        }
        info!("[OnlineStatus] 连接恢复, 重新订阅用户在线状态, count={}", user_ids.len());
        match self.ws_subscribe(&user_ids).await {
            Ok(statuses) => self.apply_statuses(&statuses).await,
            Err(e) => warn!("[OnlineStatus] 重连重订阅失败: {}", e),
        }
    }

    /// 通过 WS 消息 2005 订阅，响应即初始状态快照。
    async fn ws_subscribe(&self, user_ids: &[String]) -> Result<Vec<OnlineStatus>> {
        let req = SubUserOnlineStatus {
            subscribe_user_id: user_ids.to_vec(),
            unsubscribe_user_id: vec![],
        };
        let tips = self
            .connection
            .send_rpc::<SubUserOnlineStatus, SubUserOnlineStatusTips>(WS_SUB_USER_ONLINE_STATUS, &req)
            .await?;
        Ok(tips
            .subscribers
            .into_iter()
            .map(|e| OnlineStatus {
                user_id: e.user_id,
                status: if e.online_platform_i_ds.is_empty() { status::OFFLINE } else { status::ONLINE },
                platform_ids: e.online_platform_i_ds,
            })
            .collect())
    }

    /// 通过 WS 消息 2005 退订。
    async fn ws_unsubscribe(&self, user_ids: &[String]) -> Result<()> {
        let req = SubUserOnlineStatus {
            subscribe_user_id: vec![],
            unsubscribe_user_id: user_ids.to_vec(),
        };
        let _tips = self
            .connection
            .send_rpc::<SubUserOnlineStatus, SubUserOnlineStatusTips>(WS_SUB_USER_ONLINE_STATUS, &req)
            .await?;
        Ok(())
    }

    /// HTTP 订阅（旧服务端兼容路径）。
    async fn http_subscribe(&self, user_ids: &[String]) -> Result<Vec<OnlineStatus>> {
        let req = SubscribeUsersStatusReq {
            user_id: self.user_id.get().await,
            user_ids: user_ids.to_vec(),
            genre: status::SUBSCRIBE,
        };

        let resp = self.api.subscribe_users_status(&req).await?;

        Ok(resp
            .users_status
            .unwrap_or_default()
            .into_iter()
            .map(|s| OnlineStatus {
                user_id: s.user_id,
                status: s.status,
                platform_ids: s.platform_ids,
            })
            .collect())
    }

    /// 写入缓存并广播状态变更事件。
    async fn apply_statuses(&self, statuses: &[OnlineStatus]) {
        self.update_cache(statuses).await;
        for status in statuses {
            self.listener.emit(UserEvent::UserStatusChanged {
                user_id: status.user_id.clone(),
                status: status.status,
                platform_ids: status.platform_ids.clone(),
            });
        }
    }

    pub async fn get_subscribe_users_status(&self) -> Result<Vec<OnlineStatus>> {
        let req = GetSubscribeUsersStatusReq {
            user_id: self.user_id.get().await,
        };
        let resp = self.api.get_subscribe_users_status(&req).await?;

        let statuses: Vec<OnlineStatus> = resp
            .users_status
            .unwrap_or_default()
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
            user_id: "me".to_string(),
            user_ids: vec!["user_3".to_string()],
            genre: status::SUBSCRIBE,
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("userID"));
        assert!(json.contains("userIDs"));
        assert!(json.contains("\"genre\":1"));
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
