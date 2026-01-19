//! 会话 HTTP API 客户端
//!
//! 负责所有会话相关的 HTTP 请求

use crate::im::http::{make_client, HttpClient, HttpResponseExtractor};
use crate::im::model::conversation::{
    AllConversationsResp, ConversationIDsResp, EmptyResp, GetConversationReq, GetConversationResp, GetConversationsReq, GetConversationsResp, GetSortedConversationListReq,
    GetSortedConversationListResp, IncrementalConversationResp, OwnerConversationReq, SetConversationsReq,
};
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::collections::HashSet;
use tower::ServiceExt;
use tower_http_client::ServiceExt as _;
use uuid::Uuid;

/// 会话相关的 HTTP API 客户端
#[derive(Clone)]
pub struct ConversationApi {
    client: HttpClient,
    api_base_url: String,
    user_id: String,
}

impl ConversationApi {
    /// 创建新的会话 API 客户端
    ///
    /// `client` 应该已经在外部配置好认证拦截器
    pub fn new(client: reqwest::Client, api_base_url: String, user_id: String, token: &str) -> Self {
        Self {
            client: make_client(client, token),
            api_base_url,
            user_id,
        }
    }

    /// 从服务器获取每个会话的 MaxSeq 和 HasReadSeq
    pub async fn get_has_read_and_max_seqs(&self) -> Result<HashMap<String, (i64, i64)>> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/msg/get_conversations_has_read_and_max_seq", self.api_base_url);

        let mut client = self.client.clone();
        let service = client.ready().await?;
        let req = service
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
            }))?;

        #[derive(Deserialize, Serialize)]
        struct SeqInfo {
            #[serde(rename = "maxSeq")]
            max_seq: i64,
            #[serde(rename = "hasReadSeq")]
            has_read_seq: i64,
            #[serde(rename = "maxSeqTime", default)]
            max_seq_time: i64,
        }

        #[derive(Deserialize)]
        struct SeqsData {
            seqs: HashMap<String, SeqInfo>,
        }

        let data: SeqsData = HttpResponseExtractor::send_data(req).await?;

        let mut result = HashMap::new();

        for (conv_id, seq_info) in data.seqs.iter() {
            let max_seq = seq_info.max_seq;
            let has_read_seq = seq_info.has_read_seq;
            result.insert(conv_id.clone(), (max_seq, has_read_seq));
        }

        Ok(result)
    }

    /// 从服务器获取增量会话
    pub async fn get_incremental_conversations(&self, version: u64, version_id: &str) -> Result<IncrementalConversationResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/conversation/get_incremental_conversations", self.api_base_url);

        let mut client = self.client.clone();
        let service = client.ready().await?;
        let req = service
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "version": version,
                "versionID": version_id
            }))?;

        let resp: IncrementalConversationResp = HttpResponseExtractor::send_data(req).await?;

        Ok(resp)
    }

    /// 从服务器获取所有会话
    pub async fn get_all_conversations(&self) -> Result<AllConversationsResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/conversation/get_all_conversations", self.api_base_url);

        let mut client = self.client.clone();
        let service = client.ready().await?;
        let req = service
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "ownerUserID": self.user_id
            }))?;

        let resp: AllConversationsResp = HttpResponseExtractor::send_data(req).await?;

        Ok(resp)
    }

    /// 从服务器获取所有会话 ID
    pub async fn get_all_conversation_ids(&self) -> Result<Vec<String>> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/conversation/get_full_conversation_ids", self.api_base_url);

        let mut client = self.client.clone();
        let service = client.ready().await?;
        let req = service
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id
            }))?;

        #[derive(Deserialize)]
        struct ConversationIdsData {
            #[serde(rename = "conversationIDs")]
            conversation_ids: Vec<String>,
        }

        let data: ConversationIdsData = HttpResponseExtractor::send_data(req).await?;

        Ok(data.conversation_ids)
    }

    /// /conversation/get_sorted_conversation_list
    pub async fn get_sorted_conversation_list(&self, req: GetSortedConversationListReq) -> Result<GetSortedConversationListResp> {
        let url = format!("{}/conversation/get_sorted_conversation_list", self.api_base_url);
        let mut client = self.client.clone();
        let service = client.ready().await?;
        let req = service
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", Uuid::new_v4().to_string())
            .json(&req)?;
        HttpResponseExtractor::send_data(req).await
    }

    /// /conversation/get_conversation
    pub async fn get_conversation(&self, req: GetConversationReq) -> Result<GetConversationResp> {
        self.post_json("/conversation/get_conversation", req).await
    }

    /// /conversation/get_conversations
    pub async fn get_conversations(&self, req: GetConversationsReq) -> Result<GetConversationsResp> {
        self.post_json("/conversation/get_conversations", req).await
    }

    /// /conversation/set_conversations
    pub async fn set_conversations(&self, req: SetConversationsReq) -> Result<EmptyResp> {
        self.post_json("/conversation/set_conversations", req).await
    }

    /// /conversation/get_owner_conversation
    pub async fn get_owner_conversation(&self, req: OwnerConversationReq) -> Result<GetConversationResp> {
        self.post_json("/conversation/get_owner_conversation", req).await
    }

    /// /conversation/get_not_notify_conversation_ids
    pub async fn get_not_notify_conversation_ids(&self) -> Result<HashSet<String>> {
        let payload = serde_json::json!({ "ownerUserID": self.user_id });
        let resp: ConversationIDsResp = self.post_json("/conversation/get_not_notify_conversation_ids", payload).await?;
        Ok(resp.conversation_ids.into_iter().collect())
    }

    /// /conversation/get_pinned_conversation_ids
    pub async fn get_pinned_conversation_ids(&self) -> Result<HashSet<String>> {
        let payload = serde_json::json!({ "ownerUserID": self.user_id });
        let resp: ConversationIDsResp = self.post_json("/conversation/get_pinned_conversation_ids", payload).await?;
        Ok(resp.conversation_ids.into_iter().collect())
    }

    async fn post_json<T: serde::Serialize, R: serde::de::DeserializeOwned>(&self, path: &str, payload: T) -> Result<R> {
        let url = format!("{}{}", self.api_base_url, path);
        let mut client = self.client.clone();
        let service = client.ready().await?;
        let req = service.post(&url).header("Content-Type", "application/json").json(&payload)?;
        HttpResponseExtractor::send_data(req).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::im::auth::login_async;
    use crate::im::conversation::RequestPagination;
    use crate::im::logger::logger::init_logger;
    use crate::im::model::conversation::{GetConversationReq, GetConversationsReq, GetSortedConversationListReq, OwnerConversationReq, SetConversationsReq};
    use test_context::{test_context, AsyncTestContext};
    use tokio::sync::OnceCell;
    use tracing::{error, info};

    static APP_CTX: OnceCell<AppCtx> = OnceCell::const_new();

    #[derive(Clone)]
    pub struct AppCtx {
        pub api: ConversationApi,
    }

    impl AsyncTestContext for AppCtx {
        async fn setup() -> Self {
            APP_CTX
                .get_or_init(|| async {
                    init_logger("debug,sqlx=debug,hyper_util::client=info,reqwest=info");
                    let area_code = "+86".to_string();
                    let password = "284f3d09ea0695538e4ded1c1766d73a".to_string();
                    let platform = 5;

                    let token_info = login_async(area_code, "17764338283".to_string(), password, platform).await.expect("登录失败");

                    let api = ConversationApi::new(reqwest::Client::new(), "http://localhost:10002".to_string(), token_info.user_id.clone(), &token_info.im_token);
                    AppCtx { api }
                })
                .await
                .clone()
        }

        async fn teardown(self) {
            // 如果需要，可以在这里做清理
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_has_read_and_max_seqs(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let res = api.get_has_read_and_max_seqs().await.unwrap();
        info!("会话 Seq 信息获取成功，条目数: {}", res.len());
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_incremental_conversations(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let resp = api.get_incremental_conversations(0, "").await.unwrap();
        info!("增量会话同步成功: {:?}", resp);
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_all_conversations(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let resp = api.get_all_conversations().await.unwrap();
        info!("全量会话同步成功，会话数: {}", resp.conversations.len());
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_all_conversation_ids(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let ids = api.get_all_conversation_ids().await.unwrap();
        info!("会话 ID 获取成功，数量: {}", ids.len());
    }

    async fn pick_first_conversation_id(api: &ConversationApi) -> Option<String> {
        match api.get_all_conversation_ids().await {
            Ok(mut ids) if !ids.is_empty() => Some(ids.swap_remove(0)),
            _ => None,
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_sorted_conversation_list(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let req = GetSortedConversationListReq {
            user_id: api.user_id.clone(),
            conversation_ids: vec![],
            pagination: RequestPagination::default(),
        };
        match api.get_sorted_conversation_list(req).await {
            Ok(resp) => info!("get_sorted_conversation_list total: {}", resp.conversation_total),
            Err(e) => error!("get_sorted_conversation_list error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_conversation(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        if let Some(conv_id) = pick_first_conversation_id(&api).await {
            let req = GetConversationReq {
                owner_user_id: api.user_id.clone(),
                conversation_id: conv_id,
            };
            match api.get_conversation(req).await {
                Ok(resp) => info!("get_conversation resp: {:?}", resp.conversation),
                Err(e) => error!("get_conversation error: {:?}", e),
            }
        } else {
            info!("skip get_conversation: no conversation id available");
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_conversations(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        if let Some(conv_id) = pick_first_conversation_id(&api).await {
            let req = GetConversationsReq {
                owner_user_id: api.user_id.clone(),
                conversation_ids: vec![conv_id],
            };
            match api.get_conversations(req).await {
                Ok(resp) => info!("get_conversations count: {}", resp.conversations.len()),
                Err(e) => error!("get_conversations error: {:?}", e),
            }
        } else {
            info!("skip get_conversations: no conversation id available");
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_set_conversations(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        if let Some(conv_id) = pick_first_conversation_id(&api).await {
            let req = SetConversationsReq {
                owner_user_id: api.user_id.clone(),
                conversation_ids: vec![conv_id],
                recv_msg_opt: 0,
                is_pinned: false,
            };
            match api.set_conversations(req).await {
                Ok(_) => info!("set_conversations ok"),
                Err(e) => error!("set_conversations error: {:?}", e),
            }
        } else {
            info!("skip set_conversations: no conversation id available");
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_owner_conversation(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        if let Some(conv_id) = pick_first_conversation_id(&api).await {
            let req = OwnerConversationReq {
                owner_user_id: api.user_id.clone(),
                conversation_id: conv_id,
            };
            match api.get_owner_conversation(req).await {
                Ok(resp) => info!("get_owner_conversation resp: {:?}", resp.conversation),
                Err(e) => error!("get_owner_conversation error: {:?}", e),
            }
        } else {
            info!("skip get_owner_conversation: no conversation id available");
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_not_notify_conversation_ids(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        match api.get_not_notify_conversation_ids().await {
            Ok(ids) => info!("not_notify ids: {}", ids.len()),
            Err(e) => error!("get_not_notify_conversation_ids error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_pinned_conversation_ids(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        match api.get_pinned_conversation_ids().await {
            Ok(ids) => info!("pinned ids: {}", ids.len()),
            Err(e) => error!("get_pinned_conversation_ids error: {:?}", e),
        }
    }
}
