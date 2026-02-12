use crate::im::model::common::deserialize_vec_or_null;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
/// 增量会话响应（业务逻辑层结构体，可直接从 API 响应反序列化）
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct IncrementalConversationResp {
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub full: bool,
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub delete: Vec<String>,
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub insert: Vec<LocalConversation>,
    #[serde(deserialize_with = "deserialize_vec_or_null")]
    pub update: Vec<LocalConversation>,
}

/// 全量会话响应（业务逻辑层结构体，可直接从 API 响应反序列化）
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AllConversationsResp {
    pub conversations: Vec<LocalConversation>,
}

/// 本地会话数据结构
/// 可以直接从服务器返回的 JSON 反序列化，缺失的字段使用默认值
/// 同时实现 FromRow 用于 sqlx 直接映射数据库行（SQLite INTEGER 0/1 自动转为 bool）
#[derive(Debug, Clone, Serialize, Deserialize, Default, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct LocalConversation {
    /// 会话 ID
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    /// 会话类型：1=单聊, 2=普通群聊, 3=超级群聊, 4=通知会话
    pub conversation_type: i32,
    /// 用户 ID（单聊时使用）
    #[serde(default)]
    pub user_id: String,
    /// 群组 ID（群聊时使用）
    #[serde(default)]
    pub group_id: String,
    /// 显示名称（服务器不返回，需要从用户/群组信息获取）
    #[serde(default)]
    pub show_name: String,
    /// 头像 URL（服务器不返回，需要从用户/群组信息获取）
    #[serde(default)]
    pub face_url: String,
    /// 最新消息（服务器不返回，需要从消息获取）
    #[serde(default)]
    pub latest_msg: String,
    /// 最新消息发送时间（服务器不返回，需要从消息获取）
    #[serde(default)]
    pub latest_msg_send_time: i64,
    /// 未读消息数（服务器可能不返回）
    #[serde(default)]
    pub unread_count: i32,
    /// 接收消息选项：0=接收并通知, 1=接收但不通知, 2=屏蔽
    #[serde(default)]
    pub recv_msg_opt: i32,
    /// 是否置顶
    #[serde(default)]
    pub is_pinned: bool,
    /// 是否私聊
    #[serde(default)]
    pub is_private_chat: bool,
    /// 阅后即焚时长（秒）
    #[serde(default)]
    pub burn_duration: i32,
    /// 群@类型：0=正常, 1=@我, 2=@所有人
    #[serde(default)]
    pub group_at_type: i32,
    /// 是否不在群中
    #[serde(default)]
    pub is_not_in_group: bool,
    /// 更新未读数时间
    #[serde(default)]
    pub update_unread_count_time: i64,
    /// 附加信息
    #[serde(default)]
    pub attached_info: String,
    /// 扩展信息
    #[serde(default)]
    pub ex: String,
    /// 草稿文本
    #[serde(default)]
    pub draft_text: String,
    /// 草稿文本时间
    #[serde(default)]
    pub draft_text_time: i64,
    /// 最大序列号
    #[serde(default)]
    pub max_seq: i64,
    /// 最小序列号
    #[serde(default)]
    pub min_seq: i64,
    /// 是否消息销毁
    #[serde(default)]
    pub is_msg_destruct: bool,
    /// 消息销毁时间
    #[serde(default)]
    pub msg_destruct_time: i64,
}

// ---------- API 请求/响应模型（从 conversation/models.rs 迁移） ----------

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EmptyResp {}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetSortedConversationListReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "conversationIDs", default)]
    pub conversation_ids: Vec<String>,
    #[serde(rename = "pagination", default)]
    pub pagination: RequestPagination,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RequestPagination {
    #[serde(rename = "pageNumber")]
    pub page_number: i32,
    #[serde(rename = "showNumber")]
    pub show_number: i32,
}

impl Default for RequestPagination {
    fn default() -> Self {
        RequestPagination { page_number: 1, show_number: 20 }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ConversationElem {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "isPinned", default)]
    pub is_pinned: bool,
    #[serde(rename = "recvMsgOpt", default)]
    pub recv_msg_opt: i32,
    #[serde(rename = "msgInfo", skip_serializing_if = "Option::is_none")]
    pub msg_info: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GetSortedConversationListResp {
    #[serde(rename = "conversationTotal", default)]
    pub conversation_total: i64,
    #[serde(rename = "conversationElems", default)]
    pub conversation_elems: Vec<ConversationElem>,
    #[serde(rename = "unreadTotal", default)]
    pub unread_total: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetConversationReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GetConversationResp {
    #[serde(rename = "conversation", skip_serializing_if = "Option::is_none")]
    pub conversation: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetConversationsReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "conversationIDs")]
    pub conversation_ids: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GetConversationsResp {
    #[serde(rename = "conversations", default)]
    pub conversations: Vec<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SetConversationsReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "conversationIDs")]
    pub conversation_ids: Vec<String>,
    #[serde(rename = "recvMsgOpt", default)]
    pub recv_msg_opt: i32,
    #[serde(rename = "isPinned", default)]
    pub is_pinned: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OwnerConversationReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ConversationIDsResp {
    #[serde(rename = "conversationIDs", default)]
    pub conversation_ids: Vec<String>,
}

/// 版本同步信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LocalVersionSync {
    /// 表名
    #[serde(rename = "tableName")]
    pub table_name: String,
    /// 实体 ID（用户 ID）
    #[serde(rename = "entityID")]
    pub entity_id: String,
    /// 版本号
    pub version: u64,
    /// 版本 ID
    #[serde(rename = "versionID")]
    pub version_id: String,
}

/// 会话同步器配置
pub struct ConversationSyncerConfig {
    /// 用户 ID
    pub user_id: String,
    /// API 基础 URL
    pub api_base_url: String,
    /// Token
    pub token: String,
    /// 数据库路径（SQLite），可以是：
    /// - 相对路径：如 "conversations.db" 会转换为 "sqlite://conversations.db"
    /// - 绝对路径：如 "/path/to/db.db" 会转换为 "sqlite:///path/to/db.db"
    /// - 完整URL：如 "sqlite://conversations.db" 直接使用
    pub db_path: String,
}

impl ConversationSyncerConfig {}

// 实体定义已迁移到 dao 层，保留兼容说明
