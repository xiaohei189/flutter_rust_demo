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
    let content_str = std::str::from_utf8(content).map_err(|e| anyhow::anyhow!("content 不是有效 UTF-8: {}", e))?;
    let outer: NotificationElem = serde_json::from_str(content_str).map_err(|e| anyhow::anyhow!("解析外层 NotificationElem 失败: {}", e))?;
    let inner: T = serde_json::from_str(&outer.detail).map_err(|e| anyhow::anyhow!("解析内层 detail 失败: {}", e))?;
    Ok(inner)
}

// --- 撤回通知 (2101) ---

#[derive(Debug, Deserialize)]
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
    #[serde(default, rename = "faceURL")]
    pub(crate) face_url: String,
    #[serde(default)]
    pub(crate) ex: String,
    #[serde(default, rename = "globalRecvMsgOpt")]
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

/// 仅携带用户 ID 的通知（好友删除/黑名单等）
#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub(crate) struct UserIdOnlyJson {
    #[serde(default, rename = "userID")]
    pub(crate) user_id: String,
}

/// 群组变更通知中用于提取 groupID 的宽泛结构
#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub(crate) struct GroupChangeInfoJson {
    #[serde(default, rename = "groupID")]
    pub(crate) group_id: String,
    #[serde(default)]
    pub(crate) group: GroupInfoJson,
    #[serde(default, rename = "groupInfo")]
    pub(crate) group_info: GroupInfoJson,
}

impl GroupChangeInfoJson {
    pub(crate) fn effective_group_id(&self) -> String {
        if !self.group_id.is_empty() {
            self.group_id.clone()
        } else if !self.group.group_id.is_empty() {
            self.group.group_id.clone()
        } else {
            self.group_info.group_id.clone()
        }
    }
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_unmarshal_revoke_notification() {
        let content = r#"{"detail":"{\"revokerUserID\":\"user_1\",\"clientMsgID\":\"msg_001\",\"revokeTime\":1000,\"sesstionType\":1,\"seq\":5,\"conversationID\":\"conv_1\",\"isAdminRevoke\":false,\"revokerNickname\":\"Alice\",\"revokerRole\":1}"}"#;
        let tips: RevokeMsgTipsJson = unmarshal_notification_elem(content.as_bytes()).unwrap();
        assert_eq!(tips.revoker_user_id, "user_1");
        assert_eq!(tips.client_msg_id, "msg_001");
        assert_eq!(tips.seq, 5);
        assert_eq!(tips.revoker_nickname, "Alice");
        assert!(!tips.is_admin_revoke);
    }

    #[test]
    fn test_unmarshal_revoke_notification_admin_revoke() {
        let content =
            r#"{"detail":"{\"revokerUserID\":\"admin_1\",\"clientMsgID\":\"msg_002\",\"revokeTime\":2000,\"sesstionType\":2,\"seq\":10,\"conversationID\":\"sg_group_1\",\"isAdminRevoke\":true}"}"#;
        let tips: RevokeMsgTipsJson = unmarshal_notification_elem(content.as_bytes()).unwrap();
        assert_eq!(tips.revoker_user_id, "admin_1");
        assert_eq!(tips.seq, 10);
        assert!(tips.is_admin_revoke);
        // 没有提供时使用默认值
        assert_eq!(tips.revoker_nickname, "");
    }

    #[test]
    fn test_unmarshal_friend_application_approved() {
        let content = r#"{"detail":"{\"handleMsg\":\"Welcome!\",\"request\":{\"fromUserID\":\"user_a\",\"toUserID\":\"user_b\",\"fromNickname\":\"Alice\",\"fromFaceURL\":\"http://example.com/avatar.jpg\",\"handleResult\":1,\"reqMsg\":\"\",\"createTime\":1000}}"}"#;
        let tips: FriendApplicationApprovedTipsJson = unmarshal_notification_elem(content.as_bytes()).unwrap();
        assert_eq!(tips.handle_msg, "Welcome!");
        assert_eq!(tips.request.from_user_id, "user_a");
        assert_eq!(tips.request.from_nickname, "Alice");
    }

    #[test]
    fn test_unmarshal_friend_application_rejected() {
        let content = r#"{"detail":"{\"handleMsg\":\"Sorry\",\"request\":{\"fromUserID\":\"user_a\",\"fromNickname\":\"Alice\",\"handleResult\":-1,\"createTime\":1000}}"}"#;
        let tips: FriendApplicationRejectedTipsJson = unmarshal_notification_elem(content.as_bytes()).unwrap();
        assert_eq!(tips.handle_msg, "Sorry");
        assert_eq!(tips.request.handle_result, -1);
    }

    #[test]
    fn test_unmarshal_friend_application_added() {
        let content = r#"{"detail":"{\"request\":{\"fromUserID\":\"user_a\",\"fromNickname\":\"Alice\",\"fromFaceURL\":\"http://example.com/avatar.jpg\",\"handleResult\":0,\"reqMsg\":\"Hello!\",\"createTime\":1000}}"}"#;
        let tips: FriendApplicationTipsJson = unmarshal_notification_elem(content.as_bytes()).unwrap();
        assert_eq!(tips.request.from_user_id, "user_a");
        assert_eq!(tips.request.req_msg, "Hello!");
        assert_eq!(tips.request.handle_result, 0);
    }

    #[test]
    fn test_unmarshal_user_info_updated() {
        let content = r#"{"detail":"{\"userID\":\"user_1\",\"nickname\":\"NewName\",\"faceURL\":\"http://example.com/new.jpg\",\"ex\":\"some ex\",\"globalRecvMsgOpt\":1}"}"#;
        let info: UserInfoJson = unmarshal_notification_elem(content.as_bytes()).unwrap();
        assert_eq!(info.user_id, "user_1");
        assert_eq!(info.nickname, "NewName");
        assert_eq!(info.global_recv_msg_opt, 1);
    }

    #[test]
    fn test_unmarshal_group_application_added() {
        let content = r#"{"detail":"{\"request\":{\"groupInfo\":{\"groupID\":\"group_1\"},\"userInfo\":{\"userID\":\"user_a\",\"nickname\":\"Alice\",\"faceURL\":\"\"},\"handleResult\":0,\"reqMsg\":\"Please add me\"}}"}"#;
        let tips: JoinGroupApplicationTipsJson = unmarshal_notification_elem(content.as_bytes()).unwrap();
        assert_eq!(tips.request.group_info.group_id, "group_1");
        assert_eq!(tips.request.user_info.user_id, "user_a");
        assert_eq!(tips.request.req_msg, "Please add me");
    }

    #[test]
    fn test_unmarshal_group_application_accepted() {
        let content = r#"{"detail":"{\"handleMsg\":\"Approved\",\"request\":{\"groupInfo\":{\"groupID\":\"group_1\"},\"userInfo\":{\"userID\":\"user_a\"},\"handleResult\":1}}"}"#;
        let tips: GroupApplicationAcceptedTipsJson = unmarshal_notification_elem(content.as_bytes()).unwrap();
        assert_eq!(tips.handle_msg, "Approved");
        assert_eq!(tips.request.group_info.group_id, "group_1");
    }

    #[test]
    fn test_unmarshal_group_application_rejected() {
        let content = r#"{"detail":"{\"handleMsg\":\"Rejected\",\"request\":{\"groupInfo\":{\"groupID\":\"group_1\"},\"userInfo\":{\"userID\":\"user_a\"},\"handleResult\":-1}}"}"#;
        let tips: GroupApplicationRejectedTipsJson = unmarshal_notification_elem(content.as_bytes()).unwrap();
        assert_eq!(tips.handle_msg, "Rejected");
        assert_eq!(tips.request.handle_result, -1);
    }

    // ========== 异常路径测试 ==========

    #[test]
    fn test_unmarshal_invalid_outer_json() {
        let content = b"not json";
        let result: anyhow::Result<RevokeMsgTipsJson> = unmarshal_notification_elem(content);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("外层"));
    }

    #[test]
    fn test_unmarshal_invalid_detail_json() {
        let content = br#"{"detail":"not valid json inside"}"#;
        let result: anyhow::Result<RevokeMsgTipsJson> = unmarshal_notification_elem(content);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("内层"));
    }

    #[test]
    fn test_unmarshal_missing_detail_field() {
        let content = br#"{"otherField":"value"}"#;
        let result: anyhow::Result<RevokeMsgTipsJson> = unmarshal_notification_elem(content);
        assert!(result.is_err());
    }

    #[test]
    fn test_unmarshal_empty_content() {
        let content = b"";
        let result: anyhow::Result<RevokeMsgTipsJson> = unmarshal_notification_elem(content);
        assert!(result.is_err());
    }

    #[test]
    fn test_unmarshal_non_utf8_content() {
        let content = &[0xFF, 0xFE, 0x00, 0x01];
        let result: anyhow::Result<RevokeMsgTipsJson> = unmarshal_notification_elem(content);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("UTF-8"));
    }
}
