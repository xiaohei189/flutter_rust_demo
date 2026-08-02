//! 好友相关 FFI 桥接

use crate::domain::sdk_api::SdkApi;
use crate::api::client::OpenIMBridgeClient;
use crate::domain::ports::friend::FriendApplyInfo;
use anyhow::{Result, anyhow};

impl OpenIMBridgeClient {
    // ========== 好友操作 ==========

    #[flutter_rust_bridge::frb]
    pub async fn get_friend_list(&self) -> Result<Vec<crate::domain::model::friend::FriendInfo>> {
        Ok(self.inner.get_friend_list().await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn add_friend(&self, user_id: String, req_msg: String) -> Result<()> {
        self.inner.add_friend(&user_id, Some(&req_msg)).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn delete_friend(&self, user_id: String) -> Result<()> {
        self.inner.delete_friend(&user_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_black_list(&self) -> Result<Vec<String>> {
        Ok(self.inner.get_black_list().await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn is_friend(&self, user_id: String) -> bool {
        self.inner.is_friend(&user_id).await
    }

    #[flutter_rust_bridge::frb]
    pub async fn add_black(&self, user_id: String) -> Result<()> {
        self.inner.add_black(&user_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn remove_black(&self, user_id: String) -> Result<()> {
        self.inner.remove_black(&user_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn is_in_blacklist(&self, user_id: String) -> Result<bool> {
        Ok(self.inner.is_in_blacklist(&user_id).await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn check_friend(&self, user_ids: Vec<String>) -> Result<Vec<crate::domain::ports::friend::CheckFriendResult>> {
        self.inner.check_friend(user_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_friend_apply_list(&self) -> Result<Vec<FriendApplyInfo>> {
        self.inner.get_friend_apply_list().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_friend_apply_list_as_applicant(&self) -> Result<Vec<FriendApplyInfo>> {
        self.inner.get_friend_apply_list_as_applicant().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_friend_application_unhandled_count(&self) -> Result<i32> {
        self.inner.get_friend_application_unhandled_count().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn accept_friend_application(&self, user_id: String, handle_msg: Option<String>) -> Result<()> {
        self.inner.accept_friend_application(&user_id, handle_msg.as_deref()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn refuse_friend_application(&self, user_id: String, handle_msg: Option<String>) -> Result<()> {
        self.inner.refuse_friend_application(&user_id, handle_msg.as_deref()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_friend_id_list(&self) -> Result<Vec<String>> {
        Ok(self.inner.get_friend_id_list().await)
    }

    /// 增量同步好友列表（对齐 Go SDK IncrSyncFriends）
    #[flutter_rust_bridge::frb]
    pub async fn sync_friends_incremental(&self) -> Result<()> {
        self.inner.sync_friends_incremental().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 搜索好友（本地 SQLite 模糊查询，对齐 Go SDK SearchFriends）
    ///
    /// keyword: 搜索关键词，匹配 nickname / user_id / remark
    #[flutter_rust_bridge::frb]
    pub async fn search_friends(&self, keyword: String) -> Result<Vec<crate::domain::ports::friend::SearchFriendItem>> {
        self.inner.search_friends(&keyword).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 获取指定好友信息（对齐 Go SDK GetSpecifiedFriendsInfo）
    ///
    /// 先查本地 DB，缺失的从服务端拉取并缓存。
    /// filter_black=true 时过滤掉黑名单中的好友。
    #[flutter_rust_bridge::frb]
    pub async fn get_specified_friends_info(
        &self,
        friend_user_ids: Vec<String>,
        filter_black: bool,
    ) -> Result<Vec<crate::domain::model::friend::FriendInfo>> {
        self.inner.get_specified_friends_info(friend_user_ids, filter_black).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 分页获取好友列表（对齐 Go SDK GetFriendListPage）
    ///
    /// 从本地 DB 按置顶优先、创建时间倒序分页获取。
    /// filter_black=true 时过滤黑名单好友。
    #[flutter_rust_bridge::frb]
    pub async fn get_friend_list_page(
        &self,
        offset: i32,
        count: i32,
        filter_black: bool,
    ) -> Result<Vec<crate::domain::model::friend::FriendInfo>> {
        self.inner.get_friend_list_page(offset, count, filter_black).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 批量更新好友信息（对齐 Go SDK UpdateFriends）
    ///
    /// 支持部分更新：is_pinned / remark / ex 为 null 时不修改对应字段。
    /// 更新成功后自动执行增量同步刷新本地数据。
    #[flutter_rust_bridge::frb]
    pub async fn update_friends(
        &self,
        friend_user_ids: Vec<String>,
        is_pinned: Option<bool>,
        remark: Option<String>,
        ex: Option<String>,
    ) -> Result<()> {
        self.inner.update_friends(friend_user_ids, is_pinned, remark, ex).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }
}
