use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::group::{GroupInfo, GroupMember};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info};

/// 群组管理器
pub struct GroupManager {
    /// 群组列表缓存
    groups: Arc<RwLock<HashMap<String, GroupInfo>>>,
    /// 群成员缓存 (group_id -> members)
    members: Arc<RwLock<HashMap<String, HashMap<String, GroupMember>>>>,
    /// 事件总线
    event_bus: Arc<EventBus>,
}

impl GroupManager {
    pub fn new(event_bus: Arc<EventBus>) -> Self {
        Self {
            groups: Arc::new(RwLock::new(HashMap::new())),
            members: Arc::new(RwLock::new(HashMap::new())),
            event_bus,
        }
    }

    /// 获取所有群组
    pub async fn get_joined_group_list(&self) -> Vec<GroupInfo> {
        self.groups.read().await.values().cloned().collect()
    }

    /// 获取单个群组信息
    pub async fn get_groups_info(&self, group_ids: Vec<String>) -> Vec<GroupInfo> {
        let guard = self.groups.read().await;
        group_ids
            .into_iter()
            .filter_map(|id| guard.get(&id).cloned())
            .collect()
    }

    /// 添加群组
    pub async fn add_group(&self, group: GroupInfo) {
        let group_id = group.group_id.clone();
        self.groups.write().await.insert(group_id.clone(), group);
        
        self.event_bus.publish(SdkEvent::GroupCreated {
            group_id,
        });
        
        info!("群组已添加");
    }

    /// 批量添加群组
    pub async fn add_groups(&self, groups: Vec<GroupInfo>) {
        let mut guard = self.groups.write().await;
        for group in groups {
            guard.insert(group.group_id.clone(), group);
        }
    }

    /// 更新群组信息
    pub async fn update_group(&self, group_id: &str, updates: GroupInfoUpdate) -> Result<()> {
        if let Some(group) = self.groups.write().await.get_mut(group_id) {
            if let Some(name) = updates.group_name {
                group.group_name = name;
            }
            if let Some(face_url) = updates.face_url {
                group.face_url = face_url;
            }
            if let Some(intro) = updates.introduction {
                group.introduction = intro;
            }
            if let Some(notice) = updates.notification {
                group.notification = notice;
            }
            
            self.event_bus.publish(SdkEvent::GroupInfoChanged {
                group_id: group_id.to_string(),
            });
            
            info!("群组信息已更新: {}", group_id);
            Ok(())
        } else {
            Err(SdkError::unknown(format!("群组不存在: {}", group_id)))
        }
    }

    /// 删除群组
    pub async fn delete_group(&self, group_id: &str) -> bool {
        let removed = self.groups.write().await.remove(group_id);
        if removed.is_some() {
            self.members.write().await.remove(group_id);
            self.event_bus.publish(SdkEvent::GroupDismissed {
                group_id: group_id.to_string(),
            });
            info!("群组已删除: {}", group_id);
            true
        } else {
            false
        }
    }

    /// 检查是否在群组中
    pub async fn is_in_group(&self, group_id: &str) -> bool {
        self.groups.read().await.contains_key(group_id)
    }

    /// 获取群组数量
    pub async fn group_count(&self) -> usize {
        self.groups.read().await.len()
    }

    // ========== 群成员管理 ==========

    /// 获取群成员列表
    pub async fn get_group_member_list(&self, group_id: &str) -> Vec<GroupMember> {
        if let Some(members) = self.members.read().await.get(group_id) {
            members.values().cloned().collect()
        } else {
            vec![]
        }
    }

    /// 获取单个群成员
    pub async fn get_group_member(&self, group_id: &str, user_id: &str) -> Option<GroupMember> {
        self.members
            .read()
            .await
            .get(group_id)
            .and_then(|members| members.get(user_id).cloned())
    }

    /// 添加群成员
    pub async fn add_group_members(&self, group_id: &str, members: Vec<GroupMember>) {
        let count = members.len();
        let mut guard = self.members.write().await;
        let group_members = guard.entry(group_id.to_string()).or_insert_with(HashMap::new);
        
        for member in members {
            let user_id = member.user_id.clone();
            group_members.insert(user_id, member);
        }
        
        info!("群成员已添加: group={}, count={}", group_id, count);
    }

    /// 删除群成员
    pub async fn remove_group_members(&self, group_id: &str, user_ids: Vec<String>) {
        let count = user_ids.len();
        if let Some(members) = self.members.write().await.get_mut(group_id) {
            for user_id in user_ids {
                members.remove(&user_id);
            }
            info!("群成员已删除: group={}, count={}", group_id, count);
        }
    }

    /// 更新群成员信息
    pub async fn update_group_member(
        &self,
        group_id: &str,
        user_id: &str,
        updates: GroupMemberUpdate,
    ) -> Result<()> {
        if let Some(members) = self.members.write().await.get_mut(group_id) {
            if let Some(member) = members.get_mut(user_id) {
                if let Some(nickname) = updates.nickname {
                    member.nickname = nickname;
                }
                if let Some(role_level) = updates.role_level {
                    member.role_level = role_level;
                }
                
                info!("群成员信息已更新: group={}, user={}", group_id, user_id);
                Ok(())
            } else {
                Err(SdkError::unknown(format!("群成员不存在: {}", user_id)))
            }
        } else {
            Err(SdkError::unknown(format!("群组不存在: {}", group_id)))
        }
    }

    /// 清空所有数据
    pub async fn clear(&self) {
        self.groups.write().await.clear();
        self.members.write().await.clear();
        info!("群组数据已清空");
    }
}

/// 群组信息更新
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct GroupInfoUpdate {
    pub group_name: Option<String>,
    pub face_url: Option<String>,
    pub introduction: Option<String>,
    pub notification: Option<String>,
}

/// 群成员信息更新
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct GroupMemberUpdate {
    pub nickname: Option<String>,
    pub role_level: Option<i32>,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_group(group_id: &str) -> GroupInfo {
        GroupInfo {
            group_id: group_id.to_string(),
            group_name: format!("Group {}", group_id),
            face_url: String::new(),
            introduction: String::new(),
            notification: String::new(),
            owner_user_id: "owner_1".to_string(),
            create_time: 0,
            member_count: 0,
            status: 0,
        }
    }

    fn create_test_member(user_id: &str) -> GroupMember {
        GroupMember {
            group_id: "group_1".to_string(),
            user_id: user_id.to_string(),
            nickname: format!("Member {}", user_id),
            face_url: String::new(),
            role_level: 1,
            join_time: 0,
            join_source: String::new(),
        }
    }

    #[tokio::test]
    async fn test_group_manager_creation() {
        let event_bus = Arc::new(EventBus::new());
        let manager = GroupManager::new(event_bus);

        assert_eq!(manager.group_count().await, 0);
    }

    #[tokio::test]
    async fn test_group_manager_add_and_get() {
        let event_bus = Arc::new(EventBus::new());
        let manager = GroupManager::new(event_bus);

        let group = create_test_group("group_1");
        manager.add_group(group).await;

        assert_eq!(manager.group_count().await, 1);
        assert!(manager.is_in_group("group_1").await);

        let groups = manager.get_groups_info(vec!["group_1".to_string()]).await;
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].group_id, "group_1");
    }

    #[tokio::test]
    async fn test_group_manager_delete() {
        let event_bus = Arc::new(EventBus::new());
        let manager = GroupManager::new(event_bus);

        let group = create_test_group("group_1");
        manager.add_group(group).await;
        assert!(manager.is_in_group("group_1").await);

        let deleted = manager.delete_group("group_1").await;
        assert!(deleted);
        assert!(!manager.is_in_group("group_1").await);
    }

    #[tokio::test]
    async fn test_group_manager_members() {
        let event_bus = Arc::new(EventBus::new());
        let manager = GroupManager::new(event_bus);

        let member1 = create_test_member("user_1");
        let member2 = create_test_member("user_2");
        
        manager.add_group_members("group_1", vec![member1, member2]).await;

        let members = manager.get_group_member_list("group_1").await;
        assert_eq!(members.len(), 2);

        let member = manager.get_group_member("group_1", "user_1").await;
        assert!(member.is_some());

        manager.remove_group_members("group_1", vec!["user_1".to_string()]).await;
        let members = manager.get_group_member_list("group_1").await;
        assert_eq!(members.len(), 1);
    }

    #[tokio::test]
    async fn test_group_manager_update() {
        let event_bus = Arc::new(EventBus::new());
        let manager = GroupManager::new(event_bus);

        let group = create_test_group("group_1");
        manager.add_group(group).await;

        manager
            .update_group("group_1", GroupInfoUpdate {
                group_name: Some("New Group Name".to_string()),
                ..Default::default()
            })
            .await
            .unwrap();

        let groups = manager.get_groups_info(vec!["group_1".to_string()]).await;
        assert_eq!(groups[0].group_name, "New Group Name");
    }
}
