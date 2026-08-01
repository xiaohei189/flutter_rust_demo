use crate::domain::error::{Result, SdkError};
use crate::event::bus::EventBus;
use crate::event::sender::EventSender;
use crate::event::types::SdkEvent;
use crate::event::events::friend::{FriendListener, FriendEvent};
use crate::domain::model::friend::FriendInfo;
use crate::domain::model::UserId;
use crate::domain::model::local::LocalFriend;
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{
    ACCEPT_FRIEND_APPLICATION, ADD_BLACK, ADD_FRIEND, CHECK_FRIEND, DELETE_FRIEND,
    GET_BLACK_LIST, GET_DESIGNATED_FRIENDS, GET_FRIEND_APPLY_LIST, GET_FRIEND_ID_LIST,
    GET_FRIEND_LIST, GET_FULL_FRIEND_USER_IDS, GET_INCREMENTAL_FRIENDS,
    GET_SELF_FRIEND_APPLY_LIST, GET_SELF_UNHANDLED_APPLY_COUNT, REFUSE_FRIEND_APPLICATION,
    REMOVE_BLACK, RESPOND_FRIEND_APPLY, UPDATE_FRIENDS,
};
use crate::sdk::context::Repositories;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFriendListReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "pagination")]
    pub pagination: Pagination,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Pagination {
    #[serde(rename = "pageNumber")]
    pub page_number: i32,
    #[serde(rename = "showNumber")]
    pub show_number: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FriendUserInfo {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    pub ex: String,
    #[serde(rename = "createTime", default)]
    pub create_time: i64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FriendServerInfo {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    pub remark: String,
    #[serde(rename = "createTime", default)]
    pub create_time: i64,
    #[serde(rename = "friendUser")]
    pub friend_user: FriendUserInfo,
    #[serde(rename = "addSource", default)]
    pub add_source: i32,
    #[serde(rename = "operatorUserID", default)]
    pub operator_user_id: String,
    #[serde(default)]
    pub ex: String,
    #[serde(rename = "isPinned", default)]
    pub is_pinned: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetFriendListResp {
    #[serde(rename = "friendsInfo", default)]
    pub friends_info: Option<Vec<FriendServerInfo>>,
    #[serde(rename = "total", default)]
    pub total: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AddFriendReq {
    #[serde(rename = "fromUserID")]
    pub from_user_id: String,
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
    #[serde(rename = "reqMsg")]
    pub req_msg: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DeleteFriendReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFriendIdListResp {
    #[serde(rename = "friendIDs")]
    pub friend_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AddBlackReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RemoveBlackReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetBlackListResp {
    #[serde(rename = "blacksInfo", default)]
    pub blacks_info: Vec<BlackServerInfo>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BlackServerInfo {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    pub ex: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFriendApplyListReq {
    #[serde(rename = "userID")]
    pub from_user_id: String,
    #[serde(rename = "pagination")]
    pub pagination: Pagination,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetFriendApplyListResp {
    #[serde(rename = "applyInfos", default)]
    pub apply_infos: Option<Vec<FriendApplyInfo>>,
    #[serde(rename = "total", default)]
    pub total: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FriendApplyInfo {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    pub gender: i32,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    #[serde(rename = "addSource")]
    pub add_source: i32,
    pub ex: String,
    pub req_msg: Option<String>,
    pub handle_result: i32,
    pub handle_msg: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AcceptFriendApplicationReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
    #[serde(rename = "handleMsg")]
    pub handle_msg: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RefuseFriendApplicationReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
    #[serde(rename = "handleMsg")]
    pub handle_msg: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CheckFriendResult {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "result")]
    pub result: i32,
}

// ========== 增量同步类型 ==========

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetIncrementalFriendsReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub version: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetIncrementalFriendsResp {
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub full: bool,
    #[serde(default)]
    pub delete: Vec<String>,
    #[serde(default)]
    pub insert: Vec<FriendServerInfo>,
    #[serde(default)]
    pub update: Vec<FriendServerInfo>,
    #[serde(rename = "sortVersion", default)]
    pub sort_version: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFullFriendUserIDsReq {
    #[serde(rename = "idHash")]
    pub id_hash: u64,
    #[serde(rename = "userID")]
    pub user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetFullFriendUserIDsResp {
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub equal: bool,
    #[serde(rename = "userIDs", default)]
    pub user_ids: Vec<String>,
}

// ========== 搜索好友类型（对齐 Go SDK SearchFriendsParam） ==========

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SearchFriendsParam {
    #[serde(rename = "keywordList")]
    pub keyword_list: Vec<String>,
    #[serde(rename = "isSearchUserID", default)]
    pub is_search_user_id: bool,
    #[serde(rename = "isSearchNickname", default)]
    pub is_search_nickname: bool,
    #[serde(rename = "isSearchRemark", default)]
    pub is_search_remark: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SearchFriendItem {
    #[serde(rename = "friendUserID")]
    pub friend_user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    pub remark: String,
    pub ex: String,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    /// 1=好友, 2=黑名单
    #[serde(rename = "relationship")]
    pub relationship: i32,
}

// ========== 指定好友查询（对齐 Go SDK GetSpecifiedFriendsInfo） ==========

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetDesignatedFriendsReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "friendUserIDs")]
    pub friend_user_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetDesignatedFriendsResp {
    #[serde(rename = "friendsInfo", default)]
    pub friends_info: Vec<FriendServerInfo>,
}

// ========== 批量更新好友（对齐 Go SDK UpdateFriends） ==========

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UpdateFriendsReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "friendUserIDs")]
    pub friend_user_ids: Vec<String>,
    #[serde(rename = "isPinned", skip_serializing_if = "Option::is_none")]
    pub is_pinned: Option<bool>,
    #[serde(rename = "remark", skip_serializing_if = "Option::is_none")]
    pub remark: Option<String>,
    #[serde(rename = "ex", skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
}

pub struct FriendService {
    /// 外部依赖
    http_client: Arc<HttpApiClient>,
    repositories: Arc<Repositories>,
    /// 身份
    user_id: UserId,
    /// 内部状态
    friends: Arc<RwLock<Vec<FriendInfo>>>,
    blacks: Arc<RwLock<Vec<String>>>,
    /// 事件
    pub(crate) events: EventSender<FriendEvent>,
}

impl FriendService {
    pub fn new(
        http_client: Arc<HttpApiClient>,
        repositories: Arc<Repositories>,
        user_id: UserId,
    ) -> Self {
        Self {
            http_client,
            repositories,
            user_id,
            friends: Arc::new(RwLock::new(Vec::new())),
            blacks: Arc::new(RwLock::new(Vec::new())),
            events: EventSender::new(),
        }
    }

    pub fn set_event_sender(&self, tx: tokio::sync::mpsc::UnboundedSender<FriendEvent>) {
        self.events.set_sender(tx);
    }

    pub(crate) fn send(&self, e: FriendEvent) {
        tracing::info!("[SEND] {:?}, has_subscriber={}", &e, self.events.has_subscriber());
        self.events.publish(e);
    }

    fn notify_friend(&self, f: impl FnOnce(&dyn FriendListener)) {
    }

    fn on_added(&self, fs: &[FriendInfo]) { self.notify_friend(|l| l.on_added(fs)); }
    fn on_deleted(&self, id: &str) { self.notify_friend(|l| l.on_deleted(id)); }
    fn on_black_added(&self, id: &str) { self.notify_friend(|l| l.on_black_added(id)); }
    fn on_black_deleted(&self, id: &str) { self.notify_friend(|l| l.on_black_deleted(id)); }

    pub async fn set_user_id(&self, user_id: String) {
        self.user_id.set(user_id.clone()).await;
        debug!("FriendService user_id 已更新为: {}", user_id);
    }

    /// 从本地数据库加载好友列表到内存缓存
    /// 在登录时调用，确保切换账号后能立即显示已有数据
    pub async fn load_friends_from_db(&self) {
        let user_id = self.user_id.get().await;
        match self.repositories.friend_repo.get_all(&user_id).await {
            Ok(local_friends) => {
                let friends: Vec<FriendInfo> = local_friends.iter().map(local_to_friend_info).collect();
                let count = friends.len();
                *self.friends.write().await = friends;
                info!("从数据库加载好友列表完成, count={}", count);
            }
            Err(e) => {
                warn!("从数据库加载好友列表失败: {}", e);
            }
        }
    }

    pub async fn get_friend_list(&self) -> Vec<FriendInfo> {
        self.friends.read().await.clone()
    }

    pub async fn get_friend_id_list(&self) -> Vec<String> {
        self.friends
            .read()
            .await
            .iter()
            .map(|f| f.user_id.clone())
            .collect()
    }

    /// 全量同步好友列表（对齐 Go SDK FullSync）
    ///
    /// 从服务端拉取全部好友并覆盖本地内存 + 数据库
    pub async fn sync_friends(&self) -> Result<()> {
        let user_id = self.user_id.get().await;
        let req = GetFriendListReq {
            user_id: user_id.clone(),
            pagination: Pagination {
                page_number: 1,
                show_number: 1000,
            },
        };

        let resp: GetFriendListResp = self.http_client.post(GET_FRIEND_LIST, &req).await?;

        let friends: Vec<FriendInfo> = resp
            .friends_info
            .unwrap_or_default()
            .into_iter()
            .map(|s| server_to_friend(s))
            .collect();

        // 持久化到数据库
        let local_friends: Vec<LocalFriend> = friends.iter().map(|f| friend_info_to_local(f, &user_id)).collect();
        if let Err(e) = self.repositories.friend_repo.batch_upsert(&local_friends).await {
            warn!("全量同步好友到数据库失败: {}", e);
        }

        // 更新内存缓存
        *self.friends.write().await = friends.clone();

        self.send(FriendEvent::Added(friends.to_vec()));

        info!("好友列表已全量同步, count={}", friends.len());
        Ok(())
    }

    /// 增量同步好友列表（对齐 Go SDK IncrSyncFriends / VersionSynchronizer）
    ///
    /// 1. 从 local_sync_version 读取本地版本
    /// 2. 调用 get_incremental_friends 获取增量数据
    /// 3. 如果 full=true 回退到全量同步
    /// 4. 否则处理 delete/insert/update 增量合并
    /// 5. 更新版本号
    pub async fn sync_friends_incremental(&self) -> Result<()> {
        let user_id = self.user_id.get().await;
        let table_name = "local_friends";

        // 1. 获取本地版本
        let (version_id, version) = match self.repositories.sync_version_repo.get_version_sync(table_name, &user_id).await? {
            Some((vid, v)) => (vid, v),
            None => (String::new(), 0),
        };

        info!("开始增量同步好友, version={}, version_id={}", version, version_id);

        // 2. 请求增量数据
        let req = GetIncrementalFriendsReq {
            user_id: user_id.clone(),
            version_id: version_id.clone(),
            version,
        };

        let resp: GetIncrementalFriendsResp = match self.http_client.post(GET_INCREMENTAL_FRIENDS, &req).await {
            Ok(r) => r,
            Err(e) => {
                warn!("增量同步好友请求失败, 回退全量同步: {}", e);
                return self.sync_friends().await;
            }
        };

        // 3. full=true 回退全量
        if resp.full {
            info!("服务端返回 full=true, 执行全量同步");
            return self.sync_friends().await;
        }

        // 4. 处理增量变更

        // 4a. 删除
        if !resp.delete.is_empty() {
            info!("增量同步: 删除 {} 个好友", resp.delete.len());
            if let Err(e) = self.repositories.friend_repo.batch_delete(&user_id, &resp.delete).await {
                warn!("增量删除好友数据库操作失败: {}", e);
            }
            // 更新内存
            let del_set: HashSet<&String> = resp.delete.iter().collect();
            self.friends.write().await.retain(|f| !del_set.contains(&f.user_id));
        }

        // 4b. 新增
        for s in &resp.insert {
            let friend_info = server_to_friend(s.clone());
            let local = friend_info_to_local(&friend_info, &user_id);
            if let Err(e) = self.repositories.friend_repo.upsert(&local).await {
                warn!("增量插入好友数据库操作失败: {}", e);
            }
            self.friends.write().await.push(friend_info);
        }

        // 4c. 更新
        for s in &resp.update {
            let friend_info = server_to_friend(s.clone());
            let local = friend_info_to_local(&friend_info, &user_id);
            if let Err(e) = self.repositories.friend_repo.upsert(&local).await {
                warn!("增量更新好友数据库操作失败: {}", e);
            }
            // 更新内存中的对应好友
            let mut friends = self.friends.write().await;
            if let Some(existing) = friends.iter_mut().find(|f| f.user_id == friend_info.user_id) {
                *existing = friend_info;
            } else {
                // 本地不存在视为新增
                friends.push(friend_info);
            }
        }

        // 4d. 如果排序版本变化，从数据库刷新内存列表
        if resp.sort_version > 0 {
            info!("好友排序版本变化 (sortVersion={}), 刷新内存列表", resp.sort_version);
            if let Ok(local_friends) = self.repositories.friend_repo.get_all(&user_id).await {
                let friends: Vec<FriendInfo> = local_friends.iter().map(local_to_friend_info).collect();
                *self.friends.write().await = friends;
            }
        }

        // 5. 更新版本号
        if let Err(e) = self.repositories.sync_version_repo.set_version_sync(table_name, &user_id, &resp.version_id, resp.version).await {
            warn!("更新好友同步版本失败: {}", e);
        }

        // 发布事件
        if !resp.insert.is_empty() || !resp.update.is_empty() {
            let all_changed: Vec<FriendInfo> = resp.insert.iter().chain(resp.update.iter())
                .map(|s| server_to_friend(s.clone()))
                .collect();
            self.send(FriendEvent::Added(all_changed.to_vec()));
        }

        info!("增量同步好友完成, insert={}, update={}, delete={}",
            resp.insert.len(), resp.update.len(), resp.delete.len());
        Ok(())
    }

    /// 搜索好友（本地 SQLite 模糊查询，对齐 Go SDK SearchFriends）
    ///
    /// keyword: 搜索关键词，匹配 nickname / user_id / remark
    pub async fn search_friends(&self, keyword: String) -> Result<Vec<SearchFriendItem>> {
        let user_id = self.user_id.get().await;
        let local_friends = self.repositories.friend_repo.search_friends(&user_id, &keyword).await?;

        // 获取黑名单用于标记 relationship
        let blacks = self.blacks.read().await;
        let black_set: HashSet<&String> = blacks.iter().collect();

        let items: Vec<SearchFriendItem> = local_friends.into_iter().map(|f| {
            let relationship = if black_set.contains(&f.friend_user_id) { 2 } else { 1 };
            SearchFriendItem {
                friend_user_id: f.friend_user_id,
                nickname: f.nickname,
                face_url: f.face_url,
                remark: f.remark,
                ex: f.ex,
                create_time: f.create_time,
                relationship,
            }
        }).collect();

        Ok(items)
    }

    /// 获取指定好友信息（对齐 Go SDK GetSpecifiedFriendsInfo）
    ///
    /// 先查本地 DB，缺失的从服务端拉取并缓存到本地。
    /// filterBlack=true 时过滤掉黑名单中的好友。
    pub async fn get_specified_friends_info(
        &self,
        friend_user_ids: Vec<String>,
        filter_black: bool,
    ) -> Result<Vec<FriendInfo>> {
        let user_id = self.user_id.get().await;

        // 1. 从本地 DB 查询已有数据
        let mut local_map: std::collections::HashMap<String, LocalFriend> =
            std::collections::HashMap::new();
        let mut missing_ids: Vec<String> = Vec::new();

        for uid in &friend_user_ids {
            match self.repositories.friend_repo.get_by_id(&user_id, uid).await {
                Ok(Some(f)) => {
                    local_map.insert(uid.clone(), f);
                }
                _ => {
                    missing_ids.push(uid.clone());
                }
            }
        }

        // 2. 缺失的从服务端拉取
        if !missing_ids.is_empty() {
            let req = GetDesignatedFriendsReq {
                owner_user_id: user_id.clone(),
                friend_user_ids: missing_ids,
            };
            let resp: GetDesignatedFriendsResp =
                self.http_client.post(GET_DESIGNATED_FRIENDS, &req).await?;

            // 缓存到本地 DB + 内存
            let server_friends = resp
                .friends_info
                .into_iter()
                .map(|s| {
                    let info = server_to_friend(s.clone());
                    let local = friend_info_to_local(&info, &user_id);
                    (s.friend_user.user_id, (info, local))
                })
                .collect::<Vec<_>>();

            for (_uid, (_info, local)) in &server_friends {
                if let Err(e) = self.repositories.friend_repo.upsert(local).await {
                    warn!("缓存指定好友到 DB 失败 ({}): {}", _uid, e);
                }
                local_map.insert(_uid.clone(), (*local).clone());
            }
        }

        // 3. 按原始顺序组装结果
        let mut result: Vec<FriendInfo> = Vec::new();
        for uid in &friend_user_ids {
            if let Some(f) = local_map.remove(uid) {
                result.push(FriendInfo {
                    user_id: f.friend_user_id.clone(),
                    nickname: f.nickname.clone(),
                    face_url: f.face_url.clone(),
                    gender: 0,
                    remark: f.remark.clone(),
                    create_time: f.create_time,
                    add_source: f.add_source.to_string(),
                    ex: f.ex.clone(),
                });
            }
        }

        // 4. filterBlack 过滤
        if filter_black {
            let blacks = self.blacks.read().await;
            let black_set: HashSet<&String> = blacks.iter().collect();
            result.retain(|f| !black_set.contains(&f.user_id));
        }

        Ok(result)
    }

    /// 分页获取好友列表（对齐 Go SDK GetFriendListPage）
    ///
    /// 从本地 DB 按 is_pinned DESC, create_time DESC 排序分页获取。
    /// filterBlack=true 时过滤黑名单好友。
    pub async fn get_friend_list_page(
        &self,
        offset: i32,
        count: i32,
        filter_black: bool,
    ) -> Result<Vec<FriendInfo>> {
        let user_id = self.user_id.get().await;

        // 从本地 DB 获取全部好友（DAO 已按 is_pinned DESC, create_time DESC 排序）
        let all_local = self.repositories.friend_repo.get_all(&user_id).await?;

        // 可选过滤黑名单
        let filtered: Vec<&LocalFriend> = if filter_black {
            let blacks = self.blacks.read().await;
            let black_set: HashSet<&String> = blacks.iter().collect();
            all_local
                .iter()
                .filter(|f| !black_set.contains(&f.friend_user_id))
                .collect()
        } else {
            all_local.iter().collect()
        };

        // 分页
        let start = offset.max(0) as usize;
        let page: Vec<FriendInfo> = filtered
            .into_iter()
            .skip(start)
            .take(count.max(0) as usize)
            .map(|l| local_to_friend_info(l))
            .collect();

        Ok(page)
    }

    /// 批量更新好友信息（对齐 Go SDK UpdateFriends）
    ///
    /// 支持部分更新：is_pinned / remark / ex 为 None 时不修改对应字段。
    /// 更新成功后自动执行增量同步刷新本地数据。
    pub async fn update_friends(
        &self,
        friend_user_ids: Vec<String>,
        is_pinned: Option<bool>,
        remark: Option<String>,
        ex: Option<String>,
    ) -> Result<()> {
        let user_id = self.user_id.get().await;

        let req = UpdateFriendsReq {
            owner_user_id: user_id,
            friend_user_ids,
            is_pinned,
            remark,
            ex,
        };

        let _resp: serde_json::Value = self.http_client.post(UPDATE_FRIENDS, &req).await?;

        // 增量同步刷新本地好友列表
        if let Err(e) = self.sync_friends_incremental().await {
            warn!("UpdateFriends 后增量同步失败: {}", e);
        }

        info!("好友信息已批量更新");
        Ok(())
    }

    pub async fn add_friend(&self, user_id: String, req_msg: Option<String>) -> Result<()> {
        let from_user_id = self.user_id.get().await;
        let req = AddFriendReq {
            from_user_id,
            to_user_id: user_id.clone(),
            req_msg,
        };

        let _resp: serde_json::Value = self.http_client.post(ADD_FRIEND, &req).await?;

        info!("好友申请已发送: {}", user_id);
        Ok(())
    }

    pub async fn delete_friend(&self, user_id: String) -> Result<()> {
        let req = DeleteFriendReq {
            to_user_id: user_id.clone(),
        };

        let _resp: serde_json::Value = self.http_client.post(DELETE_FRIEND, &req).await?;

        self.friends.write().await.retain(|f| f.user_id != user_id);

        self.send(FriendEvent::Deleted(user_id.to_string()));

        info!("好友已删除: {}", user_id);
        Ok(())
    }

    pub async fn is_friend(&self, user_id: &str) -> bool {
        self.friends.read().await.iter().any(|f| f.user_id == user_id)
    }

    /// 批量检查好友关系状态（对齐 Go SDK CheckFriend）
    pub async fn check_friend(&self, user_ids: Vec<String>) -> Result<Vec<CheckFriendResult>> {
        let req = serde_json::json!({
            "userIDList": user_ids,
        });
        #[derive(Deserialize, Default)]
        struct CheckFriendResp {
            #[serde(rename = "resultInfo")]
            result_info: Vec<CheckFriendResult>,
        }
        let resp: CheckFriendResp = self.http_client.post(CHECK_FRIEND, &req).await?;
        Ok(resp.result_info)
    }

    pub async fn friend_count(&self) -> usize {
        self.friends.read().await.len()
    }

    pub async fn get_blacklist(&self) -> Vec<String> {
        self.blacks.read().await.clone()
    }

    pub async fn sync_blacks(&self) -> Result<()> {
        let resp: GetBlackListResp = self.http_client.post(GET_BLACK_LIST, &()).await?;

        let blacks: Vec<String> = resp.blacks_info.into_iter().map(|b| b.user_id).collect();

        *self.blacks.write().await = blacks.clone();

        info!("黑名单已同步, count={}", blacks.len());
        Ok(())
    }

    pub async fn add_black(&self, user_id: String) -> Result<()> {
        let req = AddBlackReq {
            to_user_id: user_id.clone(),
        };

        let _resp: serde_json::Value = self.http_client.post(ADD_BLACK, &req).await?;

        self.blacks.write().await.push(user_id.clone());

        self.send(FriendEvent::BlackAdded(user_id.to_string()));

        info!("已添加到黑名单: {}", user_id);
        Ok(())
    }

    pub async fn remove_black(&self, user_id: String) -> Result<()> {
        let req = RemoveBlackReq {
            to_user_id: user_id.clone(),
        };

        let _resp: serde_json::Value = self.http_client.post(REMOVE_BLACK, &req).await?;

        self.blacks.write().await.retain(|id| id != &user_id);

        self.send(FriendEvent::BlackDeleted(user_id.to_string()));

        info!("已从黑名单移除: {}", user_id);
        Ok(())
    }

    pub async fn is_in_blacklist(&self, user_id: &str) -> bool {
        self.blacks.read().await.iter().any(|id| id == user_id)
    }

    pub async fn get_friend_apply_list(&self) -> Result<GetFriendApplyListResp> {
        let user_id = self.user_id.get().await;
        let req = GetFriendApplyListReq {
            from_user_id: user_id,
            pagination: Pagination {
                page_number: 1,
                show_number: 1000,
            },
        };
        let resp: GetFriendApplyListResp = self.http_client.post(GET_FRIEND_APPLY_LIST, &req).await?;
        Ok(resp)
    }

    /// 获取自己发出的好友申请列表（对齐 Go SDK GetFriendApplicationListAsApplicant）
    pub async fn get_friend_apply_list_as_applicant(&self) -> Result<GetFriendApplyListResp> {
        let user_id = self.user_id.get().await;
        let req = GetFriendApplyListReq {
            from_user_id: user_id,
            pagination: Pagination {
                page_number: 1,
                show_number: 1000,
            },
        };
        let resp: GetFriendApplyListResp = self.http_client.post(GET_SELF_FRIEND_APPLY_LIST, &req).await?;
        Ok(resp)
    }

    /// 获取未处理的好友申请数量（对齐 Go SDK GetFriendApplicationUnhandledCount）
    pub async fn get_friend_application_unhandled_count(&self) -> Result<i32> {
        #[derive(Serialize)]
        struct UnhandledCountReq {
            user_id: String,
        }
        let user_id = self.user_id.get().await;
        let req = UnhandledCountReq { user_id };
        #[derive(Deserialize, Default)]
        struct UnhandledCountResp {
            count: i32,
        }
        let resp: UnhandledCountResp = self.http_client.post(GET_SELF_UNHANDLED_APPLY_COUNT, &req).await?;
        Ok(resp.count)
    }

    pub async fn accept_friend_application(&self, user_id: String, handle_msg: Option<String>) -> Result<()> {
        let req = AcceptFriendApplicationReq {
            to_user_id: user_id.clone(),
            handle_msg,
        };
        let _resp: serde_json::Value = self.http_client.post(ACCEPT_FRIEND_APPLICATION, &req).await?;

        // 对齐 Go SDK: 接受好友申请后同步好友列表（创建好友关系）
        if let Err(e) = self.sync_friends().await {
            tracing::warn!("接受好友申请后同步好友列表失败: {}", e);
        }

        info!("好友申请已接受: {}", user_id);
        Ok(())
    }

    pub async fn refuse_friend_application(&self, user_id: String, handle_msg: Option<String>) -> Result<()> {
        let req = RefuseFriendApplicationReq {
            to_user_id: user_id.clone(),
            handle_msg,
        };
        let _resp: serde_json::Value = self.http_client.post(REFUSE_FRIEND_APPLICATION, &req).await?;
        info!("好友申请已拒绝: {}", user_id);
        Ok(())
    }

    pub async fn clear(&self) {
        self.friends.write().await.clear();
        self.blacks.write().await.clear();
        info!("好友数据已清空");
    }
}

fn server_to_friend(s: FriendServerInfo) -> FriendInfo {
    FriendInfo {
        user_id: s.friend_user.user_id,
        nickname: s.friend_user.nickname,
        face_url: s.friend_user.face_url,
        gender: 0,
        remark: s.remark,
        create_time: s.create_time,
        add_source: s.add_source.to_string(),
        ex: s.friend_user.ex,
    }
}

fn friend_info_to_local(f: &FriendInfo, owner_user_id: &str) -> LocalFriend {
    LocalFriend {
        owner_user_id: owner_user_id.to_string(),
        friend_user_id: f.user_id.clone(),
        remark: f.remark.clone(),
        create_time: f.create_time,
        add_source: f.add_source.parse::<i32>().unwrap_or(0),
        operator_user_id: String::new(),
        nickname: f.nickname.clone(),
        face_url: f.face_url.clone(),
        ex: f.ex.clone(),
        attached_info: String::new(),
        is_pinned: 0,
    }
}

fn local_to_friend_info(l: &LocalFriend) -> FriendInfo {
    FriendInfo {
        user_id: l.friend_user_id.clone(),
        nickname: l.nickname.clone(),
        face_url: l.face_url.clone(),
        gender: 0,
        remark: l.remark.clone(),
        create_time: l.create_time,
        add_source: l.add_source.to_string(),
        ex: l.ex.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_server_to_friend_conversion() {
        let server = FriendServerInfo {
            owner_user_id: "owner_123".to_string(),
            remark: "My Friend".to_string(),
            create_time: 1234567890,
            friend_user: FriendUserInfo {
                user_id: "user_123".to_string(),
                nickname: "Test Friend".to_string(),
                face_url: "https://example.com/avatar.jpg".to_string(),
                ex: String::new(),
                create_time: 0,
            },
            add_source: 1,
            operator_user_id: "owner_123".to_string(),
            ex: String::new(),
            is_pinned: false,
        };

        let domain = server_to_friend(server);
        assert_eq!(domain.user_id, "user_123");
        assert_eq!(domain.nickname, "Test Friend");
        assert_eq!(domain.remark, "My Friend");
    }

    #[test]
    fn test_get_friend_list_req_serialization() {
        let req = GetFriendListReq {
            user_id: "test_user".to_string(),
            pagination: Pagination {
                page_number: 1,
                show_number: 100,
            },
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("pagination"));
        assert!(json.contains("pageNumber"));
    }

    #[test]
    fn test_add_friend_req_serialization() {
        let req = AddFriendReq {
            from_user_id: "user_123".to_string(),
            to_user_id: "user_456".to_string(),
            req_msg: Some("Hello!".to_string()),
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("toUserID"));
        assert!(json.contains("fromUserID"));
        assert!(json.contains("Hello!"));
    }

    #[test]
    fn test_add_black_req_serialization() {
        let req = AddBlackReq {
            to_user_id: "user_789".to_string(),
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("toUserID"));
        assert!(json.contains("user_789"));
    }
}


