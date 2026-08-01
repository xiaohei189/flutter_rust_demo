//! HTTP 适配器 — impl MessageServerApi for HttpMessageApi
//!
//! trait 定义在 `domain::ports::message`

use crate::domain::error::Result;
use crate::domain::ports::message::{
    MarkConversationAsReadReq, MarkMessagesAsReadReq, MessageServerApi, RevokeMessageReq,
};
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{
    DELETE_MSGS, MARK_CONVERSATION_AS_READ, MARK_MSGS_AS_READ, REVOKE_MSG,
};
use async_trait::async_trait;
use serde::Serialize;
use std::sync::Arc;

/// 基于 HTTP 的生产实现
pub struct HttpMessageApi {
    http_client: Arc<HttpApiClient>,
}

impl HttpMessageApi {
    pub fn new(http_client: Arc<HttpApiClient>) -> Self {
        Self { http_client }
    }
}

/// 删除消息的服务端请求体（内部使用）
#[derive(Serialize)]
struct ServerDeleteReq {
    #[serde(rename = "conversationID")]
    conversation_id: String,
    seqs: Vec<i64>,
    #[serde(rename = "userID")]
    user_id: String,
}

#[async_trait]
impl MessageServerApi for HttpMessageApi {
    async fn revoke_on_server(&self, req: &RevokeMessageReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(REVOKE_MSG, req).await?;
        Ok(())
    }

    async fn delete_on_server(&self, conversation_id: &str, seqs: &[i64], user_id: &str) -> Result<()> {
        let req = ServerDeleteReq {
            conversation_id: conversation_id.to_string(),
            seqs: seqs.to_vec(),
            user_id: user_id.to_string(),
        };
        let _: serde_json::Value = self.http_client.post(DELETE_MSGS, &req).await?;
        Ok(())
    }

    async fn mark_conversation_as_read_on_server(&self, req: &MarkConversationAsReadReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(MARK_CONVERSATION_AS_READ, req).await?;
        Ok(())
    }

    async fn mark_messages_as_read_on_server(&self, req: &MarkMessagesAsReadReq) -> Result<()> {
        let _: serde_json::Value = self.http_client.post(MARK_MSGS_AS_READ, req).await?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::http::client::HttpApiClient;
    use wiremock::matchers::{method, path};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    fn make_api(server: &MockServer) -> HttpMessageApi {
        let client = Arc::new(HttpApiClient::new(server.uri(), "test_token".to_string(), "test_op".to_string()));
        HttpMessageApi::new(client)
    }

    fn ok_response() -> ResponseTemplate {
        ResponseTemplate::new(200).set_body_json(serde_json::json!({"errCode": 0, "errMsg": "", "data": null}))
    }

    fn err_response() -> ResponseTemplate {
        ResponseTemplate::new(200).set_body_json(serde_json::json!({"errCode": 1001, "errMsg": "message not found", "data": null}))
    }

    #[tokio::test]
    async fn test_revoke_on_server_success() {
        let server = MockServer::start().await;
        Mock::given(method("POST")).and(path("/msg/revoke_msg")).respond_with(ok_response()).mount(&server).await;
        let api = make_api(&server);
        let req = RevokeMessageReq { conversation_id: "conv_1".to_string(), seq: 5, user_id: "user_1".to_string(), client_msg_id: "msg_1".to_string(), session_type: 1 };
        assert!(api.revoke_on_server(&req).await.is_ok());
    }

    #[tokio::test]
    async fn test_revoke_on_server_business_error() {
        let server = MockServer::start().await;
        Mock::given(method("POST")).and(path("/msg/revoke_msg")).respond_with(err_response()).mount(&server).await;
        let api = make_api(&server);
        let req = RevokeMessageReq { conversation_id: "conv_1".to_string(), seq: 5, user_id: "user_1".to_string(), client_msg_id: "msg_1".to_string(), session_type: 1 };
        assert!(api.revoke_on_server(&req).await.is_err());
    }

    #[tokio::test]
    async fn test_delete_on_server_success() {
        let server = MockServer::start().await;
        Mock::given(method("POST")).and(path("/msg/delete_msgs")).respond_with(ok_response()).mount(&server).await;
        let api = make_api(&server);
        assert!(api.delete_on_server("conv_1", &[1, 2, 3], "user_1").await.is_ok());
    }

    #[tokio::test]
    async fn test_mark_conv_read_success() {
        let server = MockServer::start().await;
        Mock::given(method("POST")).and(path("/msg/mark_conversation_as_read")).respond_with(ok_response()).mount(&server).await;
        let api = make_api(&server);
        let req = MarkConversationAsReadReq { user_id: "user_1".to_string(), conversation_id: "conv_1".to_string(), has_read_seq: 10, seqs: vec![1, 2, 3] };
        assert!(api.mark_conversation_as_read_on_server(&req).await.is_ok());
    }

    #[tokio::test]
    async fn test_mark_msgs_read_success() {
        let server = MockServer::start().await;
        Mock::given(method("POST")).and(path("/msg/mark_msgs_as_read")).respond_with(ok_response()).mount(&server).await;
        let api = make_api(&server);
        let req = MarkMessagesAsReadReq { conversation_id: "conv_1".to_string(), user_id: "user_1".to_string(), session_type: 1, has_read_seq: 6, seqs: vec![5, 6] };
        assert!(api.mark_messages_as_read_on_server(&req).await.is_ok());
    }
}