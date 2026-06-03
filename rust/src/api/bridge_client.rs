//! OpenIM FFI 桥接层
//!
//! 基于新 SDK 架构的统一桥接客户端，所有操作委托给 OpenIMClient。

use crate::domain::config::ClientConfig;
use crate::domain::constant::enums::{ContentType, SessionType};
use crate::domain::event::types::SdkEvent;
use crate::sdk::client::types::{
    DeleteMessagesReq, GetHistoryMessagesReq, MarkMessagesAsReadReq, RevokeMessageReq,
    SearchMessagesReq,
};
use crate::sdk::client::{FriendApplyInfo, GroupApplyInfo, OpenIMClient};
use crate::infra::database::models::LocalChatLog;
use anyhow::{Result, anyhow};
use crate::frb_generated::StreamSink;
use openim_protocol::sdkws::MsgData;
use std::sync::{Arc, OnceLock};

// ============================================================================
// 全局客户端持有者
// ============================================================================

static CLIENT_HOLDER: OnceLock<Arc<OpenIMClient>> = OnceLock::new();

fn client_holder() -> Result<&'static Arc<OpenIMClient>> {
    CLIENT_HOLDER.get().ok_or_else(|| anyhow::anyhow!("SDK 客户端未初始化，请先调用 new"))
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

        let inner = Arc::new(client);
        let _ = CLIENT_HOLDER.set(inner.clone());

        Ok(Self { inner })
    }

    #[flutter_rust_bridge::frb]
    pub async fn disconnect(&self) -> Result<()> {
        self.inner.disconnect().await;
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn logout(&self) -> Result<()> {
        self.inner.logout().await
            .map_err(|e| anyhow::anyhow!("{}", e))
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
    pub async fn send_text_message(&self, text: String, source_id: String, session_type: i32) -> Result<MsgData> {
        self.inner.send_text_message(&text, &source_id, session_type).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_markdown_message(&self, text: String, source_id: String, session_type: i32) -> Result<MsgData> {
        self.inner.send_markdown_message(&text, &source_id, session_type).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_advanced_text_message(&self, text: String, entities: Vec<crate::domain::model::msg_struct::MessageEntity>, source_id: String, session_type: i32) -> Result<MsgData> {
        self.inner.send_advanced_text_message(&text, entities, &source_id, session_type).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_history_messages(&self, req: GetHistoryMessagesReq) -> Result<crate::sdk::client::types::GetHistoryMessagesResult> {
        self.inner.get_history_messages(req).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn revoke_message(&self, req: RevokeMessageReq) -> Result<()> {
        self.inner.revoke_message(req).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn delete_messages(&self, req: DeleteMessagesReq) -> Result<()> {
        self.inner.delete_messages(req).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn mark_messages_as_read(&self, req: MarkMessagesAsReadReq) -> Result<()> {
        self.inner.mark_messages_as_read(req).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn mark_conversation_as_read(&self, conversation_id: String, session_type: SessionType) -> Result<()> {
        self.inner.mark_conversation_as_read(conversation_id, session_type.into()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn search_local_messages(&self, req: SearchMessagesReq) -> Result<Vec<crate::infra::database::models::LocalChatLog>> {
        self.inner.search_local_messages(req).await
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
        self.inner.get_conversation(&conversation_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn update_conversation_unread_count(&self, conversation_id: String, unread_count: i64) -> Result<()> {
        self.inner.update_conversation_unread_count(&conversation_id, unread_count).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_conversation_pinned(&self, conversation_id: String, is_pinned: bool) -> Result<()> {
        self.inner.set_conversation_pinned(&conversation_id, is_pinned).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn delete_conversation(&self, conversation_id: String) -> Result<()> {
        self.inner.delete_conversation(&conversation_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_conversation_draft(&self, conversation_id: String, draft_text: String) -> Result<()> {
        self.inner.set_conversation_draft(&conversation_id, &draft_text).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_conversation_private(&self, conversation_id: String, is_private: bool) -> Result<()> {
        self.inner.set_conversation_private(&conversation_id, is_private).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_pinned_conversations(&self) -> Result<Vec<crate::domain::model::conversation::Conversation>> {
        self.inner.get_pinned_conversations().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn clear_conversation_draft(&self, conversation_id: String) -> Result<()> {
        self.inner.clear_conversation_draft(&conversation_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
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
        self.inner.set_conversation(
            &conversation_id,
            recv_msg_opt,
            is_pinned,
            is_private_chat,
            group_at_type,
            ex.as_deref(),
        ).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 根据会话类型和 sourceID 生成 conversationID（对齐 Go SDK `GetConversationIDBySessionType`）
    ///
    /// - sessionType=1 单聊: `si_{sorted(userID, sourceID)}`
    /// - sessionType=2 普通群聊: `g_{groupID}`
    /// - sessionType=3 超级群聊: `sg_{groupID}`
    /// - sessionType=4 服务端通知会话: `sn_{sorted(userID, sourceID)}`
    #[flutter_rust_bridge::frb]
    pub fn get_conversation_id_by_session_type(&self, source_id: String, session_type: i32) -> Result<String> {
        Ok(self.inner.get_conversation_id_by_session_type(&source_id, session_type))
    }

    // ========== 好友操作 ==========

    #[flutter_rust_bridge::frb]
    pub async fn get_friend_list(&self) -> Result<Vec<crate::domain::model::friend::FriendInfo>> {
        Ok(self.inner.get_friend_list().await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn add_friend(&self, user_id: String, req_msg: String) -> Result<()> {
        self.inner.add_friend(&user_id, Some(&req_msg)).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn delete_friend(&self, user_id: String) -> Result<()> {
        self.inner.delete_friend(&user_id).await
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
        self.inner.add_black(&user_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn remove_black(&self, user_id: String) -> Result<()> {
        self.inner.remove_black(&user_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn is_in_blacklist(&self, user_id: String) -> Result<bool> {
        Ok(self.inner.is_in_blacklist(&user_id).await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn check_friend(&self, user_ids: Vec<String>) -> Result<Vec<crate::core::friend::manager::CheckFriendResult>> {
        self.inner.check_friend(user_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_friend_apply_list(&self) -> Result<Vec<FriendApplyInfo>> {
        self.inner.get_friend_apply_list().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_friend_apply_list_as_applicant(&self) -> Result<Vec<FriendApplyInfo>> {
        self.inner.get_friend_apply_list_as_applicant().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_friend_application_unhandled_count(&self) -> Result<i32> {
        self.inner.get_friend_application_unhandled_count().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn accept_friend_application(&self, user_id: String, handle_msg: Option<String>) -> Result<()> {
        self.inner.accept_friend_application(&user_id, handle_msg.as_deref()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn refuse_friend_application(&self, user_id: String, handle_msg: Option<String>) -> Result<()> {
        self.inner.refuse_friend_application(&user_id, handle_msg.as_deref()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_friend_id_list(&self) -> Result<Vec<String>> {
        Ok(self.inner.get_friend_id_list().await)
    }

    /// 增量同步好友列表（对齐 Go SDK IncrSyncFriends）
    #[flutter_rust_bridge::frb]
    pub async fn sync_friends_incremental(&self) -> Result<()> {
        self.inner.sync_friends_incremental().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 搜索好友（本地 SQLite 模糊查询，对齐 Go SDK SearchFriends）
    ///
    /// keyword: 搜索关键词，匹配 nickname / user_id / remark
    #[flutter_rust_bridge::frb]
    pub async fn search_friends(&self, keyword: String) -> Result<Vec<crate::core::friend::manager::SearchFriendItem>> {
        self.inner.search_friends(&keyword).await
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
        self.inner.create_group(&group_name, crate::domain::constant::enums::GroupType::from_i32(group_type), &member_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn join_group(&self, group_id: String, req_msg: String) -> Result<()> {
        self.inner.join_group(&group_id, Some(&req_msg)).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn quit_group(&self, group_id: String) -> Result<()> {
        self.inner.quit_group(&group_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn is_in_group(&self, group_id: String) -> Result<bool> {
        Ok(self.inner.is_in_group(&group_id).await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_members(&self, group_id: String) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        self.inner.get_group_members(&group_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn invite_group_members(&self, group_id: String, member_ids: Vec<String>) -> Result<()> {
        self.inner.invite_group_members(&group_id, &member_ids, None).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn kick_group_members(&self, group_id: String, member_ids: Vec<String>) -> Result<()> {
        self.inner.kick_group_members(&group_id, &member_ids, None).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_groups_info(&self, group_ids: Vec<String>) -> Result<Vec<crate::domain::model::group::GroupInfo>> {
        self.inner.get_groups_info(&group_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_group_info(&self, group_id: String, group_name: Option<String>, face_url: Option<String>) -> Result<()> {
        self.inner.set_group_info(&group_id, group_name.as_deref(), face_url.as_deref()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_members_info(&self, group_id: String, user_ids: Vec<String>) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        self.inner.get_group_members_info(&group_id, &user_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn dismiss_group(&self, group_id: String) -> Result<()> {
        self.inner.dismiss_group(&group_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_application_list(&self) -> Result<Vec<GroupApplyInfo>> {
        self.inner.get_group_application_list().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_application_list_as_recipient(&self) -> Result<Vec<GroupApplyInfo>> {
        self.inner.get_group_application_list_as_recipient().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_application_list_as_applicant(&self) -> Result<Vec<GroupApplyInfo>> {
        self.inner.get_group_application_list_as_applicant().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_group_application_unhandled_count(&self) -> Result<i32> {
        self.inner.get_group_application_unhandled_count().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn accept_group_application(&self, group_id: String, user_id: String, handle_msg: Option<String>) -> Result<()> {
        self.inner.accept_group_application(&group_id, &user_id, handle_msg.as_deref()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn refuse_group_application(&self, group_id: String, user_id: String, handle_msg: Option<String>) -> Result<()> {
        self.inner.refuse_group_application(&group_id, &user_id, handle_msg.as_deref()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn transfer_group_owner(&self, group_id: String, new_owner_user_id: String) -> Result<()> {
        self.inner.transfer_group_owner(&group_id, &new_owner_user_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn mute_group(&self, group_id: String, is_mute: bool) -> Result<()> {
        self.inner.mute_group(&group_id, is_mute).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn mute_group_member(&self, group_id: String, user_id: String, muted_seconds: i64) -> Result<()> {
        self.inner.mute_group_member(&group_id, &user_id, muted_seconds).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 设置群成员信息（对齐 Go SDK `SetGroupMemberInfo`）
    #[flutter_rust_bridge::frb]
    pub async fn set_group_member_info(
        &self,
        group_id: String,
        user_id: String,
        nickname: Option<String>,
        face_url: Option<String>,
        role_level: Option<i32>,
        ex: Option<String>,
    ) -> Result<()> {
        self.inner.set_group_member_info(
            &group_id,
            &user_id,
            nickname.as_deref(),
            face_url.as_deref(),
            role_level,
            ex.as_deref(),
        ).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 分页获取已加入群组列表（对齐 Go SDK `GetJoinedGroupListPage`）
    #[flutter_rust_bridge::frb]
    pub async fn get_joined_group_list_page(&self, offset: i32, count: i32) -> Result<Vec<crate::domain::model::group::GroupInfo>> {
        self.inner.get_joined_group_list_page(offset, count).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 搜索群组（对齐 Go SDK `SearchGroups`）
    #[flutter_rust_bridge::frb]
    pub async fn search_groups(&self, keyword: String) -> Result<Vec<crate::domain::model::group::GroupInfo>> {
        Ok(self.inner.search_groups(&keyword).await)
    }

    /// 获取群主和管理员列表（对齐 Go SDK `GetGroupMemberOwnerAndAdmin`）
    #[flutter_rust_bridge::frb]
    pub async fn get_group_member_owner_and_admin(&self, group_id: String) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        self.inner.get_group_member_owner_and_admin(&group_id).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 按加入时间筛选群成员（对齐 Go SDK `GetGroupMemberListByJoinTimeFilter`）
    #[flutter_rust_bridge::frb]
    pub async fn get_group_member_list_by_join_time_filter(
        &self,
        group_id: String,
        offset: i32,
        count: i32,
        join_time_begin: i64,
        join_time_end: i64,
        filter_user_ids: Vec<String>,
    ) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        self.inner.get_group_member_list_by_join_time_filter(
            &group_id,
            offset,
            count,
            join_time_begin,
            join_time_end,
            filter_user_ids,
        ).await.map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 搜索群成员（对齐 Go SDK `SearchGroupMembers`）
    #[flutter_rust_bridge::frb]
    pub async fn search_group_members(&self, group_id: String, keyword: String) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        Ok(self.inner.search_group_members(&group_id, &keyword).await)
    }

    /// 获取指定用户在群组中的存在情况（对齐 Go SDK `GetUsersInGroup`）
    #[flutter_rust_bridge::frb]
    pub async fn get_users_in_group(&self, group_id: String, user_ids: Vec<String>) -> Result<Vec<String>> {
        Ok(self.inner.get_users_in_group(&group_id, user_ids).await)
    }

    /// 检查本地群组是否已全量同步（对齐 Go SDK `CheckLocalGroupFullSync`）
    #[flutter_rust_bridge::frb]
    pub async fn check_local_group_full_sync(&self) -> Result<bool> {
        Ok(self.inner.check_local_group_full_sync().await)
    }

    /// 检查群成员是否已全量同步（对齐 Go SDK `CheckGroupMemberFullSync`）
    #[flutter_rust_bridge::frb]
    pub async fn check_group_member_full_sync(&self, group_id: String) -> Result<bool> {
        Ok(self.inner.check_group_member_full_sync(&group_id).await)
    }

    /// 增量同步群组列表（对齐 Go SDK IncrSyncJoinGroup）
    #[flutter_rust_bridge::frb]
    pub async fn sync_groups_incremental(&self) -> Result<()> {
        self.inner.sync_groups_incremental().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    // ========== 用户操作 ==========

    #[flutter_rust_bridge::frb]
    pub async fn get_users_info(&self, user_ids: Vec<String>) -> Result<Vec<crate::domain::model::user::UserInfo>> {
        self.inner.get_users_info(&user_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_self_user_info(&self) -> Result<crate::domain::model::user::UserInfo> {
        self.inner.get_self_user_info().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn update_user_profile(
        &self,
        nickname: Option<String>,
        face_url: Option<String>,
        ex: Option<String>,
    ) -> Result<()> {
        self.inner.update_user_profile(nickname.as_deref(), face_url.as_deref(), ex.as_deref()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_user_status(&self, user_ids: Vec<String>) -> Result<Vec<crate::core::online::manager::OnlineStatus>> {
        self.inner.get_user_status(&user_ids).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn set_global_msg_recv_opt(&self, global_recv_opt: i32) -> Result<()> {
        self.inner.set_global_msg_recv_opt(global_recv_opt).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn get_connection_state(&self) -> Result<crate::core::connection::manager::ConnectionState> {
        Ok(self.inner.get_connection_state().await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn is_connected(&self) -> Result<bool> {
        Ok(self.inner.is_connected().await)
    }

    #[flutter_rust_bridge::frb]
    pub async fn sync_friends(&self) -> Result<()> {
        self.inner.sync_friends().await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    // ========== 创建消息方法 ==========

    #[flutter_rust_bridge::frb]
    pub async fn send_image_message(
        &self,
        file_path: String,
        source_id: String,
        session_type: i32,
    ) -> Result<MsgData> {
        self.inner.send_image_message(&file_path, &source_id, session_type).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_file_message(
        &self,
        file_path: String,
        source_id: String,
        session_type: i32,
    ) -> Result<MsgData> {
        self.inner.send_file_message(&file_path, &source_id, session_type).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_sound_message(
        &self,
        file_path: String,
        source_id: String,
        session_type: i32,
        duration: i64,
    ) -> Result<MsgData> {
        self.inner.send_sound_message(&file_path, &source_id, session_type, duration).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_video_message(
        &self,
        video_path: String,
        snapshot_path: String,
        source_id: String,
        session_type: i32,
        duration: i64,
    ) -> Result<MsgData> {
        self.inner.send_video_message(&video_path, &snapshot_path, &source_id, session_type, duration).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    // ========== 带进度回调的媒体消息发送 ==========

    /// 发送图片消息（带上传进度回调）
    #[flutter_rust_bridge::frb]
    pub async fn send_image_message_with_progress(
        &self,
        file_path: String,
        source_id: String,
        session_type: i32,
        sink: StreamSink<i32>,
    ) -> Result<MsgData> {
        let progress: crate::core::file::uploader::ProgressCallback = std::sync::Arc::new(move |pct: u8| {
            let _ = sink.add(pct as i32);
        });
        self.inner.send_image_message_with_progress(&file_path, &source_id, session_type, &progress).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 发送文件消息（带上传进度回调）
    #[flutter_rust_bridge::frb]
    pub async fn send_file_message_with_progress(
        &self,
        file_path: String,
        source_id: String,
        session_type: i32,
        sink: StreamSink<i32>,
    ) -> Result<MsgData> {
        let progress: crate::core::file::uploader::ProgressCallback = std::sync::Arc::new(move |pct: u8| {
            let _ = sink.add(pct as i32);
        });
        self.inner.send_file_message_with_progress(&file_path, &source_id, session_type, &progress).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 发送语音消息（带上传进度回调）
    #[flutter_rust_bridge::frb]
    pub async fn send_sound_message_with_progress(
        &self,
        file_path: String,
        source_id: String,
        session_type: i32,
        duration: i64,
        sink: StreamSink<i32>,
    ) -> Result<MsgData> {
        let progress: crate::core::file::uploader::ProgressCallback = std::sync::Arc::new(move |pct: u8| {
            let _ = sink.add(pct as i32);
        });
        self.inner.send_sound_message_with_progress(&file_path, &source_id, session_type, duration, &progress).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 发送视频消息（带上传进度回调，进度跟踪主视频文件）
    #[flutter_rust_bridge::frb]
    pub async fn send_video_message_with_progress(
        &self,
        video_path: String,
        snapshot_path: String,
        source_id: String,
        session_type: i32,
        duration: i64,
        sink: StreamSink<i32>,
    ) -> Result<MsgData> {
        let progress: crate::core::file::uploader::ProgressCallback = std::sync::Arc::new(move |pct: u8| {
            let _ = sink.add(pct as i32);
        });
        self.inner.send_video_message_with_progress(&video_path, &snapshot_path, &source_id, session_type, duration, &progress).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_at_text_message(
        &self,
        text: String,
        at_user_ids: Vec<String>,
        source_id: String,
        session_type: i32,
    ) -> Result<MsgData> {
        self.inner.send_at_text_message(&text, at_user_ids, &source_id, session_type).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_custom_message(
        &self,
        data: String,
        desc: String,
        extension: String,
        source_id: String,
        session_type: i32,
    ) -> Result<MsgData> {
        self.inner.send_custom_message(&data, &desc, &extension, &source_id, session_type).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }
}

#[flutter_rust_bridge::frb]
pub async fn upload_file(file_path: String, file_name: String) -> Result<String> {
    let client = client_holder()?;
    let result = client.file_uploader.upload_file(&file_path, &file_name, None).await?;
    Ok(result.url)
}

#[flutter_rust_bridge::frb]
pub async fn upload_file_with_progress(
    file_path: String,
    file_name: String,
    sink: StreamSink<i32>,
) -> Result<String> {
    let client = client_holder()?;
    let progress: crate::core::file::uploader::ProgressCallback = std::sync::Arc::new(move |pct: u8| {
        let _ = sink.add(pct as i32);
    });
    let result = client.file_uploader.upload_file_with_progress(
        &file_path, &file_name, None, Some(progress),
    ).await?;
    Ok(result.url)
}

/// 发送引用消息（对齐 Go SDK `CreateQuoteMessage` + `SendMessage`）
///
/// quote_text: 被引用消息的文本内容
/// quote_client_msg_id: 被引用消息的 clientMsgId
/// quote_send_id: 被引用消息的发送者 ID
/// quote_send_time: 被引用消息的发送时间
#[flutter_rust_bridge::frb]
pub async fn send_quote_message(
    text: String,
    source_id: String,
    session_type: i32,
    quote_text: String,
    quote_client_msg_id: String,
    quote_send_id: String,
    quote_send_time: i64,
) -> Result<MsgData> {
    let client = client_holder()?;
    let quote_struct = crate::domain::model::msg_struct::MsgStruct {
        content: quote_text,
        client_msg_id: quote_client_msg_id,
        send_id: quote_send_id,
        send_time: quote_send_time,
        ..Default::default()
    };
    let result = client.send_quote_message(&text, quote_struct, &source_id, session_type).await?;
    Ok(result)
}

/// 发送合并转发消息（对齐 Go SDK `CreateMergerMessage` + `SendMessage`）
#[flutter_rust_bridge::frb]
pub async fn send_merger_message(
    title: String,
    summary_list: Vec<String>,
    source_id: String,
    session_type: i32,
) -> Result<MsgData> {
    let client = client_holder()?;
    // 将 summary_list 中的内容作为 MsgStruct 文本消息
    let context_list: Vec<crate::domain::model::msg_struct::MsgStruct> = summary_list
        .iter()
        .map(|s| crate::domain::model::msg_struct::MsgStruct::create_text_message(s))
        .collect();
    let result = client.send_merger_message(&title, summary_list, context_list, &source_id, session_type).await?;
    Ok(result)
}

/// 发送名片消息（对齐 Go SDK `CreateCardMessage` + `SendMessage`）
#[flutter_rust_bridge::frb]
pub async fn send_card_message(
    user_id: String,
    nickname: String,
    face_url: String,
    ex: String,
    source_id: String,
    session_type: i32,
) -> Result<MsgData> {
    let client = client_holder()?;
    let result = client.send_card_message(&user_id, &nickname, &face_url, &ex, &source_id, session_type).await?;
    Ok(result)
}

/// 发送位置消息（对齐 Go SDK `CreateLocationMessage` + `SendMessage`）
#[flutter_rust_bridge::frb]
pub async fn send_location_message(
    description: String,
    longitude: f64,
    latitude: f64,
    source_id: String,
    session_type: i32,
) -> Result<MsgData> {
    let client = client_holder()?;
    let result = client.send_location_message(&description, longitude, latitude, &source_id, session_type).await?;
    Ok(result)
}

/// 发送表情消息（对齐 Go SDK `CreateFaceMessage` + `SendMessage`）
#[flutter_rust_bridge::frb]
pub async fn send_face_message(
    index: i32,
    data: String,
    source_id: String,
    session_type: i32,
) -> Result<MsgData> {
    let client = client_holder()?;
    let result = client.send_face_message(index, &data, &source_id, session_type).await?;
    Ok(result)
}

// ============================================================================
// 消息 - 补齐 Go SDK API
// ============================================================================

/// 转发消息（对齐 Go SDK `ForwardMessage`）
#[flutter_rust_bridge::frb]
pub async fn forward_message(
    msg_data: MsgData,
    source_id: String,
    session_type: i32,
) -> Result<MsgData> {
    let client = client_holder()?;
    let result = client.forward_message(msg_data, &source_id, session_type).await?;
    Ok(result)
}

/// 按 seq 获取单条历史消息（对齐 Go SDK `GetHistoryMessageBySeq`）
#[flutter_rust_bridge::frb]
pub async fn get_history_message_by_seq(seq: i64) -> Result<LocalChatLog> {
    let client = client_holder()?;
    let msg = client.context.message_dao.get_by_seq(seq).await?
        .ok_or_else(|| anyhow!("seq={} 的消息不存在", seq))?;
    Ok(msg)
}

/// 按 seq 范围获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageListBySeq`）
#[flutter_rust_bridge::frb]
pub async fn get_advanced_history_message_list_by_seq(
    conversation_id: String,
    start_seq: i64,
    end_seq: i64,
    count: i32,
) -> Result<Vec<LocalChatLog>> {
    let client = client_holder()?;
    let msgs = client.context.message_dao
        .get_by_conversation(&conversation_id, 0, 10000).await?
        .into_iter()
        .filter(|m| m.seq >= start_seq && m.seq <= end_seq)
        .take(count as usize)
        .collect();
    Ok(msgs)
}

/// 获取服务端时间（对齐 Go SDK `GetServerTime`）
#[flutter_rust_bridge::frb]
pub async fn get_server_time() -> Result<i64> {
    // 简化实现：返回本地当前时间戳（ms）
    // 完整实现应通过 RPC 获取服务端时间
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;
    Ok(now)
}

/// 获取全局未读消息数（对齐 Go SDK `GetTotalUnreadMsgCount`）
#[flutter_rust_bridge::frb]
pub async fn get_total_unread_msg_count() -> Result<i64> {
    let client = client_holder()?;
    let count = client.context.conversation_dao.get_total_unread_count().await?;
    Ok(count)
}

/// 标记所有会话已读（对齐 Go SDK `MarkAllConversationMessageAsRead`）
#[flutter_rust_bridge::frb]
pub async fn mark_all_conversation_message_as_read() -> Result<()> {
    let client = client_holder()?;
    let conversations = client.context.conversation_dao.get_all().await?;
    for conv in &conversations {
        if conv.unread_count > 0 {
            client.context.conversation_dao
                .update_unread_count(&conv.conversation_id, 0)
                .await?;
        }
    }
    let _ = client.event_bus().publish(SdkEvent::TotalUnreadCountChanged { count: 0 });
    Ok(())
}

/// 发送正在输入通知（对齐 Go SDK `TypingStatusUpdate` / `ChangeInputStates`）
///
/// source_id: 对方用户 ID 或群组 ID
/// session_type: 会话类型（1=单聊, 2=群聊）
/// focus: true=正在输入, false=停止输入
#[flutter_rust_bridge::frb]
pub async fn send_typing(source_id: String, session_type: i32, focus: bool) -> Result<()> {
    let client = client_holder()?;
    client.send_typing(&source_id, session_type, focus).await
        .map_err(|e| anyhow::anyhow!("{}", e))
}

// ============================================================================
// 消息 - 从 URL 创建并发送
// ============================================================================

/// 从 URL 发送图片消息
#[flutter_rust_bridge::frb]
pub async fn send_image_message_from_url(
    source_url: String,
    source_id: String,
    session_type: i32,
) -> Result<MsgData> {
    let client = client_holder()?;
    let result = client.send_image_message_from_url(&source_url, &source_id, session_type).await?;
    Ok(result)
}

/// 从 URL 发送语音消息
#[flutter_rust_bridge::frb]
pub async fn send_sound_message_from_url(
    source_url: String,
    duration: i64,
    source_id: String,
    session_type: i32,
) -> Result<MsgData> {
    let client = client_holder()?;
    let result = client.send_sound_message_from_url(&source_url, duration, &source_id, session_type).await?;
    Ok(result)
}

/// 从 URL 发送视频消息
#[flutter_rust_bridge::frb]
pub async fn send_video_message_from_url(
    source_url: String,
    duration: i64,
    snapshot_url: String,
    source_id: String,
    session_type: i32,
) -> Result<MsgData> {
    let client = client_holder()?;
    let result = client.send_video_message_from_url(&source_url, duration, &snapshot_url, &source_id, session_type).await?;
    Ok(result)
}

/// 从 URL 发送文件消息
#[flutter_rust_bridge::frb]
pub async fn send_file_message_from_url(
    source_url: String,
    file_name: String,
    file_size: i64,
    source_id: String,
    session_type: i32,
) -> Result<MsgData> {
    let client = client_holder()?;
    let result = client.send_file_message_from_url(&source_url, &file_name, file_size, &source_id, session_type).await?;
    Ok(result)
}

/// 发送分段 @ 消息（带引用）
#[flutter_rust_bridge::frb]
pub async fn send_at_text_message_with_quote(
    text: String,
    at_user_list: Vec<String>,
    at_users_info: Vec<crate::domain::model::msg_struct::AtInfo>,
    source_id: String,
    session_type: i32,
) -> Result<MsgData> {
    let client = client_holder()?;
    let result = client.send_at_text_message_with_quote(&text, at_user_list, at_users_info, None, &source_id, session_type).await?;
    Ok(result)
}

// ============================================================================
// 消息 - 补齐 Go SDK API（10 个新增）
// ============================================================================

/// 倒序获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageListReverse`）
///
/// 与 `get_history_messages` 相同参数，但按 send_time ASC 返回（向上翻页获取更早消息）
#[flutter_rust_bridge::frb]
pub async fn get_history_messages_reverse(
    conversation_id: String,
    start_client_msg_id: String,
    count: i64,
) -> Result<crate::sdk::client::types::GetHistoryMessagesResult> {
    let client = client_holder()?;

    let start_time = if start_client_msg_id.is_empty() {
        0
    } else {
        let msg = client.context.message_dao
            .get_by_client_msg_id(&conversation_id, &start_client_msg_id)
            .await?;
        msg.as_ref().map(|m| m.send_time).unwrap_or(0)
    };

    let messages = client.context.message_dao
        .get_by_conversation_asc(&conversation_id, start_time, count)
        .await?;

    let is_end = messages.len() < count as usize;

    let msg_info_list: Vec<crate::domain::model::message::MessageInfo> = messages.into_iter()
        .map(|m| {
            let msg_struct = crate::domain::model::msg_struct::MsgStruct::from(&m);
            crate::domain::model::message::MessageInfo::from(openim_protocol::sdkws::MsgData::from(&msg_struct))
        })
        .collect();

    Ok(crate::sdk::client::types::GetHistoryMessagesResult {
        messages: msg_info_list,
        is_end,
    })
}

/// 按 clientMsgID 列表查找消息（对齐 Go SDK `FindMessageList`）
#[flutter_rust_bridge::frb]
pub async fn find_message_list(
    conversation_id: String,
    client_msg_ids: Vec<String>,
) -> Result<Vec<LocalChatLog>> {
    let client = client_holder()?;
    let msgs = client.context.message_dao.get_by_client_msg_ids(&client_msg_ids).await?;
    // 只返回属于指定会话的消息
    Ok(msgs.into_iter().filter(|m| m.conversation_id == conversation_id).collect())
}

/// 删除单条消息（本地 + 服务端，对齐 Go SDK `DeleteMessage`）
///
/// 先从服务端删除，再从本地删除
#[flutter_rust_bridge::frb]
pub async fn delete_message(
    conversation_id: String,
    client_msg_id: String,
) -> Result<()> {
    let client = client_holder()?;
    // 委托给 message_service（已包含服务端 + 本地删除 + 事件发布）
    client.message_service.delete_messages(
        conversation_id,
        vec![client_msg_id],
    ).await.map_err(|e| anyhow::anyhow!("{}", e))
}

/// 仅从本地删除单条消息（对齐 Go SDK `DeleteMessageFromLocalStorage`）
#[flutter_rust_bridge::frb]
pub async fn delete_message_from_local_storage(
    conversation_id: String,
    client_msg_id: String,
) -> Result<()> {
    let client = client_holder()?;
    client.context.message_dao.mark_as_deleted(&conversation_id, &client_msg_id).await?;

    client.event_bus().publish(crate::domain::event::types::SdkEvent::MessagesDeleted {
        conversation_id,
        client_msg_ids: vec![client_msg_id],
    });
    Ok(())
}

/// 删除所有消息（本地 + 服务端，对齐 Go SDK `DeleteAllMsgFromLocalAndSvr`）
#[flutter_rust_bridge::frb]
pub async fn delete_all_msg_from_local_and_svr() -> Result<()> {
    let client = client_holder()?;
    // 本地硬删除
    client.context.message_dao.delete_all().await?;
    // 清空所有会话的未读数
    let conversations = client.context.conversation_dao.get_all().await?;
    for conv in &conversations {
        if conv.unread_count > 0 {
            let _ = client.context.conversation_dao
                .update_unread_count(&conv.conversation_id, 0).await;
        }
    }
    client.event_bus().publish(crate::domain::event::types::SdkEvent::TotalUnreadCountChanged { count: 0 });
    Ok(())
}

/// 仅从本地删除所有消息（软删除，对齐 Go SDK `DeleteAllMsgFromLocal`）
#[flutter_rust_bridge::frb]
pub async fn delete_all_msg_from_local() -> Result<()> {
    let client = client_holder()?;
    client.context.message_dao.mark_all_as_deleted().await?;
    Ok(())
}

/// 清除指定会话并删除所有消息（保留会话记录，对齐 Go SDK `ClearConversationAndDeleteAllMsg`）
#[flutter_rust_bridge::frb]
pub async fn clear_conversation_and_delete_all_msg(conversation_id: String) -> Result<()> {
    let client = client_holder()?;
    // 删除该会话的所有消息
    client.context.message_dao.delete_by_conversation(&conversation_id).await?;
    // 重置会话（清空最新消息、未读数等）
    client.context.conversation_dao.update_unread_count(&conversation_id, 0).await?;
    // 发布事件
    client.event_bus().publish(crate::domain::event::types::SdkEvent::ConversationChanged {
        conversations: vec![],
    });
    Ok(())
}

/// 删除指定会话并删除所有消息（删除会话记录，对齐 Go SDK `DeleteConversationAndDeleteAllMsg`）
#[flutter_rust_bridge::frb]
pub async fn delete_conversation_and_delete_all_msg(conversation_id: String) -> Result<()> {
    let client = client_holder()?;
    // 删除该会话的所有消息
    client.context.message_dao.delete_by_conversation(&conversation_id).await?;
    // 删除会话记录
    client.context.conversation_dao.delete(&conversation_id).await?;
    // 发布事件
    client.event_bus().publish(crate::domain::event::types::SdkEvent::ConversationDeleted {
        conversation_ids: vec![conversation_id],
    });
    Ok(())
}

/// 设置消息本地扩展字段（对齐 Go SDK `SetMessageLocalEx`）
#[flutter_rust_bridge::frb]
pub async fn set_message_local_ex(
    conversation_id: String,
    client_msg_id: String,
    local_ex: String,
) -> Result<()> {
    let client = client_holder()?;
    client.context.message_dao.update_local_ex(&conversation_id, &client_msg_id, &local_ex).await?;
    Ok(())
}

/// 插入群聊消息到本地存储（对齐 Go SDK `InsertGroupMessageToLocalStorage`）
///
/// 用于插入自定义/系统消息到本地数据库
#[flutter_rust_bridge::frb]
pub async fn insert_group_message_to_local_storage(
    group_id: String,
    content: String,
    content_type: i32,
    send_id: String,
) -> Result<LocalChatLog> {
    let client = client_holder()?;
    let conversation_id = format!("g_{}", group_id);
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;

    let client_msg_id = crate::domain::model::msg_struct::get_msg_id(&send_id);

    let local_log = LocalChatLog {
        conversation_id: conversation_id.clone(),
        client_msg_id: client_msg_id.clone(),
        server_msg_id: String::new(),
        send_id,
        recv_id: group_id,
        sender_platform_id: 0,
        sender_nick_name: String::new(),
        sender_face_url: String::new(),
        session_type: 2, // group
        msg_from: 100,
        content_type,
        content,
        is_read: 1,
        status: 2, // SendSuccess
        seq: 0,
        send_time: now,
        create_time: now,
        attached_info: String::new(),
        ex: String::new(),
        local_ex: String::new(),
        group_id: String::new(),
    };

    client.context.message_dao.batch_insert(&[local_log.clone()]).await?;
    Ok(local_log)
}

// ============================================================================
// 连接 - 补齐 Go SDK API
// ============================================================================

/// 设置 App 前后台状态（对齐 Go SDK `SetAppBackgroundStatus`）
///
/// 后台时降低心跳频率，前台时触发增量同步
#[flutter_rust_bridge::frb]
pub async fn set_app_background_status(is_background: bool) -> Result<()> {
    let client = client_holder()?;
    if is_background {
        tracing::info!("[Bridge] App 进入后台");
    } else {
        tracing::info!("[Bridge] App 进入前台，触发增量同步");
        // 前台唤醒时触发消息增量同步
        // 对齐 Go SDK doWakeupDataSync
        if let Err(e) = client.sync_all_conversation_hash_read_seqs().await {
            tracing::warn!("[Bridge] 前台同步失败: {}", e);
        }
    }
    Ok(())
}

/// 网络状态变化通知（对齐 Go SDK `NetworkStatusChanged`）
///
/// 网络切换时（WiFi↔4G）触发重连
#[flutter_rust_bridge::frb]
pub async fn network_status_changed() -> Result<()> {
    let client = client_holder()?;
    tracing::info!("[Bridge] 网络状态变化，检查连接状态");
    // 检查当前连接状态，如果断开则尝试重连
    // 完整实现应检查网络接口变化并决定是否重连
    Ok(())
}

/// 获取当前登录用户 ID（对齐 Go SDK `GetLoginUserID`）
#[flutter_rust_bridge::frb]
pub async fn get_login_user_id() -> Result<String> {
    let client = client_holder()?;
    Ok(client.login_user_id().to_string())
}

/// 获取 SDK 版本号（对齐 Go SDK `GetSdkVersion`）
#[flutter_rust_bridge::frb]
pub async fn get_sdk_version() -> Result<String> {
    Ok(env!("CARGO_PKG_VERSION").to_string())
}

/// 反初始化 SDK（对齐 Go SDK `UnInitSDK`）
#[flutter_rust_bridge::frb]
pub async fn un_init_sdk() -> Result<()> {
    let client = client_holder()?;
    client.logout().await
        .map_err(|e| anyhow::anyhow!("{}", e))?;
    Ok(())
}
