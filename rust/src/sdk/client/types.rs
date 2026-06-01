use crate::domain::constant::enums::{ContentType, SessionType};
use crate::domain::model::message::MessageInfo;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SendMessageReq {
    pub recv_id: String,
    pub group_id: String,
    pub session_type: SessionType,
    pub content_type: ContentType,
    pub content: String,
    pub client_msg_id: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetHistoryMessagesReq {
    pub conversation_id: String,
    pub start_client_msg_id: String,
    pub count: i64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetHistoryMessagesResult {
    pub messages: Vec<MessageInfo>,
    pub is_end: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RevokeMessageReq {
    pub conversation_id: String,
    pub seq: i64,
    pub client_msg_id: String,
    pub session_type: SessionType,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeleteMessagesReq {
    pub conversation_id: String,
    pub client_msg_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MarkMessagesAsReadReq {
    pub conversation_id: String,
    pub session_type: SessionType,
    pub has_read_seq: i64,
    pub seqs: Vec<i64>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SearchMessagesReq {
    pub conversation_id: String,
    pub keyword: String,
}
