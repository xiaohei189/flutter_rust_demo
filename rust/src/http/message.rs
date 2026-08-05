//! 消息服务端 API 契约与请求体（Port）

use crate::error::Result;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

/// 撤回消息请求体（对齐服务端 `/msg/revoke_msg` API）
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

/// 删除消息请求体（对齐服务端 `/msg/delete_msgs` API）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DeleteMessagesReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "clientMsgIDs")]
    pub client_msg_ids: Vec<String>,
}

/// 按 seq 列表标记消息已读请求体（对齐服务端 `/msg/mark_msgs_as_read` API）
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

/// 标记整个会话为已读的请求（对齐 Go SDK `MarkConversationAsReadReq`）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MarkConversationAsReadReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "hasReadSeq")]
    pub has_read_seq: i64,
    #[serde(rename = "seqs")]
    pub seqs: Vec<i64>,
}

/// 批量标记所有会话为已读的请求
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MarkAllConversationAsReadReq {
    #[serde(rename = "conversationIDs")]
    pub conversation_ids: Vec<String>,
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "hasReadSeqs")]
    pub has_read_seqs: Vec<i64>,
}

/// 消息服务端 API 接口
///
/// 定义 MessageService 需要的所有远程操作。
/// 生产环境由 [`HttpMessageApi`](crate::http::message_api::HttpMessageApi) 实现，测试中可用 mock 替代。
#[async_trait]
pub trait MessageServerApi: Send + Sync {
    /// 通知服务端撤回消息
    async fn revoke_on_server(&self, req: &RevokeMessageReq) -> Result<()>;

    /// 通知服务端删除消息（按 seqs）
    async fn delete_on_server(&self, conversation_id: &str, seqs: &[i64], user_id: &str) -> Result<()>;

    /// 通知服务端标记会话已读
    async fn mark_conversation_as_read_on_server(&self, req: &MarkConversationAsReadReq) -> Result<()>;

    /// 通知服务端按 seq 列表标记消息已读
    async fn mark_messages_as_read_on_server(&self, req: &MarkMessagesAsReadReq) -> Result<()>;
}
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_revoke_message_req_serialization() {
        let req = RevokeMessageReq {
            conversation_id: "si_user_a_user_b".to_string(),
            seq: 100,
            user_id: "user_a".to_string(),
            client_msg_id: "msg_001".to_string(),
            session_type: 1,
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("conversationID"));
        assert!(json.contains("seq"));
        assert!(json.contains("userID"));
        assert!(json.contains("clientMsgID"));
        assert!(json.contains("sessionType"));
    }

    #[test]
    fn test_delete_messages_req_serialization() {
        let req = DeleteMessagesReq {
            conversation_id: "si_user_a_user_b".to_string(),
            client_msg_ids: vec!["msg_001".to_string(), "msg_002".to_string()],
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("conversationID"));
        assert!(json.contains("clientMsgIDs"));
        assert!(json.contains("msg_001"));
    }

    #[test]
    fn test_mark_messages_as_read_req_serialization() {
        let req = MarkMessagesAsReadReq {
            conversation_id: "si_user_a_user_b".to_string(),
            seqs: vec![1, 2, 3],
            user_id: "user_a".to_string(),
            has_read_seq: 0,
            session_type: 1,
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("conversationID"));
        assert!(json.contains("seqs"));
        assert!(json.contains("userID"));
    }
}
