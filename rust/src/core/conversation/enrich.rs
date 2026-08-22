//! 会话头像/名称补全（对齐 Go SDK `batchAddFaceURLAndName`）
//!
//! 服务端下发的会话不含 `show_name`/`face_url`（本地计算字段），
//! 由 SDK 从好友/用户/群组本地数据中补全：
//! - 单聊：好友备注 > 好友昵称 > 用户昵称（好友信息完整时不再查询用户表）
//! - 群聊：群组名称 + 群头像（`group_id` 缺失时从 `conversation_id` 前缀解析）
//!
//! 补全采用「数据源优先」：数据源可查到则覆盖，查不到则保留原值
//! （如消息携带的 `sender_nickname`），避免用空串覆盖已有名称。

use crate::core::context::Repositories;
use crate::domain::error::Result;
use crate::domain::model::local::LocalConversation;
use std::sync::Arc;
use tracing::debug;

/// 批量补全会话的 show_name / face_url（对齐 Go SDK `batchAddFaceURLAndName`）
///
/// `login_user_id` 用于查询好友表（好友以当前登录用户为 owner）。
pub async fn batch_add_face_url_and_name(repositories: &Arc<Repositories>, login_user_id: &str, conversations: &mut [LocalConversation]) -> Result<()> {
    for conv in conversations.iter_mut() {
        // 单聊/群聊判定对齐 Go SDK `batchAddFaceURLAndName`：以 conversation_id 前缀为主
        // （服务端可能不下发 conversation_type），conversation_type 仅作兜底
        let is_single = conv.conversation_type == 1 || conv.conversation_id.starts_with("si_");
        let is_group = !is_single
            && (conv.conversation_type == 2
                || conv.conversation_type == 3
                || conv.conversation_id.starts_with("g_")
                || conv.conversation_id.starts_with("sg_"));
        // 单聊：好友备注 > 好友昵称 > 用户昵称
        if is_single {
            // user_id 缺失时从会话 ID 解析对方（si_{a}_{b}）
            if conv.user_id.is_empty() {
                if let Some(other) = user_id_from_conversation_id(&conv.conversation_id, login_user_id) {
                    conv.user_id = other;
                }
            }
            if let Ok(Some(friend)) = repositories.friend_repo.get_by_id(login_user_id, &conv.user_id).await {
                if !friend.remark.is_empty() {
                    conv.show_name = friend.remark.clone();
                } else if !friend.nickname.is_empty() {
                    conv.show_name = friend.nickname.clone();
                }
                if !friend.face_url.is_empty() {
                    conv.face_url = friend.face_url.clone();
                }
                continue;
            }
            if let Ok(Some(user)) = repositories.user_repo.get_by_id(&conv.user_id).await {
                if !user.name.is_empty() {
                    conv.show_name = user.name.clone();
                }
                if !user.face_url.is_empty() {
                    conv.face_url = user.face_url.clone();
                }
            }
        } else if is_group {
            // 群聊：群名 + 群头像（group_id 缺失时从会话 ID 前缀解析 g_/sg_）
            if conv.group_id.is_empty() {
                conv.group_id = group_id_from_conversation_id(&conv.conversation_id);
            }
            if let Ok(Some(group)) = repositories.group_repo.get_group(&conv.group_id).await {
                if !group.name.is_empty() {
                    conv.show_name = group.name.clone();
                }
                if !group.face_url.is_empty() {
                    conv.face_url = group.face_url.clone();
                }
            }
        }
    }
    debug!("会话头像/名称补全完成，共 {} 个会话", conversations.len());
    Ok(())
}

/// 从单聊会话 ID（`si_{a}_{b}`）解析对方用户 ID
fn user_id_from_conversation_id(conversation_id: &str, login_user_id: &str) -> Option<String> {
    let parts = conversation_id.strip_prefix("si_")?.split('_').collect::<Vec<_>>();
    if parts.len() < 2 {
        return None;
    }
    Some(if parts[0] == login_user_id { parts[1].to_string() } else { parts[0].to_string() })
}

/// 从群聊会话 ID 解析群 ID（`g_{id}` / `sg_{id}`）
fn group_id_from_conversation_id(conversation_id: &str) -> String {
    if let Some(id) = conversation_id.strip_prefix("sg_") {
        id.to_string()
    } else if let Some(id) = conversation_id.strip_prefix("g_") {
        id.to_string()
    } else {
        String::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::model::local::{LocalConversation, LocalFriend, LocalGroup, LocalUser};
    use crate::infra::db::pool::create_pool_memory;
    use crate::infra::db::{ConversationDao, FriendDao, GroupDao, MessageDao, NotificationSeqDao, SendingMessageDao, SyncVersionDao, UserDao};

    fn make_test_repositories(pool: sqlx::SqlitePool) -> Arc<Repositories> {
        Arc::new(Repositories {
            message_repo: Arc::new(MessageDao::new(pool.clone())),
            conversation_repo: Arc::new(ConversationDao::new(pool.clone())),
            friend_repo: Arc::new(FriendDao::new(pool.clone())),
            user_repo: Arc::new(UserDao::new(pool.clone())),
            group_repo: Arc::new(GroupDao::new(pool.clone())),
            sync_version_repo: Arc::new(SyncVersionDao::new(pool.clone())),
            notification_seq_repo: Arc::new(NotificationSeqDao::new(pool.clone())),
            sending_message_repo: Arc::new(SendingMessageDao::new(pool)),
        })
    }

    fn single_chat_conv(user_id: &str) -> LocalConversation {
        LocalConversation {
            conversation_id: format!("si_me_{}", user_id),
            conversation_type: 1,
            user_id: user_id.to_string(),
            ..Default::default()
        }
    }

    fn group_chat_conv(group_id: &str, conversation_type: i32) -> LocalConversation {
        let prefix = if conversation_type == 3 { "sg_" } else { "g_" };
        LocalConversation {
            conversation_id: format!("{}{}", prefix, group_id),
            conversation_type,
            group_id: group_id.to_string(),
            ..Default::default()
        }
    }

    /// 单聊：好友有备注时用备注覆盖昵称（对齐 Go friendMap 优先）
    #[tokio::test]
    async fn test_single_chat_uses_friend_remark_first() {
        let pool = create_pool_memory().await.unwrap();
        let repos = make_test_repositories(pool);
        repos
            .friend_repo
            .upsert(&LocalFriend {
                owner_user_id: "me".to_string(),
                friend_user_id: "u1".to_string(),
                remark: "老板".to_string(),
                nickname: "王强".to_string(),
                face_url: "http://friend.png".to_string(),
                ..Default::default()
            })
            .await
            .unwrap();

        let mut convs = vec![single_chat_conv("u1")];
        batch_add_face_url_and_name(&repos, "me", &mut convs).await.unwrap();

        assert_eq!(convs[0].show_name, "老板", "好友备注优先");
        assert_eq!(convs[0].face_url, "http://friend.png");
    }

    /// 单聊：好友无备注时用好友昵称
    #[tokio::test]
    async fn test_single_chat_uses_friend_nickname_without_remark() {
        let pool = create_pool_memory().await.unwrap();
        let repos = make_test_repositories(pool);
        repos
            .friend_repo
            .upsert(&LocalFriend {
                owner_user_id: "me".to_string(),
                friend_user_id: "u1".to_string(),
                nickname: "王强".to_string(),
                ..Default::default()
            })
            .await
            .unwrap();

        let mut convs = vec![single_chat_conv("u1")];
        batch_add_face_url_and_name(&repos, "me", &mut convs).await.unwrap();

        assert_eq!(convs[0].show_name, "王强");
    }

    /// 单聊：非好友时用用户表昵称（对齐 Go GetUsersInfo 数据源）
    #[tokio::test]
    async fn test_single_chat_uses_user_nickname_for_non_friend() {
        let pool = create_pool_memory().await.unwrap();
        let repos = make_test_repositories(pool);
        repos
            .user_repo
            .upsert(&LocalUser {
                user_id: "u1".to_string(),
                name: "李雷".to_string(),
                face_url: "http://user.png".to_string(),
                ..Default::default()
            })
            .await
            .unwrap();

        let mut convs = vec![single_chat_conv("u1")];
        batch_add_face_url_and_name(&repos, "me", &mut convs).await.unwrap();

        assert_eq!(convs[0].show_name, "李雷");
        assert_eq!(convs[0].face_url, "http://user.png");
    }

    /// 群聊：用群名 + 群头像（普通群 g_ 与超级群 sg_ 均支持）
    #[tokio::test]
    async fn test_group_chat_uses_group_name() {
        let pool = create_pool_memory().await.unwrap();
        let repos = make_test_repositories(pool);
        repos
            .group_repo
            .upsert_group(&LocalGroup {
                group_id: "g1".to_string(),
                name: "产品讨论群".to_string(),
                face_url: "http://group.png".to_string(),
                ..Default::default()
            })
            .await
            .unwrap();

        let mut convs = vec![group_chat_conv("g1", 2), group_chat_conv("g1", 3)];
        batch_add_face_url_and_name(&repos, "me", &mut convs).await.unwrap();

        assert_eq!(convs[0].show_name, "产品讨论群");
        assert_eq!(convs[0].face_url, "http://group.png");
        assert_eq!(convs[1].show_name, "产品讨论群", "超级群 sg_ 前缀同样解析");
    }

    /// 群聊：group_id 缺失时从 conversation_id 前缀解析
    #[tokio::test]
    async fn test_group_chat_resolves_group_id_from_conversation_id() {
        let pool = create_pool_memory().await.unwrap();
        let repos = make_test_repositories(pool);
        repos
            .group_repo
            .upsert_group(&LocalGroup {
                group_id: "g2".to_string(),
                name: "需求评审群".to_string(),
                ..Default::default()
            })
            .await
            .unwrap();

        let mut conv = LocalConversation {
            conversation_id: "sg_g2".to_string(),
            conversation_type: 3,
            group_id: String::new(),
            ..Default::default()
        };
        batch_add_face_url_and_name(&repos, "me", std::slice::from_mut(&mut conv)).await.unwrap();

        assert_eq!(conv.group_id, "g2");
        assert_eq!(conv.show_name, "需求评审群");
    }

    /// 对齐 Go：conversation_type 缺失（服务端不下发）时，仍按 conversation_id 前缀判断单聊/群聊
    #[tokio::test]
    async fn test_group_chat_uses_id_prefix_when_type_missing() {
        let pool = create_pool_memory().await.unwrap();
        let repos = make_test_repositories(pool);
        repos
            .group_repo
            .upsert_group(&LocalGroup {
                group_id: "sg3".to_string(),
                name: "超级群讨论组".to_string(),
                ..Default::default()
            })
            .await
            .unwrap();

        // 服务端未下发 conversation_type（=0），仅凭 sg_ 前缀识别群聊
        let mut conv = LocalConversation {
            conversation_id: "sg_sg3".to_string(),
            conversation_type: 0,
            group_id: String::new(),
            ..Default::default()
        };
        batch_add_face_url_and_name(&repos, "me", std::slice::from_mut(&mut conv)).await.unwrap();

        assert_eq!(conv.show_name, "超级群讨论组", "type 缺失时按 sg_ 前缀识别群聊并补全群名");
    }

    /// 单聊：user_id 缺失时从会话 ID 解析对方
    #[tokio::test]
    async fn test_single_chat_resolves_user_id_from_conversation_id() {
        let pool = create_pool_memory().await.unwrap();
        let repos = make_test_repositories(pool);
        repos
            .user_repo
            .upsert(&LocalUser {
                user_id: "u2".to_string(),
                name: "韩梅梅".to_string(),
                ..Default::default()
            })
            .await
            .unwrap();

        let mut conv = LocalConversation {
            conversation_id: "si_me_u2".to_string(),
            conversation_type: 1,
            user_id: String::new(),
            ..Default::default()
        };
        batch_add_face_url_and_name(&repos, "me", std::slice::from_mut(&mut conv)).await.unwrap();

        assert_eq!(conv.user_id, "u2");
        assert_eq!(conv.show_name, "韩梅梅");
    }

    /// 数据源查不到时保留原值（不覆盖消息携带的名称）
    #[tokio::test]
    async fn test_keeps_original_values_when_source_missing() {
        let pool = create_pool_memory().await.unwrap();
        let repos = make_test_repositories(pool);

        let mut convs = vec![
            LocalConversation {
                conversation_id: "si_me_u9".to_string(),
                conversation_type: 1,
                user_id: "u9".to_string(),
                show_name: "消息里的昵称".to_string(),
                face_url: "http://msg.png".to_string(),
                ..Default::default()
            },
            group_chat_conv("g_missing", 2),
        ];
        batch_add_face_url_and_name(&repos, "me", &mut convs).await.unwrap();

        assert_eq!(convs[0].show_name, "消息里的昵称", "查不到时保留原值");
        assert_eq!(convs[0].face_url, "http://msg.png");
        assert!(convs[1].show_name.is_empty(), "群信息缺失时保持为空，由 UI 兜底");
    }
}
