use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

/// 内存缓存管理器
pub struct CacheManager {
    /// 通用键值缓存
    data: Arc<RwLock<HashMap<String, String>>>,
}

impl CacheManager {
    pub fn new() -> Self {
        Self {
            data: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// 获取缓存值
    pub async fn get(&self, key: &str) -> Option<String> {
        self.data.read().await.get(key).cloned()
    }

    /// 设置缓存值
    pub async fn set(&self, key: String, value: String) {
        self.data.write().await.insert(key, value);
    }

    /// 删除缓存值
    pub async fn remove(&self, key: &str) {
        self.data.write().await.remove(key);
    }

    /// 清空所有缓存
    pub async fn clear(&self) {
        self.data.write().await.clear();
    }

    /// 检查缓存是否存在
    pub async fn contains(&self, key: &str) -> bool {
        self.data.read().await.contains_key(key)
    }
}

impl Default for CacheManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_cache_set_and_get() {
        let cache = CacheManager::new();
        cache.set("key1".to_string(), "value1".to_string()).await;
        let value = cache.get("key1").await;
        assert_eq!(value, Some("value1".to_string()));
    }

    #[tokio::test]
    async fn test_cache_get_nonexistent() {
        let cache = CacheManager::new();
        let value = cache.get("nonexistent").await;
        assert_eq!(value, None);
    }

    #[tokio::test]
    async fn test_cache_remove() {
        let cache = CacheManager::new();
        cache.set("key1".to_string(), "value1".to_string()).await;
        cache.remove("key1").await;
        let value = cache.get("key1").await;
        assert_eq!(value, None);
    }

    #[tokio::test]
    async fn test_cache_clear() {
        let cache = CacheManager::new();
        cache.set("key1".to_string(), "value1".to_string()).await;
        cache.set("key2".to_string(), "value2".to_string()).await;
        cache.clear().await;
        assert_eq!(cache.get("key1").await, None);
        assert_eq!(cache.get("key2").await, None);
    }

    #[tokio::test]
    async fn test_cache_contains() {
        let cache = CacheManager::new();
        cache.set("key1".to_string(), "value1".to_string()).await;
        assert!(cache.contains("key1").await);
        assert!(!cache.contains("key2").await);
    }
}
