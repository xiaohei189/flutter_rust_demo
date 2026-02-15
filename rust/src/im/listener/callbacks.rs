//! 与 open_im_sdk_callback/callback_client.go 对齐的监听器回调（合并 conn / conversation / message，并补齐缺失）

use async_trait::async_trait;
use tracing::info;

// ============== OnConnListener ==============

/// 连接监听器（Go: OnConnListener）
#[async_trait]
pub trait ConnListener: Send + Sync {
    async fn on_connecting(&self);
    async fn on_connect_success(&self);
    async fn on_connect_failed(&self, err_code: i32, err_msg: String);
    async fn on_kicked_offline(&self);
    async fn on_user_token_expired(&self);
    async fn on_user_token_invalid(&self, err_msg: String);
}

pub struct EmptyConnListener;

#[async_trait]
impl ConnListener for EmptyConnListener {
    async fn on_connecting(&self) {
        info!("[ConnListener] on_connecting (空实现)");
    }
    async fn on_connect_success(&self) {
        info!("[ConnListener] on_connect_success (空实现)");
    }
    async fn on_connect_failed(&self, err_code: i32, err_msg: String) {
        info!("[ConnListener] on_connect_failed err_code={} err_msg={} (空实现)", err_code, err_msg);
    }
    async fn on_kicked_offline(&self) {
        info!("[ConnListener] on_kicked_offline (空实现)");
    }
    async fn on_user_token_expired(&self) {
        info!("[ConnListener] on_user_token_expired (空实现)");
    }
    async fn on_user_token_invalid(&self, err_msg: String) {
        info!("[ConnListener] on_user_token_invalid err_msg={} (空实现)", err_msg);
    }
}

// ============== OnConversationListener ==============

/// 会话监听器（Go: OnConversationListener）
#[async_trait]
pub trait ConversationListener: Send + Sync {
    async fn on_sync_server_start(&self, reinstalled: bool);
    async fn on_sync_server_finish(&self, reinstalled: bool);
    async fn on_sync_server_progress(&self, progress: i32);
    async fn on_sync_server_failed(&self, reinstalled: bool);
    async fn on_new_conversation(&self, conversation_list: String);
    async fn on_conversation_changed(&self, conversation_list: String);
    async fn on_total_unread_message_count_changed(&self, total_unread_count: i32);
    async fn on_conversation_user_input_status_changed(&self, change: String);
}

pub struct EmptyConversationListener;

#[async_trait]
impl ConversationListener for EmptyConversationListener {
    async fn on_sync_server_start(&self, reinstalled: bool) {
        info!("[EmptyConversationListener] on_sync_server_start reinstalled={}", reinstalled);
    }
    async fn on_sync_server_finish(&self, reinstalled: bool) {
        info!("[EmptyConversationListener] on_sync_server_finish reinstalled={}", reinstalled);
    }
    async fn on_sync_server_progress(&self, progress: i32) {
        info!("[EmptyConversationListener] on_sync_server_progress progress={}", progress);
    }
    async fn on_sync_server_failed(&self, reinstalled: bool) {
        info!("[EmptyConversationListener] on_sync_server_failed reinstalled={}", reinstalled);
    }
    async fn on_new_conversation(&self, conversation_list: String) {
        info!("[EmptyConversationListener] on_new_conversation {:?}", conversation_list);
    }
    async fn on_conversation_changed(&self, conversation_list: String) {
        info!("[EmptyConversationListener] on_conversation_changed {:?}", conversation_list);
    }
    async fn on_total_unread_message_count_changed(&self, total_unread_count: i32) {
        info!(
            "[EmptyConversationListener] on_total_unread_message_count_changed total_unread_count={}",
            total_unread_count
        );
    }
    async fn on_conversation_user_input_status_changed(&self, change: String) {
        info!("[EmptyConversationListener] on_conversation_user_input_status_changed {:?}", change);
    }
}

// ============== OnAdvancedMsgListener ==============

/// 高级消息监听器（Go: OnAdvancedMsgListener）
#[async_trait]
pub trait AdvancedMsgListener: Send + Sync {
    async fn on_recv_new_message(&self, message: String);
    async fn on_recv_c2c_read_receipt(&self, msg_receipt_list: String);
    async fn on_new_recv_message_revoked(&self, message_revoked: String);
    async fn on_recv_offline_new_message(&self, message: String);
    async fn on_msg_deleted(&self, message: String);
    async fn on_recv_online_only_message(&self, message: String);
}

pub struct EmptyAdvancedMsgListener;

#[async_trait]
impl AdvancedMsgListener for EmptyAdvancedMsgListener {
    async fn on_recv_new_message(&self, message: String) {
        info!("[EmptyAdvancedMsgListener] on_recv_new_message {:?}", message);
    }
    async fn on_recv_c2c_read_receipt(&self, msg_receipt_list: String) {
        info!("[EmptyAdvancedMsgListener] on_recv_c2c_read_receipt {:?}", msg_receipt_list);
    }
    async fn on_new_recv_message_revoked(&self, message_revoked: String) {
        info!("[EmptyAdvancedMsgListener] on_new_recv_message_revoked {:?}", message_revoked);
    }
    async fn on_recv_offline_new_message(&self, message: String) {
        info!("[EmptyAdvancedMsgListener] on_recv_offline_new_message {:?}", message);
    }
    async fn on_msg_deleted(&self, message: String) {
        info!("[EmptyAdvancedMsgListener] on_msg_deleted {:?}", message);
    }
    async fn on_recv_online_only_message(&self, message: String) {
        info!("[EmptyAdvancedMsgListener] on_recv_online_only_message {:?}", message);
    }
}

// ============== OnGroupListener（Go 有，Rust 补齐） ==============

/// 群组监听器（Go: OnGroupListener）
#[async_trait]
pub trait GroupListener: Send + Sync {
    async fn on_joined_group_added(&self, group_info: String);
    async fn on_joined_group_deleted(&self, group_info: String);
    async fn on_group_member_added(&self, group_member_info: String);
    async fn on_group_member_deleted(&self, group_member_info: String);
    async fn on_group_application_added(&self, group_application: String);
    async fn on_group_application_deleted(&self, group_application: String);
    async fn on_group_info_changed(&self, group_info: String);
    async fn on_group_dismissed(&self, group_info: String);
    async fn on_group_member_info_changed(&self, group_member_info: String);
    async fn on_group_application_accepted(&self, group_application: String);
    async fn on_group_application_rejected(&self, group_application: String);
}

pub struct EmptyGroupListener;

#[async_trait]
impl GroupListener for EmptyGroupListener {
    async fn on_joined_group_added(&self, _group_info: String) {}
    async fn on_joined_group_deleted(&self, _group_info: String) {}
    async fn on_group_member_added(&self, _group_member_info: String) {}
    async fn on_group_member_deleted(&self, _group_member_info: String) {}
    async fn on_group_application_added(&self, _group_application: String) {}
    async fn on_group_application_deleted(&self, _group_application: String) {}
    async fn on_group_info_changed(&self, _group_info: String) {}
    async fn on_group_dismissed(&self, _group_info: String) {}
    async fn on_group_member_info_changed(&self, _group_member_info: String) {}
    async fn on_group_application_accepted(&self, _group_application: String) {}
    async fn on_group_application_rejected(&self, _group_application: String) {}
}

// ============== OnUserListener（Go 有，Rust 补齐） ==============

/// 用户监听器（Go: OnUserListener）
#[async_trait]
pub trait UserListener: Send + Sync {
    async fn on_self_info_updated(&self, user_info: String);
    async fn on_user_status_changed(&self, user_online_status: String);
}

pub struct EmptyUserListener;

#[async_trait]
impl UserListener for EmptyUserListener {
    async fn on_self_info_updated(&self, _user_info: String) {}
    async fn on_user_status_changed(&self, _user_online_status: String) {}
}

// ============== OnCustomBusinessListener（Go 有，Rust 补齐） ==============

/// 自定义业务消息监听器（Go: OnCustomBusinessListener）
#[async_trait]
pub trait CustomBusinessListener: Send + Sync {
    async fn on_recv_custom_business_message(&self, business_message: String);
}

pub struct EmptyCustomBusinessListener;

#[async_trait]
impl CustomBusinessListener for EmptyCustomBusinessListener {
    async fn on_recv_custom_business_message(&self, _business_message: String) {}
}

// ============== OnMessageKvInfoListener（Go 有，Rust 补齐） ==============

/// 消息 KV 变更监听器（Go: OnMessageKvInfoListener）
#[async_trait]
pub trait MessageKvInfoListener: Send + Sync {
    async fn on_message_kv_info_changed(&self, message_changed_list: String);
}

pub struct EmptyMessageKvInfoListener;

#[async_trait]
impl MessageKvInfoListener for EmptyMessageKvInfoListener {
    async fn on_message_kv_info_changed(&self, _message_changed_list: String) {}
}
