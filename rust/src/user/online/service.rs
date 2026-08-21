use crate::connection::manager::ConnectionManager;
use crate::domain::constant::ws_push_identifier::WS_SUB_USER_ONLINE_STATUS;
use crate::domain::error::Result;
use crate::event::events::user::{UserEvent, UserListener, UserListenerExt};
use crate::infra::http::OnlineStatusServerApi;

use crate::infra::http::online::*;
use crate::domain::model::UserId;
use async_trait::async_trait;
use openim_protocol::sdkws::{SubUserOnlineStatus, SubUserOnlineStatusTips};
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

/// 在线状态 WS 订阅通道，便于在单元测试中注入 fake。
#[async_trait]
pub trait OnlineStatusRpc: Send + Sync {
    async fn subscribe_online_status(&self, req: &SubUserOnlineStatus) -> Result<SubUserOnlineStatusTips>;
}

#[async_trait]
impl OnlineStatusRpc for ConnectionManager {
    async fn subscribe_online_status(&self, req: &SubUserOnlineStatus) -> Result<SubUserOnlineStatusTips> {
        self.send_rpc::<SubUserOnlineStatus, SubUserOnlineStatusTips>(WS_SUB_USER_ONLINE_STATUS, req).await
    }
}

pub struct OnlineStatusService {
    api: Arc<dyn OnlineStatusServerApi>,
    connection: Arc<dyn OnlineStatusRpc>,
    user_id: UserId,
    listener: Arc<dyn UserListener>,
    subscribed_users: Arc<RwLock<HashSet<String>>>,
    status_cache: Arc<RwLock<Vec<OnlineStatus>>>,
}

impl OnlineStatusService {
    pub fn new(api: Arc<dyn OnlineStatusServerApi>, connection: Arc<dyn OnlineStatusRpc>, user_id: UserId, listener: Arc<dyn UserListener>) -> Self {
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
        let tips = self.connection.subscribe_online_status(&req).await?;
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
        let _tips = self.connection.subscribe_online_status(&req).await?;
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
        let req = GetSubscribeUsersStatusReq { user_id: self.user_id.get().await };
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

    #[allow(dead_code)]
    async fn cached_statuses(&self) -> Vec<OnlineStatus> {
        self.status_cache.read().await.clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::error::SdkError;
    use crate::event::events::user::UserListener;
    use openim_protocol::sdkws::SubUserOnlineStatusElem;
    use std::sync::Mutex as StdMutex;

    #[derive(Default)]
    struct FakeOnlineStatusApi {
        subscribe_result: StdMutex<Option<Result<SubscribeUsersStatusResp>>>,
        unsubscribe_result: StdMutex<Option<Result<()>>>,
        subscribe_calls: StdMutex<Vec<SubscribeUsersStatusReq>>,
        unsubscribe_calls: StdMutex<Vec<UnsubscribeUsersStatusReq>>,
    }

    impl FakeOnlineStatusApi {
        fn with_subscribe(statuses: Vec<UserStatusItem>) -> Self {
            Self {
                subscribe_result: StdMutex::new(Some(Ok(SubscribeUsersStatusResp { users_status: Some(statuses) }))),
                ..Default::default()
            }
        }

        fn with_subscribe_error(e: SdkError) -> Self {
            Self {
                subscribe_result: StdMutex::new(Some(Err(e))),
                ..Default::default()
            }
        }
    }

    #[async_trait]
    impl OnlineStatusServerApi for FakeOnlineStatusApi {
        async fn get_user_status(&self, _req: &GetUserStatusReq) -> Result<GetUserStatusResp> {
            Ok(GetUserStatusResp::default())
        }

        async fn subscribe_users_status(&self, req: &SubscribeUsersStatusReq) -> Result<SubscribeUsersStatusResp> {
            self.subscribe_calls.lock().unwrap().push(req.clone());
            self.subscribe_result.lock().unwrap().take().unwrap_or_else(|| Ok(SubscribeUsersStatusResp::default()))
        }

        async fn unsubscribe_users_status(&self, req: &UnsubscribeUsersStatusReq) -> Result<()> {
            self.unsubscribe_calls.lock().unwrap().push(req.clone());
            self.unsubscribe_result.lock().unwrap().take().unwrap_or(Ok(()))
        }

        async fn get_subscribe_users_status(&self, _req: &GetSubscribeUsersStatusReq) -> Result<GetSubscribeUsersStatusResp> {
            Ok(GetSubscribeUsersStatusResp::default())
        }
    }

    struct FakeOnlineStatusRpc {
        result: StdMutex<Option<Result<SubUserOnlineStatusTips>>>,
        requests: StdMutex<Vec<SubUserOnlineStatus>>,
    }

    impl FakeOnlineStatusRpc {
        fn with_tips(tips: SubUserOnlineStatusTips) -> Self {
            Self {
                result: StdMutex::new(Some(Ok(tips))),
                requests: StdMutex::new(Vec::new()),
            }
        }

        fn with_error(e: SdkError) -> Self {
            Self {
                result: StdMutex::new(Some(Err(e))),
                requests: StdMutex::new(Vec::new()),
            }
        }

        fn set_result(&self, result: Result<SubUserOnlineStatusTips>) {
            *self.result.lock().unwrap() = Some(result);
        }
    }

    #[async_trait]
    impl OnlineStatusRpc for FakeOnlineStatusRpc {
        async fn subscribe_online_status(&self, req: &SubUserOnlineStatus) -> Result<SubUserOnlineStatusTips> {
            self.requests.lock().unwrap().push(req.clone());
            self.result.lock().unwrap().take().unwrap_or_else(|| Ok(SubUserOnlineStatusTips::default()))
        }
    }

    #[derive(Default)]
    struct RecordingUserListener {
        events: StdMutex<Vec<(String, i32, Vec<i32>)>>,
    }

    impl UserListener for RecordingUserListener {
        fn on_user_status_changed(&self, user_id: &str, status: i32, platform_ids: &[i32]) {
            self.events.lock().unwrap().push((user_id.to_string(), status, platform_ids.to_vec()));
        }
    }

    fn tips(subscribers: Vec<(String, Vec<i32>)>) -> SubUserOnlineStatusTips {
        SubUserOnlineStatusTips {
            subscribers: subscribers
                .into_iter()
                .map(|(user_id, online_platform_i_ds)| SubUserOnlineStatusElem { user_id, online_platform_i_ds })
                .collect(),
        }
    }

    async fn make_service(rpc: Arc<FakeOnlineStatusRpc>, api: FakeOnlineStatusApi) -> (OnlineStatusService, Arc<RecordingUserListener>) {
        let listener = Arc::new(RecordingUserListener::default());
        let service = OnlineStatusService::new(Arc::new(api), rpc, UserId::new("me"), listener.clone());
        (service, listener)
    }

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

    #[tokio::test]
    async fn test_ws_subscribe_success_updates_cache_and_emits() {
        let rpc = Arc::new(FakeOnlineStatusRpc::with_tips(tips(vec![("u1".to_string(), vec![1, 2]), ("u2".to_string(), vec![])])));
        let (service, listener) = make_service(rpc, FakeOnlineStatusApi::default()).await;

        let statuses = service.subscribe_users_status(vec!["u1".to_string(), "u2".to_string()]).await.unwrap();

        assert_eq!(statuses.len(), 2);
        assert_eq!(statuses[0].user_id, "u1");
        assert_eq!(statuses[0].status, status::ONLINE);
        assert_eq!(statuses[1].user_id, "u2");
        assert_eq!(statuses[1].status, status::OFFLINE);
        assert!(service.is_subscribed("u1").await);
        assert_eq!(service.get_subscribed_count().await, 2);
        assert_eq!(service.cached_statuses().await.len(), 2);
        assert_eq!(listener.events.lock().unwrap().len(), 2);
    }

    #[tokio::test]
    async fn test_ws_subscribe_failure_falls_back_to_http() {
        let rpc = Arc::new(FakeOnlineStatusRpc::with_error(SdkError::network("ws down")));
        let api = FakeOnlineStatusApi::with_subscribe(vec![UserStatusItem {
            user_id: "u1".to_string(),
            status: status::ONLINE,
            platform_ids: vec![1],
        }]);
        let (service, listener) = make_service(rpc, api).await;

        let statuses = service.subscribe_users_status(vec!["u1".to_string()]).await.unwrap();

        assert_eq!(statuses.len(), 1);
        assert_eq!(statuses[0].user_id, "u1");
        assert!(service.is_subscribed("u1").await);
        assert_eq!(service.cached_statuses().await.len(), 1);
        assert_eq!(listener.events.lock().unwrap().len(), 1);
    }

    #[tokio::test]
    async fn test_subscribe_both_paths_fail_keeps_state_clean() {
        let rpc = Arc::new(FakeOnlineStatusRpc::with_error(SdkError::network("ws down")));
        let api = FakeOnlineStatusApi::with_subscribe_error(SdkError::network("http down"));
        let (service, listener) = make_service(rpc, api).await;

        let result = service.subscribe_users_status(vec!["u1".to_string()]).await;

        assert!(result.is_err());
        assert_eq!(service.get_subscribed_count().await, 0);
        assert!(service.cached_statuses().await.is_empty());
        assert!(listener.events.lock().unwrap().is_empty());
    }

    #[tokio::test]
    async fn test_resubscribe_all_noop_when_empty() {
        let rpc = Arc::new(FakeOnlineStatusRpc::with_tips(SubUserOnlineStatusTips::default()));
        let (service, _listener) = make_service(rpc, FakeOnlineStatusApi::default()).await;

        service.resubscribe_all().await;

        assert_eq!(service.get_subscribed_count().await, 0);
    }

    #[tokio::test]
    async fn test_resubscribe_all_applies_new_statuses() {
        let rpc = Arc::new(FakeOnlineStatusRpc::with_tips(tips(vec![("u1".to_string(), vec![1])])));
        let (service, listener) = make_service(rpc.clone(), FakeOnlineStatusApi::default()).await;
        service.subscribe_users_status(vec!["u1".to_string()]).await.unwrap();

        // 重连后服务端返回最新快照：u1 离线，u2 在线
        rpc.set_result(Ok(tips(vec![("u1".to_string(), vec![]), ("u2".to_string(), vec![3])])));

        service.resubscribe_all().await;

        assert_eq!(service.get_subscribed_count().await, 1);
        let cached = service.cached_statuses().await;
        assert_eq!(cached.len(), 2);
        assert!(cached.iter().any(|s| s.user_id == "u1" && s.status == status::OFFLINE));
        assert!(cached.iter().any(|s| s.user_id == "u2" && s.status == status::ONLINE));
        assert_eq!(listener.events.lock().unwrap().len(), 3);
    }

    #[tokio::test]
    async fn test_unsubscribe_removes_subscription_and_cache() {
        let rpc = Arc::new(FakeOnlineStatusRpc::with_tips(tips(vec![("u1".to_string(), vec![1])])));
        let (service, _listener) = make_service(rpc.clone(), FakeOnlineStatusApi::default()).await;
        service.subscribe_users_status(vec!["u1".to_string()]).await.unwrap();

        rpc.set_result(Err(SdkError::network("ws down")));

        service.unsubscribe_users_status(vec!["u1".to_string()]).await.unwrap();

        assert_eq!(service.get_subscribed_count().await, 0);
        assert!(service.cached_statuses().await.is_empty());
    }
}
