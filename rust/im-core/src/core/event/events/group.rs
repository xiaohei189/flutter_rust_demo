use crate::core::event::events::message::GroupReadReceipt;
use crate::domain::model::group::{GroupInfo, GroupMember};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum GroupEvent {
    JoinedGroupAdded(GroupInfo),
    JoinedGroupDeleted(GroupInfo),
    GroupInfoChanged(GroupInfo),
    MemberAdded(GroupMember),
    MemberDeleted(GroupMember),
    MemberInfoChanged(GroupMember),
    GroupReadReceipt(Vec<GroupReadReceipt>),
    ApplicationAdded(String),
    ApplicationDeleted(String),
    ApplicationApproved(String),
    ApplicationRejected(String),
    Dismissed(GroupInfo),
}

impl GroupEvent {
    /// 事件类型字符串（用于日志与测试）
    pub fn as_str(&self) -> &'static str {
        match self {
            GroupEvent::JoinedGroupAdded(_) => "joined_group_added",
            GroupEvent::JoinedGroupDeleted(_) => "joined_group_deleted",
            GroupEvent::GroupInfoChanged(_) => "group_info_changed",
            GroupEvent::MemberAdded(_) => "member_added",
            GroupEvent::MemberDeleted(_) => "member_deleted",
            GroupEvent::MemberInfoChanged(_) => "member_info_changed",
            GroupEvent::GroupReadReceipt(_) => "group_read_receipt",
            GroupEvent::ApplicationAdded(_) => "application_added",
            GroupEvent::ApplicationDeleted(_) => "application_deleted",
            GroupEvent::ApplicationApproved(_) => "application_approved",
            GroupEvent::ApplicationRejected(_) => "application_rejected",
            GroupEvent::Dismissed(_) => "dismissed",
        }
    }
}

/// group 事件（对齐 Go SDK GroupListener）
pub trait GroupListener: Send + Sync {
    fn on_joined_group_added(&self, _group: &GroupInfo) {}
    fn on_joined_group_deleted(&self, _group: &GroupInfo) {}
    fn on_group_info_changed(&self, _group: &GroupInfo) {}
    fn on_member_added(&self, _member: &GroupMember) {}
    fn on_member_deleted(&self, _member: &GroupMember) {}
    fn on_member_info_changed(&self, _member: &GroupMember) {}
    fn on_group_read_receipt(&self, _receipts: &[GroupReadReceipt]) {}
    fn on_application_added(&self, _group_id: &str) {}
    fn on_application_deleted(&self, _group_id: &str) {}
    fn on_application_approved(&self, _group_id: &str) {}
    fn on_application_rejected(&self, _group_id: &str) {}
    fn on_dismissed(&self, _group: &GroupInfo) {}
}

/// 事件 → 回调 的统一分发（Service 通过它把领域事件交给 Listener）
pub trait GroupListenerExt: GroupListener {
    fn emit(&self, event: GroupEvent) {
        match event {
            GroupEvent::JoinedGroupAdded(group) => self.on_joined_group_added(&group),
            GroupEvent::JoinedGroupDeleted(group) => self.on_joined_group_deleted(&group),
            GroupEvent::GroupInfoChanged(group) => self.on_group_info_changed(&group),
            GroupEvent::MemberAdded(member) => self.on_member_added(&member),
            GroupEvent::MemberDeleted(member) => self.on_member_deleted(&member),
            GroupEvent::MemberInfoChanged(member) => self.on_member_info_changed(&member),
            GroupEvent::GroupReadReceipt(receipts) => self.on_group_read_receipt(&receipts),
            GroupEvent::ApplicationAdded(group_id) => self.on_application_added(&group_id),
            GroupEvent::ApplicationDeleted(group_id) => self.on_application_deleted(&group_id),
            GroupEvent::ApplicationApproved(group_id) => self.on_application_approved(&group_id),
            GroupEvent::ApplicationRejected(group_id) => self.on_application_rejected(&group_id),
            GroupEvent::Dismissed(group) => self.on_dismissed(&group),
        }
    }
}
impl<T: GroupListener + ?Sized> GroupListenerExt for T {}
