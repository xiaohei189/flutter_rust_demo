//! 会话监听器回调接口

use async_trait::async_trait;
use tracing::info;

/// 会话监听器回调接口（对应 Go 版本的 OnConversationListener）
#[async_trait]
pub trait ConversationListener: Send + Sync {
    /// 同步服务器开始
    async fn on_sync_server_start(&self, reinstalled: bool);

    /// 同步服务器完成
    async fn on_sync_server_finish(&self, reinstalled: bool);

    /// 同步服务器进度
    async fn on_sync_server_progress(&self, progress: i32);

    /// 同步服务器失败
    async fn on_sync_server_failed(&self, reinstalled: bool);

    /// 新会话
    async fn on_new_conversation(&self, conversation_list: String);

    /// 会话变更
    async fn on_conversation_changed(&self, conversation_list: String);

    /// 总未读消息数变更
    async fn on_total_unread_message_count_changed(&self, total_unread_count: i32);

    /// 会话用户输入状态变更
    async fn on_conversation_user_input_status_changed(&self, change: String);
}

/// 空实现（默认监听器），仅输出日志
pub struct EmptyConversationListener;

#[async_trait]
impl ConversationListener for EmptyConversationListener {
    async fn on_sync_server_start(&self, reinstalled: bool) {
        info!("[ConversationListener] on_sync_server_start reinstalled={} (空实现)", reinstalled);
    }
    async fn on_sync_server_finish(&self, reinstalled: bool) {
        info!("[ConversationListener] on_sync_server_finish reinstalled={} (空实现)", reinstalled);
    }
    async fn on_sync_server_progress(&self, progress: i32) {
        info!("[ConversationListener] on_sync_server_progress progress={} (空实现)", progress);
    }
    async fn on_sync_server_failed(&self, reinstalled: bool) {
        info!("[ConversationListener] on_sync_server_failed reinstalled={} (空实现)", reinstalled);
    }
    async fn on_new_conversation(&self, conversation_list: String) {
        info!("[ConversationListener] on_new_conversation len={} (空实现)", conversation_list.len());
    }
    async fn on_conversation_changed(&self, conversation_list: String) {
        info!("[ConversationListener] on_conversation_changed len={} (空实现)", conversation_list.len());
    }
    async fn on_total_unread_message_count_changed(&self, total_unread_count: i32) {
        info!("[ConversationListener] on_total_unread_message_count_changed total_unread_count={} (空实现)", total_unread_count);
    }
    async fn on_conversation_user_input_status_changed(&self, change: String) {
        info!("[ConversationListener] on_conversation_user_input_status_changed len={} (空实现)", change.len());
    }
}
