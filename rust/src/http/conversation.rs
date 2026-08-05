//! 会话同步契约与请求/响应 DTO（Port）
//!
//! 对齐 Go SDK `conversation.go` 中的请求体定义。

use crate::error::Result;
use async_trait::async_trait;
use serde::Deserializer;
use serde::{Deserialize, Serialize};

// ========== Request/Response Structs ==========

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetAllConversationsReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetAllConversationsResp {
    #[serde(default)]
    pub conversations: Option<Vec<ServerConversation>>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetIncrementalConversationReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub version: u64,
}

/// serde 反序列化辅助：将 JSON null 视为 Default（空 Vec 等）
fn deserialize_null_default<'de, D, T>(d: D) -> std::result::Result<T, D::Error>
where
    D: Deserializer<'de>,
    T: Default + Deserialize<'de>,
{
    Option::<T>::deserialize(d).map(|x| x.unwrap_or_default())
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetIncrementalConversationResp {
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub full: bool,
    #[serde(default, deserialize_with = "deserialize_null_default")]
    pub delete: Vec<String>,
    #[serde(default, deserialize_with = "deserialize_null_default")]
    pub insert: Vec<ServerConversation>,
    #[serde(default, deserialize_with = "deserialize_null_default")]
    pub update: Vec<ServerConversation>,
}

/// 按 ID 查询会话的请求（对齐 Go SDK `getConversationsByIDsFromServer`）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetConversationsByIDsReq {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    #[serde(rename = "conversationIDs")]
    pub conversation_ids: Vec<String>,
}

/// 按 ID 查询会话的响应
#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetConversationsByIDsResp {
    #[serde(default)]
    pub conversations: Option<Vec<ServerConversation>>,
}

/// 获取所有会话 ID 的请求（对齐 Go SDK `getAllConversationIDsFromServer`）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFullConversationIDsReq {
    #[serde(rename = "userID")]
    pub user_id: String,
}

/// 获取所有会话 ID 的响应（对齐 Go SDK `GetFullOwnerConversationIDsResp`）
#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetFullConversationIDsResp {
    pub version: u64,
    #[serde(rename = "versionID")]
    pub version_id: String,
    pub equal: bool,
    #[serde(default, rename = "conversationIDs", deserialize_with = "deserialize_null_default")]
    pub conversation_ids: Vec<String>,
}

/// 设置会话的请求体（对齐 Go SDK `SetConversationReq` / HTTP 路由 `/conversation/set_conversation`）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SetConversationReq {
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "recvMsgOpt", skip_serializing_if = "Option::is_none")]
    pub recv_msg_opt: Option<i32>,
    #[serde(rename = "isPinned", skip_serializing_if = "Option::is_none")]
    pub is_pinned: Option<bool>,
    #[serde(rename = "isPrivateChat", skip_serializing_if = "Option::is_none")]
    pub is_private_chat: Option<bool>,
    #[serde(rename = "groupAtType", skip_serializing_if = "Option::is_none")]
    pub group_at_type: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ex: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct ServerConversation {
    #[serde(rename = "ownerUserID", default)]
    pub owner_user_id: String,
    #[serde(rename = "conversationID", default)]
    pub conversation_id: String,
    #[serde(rename = "conversationType")]
    pub conversation_type: i32,
    #[serde(rename = "recvMsgOpt")]
    pub recv_msg_opt: i32,
    #[serde(rename = "userID", default)]
    pub user_id: String,
    #[serde(rename = "groupID", default)]
    pub group_id: String,
    #[serde(rename = "isPinned")]
    pub is_pinned: bool,
    #[serde(rename = "isPrivateChat")]
    pub is_private_chat: bool,
    #[serde(rename = "groupAtType")]
    pub group_at_type: i32,
    #[serde(default)]
    pub ex: String,
    #[serde(rename = "attachedInfo", default)]
    pub attached_info: String,
    #[serde(rename = "burnDuration")]
    pub burn_duration: i32,
    #[serde(rename = "minSeq")]
    pub min_seq: i64,
    #[serde(rename = "maxSeq")]
    pub max_seq: i64,
    #[serde(rename = "msgDestructTime")]
    pub msg_destruct_time: i64,
    #[serde(rename = "isMsgDestruct")]
    pub is_msg_destruct: bool,
}

/// 会话服务端 API 接口
///
/// 生产环境由 [`HttpConversationApi`](crate::http::conversation_api::HttpConversationApi) 实现，测试中可用 mock 替代。
#[async_trait]
pub trait ConversationServerApi: Send + Sync {
    /// 拉取所有会话
    async fn pull_all(&self, user_id: String) -> Result<GetAllConversationsResp>;

    /// 增量拉取会话
    async fn pull_incremental(&self, user_id: String, version: u64, version_id: String) -> Result<GetIncrementalConversationResp>;

    /// 按 ID 列表拉取会话
    async fn pull_conversations_by_ids(&self, user_id: String, conversation_ids: Vec<String>) -> Result<Vec<ServerConversation>>;

    /// 拉取所有会话 ID
    async fn pull_full_conversation_ids(&self, user_id: String) -> Result<GetFullConversationIDsResp>;

    /// 设置会话属性（对齐 Go SDK `SetConversation` / HTTP 路由 `/conversation/set_conversation`）
    async fn set_conversation_on_server(&self, req: &SetConversationReq) -> Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_set_conversation_req_serialization() {
        let req = SetConversationReq {
            conversation_id: "si_user_a_user_b".to_string(),
            recv_msg_opt: Some(2),
            is_pinned: Some(true),
            is_private_chat: None,
            group_at_type: None,
            ex: None,
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("recvMsgOpt"));
        assert!(json.contains("isPinned"));
        assert!(json.contains("true"));
    }
}
