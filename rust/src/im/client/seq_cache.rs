use std::collections::HashMap;
use std::sync::Arc;

/// 序列号映射缓存（完全参考 Go SDK 的 ConversationSeqContextCache）
///
/// 用于跟踪消息拉取的结束序列号，避免重复拉取
#[derive(Clone)]
pub struct ConversationSeqContextCache {
    cache: Arc<std::sync::Mutex<HashMap<String, i64>>>,
}

impl ConversationSeqContextCache {
    pub fn new() -> Self {
        Self {
            cache: Arc::new(std::sync::Mutex::new(HashMap::new())),
        }
    }

    fn get_key(conversation_id: &str, view_type: i32) -> String {
        format!("{}::viewType::{}", conversation_id, view_type)
    }

    pub fn load(&self, conversation_id: &str, view_type: i32) -> Option<i64> {
        let key = Self::get_key(conversation_id, view_type);
        let cache = self.cache.lock().unwrap();
        cache.get(&key).copied()
    }

    pub fn store(&self, conversation_id: &str, view_type: i32, seq: i64) {
        let key = Self::get_key(conversation_id, view_type);
        let mut cache = self.cache.lock().unwrap();
        cache.insert(key, seq);
    }

    #[allow(dead_code)]
    pub fn store_with_func<F>(&self, conversation_id: &str, view_type: i32, seq: i64, func: F)
    where
        F: FnOnce(&str, i64) -> bool,
    {
        let key = Self::get_key(conversation_id, view_type);
        let mut cache = self.cache.lock().unwrap();
        if func(&key, seq) {
            cache.insert(key, seq);
        }
    }

    pub fn delete(&self, conversation_id: &str, view_type: i32) {
        let key = Self::get_key(conversation_id, view_type);
        let mut cache = self.cache.lock().unwrap();
        cache.remove(&key);
    }

    #[allow(dead_code)]
    pub fn delete_by_view_type(&self, view_type: i32) {
        let mut cache = self.cache.lock().unwrap();
        let suffix = format!("::viewType::{}", view_type);
        cache.retain(|k, _| !k.ends_with(&suffix));
    }
}
