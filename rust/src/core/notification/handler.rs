//! 通知消息处理器
//!
//! 对齐 Go SDK 的 DoNotification 机制，按 content_type 范围路由通知消息到对应模块。
//! 好友通知 (1200-1299) → friend 模块
//! 用户通知 (1301-1399) → user 模块
//! 群组通知 (1500-1599) → group 模块

use crate::core::friend::manager::FriendManager;
use crate::core::group::manager::GroupManager;
use crate::core::user::manager::UserManager;
use crate::domain::constant::types::notification_type;
use crate::domain::event::bus::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::protocol::sdkws::{
    FriendApplicationApprovedTips, FriendApplicationRejectedTips, FriendApplicationTips,
    GroupApplicationAcceptedTips, GroupApplicationRejectedTips, JoinGroupApplicationTips,
    MsgData, UserInfo,
};
use prost::Message as ProstMessage;
use std::sync::Arc;
use tracing::{debug, info, warn};

pub struct NotificationHandler {
    friend_manager: Arc<FriendManager>,
    group_manager: Arc<GroupManager>,
    user_manager: Arc<UserManager>,
    event_bus: Arc<EventBus>,
    user_id: std::sync::Mutex<String>,
}

impl NotificationHandler {
    pub fn new(
        friend_manager: Arc<FriendManager>,
        group_manager: Arc<GroupManager>,
        user_manager: Arc<UserManager>,
        event_bus: Arc<EventBus>,
    ) -> Self {
        Self {
            friend_manager,
            group_manager,
            user_manager,
            event_bus,
            user_id: std::sync::Mutex::new(String::new()),
        }
    }

    pub fn set_user_id(&self, user_id: String) {
        *self.user_id.lock().unwrap() = user_id;
    }

    /// 处理通知消息列表（对齐 Go SDK Work() 方法的 CmdNotification 路由）
    pub async fn handle_notifications(&self, msgs: &[MsgData]) {
        for msg in msgs {
            if let Err(e) = self.handle_single_notification(msg).await {
                warn!(
                    "处理通知消息失败: content_type={}, error={}",
                    msg.content_type, e
                );
            }
        }
    }

    async fn handle_single_notification(&self, msg: &MsgData) -> anyhow::Result<()> {
        let ct = msg.content_type;
        match ct {
            // ========== 好友通知 (1200-1299) ==========
            notification_type::FRIEND_APPLICATION_APPROVED => {
                self.handle_friend_application_approved(&msg.content).await?;
            }
            notification_type::FRIEND_APPLICATION_REJECTED => {
                self.handle_friend_application_rejected(&msg.content).await?;
            }
            notification_type::FRIEND_APPLICATION => {
                self.handle_friend_application_added(&msg.content).await?;
            }
            notification_type::FRIEND_ADDED
            | notification_type::FRIEND_DELETED
            | notification_type::FRIEND_REMARK_SET
            | notification_type::FRIEND_INFO_UPDATED
            | notification_type::FRIENDS_INFO_UPDATE => {
                info!("收到好友列表变更通知: content_type={}, 同步好友列表", ct);
                if let Err(e) = self.friend_manager.sync_friends().await {
                    warn!("同步好友列表失败: {}", e);
                }
            }
            notification_type::BLACK_ADDED => {
                info!("收到黑名单添加通知, 同步黑名单");
                if let Err(e) = self.friend_manager.sync_blacks().await {
                    warn!("同步黑名单失败: {}", e);
                }
            }
            notification_type::BLACK_DELETED => {
                info!("收到黑名单移除通知, 同步黑名单");
                if let Err(e) = self.friend_manager.sync_blacks().await {
                    warn!("同步黑名单失败: {}", e);
                }
            }

            // ========== 用户通知 (1301-1399) ==========
            notification_type::USER_INFO_UPDATED => {
                info!("收到用户信息更新通知");
                self.handle_user_info_updated(&msg.content).await?;
            }

            // ========== 群组通知 (1500-1599) ==========
            notification_type::GROUP_CREATED
            | notification_type::GROUP_INFO_SET
            | notification_type::MEMBER_QUIT
            | notification_type::GROUP_OWNER_TRANSFERRED
            | notification_type::MEMBER_KICKED
            | notification_type::MEMBER_INVITED
            | notification_type::MEMBER_ENTER
            | notification_type::GROUP_DISMISSED
            | notification_type::GROUP_MEMBER_MUTED
            | notification_type::GROUP_MEMBER_CANCEL_MUTED
            | notification_type::GROUP_MUTED
            | notification_type::GROUP_CANCEL_MUTED
            | notification_type::GROUP_MEMBER_INFO_SET
            | notification_type::GROUP_MEMBER_SET_TO_ADMIN
            | notification_type::GROUP_MEMBER_SET_TO_ORDINARY_USER
            | notification_type::GROUP_INFO_SET_ANNOUNCEMENT
            | notification_type::GROUP_INFO_SET_NAME => {
                info!("收到群组变更通知: content_type={}, 同步群组列表", ct);
                if let Err(e) = self.group_manager.sync_groups().await {
                    warn!("同步群组列表失败: {}", e);
                }
            }
            notification_type::JOIN_GROUP_APPLICATION => {
                self.handle_group_application_added(&msg.content).await?;
            }
            notification_type::GROUP_APPLICATION_ACCEPTED => {
                self.handle_group_application_accepted(&msg.content).await?;
            }
            notification_type::GROUP_APPLICATION_REJECTED => {
                self.handle_group_application_rejected(&msg.content).await?;
            }

            _ => {
                debug!("未处理的通知类型: content_type={}", ct);
            }
        }
        Ok(())
    }

    // ========== 好友通知处理 ==========

    /// 1201 - 好友申请被接受
    async fn handle_friend_application_approved(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips = FriendApplicationApprovedTips::decode(content)
            .map_err(|e| anyhow::anyhow!("解析 FriendApplicationApprovedTips 失败: {}", e))?;

        let request = tips.request.unwrap_or_default();
        info!(
            "好友申请已接受: from={}, to={}",
            request.from_user_id, request.to_user_id
        );

        let login_user_id = self.user_id.lock().unwrap().clone();

        // 对齐 Go SDK: 接受后同步好友列表
        if let Err(e) = self.friend_manager.sync_friends().await {
            warn!("接受好友申请后同步好友列表失败: {}", e);
        }

        // 构建 FriendApplyInfo JSON 推送到 Flutter
        let application_json = serde_json::json!({
            "userId": request.from_user_id,
            "nickname": request.from_nickname,
            "faceUrl": request.from_face_url,
            "handleResult": request.handle_result,
            "handleMsg": tips.handle_msg,
            "createTime": request.create_time,
        })
        .to_string();

        self.event_bus
            .publish(SdkEvent::FriendApplicationApproved {
                application: application_json,
            });

        Ok(())
    }

    /// 1202 - 好友申请被拒绝
    async fn handle_friend_application_rejected(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips = FriendApplicationRejectedTips::decode(content)
            .map_err(|e| anyhow::anyhow!("解析 FriendApplicationRejectedTips 失败: {}", e))?;

        let request = tips.request.unwrap_or_default();
        info!(
            "好友申请已拒绝: from={}, to={}",
            request.from_user_id, request.to_user_id
        );

        let application_json = serde_json::json!({
            "userId": request.from_user_id,
            "nickname": request.from_nickname,
            "faceUrl": request.from_face_url,
            "handleResult": request.handle_result,
            "handleMsg": tips.handle_msg,
            "createTime": request.create_time,
        })
        .to_string();

        self.event_bus
            .publish(SdkEvent::FriendApplicationRejected {
                application: application_json,
            });

        Ok(())
    }

    /// 1203 - 收到好友申请
    async fn handle_friend_application_added(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips = FriendApplicationTips::decode(content)
            .map_err(|e| anyhow::anyhow!("解析 FriendApplicationTips 失败: {}", e))?;

        let request = tips.request.unwrap_or_default();
        info!(
            "收到好友申请: from={}, to={}",
            request.from_user_id, request.to_user_id
        );

        let application_json = serde_json::json!({
            "userId": request.from_user_id,
            "nickname": request.from_nickname,
            "faceUrl": request.from_face_url,
            "handleResult": request.handle_result,
            "reqMsg": request.req_msg,
            "createTime": request.create_time,
        })
        .to_string();

        self.event_bus
            .publish(SdkEvent::FriendApplicationAdded {
                application: application_json,
            });

        Ok(())
    }

    // ========== 用户通知处理 ==========

    /// 1303 - 用户信息更新
    async fn handle_user_info_updated(&self, content: &[u8]) -> anyhow::Result<()> {
        let user_info = UserInfo::decode(content)
            .map_err(|e| anyhow::anyhow!("解析 UserInfo 失败: {}", e))?;

        info!("用户信息更新: user_id={}", user_info.user_id);

        // 发布事件通知 Flutter 层刷新用户信息
        // 完整的同步逻辑将在 VersionSynchronizer 实现时补齐
        self.event_bus.publish(SdkEvent::UserInfoUpdated {
            user: crate::domain::model::user::UserInfo {
                user_id: user_info.user_id,
                nickname: user_info.nickname,
                face_url: user_info.face_url,
                gender: 0,
                telephone: String::new(),
                email: String::new(),
                remark: user_info.ex,
                global_recv_msg_opt: user_info.global_recv_msg_opt,
            },
        });

        Ok(())
    }

    // ========== 群组通知处理 ==========

    /// 1503 - 收到群组申请
    async fn handle_group_application_added(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips = JoinGroupApplicationTips::decode(content)
            .map_err(|e| anyhow::anyhow!("解析 JoinGroupApplicationTips 失败: {}", e))?;

        let request = tips.request.unwrap_or_default();
        let user_info = request.user_info.unwrap_or_default();
        info!(
            "收到群组申请: group={}, user={}",
            request
                .group_info
                .as_ref()
                .map(|g| g.group_id.as_str())
                .unwrap_or(""),
            user_info.user_id
        );

        let application_json = serde_json::json!({
            "groupId": request.group_info.as_ref().map(|g| g.group_id.clone()).unwrap_or_default(),
            "userId": user_info.user_id,
            "nickname": user_info.nickname,
            "faceUrl": user_info.face_url,
            "handleResult": request.handle_result,
            "reason": request.req_msg,
        })
        .to_string();

        self.event_bus
            .publish(SdkEvent::GroupApplicationAdded {
                application: application_json,
            });

        Ok(())
    }

    /// 1505 - 群组申请被接受
    async fn handle_group_application_accepted(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips = GroupApplicationAcceptedTips::decode(content)
            .map_err(|e| anyhow::anyhow!("解析 GroupApplicationAcceptedTips 失败: {}", e))?;

        let request = tips.request.unwrap_or_default();
        let user_info = request.user_info.unwrap_or_default();
        info!(
            "群组申请已接受: group={}, user={}",
            request
                .group_info
                .as_ref()
                .map(|g| g.group_id.as_str())
                .unwrap_or(""),
            user_info.user_id
        );

        // 对齐 Go SDK: 接受后同步群组列表
        if let Err(e) = self.group_manager.sync_groups().await {
            warn!("接受群组申请后同步群组列表失败: {}", e);
        }

        let application_json = serde_json::json!({
            "groupId": request.group_info.as_ref().map(|g| g.group_id.clone()).unwrap_or_default(),
            "userId": user_info.user_id,
            "nickname": user_info.nickname,
            "faceUrl": user_info.face_url,
            "handleResult": request.handle_result,
            "handleMsg": tips.handle_msg,
        })
        .to_string();

        self.event_bus
            .publish(SdkEvent::GroupApplicationApproved {
                application: application_json,
            });

        Ok(())
    }

    /// 1506 - 群组申请被拒绝
    async fn handle_group_application_rejected(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips = GroupApplicationRejectedTips::decode(content)
            .map_err(|e| anyhow::anyhow!("解析 GroupApplicationRejectedTips 失败: {}", e))?;

        let request = tips.request.unwrap_or_default();
        let user_info = request.user_info.unwrap_or_default();
        info!(
            "群组申请已拒绝: group={}, user={}",
            request
                .group_info
                .as_ref()
                .map(|g| g.group_id.as_str())
                .unwrap_or(""),
            user_info.user_id
        );

        let application_json = serde_json::json!({
            "groupId": request.group_info.as_ref().map(|g| g.group_id.clone()).unwrap_or_default(),
            "userId": user_info.user_id,
            "nickname": user_info.nickname,
            "faceUrl": user_info.face_url,
            "handleResult": request.handle_result,
            "handleMsg": tips.handle_msg,
        })
        .to_string();

        self.event_bus
            .publish(SdkEvent::GroupApplicationRejected {
                application: application_json,
            });

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::friend::manager::FriendManager;
    use crate::core::group::manager::GroupManager;
    use crate::core::user::manager::UserManager;
    use crate::domain::event::EventBus;
    use crate::infra::http::client::HttpApiClient;

    fn make_handler() -> NotificationHandler {
        let event_bus = Arc::new(EventBus::new());
        let http_client = Arc::new(HttpApiClient::new("http://localhost".to_string(), String::new(), String::new()));
        let friend = Arc::new(FriendManager::new(http_client.clone(), event_bus.clone(), "user1".into()));
        let group = Arc::new(GroupManager::new(http_client.clone(), event_bus.clone(), "user1".into()));
        let user = Arc::new(UserManager::new(http_client.clone(), event_bus.clone()));
        NotificationHandler::new(friend, group, user, event_bus)
    }

    #[test]
    fn test_notification_handler_creation() {
        let handler = make_handler();
        handler.set_user_id("user1".into());
        // 基本创建测试
    }
}
