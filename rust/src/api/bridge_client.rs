//! OpenIM FFI 桥接层
//!
//! 基于新 SDK 架构的统一桥接客户端，所有操作集成到 OpenIMBridgeClient 上。
//!
//! Dart 侧调用示例：
//! ```dart
//! final client = await OpenIMBridgeClient.new(...);
//! await client.sendMessage(msg);
//! await client.getConversations();
//! await client.getFriendList();
//! ```

use crate::domain::config::ClientConfig;
use crate::domain::constant::types::content_type;
use crate::domain::event::types::SdkEvent;
use crate::sdk::client::OpenIMClient;
use anyhow::Result;
use crate::frb_generated::StreamSink;
use openim_protocol::sdkws::MsgData;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio_stream::StreamExt;

// ============================================================================
// 请求/响应结构体
// ============================================================================

/// 发送消息请求
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

/// 获取历史消息请求
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetHistoryMessagesReq {
    pub conversation_id: String,
    pub start_seq: i64,
    pub count: i64,
}

/// 撤回消息请求
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RevokeMessageReq {
    pub conversation_id: String,
    pub seq: i64,
    pub client_msg_id: String,
    pub session_type: i32,
}

/// 删除消息请求
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeleteMessagesReq {
    pub conversation_id: String,
    pub client_msg_ids: Vec<String>,
}

/// 标记已读请求
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

/// OpenIM SDK 桥接客户端
/// 
/// 所有操作集成到此结构体上，与内部 SDK 的 OpenIMClient 保持一致的设计。
#[flutter_rust_bridge::frb(opaque)]
pub struct OpenIMBridgeClient {
    inner: Arc<OpenIMClient>,
}

impl OpenIMBridgeClient {
    // ========== 客户端生命周期 ==========

    /// 创建新的 SDK 客户端实例
    #[flutter_rust_bridge::frb]
    pub async fn new(
        user_id: String,
        token: String,
        platform_id: i32,
        ws_url: Option<String>,
        api_base_url: Option<String>,
        data_dir: Option<String>,
    ) -> Result<Self> {
        let config = ClientConfig::new(
            user_id.clone(),
            token.clone(),
            platform_id,
            ws_url,
            api_base_url,
            data_dir,
        );
        
        let client = OpenIMClient::new(config).await?;
        client.login(&user_id, &token).await?;
        
        Ok(Self {
            inner: Arc::new(client),
        })
    }

    /// 断开连接并清理资源
    #[flutter_rust_bridge::frb]
    pub async fn disconnect(&self) -> Result<()> {
        self.inner.disconnect().await;
        Ok(())
    }

    /// 事件流。Dart 端得到 Stream<SdkEvent> 并 listen。
    #[flutter_rust_bridge::frb]
    pub async fn event_stream(&self, sink: StreamSink<SdkEvent>) -> Result<()> {
        let event_bus = self.inner.event_bus.clone();
        tokio::spawn(async move {
            let mut subscription = event_bus.subscribe();
            while let Some(event) = subscription.next().await {
                let _ = sink.add(event);
            }
        });
        Ok(())
    }

    // ========== 消息操作 ==========

    /// 发送消息
    #[flutter_rust_bridge::frb]
    pub async fn send_message(&self, req: SendMessageReq) -> Result<()> {
        let client_msg_id = req.client_msg_id.unwrap_or_else(|| {
            format!("msg_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis())
        });
        
        let pending_msg = crate::core::message::sender::PendingMessage {
            client_msg_id,
            send_id: self.inner.context.user_id.lock().unwrap().clone(),
            recv_id: req.recv_id,
            group_id: req.group_id,
            sender_platform_id: self.inner.context.config.platform_id,
            sender_nickname: String::new(),
            sender_face_url: String::new(),
            session_type: req.session_type,
            msg_from: 100,
            content_type: req.content_type,
            content: req.content,
        };
        
        Ok(self.inner.message_sender.send_message(pending_msg).await?)
    }

    /// 获取历史消息
    #[flutter_rust_bridge::frb]
    pub async fn get_history_messages(&self, req: GetHistoryMessagesReq) -> Result<Vec<MsgData>> {
        let messages = self.inner.message_handler.message_dao()
            .get_by_conversation(&req.conversation_id, req.start_seq, req.start_seq + req.count)
            .await?;
        
        let msg_data_list: Vec<MsgData> = messages.into_iter().map(|m| MsgData {
            server_msg_id: m.server_msg_id,
            client_msg_id: m.client_msg_id,
            send_id: m.send_id,
            recv_id: m.recv_id,
            sender_platform_id: m.sender_platform_id,
            sender_nickname: m.sender_nick_name,
            sender_face_url: m.sender_face_url,
            session_type: m.session_type,
            msg_from: m.msg_from,
            content_type: m.content_type,
            content: m.content.into_bytes(),
            seq: m.seq,
            send_time: m.send_time,
            create_time: m.create_time,
            group_id: m.group_id,
            ..Default::default()
        }).collect();
        
        Ok(msg_data_list)
    }

    /// 撤回消息
    #[flutter_rust_bridge::frb]
    pub async fn revoke_message(&self, req: RevokeMessageReq) -> Result<()> {
        Ok(self.inner.message_service
            .revoke_message(
                req.conversation_id,
                req.seq,
                req.client_msg_id,
                req.session_type,
            )
            .await?)
    }

    /// 删除消息
    #[flutter_rust_bridge::frb]
    pub async fn delete_messages(&self, req: DeleteMessagesReq) -> Result<()> {
        Ok(self.inner.message_service
            .delete_messages(req.conversation_id, req.client_msg_ids)
            .await?)
    }

    /// 标记消息已读
    #[flutter_rust_bridge::frb]
    pub async fn mark_messages_as_read(&self, req: MarkMessagesAsReadReq) -> Result<()> {
        Ok(self.inner.message_service
            .mark_messages_as_read(
                req.conversation_id,
                req.session_type,
                req.has_read_seq,
                req.seqs,
            )
            .await?)
    }

    // ========== 会话操作 ==========

    /// 获取所有会话列表
    #[flutter_rust_bridge::frb]
    pub async fn get_conversations(&self) -> Result<Vec<crate::infra::database::models::LocalConversation>> {
        let convs = self.inner.conversation.get_all_conversations().await?;
        let local_convs: Vec<crate::infra::database::models::LocalConversation> = convs.into_iter().map(|c| {
            crate::core::conversation::manager::domain_to_local(c)
        }).collect();
        Ok(local_convs)
    }

    /// 获取单个会话
    #[flutter_rust_bridge::frb]
    pub async fn get_conversation(&self, conversation_id: String) -> Result<Option<crate::infra::database::models::LocalConversation>> {
        match self.inner.conversation.get_conversation(&conversation_id).await? {
            Some(c) => Ok(Some(crate::core::conversation::manager::domain_to_local(c))),
            None => Ok(None),
        }
    }

    /// 更新会话未读数
    #[flutter_rust_bridge::frb]
    pub async fn update_conversation_unread_count(&self, conversation_id: String, unread_count: i64) -> Result<()> {
        Ok(self.inner.conversation.update_unread_count(&conversation_id, unread_count as i32).await?)
    }

    /// 设置会话置顶
    #[flutter_rust_bridge::frb]
    pub async fn set_conversation_pinned(&self, conversation_id: String, is_pinned: bool) -> Result<()> {
        Ok(self.inner.conversation.set_pinned(&conversation_id, is_pinned).await?)
    }

    /// 删除会话
    #[flutter_rust_bridge::frb]
    pub async fn delete_conversation(&self, conversation_id: String) -> Result<()> {
        Ok(self.inner.conversation.delete_conversation(&conversation_id).await?)
    }

    // ========== 好友操作 ==========

    /// 获取好友列表
    #[flutter_rust_bridge::frb]
    pub async fn get_friend_list(&self) -> Result<Vec<crate::domain::model::friend::FriendInfo>> {
        Ok(self.inner.friend.get_friend_list().await)
    }

    /// 添加好友
    #[flutter_rust_bridge::frb]
    pub async fn add_friend(&self, user_id: String, req_msg: String) -> Result<()> {
        Ok(self.inner.friend.add_friend(user_id, Some(req_msg)).await?)
    }

    /// 删除好友
    #[flutter_rust_bridge::frb]
    pub async fn delete_friend(&self, user_id: String) -> Result<()> {
        Ok(self.inner.friend.delete_friend(user_id).await?)
    }

    /// 获取黑名单
    #[flutter_rust_bridge::frb]
    pub async fn get_black_list(&self) -> Result<Vec<String>> {
        Ok(self.inner.friend.get_blacklist().await)
    }

    /// 添加到黑名单
    #[flutter_rust_bridge::frb]
    pub async fn add_black(&self, user_id: String) -> Result<()> {
        Ok(self.inner.friend.add_black(user_id).await?)
    }

    /// 从黑名单移除
    #[flutter_rust_bridge::frb]
    pub async fn remove_black(&self, user_id: String) -> Result<()> {
        Ok(self.inner.friend.remove_black(user_id).await?)
    }

    // ========== 群组操作 ==========

    /// 获取群组列表
    #[flutter_rust_bridge::frb]
    pub async fn get_group_list(&self) -> Result<Vec<crate::domain::model::group::GroupInfo>> {
        Ok(self.inner.group.get_joined_group_list().await)
    }

    /// 创建群组
    #[flutter_rust_bridge::frb]
    pub async fn create_group(
        &self,
        group_name: String,
        group_type: i32,
        member_ids: Vec<String>,
    ) -> Result<crate::domain::model::group::GroupInfo> {
        let user_id = self.inner.context.user_id.lock().unwrap().clone();
        Ok(self.inner.group.create_group(
            group_name,
            None,
            None,
            None,
            member_ids,
            vec![],
            user_id,
        ).await?)
    }

    /// 加入群组
    #[flutter_rust_bridge::frb]
    pub async fn join_group(&self, group_id: String, req_msg: String) -> Result<()> {
        Ok(self.inner.group.join_group(group_id, Some(req_msg)).await?)
    }

    /// 退出群组
    #[flutter_rust_bridge::frb]
    pub async fn quit_group(&self, group_id: String) -> Result<()> {
        Ok(self.inner.group.quit_group(group_id).await?)
    }

    /// 获取群组成员
    #[flutter_rust_bridge::frb]
    pub async fn get_group_members(&self, group_id: String) -> Result<Vec<crate::domain::model::group::GroupMember>> {
        Ok(self.inner.group.get_group_member_list(group_id, 0, 0, 1000).await?)
    }

    /// 邀请成员
    #[flutter_rust_bridge::frb]
    pub async fn invite_group_members(&self, group_id: String, member_ids: Vec<String>) -> Result<()> {
        Ok(self.inner.group.invite_user_to_group(group_id, member_ids, None).await?)
    }

    /// 踢出成员
    #[flutter_rust_bridge::frb]
    pub async fn kick_group_members(&self, group_id: String, member_ids: Vec<String>) -> Result<()> {
        Ok(self.inner.group.kick_group_member(group_id, member_ids, None).await?)
    }

    // ========== 用户操作 ==========

    /// 获取用户信息
    #[flutter_rust_bridge::frb]
    pub async fn get_users_info(&self, user_ids: Vec<String>) -> Result<Vec<crate::domain::model::user::UserInfo>> {
        Ok(self.inner.user.get_users_info(user_ids).await?)
    }

    /// 更新用户资料
    #[flutter_rust_bridge::frb]
    pub async fn update_user_profile(
        &self,
        nickname: Option<String>,
        face_url: Option<String>,
        ex: Option<String>,
    ) -> Result<()> {
        let updates = crate::core::user::manager::UpdateUserFields {
            nickname,
            face_url,
            gender: None,
            email: ex,
        };
        Ok(self.inner.user.update_self_user_info(updates).await?)
    }
}
