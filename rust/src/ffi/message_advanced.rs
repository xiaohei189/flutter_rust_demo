//! 消息 - 对齐 Go SDK 的补齐 API
//!
//! 转发、seq 查询、Typing、编辑、删除系列、本地存储管理等
//! 所有操作委托给 OpenIMClient

use crate::client::SdkApi;
use crate::constant::SessionType;
use crate::ffi::global::client_holder;
use crate::http::message::DeleteMessagesReq;
use crate::model::local::LocalChatLog;
use crate::model::msg_struct::{MsgStruct, OfflinePushInfo};
use anyhow::{anyhow, Result};

// ============================================================================
// 消息转发
// ============================================================================

/// 转发消息（对齐 Go SDK `ForwardMessage`）
#[flutter_rust_bridge::frb]
pub async fn forward_message(msg_struct: MsgStruct, source_id: String, session_type: SessionType) -> Result<MsgStruct> {
    let client = client_holder()?;
    let result = client.forward_message(msg_struct, &source_id, session_type.into()).await?;
    Ok(result)
}

/// 转发消息（按 clientMsgId 查找消息并转发）
#[flutter_rust_bridge::frb]
pub async fn forward_message_by_client_id(client_msg_id: String, source_id: String, session_type: SessionType) -> Result<MsgStruct> {
    let client = client_holder()?;
    let log = client.get_message_by_client_msg_id(&client_msg_id).await?.ok_or_else(|| anyhow!("消息不存在: {}", client_msg_id))?;
    let msg_struct = MsgStruct::from(&log);
    let result = client.forward_message(msg_struct, &source_id, session_type.into()).await?;
    Ok(result)
}

// ============================================================================
// 按 seq 查询历史消息
// ============================================================================

/// 按 seq 获取单条历史消息（对齐 Go SDK `GetHistoryMessageBySeq`）
#[flutter_rust_bridge::frb]
pub async fn get_history_message_by_seq(seq: i64) -> Result<LocalChatLog> {
    let client = client_holder()?;
    let msg = client.get_history_message_by_seq(seq).await?;
    Ok(msg)
}

/// 按 seq 范围获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageListBySeq`）
#[flutter_rust_bridge::frb]
pub async fn get_advanced_history_message_list_by_seq(conversation_id: String, start_seq: i64, end_seq: i64, count: i32) -> Result<Vec<LocalChatLog>> {
    let client = client_holder()?;
    let msgs = client.get_advanced_history_message_list_by_seq(&conversation_id, start_seq, end_seq, count).await?;
    Ok(msgs)
}

/// 倒序获取历史消息（对齐 Go SDK `GetAdvancedHistoryMessageListReverse`）
///
/// 与 `get_history_messages` 相同参数，但按 send_time ASC 返回（向上翻页获取更早消息）
#[flutter_rust_bridge::frb]
pub async fn get_history_messages_reverse(conversation_id: String, start_client_msg_id: String, count: i64) -> Result<crate::client::GetHistoryMessagesResult> {
    let client = client_holder()?;

    let start_time = if start_client_msg_id.is_empty() {
        0
    } else {
        let msg = client.get_message_by_client_msg_id(&start_client_msg_id).await?;
        msg.as_ref().map(|m| m.send_time).unwrap_or(0)
    };

    Ok(client.get_history_messages_reverse(&conversation_id, &start_client_msg_id, count).await?)
}

/// 按 clientMsgID 列表查找消息（对齐 Go SDK `FindMessageList`）
#[flutter_rust_bridge::frb]
pub async fn find_message_list(conversation_id: String, client_msg_ids: Vec<String>) -> Result<Vec<LocalChatLog>> {
    let client = client_holder()?;
    let msgs = client.find_message_list(&conversation_id, client_msg_ids).await?;
    Ok(msgs)
}

// ============================================================================
// 消息删除
// ============================================================================

/// 删除单条消息（本地 + 服务端，对齐 Go SDK `DeleteMessage`）
///
/// 先从服务端删除，再从本地删除
#[flutter_rust_bridge::frb]
pub async fn delete_message(conversation_id: String, client_msg_id: String) -> Result<()> {
    let client = client_holder()?;
    // 委托给 message_service（已包含服务端 + 本地删除 + 事件发布）
    client
        .delete_messages(DeleteMessagesReq {
            conversation_id,
            client_msg_ids: vec![client_msg_id],
        })
        .await
        .map_err(|e| anyhow::anyhow!("{}", e))
}

/// 仅从本地删除单条消息（对齐 Go SDK `DeleteMessageFromLocalStorage`）
#[flutter_rust_bridge::frb]
pub async fn delete_message_from_local_storage(conversation_id: String, client_msg_id: String) -> Result<()> {
    let client = client_holder()?;
    client.delete_message_from_local_storage(&conversation_id, &client_msg_id).await?;
    Ok(())
}

/// 删除所有消息（本地 + 服务端，对齐 Go SDK `DeleteAllMsgFromLocalAndSvr`）
#[flutter_rust_bridge::frb]
pub async fn delete_all_msg_from_local_and_svr() -> Result<()> {
    let client = client_holder()?;
    client.delete_all_msg_from_local_and_svr().await?;
    Ok(())
}

/// 仅从本地删除所有消息（软删除，对齐 Go SDK `DeleteAllMsgFromLocal`）
#[flutter_rust_bridge::frb]
pub async fn delete_all_msg_from_local() -> Result<()> {
    let client = client_holder()?;
    client.delete_all_msg_from_local().await?;
    Ok(())
}

/// 清除指定会话并删除所有消息（保留会话记录，对齐 Go SDK `ClearConversationAndDeleteAllMsg`）
#[flutter_rust_bridge::frb]
pub async fn clear_conversation_and_delete_all_msg(conversation_id: String) -> Result<()> {
    let client = client_holder()?;
    client.clear_conversation_and_delete_all_msg(&conversation_id).await?;
    Ok(())
}

/// 删除会话并删除该会话的所有消息（对齐 Go SDK `DeleteConversationAndDeleteAllMsg`）
#[flutter_rust_bridge::frb]
pub async fn delete_conversation_and_delete_all_msg(conversation_id: String) -> Result<()> {
    let client = client_holder()?;
    client.delete_conversation_and_delete_all_msg(&conversation_id).await?;
    Ok(())
}

// ============================================================================
// 消息状态与已读
// ============================================================================

/// 获取服务端时间（对齐 Go SDK `GetServerTime`）
#[flutter_rust_bridge::frb]
pub async fn get_server_time() -> Result<i64> {
    let client = client_holder()?;
    client.get_server_time().await.map_err(|e| anyhow::anyhow!("{}", e))
}

/// 获取全局未读消息数（对齐 Go SDK `GetTotalUnreadMsgCount`）
#[flutter_rust_bridge::frb]
pub async fn get_total_unread_msg_count() -> Result<i64> {
    let client = client_holder()?;
    Ok(client.get_total_unread_msg_count().await?)
}

/// 标记所有会话已读（对齐 Go SDK `MarkAllConversationMessageAsRead`）
///
/// 遍历所有未读会话，逐个通知服务端 + 标记本地已读
#[flutter_rust_bridge::frb]
pub async fn mark_all_conversation_message_as_read() -> Result<()> {
    let client = client_holder()?;
    client.mark_all_conversation_as_read().await.map_err(|e| anyhow::anyhow!("{}", e))
}

// ============================================================================
// Typing 与消息编辑
// ============================================================================

/// Typing 响应结果
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SendTypingResp {
    pub server_msg_id: String,
    pub client_msg_id: String,
    pub send_time: i64,
}

impl From<openim_protocol::sdkws::UserSendMsgResp> for SendTypingResp {
    fn from(resp: openim_protocol::sdkws::UserSendMsgResp) -> Self {
        Self {
            server_msg_id: resp.server_msg_id,
            client_msg_id: resp.client_msg_id,
            send_time: resp.send_time,
        }
    }
}

/// 发送正在输入通知（对齐 Go SDK `TypingStatusUpdate` / `ChangeInputStates`）
///
/// source_id: 对方用户 ID 或群组 ID
/// session_type: 会话类型（1=单聊, 2=群聊）
/// focus: true=正在输入, false=停止输入
#[flutter_rust_bridge::frb]
pub async fn send_typing(source_id: String, session_type: SessionType, focus: bool) -> Result<SendTypingResp> {
    let client = client_holder()?;
    let resp = client.send_typing(&source_id, session_type.into(), focus).await.map_err(|e| anyhow::anyhow!("{}", e))?;
    Ok(resp.into())
}

/// 编辑消息（对齐 Go SDK 消息修改功能）
///
/// 当前实现：构造一条新的文本消息发送，服务端通过 MsgDataToModifyByMQ 广播修改通知。
/// - `conversation_id`: 消息所属会话 ID
/// - `client_msg_id`: 要编辑的消息的 clientMsgId
/// - `content`: 编辑后的新内容（JSON 字符串，如 `{"text":"新内容"}`）
/// - `content_type`: 消息内容类型（如 101=文本, 117=富文本, 118=Markdown）
#[flutter_rust_bridge::frb]
pub async fn edit_message(conversation_id: String, client_msg_id: String, content: String, content_type: i32) -> Result<MsgStruct> {
    let client = client_holder()?;
    let result = client.edit_message(&conversation_id, &client_msg_id, &content, content_type).await?;
    Ok(result.into())
}

// ============================================================================
// 会话同步
// ============================================================================

/// 增量同步会话列表（对齐 Go SDK `IncrSyncConversations`）
///
/// 版本号持久化到数据库，重连后无需全量同步。
/// 收到会话变更通知时调用。
#[flutter_rust_bridge::frb]
pub async fn incr_sync_conversations() -> Result<()> {
    let client = client_holder()?;
    client.incr_sync_conversations().await.map_err(|e| anyhow::anyhow!("{}", e))
}

// ============================================================================
// 本地存储管理
// ============================================================================

/// 设置消息本地扩展字段（对齐 Go SDK `SetMessageLocalEx`）
#[flutter_rust_bridge::frb]
pub async fn set_message_local_ex(conversation_id: String, client_msg_id: String, local_ex: String) -> Result<()> {
    let client = client_holder()?;
    client.set_message_local_ex(&conversation_id, &client_msg_id, &local_ex).await?;
    Ok(())
}

/// 插入群聊消息到本地存储（对齐 Go SDK `InsertGroupMessageToLocalStorage`）
///
/// 用于插入自定义/系统消息到本地数据库
#[flutter_rust_bridge::frb]
pub async fn insert_group_message_to_local_storage(group_id: String, content: String, content_type: i32, send_id: String) -> Result<LocalChatLog> {
    let client = client_holder()?;
    let local_log = client.insert_group_message_to_local_storage(&group_id, &content, content_type, &send_id).await?;
    Ok(local_log)
}

/// 插入单聊消息到本地存储（对齐 Go SDK `InsertSingleMessageToLocalStorage`）
#[flutter_rust_bridge::frb]
pub async fn insert_single_message_to_local_storage(recv_id: String, content: String, content_type: i32, send_id: String) -> Result<LocalChatLog> {
    let client = client_holder()?;
    let local_log = client.insert_single_message_to_local_storage(&recv_id, &content, content_type, &send_id).await?;
    Ok(local_log)
}

/// 发送仅在线消息（对齐 Go SDK `SendMessage` isOnlineOnly=true）
#[flutter_rust_bridge::frb]
pub async fn send_message_online_only(msg_struct: MsgStruct, source_id: String, session_type: crate::constant::SessionType) -> Result<MsgStruct> {
    let client = client_holder()?;
    let mut msg = msg_struct;
    msg.session_type = session_type.into();
    let result = client.send_msg_online_only(msg, &source_id).await?;
    Ok(result)
}

/// 通用消息发送（对齐 Go SDK `SendMessage`，支持离线推送参数）
#[flutter_rust_bridge::frb]
pub async fn send_message(
    msg_struct: MsgStruct,
    source_id: String,
    session_type: crate::constant::SessionType,
    offline_push_info: Option<OfflinePushInfo>,
) -> Result<MsgStruct> {
    let client = client_holder()?;
    let mut msg = msg_struct;
    msg.session_type = session_type.into();
    let push = offline_push_info.map(|p| openim_protocol::sdkws::OfflinePushInfo {
        title: p.title,
        desc: p.desc,
        ex: p.ex,
        i_os_push_sound: p.ios_push_sound,
        i_os_badge_count: p.ios_badge_count,
        signal_info: p.signal_info,
    });
    let result = client.send_msg(msg, &source_id, push).await?;
    Ok(result)
}
