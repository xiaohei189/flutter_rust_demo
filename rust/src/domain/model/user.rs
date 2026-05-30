use serde::{Deserialize, Serialize};

/// 用户信息模型
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UserInfo {
    /// 用户 ID
    pub user_id: String,
    /// 昵称
    pub nickname: String,
    /// 头像 URL
    pub face_url: String,
    /// 性别 (0:未知, 1:男, 2:女)
    pub gender: i32,
    /// 手机号
    pub telephone: String,
    /// 邮箱
    pub email: String,
    /// 备注
    pub remark: String,
    /// 全局免打扰
    pub global_recv_msg_opt: i32,
}
