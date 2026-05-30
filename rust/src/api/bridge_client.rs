//! OpenIM FFI 桥接层
//!
//! 基于新 SDK 架构的统一桥接客户端，所有操作委托给 OpenIMClient。

use crate::domain::config::ClientConfig;
use crate::domain::event::types::SdkEvent;
use crate::sdk::client::{FriendApplyInfo, GroupApplyInfo, OpenIMClient};
use anyhow::Result;
use crate::frb_generated::StreamSink;
use openim_protocol::sdkws::MsgData;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio_stream::StreamExt;

// ============================================================================
// 请求/响应结构体（FFI 专用类型）
// ============================================================================

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SendMessageReq {
    pub recv_id: String,
    pub group_id: String,
    pub session_type: i32,
    pub content_type: i32,
    pub content: String,
    pub client_msg_id: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetHistoryMessagesReq {
    pub conversation_id: String,
    pub start_seq: i64,
    pub count: i64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RevokeMessageReq {
    pub conversation_id: String,
    pub seq: i64,
    pub client_msg_id: String,
    pub session_type: i32,
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
    pub session_type: i32,
    pub has_read_seq: i64,
    pub seqs: Vec<i64>,
}

// ============================================================================
// 桥接客户端
// ============================================================================

#[flutter_rust_bridge::frb(opaque)]
pub struct OpenIMBridgeClient {
    inner: Arc<OpenIMClient>,
}

impl OpenIMBridgeClient {
    // ========== 客户端生命周期 ==========

    #[flutter_rust_bridge::frb]
    pub async fn new(config: ClientConfig) -> Result<Self> {
        let client = OpenIMClient::new(config.clone()).await
            .map_err(|e| anyhow::anyhow!("{}", e))?;
        client.login(&config.user_id, &config.token).await
            .map_err(|e| anyhow::anyhow!("{}", e))?;

        Ok(Self {
            inner: Arc::new(client),
        })
    }

    #[flutter_rust_bridge::frb]
    pub async fn disconnect(&self) -> Result<()> {
        self.inner.disconnect().await;
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn event_stream(&self, sink: StreamSink<SdkEvent>) -> Result<()> {
        let event_bus = self.inner.event_bus();
        tokio::spawn(async move {
            let mut subscription = event_bus.subscribe();
            while let Some(event) = subscription.next().await {
                let _ = sink.add(event);
            }
        });
        Ok(())
    }

    // ========== 消息操作 ==========

    #[flutter_rust_bridge::frb]
    pub async fn send_message(&self, req: SendMessageReq) -> Result<MsgData> {
        self.inner.send_message(
            req.recv_id,
            req.group_id,
            req.session_type,
            req.content_type,
            req.content,
            req.client_msg_id,
        ).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_history_messages(&self, req: GetHistoryMessagesReq) -> Result<Vec<crate::domain::model::message::MessageInfo>> {
        self.inner.get_history_messages(req.conversation_id, req.start_seq, req.count).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn revoke_message(&self, req: RevokeMessageReq) -> Result<()> {
        self.inner.revoke_message(req.conversation_id, req.seq, req.client_msg_id, req.session_type).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn delete_messages(&self, req: DeleteMessagesReq) -> Result<()> {
        self.inner.delete_messages(req.conversation_id, req.client_msg_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn mark_messages_as_read(&self, req: MarkMessagesAsReadReq) -> Result<()> {
        self.inner.mark_messages_as_read(req.conversation_id, req.session_type, req.has_read_seq, req.seqs).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn search_local_messages(&self, conversation_id: String, keyword: String) -> Result<Vec<crate::infra::database::models::LocalChatLog>> {
        self.inner.search_local_messages(conversation_id, keyword).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    // ========== 会话操作 ==========

    #[flutter_rust_bridge::frb]
    pub async fn get_conversations(&self) -> Result<Vec<crate::infra::database::models::LocalConversation>> {
        self.inner.get_conversations().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_conversation(&self, conversation_id: String) -> Result<Option<crate::infra::database::models::LocalConversation>> {
        self.inner.get_conversation(conversation_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn update_conversation_unread_count(&self, conversation_id: String, unread_count: i64) -> Result<()> {
        self.inner.update_conversation_unread_count(conversation_id, unread_count).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_conversation_pinned(&self, conversation_id: String, is_pinned: bool) -> Result<()> {
        self.inner.set_conversation_pinned(conversation_id, is_pinned).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn delete_conversation(&self, conversation_id: String) -> Result<()> {
        self.inner.delete_conversation(conversation_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_conversation_draft(&self, conversation_id: String, draft_text: String) -> Result<()> {
        self.inner.set_conversation_draft(conversation_id, draft_text).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_conversation_private(&self, conversation_id: String, is_private: bool) -> Result<()> {
        self.inner.set_conversation_private(conversation_id, is_private).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    // ========== 好友操作 ==========

    #[flutter_rust_bridge::frb]
    pub async fn get_friend_list(&self) -> Result<Vec<crate::domain::model::friend::FriendInfo>> {
        Ok(self.inner.get_friend_list().await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn add_friend(&self, user_id: String, req_msg: String) -> Result<()> {
        self.inner.add_friend(user_id, Some(req_msg)).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn delete_friend(&self, user_id: String) -> Result<()> {
        self.inner.delete_friend(user_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_black_list(&self) -> Result<Vec<String>> {
        Ok(self.inner.get_black_list().await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn is_friend(&self, user_id: String) -> bool {
        self.inner.is_friend(&user_id).await
    }

    #[flutter_rust_bridge::frb]
    pub async fn add_black(&self, user_id: String) -> Result<()> {
        self.inner.add_black(user_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn remove_black(&self, user_id: String) -> Result<()> {
        self.inner.remove_black(user_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_friend_apply_list(&self) -> Result<Vec<FriendApplyInfo>> {
        self.inner.get_friend_apply_list().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn accept_friend_application(&self, user_id: String) -> Result<()> {
        self.inner.accept_friend_application(user_id, None).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn refuse_friend_application(&self, user_id: String) -> Result<()> {
        self.inner.refuse_friend_application(user_id, None).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    // ========== 群组操作 ==========

    #[flutter_rust_bridge::frb]
    pub async fn get_group_list(&self) -> Result<Vec<crate::domain::model::group::GroupInfo>> {
        Ok(self.inner.get_group_list().await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn create_group(
        &self,
        group_name: String,
        group_type: i32,
        member_ids: Vec<String>,
    ) -> Result<crate::domain::model::group::GroupInfo> {
        self.inner.create_group(group_name, group_type, member_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn join_group(&self, group_id: String, req_msg: String) -> Result<()> {
        self.inner.join_group(group_id, Some(req_msg)).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn quit_group(&self, group_id: String) -> Result<()> {
        self.inner.quit_group(group_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_members(&self, group_id: String) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        self.inner.get_group_members(group_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn invite_group_members(&self, group_id: String, member_ids: Vec<String>) -> Result<()> {
        self.inner.invite_group_members(group_id, member_ids, None).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn kick_group_members(&self, group_id: String, member_ids: Vec<String>) -> Result<()> {
        self.inner.kick_group_members(group_id, member_ids, None).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_groups_info(&self, group_ids: Vec<String>) -> Result<Vec<crate::domain::model::group::GroupInfo>> {
        self.inner.get_groups_info(group_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_group_info(&self, group_id: String, group_name: Option<String>, face_url: Option<String>) -> Result<()> {
        self.inner.set_group_info(group_id, group_name, face_url).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_members_info(&self, group_id: String, user_ids: Vec<String>) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        self.inner.get_group_members_info(group_id, user_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn dismiss_group(&self, group_id: String) -> Result<()> {
        self.inner.dismiss_group(group_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_application_list(&self) -> Result<Vec<GroupApplyInfo>> {
        self.inner.get_group_application_list().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn accept_group_application(&self, group_id: String, user_id: String) -> Result<()> {
        self.inner.accept_group_application(group_id, user_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn refuse_group_application(&self, group_id: String, user_id: String) -> Result<()> {
        self.inner.refuse_group_application(group_id, user_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    // ========== 用户操作 ==========

    #[flutter_rust_bridge::frb]
    pub async fn get_users_info(&self, user_ids: Vec<String>) -> Result<Vec<crate::domain::model::user::UserInfo>> {
        self.inner.get_users_info(user_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn update_user_profile(
        &self,
        nickname: Option<String>,
        face_url: Option<String>,
        ex: Option<String>,
    ) -> Result<()> {
        self.inner.update_user_profile(nickname, face_url, ex).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }
}

#[flutter_rust_bridge::frb]
pub async fn upload_file(file_path: String, file_name: String) -> Result<String> {
    anyhow::bail!("文件上传功能暂未实现: {} / {}", file_path, file_name)
}

#[flutter_rust_bridge::frb]
pub async fn upload_file_with_progress(file_path: String, file_name: String) -> Result<String> {
    anyhow::bail!("文件上传（含进度）功能暂未实现: {} / {}", file_path, file_name)
}
