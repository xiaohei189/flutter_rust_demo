//! HTTP 适配器 — impl ConversationServerApi for HttpConversationApi
//!
//! trait 定义在 `domain::ports::conversation`

use crate::domain::error::Result;
use crate::http::client::HttpApiClient;
use crate::http::conversation::{
    ConversationServerApi, GetAllConversationsReq, GetAllConversationsResp, GetConversationsByIDsReq, GetConversationsByIDsResp, GetFullConversationIDsReq, GetFullConversationIDsResp,
    GetIncrementalConversationReq, GetIncrementalConversationResp, ServerConversation, SetConversationReq,
};
use crate::http::routes::{GET_ALL_CONVERSATION_LIST, GET_CONVERSATIONS, GET_FULL_CONVERSATION_IDS, GET_INCREMENTAL_CONVERSATION, SET_CONVERSATION};
use async_trait::async_trait;
use serde::Serialize;
use std::sync::Arc;

/// 基于 HTTP 的生产实现
pub struct HttpConversationApi {
    http_client: Arc<HttpApiClient>,
}

#[derive(Serialize)]
struct ServerConversationReq {
    #[serde(rename = "conversationID")]
    conversation_id: String,
    #[serde(rename = "conversationType")]
    conversation_type: i32,
    #[serde(rename = "userID")]
    user_id: String,
    #[serde(rename = "groupID")]
    group_id: String,
    #[serde(rename = "recvMsgOpt", skip_serializing_if = "Option::is_none")]
    recv_msg_opt: Option<i32>,
    #[serde(rename = "isPinned", skip_serializing_if = "Option::is_none")]
    is_pinned: Option<bool>,
    #[serde(rename = "isPrivateChat", skip_serializing_if = "Option::is_none")]
    is_private_chat: Option<bool>,
    #[serde(rename = "groupAtType", skip_serializing_if = "Option::is_none")]
    group_at_type: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    ex: Option<String>,
}

#[derive(Serialize)]
struct ServerSetConversationsReq {
    #[serde(rename = "userIDs")]
    user_ids: Vec<String>,
    conversation: ServerConversationReq,
}

impl HttpConversationApi {
    pub fn new(http_client: Arc<HttpApiClient>) -> Self {
        Self { http_client }
    }
}

#[async_trait]
impl ConversationServerApi for HttpConversationApi {
    async fn pull_all(&self, user_id: String) -> Result<GetAllConversationsResp> {
        let req = GetAllConversationsReq { owner_user_id: user_id };
        tracing::debug!("从服务器拉取所有会话");
        let resp: GetAllConversationsResp = self.http_client.post(GET_ALL_CONVERSATION_LIST, &req).await?;
        tracing::debug!("拉取到 {} 个会话", resp.conversations.as_ref().map_or(0, |v| v.len()));
        Ok(resp)
    }

    async fn pull_incremental(&self, user_id: String, version: u64, version_id: String) -> Result<GetIncrementalConversationResp> {
        let req = GetIncrementalConversationReq { user_id, version_id, version };
        tracing::debug!("从服务器拉取增量会话，版本: {}", version);
        let resp: GetIncrementalConversationResp = self.http_client.post(GET_INCREMENTAL_CONVERSATION, &req).await?;
        tracing::debug!("增量响应: full={}, insert={}, update={}, delete={}", resp.full, resp.insert.len(), resp.update.len(), resp.delete.len());
        Ok(resp)
    }

    async fn pull_conversations_by_ids(&self, user_id: String, conversation_ids: Vec<String>) -> Result<Vec<ServerConversation>> {
        let req = GetConversationsByIDsReq {
            owner_user_id: user_id,
            conversation_ids,
        };
        let resp: GetConversationsByIDsResp = self.http_client.post(GET_CONVERSATIONS, &req).await?;
        Ok(resp.conversations.unwrap_or_default())
    }

    async fn pull_full_conversation_ids(&self, user_id: String) -> Result<GetFullConversationIDsResp> {
        let req = GetFullConversationIDsReq { user_id };
        let resp: GetFullConversationIDsResp = self.http_client.post(GET_FULL_CONVERSATION_IDS, &req).await?;
        Ok(resp)
    }

    async fn set_conversation_on_server(&self, req: &SetConversationReq) -> Result<()> {
        let body = ServerSetConversationsReq {
            user_ids: req.user_ids.clone(),
            conversation: ServerConversationReq {
                conversation_id: req.conversation_id.clone(),
                conversation_type: req.conversation_type.unwrap_or(0),
                user_id: req.user_id.clone().unwrap_or_default(),
                group_id: req.group_id.clone().unwrap_or_default(),
                recv_msg_opt: req.recv_msg_opt,
                is_pinned: req.is_pinned,
                is_private_chat: req.is_private_chat,
                group_at_type: req.group_at_type,
                ex: req.ex.clone(),
            },
        };
        let _: serde_json::Value = self.http_client.post(SET_CONVERSATION, &body).await?;
        tracing::debug!("会话设置已同步到服务器: conversation_id={}", req.conversation_id);
        Ok(())
    }
}
