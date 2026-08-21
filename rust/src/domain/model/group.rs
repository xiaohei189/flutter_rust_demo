use serde::{Deserialize, Serialize};

/// 群组信息模型
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GroupInfo {
    /// 群组 ID
    pub group_id: String,
    /// 群组名称
    pub group_name: String,
    /// 头像 URL
    pub face_url: String,
    /// 群简介
    pub introduction: String,
    /// 群公告
    pub notification: String,
    /// 群主 ID
    pub owner_user_id: String,
    /// 创建时间
    pub create_time: i64,
    /// 成员数量
    pub member_count: u32,
    /// 状态 (0:正常, 1:封禁, 2:解散)
    pub status: i32,
}

/// 群成员信息模型
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GroupMember {
    /// 群组 ID
    pub group_id: String,
    /// 用户 ID
    pub user_id: String,
    /// 昵称
    pub nickname: String,
    /// 头像 URL
    pub face_url: String,
    /// 角色等级 (1:普通成员, 2:管理员, 3:群主)
    pub role_level: i32,
    /// 加入时间
    pub join_time: i64,
    /// 加入来源
    pub join_source: String,
}

/// 设置群组信息字段（仅设置需要修改的字段）
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct SetGroupInfoFields {
    pub group_id: String,
    pub group_name: Option<String>,
    pub face_url: Option<String>,
    pub introduction: Option<String>,
    pub notification: Option<String>,
    pub ex: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_group_member_creation() {
        let member = GroupMember {
            group_id: "g1".to_string(),
            user_id: "u1".to_string(),
            nickname: "Test".to_string(),
            face_url: String::new(),
            role_level: 1,
            join_time: 1000,
            join_source: "1".to_string(),
        };
        assert_eq!(member.user_id, "u1");
        assert_eq!(member.role_level, 1);
    }

    #[test]
    fn test_set_group_info_fields_creation() {
        let fields = SetGroupInfoFields {
            group_id: "g1".to_string(),
            group_name: Some("New Name".to_string()),
            face_url: None,
            introduction: None,
            notification: None,
            ex: None,
        };
        assert_eq!(fields.group_id, "g1");
    }
}
