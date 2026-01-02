//! 会话 HTTP API 客户端
//!
//! 负责所有会话相关的 HTTP 请求

use crate::im::conversation::types::{AllConversationsResp, IncrementalConversationResp};
use crate::im::http::{make_client, HttpClient, HttpResponseExtractor};
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tower::ServiceExt;
use tower_http_client::ServiceExt as _;
use tracing::info;
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
    pub fn new(
        client: reqwest::Client,
        api_base_url: String,
        user_id: String,
        token: &str,
    ) -> Self {
        Self {
            client: make_client(client, token),
            api_base_url,
            user_id,
        }
    }

    /// 从服务器获取每个会话的 MaxSeq 和 HasReadSeq
    pub async fn get_has_read_and_max_seqs(&self) -> Result<HashMap<String, (i64, i64)>> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!(
            "{}/msg/get_conversations_has_read_and_max_seq",
            self.api_base_url
        );

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

        let data: SeqsData = HttpResponseExtractor::send(req).await?;

        let mut result = HashMap::new();

        for (conv_id, seq_info) in data.seqs.iter() {
            let max_seq = seq_info.max_seq;
            let has_read_seq = seq_info.has_read_seq;
            let unread = (max_seq - has_read_seq).max(0);
            result.insert(conv_id.clone(), (max_seq, has_read_seq));
        }

        Ok(result)
    }

    /// 从服务器获取增量会话
    pub async fn get_incremental_conversations(
        &self,
        version: u64,
        version_id: &str,
    ) -> Result<IncrementalConversationResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!(
            "{}/conversation/get_incremental_conversations",
            self.api_base_url
        );

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

        let resp: IncrementalConversationResp = HttpResponseExtractor::send(req).await?;

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

        let resp: AllConversationsResp = HttpResponseExtractor::send(req).await?;

        Ok(resp)
    }

    /// 从服务器获取所有会话 ID
    pub async fn get_all_conversation_ids(&self) -> Result<Vec<String>> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!(
            "{}/conversation/get_full_conversation_ids",
            self.api_base_url
        );

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

        let data: ConversationIdsData = HttpResponseExtractor::send(req).await?;

        Ok(data.conversation_ids)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::im::auth::login_async;
    use crate::im::logger::logger::init_logger;
    use test_context::{test_context, AsyncTestContext};
    use tokio::sync::OnceCell;
    use tracing::info;

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

                    let token_info =
                        login_async(area_code, "17764338283".to_string(), password, platform)
                            .await
                            .expect("登录失败");

                    let api = ConversationApi::new(
                        reqwest::Client::new(),
                        "http://localhost:10002".to_string(),
                        token_info.user_id.clone(),
                        &token_info.im_token,
                    );
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
}
