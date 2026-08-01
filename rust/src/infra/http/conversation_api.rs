//! HTTP 适配器 — impl ConversationServerApi for HttpConversationApi
//!
//! trait 定义在 `domain::ports::conversation`

use crate::domain::error::Result;
use crate::domain::ports::conversation::{
    ConversationServerApi, GetAllConversationsReq, GetAllConversationsResp,
    GetConversationsByIDsReq, GetConversationsByIDsResp, GetFullConversationIDsReq,
    GetFullConversationIDsResp, GetIncrementalConversationReq, GetIncrementalConversationResp,
    ServerConversation,
};
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{
    GET_ALL_CONVERSATION_LIST, GET_CONVERSATIONS, GET_FULL_CONVERSATION_IDS,
    GET_INCREMENTAL_CONVERSATION,
};
use async_trait::async_trait;
use std::sync::Arc;

/// 基于 HTTP 的生产实现
pub struct HttpConversationApi {
    http_client: Arc<HttpApiClient>,
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
        tracing::debug!(
            "拉取到 {} 个会话",
            resp.conversations.as_ref().map_or(0, |v| v.len())
        );
        Ok(resp)
    }

    async fn pull_incremental(
        &self,
        user_id: String,
        version: u64,
        version_id: String,
    ) -> Result<GetIncrementalConversationResp> {
        let req = GetIncrementalConversationReq {
            user_id,
            version_id,
            version,
        };
        tracing::debug!("从服务器拉取增量会话，版本: {}", version);
        let resp: GetIncrementalConversationResp =
            self.http_client.post(GET_INCREMENTAL_CONVERSATION, &req).await?;
        tracing::debug!(
            "增量响应: full={}, insert={}, update={}, delete={}",
            resp.full,
            resp.insert.len(),
            resp.update.len(),
            resp.delete.len()
        );
        Ok(resp)
    }

    async fn pull_conversations_by_ids(
        &self,
        user_id: String,
        conversation_ids: Vec<String>,
    ) -> Result<Vec<ServerConversation>> {
        let req = GetConversationsByIDsReq {
            owner_user_id: user_id,
            conversation_ids,
        };
        let resp: GetConversationsByIDsResp =
            self.http_client.post(GET_CONVERSATIONS, &req).await?;
        Ok(resp.conversations.unwrap_or_default())
    }

    async fn pull_full_conversation_ids(&self, user_id: String) -> Result<GetFullConversationIDsResp> {
        let req = GetFullConversationIDsReq { user_id };
        let resp: GetFullConversationIDsResp =
            self.http_client.post(GET_FULL_CONVERSATION_IDS, &req).await?;
        Ok(resp)
    }
}