//! 不依赖外部 OpenIM 服务的离线集成测试。

use rust_lib_flutter_rust_demo::client::context::Repositories;
use rust_lib_flutter_rust_demo::core::conversation::syncer::ConversationSyncer;
use rust_lib_flutter_rust_demo::infra::db::pool::create_pool_memory;
use rust_lib_flutter_rust_demo::infra::db::*;
use rust_lib_flutter_rust_demo::core::event::hub::EventHub;
use rust_lib_flutter_rust_demo::friend::service::FriendService;
use rust_lib_flutter_rust_demo::group::service::GroupService;
use rust_lib_flutter_rust_demo::infra::http::client::HttpApiClient;
use rust_lib_flutter_rust_demo::infra::http::friend_api::HttpFriendApi;
use rust_lib_flutter_rust_demo::infra::http::group::GroupServerApi;
use rust_lib_flutter_rust_demo::infra::http::group_api::HttpGroupApi;
use rust_lib_flutter_rust_demo::infra::http::online::{GetUserStatusReq, OnlineStatusServerApi};
use rust_lib_flutter_rust_demo::infra::http::online_api::HttpOnlineStatusApi;
use rust_lib_flutter_rust_demo::domain::model::UserId;
use std::sync::Arc;
use wiremock::matchers::{method, path};
use wiremock::{Mock, MockServer, ResponseTemplate};

/// 构造内存数据库对应的完整仓储集合，供离线测试共享。
fn make_repositories(pool: sqlx::SqlitePool) -> Arc<Repositories> {
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

/// 验证 wiremock 好友全量同步响应能被正确解析并写入本地。
#[tokio::test]
async fn friend_full_sync_works_without_live_server() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/friend/get_friend_list"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::from_str::<serde_json::Value>(include_str!("fixtures/friend_list.json")).unwrap()))
        .mount(&server)
        .await;

    let pool = create_pool_memory().await.unwrap();
    let repos = make_repositories(pool.clone());
    let http = Arc::new(HttpApiClient::new(server.uri(), "test_token".to_string(), "test_op".to_string()));
    let api: Arc<dyn rust_lib_flutter_rust_demo::infra::http::friend::FriendServerApi> = Arc::new(HttpFriendApi::new(http));
    let user_id = UserId::new("me");
    let hub = EventHub::new();
    let friend_service = FriendService::new(api, repos.clone(), user_id, hub.clone());

    friend_service.sync_friends().await.expect("全量同步好友失败");

    let friends = friend_service.get_friend_list().await;
    assert_eq!(friends.len(), 1);
    assert_eq!(friends[0].user_id, "user_2");
    assert_eq!(friends[0].nickname, "Alice");

    let stored = repos.friend_repo.get_all("me").await.unwrap();
    assert_eq!(stored.len(), 1);
    assert_eq!(stored[0].friend_user_id, "user_2");
}

/// 复现并验证：重新登录（新客户端实例、内存缓存为空）时，若增量同步返回“无变更”，
/// 必须先调用 load_friends_from_db 从本地数据库恢复内存缓存，否则 get_friend_list 为空，
/// 导致好友列表显示“暂无好友”。
#[tokio::test]
async fn friend_list_restores_from_db_when_incremental_has_no_changes() {
    // 首次登录的服务器：增量接口返回 full=true，触发全量同步并持久化版本号
    let server1 = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/friend/get_incremental_friends"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::from_str::<serde_json::Value>(include_str!("fixtures/friend_incremental_full.json")).unwrap()))
        .mount(&server1)
        .await;
    Mock::given(method("POST"))
        .and(path("/friend/get_friend_list"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::from_str::<serde_json::Value>(include_str!("fixtures/friend_list.json")).unwrap()))
        .mount(&server1)
        .await;

    let pool = create_pool_memory().await.unwrap();
    let repos = make_repositories(pool);

    let make_api = |uri: &str| {
        let http = Arc::new(HttpApiClient::new(uri.to_string(), "test_token".to_string(), "test_op".to_string()));
        Arc::new(HttpFriendApi::new(http)) as Arc<dyn rust_lib_flutter_rust_demo::infra::http::friend::FriendServerApi>
    };

    // 首次登录：内存 + DB + 版本号均有数据
    let first = FriendService::new(make_api(&server1.uri()), repos.clone(), UserId::new("me"), EventHub::new());
    first.sync_friends_incremental().await.unwrap();
    assert_eq!(first.get_friend_list().await.len(), 1);
    let version = repos.sync_version_repo.get_version_sync("local_friends", "me").await.unwrap();
    assert_eq!(version, Some(("v1".to_string(), 11)));

    // 第二次登录：新客户端实例，内存为空；独立服务器仅返回“无变更”增量响应，
    // 确保不会误触发全量同步，从而真实复现内存缓存为空的问题。
    let server2 = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/friend/get_incremental_friends"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::from_str::<serde_json::Value>(include_str!("fixtures/friend_incremental_no_change.json")).unwrap()))
        .mount(&server2)
        .await;

    let second = FriendService::new(make_api(&server2.uri()), repos.clone(), UserId::new("me"), EventHub::new());
    // 修复点：登录时先从本地数据库恢复内存缓存
    second.load_friends_from_db().await;
    second.sync_friends_incremental().await.unwrap();

    let friends = second.get_friend_list().await;
    assert_eq!(friends.len(), 1, "重新登录后好友列表不应为空");
    assert_eq!(friends[0].user_id, "user_2");
    assert_eq!(friends[0].nickname, "Alice");
}

/// 验证 wiremock 会话全量同步响应能被正确解析并写入本地。
#[tokio::test]
async fn conversation_full_sync_works_without_live_server() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/conversation/get_all_conversations"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::from_str::<serde_json::Value>(include_str!("fixtures/conversation_list.json")).unwrap()))
        .mount(&server)
        .await;

    let pool = create_pool_memory().await.unwrap();
    let repos = make_repositories(pool);
    let http = Arc::new(HttpApiClient::new(server.uri(), "test_token".to_string(), "test_op".to_string()));
    let hub = EventHub::new();
    let syncer = ConversationSyncer::new(http, repos.clone(), UserId::new("me"), hub);

    let convs = syncer.sync_full().await.unwrap();
    assert_eq!(convs.len(), 1);
    assert_eq!(convs[0].conversation_id, "si_a_b");

    let stored = repos.conversation_repo.get_all().await.unwrap();
    assert_eq!(stored.len(), 1);
    assert_eq!(stored[0].conversation_id, "si_a_b");
}

/// 验证 wiremock 群组全量同步响应能被正确解析并写入本地。
#[tokio::test]
async fn group_full_sync_works_without_live_server() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/group/get_joined_group_list"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::from_str::<serde_json::Value>(include_str!("fixtures/group_list.json")).unwrap()))
        .mount(&server)
        .await;

    let pool = create_pool_memory().await.unwrap();
    let repos = make_repositories(pool);
    let http = Arc::new(HttpApiClient::new(server.uri(), "test_token".to_string(), "test_op".to_string()));
    let api: Arc<dyn GroupServerApi> = Arc::new(HttpGroupApi::new(http));
    let group_service = GroupService::new(api, repos.clone(), UserId::new("me"), EventHub::new());

    group_service.sync_groups().await.unwrap();

    let stored = repos.group_repo.get_all_groups().await.unwrap();
    assert_eq!(stored.len(), 1);
    assert_eq!(stored[0].group_id, "g1");
}

/// 验证会话增量同步会插入新会话并持久化版本号。
#[tokio::test]
async fn conversation_incremental_sync_stores_insert_and_version() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/conversation/get_incremental_conversations"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::from_str::<serde_json::Value>(include_str!("fixtures/conversation_incremental.json")).unwrap()))
        .mount(&server)
        .await;

    let pool = create_pool_memory().await.unwrap();
    let repos = make_repositories(pool);
    let http = Arc::new(HttpApiClient::new(server.uri(), "test_token".to_string(), "test_op".to_string()));
    let syncer = ConversationSyncer::new(http, repos.clone(), UserId::new("me"), EventHub::new());

    let convs = syncer.sync_incremental().await.unwrap();
    assert_eq!(convs.len(), 1);
    assert_eq!(convs[0].conversation_id, "si_inc");

    let stored = repos.conversation_repo.get_all().await.unwrap();
    assert_eq!(stored.len(), 1);
    assert_eq!(stored[0].conversation_id, "si_inc");

    let version = repos.sync_version_repo.get_version_sync("local_conversations", "me").await.unwrap();
    assert_eq!(version, Some(("v1".to_string(), 1)));
}

/// 验证群组增量同步会插入新群组并持久化版本号。
#[tokio::test]
async fn group_incremental_sync_stores_insert_and_version() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/group/get_incremental_join_groups"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::from_str::<serde_json::Value>(include_str!("fixtures/group_incremental.json")).unwrap()))
        .mount(&server)
        .await;

    let pool = create_pool_memory().await.unwrap();
    let repos = make_repositories(pool);
    let http = Arc::new(HttpApiClient::new(server.uri(), "test_token".to_string(), "test_op".to_string()));
    let api: Arc<dyn GroupServerApi> = Arc::new(HttpGroupApi::new(http));
    let group_service = GroupService::new(api, repos.clone(), UserId::new("me"), EventHub::new());

    group_service.sync_groups_incremental().await.unwrap();

    let stored = repos.group_repo.get_all_groups().await.unwrap();
    assert_eq!(stored.len(), 1);
    assert_eq!(stored[0].group_id, "g_inc");

    let version = repos.sync_version_repo.get_version_sync("local_groups", "me").await.unwrap();
    assert_eq!(version, Some(("v1".to_string(), 1)));
}

/// 验证 wiremock 用户在线状态响应能被正确解析。
#[tokio::test]
async fn online_status_http_get_user_status_works_without_live_server() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/user/get_users_status"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::from_str::<serde_json::Value>(include_str!("fixtures/user_status.json")).unwrap()))
        .mount(&server)
        .await;

    let http = Arc::new(HttpApiClient::new(server.uri(), "test_token".to_string(), "test_op".to_string()));
    let api = HttpOnlineStatusApi::new(http);
    let resp = api.get_user_status(&GetUserStatusReq { user_ids: vec!["user_1".to_string()] }).await.unwrap();

    let statuses = resp.users_status.unwrap_or_default();
    assert_eq!(statuses.len(), 1);
    assert_eq!(statuses[0].user_id, "user_1");
    assert_eq!(statuses[0].status, 1);
    assert_eq!(statuses[0].platform_ids, vec![1, 2]);
}

/// 验证 wiremock 黑名单响应能被解析并同步到本地内存。
#[tokio::test]
async fn friend_black_list_sync_works_without_live_server() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/friend/get_black_list"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::from_str::<serde_json::Value>(include_str!("fixtures/black_list.json")).unwrap()))
        .mount(&server)
        .await;

    let pool = create_pool_memory().await.unwrap();
    let repos = make_repositories(pool);
    let http = Arc::new(HttpApiClient::new(server.uri(), "test_token".to_string(), "test_op".to_string()));
    let api: Arc<dyn rust_lib_flutter_rust_demo::infra::http::friend::FriendServerApi> = Arc::new(HttpFriendApi::new(http));
    let friend_service = FriendService::new(api, repos, UserId::new("me"), EventHub::new());

    friend_service.sync_blacks().await.unwrap();

    assert_eq!(friend_service.get_blacklist().await, vec!["black_1"]);
}

/// 验证 wiremock 群成员响应能被解析并返回领域模型。
#[tokio::test]
async fn group_member_list_works_without_live_server() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/group/get_group_member_list"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::from_str::<serde_json::Value>(include_str!("fixtures/group_members.json")).unwrap()))
        .mount(&server)
        .await;

    let pool = create_pool_memory().await.unwrap();
    let repos = make_repositories(pool);
    let http = Arc::new(HttpApiClient::new(server.uri(), "test_token".to_string(), "test_op".to_string()));
    let api: Arc<dyn GroupServerApi> = Arc::new(HttpGroupApi::new(http));
    let group_service = GroupService::new(api, repos, UserId::new("me"), EventHub::new());

    let members = group_service.get_group_member_list("g1".to_string(), 0, 0, 100).await.unwrap();

    assert_eq!(members.len(), 1);
    assert_eq!(members[0].user_id, "user_member");
    assert_eq!(members[0].group_id, "g1");
}
