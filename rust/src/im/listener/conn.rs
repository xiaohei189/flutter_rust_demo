//! 连接监听器回调接口（对应 Go 版本的 OnConnListener）

use async_trait::async_trait;
use tracing::info;

/// 连接监听器（对应 Go 版本的 OnConnListener）
///
/// 用于连接建立、失败、被踢下线、Token 失效等事件。
#[async_trait]
pub trait ConnListener: Send + Sync {
    /// 正在连接中
    async fn on_connecting(&self);

    /// 连接成功
    async fn on_connect_success(&self);

    /// 连接失败
    ///
    /// - `err_code`: 错误码
    /// - `err_msg`: 错误信息
    async fn on_connect_failed(&self, err_code: i32, err_msg: String);

    /// 被踢下线
    async fn on_kicked_offline(&self);

    /// 用户 Token 过期
    async fn on_user_token_expired(&self);

    /// 用户 Token 无效
    async fn on_user_token_invalid(&self, err_msg: String);
}

/// 空实现（默认连接监听器），仅输出日志
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
