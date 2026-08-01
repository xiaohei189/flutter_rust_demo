//! 消息相关 FFI 桥接
//!
//! 文本/@/自定义消息发送、历史消息查询、撤回/删除/已读/搜索，以及富消息发送（引用/合并/名片/位置/表情）
//! 媒体消息见 `message_media`，Go SDK 补齐 API 见 `message_advanced`
//! 所有操作委托给 OpenIMClient

use crate::api::client::client_holder;
use crate::api::client::OpenIMBridgeClient;
use crate::domain::constant::SessionType;
use crate::domain::model::msg_struct::MsgStruct;
use crate::domain::ports::message::{
    DeleteMessagesReq, MarkMessagesAsReadReq, RevokeMessageReq,
};
use crate::sdk::client::types::{GetHistoryMessagesReq, SearchMessagesReq};
use anyhow::{Result, anyhow};

impl OpenIMBridgeClient {
    // ========== 消息操作 ==========

    #[flutter_rust_bridge::frb]
    pub async fn send_text_message(&self, text: String, source_id: String, session_type: SessionType) -> Result<MsgStruct> {
        self.inner.send_text_message(&text, &source_id, session_type.into()).await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_markdown_message(&self, text: String, source_id: String, session_type: SessionType) -> Result<MsgStruct> {
        self.inner.send_markdown_message(&text, &source_id, session_type.into()).await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_advanced_text_message(&self, text: String, entities: Vec<crate::domain::model::msg_struct::MessageEntity>, source_id: String, session_type: SessionType) -> Result<MsgStruct> {
        self.inner.send_advanced_text_message(&text, entities, &source_id, session_type.into()).await
            .map(|msg| msg.into())
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
    pub async fn mark_conversation_message_as_read(&self, conversation_id: String, session_type: SessionType) -> Result<()> {
        self.inner.mark_conversation_message_as_read(conversation_id, session_type.into()).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn search_local_messages(&self, req: SearchMessagesReq) -> Result<Vec<crate::domain::model::local::LocalChatLog>> {
        self.inner.search_local_messages(req).await
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    // ========== 特殊文本消息发送 ==========

    #[flutter_rust_bridge::frb]
    pub async fn send_at_text_message(
        &self,
        text: String,
        at_user_ids: Vec<String>,
        source_id: String,
        session_type: SessionType,
    ) -> Result<MsgStruct> {
        self.inner.send_at_text_message(&text, at_user_ids, &source_id, session_type.into()).await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_custom_message(
        &self,
        data: String,
        desc: String,
        extension: String,
        source_id: String,
        session_type: SessionType,
    ) -> Result<MsgStruct> {
        self.inner.send_custom_message(&data, &desc, &extension, &source_id, session_type.into()).await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }
}

// ============================================================================
// 创建富消息并发送（对齐 Go SDK CreateXxxMessage + SendMessage）
// ============================================================================

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
    session_type: SessionType,
    quote_text: String,
    quote_client_msg_id: String,
    quote_send_id: String,
    quote_send_time: i64,
) -> Result<MsgStruct> {
    let client = client_holder()?;
    let quote_struct = MsgStruct {
        content: quote_text,
        client_msg_id: quote_client_msg_id,
        send_id: quote_send_id,
        send_time: quote_send_time,
        ..Default::default()
    };
    let result = client.send_quote_message(&text, quote_struct, &source_id, session_type.into()).await?;
    Ok(result.into())
}

/// 发送合并转发消息（对齐 Go SDK `CreateMergerMessage` + `SendMessage`）
#[flutter_rust_bridge::frb]
pub async fn send_merger_message(
    title: String,
    summary_list: Vec<String>,
    source_id: String,
    session_type: SessionType,
) -> Result<MsgStruct> {
    let client = client_holder()?;
    // 将 summary_list 中的内容作为 MsgStruct 文本消息
    let context_list: Vec<MsgStruct> = summary_list
        .iter()
        .map(|s| MsgStruct::create_text_message(s))
        .collect();
    let result = client.send_merger_message(&title, summary_list, context_list, &source_id, session_type.into()).await?;
    Ok(result.into())
}

/// 发送名片消息（对齐 Go SDK `CreateCardMessage` + `SendMessage`）
#[flutter_rust_bridge::frb]
pub async fn send_card_message(
    user_id: String,
    nickname: String,
    face_url: String,
    ex: String,
    source_id: String,
    session_type: SessionType,
) -> Result<MsgStruct> {
    let client = client_holder()?;
    let result = client.send_card_message(&user_id, &nickname, &face_url, &ex, &source_id, session_type.into()).await?;
    Ok(result.into())
}

/// 发送位置消息（对齐 Go SDK `CreateLocationMessage` + `SendMessage`）
#[flutter_rust_bridge::frb]
pub async fn send_location_message(
    description: String,
    longitude: f64,
    latitude: f64,
    source_id: String,
    session_type: SessionType,
) -> Result<MsgStruct> {
    let client = client_holder()?;
    let result = client.send_location_message(&description, longitude, latitude, &source_id, session_type.into()).await?;
    Ok(result.into())
}

/// 发送表情消息（对齐 Go SDK `CreateFaceMessage` + `SendMessage`）
#[flutter_rust_bridge::frb]
pub async fn send_face_message(
    index: i32,
    data: String,
    source_id: String,
    session_type: SessionType,
) -> Result<MsgStruct> {
    let client = client_holder()?;
    let result = client.send_face_message(index, &data, &source_id, session_type.into()).await?;
    Ok(result.into())
}

/// 发送高级引用消息（对齐 Go SDK `CreateAdvancedQuoteMessage` + `SendMessage`）
///
/// 与 `send_quote_message` 的区别：额外支持 `message_entities` 参数，
/// 可以为引用消息的文本添加实体（如 @提及、链接等富文本）。
#[flutter_rust_bridge::frb]
pub async fn send_advanced_quote_message(
    text: String,
    source_id: String,
    session_type: SessionType,
    quote_text: String,
    quote_client_msg_id: String,
    quote_send_id: String,
    quote_send_time: i64,
    message_entities: Vec<crate::domain::model::msg_struct::MessageEntity>,
) -> Result<MsgStruct> {
    let client = client_holder()?;
    let quote_struct = MsgStruct {
        content: quote_text,
        client_msg_id: quote_client_msg_id,
        send_id: quote_send_id,
        send_time: quote_send_time,
        ..Default::default()
    };
    let result = client.send_advanced_quote_message(
        &text, quote_struct, message_entities, &source_id, session_type.into(),
    ).await?;
    Ok(result.into())
}

/// 发送分段 @ 消息（带引用）
#[flutter_rust_bridge::frb]
pub async fn send_at_text_message_with_quote(
    text: String,
    at_user_list: Vec<String>,
    at_users_info: Vec<crate::domain::model::msg_struct::AtInfo>,
    source_id: String,
    session_type: SessionType,
) -> Result<MsgStruct> {
    let client = client_holder()?;
    let result = client.send_at_text_message_with_quote(&text, at_user_list, at_users_info, None, &source_id, session_type.into()).await?;
    Ok(result.into())
}
