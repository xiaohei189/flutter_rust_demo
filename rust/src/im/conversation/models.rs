//! 会话本地模型定义

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EmptyResp {}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetSortedConversationListReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "conversationIDs", default)]
    pub conversation_ids: Vec<String>,
    #[serde(rename = "pagination",default)]
    pub pagination: RequestPagination,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RequestPagination {
    #[serde(rename = "pageNumber",)]
    pub page_number: i32,
    #[serde(rename = "showNumber")]
    pub show_number: i32,
}


impl Default for RequestPagination {
    fn default() -> Self {
        RequestPagination {
            page_number: 1,
            show_number: 20,
        }
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

