use serde::{Deserialize, Serialize};

/// 好友信息模型
#[derive(Clone, Debug, Serialize, Deserialize)]
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
