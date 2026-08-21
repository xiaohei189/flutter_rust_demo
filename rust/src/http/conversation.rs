//! 会话同步契约与请求/响应 DTO（Port）
//!
//! 对齐 Go SDK `conversation.go` 中的请求体定义。

use crate::domain::error::Result;
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

/// 设置会话的请求体（对齐 Go SDK `SetConversationsReq` / HTTP 路由 `/conversation/set_conversations`）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SetConversationReq {
    #[serde(rename = "userIDs", skip_serializing_if = "Vec::is_empty")]
    pub user_ids: Vec<String>,
    #[serde(rename = "conversationID")]
    pub conversation_id: String,
    #[serde(rename = "conversationType", skip_serializing_if = "Option::is_none")]
    pub conversation_type: Option<i32>,
    #[serde(rename = "userID", skip_serializing_if = "Option::is_none")]
    pub user_id: Option<String>,
    #[serde(rename = "groupID", skip_serializing_if = "Option::is_none")]
    pub group_id: Option<String>,
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

/// 测试用 Mock ConversationServerApi（供 conversation 模块各文件测试共享）
#[cfg(test)]
pub(crate) struct MockConversationApi {
    pub(crate) all: Vec<ServerConversation>,
    pub(crate) incremental: GetIncrementalConversationResp,
    pub(crate) by_ids: Vec<ServerConversation>,
    pub(crate) full_ids: GetFullConversationIDsResp,
    pub(crate) set_fail: bool,
    pub(crate) set_calls: std::sync::Arc<std::sync::Mutex<Vec<SetConversationReq>>>,
    pub(crate) incremental_calls: std::sync::Arc<std::sync::Mutex<usize>>,
}

#[cfg(test)]
#[allow(dead_code)]
impl MockConversationApi {
    pub(crate) fn new() -> Self {
        Self {
            all: Vec::new(),
            incremental: GetIncrementalConversationResp::default(),
            by_ids: Vec::new(),
            full_ids: GetFullConversationIDsResp::default(),
            set_fail: false,
            set_calls: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
            incremental_calls: std::sync::Arc::new(std::sync::Mutex::new(0)),
        }
    }

    pub(crate) fn with_all(mut self, all: Vec<ServerConversation>) -> Self {
        self.all = all;
        self
    }

    pub(crate) fn with_incremental(mut self, incremental: GetIncrementalConversationResp) -> Self {
        self.incremental = incremental;
        self
    }

    pub(crate) fn with_by_ids(mut self, by_ids: Vec<ServerConversation>) -> Self {
        self.by_ids = by_ids;
        self
    }

    pub(crate) fn with_full_ids(mut self, full_ids: GetFullConversationIDsResp) -> Self {
        self.full_ids = full_ids;
        self
    }

    pub(crate) fn with_set_fail(mut self, set_fail: bool) -> Self {
        self.set_fail = set_fail;
        self
    }

    pub(crate) fn set_calls(&self) -> Vec<SetConversationReq> {
        self.set_calls.lock().unwrap().clone()
    }

    pub(crate) fn incremental_call_count(&self) -> usize {
        *self.incremental_calls.lock().unwrap()
    }
}

#[cfg(test)]
#[async_trait]
impl ConversationServerApi for MockConversationApi {
    async fn pull_all(&self, _user_id: String) -> Result<GetAllConversationsResp> {
        Ok(GetAllConversationsResp {
            conversations: Some(self.all.clone()),
        })
    }

    async fn pull_incremental(&self, _user_id: String, _version: u64, _version_id: String) -> Result<GetIncrementalConversationResp> {
        *self.incremental_calls.lock().unwrap() += 1;
        Ok(self.incremental.clone())
    }

    async fn pull_conversations_by_ids(&self, _user_id: String, _conversation_ids: Vec<String>) -> Result<Vec<ServerConversation>> {
        Ok(self.by_ids.clone())
    }

    async fn pull_full_conversation_ids(&self, _user_id: String) -> Result<GetFullConversationIDsResp> {
        Ok(self.full_ids.clone())
    }

    async fn set_conversation_on_server(&self, req: &SetConversationReq) -> Result<()> {
        if self.set_fail {
            return Err(crate::domain::error::SdkError::network("mock server failure".to_string()));
        }
        self.set_calls.lock().unwrap().push(req.clone());
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_set_conversation_req_serialization() {
        let req = SetConversationReq {
            user_ids: vec!["user_a".to_string()],
            conversation_id: "si_user_a_user_b".to_string(),
            conversation_type: Some(1),
            user_id: Some("user_a".to_string()),
            group_id: None,
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
        assert!(json.contains("userIDs"));
    }
}
