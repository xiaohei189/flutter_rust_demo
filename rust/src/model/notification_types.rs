//! 通知消息 JSON 反序列化类型（对齐 Go SDK proto 的 JSON 序列化格式）
//!
//! 服务端将 protobuf 对象转为 JSON 后放入 MsgData.content，
//! 字段名为 camelCase（Go proto JSON 默认行为）。
//! 使用 `unmarshal_notification_elem` 进行两层解析。

use serde::Deserialize;

/// 外层包装（对齐 Go SDK `sdk_struct.NotificationElem`）
#[derive(Deserialize)]
pub(crate) struct NotificationElem {
    #[serde(default)]
    pub(crate) detail: String,
}

/// 两层 JSON 解析辅助函数（对齐 Go SDK `UnmarshalNotificationElem`）
/// 1. 解析外层 `{"detail": "..."}` → 取出 detail 字符串
/// 2. 解析内层 detail JSON → 目标类型 T
pub(crate) fn unmarshal_notification_elem<T: serde::de::DeserializeOwned>(content: &[u8]) -> anyhow::Result<T> {
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
pub(crate) struct RevokeMsgTipsJson {
    #[serde(rename = "revokerUserID")]
    pub(crate) revoker_user_id: String,
    #[serde(rename = "clientMsgID")]
    pub(crate) client_msg_id: String,
    pub(crate) revoke_time: i64,
    #[serde(rename = "sesstionType")]
    pub(crate) sesstion_type: i32,
    pub(crate) seq: i64,
    #[serde(rename = "conversationID")]
    pub(crate) conversation_id: String,
    #[serde(rename = "isAdminRevoke")]
    pub(crate) is_admin_revoke: bool,
    #[serde(rename = "revokerNickname", default)]
    pub(crate) revoker_nickname: String,
    #[serde(rename = "revokerRole", default)]
    pub(crate) revoker_role: i32,
}

// --- 好友申请通知 ---

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub(crate) struct FriendRequestJson {
    #[serde(default, rename = "fromUserID")]
    pub(crate) from_user_id: String,
    #[serde(default, rename = "toUserID")]
    pub(crate) to_user_id: String,
    #[serde(default)]
    pub(crate) from_nickname: String,
    #[serde(default, rename = "fromFaceURL")]
    pub(crate) from_face_url: String,
    #[serde(default)]
    pub(crate) to_nickname: String,
    #[serde(default, rename = "toFaceURL")]
    pub(crate) to_face_url: String,
    #[serde(default)]
    pub(crate) handle_result: i32,
    #[serde(default)]
    pub(crate) req_msg: String,
    #[serde(default)]
    pub(crate) create_time: i64,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct FriendApplicationApprovedTipsJson {
    #[serde(default)]
    pub(crate) handle_msg: String,
    #[serde(default)]
    pub(crate) request: FriendRequestJson,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct FriendApplicationRejectedTipsJson {
    #[serde(default)]
    pub(crate) handle_msg: String,
    #[serde(default)]
    pub(crate) request: FriendRequestJson,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct FriendApplicationTipsJson {
    #[serde(default)]
    pub(crate) request: FriendRequestJson,
}

// --- 用户信息更新通知 ---

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct UserInfoJson {
    #[serde(default, rename = "userID")]
    pub(crate) user_id: String,
    #[serde(default)]
    pub(crate) nickname: String,
    #[serde(default)]
    pub(crate) face_url: String,
    #[serde(default)]
    pub(crate) ex: String,
    #[serde(default)]
    pub(crate) global_recv_msg_opt: i32,
}

// --- 群组申请通知 ---

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub(crate) struct GroupInfoJson {
    #[serde(default, rename = "groupID")]
    pub(crate) group_id: String,
}

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub(crate) struct PublicUserInfoJson {
    #[serde(default, rename = "userID")]
    pub(crate) user_id: String,
    #[serde(default)]
    pub(crate) nickname: String,
    #[serde(default)]
    pub(crate) face_url: String,
}

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub(crate) struct GroupRequestJson {
    #[serde(default)]
    pub(crate) group_info: GroupInfoJson,
    #[serde(default)]
    pub(crate) user_info: PublicUserInfoJson,
    #[serde(default)]
    pub(crate) handle_result: i32,
    #[serde(default)]
    pub(crate) req_msg: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct JoinGroupApplicationTipsJson {
    #[serde(default)]
    pub(crate) request: GroupRequestJson,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct GroupApplicationAcceptedTipsJson {
    #[serde(default)]
    pub(crate) handle_msg: String,
    #[serde(default)]
    pub(crate) request: GroupRequestJson,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct GroupApplicationRejectedTipsJson {
    #[serde(default)]
    pub(crate) handle_msg: String,
    #[serde(default)]
    pub(crate) request: GroupRequestJson,
}
