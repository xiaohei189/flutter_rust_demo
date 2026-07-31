//! 消息服务 HTTP API 请求体定义
//!
//! 这些结构体与服务端 REST API 一一对应，仅用于 `MessageService` 内部序列化。

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
