use serde::{Deserialize, Serialize};

/// 好友信息模型
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FriendInfo {
    /// 用户 ID
    pub user_id: String,
    /// 昵称
    pub nickname: String,
    /// 头像 URL
    pub face_url: String,
    /// 性别 (0:未知, 1:男, 2:女)
    pub gender: i32,
    /// 备注
    pub remark: String,
    /// 创建时间
    pub create_time: i64,
    /// 添加来源
    pub add_source: String,
    /// 扩展字段
    pub ex: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_friend_info_creation() {
        let info = FriendInfo {
            user_id: "user_1".to_string(),
            nickname: "Test".to_string(),
            face_url: "http://example.com/avatar.jpg".to_string(),
            gender: 1,
            remark: "My Friend".to_string(),
            create_time: 1000,
            add_source: "1".to_string(),
            ex: String::new(),
        };
        assert_eq!(info.user_id, "user_1");
        assert_eq!(info.remark, "My Friend");
    }
}
