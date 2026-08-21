//! 会话相关 FFI 桥接

use crate::domain::constant::SessionType;
use crate::api::ffi::client::OpenIMBridgeClient;
use anyhow::Result;

impl OpenIMBridgeClient {
    // ========== 会话操作 ==========

    #[flutter_rust_bridge::frb]
    pub async fn get_conversations(&self) -> Result<Vec<crate::domain::model::local::LocalConversation>> {
        self.inner.get_conversations().await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_conversation(&self, conversation_id: String) -> Result<Option<crate::domain::model::local::LocalConversation>> {
        self.inner.get_conversation(&conversation_id).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn update_conversation_unread_count(&self, conversation_id: String, unread_count: i64) -> Result<()> {
        self.inner.update_conversation_unread_count(&conversation_id, unread_count).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_conversation_pinned(&self, conversation_id: String, is_pinned: bool) -> Result<()> {
        self.inner.set_conversation_pinned(&conversation_id, is_pinned).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn delete_conversation(&self, conversation_id: String) -> Result<()> {
        self.inner.delete_conversation(&conversation_id).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_conversation_draft(&self, conversation_id: String, draft_text: String) -> Result<()> {
        self.inner.set_conversation_draft(&conversation_id, &draft_text).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_conversation_private(&self, conversation_id: String, is_private: bool) -> Result<()> {
        self.inner.set_conversation_private(&conversation_id, is_private).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_pinned_conversations(&self) -> Result<Vec<crate::domain::model::local::LocalConversation>> {
        self.inner.get_pinned_conversations().await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn clear_conversation_draft(&self, conversation_id: String) -> Result<()> {
        self.inner.clear_conversation_draft(&conversation_id).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 分页获取会话列表（对齐 Go SDK `GetConversationListSplit`）
    #[flutter_rust_bridge::frb]
    pub async fn get_conversation_list_split(&self, offset: i64, count: i64) -> Result<Vec<crate::domain::model::local::LocalConversation>> {
        self.inner.get_conversation_list_split(offset, count).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 按 ID 列表批量获取会话（对齐 Go SDK `GetMultipleConversation`）
    #[flutter_rust_bridge::frb]
    pub async fn get_multiple_conversations(&self, conversation_ids: Vec<String>) -> Result<Vec<crate::domain::model::local::LocalConversation>> {
        self.inner.get_multiple_conversations(conversation_ids).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 搜索会话（对齐 Go SDK `SearchConversation`）
    #[flutter_rust_bridge::frb]
    pub async fn search_conversations(&self, keyword: String) -> Result<Vec<crate::domain::model::local::LocalConversation>> {
        self.inner.search_conversations(&keyword).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 隐藏会话（对齐 Go SDK `HideConversation`）
    #[flutter_rust_bridge::frb]
    pub async fn hide_conversation(&self, conversation_id: String) -> Result<()> {
        self.inner.hide_conversation(&conversation_id).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 隐藏全部会话（对齐 Go SDK `HideAllConversations`）
    #[flutter_rust_bridge::frb]
    pub async fn hide_all_conversations(&self) -> Result<()> {
        self.inner.hide_all_conversations().await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 通用会话信息设置（对齐 Go SDK `SetConversation`）
    ///
    /// 只更新传入的非空字段，其余保持不变。
    #[flutter_rust_bridge::frb]
    pub async fn set_conversation(
        &self,
        conversation_id: String,
        recv_msg_opt: Option<i32>,
        is_pinned: Option<bool>,
        is_private_chat: Option<bool>,
        group_at_type: Option<i32>,
        ex: Option<String>,
    ) -> Result<()> {
        self.inner
            .set_conversation(&conversation_id, recv_msg_opt, is_pinned, is_private_chat, group_at_type, ex.as_deref())
            .await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 获取所有会话 ID（对齐 Go SDK `GetAllConversationIDs`）
    #[flutter_rust_bridge::frb]
    pub async fn get_conversation_ids(&self) -> Result<Vec<String>> {
        self.inner.get_conversation_ids().await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 根据会话类型和 sourceID 生成 conversationID（对齐 Go SDK `GetConversationIDBySessionType`）
    ///
    /// - sessionType=1 单聊: `si_{sorted(userID, sourceID)}`
    /// - sessionType=2 普通群聊: `g_{groupID}`
    /// - sessionType=3 超级群聊: `sg_{groupID}`
    /// - sessionType=4 服务端通知会话: `sn_{sorted(userID, sourceID)}`
    #[flutter_rust_bridge::frb]
    pub fn get_conversation_id_by_session_type(&self, source_id: String, session_type: SessionType) -> Result<String> {
        Ok(self.inner.get_conversation_id_by_session_type(&source_id, session_type.into()))
    }
}
