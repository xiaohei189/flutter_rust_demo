//! 客户端全局回调结构体
//!
//! 将连接、会话、消息等各类监听器集中在一个结构体中，便于传递和扩展。

use crate::im::friend::FriendListener;
use crate::im::listener::{AdvancedMsgListener, ConnListener, ConversationListener, UserListener};
use std::sync::Arc;

/// 客户端全局回调（连接、会话、消息、好友、用户等），各字段代表一种类型，后续扩展时新增字段即可
#[derive(Clone, Default)]
pub struct ClientCallbacks {
    /// 连接状态回调
    pub conn_listener: Option<Arc<dyn ConnListener>>,
    /// 会话变更回调
    pub conversation_listener: Option<Arc<dyn ConversationListener>>,
    /// 高级消息回调
    pub advanced_msg_listener: Option<Arc<dyn AdvancedMsgListener>>,
    /// 好友变更回调
    pub friend_listener: Option<Arc<dyn FriendListener>>,
    /// 用户信息回调（Go: OnUserListener，含 OnSelfInfoUpdated）
    pub user_listener: Option<Arc<dyn UserListener>>,
}
