use crate::domain::event::types::GroupReadReceipt;
use crate::domain::model::group::GroupInfo;

/// group 事件（对齐 Go SDK GroupListener）
pub trait GroupListener: Send + Sync {
    fn on_joined_group_added(&self, _group: &GroupInfo) {}
    fn on_joined_group_deleted(&self, _group: &GroupInfo) {}
    fn on_group_info_changed(&self, _group: &GroupInfo) {}
    fn on_member_added(&self, _group_id: &str) {}
    fn on_member_deleted(&self, _group_id: &str) {}
    fn on_group_read_receipt(&self, _receipts: &[GroupReadReceipt]) {}
}

