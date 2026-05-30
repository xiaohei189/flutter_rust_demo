//! 通用同步器框架（对齐 Go pkg/syncer/syncer.go）
//!
//! 提供泛型数据同步能力，支持全量同步、增量同步、版本控制、本地缓存。
//! 每个业务模块（Group/Relation/User）可复用此同步器。

use anyhow::Result;
use serde::de::DeserializeOwned;
use std::collections::HashMap;
use std::hash::Hash;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn};

/// 同步器配置
pub struct SyncerConfig {
    /// 同步器名称（用于日志）
    pub name: String,
    /// 每页拉取数量
    pub batch_page_size: i32,
    /// 是否启用缓存
    pub enable_cache: bool,
}

impl Default for SyncerConfig {
    fn default() -> Self {
        Self {
            name: "syncer".to_string(),
            batch_page_size: 500,
            enable_cache: true,
        }
    }
}

/// 泛型同步器（对齐 Go Syncer[T, Resp, Key]）
///
/// # 类型参数
/// * `T` - 数据项类型（必须可克隆、可序列化、线程安全）
/// * `K` - 缓存键类型（必须可哈希、可克隆、线程安全）
pub struct Syncer<T, K>
where
    T: Clone + Send + Sync + 'static,
    K: Clone + Eq + Hash + Send + Sync + 'static,
{
    config: SyncerConfig,
    /// 插入回调
    on_insert: Option<Box<dyn Fn(&[T]) + Send + Sync>>,
    /// 删除回调
    on_delete: Option<Box<dyn Fn(&[T]) + Send + Sync>>,
    /// 更新回调
    on_update: Option<Box<dyn Fn(&[T]) + Send + Sync>>,
    /// 通知回调
    on_notice: Option<Box<dyn Fn(&[T]) + Send + Sync>>,
    /// 内存缓存（对齐 Go WithCache）
    cache: Option<Arc<RwLock<HashMap<K, T>>>>,
}

impl<T, K> Syncer<T, K>
where
    T: Clone + Send + Sync + 'static,
    K: Clone + Eq + Hash + Send + Sync + 'static,
{
    /// 创建新的同步器
    pub fn new(config: SyncerConfig) -> Self {
        let cache = if config.enable_cache {
            Some(Arc::new(RwLock::new(HashMap::new())))
        } else {
            None
        };

        Self {
            config,
            on_insert: None,
            on_delete: None,
            on_update: None,
            on_notice: None,
            cache,
        }
    }

    /// 设置插入回调（对齐 Go WithInsert）
    pub fn with_insert<F>(mut self, callback: F) -> Self
    where
        F: Fn(&[T]) + Send + Sync + 'static,
    {
        self.on_insert = Some(Box::new(callback));
        self
    }

    /// 设置删除回调（对齐 Go WithDelete）
    pub fn with_delete<F>(mut self, callback: F) -> Self
    where
        F: Fn(&[T]) + Send + Sync + 'static,
    {
        self.on_delete = Some(Box::new(callback));
        self
    }

    /// 设置更新回调（对齐 Go WithUpdate）
    pub fn with_update<F>(mut self, callback: F) -> Self
    where
        F: Fn(&[T]) + Send + Sync + 'static,
    {
        self.on_update = Some(Box::new(callback));
        self
    }

    /// 设置通知回调（对齐 Go WithNotice）
    pub fn with_notice<F>(mut self, callback: F) -> Self
    where
        F: Fn(&[T]) + Send + Sync + 'static,
    {
        self.on_notice = Some(Box::new(callback));
        self
    }

    /// 全量同步（对齐 Go FullSync）
    ///
    /// # 参数
    /// * `fetcher` - 分页数据获取函数，返回 (数据列表, 是否还有更多)
    /// * `extract_key` - 从数据项提取缓存键的函数
    /// * `upsert_local` - 将数据项插入或更新到本地数据库的函数
    pub async fn full_sync<Fut, FetchFn, KeyFn, UpsertFn>(
        &self,
        fetcher: FetchFn,
        extract_key: KeyFn,
        upsert_local: UpsertFn,
    ) -> Result<()>
    where
        Fut: std::future::Future<Output = Result<(Vec<T>, bool)>>,
        FetchFn: Fn(i32, i32) -> Fut + Send + Sync,
        KeyFn: Fn(&T) -> K + Send + Sync,
        UpsertFn: Fn(&T) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<()>> + Send>> + Send + Sync,
    {
        info!("[Syncer:{}] 开始全量同步", self.config.name);

        let mut page = 1;
        let mut total_count = 0;

        loop {
            let (items, has_more) = fetcher(page, self.config.batch_page_size).await?;
            if items.is_empty() {
                break;
            }

            let count = items.len();
            total_count += count;

            // 批量插入或更新到本地
            for item in &items {
                upsert_local(item).await?;
            }

            // 触发插入回调
            if let Some(ref on_insert) = self.on_insert {
                on_insert(&items);
            }

            // 更新缓存
            if let Some(ref cache) = self.cache {
                let mut cache_guard = cache.write().await;
                for item in &items {
                    let key = extract_key(item);
                    cache_guard.insert(key, item.clone());
                }
            }

            debug!("[Syncer:{}] 第 {} 页同步完成，共 {} 条", self.config.name, page, count);

            if !has_more {
                break;
            }

            page += 1;
        }

        info!("[Syncer:{}] 全量同步完成，共 {} 条", self.config.name, total_count);
        Ok(())
    }

    /// 增量同步（对齐 Go IncrementalSync）
    ///
    /// # 参数
    /// * `fetcher` - 增量数据获取函数
    /// * `extract_key` - 从数据项提取缓存键的函数
    /// * `get_local_items` - 获取本地所有数据项的函数
    /// * `upsert_local` - 将数据项插入或更新到本地数据库的函数
    /// * `delete_local` - 从本地数据库删除数据项的函数
    pub async fn incremental_sync<Fut, FetchFn, KeyFn, GetLocalFn, UpsertFn, DeleteFn>(
        &self,
        fetcher: FetchFn,
        extract_key: KeyFn,
        get_local_items: GetLocalFn,
        upsert_local: UpsertFn,
        delete_local: DeleteFn,
    ) -> Result<()>
    where
        Fut: std::future::Future<Output = Result<Vec<T>>>,
        FetchFn: Fn() -> Fut + Send + Sync,
        KeyFn: Fn(&T) -> K + Send + Sync,
        GetLocalFn: Fn() -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<Vec<T>>> + Send>> + Send + Sync,
        UpsertFn: Fn(&T) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<()>> + Send>> + Send + Sync,
        DeleteFn: Fn(&K) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<()>> + Send>> + Send + Sync,
    {
        info!("[Syncer:{}] 开始增量同步", self.config.name);

        // 获取服务端数据
        let server_items = fetcher().await?;
        if server_items.is_empty() {
            info!("[Syncer:{}] 增量同步完成，无变更", self.config.name);
            return Ok(());
        }

        // 获取本地数据
        let local_items = get_local_items().await?;

        // 构建映射
        let server_map: HashMap<K, T> = server_items
            .iter()
            .map(|item| (extract_key(item), item.clone()))
            .collect();

        let local_map: HashMap<K, T> = local_items
            .iter()
            .map(|item| (extract_key(item), item.clone()))
            .collect();

        let mut inserted = Vec::new();
        let mut updated = Vec::new();
        let mut deleted = Vec::new();

        // 检查新增和更新
        for (key, server_item) in &server_map {
            if let Some(local_item) = local_map.get(key) {
                // 检查是否有变更（需要 T 实现 PartialEq）
                if self.is_changed(local_item, server_item) {
                    upsert_local(server_item).await?;
                    updated.push(server_item.clone());
                }
            } else {
                // 新增
                upsert_local(server_item).await?;
                inserted.push(server_item.clone());
            }
        }

        // 检查删除
        for (key, local_item) in &local_map {
            if !server_map.contains_key(key) {
                delete_local(key).await?;
                deleted.push(local_item.clone());
            }
        }

        // 触发回调
        if !inserted.is_empty() {
            if let Some(ref on_insert) = self.on_insert {
                on_insert(&inserted);
            }
            info!("[Syncer:{}] 新增 {} 条", self.config.name, inserted.len());
        }

        if !updated.is_empty() {
            if let Some(ref on_update) = self.on_update {
                on_update(&updated);
            }
            info!("[Syncer:{}] 更新 {} 条", self.config.name, updated.len());
        }

        if !deleted.is_empty() {
            if let Some(ref on_delete) = self.on_delete {
                on_delete(&deleted);
            }
            info!("[Syncer:{}] 删除 {} 条", self.config.name, deleted.len());
        }

        // 更新缓存
        if let Some(ref cache) = self.cache {
            let mut cache_guard = cache.write().await;
            for item in &inserted {
                cache_guard.insert(extract_key(item), item.clone());
            }
            for item in &updated {
                cache_guard.insert(extract_key(item), item.clone());
            }
            for item in &deleted {
                cache_guard.remove(&extract_key(item));
            }
        }

        info!(
            "[Syncer:{}] 增量同步完成: 新增={}, 更新={}, 删除={}",
            self.config.name,
            inserted.len(),
            updated.len(),
            deleted.len()
        );

        Ok(())
    }

    /// 从缓存获取数据
    pub async fn get_from_cache(&self, key: &K) -> Option<T> {
        if let Some(ref cache) = self.cache {
            cache.read().await.get(key).cloned()
        } else {
            None
        }
    }

    /// 更新缓存
    pub async fn update_cache(&self, key: K, value: T) {
        if let Some(ref cache) = self.cache {
            cache.write().await.insert(key, value);
        }
    }

    /// 从缓存删除
    pub async fn remove_from_cache(&self, key: &K) {
        if let Some(ref cache) = self.cache {
            cache.write().await.remove(key);
        }
    }

    /// 清空缓存
    pub async fn clear_cache(&self) {
        if let Some(ref cache) = self.cache {
            cache.write().await.clear();
        }
    }

    /// 检查数据项是否有变更（默认实现，子类可重写）
    fn is_changed(&self, _local: &T, _server: &T) -> bool {
        // 默认认为有变更，子类可通过 PartialEq 实现精确比较
        true
    }
}

/// 同步器构建器（对齐 Go 的链式调用风格）
pub struct SyncerBuilder<T, K>
where
    T: Clone + Send + Sync + 'static,
    K: Clone + Eq + Hash + Send + Sync + 'static,
{
    config: SyncerConfig,
    on_insert: Option<Box<dyn Fn(&[T]) + Send + Sync>>,
    on_delete: Option<Box<dyn Fn(&[T]) + Send + Sync>>,
    on_update: Option<Box<dyn Fn(&[T]) + Send + Sync>>,
    on_notice: Option<Box<dyn Fn(&[T]) + Send + Sync>>,
}

impl<T, K> SyncerBuilder<T, K>
where
    T: Clone + Send + Sync + 'static,
    K: Clone + Eq + Hash + Send + Sync + 'static,
{
    pub fn new(name: &str) -> Self {
        Self {
            config: SyncerConfig {
                name: name.to_string(),
                ..Default::default()
            },
            on_insert: None,
            on_delete: None,
            on_update: None,
            on_notice: None,
        }
    }

    pub fn batch_page_size(mut self, size: i32) -> Self {
        self.config.batch_page_size = size;
        self
    }

    pub fn enable_cache(mut self, enable: bool) -> Self {
        self.config.enable_cache = enable;
        self
    }

    pub fn on_insert<F>(mut self, callback: F) -> Self
    where
        F: Fn(&[T]) + Send + Sync + 'static,
    {
        self.on_insert = Some(Box::new(callback));
        self
    }

    pub fn on_delete<F>(mut self, callback: F) -> Self
    where
        F: Fn(&[T]) + Send + Sync + 'static,
    {
        self.on_delete = Some(Box::new(callback));
        self
    }

    pub fn on_update<F>(mut self, callback: F) -> Self
    where
        F: Fn(&[T]) + Send + Sync + 'static,
    {
        self.on_update = Some(Box::new(callback));
        self
    }

    pub fn on_notice<F>(mut self, callback: F) -> Self
    where
        F: Fn(&[T]) + Send + Sync + 'static,
    {
        self.on_notice = Some(Box::new(callback));
        self
    }

    pub fn build(self) -> Syncer<T, K> {
        let cache = if self.config.enable_cache {
            Some(Arc::new(RwLock::new(HashMap::new())))
        } else {
            None
        };

        Syncer {
            config: self.config,
            on_insert: self.on_insert,
            on_delete: self.on_delete,
            on_update: self.on_update,
            on_notice: self.on_notice,
            cache,
        }
    }
}
