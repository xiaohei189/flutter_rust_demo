use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::conversation::Conversation;
use crate::infra::database::conversation_dao::ConversationDao;
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{GET_ALL_CONVERSATION_LIST, GET_INCREMENTAL_CONVERSATION};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn};

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

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetIncrementalConversationResp {
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub full: bool,
    #[serde(default)]
    pub delete: Vec<String>,
    #[serde(default)]
    pub insert: Vec<ServerConversation>,
    #[serde(default)]
    pub update: Vec<ServerConversation>,
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
    event_bus: Arc<EventBus>,
    sync_version: Arc<RwLock<u64>>,
    sync_version_id: Arc<RwLock<String>>,
    is_first_sync: Arc<RwLock<bool>>,
    user_id: Arc<RwLock<String>>,
}

impl ConversationSyncer {
    pub fn new(
        http_client: Arc<HttpApiClient>,
        dao: Arc<ConversationDao>,
        event_bus: Arc<EventBus>,
        user_id: String,
    ) -> Self {
        Self {
            http_client,
            dao,
            event_bus,
            sync_version: Arc::new(RwLock::new(0)),
            sync_version_id: Arc::new(RwLock::new(String::new())),
            is_first_sync: Arc::new(RwLock::new(true)),
            user_id: Arc::new(RwLock::new(user_id)),
        }
    }

    pub async fn set_user_id(&self, user_id: String) {
        let mut uid = self.user_id.write().await;
        *uid = user_id;
    }

    pub async fn sync_incremental(&self) -> Result<Vec<Conversation>> {
        let current_version = *self.sync_version.read().await;
        let current_version_id = self.sync_version_id.read().await.clone();
        info!("开始增量同步会话，版本: {}, version_id: {}", current_version, current_version_id);

        self.event_bus.publish(SdkEvent::SyncStarted);

        let resp = match self.pull_incremental(current_version, &current_version_id).await {
            Ok(r) => r,
            Err(e) => {
                self.event_bus.publish(SdkEvent::SyncFailed {
                    error: format!("{}", e),
                });
                return Err(e);
            }
        };

        if resp.full {
            info!("增量同步返回 full=true，执行全量同步");
            return self.sync_full().await;
        }

        for conv_id in &resp.delete {
            self.dao.delete(conv_id).await?;
            self.event_bus.publish(SdkEvent::ConversationDeleted {
                conversation_ids: vec![conv_id.clone()],
            });
        }

        for s in &resp.update {
            let domain = server_to_domain(s.clone());
            let local = crate::core::conversation::manager::domain_to_local(domain.clone());
            self.dao.upsert(&local).await?;
        }

        for s in &resp.insert {
            let domain = server_to_domain(s.clone());
            let local = crate::core::conversation::manager::domain_to_local(domain.clone());
            self.dao.upsert(&local).await?;
        }

        if !resp.update.is_empty() || !resp.insert.is_empty() {
            let changed: Vec<Conversation> = resp.update.iter().chain(resp.insert.iter())
                .map(|s| server_to_domain(s.clone()))
                .collect();
            self.event_bus.publish(SdkEvent::ConversationChanged {
                conversations: changed,
            });
        }

        *self.sync_version.write().await = resp.version;
        *self.sync_version_id.write().await = resp.version_id;
        *self.is_first_sync.write().await = false;

        self.event_bus.publish(SdkEvent::SyncFinished);
        info!("增量同步完成，insert={}, update={}, delete={}",
            resp.insert.len(), resp.update.len(), resp.delete.len());

        let inserted_convs: Vec<Conversation> = resp.insert.iter().map(|s| server_to_domain(s.clone())).collect();
        Ok(inserted_convs)
    }

    pub async fn sync_full(&self) -> Result<Vec<Conversation>> {
        info!("开始全量同步会话");
        self.event_bus.publish(SdkEvent::SyncStarted);

        let resp = match self.pull_all().await {
            Ok(r) => r,
            Err(e) => {
                self.event_bus.publish(SdkEvent::SyncFailed {
                    error: format!("{}", e),
                });
                return Err(e);
            }
        };

        let conversations: Vec<Conversation> = resp.conversations.unwrap_or_default().into_iter()
            .map(|s| server_to_domain(s))
            .collect();

        self.dao.clear_all().await?;
        for conv in &conversations {
            let local = crate::core::conversation::manager::domain_to_local(conv.clone());
            self.dao.upsert(&local).await?;
        }

        self.event_bus.publish(SdkEvent::ConversationChanged {
            conversations: conversations.clone(),
        });

        *self.is_first_sync.write().await = false;

        self.event_bus.publish(SdkEvent::SyncFinished);
        info!("全量同步完成，同步 {} 个会话", conversations.len());

        if let Ok(count) = self.dao.count().await {
            self.event_bus.publish(SdkEvent::TotalUnreadCountChanged {
                count: count as i64,
            });
        }

        Ok(conversations)
    }

    async fn pull_all(&self) -> Result<GetAllConversationsResp> {
        let user_id = self.user_id.read().await.clone();
        let req = GetAllConversationsReq {
            owner_user_id: user_id,
        };
        debug!("从服务器拉取所有会话");
        let resp: GetAllConversationsResp = self.http_client.post(GET_ALL_CONVERSATION_LIST, &req).await?;
        debug!("拉取到 {} 个会话", resp.conversations.as_ref().map_or(0, |v| v.len()));
        Ok(resp)
    }

    async fn pull_incremental(&self, version: u64, version_id: &str) -> Result<GetIncrementalConversationResp> {
        let user_id = self.user_id.read().await.clone();
        let req = GetIncrementalConversationReq {
            user_id,
            version_id: version_id.to_string(),
            version,
        };
        debug!("从服务器拉取增量会话，版本: {}, version_id: {}", version, version_id);
        let resp: GetIncrementalConversationResp = self.http_client.post(GET_INCREMENTAL_CONVERSATION, &req).await?;
        debug!("增量响应: full={}, insert={}, update={}, delete={}",
            resp.full, resp.insert.len(), resp.update.len(), resp.delete.len());
        Ok(resp)
    }

    pub async fn get_sync_version(&self) -> u64 {
        *self.sync_version.read().await
    }

    pub async fn get_sync_version_id(&self) -> String {
        self.sync_version_id.read().await.clone()
    }

    pub async fn is_first_sync(&self) -> bool {
        *self.is_first_sync.read().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

    #[tokio::test]
    async fn test_conversation_syncer_creation() {
        let pool = create_pool_memory().await.unwrap();
        let dao = Arc::new(ConversationDao::new(pool));
        let event_bus = Arc::new(EventBus::new());
        let http_client = Arc::new(HttpApiClient::new(
            "http://localhost:10002".to_string(),
            "test_token".to_string(),
            "test_op".to_string(),
        ));
        let syncer = ConversationSyncer::new(
            http_client,
            dao,
            event_bus,
            "test_user".to_string(),
        );

        assert_eq!(syncer.get_sync_version().await, 0);
        assert!(syncer.is_first_sync().await);
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
        assert_eq!(domain.is_pinned, false);
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
}