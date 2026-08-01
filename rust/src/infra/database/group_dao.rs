use crate::domain::model::local::{LocalGroup, LocalGroupMember};
use crate::domain::error::{Result, SdkError};
use sqlx::SqlitePool;

pub struct GroupDao {
    pool: SqlitePool,
}

impl GroupDao {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    // ---- group ----

    pub async fn upsert_group(&self, group: &LocalGroup) -> Result<()> {
        sqlx::query(
            "INSERT INTO local_groups (group_id, name, notification, introduction, face_url, create_time, status, creator_user_id, group_type, owner_user_id, member_count, ex, attached_info, need_verification, look_member_info, apply_member_friend, notification_update_time, notification_user_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(group_id) DO UPDATE SET name=excluded.name, notification=excluded.notification, introduction=excluded.introduction, face_url=excluded.face_url, create_time=excluded.create_time, status=excluded.status, creator_user_id=excluded.creator_user_id, group_type=excluded.group_type, owner_user_id=excluded.owner_user_id, member_count=excluded.member_count, ex=excluded.ex, attached_info=excluded.attached_info, need_verification=excluded.need_verification, look_member_info=excluded.look_member_info, apply_member_friend=excluded.apply_member_friend, notification_update_time=excluded.notification_update_time, notification_user_id=excluded.notification_user_id",
        )
        .bind(&group.group_id)
        .bind(&group.name)
        .bind(&group.notification)
        .bind(&group.introduction)
        .bind(&group.face_url)
        .bind(group.create_time)
        .bind(group.status)
        .bind(&group.creator_user_id)
        .bind(group.group_type)
        .bind(&group.owner_user_id)
        .bind(group.member_count)
        .bind(&group.ex)
        .bind(&group.attached_info)
        .bind(group.need_verification)
        .bind(group.look_member_info)
        .bind(group.apply_member_friend)
        .bind(group.notification_update_time)
        .bind(&group.notification_user_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("upsert group: {}", e)))?;
        Ok(())
    }

    pub async fn get_all_groups(&self) -> Result<Vec<LocalGroup>> {
        let rows = sqlx::query_as::<_, LocalGroup>(
            "SELECT * FROM local_groups ORDER BY create_time DESC",
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query all groups: {}", e)))?;
        Ok(rows)
    }

    pub async fn get_group(&self, group_id: &str) -> Result<Option<LocalGroup>> {
        let row = sqlx::query_as::<_, LocalGroup>(
            "SELECT * FROM local_groups WHERE group_id = ?",
        )
        .bind(group_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query group: {}", e)))?;
        Ok(row)
    }

    pub async fn delete_group(&self, group_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_groups WHERE group_id = ?")
            .bind(group_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("delete group: {}", e)))?;
        Ok(())
    }

    // ---- member ----

    pub async fn upsert_member(&self, member: &LocalGroupMember) -> Result<()> {
        sqlx::query(
            "INSERT INTO local_group_members (group_id, user_id, nickname, user_group_face_url, role_level, join_time, join_source, inviter_user_id, mute_end_time, operator_user_id, ex, attached_info) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(group_id, user_id) DO UPDATE SET nickname=excluded.nickname, user_group_face_url=excluded.user_group_face_url, role_level=excluded.role_level, join_time=excluded.join_time, join_source=excluded.join_source, inviter_user_id=excluded.inviter_user_id, mute_end_time=excluded.mute_end_time, operator_user_id=excluded.operator_user_id, ex=excluded.ex, attached_info=excluded.attached_info",
        )
        .bind(&member.group_id)
        .bind(&member.user_id)
        .bind(&member.nickname)
        .bind(&member.user_group_face_url)
        .bind(member.role_level)
        .bind(member.join_time)
        .bind(member.join_source)
        .bind(&member.inviter_user_id)
        .bind(member.mute_end_time)
        .bind(&member.operator_user_id)
        .bind(&member.ex)
        .bind(&member.attached_info)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("upsert member: {}", e)))?;
        Ok(())
    }

    pub async fn batch_upsert_members(&self, members: &[LocalGroupMember]) -> Result<()> {
        for member in members {
            self.upsert_member(member).await?;
        }
        Ok(())
    }

    pub async fn get_members(&self, group_id: &str) -> Result<Vec<LocalGroupMember>> {
        let rows = sqlx::query_as::<_, LocalGroupMember>(
            "SELECT * FROM local_group_members WHERE group_id = ? ORDER BY role_level DESC, join_time ASC",
        )
        .bind(group_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("query members: {}", e)))?;
        Ok(rows)
    }

    pub async fn delete_member(&self, group_id: &str, user_id: &str) -> Result<()> {
        sqlx::query(
            "DELETE FROM local_group_members WHERE group_id = ? AND user_id = ?",
        )
        .bind(group_id)
        .bind(user_id)
        .execute(&self.pool)
        .await
        .map_err(|e| SdkError::database(format!("delete member: {}", e)))?;
        Ok(())
    }

    pub async fn delete_members_by_group(&self, group_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM local_group_members WHERE group_id = ?")
            .bind(group_id)
            .execute(&self.pool)
            .await
            .map_err(|e| SdkError::database(format!("delete members: {}", e)))?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::database::pool::create_pool_memory;

    #[tokio::test]
    async fn test_group_crud() {
        let pool = create_pool_memory().await.unwrap();
        let dao = GroupDao::new(pool);

        let group = LocalGroup {
            group_id: "g_1".into(),
            name: "TestGroup".into(),
            notification: String::new(),
            introduction: String::new(),
            face_url: String::new(),
            create_time: 1000,
            status: 0,
            creator_user_id: "user_1".into(),
            group_type: 1,
            owner_user_id: "user_1".into(),
            member_count: 1,
            ex: String::new(),
            attached_info: String::new(),
            need_verification: 0,
            look_member_info: 0,
            apply_member_friend: 0,
            notification_update_time: 0,
            notification_user_id: String::new(),
        };

        dao.upsert_group(&group).await.unwrap();
        let found = dao.get_group("g_1").await.unwrap();
        assert!(found.is_some());
        assert_eq!(found.unwrap().name, "TestGroup");
    }

    #[tokio::test]
    async fn test_member_crud() {
        let pool = create_pool_memory().await.unwrap();
        let dao = GroupDao::new(pool);

        let member = LocalGroupMember {
            group_id: "g_1".into(),
            user_id: "user_1".into(),
            nickname: "Alice".into(),
            user_group_face_url: String::new(),
            role_level: 1,
            join_time: 1000,
            join_source: 1,
            inviter_user_id: String::new(),
            mute_end_time: 0,
            operator_user_id: String::new(),
            ex: String::new(),
            attached_info: String::new(),
        };

        dao.upsert_member(&member).await.unwrap();
        let members = dao.get_members("g_1").await.unwrap();
        assert_eq!(members.len(), 1);
        assert_eq!(members[0].nickname, "Alice");
    }
}

// ====================================================================
// Repository trait 实现
// ====================================================================

use crate::domain::repository::group::GroupRepository;

#[async_trait::async_trait]
impl GroupRepository for GroupDao {
    async fn upsert_group(&self, group: &LocalGroup) -> Result<()> { GroupDao::upsert_group(self, group).await }
    async fn get_all_groups(&self) -> Result<Vec<LocalGroup>> { self.get_all_groups().await }
    async fn get_group(&self, group_id: &str) -> Result<Option<LocalGroup>> { self.get_group(group_id).await }
    async fn delete_group(&self, group_id: &str) -> Result<()> { self.delete_group(group_id).await }
    async fn upsert_member(&self, member: &LocalGroupMember) -> Result<()> { self.upsert_member(member).await }
    async fn batch_upsert_members(&self, members: &[LocalGroupMember]) -> Result<()> { self.batch_upsert_members(members).await }
    async fn get_members(&self, group_id: &str) -> Result<Vec<LocalGroupMember>> { self.get_members(group_id).await }
    async fn delete_member(&self, group_id: &str, user_id: &str) -> Result<()> { self.delete_member(group_id, user_id).await }
    async fn delete_members_by_group(&self, group_id: &str) -> Result<()> { self.delete_members_by_group(group_id).await }
}
