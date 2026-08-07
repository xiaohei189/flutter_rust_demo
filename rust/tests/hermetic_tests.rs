//! 不依赖外部 OpenIM 服务的离线集成测试。

use rust_lib_flutter_rust_demo::client::context::Repositories;
use rust_lib_flutter_rust_demo::conversation::syncer::ConversationSyncer;
use rust_lib_flutter_rust_demo::db::pool::create_pool_memory;
use rust_lib_flutter_rust_demo::db::*;
use rust_lib_flutter_rust_demo::event::hub::EventHub;
use rust_lib_flutter_rust_demo::friend::service::FriendService;
use rust_lib_flutter_rust_demo::group::service::GroupService;
use rust_lib_flutter_rust_demo::http::client::HttpApiClient;
use rust_lib_flutter_rust_demo::http::conversation::ConversationServerApi;
use rust_lib_flutter_rust_demo::http::conversation_api::HttpConversationApi;
use rust_lib_flutter_rust_demo::http::friend_api::HttpFriendApi;
use rust_lib_flutter_rust_demo::http::group::GroupServerApi;
use rust_lib_flutter_rust_demo::http::group_api::HttpGroupApi;
use rust_lib_flutter_rust_demo::model::UserId;
use std::sync::Arc;
use wiremock::matchers::{method, path};
use wiremock::{Mock, MockServer, ResponseTemplate};

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

#[tokio::test]
async fn friend_full_sync_works_without_live_server() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/friend/get_friend_list"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "errCode": 0,
            "errMsg": "",
            "data": {
                "friendsInfo": [{
                    "ownerUserID": "me",
                    "remark": "friend",
                    "createTime": 1,
                    "friendUser": {
                        "userID": "user_2",
                        "nickname": "Alice",
                        "faceURL": "",
                        "ex": "",
                        "createTime": 1
                    },
                    "addSource": 1,
                    "operatorUserID": "me",
                    "ex": "",
                    "isPinned": false
                }],
                "total": 1
            }
        })))
        .mount(&server)
        .await;

    let pool = create_pool_memory().await.unwrap();
    let repos = make_repositories(pool.clone());
    let http = Arc::new(HttpApiClient::new(server.uri(), "test_token".to_string(), "test_op".to_string()));
    let api: Arc<dyn rust_lib_flutter_rust_demo::http::friend::FriendServerApi> =
        Arc::new(HttpFriendApi::new(http));
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

#[tokio::test]
async fn conversation_full_sync_works_without_live_server() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/conversation/get_all_conversations"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "errCode": 0,
            "errMsg": "",
            "data": {
                "conversations": [{
                    "ownerUserID": "me",
                    "conversationID": "si_a_b",
                    "conversationType": 1,
                    "recvMsgOpt": 0,
                    "userID": "user_b",
                    "groupID": "",
                    "isPinned": false,
                    "isPrivateChat": false,
                    "groupAtType": 0,
                    "ex": "",
                    "attachedInfo": "",
                    "burnDuration": 0,
                    "minSeq": 0,
                    "maxSeq": 0,
                    "msgDestructTime": 0,
                    "isMsgDestruct": false
                }]
            }
        })))
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

#[tokio::test]
async fn group_full_sync_works_without_live_server() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/group/get_joined_group_list"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "errCode": 0,
            "errMsg": "",
            "data": {
                "groups": [{
                    "groupID": "g1",
                    "groupName": "Group 1",
                    "notification": "",
                    "introduction": "",
                    "faceURL": "",
                    "ownerUserID": "me",
                    "createTime": 1,
                    "memberCount": 1,
                    "status": 0,
                    "creatorUserID": "me",
                    "groupType": 2,
                    "ex": ""
                }],
                "total": 1
            }
        })))
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

#[tokio::test]
async fn conversation_incremental_sync_stores_insert_and_version() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/conversation/get_incremental_conversations"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "errCode": 0,
            "errMsg": "",
            "data": {
                "version": 1,
                "versionID": "v1",
                "full": false,
                "delete": [],
                "insert": [{
                    "ownerUserID": "me",
                    "conversationID": "si_inc",
                    "conversationType": 1,
                    "recvMsgOpt": 0,
                    "userID": "user_b",
                    "groupID": "",
                    "isPinned": false,
                    "isPrivateChat": false,
                    "groupAtType": 0,
                    "ex": "",
                    "attachedInfo": "",
                    "burnDuration": 0,
                    "minSeq": 0,
                    "maxSeq": 0,
                    "msgDestructTime": 0,
                    "isMsgDestruct": false
                }],
                "update": []
            }
        })))
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

#[tokio::test]
async fn group_incremental_sync_stores_insert_and_version() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/group/get_incremental_join_groups"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "errCode": 0,
            "errMsg": "",
            "data": {
                "version": 1,
                "versionID": "v1",
                "full": false,
                "delete": [],
                "insert": [{
                    "groupID": "g_inc",
                    "groupName": "Incremental Group",
                    "notification": "",
                    "introduction": "",
                    "faceURL": "",
                    "ownerUserID": "me",
                    "createTime": 1,
                    "memberCount": 1,
                    "status": 0,
                    "creatorUserID": "me",
                    "groupType": 2,
                    "ex": ""
                }],
                "update": [],
                "sortVersion": 0
            }
        })))
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
