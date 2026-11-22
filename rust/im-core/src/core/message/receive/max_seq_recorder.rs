//! MaxSeqRecorder — 内存中记录每个会话的最大 seq
//!
//! 对齐 Go SDK `max_seq_recorder.go` IsNewMsg/Incr/Set/Get

use std::collections::HashMap;
use std::sync::RwLock;

/// MaxSeqRecorder — 内存中记录每个会话的最大 seq，用于判断消息是否为"新消息"
/// 对齐 Go SDK `max_seq_recorder.go` IsNewMsg/Incr/Set/Get
pub struct MaxSeqRecorder {
    seqs: RwLock<HashMap<String, i64>>,
}

impl Default for MaxSeqRecorder {
    fn default() -> Self {
        Self::new()
    }
}

impl MaxSeqRecorder {
    pub fn new() -> Self {
        Self { seqs: RwLock::new(HashMap::new()) }
    }

    /// 判断消息 seq 是否比当前记录更新（对齐 Go SDK IsNewMsg）
    pub fn is_new_msg(&self, conversation_id: &str, seq: i64) -> bool {
        let map = self.seqs.read().unwrap();
        let current = map.get(conversation_id).copied().unwrap_or(0);
        seq > current
    }

    /// 递增指定会话的 seq 记录（对齐 Go SDK Incr）
    pub fn incr(&self, conversation_id: &str, num: i64) {
        let mut map = self.seqs.write().unwrap();
        let entry = map.entry(conversation_id.to_string()).or_insert(0);
        *entry += num;
    }

    /// 直接设置会话的 seq 记录（对齐 Go SDK Set）
    pub fn set(&self, conversation_id: &str, seq: i64) {
        let mut map = self.seqs.write().unwrap();
        map.insert(conversation_id.to_string(), seq);
    }

    /// 获取会话当前记录的 seq（对齐 Go SDK Get）
    pub fn get(&self, conversation_id: &str) -> i64 {
        let map = self.seqs.read().unwrap();
        map.get(conversation_id).copied().unwrap_or(0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_max_seq_recorder_new_returns_zero() {
        let recorder = MaxSeqRecorder::new();
        assert_eq!(recorder.get("conv_1"), 0);
        assert_eq!(recorder.get("nonexistent"), 0);
    }

    #[test]
    fn test_max_seq_recorder_is_new_msg() {
        let recorder = MaxSeqRecorder::new();
        assert!(recorder.is_new_msg("conv_1", 1));
        assert!(recorder.is_new_msg("conv_1", 100));
        assert!(!recorder.is_new_msg("conv_1", 0));
        assert!(!recorder.is_new_msg("conv_1", -1));
    }

    #[test]
    fn test_max_seq_recorder_set_and_get() {
        let recorder = MaxSeqRecorder::new();
        recorder.set("conv_1", 10);
        assert_eq!(recorder.get("conv_1"), 10);
        assert_eq!(recorder.get("conv_2"), 0);
        recorder.set("conv_1", 20);
        assert_eq!(recorder.get("conv_1"), 20);
    }

    #[test]
    fn test_max_seq_recorder_incr() {
        let recorder = MaxSeqRecorder::new();
        recorder.incr("conv_1", 1);
        assert_eq!(recorder.get("conv_1"), 1);
        recorder.incr("conv_1", 5);
        assert_eq!(recorder.get("conv_1"), 6);
        recorder.incr("conv_1", -2);
        assert_eq!(recorder.get("conv_1"), 4);
    }

    #[test]
    fn test_max_seq_recorder_is_new_msg_after_set() {
        let recorder = MaxSeqRecorder::new();
        recorder.set("conv_1", 10);
        assert!(!recorder.is_new_msg("conv_1", 10));
        assert!(!recorder.is_new_msg("conv_1", 5));
        assert!(recorder.is_new_msg("conv_1", 11));
    }

    #[test]
    fn test_max_seq_recorder_multiple_conversations() {
        let recorder = MaxSeqRecorder::new();
        recorder.set("conv_a", 100);
        recorder.set("conv_b", 200);
        recorder.incr("conv_a", 3);
        assert_eq!(recorder.get("conv_a"), 103);
        assert_eq!(recorder.get("conv_b"), 200);
        assert!(recorder.is_new_msg("conv_a", 104));
        assert!(!recorder.is_new_msg("conv_b", 200));
        assert!(recorder.is_new_msg("conv_b", 201));
    }
}
