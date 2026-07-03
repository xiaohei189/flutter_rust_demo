use serde::Deserializer;

use crate::domain::error::types::{Result, SdkError};
use crate::domain::listener::conversation::ConversationListener;
use crate::domain::model::conversation::Conversation;
use crate::infra::database::conversation_dao::ConversationDao;
use crate::infra::database::sync_version_dao::SyncVersionDao;
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{
    GET_ALL_CONVERSATION_LIST, GET_CONVERSATIONS, GET_FULL_CONVERSATION_IDS,
    GET_INCREMENTAL_CONVERSATION,
};

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn, error};
use serde::{Deserialize, Serialize};

// ========== 常量 ==========

/// 版本同步表名（对齐 Go SDK `model_struct.LocalConversation{}.TableName()`）
const CONVERSATION_TABLE_NAME: &str = "local_conversations";

// ========== Request/Response Structs ==========

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetAllConversationsReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetAllConversationsResp {
    #[serde(default)]
    pub conversations: Option<Vec<ServerConversation>>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetIncrementalConversationReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub version: u64,
}

/// serde 反序列化辅助：将 JSON null 视为 Default（空 Vec 等）
fn deserialize_null_default<'de, D, T>(d: D) -> std::result::Result<T, D::Error>
where
    D: Deserializer<'de>,
    T: Default + Deserialize<'de>,
{
    Option::<T>::deserialize(d).map(|x| x.unwrap_or_default())
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetIncrementalConversationResp {
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub full: bool,
    #[serde(default, deserialize_with = "deserialize_null_default")]
    pub delete: Vec<String>,
    #[serde(default, deserialize_with = "deserialize_null_default")]
    pub insert: Vec<ServerConversation>,
    #[serde(default, deserialize_with = "deserialize_null_default")]
    pub update: Vec<ServerConversation>,
}

/// 按 ID 查询会话的请求（对齐 Go SDK `getConversationsByIDsFromServer`）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetConversationsByIDsReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "conversationIDs")]
    pub conversation_ids: Vec<String>,
}

/// 按 ID 查询会话的响应
#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetConversationsByIDsResp {
    #[serde(default)]
    pub conversations: Option<Vec<ServerConversation>>,
}

/// 获取所有会话 ID 的请求（对齐 Go SDK `getAllConversationIDsFromServer`）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFullConversationIDsReq {
    #[serde(rename = "userID")]
    pub user_id: String,
}

/// 获取所有会话 ID 的响应（对齐 Go SDK `GetFullOwnerConversationIDsResp`）
#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetFullConversationIDsResp {
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub equal: bool,
    #[serde(default, rename = "conversationIDs", deserialize_with = "deserialize_null_default")]
    pub conversation_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct ServerConversation {
    #[serde(rename = "ownerUserID", default)]
    pub owner_user_id: String,
    #[serde(rename = "conversationID", default)]
    pub conversation_id: String,
    #[serde(rename = "conversationType")]
    pub conversation_type: i32,
    #[serde(rename = "recvMsgOpt")]
    pub recv_msg_opt: i32,
    #[serde(rename = "userID", default)]
    pub user_id: String,
    #[serde(rename = "groupID", default)]
    pub group_id: String,
    #[serde(rename = "isPinned")]
    pub is_pinned: bool,
    #[serde(rename = "isPrivateChat")]
    pub is_private_chat: bool,
    #[serde(rename = "groupAtType")]
    pub group_at_type: i32,
    #[serde(default)]
    pub ex: String,
    #[serde(rename = "attachedInfo", default)]
    pub attached_info: String,
    #[serde(rename = "burnDuration")]
    pub burn_duration: i32,
    #[serde(rename = "minSeq")]
    pub min_seq: i64,
    #[serde(rename = "maxSeq")]
    pub max_seq: i64,
    #[serde(rename = "msgDestructTime")]
    pub msg_destruct_time: i64,
    #[serde(rename = "isMsgDestruct")]
    pub is_msg_destruct: bool,
}

fn server_to_domain(s: ServerConversation) -> Conversation {
    Conversation {
        conversation_id: s.conversation_id,
        conversation_type: s.conversation_type,
        user_id: s.user_id,
        group_id: s.group_id,
        show_name: String::new(),
        face_url: String::new(),
        recv_msg_opt: s.recv_msg_opt,
        unread_count: 0,
        group_at_type: s.group_at_type,
        latest_msg_seq: s.max_seq,
        latest_msg: String::new(),
        latest_msg_send_time: 0,
        draft_text: String::new(),
        draft_text_time: 0,
        is_pinned: s.is_pinned,
        is_private_chat: s.is_private_chat,
        is_not_in_group: false,
        update_flag: 0,
        sync_action: None,
        update_unread_count_time: 0,
        max_seq: s.max_seq,
        min_seq: s.min_seq,
        is_msg_destruct: s.is_msg_destruct,
        msg_destruct_time: s.msg_destruct_time,
        is_private: s.is_private_chat,
        burn_duration: s.burn_duration,
        ex: s.ex,
    }
}

pub struct ConversationSyncer {
    http_client: Arc<HttpApiClient>,
    dao: Arc<ConversationDao>,
    conversation_listener: Arc<ConversationListener>,
    sync_version_dao: Arc<SyncVersionDao>,
    user_id: Arc<RwLock<String>>,
    /// WebSocket 连接管理器（用于 sync_conversation_hash_read_seqs 的 RPC 调用）
    connection: Option<Arc<crate::core::connection::manager::ConnectionManager>>,
    /// 增量同步互斥锁（对齐 Go SDK `conversationSyncMutex`）
    sync_mutex: tokio::sync::Mutex<()>,
}

impl ConversationSyncer {
    pub fn new(
        http_client: Arc<HttpApiClient>,
        dao: Arc<ConversationDao>,
        conversation_listener: Arc<ConversationListener>,
        sync_version_dao: Arc<SyncVersionDao>,
        user_id: String,
    ) -> Self {
        Self {
            http_client,
            dao,
            conversation_listener,
            sync_version_dao,
            user_id: Arc::new(RwLock::new(user_id)),
            connection: None,
            sync_mutex: tokio::sync::Mutex::new(()),
        }
    }

    /// 设置 WebSocket 连接管理器（用于 Hash Read Seq 同步）
    pub fn set_connection(&mut self, connection: Arc<crate::core::connection::manager::ConnectionManager>) {
        self.connection = Some(connection);
    }

    pub async fn set_user_id(&self, user_id: String) {
        let mut uid = self.user_id.write().await;
        *uid = user_id;
    }

    // ========================================================================
    // 增量同步（对齐 Go SDK `IncrSyncConversations` + `VersionSynchronizer`）
    // ========================================================================

    /// 增量同步会话（版本号持久化到数据库，对齐 Go SDK `VersionSynchronizer.IncrementalSync`）
    pub async fn sync_incremental(&self) -> Result<Vec<Conversation>> {
        let user_id = self.user_id.read().await.clone();

        // 1. 从数据库获取本地版本信息（对齐 Go SDK `getVersionInfo`）
        let (local_version_id, local_version) = match self
            .sync_version_dao
            .get_version_sync(CONVERSATION_TABLE_NAME, &user_id)
            .await?
        {
            Some((vid, v)) => (vid, v),
            None => (String::new(), 0),
        };

        info!(
            "开始增量同步会话，版本: {}, version_id: {}",
            local_version, local_version_id
        );

        // 注意：不发布 SyncStarted/SyncFinished 事件，避免与 MessageSyncer 冲突
        // 会话变化通过 ConversationChanged/ConversationDeleted 事件单独通知

        // 2. 请求增量数据
        let resp = match self
            .pull_incremental(local_version, &local_version_id)
            .await
        {
            Ok(r) => r,
            Err(e) => {
                return Err(e);
            }
        };

        // 3. 如果服务端返回 full=true，回退到全量同步（对齐 Go SDK `FullSyncer`）
        if resp.full {
            info!("增量同步返回 full=true，执行全量同步");
            return self.sync_full().await;
        }

        // 4. 处理增量变更
        for conv_id in &resp.delete {
            self.dao.delete(conv_id).await?;
            self.conversation_listener.on_deleted.notify(&vec![conv_id.clone()]);
        }

        for s in &resp.update {
            let domain = server_to_domain(s.clone());
            let local = crate::core::conversation::manager::domain_to_local(domain);
            self.dao.upsert_preserving_local_fields(&local).await?;
        }

        for s in &resp.insert {
            let domain = server_to_domain(s.clone());
            let local = crate::core::conversation::manager::domain_to_local(domain);
            self.dao.upsert_preserving_local_fields(&local).await?;
        }

        if !resp.update.is_empty() || !resp.insert.is_empty() {
            let changed: Vec<Conversation> = resp
                .update
                .iter()
                .chain(resp.insert.iter())
                .map(|s| server_to_domain(s.clone()))
                .collect();
            self.conversation_listener.on_changed.notify(&changed);
        }

        // 5. 持久化版本号到数据库（对齐 Go SDK `updateVersionInfo`）
        if let Err(e) = self
            .sync_version_dao
            .set_version_sync(
                CONVERSATION_TABLE_NAME,
                &user_id,
                &resp.version_id,
                resp.version,
            )
            .await
        {
            warn!("更新会话同步版本失败: {}", e);
        }

        info!(
            "增量同步完成，insert={}, update={}, delete={}",
            resp.insert.len(),
            resp.update.len(),
            resp.delete.len()
        );

        let inserted_convs: Vec<Conversation> =
            resp.insert.iter().map(|s| server_to_domain(s.clone())).collect();
        Ok(inserted_convs)
    }

    /// 加锁版本的增量同步（对齐 Go SDK `IncrSyncConversationsWithLock`）
    pub async fn sync_incremental_with_lock(&self) -> Result<Vec<Conversation>> {
        let _guard = self.sync_mutex.lock().await;
        self.sync_incremental().await
    }

    // ========================================================================
    // 全量同步
    // ========================================================================

    pub async fn sync_full(&self) -> Result<Vec<Conversation>> {
        info!("开始全量同步会话");

        let resp = match self.pull_all().await {
            Ok(r) => r,
            Err(e) => {
                return Err(e);
            }
        };

        let conversations: Vec<Conversation> = resp
            .conversations
            .unwrap_or_default()
            .into_iter()
            .map(server_to_domain)
            .collect();

        // 保留本地 latest_msg 等字段：先记录本地所有会话 ID
        let local_ids: std::collections::HashSet<String> = self
            .dao
            .get_all()
            .await
            .unwrap_or_default()
            .into_iter()
            .map(|lc| lc.conversation_id)
            .collect();

        // 使用保留本地字段的 upsert 方法插入所有服务端会话
        for conv in &conversations {
            let local = crate::core::conversation::manager::domain_to_local(conv.clone());
            self.dao.upsert_preserving_local_fields(&local).await?;
        }

        // 删除服务端不再返回的会话（即本地存在但服务端不存在的）
        let server_ids: std::collections::HashSet<String> = conversations
            .iter()
            .map(|c| c.conversation_id.clone())
            .collect();
        for local_id in &local_ids {
            if !server_ids.contains(local_id) {
                self.dao.delete(local_id).await?;
            }
        }

        self.conversation_listener.on_changed.notify(&conversations);

        info!("全量同步完成，同步 {} 个会话", conversations.len());

        if let Ok(count) = self.dao.count().await {
            self.conversation_listener.on_total_unread_count_changed.notify(&(count as i64));
        }

        Ok(conversations)
    }

    // ========================================================================
    // Hash Read Seq 同步（对齐 Go SDK `SyncAllConversationHashReadSeqs`）
    // ========================================================================

    /// 从服务端同步所有会话的 maxSeq 和 hasReadSeq（对齐 Go SDK `sync.go:11-151`）
    ///
    /// 用于准确计算未读数：unreadCount = maxSeq - hasReadSeq
    /// 关键差异：Go SDK 会为本地不存在的会话从服务端拉取完整数据并插入，
    /// 此处补齐该逻辑。
    pub async fn sync_conversation_hash_read_seqs(
        &self,
        max_seq_recorder: &crate::core::message::handler::MaxSeqRecorder,
    ) -> Result<()> {
        let connection = match &self.connection {
            Some(c) => c,
            None => {
                warn!("[ConvSync] sync_conversation_hash_read_seqs: connection 未设置，跳过");
                return Ok(());
            }
        };

        let user_id = self.user_id.read().await.clone();
        use crate::domain::constant::types::ws_req_identifier;
        use crate::protocol::msg::{
            GetConversationsHasReadAndMaxSeqReq, GetConversationsHasReadAndMaxSeqResp,
        };

        let resp: GetConversationsHasReadAndMaxSeqResp = connection
            .send_rpc(
                ws_req_identifier::GET_CONV_MAX_READ_SEQ,
                &GetConversationsHasReadAndMaxSeqReq {
                    user_id,
                    conversation_i_ds: vec![],
                    return_pinned: false,
                },
            )
            .await
            .map_err(|e| {
                error!("[ConvSync] 获取会话 Hash Read Seq 失败: {}", e);
                SdkError::network(format!("sync hash read seq failed: {}", e))
            })?;

        if resp.seqs.is_empty() {
            return Ok(());
        }

        let mut changed_ids: Vec<String> = Vec::new();
        let mut conversation_ids_need_sync: Vec<String> = Vec::new();

        // 获取所有本地会话
        let local_conversations = self.dao.get_all().await.unwrap_or_default();
        let mut local_map: HashMap<String, crate::infra::database::models::LocalConversation> =
            HashMap::new();
        for conv in local_conversations {
            local_map.insert(conv.conversation_id.clone(), conv);
        }

        // 遍历服务端返回的 seqs
        for (conv_id, seq_info) in &resp.seqs {
            // 更新 MaxSeqRecorder 内存记录（对齐 Go SDK maxSeqRecorder.Set）
            max_seq_recorder.set(conv_id, seq_info.max_seq);

            // 计算未读数：maxSeq - hasReadSeq
            let unread_count = if seq_info.max_seq > seq_info.has_read_seq {
                (seq_info.max_seq - seq_info.has_read_seq) as i32
            } else {
                0
            };

            if let Some(local_conv) = local_map.get(conv_id) {
                // 本地存在该会话 → 检查是否需要更新未读数
                if local_conv.unread_count != unread_count {
                    if let Err(e) = self.dao.update_unread_count(conv_id, unread_count).await {
                        error!(
                            "[ConvSync] 更新会话 {} 未读数失败: {}",
                            conv_id, e
                        );
                    }
                    changed_ids.push(conv_id.clone());
                }
            } else {
                // 本地不存在该会话 → 收集待同步列表（对齐 Go SDK sync.go:82）
                conversation_ids_need_sync.push(conv_id.clone());
            }
        }

        // 同步不存在于本地的会话（对齐 Go SDK sync.go:87-123）
        if !conversation_ids_need_sync.is_empty() {
            info!(
                "[ConvSync] {} 个会话不在本地，从服务端拉取",
                conversation_ids_need_sync.len()
            );
            match self
                .pull_conversations_by_ids(&conversation_ids_need_sync)
                .await
            {
                Ok(server_convs) => {
                    let mut conversations_to_insert = Vec::new();
                    for s in &server_convs {
                        let mut domain = server_to_domain(s.clone());
                        // 计算未读数
                        if let Some(seq_info) = resp.seqs.get(&domain.conversation_id) {
                            let unread_count = if seq_info.max_seq > seq_info.has_read_seq {
                                (seq_info.max_seq - seq_info.has_read_seq) as i32
                            } else {
                                0
                            };
                            domain.unread_count = unread_count;
                        }
                        let local = crate::core::conversation::manager::domain_to_local(domain.clone());
                        if let Err(e) = self.dao.upsert(&local).await {
                            error!(
                                "[ConvSync] 插入会话 {} 失败: {}",
                                domain.conversation_id, e
                            );
                        } else {
                            conversations_to_insert.push(domain);
                        }
                    }
                    if !conversations_to_insert.is_empty() {
                        changed_ids.extend(
                            conversations_to_insert
                                .iter()
                                .map(|c| c.conversation_id.clone()),
                        );
                        self.conversation_listener.on_changed.notify(&conversations_to_insert);
                    }
                }
                Err(e) => {
                    error!(
                        "[ConvSync] 从服务端拉取缺失会话失败: {}",
                        e
                    );
                }
            }
        }

        // 对齐 Go SDK：syncHashReadSeqs 只更新 DB，不直接发布事件
        // 事件由 handle_messages_internal 末尾统一发布

        Ok(())
    }

    // ========================================================================
    // HTTP / RPC 拉取方法
    // ========================================================================

    async fn pull_all(&self) -> Result<GetAllConversationsResp> {
        let user_id = self.user_id.read().await.clone();
        let req = GetAllConversationsReq {
            owner_user_id: user_id,
        };
        debug!("从服务器拉取所有会话");
        let resp: GetAllConversationsResp = self.http_client.post(GET_ALL_CONVERSATION_LIST, &req).await?;
        debug!(
            "拉取到 {} 个会话",
            resp.conversations.as_ref().map_or(0, |v| v.len())
        );
        Ok(resp)
    }

    async fn pull_incremental(
        &self,
        version: u64,
        version_id: &str,
    ) -> Result<GetIncrementalConversationResp> {
        let user_id = self.user_id.read().await.clone();
        let req = GetIncrementalConversationReq {
            user_id,
            version_id: version_id.to_string(),
            version,
        };
        debug!(
            "从服务器拉取增量会话，版本: {}, version_id: {}",
            version, version_id
        );
        let resp: GetIncrementalConversationResp =
            self.http_client.post(GET_INCREMENTAL_CONVERSATION, &req).await?;
        debug!(
            "增量响应: full={}, insert={}, update={}, delete={}",
            resp.full,
            resp.insert.len(),
            resp.update.len(),
            resp.delete.len()
        );
        Ok(resp)
    }

    /// 按 ID 列表从服务端拉取会话（对齐 Go SDK `getConversationsByIDsFromServer`）
    async fn pull_conversations_by_ids(
        &self,
        conversation_ids: &[String],
    ) -> Result<Vec<ServerConversation>> {
        let user_id = self.user_id.read().await.clone();
        let req = GetConversationsByIDsReq {
            owner_user_id: user_id,
            conversation_ids: conversation_ids.to_vec(),
        };
        let resp: GetConversationsByIDsResp =
            self.http_client.post(GET_CONVERSATIONS, &req).await?;
        Ok(resp.conversations.unwrap_or_default())
    }

    /// 获取所有会话 ID（对齐 Go SDK `getAllConversationIDsFromServer`）
    async fn pull_full_conversation_ids(&self) -> Result<GetFullConversationIDsResp> {
        let user_id = self.user_id.read().await.clone();
        let req = GetFullConversationIDsReq { user_id };
        let resp: GetFullConversationIDsResp =
            self.http_client.post(GET_FULL_CONVERSATION_IDS, &req).await?;
        Ok(resp)
    }

    // ========================================================================
    // 版本查询（供外部使用）
    // ========================================================================

    pub async fn get_sync_version(&self) -> u64 {
        let user_id = self.user_id.read().await.clone();
        match self
            .sync_version_dao
            .get_version_sync(CONVERSATION_TABLE_NAME, &user_id)
            .await
        {
            Ok(Some((_, v))) => v,
            _ => 0,
        }
    }

    pub async fn get_sync_version_id(&self) -> String {
        let user_id = self.user_id.read().await.clone();
        match self
            .sync_version_dao
            .get_version_sync(CONVERSATION_TABLE_NAME, &user_id)
            .await
        {
            Ok(Some((vid, _))) => vid,
            _ => String::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

    #[tokio::test]
    async fn test_conversation_syncer_creation() {
        let pool = create_pool_memory().await.unwrap();
        let dao = Arc::new(ConversationDao::new(pool.clone()));
        let sync_version_dao = Arc::new(SyncVersionDao::new(pool));
        let conversation_listener = Arc::new(crate::domain::listener::conversation::ConversationListener::new());
        let http_client = Arc::new(HttpApiClient::new(
            "http://localhost:10002".to_string(),
            "test_token".to_string(),
            "test_op".to_string(),
        ));
        let syncer = ConversationSyncer::new(
            http_client,
            dao,
            conversation_listener,
            sync_version_dao,
            "test_user".to_string(),
        );

        assert_eq!(syncer.get_sync_version().await, 0);
        assert_eq!(syncer.get_sync_version_id().await, "");
    }

    #[tokio::test]
    async fn test_server_conversation_to_domain() {
        let server = ServerConversation {
            conversation_id: "si_user1_user2".to_string(),
            conversation_type: 1,
            user_id: "user2".to_string(),
            group_id: String::new(),
            owner_user_id: "user1".to_string(),
            recv_msg_opt: 0,
            is_pinned: false,
            is_private_chat: false,
            group_at_type: 0,
            ex: String::new(),
            attached_info: String::new(),
            burn_duration: 0,
            min_seq: 0,
            max_seq: 100,
            msg_destruct_time: 0,
            is_msg_destruct: false,
        };

        let domain = server_to_domain(server);
        assert_eq!(domain.conversation_id, "si_user1_user2");
        assert_eq!(domain.conversation_type, 1);
        assert_eq!(domain.user_id, "user2");
        assert_eq!(domain.recv_msg_opt, 0);
        assert_eq!(domain.latest_msg_seq, 100);
        assert!(!domain.is_pinned);
    }

    #[tokio::test]
    async fn test_get_all_conversations_req_serialization() {
        let req = GetAllConversationsReq {
            owner_user_id: "test_user".to_string(),
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("ownerUserID"));
        assert!(json.contains("test_user"));
    }

    #[tokio::test]
    async fn test_get_incremental_conversation_req_serialization() {
        let req = GetIncrementalConversationReq {
            user_id: "test_user".to_string(),
            version_id: "abc123".to_string(),
            version: 42,
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("versionID"));
        assert!(json.contains("abc123"));
        assert!(json.contains("42"));
    }

    #[tokio::test]
    async fn test_get_conversations_by_ids_req_serialization() {
        let req = GetConversationsByIDsReq {
            owner_user_id: "user1".to_string(),
            conversation_ids: vec!["si_u1_u2".to_string(), "g_group1".to_string()],
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("ownerUserID"));
        assert!(json.contains("conversationIDs"));
    }
}
