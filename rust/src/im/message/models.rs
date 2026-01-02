//! 消息本地模型定义

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// 本地聊天记录结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LocalChatLog {
    pub conversation_id: String,
    pub client_msg_id: String,
    pub server_msg_id: String,
    pub send_id: String,
    pub recv_id: String,
    pub sender_platform_id: i32,
    pub sender_nickname: String,
    pub sender_face_url: String,
    pub session_type: i32,
    pub msg_from: i32,
    pub content_type: i32,
    pub content: String,
    pub is_read: bool,
    pub status: i32,
    pub seq: i64,
    pub send_time: i64,
    pub create_time: i64,
    pub attached_info: String,
    pub ex: String,
    pub local_ex: String,
    pub group_id: String,
}

/// /msg/send_msg 请求体，对齐 open-im-server pkg/apistruct/manage.go::SendMsgReq
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SendMsgReq {
    #[serde(rename = "recvID", skip_serializing_if = "Option::is_none")]
    pub recv_id: Option<String>,
    #[serde(rename = "groupID", skip_serializing_if = "Option::is_none")]
    pub group_id: Option<String>,
    #[serde(rename = "sendID")]
    pub send_id: String,
    #[serde(rename = "senderNickname", skip_serializing_if = "Option::is_none")]
    pub sender_nickname: Option<String>,
    #[serde(rename = "senderFaceURL", skip_serializing_if = "Option::is_none")]
    pub sender_face_url: Option<String>,
    #[serde(rename = "senderPlatformID", skip_serializing_if = "Option::is_none")]
    pub sender_platform_id: Option<i32>,
    #[serde(rename = "content")]
    pub content: serde_json::Value,
    #[serde(rename = "contentType")]
    pub content_type: i32,
    #[serde(rename = "sessionType")]
    pub session_type: i32,
    #[serde(rename = "isOnlineOnly", default)]
    pub is_online_only: bool,
    #[serde(rename = "notOfflinePush", default)]
    pub not_offline_push: bool,
    #[serde(rename = "sendTime", skip_serializing_if = "Option::is_none")]
    pub send_time: Option<i64>,
    #[serde(rename = "offlinePushInfo", skip_serializing_if = "Option::is_none")]
    pub offline_push_info: Option<serde_json::Value>,
    #[serde(rename = "ex", skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
}

/// /msg/revoke_msg 请求体，对齐 apistruct.RevokeElem + 必要的上下文字段
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RevokeMsgReq {
    #[serde(rename = "revokeMsgClientID")]
    pub revoke_msg_client_id: String,
    #[serde(rename = "conversationID", skip_serializing_if = "Option::is_none")]
    pub conversation_id: Option<String>,
    #[serde(rename = "userID", skip_serializing_if = "Option::is_none")]
    pub user_id: Option<String>,
    #[serde(rename = "seq", skip_serializing_if = "Option::is_none")]
    pub seq: Option<u32>,
    #[serde(rename = "sessionType", skip_serializing_if = "Option::is_none")]
    pub session_type: Option<i32>,
}

/// /msg/mark_msgs_as_read 请求体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MarkMsgsAsReadReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "seqs")]
    pub seqs: Vec<i64>,
    #[serde(rename = "userID")]
    pub user_id: String,
}

/// /msg/mark_conversation_as_read
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MarkConversationAsReadReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "hasReadSeq")]
    pub has_read_seq: i64,
    #[serde(rename = "seqs", default)]
    pub seqs: Vec<i64>,
}

/// /msg/set_conversation_has_read_seq
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SetConversationHasReadSeqReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "hasReadSeq")]
    pub has_read_seq: i64,
    #[serde(rename = "noNotification", default)]
    pub no_notification: bool,
}

/// 删除同步选项
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct DeleteSyncOpt {
    #[serde(rename = "IsSyncSelf", default)]
    pub is_sync_self: bool,
    #[serde(rename = "IsSyncOther", default)]
    pub is_sync_other: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClearConversationsMsgReq {
    #[serde(rename = "conversationIDs")]
    pub conversation_ids: Vec<String>,
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "deleteSyncOpt", skip_serializing_if = "Option::is_none")]
    pub delete_sync_opt: Option<DeleteSyncOpt>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserClearAllMsgReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "deleteSyncOpt", skip_serializing_if = "Option::is_none")]
    pub delete_sync_opt: Option<DeleteSyncOpt>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeleteMsgsReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "seqs")]
    pub seqs: Vec<i64>,
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "deleteSyncOpt", skip_serializing_if = "Option::is_none")]
    pub delete_sync_opt: Option<DeleteSyncOpt>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeleteMsgPhysicalReq {
    #[serde(rename = "conversationIDs")]
    pub conversation_ids: Vec<String>,
    #[serde(rename = "timestamp")]
    pub timestamp: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct DeleteMsgPhysicalBySeqReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "seqs")]
    pub seqs: Vec<i64>,
}

/// /msg/check_msg_is_send_success
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckMsgIsSendSuccessReq {
    #[serde(rename = "clientMsgID")]
    pub client_msg_id: String,
    #[serde(rename = "conversationID", skip_serializing_if = "Option::is_none")]
    pub conversation_id: Option<String>,
    #[serde(rename = "userID", skip_serializing_if = "Option::is_none")]
    pub user_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CheckMsgIsSendSuccessResp {
    #[serde(rename = "isSendSuccess")]
    pub is_send_success: bool,
}

/// /msg/send_business_notification
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SendBusinessNotificationReq {
    pub key: Option<String>,
    pub data: Option<String>,
    #[serde(rename = "sendUserID")]
    pub send_user_id: String,
    #[serde(rename = "recvUserID", skip_serializing_if = "Option::is_none")]
    pub recv_user_id: Option<String>,
    #[serde(rename = "recvGroupID", skip_serializing_if = "Option::is_none")]
    pub recv_group_id: Option<String>,
    #[serde(rename = "sendMsg", default)]
    pub send_msg: bool,
    #[serde(rename = "reliabilityLevel", skip_serializing_if = "Option::is_none")]
    pub reliability_level: Option<i32>,
}

/// /msg/newest_seq
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetNewestSeqReq {
    #[serde(rename = "userID")]
    pub user_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GetNewestSeqResp {
    #[serde(rename = "maxSeqs", default)]
    pub max_seqs: HashMap<String, i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SeqRange {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "begin")]
    pub begin: i64,
    #[serde(rename = "end")]
    pub end: i64,
    #[serde(rename = "num", default)]
    pub num: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PullMessageBySeqsReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "seqRanges")]
    pub seq_ranges: Vec<SeqRange>,
    #[serde(rename = "order", default)]
    pub order: i32, // 0 asc, 1 desc
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PullMsgs {
    #[serde(rename = "Msgs", default)]
    pub msgs: Vec<crate::im::message::types::MsgStruct>,
    #[serde(rename = "isEnd", default)]
    pub is_end: bool,
    #[serde(rename = "endSeq", default)]
    pub end_seq: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatchSendMsgReq {
    #[serde(rename = "recvIDList")]
    pub recv_id_list: Vec<String>,
    #[serde(rename = "msgData")]
    pub msg_data: crate::im::message::types::MsgStruct,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SendSimpleMsgReq {
    #[serde(rename = "msgData")]
    pub msg_data: crate::im::message::types::MsgStruct,
}

/// /msg/search_msg
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchMessageReq {
    #[serde(rename = "conversationID", skip_serializing_if = "Option::is_none")]
    pub conversation_id: Option<String>,
    #[serde(rename = "keywordList", default)]
    pub keyword_list: Vec<String>,
    #[serde(rename = "keywordListMatchType", default)]
    pub keyword_list_match_type: i32,
    #[serde(rename = "senderUserIDList", default)]
    pub sender_user_id_list: Vec<String>,
    #[serde(rename = "messageTypeList", default)]
    pub message_type_list: Vec<i32>,
    #[serde(rename = "searchTimePosition", default)]
    pub search_time_position: i64,
    #[serde(rename = "searchTimePeriod", default)]
    pub search_time_period: i64,
    #[serde(rename = "pageNumber", default = "default_page_number")]
    pub page_number: i32,
    #[serde(rename = "count", default = "default_page_size")]
    pub count: i32,
    #[serde(rename = "offset", default)]
    pub offset: i32,
    #[serde(rename = "disableGroup", default)]
    pub disable_group: bool,
    #[serde(rename = "disableSingle", default)]
    pub disable_single: bool,
}

fn default_page_number() -> i32 {
    1
}

fn default_page_size() -> i32 {
    20
}

// ---------- Response structs ----------

/// /msg/send_msg
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SendMsgResp {
    #[serde(rename = "serverMsgID")]
    pub server_msg_id: String,
    #[serde(rename = "clientMsgID")]
    pub client_msg_id: String,
    #[serde(rename = "sendTime")]
    pub send_time: i64,
    #[serde(rename = "modify", skip_serializing_if = "Option::is_none")]
    pub modify: Option<crate::im::message::types::MsgStruct>,
}

/// /msg/get_server_time
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ServerTimeResp {
    #[serde(rename = "serverTime")]
    pub server_time: i64,
}

/// /msg/pull_msg_by_seq
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PullMessageBySeqsResp {
    #[serde(rename = "msgs", default)]
    pub msgs: HashMap<String, PullMsgs>,
    #[serde(rename = "notificationMsgs", default)]
    pub notification_msgs: HashMap<String, PullMsgs>,
}

/// /msg/search_msg
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SearchMessageResp {
    #[serde(rename = "chatLogs", default)]
    pub chat_logs: Vec<serde_json::Value>,
    #[serde(rename = "chatLogsNum", default)]
    pub chat_logs_num: i32,
}

/// 空响应
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EmptyResp {}

