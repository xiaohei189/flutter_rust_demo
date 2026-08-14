//! FriendApi — SDK 对外 API 契约（分域特征）
//!
//! 由 OpenIMClient 实现，pi/ 层依赖组合特征 SdkApi。

use crate::client::OpenIMClient;

use crate::error::{Result, SdkError};
use crate::event::events::friend::FriendEvent;
use crate::http::friend::{FriendApplyInfo, SearchFriendItem};
use crate::model::friend::FriendInfo;
use async_trait::async_trait;

#[async_trait]
pub trait FriendApi: Send + Sync {
    fn take_friend_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<FriendEvent>, SdkError>;
    async fn get_friend_list(&self) -> Vec<FriendInfo>;
    async fn sync_friends(&self) -> Result<()>;
    async fn add_friend(&self, user_id: &str, req_msg: Option<&str>) -> Result<()>;
    async fn delete_friend(&self, user_id: &str) -> Result<()>;
    async fn get_black_list(&self) -> Vec<String>;
    async fn is_friend(&self, user_id: &str) -> bool;
    async fn check_friend(&self, user_ids: Vec<String>) -> std::result::Result<Vec<crate::http::friend::CheckFriendResult>, SdkError>;
    async fn add_black(&self, user_id: &str) -> Result<()>;
    async fn remove_black(&self, user_id: &str) -> Result<()>;
    async fn is_in_blacklist(&self, user_id: &str) -> bool;
    async fn get_friend_apply_list(&self) -> std::result::Result<Vec<FriendApplyInfo>, SdkError>;
    async fn get_friend_apply_list_as_applicant(&self) -> std::result::Result<Vec<FriendApplyInfo>, SdkError>;
    async fn get_friend_application_unhandled_count(&self) -> Result<i32>;
    async fn accept_friend_application(&self, user_id: &str, handle_msg: Option<&str>) -> Result<()>;
    async fn refuse_friend_application(&self, user_id: &str, handle_msg: Option<&str>) -> Result<()>;
    async fn get_friend_id_list(&self) -> Vec<String>;
    async fn sync_friends_incremental(&self) -> Result<()>;
    async fn search_friends(&self, keyword: &str) -> Result<Vec<SearchFriendItem>>;
    async fn get_specified_friends_info(&self, friend_user_ids: Vec<String>, filter_black: bool) -> Result<Vec<FriendInfo>>;
    async fn get_friend_list_page(&self, offset: i32, count: i32, filter_black: bool) -> Result<Vec<FriendInfo>>;
    async fn update_friends(&self, friend_user_ids: Vec<String>, is_pinned: Option<bool>, remark: Option<String>, ex: Option<String>) -> Result<()>;
}

#[async_trait]
impl FriendApi for OpenIMClient {
    #[tracing::instrument(skip_all)]
    async fn get_friend_list(&self) -> Vec<FriendInfo> {
        self.friend.get_friend_list().await
    }

    #[tracing::instrument(skip_all)]
    async fn sync_friends(&self) -> Result<()> {
        self.friend.sync_friends().await
    }

    #[tracing::instrument(skip_all, fields(user_id = %user_id))]
    async fn add_friend(&self, user_id: &str, req_msg: Option<&str>) -> Result<()> {
        self.friend.add_friend(user_id.to_string(), req_msg.map(|s| s.to_string())).await
    }

    #[tracing::instrument(skip_all, fields(user_id = %user_id))]
    async fn delete_friend(&self, user_id: &str) -> Result<()> {
        self.friend.delete_friend(user_id.to_string()).await
    }

    #[tracing::instrument(skip_all)]
    async fn get_black_list(&self) -> Vec<String> {
        self.friend.get_blacklist().await
    }

    #[tracing::instrument(skip_all, fields(user_id = %user_id))]
    async fn is_friend(&self, user_id: &str) -> bool {
        self.friend.is_friend(user_id).await
    }

    /// 批量检查好友关系状态
    #[tracing::instrument(skip_all)]
    async fn check_friend(&self, user_ids: Vec<String>) -> std::result::Result<Vec<crate::http::friend::CheckFriendResult>, SdkError> {
        self.friend.check_friend(user_ids).await
    }

    #[tracing::instrument(skip_all, fields(user_id = %user_id))]
    async fn add_black(&self, user_id: &str) -> Result<()> {
        self.friend.add_black(user_id.to_string()).await
    }

    #[tracing::instrument(skip_all, fields(user_id = %user_id))]
    async fn remove_black(&self, user_id: &str) -> Result<()> {
        self.friend.remove_black(user_id.to_string()).await
    }

    #[tracing::instrument(skip_all, fields(user_id = %user_id))]
    async fn is_in_blacklist(&self, user_id: &str) -> bool {
        self.friend.is_in_blacklist(user_id).await
    }

    #[tracing::instrument(skip_all)]
    async fn get_friend_apply_list(&self) -> std::result::Result<Vec<FriendApplyInfo>, SdkError> {
        let resp = self.friend.get_friend_apply_list().await?;
        Ok(resp.apply_infos.unwrap_or_default())
    }

    /// 获取自己发出的好友申请列表
    #[tracing::instrument(skip_all)]
    async fn get_friend_apply_list_as_applicant(&self) -> std::result::Result<Vec<FriendApplyInfo>, SdkError> {
        let resp = self.friend.get_friend_apply_list_as_applicant().await?;
        Ok(resp.apply_infos.unwrap_or_default())
    }

    /// 获取未处理的好友申请数量
    #[tracing::instrument(skip_all)]
    async fn get_friend_application_unhandled_count(&self) -> Result<i32> {
        self.friend.get_friend_application_unhandled_count().await
    }

    #[tracing::instrument(skip_all, fields(user_id = %user_id))]
    async fn accept_friend_application(&self, user_id: &str, handle_msg: Option<&str>) -> Result<()> {
        self.friend.accept_friend_application(user_id.to_string(), handle_msg.map(|s| s.to_string())).await
    }

    #[tracing::instrument(skip_all, fields(user_id = %user_id))]
    async fn refuse_friend_application(&self, user_id: &str, handle_msg: Option<&str>) -> Result<()> {
        self.friend.refuse_friend_application(user_id.to_string(), handle_msg.map(|s| s.to_string())).await
    }

    #[tracing::instrument(skip_all)]
    async fn get_friend_id_list(&self) -> Vec<String> {
        self.friend.get_friend_id_list().await
    }

    /// 增量同步好友列表（对齐 Go SDK IncrSyncFriends）
    #[tracing::instrument(skip_all)]
    async fn sync_friends_incremental(&self) -> Result<()> {
        self.friend.sync_friends_incremental().await
    }

    /// 搜索好友（本地 SQLite 模糊查询，对齐 Go SDK SearchFriends）
    #[tracing::instrument(skip_all, fields(keyword = %keyword))]
    async fn search_friends(&self, keyword: &str) -> Result<Vec<SearchFriendItem>> {
        self.friend.search_friends(keyword.to_string()).await
    }

    /// 获取指定好友信息（对齐 Go SDK GetSpecifiedFriendsInfo）
    #[tracing::instrument(skip_all)]
    async fn get_specified_friends_info(&self, friend_user_ids: Vec<String>, filter_black: bool) -> Result<Vec<FriendInfo>> {
        self.friend.get_specified_friends_info(friend_user_ids, filter_black).await
    }

    /// 分页获取好友列表（对齐 Go SDK GetFriendListPage）
    async fn get_friend_list_page(&self, offset: i32, count: i32, filter_black: bool) -> Result<Vec<FriendInfo>> {
        self.friend.get_friend_list_page(offset, count, filter_black).await
    }

    /// 批量更新好友信息（对齐 Go SDK UpdateFriends）
    #[tracing::instrument(skip_all)]
    async fn update_friends(&self, friend_user_ids: Vec<String>, is_pinned: Option<bool>, remark: Option<String>, ex: Option<String>) -> Result<()> {
        self.friend.update_friends(friend_user_ids, is_pinned, remark, ex).await
    }

    /// 获取好友事件接收器（只能调用一次，重复调用返回错误）
    fn take_friend_rx(&self) -> std::result::Result<tokio::sync::mpsc::UnboundedReceiver<FriendEvent>, SdkError> {
        self.listeners.take_friend_rx().ok_or_else(|| SdkError::unknown("friend receiver already taken"))
    }
}
