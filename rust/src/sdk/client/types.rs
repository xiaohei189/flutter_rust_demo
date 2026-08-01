use crate::domain::constant::{ContentType, SessionType};
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
pub struct SearchMessagesReq {
    pub conversation_id: String,
    pub keyword: String,
}
