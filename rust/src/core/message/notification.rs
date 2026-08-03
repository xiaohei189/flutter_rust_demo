//! 通知消息处理器
//!
//! 对齐 Go SDK 的 DoNotification 机制，按 content_type 范围路由通知消息到对应模块。
//! 好友通知 (1200-1299) → friend 模块
//! 用户通知 (1301-1399) → user 模块
//! 群组通知 (1500-1599) → group 模块
//!
//! 重要：服务端 MsgData.content 是 JSON 字节（非 protobuf），
//! 对齐 Go SDK `UnmarshalNotificationElem`：先解析外层 NotificationElem，
//! 再解析内层 detail 到目标类型。

use crate::core::conversation::syncer::ConversationSyncer;
use crate::core::friend::service::FriendService;
use crate::core::group::service::GroupService;
use crate::core::message::MessageProcessor;
use crate::core::user::service::UserService;
use crate::domain::constant::notification_type;
use crate::event::events::friend::{FriendEvent, FriendListener, FriendListenerExt};
use crate::event::events::group::{GroupEvent, GroupListener, GroupListenerExt};
use crate::event::events::user::{UserEvent, UserListener, UserListenerExt};
use crate::domain::model::UserId;
use openim_protocol::sdkws::MsgData;
use serde::Deserialize;
use std::sync::Arc;
use tracing::{debug, info, warn};

// ============================================================
// JSON 兼容类型（对齐 Go SDK proto 的 JSON 序列化格式）
// 服务端将 protobuf 对象转为 JSON 后放入 MsgData.content，
// 字段名为 camelCase（Go proto JSON 默认行为）。
// ============================================================

/// 外层包装（对齐 Go SDK `sdk_struct.NotificationElem`）
#[derive(Deserialize)]
struct NotificationElem {
    #[serde(default)]
    detail: String,
}

/// 两层 JSON 解析辅助函数（对齐 Go SDK `UnmarshalNotificationElem`）
/// 1. 解析外层 `{"detail": "..."}` → 取出 detail 字符串
/// 2. 解析内层 detail JSON → 目标类型 T
fn unmarshal_notification_elem<T: serde::de::DeserializeOwned>(content: &[u8]) -> anyhow::Result<T> {
    let content_str = std::str::from_utf8(content)
        .map_err(|e| anyhow::anyhow!("content 不是有效 UTF-8: {}", e))?;
    let outer: NotificationElem = serde_json::from_str(content_str)
        .map_err(|e| anyhow::anyhow!("解析外层 NotificationElem 失败: {}", e))?;
    let inner: T = serde_json::from_str(&outer.detail)
        .map_err(|e| anyhow::anyhow!("解析内层 detail 失败: {}", e))?;
    Ok(inner)
}

// --- 撤回通知 (2101) ---

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct RevokeMsgTipsJson {
    #[serde(rename = "revokerUserID")]
    revoker_user_id: String,
    #[serde(rename = "clientMsgID")]
    client_msg_id: String,
    revoke_time: i64,
    #[serde(rename = "sesstionType")]
    sesstion_type: i32,
    seq: i64,
    #[serde(rename = "conversationID")]
    conversation_id: String,
    #[serde(rename = "isAdminRevoke")]
    is_admin_revoke: bool,
    #[serde(rename = "revokerNickname", default)]
    revoker_nickname: String,
    #[serde(rename = "revokerRole", default)]
    revoker_role: i32,
}

// --- 好友申请通知 ---

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct FriendRequestJson {
    #[serde(default, rename = "fromUserID")]
    from_user_id: String,
    #[serde(default, rename = "toUserID")]
    to_user_id: String,
    #[serde(default)]
    from_nickname: String,
    #[serde(default, rename = "fromFaceURL")]
    from_face_url: String,
    #[serde(default)]
    to_nickname: String,
    #[serde(default, rename = "toFaceURL")]
    to_face_url: String,
    #[serde(default)]
    handle_result: i32,
    #[serde(default)]
    req_msg: String,
    #[serde(default)]
    create_time: i64,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct FriendApplicationApprovedTipsJson {
    #[serde(default)]
    handle_msg: String,
    #[serde(default)]
    request: FriendRequestJson,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct FriendApplicationRejectedTipsJson {
    #[serde(default)]
    handle_msg: String,
    #[serde(default)]
    request: FriendRequestJson,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct FriendApplicationTipsJson {
    #[serde(default)]
    request: FriendRequestJson,
}

// --- 用户信息更新通知 ---

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct UserInfoJson {
    #[serde(default, rename = "userID")]
    user_id: String,
    #[serde(default)]
    nickname: String,
    #[serde(default)]
    face_url: String,
    #[serde(default)]
    ex: String,
    #[serde(default)]
    global_recv_msg_opt: i32,
}

// --- 群组申请通知 ---

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct GroupInfoJson {
    #[serde(default, rename = "groupID")]
    group_id: String,
}

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct PublicUserInfoJson {
    #[serde(default, rename = "userID")]
    user_id: String,
    #[serde(default)]
    nickname: String,
    #[serde(default)]
    face_url: String,
}

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct GroupRequestJson {
    #[serde(default)]
    group_info: GroupInfoJson,
    #[serde(default)]
    user_info: PublicUserInfoJson,
    #[serde(default)]
    handle_result: i32,
    #[serde(default)]
    req_msg: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct JoinGroupApplicationTipsJson {
    #[serde(default)]
    request: GroupRequestJson,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct GroupApplicationAcceptedTipsJson {
    #[serde(default)]
    handle_msg: String,
    #[serde(default)]
    request: GroupRequestJson,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct GroupApplicationRejectedTipsJson {
    #[serde(default)]
    handle_msg: String,
    #[serde(default)]
    request: GroupRequestJson,
}

// ============================================================
// NotificationHandler
// ============================================================

pub struct NotificationHandler {
    friend_manager: Arc<FriendService>,
    group_manager: Arc<GroupService>,
    user_manager: Arc<UserService>,
    conversation_syncer: Arc<ConversationSyncer>,
    message_processor: Arc<MessageProcessor>,
    friend_listener: Arc<dyn FriendListener>,
    group_listener: Arc<dyn GroupListener>,
    user_listener: Arc<dyn UserListener>,
    user_id: UserId,
}

impl NotificationHandler {
    pub fn new(
        friend_manager: Arc<FriendService>,
        group_manager: Arc<GroupService>,
        user_manager: Arc<UserService>,
        conversation_syncer: Arc<ConversationSyncer>,
        message_processor: Arc<MessageProcessor>,
        friend_listener: Arc<dyn FriendListener>,
        group_listener: Arc<dyn GroupListener>,
        user_listener: Arc<dyn UserListener>,
        user_id: UserId,
    ) -> Self {
        Self {
            friend_manager,
            group_manager,
            user_manager,
            conversation_syncer,
            message_processor,
            friend_listener,
            group_listener,
            user_listener,
            user_id,
        }
    }


    /// 处理通知消息列表（对齐 Go SDK Work() 方法的 CmdNotification 路由）
    pub async fn handle_notifications(&self, msgs: &[MsgData]) {
        for msg in msgs {
            if let Err(e) = self.handle_single_notification(msg).await {
                warn!(
                    "[NOTIFY] 处理失败: content_type={} err={}",
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
                if let Err(e) = self.friend_manager.sync_friends_incremental().await {
                    warn!("[NOTIFY] 增量同步好友列表失败: {}", e);
                }
            }
            notification_type::BLACK_ADDED => {
                if let Err(e) = self.friend_manager.sync_blacks().await {
                    warn!("[NOTIFY] 同步黑名单失败: {}", e);
                }
            }
            notification_type::BLACK_DELETED => {
                if let Err(e) = self.friend_manager.sync_blacks().await {
                    warn!("[NOTIFY] 同步黑名单失败: {}", e);
                }
            }

            // ========== 用户通知 (1301-1399) ==========
            notification_type::USER_INFO_UPDATED => {
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
                if let Err(e) = self.group_manager.sync_groups_incremental().await {
                    warn!("[NOTIFY] 增量同步群组列表失败: {}", e);
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

            // ========== 会话通知 (1300, 1701) ==========
            notification_type::CONVERSATION_CHANGE => {
                if let Err(e) = self.conversation_syncer.sync_incremental_with_lock().await {
                    warn!("[NOTIFY] 增量同步会话列表失败: {}", e);
                }
            }
            notification_type::CONVERSATION_PRIVATE_CHAT => {
                if let Err(e) = self.conversation_syncer.sync_incremental_with_lock().await {
                    warn!("[NOTIFY] 增量同步会话列表失败: {}", e);
                }
            }

            // ========== 消息撤回通知 (2101) ==========
            notification_type::REVOKE => {
                self.handle_revoke_notification(&msg.content).await?;
            }

            // ========== 已读回执通知 (2200) ==========
            notification_type::HAS_READ_RECEIPT => {
                self.message_processor.handle_read_receipt_from_msg_data(msg).await?;
            }

            _ => {
                debug!("[NOTIFY] 未处理: content_type={}", ct);
            }
        }
        Ok(())
    }

    /// 处理消息撤回通知（2101）
    /// 对齐 Go SDK do_revoke_msg: UnmarshalNotificationElem → RevokeMsgTips (JSON)
    async fn handle_revoke_notification(&self, content: &[u8]) -> anyhow::Result<()> {
        // 记录原始通知内容用于调试
        let raw_str = String::from_utf8_lossy(content);
        info!("[REVOKE-DEBUG-RAW] 原始通知内容前200字: {}", &raw_str[..raw_str.len().min(200)]);
        let tips: RevokeMsgTipsJson = unmarshal_notification_elem(content)?;
        info!("[REVOKE-DEBUG-PARSED] 解析结果: revoker_nickname='{}', revoker_role={}, user_id='{}', seq={}, conv='{}'",
            tips.revoker_nickname, tips.revoker_role, tips.revoker_user_id, tips.seq, tips.conversation_id);

        // 委托给 MessageProcessor 处理（构造 protobuf 类型兼容的结构）
        let revoke_tips = openim_protocol::sdkws::RevokeMsgTips {
            revoker_user_id: tips.revoker_user_id,
            client_msg_id: tips.client_msg_id,
            revoke_time: tips.revoke_time,
            sesstion_type: tips.sesstion_type,
            seq: tips.seq,
            conversation_id: tips.conversation_id,
            is_admin_revoke: tips.is_admin_revoke,
        };

        if let Err(e) = self.message_processor.handle_revoke_notification(&revoke_tips, &tips.revoker_nickname, tips.revoker_role).await {
            warn!("[NOTIFY] 处理撤回通知失败: {}", e);
            return Err(anyhow::anyhow!("处理撤回通知失败: {}", e));
        }

        Ok(())
    }

    // ========== 好友通知处理 ==========

    /// 1201 - 好友申请被接受
    async fn handle_friend_application_approved(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips: FriendApplicationApprovedTipsJson = unmarshal_notification_elem(content)?;
        let request = &tips.request;

        let application_json = serde_json::json!({
            "userId": request.from_user_id,
            "nickname": request.from_nickname,
            "faceUrl": request.from_face_url,
            "handleResult": request.handle_result,
            "handleMsg": tips.handle_msg,
            "createTime": request.create_time,
        })
        .to_string();

        if let Err(e) = self.friend_manager.sync_friends_incremental().await {
            warn!("[NOTIFY] 接受好友申请后增量同步好友列表失败: {}", e);
        }

        self.friend_listener
            .emit(FriendEvent::ApplicationAccepted(application_json));

        Ok(())
    }

    /// 1202 - 好友申请被拒绝
    async fn handle_friend_application_rejected(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips: FriendApplicationRejectedTipsJson = unmarshal_notification_elem(content)?;
        let request = &tips.request;

        let application_json = serde_json::json!({
            "userId": request.from_user_id,
            "nickname": request.from_nickname,
            "faceUrl": request.from_face_url,
            "handleResult": request.handle_result,
            "handleMsg": tips.handle_msg,
            "createTime": request.create_time,
        })
        .to_string();

        self.friend_listener
            .emit(FriendEvent::ApplicationRejected(application_json));

        Ok(())
    }

    /// 1203 - 收到好友申请
    async fn handle_friend_application_added(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips: FriendApplicationTipsJson = unmarshal_notification_elem(content)?;
        let request = &tips.request;

        let application_json = serde_json::json!({
            "userId": request.from_user_id,
            "nickname": request.from_nickname,
            "faceUrl": request.from_face_url,
            "handleResult": request.handle_result,
            "reqMsg": request.req_msg,
            "createTime": request.create_time,
        })
        .to_string();

        self.friend_listener
            .emit(FriendEvent::ApplicationAdded(application_json));

        Ok(())
    }

    // ========== 用户通知处理 ==========

    /// 1303 - 用户信息更新
    async fn handle_user_info_updated(&self, content: &[u8]) -> anyhow::Result<()> {
        let user_info: UserInfoJson = unmarshal_notification_elem(content)?;

        self.user_listener.emit(UserEvent::UserInfoUpdated {
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
        let tips: JoinGroupApplicationTipsJson = unmarshal_notification_elem(content)?;
        let request = &tips.request;

        let application_json = serde_json::json!({
            "groupId": request.group_info.group_id,
            "userId": request.user_info.user_id,
            "nickname": request.user_info.nickname,
            "faceUrl": request.user_info.face_url,
            "handleResult": request.handle_result,
            "reason": request.req_msg,
        })
        .to_string();

        self.group_listener
            .emit(GroupEvent::ApplicationAdded(application_json));

        Ok(())
    }

    /// 1505 - 群组申请被接受
    async fn handle_group_application_accepted(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips: GroupApplicationAcceptedTipsJson = unmarshal_notification_elem(content)?;
        let request = &tips.request;

        if let Err(e) = self.group_manager.sync_groups_incremental().await {
            warn!("[NOTIFY] 接受群组申请后增量同步群组列表失败: {}", e);
        }

        let application_json = serde_json::json!({
            "groupId": request.group_info.group_id,
            "userId": request.user_info.user_id,
            "nickname": request.user_info.nickname,
            "faceUrl": request.user_info.face_url,
            "handleResult": request.handle_result,
            "handleMsg": tips.handle_msg,
        })
        .to_string();

        self.group_listener
            .emit(GroupEvent::ApplicationApproved(application_json));

        Ok(())
    }

    /// 1506 - 群组申请被拒绝
    async fn handle_group_application_rejected(&self, content: &[u8]) -> anyhow::Result<()> {
        let tips: GroupApplicationRejectedTipsJson = unmarshal_notification_elem(content)?;
        let request = &tips.request;

        let application_json = serde_json::json!({
            "groupId": request.group_info.group_id,
            "userId": request.user_info.user_id,
            "nickname": request.user_info.nickname,
            "faceUrl": request.user_info.face_url,
            "handleResult": request.handle_result,
            "handleMsg": tips.handle_msg,
        })
        .to_string();

        self.group_listener
            .emit(GroupEvent::ApplicationRejected(application_json));

        Ok(())
    }
}


