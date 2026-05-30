//! 在线状态模块（对齐 Go internal/interaction/online.go）
//!
//! 实现用户在线状态订阅与查询功能。

use crate::im::client::connection_handle::ConnectionHandle;
use crate::im::model::ws::{msg_type, OpenIMReq, OpenIMResp};
use crate::im::util;
use anyhow::Result;
use openim_protocol::sdkws;
use openim_protocol::prost::Message as ProtobufMessage;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info};

/// 在线状态
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OnlineStatus {
    /// 用户ID
    pub user_id: String,
    /// 在线平台ID列表
    pub platform_ids: Vec<i32>,
    /// 在线状态 (1=在线, 0=离线)
    pub status: i32,
}

/// 在线状态常量
pub mod status {
    pub const OFFLINE: i32 = 0;
    pub const ONLINE: i32 = 1;
}

/// 平台ID定义（对齐 Go pkg/constant）
pub mod platform {
    pub const IOS: i32 = 1;
    pub const ANDROID: i32 = 2;
    pub const WINDOWS: i32 = 3;
    pub const MACOS: i32 = 4;
    pub const WEB: i32 = 5;
    pub const LINUX: i32 = 7;
}

/// 在线状态管理器（对齐 Go LongConnMgr 中的 subscription）
pub struct OnlineStatusManager {
    /// 连接句柄（用于发送 WS 请求）
    connection_handle: Arc<RwLock<ConnectionHandle>>,
    /// 已订阅的用户ID集合
    subscribed_users: Arc<RwLock<HashSet<String>>>,
}

impl OnlineStatusManager {
    /// 创建新的在线状态管理器
    pub fn new(connection_handle: Arc<RwLock<ConnectionHandle>>) -> Self {
        Self {
            connection_handle,
            subscribed_users: Arc::new(RwLock::new(HashSet::new())),
        }
    }

    /// 订阅用户在线状态（对齐 Go SubscribeUsersStatus）
    ///
    /// # 参数
    /// * `user_ids` - 要订阅的用户ID列表
    ///
    /// # 返回
    /// 用户在线状态列表
    pub async fn subscribe_users_status(&self, user_ids: Vec<String>) -> Result<Vec<OnlineStatus>> {
        if user_ids.is_empty() {
            return Ok(vec![]);
        }

        info!("[OnlineStatus] 订阅用户在线状态: {:?}", user_ids);

        // 获取用户在线平台
        let platform_ids = self.get_user_online_platform_ids(user_ids.clone()).await?;

        // 构建状态
        let status: Vec<OnlineStatus> = user_ids.iter().map(|user_id| {
            let platforms = platform_ids.get(user_id).cloned().unwrap_or_default();
            let online_status = if platforms.is_empty() {
                status::OFFLINE
            } else {
                status::ONLINE
            };

            debug!(
                "[OnlineStatus] 用户 {} 状态: {}, 平台: {:?}",
                user_id, online_status, platforms
            );

            OnlineStatus {
                user_id: user_id.clone(),
                platform_ids: platforms,
                status: online_status,
            }
        }).collect();

        // 更新订阅列表
        {
            let mut subscribed = self.subscribed_users.write().await;
            for user_id in &user_ids {
                subscribed.insert(user_id.clone());
            }
        }

        info!("[OnlineStatus] 订阅完成，当前已订阅用户数: {}", self.subscribed_users.read().await.len());

        Ok(status)
    }

    /// 取消订阅用户在线状态（对齐 Go UnsubscribeUsersStatus）
    ///
    /// # 参数
    /// * `user_ids` - 要取消订阅的用户ID列表
    pub async fn unsubscribe_users_status(&self, user_ids: Vec<String>) -> Result<()> {
        if user_ids.is_empty() {
            return Ok(());
        }

        info!("[OnlineStatus] 取消订阅用户: {:?}", user_ids);

        // 发送取消订阅 WS 请求
        let req = sdkws::UnsubscribeUserOnlineStatusReq {
            user_ids: user_ids.clone(),
        };

        let conn = self.connection_handle.read().await;
        let _: sdkws::UnsubscribeUserOnlineStatusResp = conn
            .send_ws_req(msg_type::WS_UNSUBSCRIBE_USER_STATUS, &req)
            .await?;

        // 更新订阅列表
        {
            let mut subscribed = self.subscribed_users.write().await;
            for user_id in &user_ids {
                subscribed.remove(user_id);
            }
        }

        info!("[OnlineStatus] 取消订阅完成，当前已订阅用户数: {}", self.subscribed_users.read().await.len());

        Ok(())
    }

    /// 获取已订阅用户的在线状态（对齐 Go GetSubscribeUsersStatus）
    ///
    /// # 返回
    /// 所有已订阅用户的在线状态
    pub async fn get_subscribe_users_status(&self) -> Result<Vec<OnlineStatus>> {
        let user_ids: Vec<String> = {
            let subscribed = self.subscribed_users.read().await;
            subscribed.iter().cloned().collect()
        };

        if user_ids.is_empty() {
            return Ok(vec![]);
        }

        // 复用 subscribe_users_status 逻辑
        self.subscribe_users_status(user_ids).await
    }

    /// 获取用户在线平台ID列表（对齐 Go GetUserOnlinePlatformIDs）
    ///
    /// # 参数
    /// * `user_ids` - 用户ID列表
    ///
    /// # 返回
    /// 用户ID到平台ID列表的映射
    async fn get_user_online_platform_ids(&self, user_ids: Vec<String>) -> Result<HashMap<String, Vec<i32>>> {
        if user_ids.is_empty() {
            return Ok(HashMap::new());
        }

        info!("[OnlineStatus] 获取用户在线平台: {:?}", user_ids);

        // 构建 WS 请求
        let req = sdkws::GetUserOnlinePlatformIDsReq {
            user_ids: user_ids.clone(),
        };

        let conn = self.connection_handle.read().await;
        let resp: sdkws::GetUserOnlinePlatformIDsResp = conn
            .send_ws_req(msg_type::WS_GET_USER_ONLINE_PLATFORM_IDS, &req)
            .await?;

        // 解析响应
        let mut result = HashMap::new();
        for status in resp.user_status_list {
            result.insert(status.user_id, status.platform_ids);
        }

        Ok(result)
    }

    /// 获取已订阅用户数量
    pub async fn get_subscribed_count(&self) -> usize {
        self.subscribed_users.read().await.len()
    }

    /// 检查用户是否已订阅
    pub async fn is_subscribed(&self, user_id: &str) -> bool {
        self.subscribed_users.read().await.contains(user_id)
    }

    /// 清空所有订阅
    pub async fn clear_subscriptions(&self) -> Result<()> {
        let user_ids: Vec<String> = {
            let subscribed = self.subscribed_users.read().await;
            subscribed.iter().cloned().collect()
        };

        if !user_ids.is_empty() {
            self.unsubscribe_users_status(user_ids).await?;
        }

        self.subscribed_users.write().await.clear();
        Ok(())
    }
}

use std::collections::HashMap;
