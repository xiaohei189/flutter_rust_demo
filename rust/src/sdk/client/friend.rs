use crate::domain::error::types::Result;
use crate::domain::error::types::SdkError;
use crate::domain::model::friend::FriendInfo;
use crate::sdk::client::{FriendApplyInfo, OpenIMClient};

impl OpenIMClient {
    pub async fn get_friend_list(&self) -> Vec<FriendInfo> {
        self.friend.get_friend_list().await
    }

    pub async fn add_friend(&self, user_id: &str, req_msg: Option<&str>) -> Result<()> {
        self.friend.add_friend(user_id.to_string(), req_msg.map(|s| s.to_string())).await
    }

    pub async fn delete_friend(&self, user_id: &str) -> Result<()> {
        self.friend.delete_friend(user_id.to_string()).await
    }

    pub async fn get_black_list(&self) -> Vec<String> {
        self.friend.get_blacklist().await
    }

    pub async fn is_friend(&self, user_id: &str) -> bool {
        self.friend.is_friend(user_id).await
    }

    pub async fn add_black(&self, user_id: &str) -> Result<()> {
        self.friend.add_black(user_id.to_string()).await
    }

    pub async fn remove_black(&self, user_id: &str) -> Result<()> {
        self.friend.remove_black(user_id.to_string()).await
    }

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

    pub async fn accept_friend_application(&self, user_id: &str, handle_msg: Option<&str>) -> Result<()> {
        self.friend.accept_friend_application(user_id.to_string(), handle_msg.map(|s| s.to_string())).await
    }

    pub async fn refuse_friend_application(&self, user_id: &str, handle_msg: Option<&str>) -> Result<()> {
        self.friend.refuse_friend_application(user_id.to_string(), handle_msg.map(|s| s.to_string())).await
    }

    pub async fn get_friend_id_list(&self) -> Vec<String> {
        self.friend.get_friend_id_list().await
    }
}