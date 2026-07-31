//! UserId — 当前登录用户 ID 的 newtype 封装
//!
//! 统一项目中 user_id 的 4 种混乱表示（String / Arc<RwLock> / Mutex / Arc<Mutex>），
//! 对外只暴露 get/set 语义，隐藏内部锁实现。

use std::sync::Arc;
use tokio::sync::RwLock;

/// 当前登录用户 ID — 跨 task 共享，运行时可变
///
/// # 设计
///
/// - 内部 `Arc<RwLock<String>>`：跨 async task 共享 + 读多写少
/// - Clone 廉价（Arc），所有模块持有同一份引用
/// - 对外只暴露 `get()` / `set()` 语义
///
/// # 用法
///
/// ```ignore
/// let user_id = UserId::new("user_123");
/// assert_eq!(user_id.get().await, "user_123");
/// user_id.set("user_456").await;
/// ```
#[derive(Clone)]
pub struct UserId(Arc<RwLock<String>>);

impl UserId {
    /// 创建新的 UserId
    pub fn new(id: impl Into<String>) -> Self {
        Self(Arc::new(RwLock::new(id.into())))
    }

    /// 获取当前 user_id 的快照（async）
    pub async fn get(&self) -> String {
        self.0.read().await.clone()
    }

    /// 更新 user_id（登录/切换账号时调用）
    pub async fn set(&self, id: impl Into<String>) {
        *self.0.write().await = id.into();
    }

    /// 非 async 上下文中的快捷读取（测试/同步代码）
    pub fn get_blocking(&self) -> String {
        self.0.blocking_read().clone()
    }

    /// 非 async 上下文中的快捷设置
    pub fn set_blocking(&self, id: impl Into<String>) {
        *self.0.blocking_write() = id.into();
    }
}

impl std::fmt::Debug for UserId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let id = self.0.blocking_read();
        f.debug_tuple("UserId").field(&*id).finish()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_user_id_new_and_get() {
        let uid = UserId::new("user_123");
        assert_eq!(uid.get().await, "user_123");
    }

    #[tokio::test]
    async fn test_user_id_set() {
        let uid = UserId::new("old");
        uid.set("new").await;
        assert_eq!(uid.get().await, "new");
    }

    #[tokio::test]
    async fn test_user_id_clone_shares_state() {
        let uid = UserId::new("shared");
        let cloned = uid.clone();
        uid.set("updated").await;
        assert_eq!(cloned.get().await, "updated");
    }

    #[test]
    fn test_user_id_blocking() {
        let uid = UserId::new("sync_user");
        assert_eq!(uid.get_blocking(), "sync_user");
        uid.set_blocking("sync_new");
        assert_eq!(uid.get_blocking(), "sync_new");
    }

    #[test]
    fn test_user_id_debug() {
        let uid = UserId::new("debug_user");
        assert_eq!(format!("{:?}", uid), "UserId(\"debug_user\")");
    }
}
