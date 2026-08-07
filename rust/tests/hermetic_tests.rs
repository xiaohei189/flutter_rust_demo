//! 不依赖外部 OpenIM 服务的离线集成测试。

use rust_lib_flutter_rust_demo::client::context::Repositories;
use rust_lib_flutter_rust_demo::db::pool::create_pool_memory;
use rust_lib_flutter_rust_demo::db::*;
use rust_lib_flutter_rust_demo::event::hub::EventHub;
use rust_lib_flutter_rust_demo::friend::service::FriendService;
use rust_lib_flutter_rust_demo::http::client::HttpApiClient;
use rust_lib_flutter_rust_demo::http::friend_api::HttpFriendApi;
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
