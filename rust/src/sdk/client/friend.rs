use crate::domain::error::types::Result;
use crate::domain::error::types::SdkError;
use crate::domain::model::friend::FriendInfo;
use crate::sdk::client::{FriendApplyInfo, OpenIMClient};

impl OpenIMClient {
    /// 获取好友列表
    pub async fn get_friend_list(&self) -> Vec<FriendInfo> {
        self.friend.get_friend_list().await
    }

    /// 添加好友
    pub async fn add_friend(&self, user_id: String, req_msg: Option<String>) -> Result<()> {
        self.friend.add_friend(user_id, req_msg).await
    }

    /// 删除好友
    pub async fn delete_friend(&self, user_id: String) -> Result<()> {
        self.friend.delete_friend(user_id).await
    }

    /// 获取黑名单
    pub async fn get_black_list(&self) -> Vec<String> {
        self.friend.get_blacklist().await
    }

    /// 判断是否为好友
    pub async fn is_friend(&self, user_id: &str) -> bool {
        self.friend.is_friend(user_id).await
    }

    /// 添加到黑名单
    pub async fn add_black(&self, user_id: String) -> Result<()> {
        self.friend.add_black(user_id).await
    }

    /// 从黑名单移除
    pub async fn remove_black(&self, user_id: String) -> Result<()> {
        self.friend.remove_black(user_id).await
    }

    /// 获取好友申请列表
    pub async fn get_friend_apply_list(&self) -> std::result::Result<Vec<FriendApplyInfo>, SdkError> {
        let resp = self.friend.get_friend_apply_list().await?;
        Ok(resp.apply_infos.unwrap_or_default().into_iter().map(|a| FriendApplyInfo {
            user_id: a.user_id,
            nickname: a.nickname,
            face_url: a.face_url,
            create_time: a.create_time,
            req_msg: a.req_msg,
            handle_result: a.handle_result,
        }).collect())
    }

    /// 接受好友申请
    pub async fn accept_friend_application(&self, user_id: String, handle_msg: Option<String>) -> Result<()> {
        self.friend.accept_friend_application(user_id, handle_msg).await
    }

    /// 拒绝好友申请
    pub async fn refuse_friend_application(&self, user_id: String, handle_msg: Option<String>) -> Result<()> {
        self.friend.refuse_friend_application(user_id, handle_msg).await
    }

    /// 获取好友 ID 列表
    pub async fn get_friend_id_list(&self) -> Vec<String> {
        self.friend.get_friend_id_list().await
    }
}
