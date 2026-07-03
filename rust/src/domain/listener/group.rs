use crate::domain::model::group::GroupInfo;
use super::ListenerSet;

/// 群组事件（替代 SdkEvent::JoinedGroupAdded/GroupInfoChanged/...）
pub struct GroupListener {
    pub on_joined_group_added: ListenerSet<GroupInfo>,
    pub on_joined_group_deleted: ListenerSet<GroupInfo>,
    pub on_group_info_changed: ListenerSet<GroupInfo>,
    pub on_member_added: ListenerSet<String>,
    pub on_member_deleted: ListenerSet<String>,
    pub on_group_read_receipt: ListenerSet<Vec<crate::domain::event::types::GroupReadReceipt>>,
}

impl GroupListener {
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
