use crate::domain::event::types::GroupReadReceipt;
use crate::domain::model::group::GroupInfo;
use super::ListenerSet;

/// group 事件（对齐 Go SDK GroupListener）
pub trait GroupListener: Send + Sync {
    fn on_joined_group_added(&self, _group: &GroupInfo) {}
    fn on_joined_group_deleted(&self, _group: &GroupInfo) {}
    fn on_group_info_changed(&self, _group: &GroupInfo) {}
    fn on_member_added(&self, _group_id: &str) {}
    fn on_member_deleted(&self, _group_id: &str) {}
    fn on_group_read_receipt(&self, _receipts: &[GroupReadReceipt]) {}
}

// === 以下为旧 ListenerSet 模式，逐步迁移后删除 ===

pub struct GroupListeners {
    pub pub on_joined_group_added: ListenerSet<GroupInfo>,
    pub on_joined_group_deleted: ListenerSet<GroupInfo>,
    pub on_group_info_changed: ListenerSet<GroupInfo>,
    pub on_member_added: ListenerSet<String>,
    pub on_member_deleted: ListenerSet<String>,
    pub on_group_read_receipt: ListenerSet<Vec<GroupReadReceipt>>,
}

impl GroupListeners {
    pub fn new() -> Self {
        Self {
            on_joined_group_added: ListenerSet::new(),
            on_joined_group_deleted: ListenerSet::new(),
            on_group_info_changed: ListenerSet::new(),
            on_member_added: ListenerSet::new(),
            on_member_deleted: ListenerSet::new(),
            on_group_read_receipt: ListenerSet::new(),
        }
    }
}
