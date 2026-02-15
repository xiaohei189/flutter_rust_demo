//! 消息相关模型与类型，合并自 `im/message/models.rs` 与 `im/message/types.rs`

use anyhow::Result;
use openim_protocol::constant;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use std::collections::HashMap;
use tracing::warn;

// ---------- 本地存储模型 ----------

/// 本地聊天记录结构体
///
/// 实现 `FromRow` 用于从按会话分表的 message 表查询；查询时需包含 conversation_id（如 `SELECT ? as conversation_id, * FROM msg_xxx`）。
/// SQLite 中 is_read 存为 INTEGER 0/1，sqlx 会映射为 bool。
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
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

// ---------- 请求体 ----------

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

/// /msg/pull_msg_by_seq
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PullMsgs {
    #[serde(rename = "Msgs", default)]
    pub msgs: Vec<MsgStruct>,
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
    pub msg_data: MsgStruct,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SendSimpleMsgReq {
    #[serde(rename = "msgData")]
    pub msg_data: MsgStruct,
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

// ---------- 响应体 ----------

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
    pub modify: Option<MsgStruct>,
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

// ---------- 消息元素与结构 ----------

/// 图片基础信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PictureBaseInfo {
    #[serde(rename = "uuid")]
    pub uuid: String,
    #[serde(rename = "type")]
    pub r#type: String,
    #[serde(rename = "size")]
    pub size: i64,
    #[serde(rename = "width")]
    pub width: i32,
    #[serde(rename = "height")]
    pub height: i32,
    #[serde(rename = "url")]
    pub url: String,
}

/// 图片元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PictureElem {
    #[serde(rename = "sourcePath")]
    pub source_path: String,
    #[serde(rename = "sourcePicture")]
    pub source_picture: PictureBaseInfo,
    #[serde(rename = "bigPicture")]
    pub big_picture: PictureBaseInfo,
    #[serde(rename = "snapshotPicture")]
    pub snapshot_picture: PictureBaseInfo,
}

/// 语音元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SoundElem {
    #[serde(rename = "uuid")]
    pub uuid: String,
    #[serde(rename = "soundPath")]
    pub sound_path: String,
    #[serde(rename = "sourceUrl")]
    pub source_url: String,
    #[serde(rename = "dataSize")]
    pub data_size: i64,
    #[serde(rename = "duration")]
    pub duration: i64,
}

/// 视频元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoElem {
    #[serde(rename = "videoPath")]
    pub video_path: String,
    #[serde(rename = "videoUUID")]
    pub video_uuid: String,
    #[serde(rename = "videoUrl")]
    pub video_url: String,
    #[serde(rename = "videoType")]
    pub video_type: String,
    #[serde(rename = "videoSize")]
    pub video_size: i64,
    #[serde(rename = "duration")]
    pub duration: i64,
    #[serde(rename = "snapshotPath")]
    pub snapshot_path: String,
    #[serde(rename = "snapshotUUID")]
    pub snapshot_uuid: String,
    #[serde(rename = "snapshotSize")]
    pub snapshot_size: i64,
    #[serde(rename = "snapshotUrl")]
    pub snapshot_url: String,
    #[serde(rename = "snapshotWidth")]
    pub snapshot_width: i32,
    #[serde(rename = "snapshotHeight")]
    pub snapshot_height: i32,
}

/// 文件元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileElem {
    #[serde(rename = "filePath")]
    pub file_path: String,
    #[serde(rename = "uuid")]
    pub uuid: String,
    #[serde(rename = "sourceUrl")]
    pub source_url: String,
    #[serde(rename = "fileName")]
    pub file_name: String,
    #[serde(rename = "fileSize")]
    pub file_size: i64,
}

/// @ 元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AtElem {
    #[serde(rename = "text")]
    pub text: String,
    #[serde(rename = "atUserList")]
    pub at_user_list: Vec<String>,
    #[serde(rename = "atUsersInfo")]
    pub at_users_info: Option<Vec<AtInfo>>,
    #[serde(rename = "quoteMessage")]
    pub quote_message: Option<Box<MsgStruct>>,
    #[serde(rename = "isAtSelf")]
    pub is_at_self: bool,
}

/// 位置元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LocationElem {
    #[serde(rename = "description")]
    pub description: String,
    #[serde(rename = "longitude")]
    pub longitude: f64,
    #[serde(rename = "latitude")]
    pub latitude: f64,
}

/// 自定义元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CustomElem {
    #[serde(rename = "data")]
    pub data: String,
    #[serde(rename = "description")]
    pub description: String,
    #[serde(rename = "extension")]
    pub extension: String,
}

/// 文本元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TextElem {
    #[serde(rename = "content")]
    pub content: String,
}

/// Markdown 文本元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MarkdownTextElem {
    #[serde(rename = "content")]
    pub content: String,
}

/// Markdown + 实体（扩展用）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MarkdownEntityElem {
    #[serde(rename = "content")]
    pub content: String,
    #[serde(rename = "messageEntityList", skip_serializing_if = "Option::is_none")]
    pub message_entity_list: Option<String>,
}

/// 流式消息元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreamMsgElem {
    #[serde(rename = "type")]
    pub r#type: String,
    #[serde(rename = "content")]
    pub content: String,
}

/// 撤回元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RevokeElem {
    #[serde(rename = "revokeMsgClientID")]
    pub revoke_msg_client_id: String,
}

/// 引用元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuoteElem {
    #[serde(rename = "text", skip_serializing_if = "Option::is_none")]
    pub text: Option<String>,
    #[serde(rename = "quoteMessage", skip_serializing_if = "Option::is_none")]
    pub quote_message: Option<Box<MsgStruct>>,
}

/// 图片/语音/视频/文件/自定义等混排通知元素
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OANotificationElem {
    #[serde(rename = "notificationName")]
    pub notification_name: String,
    #[serde(rename = "notificationFaceURL")]
    pub notification_face_url: String,
    #[serde(rename = "notificationType")]
    pub notification_type: i32,
    #[serde(rename = "text")]
    pub text: String,
    #[serde(rename = "url")]
    pub url: String,
    #[serde(rename = "mixType")]
    pub mix_type: i32,
    #[serde(rename = "pictureElem", skip_serializing_if = "Option::is_none")]
    pub picture_elem: Option<PictureElem>,
    #[serde(rename = "soundElem", skip_serializing_if = "Option::is_none")]
    pub sound_elem: Option<SoundElem>,
    #[serde(rename = "videoElem", skip_serializing_if = "Option::is_none")]
    pub video_elem: Option<VideoElem>,
    #[serde(rename = "fileElem", skip_serializing_if = "Option::is_none")]
    pub file_elem: Option<FileElem>,
    #[serde(rename = "ex")]
    pub ex: String,
}

/// 消息撤回信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageRevoked {
    #[serde(rename = "revokerID")]
    pub revoker_id: String,
    #[serde(rename = "revokerRole")]
    pub revoker_role: i32,
    #[serde(rename = "clientMsgID")]
    pub client_msg_id: String,
    #[serde(rename = "revokerNickname")]
    pub revoker_nickname: String,
    #[serde(rename = "sessionType")]
    pub session_type: i32,
    #[serde(rename = "seq")]
    pub seq: u32,
}

/// 获取高级历史消息列表参数（完全匹配 Go SDK 的 GetAdvancedHistoryMessageListParams）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetAdvancedHistoryMessageListParams {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "startClientMsgID")]
    pub start_client_msg_id: String,
    #[serde(rename = "count")]
    pub count: i32,
    #[serde(rename = "viewType")]
    pub view_type: i32,
}

/// 获取高级历史消息列表回调（完全匹配 Go SDK 的 GetAdvancedHistoryMessageListCallback）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetAdvancedHistoryMessageListCallback {
    #[serde(rename = "messageList")]
    pub message_list: Vec<MsgStruct>,
    #[serde(rename = "isEnd")]
    pub is_end: bool,
    #[serde(rename = "errCode")]
    pub err_code: i32,
    #[serde(rename = "errMsg")]
    pub err_msg: String,
}

/// 消息结构体（对应 Go 的 MsgStruct）
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct MsgStruct {
    #[serde(rename = "clientMsgID", skip_serializing_if = "Option::is_none")]
    pub client_msg_id: Option<String>,
    #[serde(rename = "serverMsgID", skip_serializing_if = "Option::is_none")]
    pub server_msg_id: Option<String>,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    #[serde(rename = "sendTime")]
    pub send_time: i64,
    #[serde(rename = "sessionType")]
    pub session_type: i32,
    #[serde(rename = "sendID", skip_serializing_if = "Option::is_none")]
    pub send_id: Option<String>,
    #[serde(rename = "recvID", skip_serializing_if = "Option::is_none")]
    pub recv_id: Option<String>,
    #[serde(rename = "msgFrom")]
    pub msg_from: i32,
    #[serde(rename = "contentType")]
    pub content_type: i32,
    #[serde(rename = "senderPlatformID")]
    pub sender_platform_id: i32,
    #[serde(rename = "senderNickname", skip_serializing_if = "Option::is_none")]
    pub sender_nickname: Option<String>,
    #[serde(rename = "senderFaceUrl", skip_serializing_if = "Option::is_none")]
    pub sender_face_url: Option<String>,
    #[serde(rename = "groupID", skip_serializing_if = "Option::is_none")]
    pub group_id: Option<String>,
    #[serde(rename = "content", skip_serializing_if = "Option::is_none")]
    pub content: Option<String>,
    #[serde(rename = "seq")]
    pub seq: i64,
    #[serde(rename = "isRead")]
    pub is_read: bool,
    #[serde(rename = "status")]
    pub status: i32,
    #[serde(rename = "isReact", skip_serializing_if = "Option::is_none")]
    pub is_react: Option<bool>,
    #[serde(rename = "isExternalExtensions", skip_serializing_if = "Option::is_none")]
    pub is_external_extensions: Option<bool>,
    // OfflinePushInfo 是 protobuf 生成的结构体，不支持 serde 序列化
    // 如果需要序列化，可以通过 protobuf 的 encode/decode 方法处理
    #[serde(skip)]
    pub offline_push: Option<openim_protocol::sdkws::OfflinePushInfo>,
    #[serde(rename = "attachedInfo", skip_serializing_if = "Option::is_none")]
    pub attached_info: Option<String>,
    #[serde(rename = "ex", skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
    #[serde(rename = "localEx", skip_serializing_if = "Option::is_none")]
    pub local_ex: Option<String>,
    #[serde(rename = "textElem", skip_serializing_if = "Option::is_none")]
    pub text_elem: Option<TextElem>,
    #[serde(rename = "pictureElem", skip_serializing_if = "Option::is_none")]
    pub picture_elem: Option<PictureElem>,
    #[serde(rename = "soundElem", skip_serializing_if = "Option::is_none")]
    pub sound_elem: Option<SoundElem>,
    #[serde(rename = "videoElem", skip_serializing_if = "Option::is_none")]
    pub video_elem: Option<VideoElem>,
    #[serde(rename = "fileElem", skip_serializing_if = "Option::is_none")]
    pub file_elem: Option<FileElem>,
    #[serde(rename = "atTextElem", skip_serializing_if = "Option::is_none")]
    pub at_text_elem: Option<AtElem>,
    #[serde(rename = "locationElem", skip_serializing_if = "Option::is_none")]
    pub location_elem: Option<LocationElem>,
    #[serde(rename = "customElem", skip_serializing_if = "Option::is_none")]
    pub custom_elem: Option<CustomElem>,
    #[serde(rename = "quoteElem", skip_serializing_if = "Option::is_none")]
    pub quote_elem: Option<QuoteElem>,
}

/// @ 用户信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AtInfo {
    #[serde(rename = "atUserID", skip_serializing_if = "Option::is_none")]
    pub at_user_id: Option<String>,
    #[serde(rename = "groupNickname", skip_serializing_if = "Option::is_none")]
    pub group_nickname: Option<String>,
}

/// 输入提示（typing）状态信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypingStatus {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "sendID", skip_serializing_if = "Option::is_none")]
    pub send_id: Option<String>,
    #[serde(rename = "msgTip")]
    pub msg_tip: String,
}

/// 解析 attached_info JSON，当 is_not_private 为 false 时设置 isPrivateChat=true 并写回（对齐 Go !isNotPrivate -> AttachedInfoElem.IsPrivateChat = true）
fn attached_info_apply_is_private_impl(attached_info: &str, is_not_private: bool) -> String {
    let mut obj: serde_json::Map<String, serde_json::Value> = serde_json::from_str(attached_info).unwrap_or_default();
    if !is_not_private {
        obj.insert("isPrivateChat".to_string(), serde_json::Value::Bool(true));
    }
    serde_json::to_string(&obj).unwrap_or_else(|_| attached_info.to_string())
}

/// 按 contentType 解析消息 content（对齐 Go msgHandleByContentType）：反序列化后再序列化回 JSON 存库，解析失败则保留原 content。
pub fn msg_handle_by_content_type(content: &[u8], content_type: i32) -> String {
    let raw = String::from_utf8_lossy(content);
    let normalized = match content_type {
        constant::TEXT => serde_json::from_str::<TextElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::PICTURE => serde_json::from_str::<PictureElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::VOICE => serde_json::from_str::<SoundElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::VIDEO => serde_json::from_str::<VideoElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::FILE => serde_json::from_str::<FileElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::AT_TEXT => serde_json::from_str::<AtElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::LOCATION => serde_json::from_str::<LocationElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::CUSTOM | constant::CUSTOM_NOT_TRIGGER_CONVERSATION | constant::CUSTOM_ONLINE_ONLY => {
            serde_json::from_str::<CustomElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok())
        }
        constant::TYPING => serde_json::from_str::<serde_json::Value>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::QUOTE => serde_json::from_str::<QuoteElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::MERGER => serde_json::from_str::<serde_json::Value>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::CARD => serde_json::from_str::<serde_json::Value>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::MARKDOWN_TEXT => serde_json::from_str::<MarkdownTextElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        _ => serde_json::from_str::<serde_json::Value>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
    };
    match normalized {
        Some(s) => s,
        None => {
            if !raw.is_empty() && serde_json::from_str::<serde_json::Value>(&raw).is_err() {
                warn!("[msg_handle_by_content_type] parse error contentType={} content_len={}", content_type, content.len());
            }
            raw.into_owned()
        }
    }
}

/// 与 Go msgHandleByContentType 对齐的 Result 版本：解析失败时返回 Err，供 do_msg_new 跳过该条消息
pub fn msg_handle_by_content_type_result(content: &[u8], content_type: i32) -> Result<String> {
    let raw = String::from_utf8_lossy(content);
    let normalized = match content_type {
        constant::TEXT => serde_json::from_str::<TextElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::PICTURE => serde_json::from_str::<PictureElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::VOICE => serde_json::from_str::<SoundElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::VIDEO => serde_json::from_str::<VideoElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::FILE => serde_json::from_str::<FileElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::AT_TEXT => serde_json::from_str::<AtElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::LOCATION => serde_json::from_str::<LocationElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::CUSTOM | constant::CUSTOM_NOT_TRIGGER_CONVERSATION | constant::CUSTOM_ONLINE_ONLY => {
            serde_json::from_str::<CustomElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok())
        }
        constant::TYPING => serde_json::from_str::<serde_json::Value>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::QUOTE => serde_json::from_str::<QuoteElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::MERGER => serde_json::from_str::<serde_json::Value>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::CARD => serde_json::from_str::<serde_json::Value>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        constant::MARKDOWN_TEXT => serde_json::from_str::<MarkdownTextElem>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
        _ => serde_json::from_str::<serde_json::Value>(&raw).ok().and_then(|e| serde_json::to_string(&e).ok()),
    };
    match normalized {
        Some(s) => Ok(s),
        None => Err(anyhow::anyhow!(
            "msg_handle_by_content_type parse error contentType={} content_len={}",
            content_type,
            content.len()
        )),
    }
}

/// 解析 attached_info，当 is_not_private 为 false 时设置 isPrivateChat=true 并写回 JSON（对齐 Go !isNotPrivate -> AttachedInfoElem.IsPrivateChat = true）
pub fn attached_info_apply_is_private(attached_info: &str, is_not_private: bool) -> String {
    attached_info_apply_is_private_impl(attached_info, is_not_private)
}
