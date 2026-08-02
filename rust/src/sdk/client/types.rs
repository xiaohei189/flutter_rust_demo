use crate::domain::model::message::MessageInfo;
use serde::{Deserialize, Serialize};

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
