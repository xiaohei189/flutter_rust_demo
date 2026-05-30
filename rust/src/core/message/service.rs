use crate::domain::constant::types::notification_type;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::infra::database::MessageDao;
use crate::infra::database::models::LocalChatLog;
use crate::infra::http::routes::{DELETE_MSGS, MARK_MSGS_AS_READ, REVOKE_MSG};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tracing::info;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RevokeMessageReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "seq")]
    pub seq: i64,
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "clientMsgID")]
    pub client_msg_id: String,
    #[serde(rename = "sessionType")]
    pub session_type: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DeleteMessagesReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "clientMsgIDs")]
    pub client_msg_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MarkMessagesAsReadReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "sessionType")]
    pub session_type: i32,
    #[serde(rename = "hasReadSeq")]
    pub has_read_seq: i64,
    #[serde(rename = "seqs")]
    pub seqs: Vec<i64>,
}

pub struct MessageService {
    message_dao: Arc<MessageDao>,
    event_bus: Arc<EventBus>,
    http_client: Arc<crate::infra::http::client::HttpApiClient>,
    user_id: Arc<std::sync::Mutex<String>>,
}

impl MessageService {
    pub fn new(
        message_dao: Arc<MessageDao>,
        event_bus: Arc<EventBus>,
        http_client: Arc<crate::infra::http::client::HttpApiClient>,
        user_id: String,
    ) -> Self {
        Self {
            message_dao,
            event_bus,
            http_client,
            user_id: Arc::new(std::sync::Mutex::new(user_id)),
        }
    }

    pub fn set_user_id(&self, user_id: String) {
        let mut uid = self.user_id.lock().unwrap();
        *uid = user_id;
    }

    /// 撤回消息
    pub async fn revoke_message(
        &self,
        conversation_id: String,
        seq: i64,
        client_msg_id: String,
        session_type: i32,
    ) -> Result<()> {
        let user_id = self.user_id.lock().unwrap().clone();
        
        let req = RevokeMessageReq {
            conversation_id: conversation_id.clone(),
            seq,
            user_id: user_id.clone(),
            client_msg_id: client_msg_id.clone(),
            session_type,
        };

        let _resp: serde_json::Value = self.http_client.post(REVOKE_MSG, &req).await?;

        // 更新本地数据库：标记消息为已撤回
        self.message_dao
            .update_content_type(&conversation_id, &client_msg_id, notification_type::REVOKE)
            .await?;

        self.event_bus.publish(SdkEvent::MessageRevoked {
            conversation_id: conversation_id.clone(),
            seq,
            client_msg_id,
        });

        info!("消息已撤回: conversation_id={}, seq={}", conversation_id, seq);
        Ok(())
    }

    /// 删除消息
    pub async fn delete_messages(
        &self,
        conversation_id: String,
        client_msg_ids: Vec<String>,
    ) -> Result<()> {
        // 调用服务端 API
        let req = DeleteMessagesReq {
            conversation_id: conversation_id.clone(),
            client_msg_ids: client_msg_ids.clone(),
        };

        let _resp: serde_json::Value = self.http_client.post(DELETE_MSGS, &req).await?;

        // 删除本地数据库中的消息
        for client_msg_id in &client_msg_ids {
            self.message_dao.delete_by_client_msg_id(&conversation_id, client_msg_id).await?;
        }

        self.event_bus.publish(SdkEvent::MessagesDeleted {
            conversation_id: conversation_id.clone(),
            client_msg_ids: client_msg_ids.clone(),
        });

        info!("消息已删除: conversation_id={}, count={}", conversation_id, client_msg_ids.len());
        Ok(())
    }

    /// 标记消息已读
    pub async fn mark_messages_as_read(
        &self,
        conversation_id: String,
        session_type: i32,
        has_read_seq: i64,
        seqs: Vec<i64>,
    ) -> Result<()> {
        let user_id = self.user_id.lock().unwrap().clone();
        
        let req = MarkMessagesAsReadReq {
            conversation_id: conversation_id.clone(),
            user_id,
            session_type,
            has_read_seq,
            seqs: seqs.clone(),
        };

        let _resp: serde_json::Value = self.http_client.post(MARK_MSGS_AS_READ, &req).await?;

        // 更新本地数据库：标记消息为已读
        if !seqs.is_empty() {
            self.message_dao.mark_as_read_by_seqs(&conversation_id, &seqs).await?;
        }

        info!("消息已标记为已读: conversation_id={}, seq_count={}", conversation_id, seqs.len());
        Ok(())
    }

    /// 本地搜索消息
    pub async fn search_local_messages(
        &self,
        conversation_id: String,
        keyword: String,
        max_count: i64,
    ) -> Result<Vec<LocalChatLog>> {
        let results = self.message_dao.search_by_keyword(&conversation_id, &keyword, max_count).await?;
        info!("本地搜索消息: conv={}, keyword={}, count={}", conversation_id, keyword, results.len());
        Ok(results)
    }
}
