//! 联系人（好友）同步模块
//!
//! 参考 Go SDK 中 internal/relation 的 IncrSyncFriends，实现本地好友表的增量同步，
//! 并通过 FriendListener 向上层发送联系人变更回调。

use anyhow::{Context, Result};
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tracing::{debug, error, info};
use uuid::Uuid;

use sea_orm::{
    sea_query::OnConflict, ColumnTrait, ConnectOptions, Database, DatabaseConnection, EntityTrait,
    QueryFilter, Set,
};

use crate::im::entities::local_friends;
use crate::im::conversation::LocalVersionSync;

/// 本地好友数据结构（与 Go 的 LocalFriend 字段基本对应）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LocalFriend {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "userID")]
    pub friend_user_id: String,
    #[serde(rename = "remark")]
    pub remark: String,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    #[serde(rename = "addSource")]
    pub add_source: i32,
    #[serde(rename = "operatorUserID")]
    pub operator_user_id: String,
    #[serde(rename = "nickname")]
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    #[serde(rename = "ex")]
    pub ex: String,
    #[serde(rename = "attachedInfo")]
    pub attached_info: String,
    #[serde(rename = "isPinned")]
    pub is_pinned: bool,
}

/// 好友同步器配置
pub struct FriendSyncerConfig {
    /// 用户 ID
    pub user_id: String,
    /// API 基础 URL
    pub api_base_url: String,
    /// Token
    pub token: String,
    /// 数据库路径（SQLite），与会话共用同一个文件即可
    pub db_path: String,
}

/// 好友增量同步响应（本地结构）
struct IncrementalFriendsResp {
    full: bool,
    version: u64,
    version_id: String,
    insert: Vec<LocalFriend>,
    update: Vec<LocalFriend>,
    delete: Vec<String>,
}

/// 好友监听器回调接口（类似 Go SDK 中 RelationListener 的一部分能力）
#[async_trait]
pub trait FriendListener: Send + Sync {
    /// 好友列表发生变更（新增或更新），参数为 JSON 数组字符串
    async fn on_friend_list_changed(&self, friends_json: String);

    /// 黑名单列表发生变更（全量同步结果），参数为 JSON 数组字符串
    async fn on_black_list_changed(&self, blacks_json: String);

    /// 好友申请列表发生变更（全量同步结果），参数为 JSON 数组字符串
    async fn on_friend_request_list_changed(&self, requests_json: String);
}

/// 默认空实现（无操作）
pub struct EmptyFriendListener;

#[async_trait]
impl FriendListener for EmptyFriendListener {
    async fn on_friend_list_changed(&self, _friends_json: String) {
        // 默认不做任何处理
    }

    async fn on_black_list_changed(&self, _blacks_json: String) {
        // 默认不做任何处理
    }

    async fn on_friend_request_list_changed(&self, _requests_json: String) {
        // 默认不做任何处理
    }
}

/// 好友同步器
pub struct FriendSyncer {
    config: FriendSyncerConfig,
    client: reqwest::Client,
    db: DatabaseConnection,
    /// 好友变更监听器
    listener: Arc<dyn FriendListener>,
}

impl FriendSyncer {
    /// 创建新的好友同步器（使用默认空监听器）
    pub async fn new(config: FriendSyncerConfig) -> Result<Self> {
        Self::with_listener(config, Arc::new(EmptyFriendListener)).await
    }

    /// 创建新的好友同步器（自定义监听器）
    pub async fn with_listener(
        config: FriendSyncerConfig,
        listener: Arc<dyn FriendListener>,
    ) -> Result<Self> {
        let db_url = config.db_path.clone();
        info!(
            "[FriendSync/DB] 创建好友同步器，用户ID: {}, SQLite数据库: {}",
            config.user_id, db_url
        );
        let mut opt = ConnectOptions::new(db_url.clone());
        opt.sqlx_logging(false);

        let db = Database::connect(opt)
            .await
            .context(format!("连接SQLite数据库失败: {}", db_url))?;

        let syncer = Self {
            client: reqwest::Client::new(),
            db: db.clone(),
            config,
            listener,
        };

        syncer.init_db().await?;
        Ok(syncer)
    }

    /// 初始化好友表结构
    async fn init_db(&self) -> Result<()> {
        use sea_orm::ConnectionTrait;

        info!("[FriendSync/DB] 初始化好友表结构");

        let sql = r#"
            CREATE TABLE IF NOT EXISTS local_friends (
                owner_user_id TEXT NOT NULL,
                friend_user_id TEXT NOT NULL,
                remark TEXT NOT NULL DEFAULT '',
                create_time INTEGER NOT NULL DEFAULT 0,
                add_source INTEGER NOT NULL DEFAULT 0,
                operator_user_id TEXT NOT NULL DEFAULT '',
                nickname TEXT NOT NULL DEFAULT '',
                face_url TEXT NOT NULL DEFAULT '',
                ex TEXT NOT NULL DEFAULT '',
                attached_info TEXT NOT NULL DEFAULT '',
                is_pinned INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (owner_user_id, friend_user_id)
            )
        "#;

        self.db
            .execute_unprepared(sql)
            .await
            .context("创建好友表失败")?;

        info!("[FriendSync/DB] 好友表初始化完成");
        Ok(())
    }

    /// 从数据库获取所有好友
    async fn get_all_friends(&self) -> Result<Vec<LocalFriend>> {
        let models = local_friends::Entity::find()
            .filter(local_friends::Column::OwnerUserId.eq(self.config.user_id.clone()))
            .all(&self.db)
            .await
            .context("查询好友列表失败")?;

        let friends: Vec<LocalFriend> = models
            .into_iter()
            .map(|m| LocalFriend {
                owner_user_id: m.owner_user_id,
                friend_user_id: m.friend_user_id,
                remark: m.remark,
                create_time: m.create_time,
                add_source: m.add_source,
                operator_user_id: m.operator_user_id,
                nickname: m.nickname,
                face_url: m.face_url,
                ex: m.ex,
                attached_info: m.attached_info,
                is_pinned: m.is_pinned != 0,
            })
            .collect();

        debug!(
            "[FriendSync/DB] 获取本地好友列表，共 {} 个好友",
            friends.len()
        );
        Ok(friends)
    }

    /// 获取本地所有好友的 userID 列表
    async fn get_all_friend_ids(&self) -> Result<Vec<String>> {
        let models = local_friends::Entity::find()
            .filter(local_friends::Column::OwnerUserId.eq(self.config.user_id.clone()))
            .all(&self.db)
            .await
            .context("查询好友ID列表失败")?;

        let ids = models
            .into_iter()
            .map(|m| m.friend_user_id)
            .collect::<Vec<_>>();
        debug!(
            "[FriendSync/DB] 获取本地好友ID列表，共 {} 个",
            ids.len()
        );
        Ok(ids)
    }

    /// 从数据库获取版本同步信息（tableName = local_friends）
    async fn get_version_sync(&self) -> Result<Option<LocalVersionSync>> {
        use crate::im::entities::local_version_sync::{Column, Entity};

        let model = Entity::find()
            .filter(Column::TableName.eq("local_friends"))
            .filter(Column::EntityId.eq(&self.config.user_id))
            .one(&self.db)
            .await
            .context("查询好友版本同步信息失败")?;

        Ok(model.map(|m| LocalVersionSync {
            table_name: m.table_name,
            entity_id: m.entity_id,
            version: m.version as u64,
            version_id: m.version_id,
        }))
    }

    /// 保存版本同步信息到数据库
    async fn save_version_sync(&self, version_sync: &LocalVersionSync) -> Result<()> {
        use crate::im::entities::local_version_sync::{ActiveModel, Column, Entity};

        let active = ActiveModel {
            table_name: Set(version_sync.table_name.clone()),
            entity_id: Set(version_sync.entity_id.clone()),
            version: Set(version_sync.version as i64),
            version_id: Set(version_sync.version_id.clone()),
        };

        Entity::insert(active)
            .on_conflict(
                OnConflict::columns([Column::TableName, Column::EntityId])
                    .update_columns([Column::Version, Column::VersionId])
                    .to_owned(),
            )
            .exec(&self.db)
            .await
            .context("保存好友版本同步信息失败")?;
        Ok(())
    }

    /// 插入或更新好友到数据库
    async fn upsert_friend(&self, f: &LocalFriend) -> Result<()> {
        use crate::im::entities::local_friends::ActiveModel;

        let active = ActiveModel {
            owner_user_id: Set(f.owner_user_id.clone()),
            friend_user_id: Set(f.friend_user_id.clone()),
            remark: Set(f.remark.clone()),
            create_time: Set(f.create_time),
            add_source: Set(f.add_source),
            operator_user_id: Set(f.operator_user_id.clone()),
            nickname: Set(f.nickname.clone()),
            face_url: Set(f.face_url.clone()),
            ex: Set(f.ex.clone()),
            attached_info: Set(f.attached_info.clone()),
            is_pinned: Set(if f.is_pinned { 1 } else { 0 }),
        };

        local_friends::Entity::insert(active)
            .on_conflict(
                OnConflict::columns([
                    local_friends::Column::OwnerUserId,
                    local_friends::Column::FriendUserId,
                ])
                .update_columns([
                    local_friends::Column::Remark,
                    local_friends::Column::CreateTime,
                    local_friends::Column::AddSource,
                    local_friends::Column::OperatorUserId,
                    local_friends::Column::Nickname,
                    local_friends::Column::FaceUrl,
                    local_friends::Column::Ex,
                    local_friends::Column::AttachedInfo,
                    local_friends::Column::IsPinned,
                ])
                .to_owned(),
            )
            .exec(&self.db)
            .await
            .context("插入或更新好友失败")?;
        Ok(())
    }

    /// 从数据库删除好友
    async fn delete_friend(&self, friend_user_id: &str) -> Result<()> {
        use sea_orm::QueryFilter;

        local_friends::Entity::delete_many()
            .filter(local_friends::Column::OwnerUserId.eq(self.config.user_id.clone()))
            .filter(local_friends::Column::FriendUserId.eq(friend_user_id))
            .exec(&self.db)
            .await
            .context("删除好友失败")?;
        Ok(())
    }

    /// 将 JSON 对象转换为本地好友结构
    fn json_to_local_friend(v: &serde_json::Value) -> Option<LocalFriend> {
        Some(LocalFriend {
            owner_user_id: v
                .get("ownerUserID")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            friend_user_id: v
                .get("friendUserID")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            remark: v
                .get("remark")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            create_time: v
                .get("createTime")
                .and_then(|v| v.as_i64())
                .unwrap_or(0),
            add_source: v
                .get("addSource")
                .and_then(|v| v.as_i64())
                .map(|v| v as i32)
                .unwrap_or(0),
            operator_user_id: v
                .get("operatorUserID")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            nickname: v
                .get("friendNickname")
                .or_else(|| v.get("nickname"))
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            face_url: v
                .get("friendFaceURL")
                .or_else(|| v.get("faceURL"))
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            ex: v
                .get("ex")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            attached_info: v
                .get("attachedInfo")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            is_pinned: v
                .get("isPinned")
                .and_then(|v| v.as_bool())
                .unwrap_or(false),
        })
    }

    /// 从服务器获取增量好友
    async fn get_incremental_friends_from_server(
        &self,
        version: u64,
        version_id: &str,
    ) -> Result<IncrementalFriendsResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/friend/get_incremental_friends", self.config.api_base_url);

        let req_json = serde_json::json!({
            "userID": self.config.user_id,
            "version": version,
            "versionID": version_id,
        });

        info!("[FriendSync/HTTP] 📡 请求增量好友同步");
        debug!("[FriendSync/HTTP]   请求URL: {}", url);
        debug!("[FriendSync/HTTP]   用户ID: {}", self.config.user_id);
        debug!("[FriendSync/HTTP]   操作ID: {}", operation_id);

        let response = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await
            .context("请求失败")?;

        let status = response.status();
        if !status.is_success() {
            let text = response.text().await.unwrap_or_default();
            error!(
                "[FriendSync/HTTP] 增量好友同步请求失败，HTTP状态: {}, 响应: {}",
                status, text
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        debug!(
            "[FriendSync/HTTP] 增量好友同步请求成功，HTTP状态: {}",
            status
        );

        let text = response.text().await.context("读取响应失败")?;
        let json_value: serde_json::Value =
            serde_json::from_str(&text).context("解析 JSON 失败")?;

        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value
                    .get("errMsg")
                    .and_then(|v| v.as_str())
                    .unwrap_or("未知错误");
                error!(
                    "[FriendSync/HTTP] 增量好友同步服务器错误，错误码: {}, 错误信息: {}",
                    err_code, err_msg
                );
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        let data = json_value
            .get("data")
            .ok_or_else(|| anyhow::anyhow!("响应中缺少 data 字段"))?;

        let version_id_str = data
            .get("versionID")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        let version_value = data.get("version").and_then(|v| v.as_u64()).unwrap_or(0);

        let inserts: Vec<LocalFriend> = data
            .get("insert")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(Self::json_to_local_friend)
                    .collect()
            })
            .unwrap_or_default();

        let updates: Vec<LocalFriend> = data
            .get("update")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(Self::json_to_local_friend)
                    .collect()
            })
            .unwrap_or_default();

        let deletes: Vec<String> = data
            .get("delete")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str().map(|s| s.to_string()))
                    .collect()
            })
            .unwrap_or_default();

        let full = data
            .get("full")
            .and_then(|v| v.as_bool())
            .unwrap_or(false);

        info!("[FriendSync/HTTP] ✅ 增量好友同步响应");
        info!(
            "[FriendSync/HTTP]   全量同步: {}, 版本ID: {}, 版本: {}",
            full, version_id_str, version_value
        );
        info!(
            "[FriendSync/HTTP]   新增: {} 个, 更新: {} 个, 删除: {} 个",
            inserts.len(),
            updates.len(),
            deletes.len()
        );

        Ok(IncrementalFriendsResp {
            full,
            version: version_value,
            version_id: version_id_str,
            insert: inserts,
            update: updates,
            delete: deletes,
        })
    }

    /// 从服务器获取全量好友 userID 列表
    async fn get_full_friend_user_ids_from_server(
        &self,
    ) -> Result<(u64, String, Vec<String>)> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!(
            "{}/friend/get_full_friend_user_ids",
            self.config.api_base_url
        );

        // 对应 GetFullFriendUserIDsReq：idHash 暂时固定为 0
        let req_json = serde_json::json!({
            "userID": self.config.user_id,
            "idHash": 0u64,
        });

        info!("[FriendSync/HTTP] 📡 请求全量好友ID列表");
        debug!("[FriendSync/HTTP]   请求URL: {}", url);
        debug!("[FriendSync/HTTP]   用户ID: {}", self.config.user_id);
        debug!("[FriendSync/HTTP]   操作ID: {}", operation_id);

        let response = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await
            .context("请求失败")?;

        let status = response.status();
        if !status.is_success() {
            let text = response.text().await.unwrap_or_default();
            error!(
                "[FriendSync/HTTP] 全量好友ID列表请求失败，HTTP状态: {}, 响应: {}",
                status, text
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        debug!(
            "[FriendSync/HTTP] 全量好友ID列表请求成功，HTTP状态: {}",
            status
        );

        let text = response.text().await.context("读取响应失败")?;
        let json_value: serde_json::Value =
            serde_json::from_str(&text).context("解析 JSON 失败")?;

        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value
                    .get("errMsg")
                    .and_then(|v| v.as_str())
                    .unwrap_or("未知错误");
                error!(
                    "[FriendSync/HTTP] 全量好友ID服务器错误，错误码: {}, 错误信息: {}",
                    err_code, err_msg
                );
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        let data = json_value
            .get("data")
            .ok_or_else(|| anyhow::anyhow!("响应中缺少 data 字段"))?;

        let version = data
            .get("version")
            .and_then(|v| v.as_u64())
            .unwrap_or(0);
        let version_id = data
            .get("versionID")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let user_ids: Vec<String> = data
            .get("userIDs")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str().map(|s| s.to_string()))
                    .collect()
            })
            .unwrap_or_default();

        info!("[FriendSync/HTTP] ✅ 全量好友ID列表响应");
        info!(
            "[FriendSync/HTTP]   版本: {}, 版本ID: {}，好友数: {}",
            version,
            version_id,
            user_ids.len()
        );

        Ok((version, version_id, user_ids))
    }

    /// 从服务器获取全量好友列表（简单分页版）
    async fn get_all_friends_from_server(&self) -> Result<Vec<LocalFriend>> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!(
            "{}/friend/get_friend_list",
            self.config.api_base_url
        );

        // 使用较大的分页大小，简单获取完整列表
        let req_json = serde_json::json!({
            "userID": self.config.user_id,
            "pagination": {
                "pageNumber": 1,
                "showNumber": 1000
            }
        });

        info!("[FriendSync/HTTP] 📡 请求全量好友列表");
        debug!("[FriendSync/HTTP]   请求URL: {}", url);
        debug!("[FriendSync/HTTP]   用户ID: {}", self.config.user_id);
        debug!("[FriendSync/HTTP]   操作ID: {}", operation_id);

        let response = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await
            .context("请求失败")?;

        let status = response.status();
        if !status.is_success() {
            let text = response.text().await.unwrap_or_default();
            error!(
                "[FriendSync/HTTP] 全量好友列表请求失败，HTTP状态: {}, 响应: {}",
                status, text
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        debug!(
            "[FriendSync/HTTP] 全量好友列表请求成功，HTTP状态: {}",
            status
        );

        let text = response.text().await.context("读取响应失败")?;
        let json_value: serde_json::Value =
            serde_json::from_str(&text).context("解析 JSON 失败")?;

        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value
                    .get("errMsg")
                    .and_then(|v| v.as_str())
                    .unwrap_or("未知错误");
                error!(
                    "[FriendSync/HTTP] 全量好友列表服务器错误，错误码: {}, 错误信息: {}",
                    err_code, err_msg
                );
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        let data = json_value
            .get("data")
            .ok_or_else(|| anyhow::anyhow!("响应中缺少 data 字段"))?;

        let friends: Vec<LocalFriend> = data
            .get("friendsInfo")
            .or_else(|| data.get("friends_info"))
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(Self::json_to_local_friend)
                    .collect()
            })
            .unwrap_or_default();

        info!(
            "[FriendSync/HTTP] ✅ 全量好友列表响应，好友数: {}",
            friends.len()
        );

        Ok(friends)
    }

    /// 从服务器获取黑名单列表（全量）
    async fn get_black_list_from_server(&self) -> Result<serde_json::Value> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!(
            "{}/friend/get_black_list",
            self.config.api_base_url
        );

        let req_json = serde_json::json!({
            "userID": self.config.user_id,
            "pagination": {
                "pageNumber": 1,
                "showNumber": 1000
            }
        });

        info!("[FriendSync/HTTP] 📡 请求黑名单列表");
        debug!("[FriendSync/HTTP]   请求URL: {}", url);
        debug!("[FriendSync/HTTP]   用户ID: {}", self.config.user_id);
        debug!("[FriendSync/HTTP]   操作ID: {}", operation_id);

        let response = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await
            .context("请求失败")?;

        let status = response.status();
        if !status.is_success() {
            let text = response.text().await.unwrap_or_default();
            error!(
                "[FriendSync/HTTP] 黑名单列表请求失败，HTTP状态: {}, 响应: {}",
                status, text
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        debug!(
            "[FriendSync/HTTP] 黑名单列表请求成功，HTTP状态: {}",
            status
        );

        let text = response.text().await.context("读取响应失败")?;
        let json_value: serde_json::Value =
            serde_json::from_str(&text).context("解析 JSON 失败")?;

        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value
                    .get("errMsg")
                    .and_then(|v| v.as_str())
                    .unwrap_or("未知错误");
                error!(
                    "[FriendSync/HTTP] 黑名单列表服务器错误，错误码: {}, 错误信息: {}",
                    err_code, err_msg
                );
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        let data = json_value
            .get("data")
            .ok_or_else(|| anyhow::anyhow!("响应中缺少 data 字段"))?;

        let blacks = data
            .get("blacks")
            .cloned()
            .unwrap_or_else(|| serde_json::Value::Array(vec![]));

        info!(
            "[FriendSync/HTTP] ✅ 黑名单列表响应，条目数: {}",
            blacks.as_array().map(|a| a.len()).unwrap_or(0)
        );

        Ok(blacks)
    }

    /// 从服务器获取好友申请列表（全量，查看「别人发给我的」申请）
    async fn get_friend_requests_from_server(&self) -> Result<serde_json::Value> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!(
            "{}/friend/get_friend_apply_list",
            self.config.api_base_url
        );

        let req_json = serde_json::json!({
            "userID": self.config.user_id,
            "pagination": {
                "pageNumber": 1,
                "showNumber": 100
            }
        });

        info!("[FriendSync/HTTP] 📡 请求好友申请列表");
        debug!("[FriendSync/HTTP]   请求URL: {}", url);
        debug!("[FriendSync/HTTP]   用户ID: {}", self.config.user_id);
        debug!("[FriendSync/HTTP]   操作ID: {}", operation_id);

        let response = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .header("token", &self.config.token)
            .json(&req_json)
            .send()
            .await
            .context("请求失败")?;

        let status = response.status();
        if !status.is_success() {
            let text = response.text().await.unwrap_or_default();
            error!(
                "[FriendSync/HTTP] 好友申请列表请求失败，HTTP状态: {}, 响应: {}",
                status, text
            );
            return Err(anyhow::anyhow!("HTTP 错误 {}: {}", status, text));
        }
        debug!(
            "[FriendSync/HTTP] 好友申请列表请求成功，HTTP状态: {}",
            status
        );

        let text = response.text().await.context("读取响应失败")?;
        let json_value: serde_json::Value =
            serde_json::from_str(&text).context("解析 JSON 失败")?;

        if let Some(err_code) = json_value.get("errCode").and_then(|v| v.as_i64()) {
            if err_code != 0 {
                let err_msg = json_value
                    .get("errMsg")
                    .and_then(|v| v.as_str())
                    .unwrap_or("未知错误");
                error!(
                    "[FriendSync/HTTP] 好友申请列表服务器错误，错误码: {}, 错误信息: {}",
                    err_code, err_msg
                );
                return Err(anyhow::anyhow!("服务器错误 {}: {}", err_code, err_msg));
            }
        }

        let data = json_value
            .get("data")
            .ok_or_else(|| anyhow::anyhow!("响应中缺少 data 字段"))?;

        let requests = data
            .get("friendRequests")
            .cloned()
            .unwrap_or_else(|| serde_json::Value::Array(vec![]));

        info!(
            "[FriendSync/HTTP] ✅ 好友申请列表响应，条目数: {}",
            requests.as_array().map(|a| a.len()).unwrap_or(0)
        );

        Ok(requests)
    }

    /// 同步好友列表（对比服务器和本地数据）
    async fn sync_friends(
        &self,
        server_friends: Vec<LocalFriend>,
        local_friends: Vec<LocalFriend>,
        is_full: bool,
    ) -> Result<()> {
        info!(
            "[FriendSync] 开始同步好友，服务器好友数: {}, 本地好友数: {}",
            server_friends.len(),
            local_friends.len()
        );

        let local_map: HashMap<String, LocalFriend> = local_friends
            .into_iter()
            .map(|f| (f.friend_user_id.clone(), f))
            .collect();
        let server_map: HashMap<String, LocalFriend> = server_friends
            .into_iter()
            .map(|f| (f.friend_user_id.clone(), f))
            .collect();

        let mut insert_count = 0;
        let mut update_count = 0;
        let mut delete_count = 0;

        // 插入或更新
        for (id, server_friend) in server_map.iter() {
            if let Some(local_friend) = local_map.get(id) {
                if !Self::friends_equal(local_friend, server_friend) {
                    info!("[FriendSync]   更新好友: {}", id);
                    self.upsert_friend(server_friend).await?;
                    update_count += 1;
                } else {
                    debug!("[FriendSync]   好友 {} 无需更新", id);
                }
            } else {
                info!("[FriendSync]   新增好友: {}", id);
                self.upsert_friend(server_friend).await?;
                insert_count += 1;
            }
        }

        // 删除：当 is_full=true 时，服务器列表视为权威，删除本地多余好友
        if is_full {
            let local_ids: std::collections::HashSet<String> =
                local_map.keys().cloned().collect();
            let server_ids: std::collections::HashSet<String> =
                server_map.keys().cloned().collect();
            for id in local_ids.difference(&server_ids) {
                info!("[FriendSync]   删除本地多余好友: {}", id);
                self.delete_friend(id).await?;
                delete_count += 1;
            }
        }

        // 触发好友变更回调（新增或更新的好友）
        if insert_count > 0 || update_count > 0 {
            let mut changed = Vec::new();
            // 这里使用 server_map 中的值即可（已是最新状态）
            for (id, friend) in server_map.iter() {
                if local_map.get(id).is_none() {
                    // 新增
                    changed.push(friend.clone());
                } else if !Self::friends_equal(local_map.get(id).unwrap(), friend) {
                    // 更新
                    changed.push(friend.clone());
                }
            }

            if !changed.is_empty() {
                if let Ok(json) = serde_json::to_string(&changed) {
                    self.listener.on_friend_list_changed(json).await;
                }
            }
        }

        info!(
            "[FriendSync] 好友同步完成 - 新增: {}, 更新: {}, 删除: {}",
            insert_count, update_count, delete_count
        );
        Ok(())
    }

    /// 比较两个好友是否相等（用于判断是否需要更新）
    fn friends_equal(local: &LocalFriend, server: &LocalFriend) -> bool {
        local.remark == server.remark
            && local.add_source == server.add_source
            && local.operator_user_id == server.operator_user_id
            && local.nickname == server.nickname
            && local.face_url == server.face_url
            && local.ex == server.ex
            && local.attached_info == server.attached_info
            && local.is_pinned == server.is_pinned
    }

    /// 增量同步好友列表
    pub async fn incr_sync_friends(&self) -> Result<()> {
        info!("[FriendSync] 🔄 开始增量同步好友...");

        let version_sync = self.get_version_sync().await?;

        if let Some(ref vs) = version_sync {
            debug!(
                "[FriendSync] 本地好友版本信息 - 版本: {}, 版本ID: {}",
                vs.version, vs.version_id
            );
        } else {
            debug!("[FriendSync] 本地无好友版本信息");
        }

        let local_friends = self.get_all_friends().await?;
        let local_ids = self.get_all_friend_ids().await?;

        // 如果本地没有版本信息，先用全量好友ID列表与本地做一次对比，必要时执行全量同步
        if version_sync.is_none() {
            if let Ok((srv_version, srv_version_id, server_ids)) =
                self.get_full_friend_user_ids_from_server().await
            {
                let server_set: std::collections::HashSet<String> =
                    server_ids.iter().cloned().collect();
                let local_set: std::collections::HashSet<String> =
                    local_ids.iter().cloned().collect();

                if server_set != local_set {
                    info!(
                        "[FriendSync] 好友ID列表与服务器不一致，执行全量好友同步..."
                    );

                    // 全量拉取好友列表并对齐
                    let server_friends = self.get_all_friends_from_server().await?;
                    self.sync_friends(server_friends, local_friends, true).await?;

                    // 以 full friend IDs 的版本信息为起点写入 version_sync
                    let new_version_sync = LocalVersionSync {
                        table_name: "local_friends".to_string(),
                        entity_id: self.config.user_id.clone(),
                        version: srv_version,
                        version_id: srv_version_id.clone(),
                    };
                    self.save_version_sync(&new_version_sync).await?;
                    info!(
                        "[FriendSync] 已通过全量好友同步初始化版本信息 - 版本: {}, 版本ID: {}",
                        new_version_sync.version, new_version_sync.version_id
                    );

                    info!("[FriendSync] ✅ 全量好友同步完成");
                    return Ok(());
                } else {
                    debug!("[FriendSync] 好友ID列表与服务器一致，直接使用增量同步");

                    // 如果服务器有合法的版本信息，也可以在这里初始化本地 version_sync
                    if srv_version > 0 && !srv_version_id.is_empty() {
                        let new_version_sync = LocalVersionSync {
                            table_name: "local_friends".to_string(),
                            entity_id: self.config.user_id.clone(),
                            version: srv_version,
                            version_id: srv_version_id.clone(),
                        };
                        self.save_version_sync(&new_version_sync).await?;
                        info!(
                            "[FriendSync] 通过全量ID列表初始化版本信息 - 版本: {}, 版本ID: {}",
                            new_version_sync.version, new_version_sync.version_id
                        );
                    }
                }
            } else {
                debug!(
                    "[FriendSync] 获取全量好友ID列表失败，将直接尝试增量同步"
                );
            }
        }

        // 继续增量同步路径
        let (version, version_id) = if let Some(vs) = version_sync {
            (vs.version, vs.version_id)
        } else {
            (0, "".to_string())
        };

        let resp = match self
            .get_incremental_friends_from_server(version, &version_id)
            .await
        {
            Ok(resp) => resp,
            Err(e) => {
                error!("[FriendSync] 增量好友同步失败: {}", e);
                return Err(e);
            }
        };

        // 如果服务器标记 full=true，则以服务器为权威做一次全量对齐
        if resp.full {
            info!("[FriendSync] 服务器要求全量好友同步...");
            let server_friends = self.get_all_friends_from_server().await?;
            self.sync_friends(server_friends, local_friends, true).await?;

            if !resp.version_id.is_empty() {
                let new_version = if resp.version > 0 {
                    resp.version
                } else {
                    version + 1
                };
                let new_version_sync = LocalVersionSync {
                    table_name: "local_friends".to_string(),
                    entity_id: self.config.user_id.clone(),
                    version: new_version,
                    version_id: resp.version_id.clone(),
                };
                self.save_version_sync(&new_version_sync).await?;
                info!(
                    "[FriendSync] 全量好友同步后更新版本信息 - 版本: {} -> {}, 版本ID: {}",
                    version, new_version_sync.version, new_version_sync.version_id
                );
            }

            info!("[FriendSync] ✅ 全量好友同步完成");
            return Ok(());
        }

        // 处理 insert/update（增量）
        let mut server_friends = Vec::new();
        server_friends.extend(resp.insert.into_iter());
        server_friends.extend(resp.update.into_iter());

        self.sync_friends(server_friends, local_friends, false).await?;

        // 处理删除
        if !resp.delete.is_empty() {
            info!(
                "[FriendSync] 处理删除好友，数量: {}",
                resp.delete.len()
            );
            for id in resp.delete.iter() {
                info!("[FriendSync]   删除好友: {}", id);
                self.delete_friend(id).await?;
            }
        }

        // 更新版本信息
        if !resp.version_id.is_empty() {
            let new_version = if resp.version > 0 {
                resp.version
            } else {
                version + 1
            };
            let new_version_sync = LocalVersionSync {
                table_name: "local_friends".to_string(),
                entity_id: self.config.user_id.clone(),
                version: new_version,
                version_id: resp.version_id.clone(),
            };
            self.save_version_sync(&new_version_sync).await?;
            info!(
                "[FriendSync] 已更新好友版本信息 - 版本: {} -> {}, 版本ID: {}",
                version, new_version_sync.version, new_version_sync.version_id
            );
        }

        info!("[FriendSync] ✅ 增量同步好友完成");

        // 增量好友同步完成后，顺带同步一次黑名单和好友申请列表，触发对应监听器
        if let Ok(blacks) = self.get_black_list_from_server().await {
            let json = blacks.to_string();
            self.listener.on_black_list_changed(json).await;
        }

        if let Ok(requests) = self.get_friend_requests_from_server().await {
            let json = requests.to_string();
            self.listener.on_friend_request_list_changed(json).await;
        }

        Ok(())
    }
}


