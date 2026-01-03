use std::sync::Arc;

use anyhow::Result;
use openim_protocol::sdkws;

use crate::im::listener::{ConversationListener, AdvancedMsgListener};
use crate::im::friend::FriendListener;
use crate::im::message::types::MsgStruct;
use crate::im::message::models::SeqRange as SeqRangeModel;
use crate::im::model::LocalConversation;

/// OpenIMClient 对外特征接口
///
/// 只暴露上层调用 / mock 所需的能力，隐藏内部实现细节。
#[allow(clippy::too_many_arguments)]
pub trait OpenIMClientApi: Send + Sync {
    // 连接与监听器
    fn set_conversation_listener(&mut self, listener: Arc<dyn ConversationListener>);
    fn set_friend_listener(&mut self, listener: Arc<dyn FriendListener>);
    fn set_advanced_msg_listener(&mut self, listener: Arc<dyn AdvancedMsgListener>);
    fn connect(&mut self) -> Result<()>;

    // 消息发送（常用）
    fn send_text_message(&self, recv_id: String, text: String, session_type: i32) -> Result<()>;
    fn send_message(
        &self,
        recv_id: String,
        group_id: String,
        message: MsgStruct,
        offline_push_info: Option<sdkws::OfflinePushInfo>,
        is_online_only: bool,
    ) -> Result<()>;
    fn send_message_not_oss(
        &self,
        recv_id: String,
        group_id: String,
        message: MsgStruct,
        offline_push_info: Option<sdkws::OfflinePushInfo>,
        is_online_only: bool,
    ) -> Result<()>;

    // WebSocket RPC
    fn ws_get_newest_seq(&self) -> Result<sdkws::GetMaxSeqResp>;
    fn ws_pull_msg_by_range(
        &self,
        ranges: Vec<SeqRangeModel>,
        order: i32,
    ) -> Result<sdkws::PullMessageBySeqsResp>;

    // 本地存储便捷
    fn insert_single_message_to_local_storage(
        &self,
        message_json: String,
        recv_id: String,
        send_id: String,
    ) -> Result<MsgStruct>;
    fn insert_group_message_to_local_storage(
        &self,
        message_json: String,
        group_id: String,
        send_id: String,
    ) -> Result<MsgStruct>;

    // 已读 / 撤回 / 删除
    fn mark_messages_as_read_by_msg_id(
        &self,
        conversation_id: String,
        client_msg_ids: Vec<String>,
    ) -> Result<()>;
    fn mark_conversation_message_as_read_full(&self, conversation_id: String) -> Result<()>;
    fn revoke_message(&self, conversation_id: String, client_msg_id: String) -> Result<()>;
    fn delete_messages(&self, conversation_id: String, seqs: Vec<i64>) -> Result<()>;

    // 会话与好友
    fn get_conversation_list(&self, offset: usize, count: usize) -> Result<Vec<LocalConversation>>;
    fn get_all_conversations(&self) -> Result<Vec<LocalConversation>>;
    fn get_total_unread_count(&self) -> Result<i32>;
    fn get_all_friends(&self) -> Result<Vec<sdkws::FriendInfo>>;
}

