/// 撤回通知扩展结构（protobuf RevokeMsgTips 不含 revokerNickname，此结构补充）
pub struct RevokeTipsWithNickname {
    pub tips: openim_protocol::sdkws::RevokeMsgTips,
    pub revoker_nickname: String,
    pub revoker_role: i32,
}

/// 从 JSON 内容解析 RevokeMsgTips（对齐 Go SDK UnmarshalNotificationElem）
pub fn parse_revoke_tips_from_json(content: &str) -> anyhow::Result<RevokeTipsWithNickname> {
    let content_str = content;

    // 解析外层 NotificationElem
    #[derive(serde::Deserialize)]
    struct Outer {
        #[serde(default)]
        detail: String,
    }
    let outer: Outer = serde_json::from_str(content_str)
        .map_err(|e| anyhow::anyhow!("解析外层 NotificationElem 失败: {}", e))?;

    // 解析内层 RevokeMsgTips JSON
    #[derive(serde::Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct Inner {
        #[serde(rename = "revokerUserID", default)]
        revoker_user_id: String,
        #[serde(rename = "clientMsgID", default)]
        client_msg_id: String,
        #[serde(default)]
        revoke_time: i64,
        #[serde(rename = "sesstionType", default)]
        sesstion_type: i32,
        #[serde(default)]
        seq: i64,
        #[serde(rename = "conversationID", default)]
        conversation_id: String,
        #[serde(rename = "isAdminRevoke", default)]
        is_admin_revoke: bool,
        #[serde(rename = "revokerNickname", default)]
        revoker_nickname: String,
        #[serde(rename = "revokerRole", default)]
        revoker_role: i32,
    }
    let inner: Inner = serde_json::from_str(&outer.detail)
        .map_err(|e| anyhow::anyhow!("解析内层 RevokeMsgTips 失败: {}", e))?;

    tracing::info!("[REVOKE-DEBUG-PARSE] parsed revoker_nickname='{}', revoker_role={}, user_id='{}'",
        inner.revoker_nickname, inner.revoker_role, inner.revoker_user_id);
    Ok(RevokeTipsWithNickname {
        tips: openim_protocol::sdkws::RevokeMsgTips {
            revoker_user_id: inner.revoker_user_id,
            client_msg_id: inner.client_msg_id,
            revoke_time: inner.revoke_time,
            sesstion_type: inner.sesstion_type,
            seq: inner.seq,
            conversation_id: inner.conversation_id,
            is_admin_revoke: inner.is_admin_revoke,
        },
        revoker_nickname: inner.revoker_nickname,
        revoker_role: inner.revoker_role,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_revoke_tips_valid() {
        let inner = serde_json::json!({
            "revokerUserID": "user_123",
            "clientMsgID": "msg_456",
            "revokeTime": 1700000000i64,
            "sesstionType": 1,
            "seq": 42,
            "conversationID": "conv_789",
            "isAdminRevoke": false,
            "revokerNickname": "Alice",
            "revokerRole": 60
        });
        let outer = serde_json::json!({ "detail": inner.to_string() });
        let content = outer.to_string();

        let result = parse_revoke_tips_from_json(&content).unwrap();
        assert_eq!(result.tips.revoker_user_id, "user_123");
        assert_eq!(result.tips.client_msg_id, "msg_456");
        assert_eq!(result.tips.revoke_time, 1700000000);
        assert_eq!(result.tips.sesstion_type, 1);
        assert_eq!(result.tips.seq, 42);
        assert_eq!(result.tips.conversation_id, "conv_789");
        assert!(!result.tips.is_admin_revoke);
        assert_eq!(result.revoker_nickname, "Alice");
        assert_eq!(result.revoker_role, 60);
    }

    #[test]
    fn test_parse_revoke_tips_admin_revoke() {
        let inner = serde_json::json!({
            "revokerUserID": "admin_1",
            "clientMsgID": "msg_001",
            "revokeTime": 1700000001i64,
            "sesstionType": 2,
            "seq": 10,
            "conversationID": "group_conv",
            "isAdminRevoke": true,
            "revokerNickname": "GroupAdmin",
            "revokerRole": 100
        });
        let outer = serde_json::json!({ "detail": inner.to_string() });

        let result = parse_revoke_tips_from_json(&outer.to_string()).unwrap();
        assert!(result.tips.is_admin_revoke);
        assert_eq!(result.revoker_role, 100);
        assert_eq!(result.tips.sesstion_type, 2);
    }

    #[test]
    fn test_parse_revoke_tips_missing_optional_fields() {
        let inner = serde_json::json!({
            "revokerUserID": "user_x",
            "clientMsgID": "msg_y",
            "revokeTime": 0i64,
            "sesstionType": 1,
            "seq": 1,
            "conversationID": "conv_z",
            "isAdminRevoke": false
        });
        let outer = serde_json::json!({ "detail": inner.to_string() });

        let result = parse_revoke_tips_from_json(&outer.to_string()).unwrap();
        assert_eq!(result.revoker_nickname, "");
        assert_eq!(result.revoker_role, 0);
    }

    #[test]
    fn test_parse_revoke_tips_invalid_outer_json() {
        let result = parse_revoke_tips_from_json("not valid json");
        assert!(result.is_err());
    }

    #[test]
    fn test_parse_revoke_tips_invalid_inner_json() {
        let outer = serde_json::json!({ "detail": "not{valid" });
        let result = parse_revoke_tips_from_json(&outer.to_string());
        assert!(result.is_err());
    }

    #[test]
    fn test_parse_revoke_tips_empty_detail() {
        let outer = serde_json::json!({ "detail": "" });
        let result = parse_revoke_tips_from_json(&outer.to_string());
        assert!(result.is_err());
    }
}
