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
