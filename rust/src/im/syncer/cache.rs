//! 缓存层（对齐 Go pkg/cache/）
//!
//! 提供内存缓存能力，用于缓存用户信息、群组信息等频繁访问的数据。

use std::collections::HashMap;
use std::hash::Hash;
use std::sync::Arc;
use tokio::sync::RwLock;
use tokio::time::{Duration, Instant};
use tracing::debug;

/// 缓存项
struct CacheItem<V> {
    value: V,
    expires_at: Option<Instant>,
}

impl<V> CacheItem<V> {
    fn new(value: V, ttl: Option<Duration>) -> Self {
        let expires_at = ttl.map(|d| Instant::now() + d);
        Self { value, expires_at }
    }

    fn is_expired(&self) -> bool {
        self.expires_at.map_or(false, |t| Instant::now() > t)
    }
}

/// 内存缓存（对齐 Go pkg/cache/cache.go）
///
/// 支持 TTL 过期、最大容量限制、自动清理过期项。
pub struct Cache<K, V>
where
    K: Eq + Hash + Clone + Send + Sync + 'static,
    V: Clone + Send + Sync + 'static,
{
    items: Arc<RwLock<HashMap<K, CacheItem<V>>>>,
    max_capacity: usize,
    default_ttl: Option<Duration>,
}

impl<K, V> Cache<K, V>
where
    K: Eq + Hash + Clone + Send + Sync + 'static,
    V: Clone + Send + Sync + 'static,
{
    /// 创建新的缓存实例
    pub fn new(max_capacity: usize, default_ttl: Option<Duration>) -> Self {
        Self {
            items: Arc::new(RwLock::new(HashMap::with_capacity(max_capacity.min(1024)))),
            max_capacity,
            default_ttl,
        }
    }

    /// 创建缓存构建器
    pub fn builder() -> CacheBuilder<K, V> {
        CacheBuilder::new()
    }

    /// 获取缓存项
    pub async fn get(&self, key: &K) -> Option<V> {
        let items = self.items.read().await;
        items.get(key).and_then(|item| {
            if item.is_expired() {
                None
            } else {
                Some(item.value.clone())
            }
        })
    }

    /// 设置缓存项
    pub async fn set(&self, key: K, value: V) {
        self.set_with_ttl(key, value, self.default_ttl).await;
    }

    /// 设置缓存项（指定 TTL）
    pub async fn set_with_ttl(&self, key: K, value: V, ttl: Option<Duration>) {
        let mut items = self.items.write().await;

        // 如果达到最大容量，先清理过期项
        if items.len() >= self.max_capacity {
            Self::evict_expired(&mut items);
        }

        // 如果仍然超出容量，随机删除一项
        if items.len() >= self.max_capacity {
            if let Some(k) = items.keys().next().cloned() {
                items.remove(&k);
            }
        }

        items.insert(key, CacheItem::new(value, ttl));
    }

    /// 删除缓存项
    pub async fn remove(&self, key: &K) -> Option<V> {
        let mut items = self.items.write().await;
        items.remove(key).map(|item| item.value)
    }

    /// 检查缓存项是否存在且未过期
    pub async fn contains(&self, key: &K) -> bool {
        let items = self.items.read().await;
        items.get(key).map_or(false, |item| !item.is_expired())
    }

    /// 清空所有缓存
    pub async fn clear(&self) {
        self.items.write().await.clear();
    }

    /// 获取缓存大小
    pub async fn len(&self) -> usize {
        let items = self.items.read().await;
        items.len()
    }

    /// 检查缓存是否为空
    pub async fn is_empty(&self) -> bool {
        self.len().await == 0
    }

    /// 清理所有过期项
    pub async fn cleanup_expired(&self) -> usize {
        let mut items = self.items.write().await;
        let before = items.len();
        Self::evict_expired(&mut items);
        before - items.len()
    }

    /// 内部方法：清理过期项
    fn evict_expired(items: &mut HashMap<K, CacheItem<V>>) {
        items.retain(|_, item| !item.is_expired());
    }

    /// 获取或设置缓存（如果不存在则调用 provided_fn）
    pub async fn get_or_set<F, Fut>(&self, key: K, provided_fn: F) -> V
    where
        F: FnOnce() -> Fut + Send,
        Fut: std::future::Future<Output = V> + Send,
    {
        if let Some(value) = self.get(&key).await {
            return value;
        }

        let value = provided_fn().await;
        self.set(key.clone(), value.clone()).await;
        value
    }
}

impl<K, V> Clone for Cache<K, V>
where
    K: Eq + Hash + Clone + Send + Sync + 'static,
    V: Clone + Send + Sync + 'static,
{
    fn clone(&self) -> Self {
        Self {
            items: self.items.clone(),
            max_capacity: self.max_capacity,
            default_ttl: self.default_ttl,
        }
    }
}

/// 缓存构建器
pub struct CacheBuilder<K, V>
where
    K: Eq + Hash + Clone + Send + Sync + 'static,
    V: Clone + Send + Sync + 'static,
{
    max_capacity: usize,
    default_ttl: Option<Duration>,
    _phantom: std::marker::PhantomData<(K, V)>,
}

impl<K, V> CacheBuilder<K, V>
where
    K: Eq + Hash + Clone + Send + Sync + 'static,
    V: Clone + Send + Sync + 'static,
{
    fn new() -> Self {
        Self {
            max_capacity: 1000,
            default_ttl: None,
            _phantom: std::marker::PhantomData,
        }
    }

    /// 设置最大容量
    pub fn max_capacity(mut self, capacity: usize) -> Self {
        self.max_capacity = capacity;
        self
    }

    /// 设置默认 TTL
    pub fn default_ttl(mut self, ttl: Duration) -> Self {
        self.default_ttl = Some(ttl);
        self
    }

    /// 构建缓存实例
    pub fn build(self) -> Cache<K, V> {
        Cache::new(self.max_capacity, self.default_ttl)
    }
}

/// 用户缓存（对齐 Go pkg/cache/user_cache.go）
///
/// 专门用于缓存用户信息，支持按 userID 缓存。
pub type UserCache = Cache<String, crate::im::dao::user::LocalUser>;

/// 群组缓存
pub type GroupCache = Cache<String, crate::im::dao::group::LocalGroup>;

/// 群成员缓存
pub type GroupMemberCache = Cache<String, Vec<crate::im::dao::group_member::LocalGroupMember>>;
