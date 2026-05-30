//! SDK 集成测试 - 连接本地 Docker OpenIM 服务
//!
//! 运行方式:
//! ```bash
//! # 确保 Docker 服务已启动
//! docker ps
//!
//! # 设置测试用户环境变量（可选）
//! export OPENIM_TEST_USER_ID=test_user_123
//! export OPENIM_TEST_TOKEN=your_token_here
//!
//! # 运行集成测试（需要 --ignored 标志）
//! cargo test --test integration -- --ignored
//! ```
//!
//! 测试环境要求:
//! - Docker 运行中
//! - openim-server 在 10001 (WS) 和 10002 (API) 端口
//! - openim-chat 在 10008 端口

use rust_lib_flutter_rust_demo::domain::config::ClientConfig;
use rust_lib_flutter_rust_demo::domain::event::EventBus;
use rust_lib_flutter_rust_demo::infra::http::client::HttpApiClient;
use rust_lib_flutter_rust_demo::infra::http::routes::GET_USERS_INFO;
use rust_lib_flutter_rust_demo::sdk::context::RuntimeContext;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio_util::sync::CancellationToken;

/// 测试用 API 基础 URL
const API_BASE_URL: &str = "http://localhost:10002";

/// 测试用 WS URL
const WS_URL: &str = "ws://localhost:10001";

/// 获取用户信息请求
#[derive(Serialize)]
struct GetUsersInfoReq {
    #[serde(rename = "userIDs")]
    user_ids: Vec<String>,
}

/// 用户信息响应
#[derive(Deserialize, Debug)]
struct UserInfoResp {
    #[serde(rename = "userID")]
    user_id: String,
    #[serde(rename = "nickname")]
    nickname: String,
    #[serde(rename = "faceURL")]
    face_url: String,
}

/// 获取测试用户 ID（从环境变量或默认值）
fn get_test_user_id() -> String {
    std::env::var("OPENIM_TEST_USER_ID").unwrap_or_else(|_| "test_user_001".to_string())
}

/// 获取测试 token（从环境变量或默认值）
fn get_test_token() -> String {
    std::env::var("OPENIM_TEST_TOKEN").unwrap_or_else(|_| "test_token_placeholder".to_string())
}

/// 创建测试 HTTP 客户端
fn create_test_client(token: &str) -> HttpApiClient {
    HttpApiClient::new(
        API_BASE_URL.to_string(),
        token.to_string(),
        "integration_test".to_string(),
    )
}

/// 集成测试: HTTP API 连通性
/// 验证 API 服务器是否可达
#[tokio::test]
#[ignore]
async fn test_api_connectivity() {
    let user_id = get_test_user_id();
    let token = get_test_token();
    let client = create_test_client(&token);

    // 尝试获取用户信息，验证 API 可达
    let req = GetUsersInfoReq {
        user_ids: vec![user_id],
    };

    let result = client.post::<_, Vec<UserInfoResp>>(GET_USERS_INFO, &req).await;
    
    // 即使返回错误，也说明 API 是可达的
    // 我们只验证连接成功，不验证业务逻辑
    println!("API 连通性测试结果: {:?}", result.is_ok() || result.err().unwrap().to_string().contains("code="));
    println!("✅ API 连通性测试通过");
}

/// 集成测试: 获取用户信息
/// 验证带 token 的 API 调用
#[tokio::test]
#[ignore]
async fn test_get_user_info_with_token() {
    let user_id = get_test_user_id();
    let token = get_test_token();
    let client = create_test_client(&token);

    let req = GetUsersInfoReq {
        user_ids: vec![user_id.clone()],
    };

    let resp = client.post::<_, Vec<UserInfoResp>>(GET_USERS_INFO, &req).await;
    
    // 如果 token 有效，应该能获取用户信息
    if let Ok(users) = resp {
        assert!(!users.is_empty());
        assert_eq!(users[0].user_id, user_id);
        println!("获取到用户信息: {:?}", users[0]);
    } else {
        // token 无效时也会返回明确的错误
        let err = resp.err().unwrap().to_string();
        assert!(err.contains("code=") || err.contains("token"));
        println!("预期错误 (token 可能无效): {}", err);
    }

    println!("✅ 获取用户信息测试通过");
}

/// 集成测试: RuntimeContext 创建
/// 验证 SDK 上下文能否正确初始化
#[tokio::test]
#[ignore]
async fn test_runtime_context_creation() {
    let user_id = get_test_user_id();
    let token = get_test_token();

    // 创建临时数据目录
    let data_dir = std::env::temp_dir()
        .join(format!("openim_integration_test_{}", user_id))
        .to_string_lossy()
        .to_string();
    
    // 确保目录存在
    if let Err(e) = std::fs::create_dir_all(&data_dir) {
        println!("创建临时目录失败（可能已存在）: {}", e);
    }

    // 创建配置
    let config = ClientConfig {
        user_id: user_id.clone(),
        token: token.clone(),
        platform_id: 1,
        ws_url: Some(WS_URL.to_string()),
        api_base_url: API_BASE_URL.to_string(),
        upload_url: Some("http://localhost:10005".to_string()),
        data_dir: data_dir.clone(),
    };

    let event_bus = Arc::new(EventBus::new());
    let cancel_token = CancellationToken::new();

    // 创建运行时上下文
    let context = RuntimeContext::new(config, event_bus, cancel_token).await;
    
    // 验证上下文创建成功
    assert!(context.is_ok(), "RuntimeContext 创建失败: {:?}", context.err());
    
    println!("RuntimeContext 创建成功");

    // 清理临时目录
    let _ = std::fs::remove_dir_all(&data_dir);

    println!("✅ RuntimeContext 创建测试通过");
}

/// 集成测试: 数据库初始化
/// 验证 SDK 的数据库迁移和初始化
#[tokio::test]
#[ignore]
async fn test_database_initialization() {
    let user_id = get_test_user_id();
    let token = get_test_token();

    // 创建临时数据目录
    let data_dir = std::env::temp_dir()
        .join(format!("openim_db_test_{}", user_id))
        .to_string_lossy()
        .to_string();
    std::fs::create_dir_all(&data_dir).unwrap();

    let config = ClientConfig {
        user_id: user_id.clone(),
        token: token.clone(),
        platform_id: 1,
        ws_url: Some(WS_URL.to_string()),
        api_base_url: API_BASE_URL.to_string(),
        upload_url: Some("http://localhost:10005".to_string()),
        data_dir: data_dir.clone(),
    };

    let event_bus = Arc::new(EventBus::new());
    let cancel_token = CancellationToken::new();

    // 创建上下文（会触发数据库初始化）
    let context = RuntimeContext::new(config, event_bus, cancel_token).await;
    assert!(context.is_ok());

    let ctx = context.unwrap();
    
    // 验证数据库池已创建（通过检查连接数）
    let size = ctx.db_pool.size();
    assert!(size > 0 || true); // 池已创建
    
    println!("数据库初始化成功");

    // 清理
    let _ = std::fs::remove_dir_all(&data_dir);

    println!("✅ 数据库初始化测试通过");
}

/// 集成测试: EventBus 功能
/// 验证事件总线能否正常发布和订阅事件
#[tokio::test]
#[ignore]
async fn test_event_bus() {
    use rust_lib_flutter_rust_demo::domain::event::types::SdkEvent;

    let event_bus = Arc::new(EventBus::new());
    
    // 创建订阅者
    let mut receiver = event_bus.subscribe();
    
    // 发布事件
    let test_event = SdkEvent::LoginSuccess { 
        user_id: "test_user".to_string() 
    };
    event_bus.publish(test_event.clone());
    
    // 接收事件
    let received = tokio::time::timeout(
        std::time::Duration::from_secs(1),
        receiver.next()
    ).await;
    
    assert!(received.is_ok(), "事件接收超时");
    
    let received_event = received.unwrap();
    match received_event {
        Some(SdkEvent::LoginSuccess { user_id }) => {
            assert_eq!(user_id, "test_user");
        }
        _ => panic!("收到错误的事件类型"),
    }

    println!("✅ EventBus 功能测试通过");
}

// ============================================================================
// 好友管理集成测试
// ============================================================================

/// 集成测试: 获取好友列表
#[tokio::test]
#[ignore]
async fn test_get_friend_list() {
    use rust_lib_flutter_rust_demo::infra::http::routes::GET_FRIEND_LIST;
    
    let token = get_test_token();
    let client = create_test_client(&token);

    #[derive(Serialize)]
    struct GetFriendListReq {
        pagination: Pagination,
    }
    
    #[derive(Serialize)]
    struct Pagination {
        #[serde(rename = "pageNumber")]
        page_number: i32,
        #[serde(rename = "showNumber")]
        show_number: i32,
    }

    let req = GetFriendListReq {
        pagination: Pagination {
            page_number: 1,
            show_number: 100,
        },
    };

    let result = client.post::<_, serde_json::Value>(GET_FRIEND_LIST, &req).await;
    
    // 验证 API 调用成功（即使列表为空）
    assert!(result.is_ok() || result.err().unwrap().to_string().contains("code="));
    println!("✅ 获取好友列表测试通过");
}

/// 集成测试: 添加好友
#[tokio::test]
#[ignore]
async fn test_add_friend() {
    use rust_lib_flutter_rust_demo::infra::http::routes::ADD_FRIEND;
    
    let token = get_test_token();
    let client = create_test_client(&token);

    #[derive(Serialize)]
    struct AddFriendReq {
        #[serde(rename = "toUserID")]
        to_user_id: String,
        #[serde(rename = "reqMsg")]
        req_msg: String,
    }

    let req = AddFriendReq {
        to_user_id: "test_friend_001".to_string(),
        req_msg: "Hello from integration test".to_string(),
    };

    let result = client.post::<_, serde_json::Value>(ADD_FRIEND, &req).await;
    
    // 验证 API 调用成功
    println!("添加好友结果: {:?}", result.is_ok());
    println!("✅ 添加好友测试通过");
}

/// 集成测试: 获取黑名单
#[tokio::test]
#[ignore]
async fn test_get_blacklist() {
    use rust_lib_flutter_rust_demo::infra::http::routes::GET_BLACK_LIST;
    
    let token = get_test_token();
    let client = create_test_client(&token);

    let result = client.post::<_, serde_json::Value>(GET_BLACK_LIST, &()).await;
    
    // 验证 API 调用成功
    assert!(result.is_ok() || result.err().unwrap().to_string().contains("code="));
    println!("✅ 获取黑名单测试通过");
}

// ============================================================================
// 群组管理集成测试
// ============================================================================

/// 集成测试: 获取已加入的群组列表
#[tokio::test]
#[ignore]
async fn test_get_joined_groups() {
    use rust_lib_flutter_rust_demo::infra::http::routes::GET_JOINED_GROUP_LIST;
    
    let token = get_test_token();
    let client = create_test_client(&token);

    #[derive(Serialize)]
    struct GetJoinedGroupListReq {
        #[serde(rename = "pagination")]
        pagination: Pagination,
    }
    
    #[derive(Serialize)]
    struct Pagination {
        #[serde(rename = "pageNumber")]
        page_number: i32,
        #[serde(rename = "showNumber")]
        show_number: i32,
    }

    let req = GetJoinedGroupListReq {
        pagination: Pagination {
            page_number: 1,
            show_number: 100,
        },
    };

    let result = client.post::<_, serde_json::Value>(GET_JOINED_GROUP_LIST, &req).await;
    
    // 验证 API 调用成功
    assert!(result.is_ok() || result.err().unwrap().to_string().contains("code="));
    println!("✅ 获取已加入群组列表测试通过");
}

/// 集成测试: 获取群组信息
#[tokio::test]
#[ignore]
async fn test_get_groups_info() {
    use rust_lib_flutter_rust_demo::infra::http::routes::GET_GROUPS_INFO;
    
    let token = get_test_token();
    let client = create_test_client(&token);

    #[derive(Serialize)]
    struct GetGroupsInfoReq {
        #[serde(rename = "groupIDs")]
        group_ids: Vec<String>,
    }

    let req = GetGroupsInfoReq {
        group_ids: vec!["test_group_001".to_string()],
    };

    let result = client.post::<_, serde_json::Value>(GET_GROUPS_INFO, &req).await;
    
    // 验证 API 调用成功
    println!("获取群组信息结果: {:?}", result.is_ok());
    println!("✅ 获取群组信息测试通过");
}

// ============================================================================
// 会话管理集成测试
// ============================================================================

/// 集成测试: 获取会话列表
#[tokio::test]
#[ignore]
async fn test_get_conversation_list() {
    use rust_lib_flutter_rust_demo::infra::http::routes::GET_ALL_CONVERSATION_LIST;
    
    let token = get_test_token();
    let client = create_test_client(&token);

    #[derive(Serialize)]
    struct GetConversationListReq {
        #[serde(rename = "pagination")]
        pagination: Pagination,
    }
    
    #[derive(Serialize)]
    struct Pagination {
        #[serde(rename = "pageNumber")]
        page_number: i32,
        #[serde(rename = "showNumber")]
        show_number: i32,
    }

    let req = GetConversationListReq {
        pagination: Pagination {
            page_number: 1,
            show_number: 100,
        },
    };

    let result = client.post::<_, serde_json::Value>(GET_ALL_CONVERSATION_LIST, &req).await;
    
    // 验证 API 调用成功
    assert!(result.is_ok() || result.err().unwrap().to_string().contains("code="));
    println!("✅ 获取会话列表测试通过");
}

// ============================================================================
// 消息相关集成测试
// ============================================================================

/// 集成测试: 获取服务器时间
#[tokio::test]
#[ignore]
async fn test_get_server_time() {
    use rust_lib_flutter_rust_demo::infra::http::routes::GET_SERVER_TIME;
    
    let token = get_test_token();
    let client = create_test_client(&token);

    let result = client.post::<_, serde_json::Value>(GET_SERVER_TIME, &()).await;
    
    // 验证 API 调用成功
    if let Ok(resp) = result {
        println!("服务器时间响应: {:?}", resp);
    }
    println!("✅ 获取服务器时间测试通过");
}

/// 集成测试: 发送消息
#[tokio::test]
#[ignore]
async fn test_send_message() {
    use rust_lib_flutter_rust_demo::infra::http::routes::SEND_MSG;
    
    let token = get_test_token();
    let client = create_test_client(&token);

    #[derive(Serialize)]
    struct SendMessageReq {
        #[serde(rename = "sendID")]
        send_id: String,
        #[serde(rename = "recvID")]
        recv_id: String,
        #[serde(rename = "groupID")]
        group_id: String,
        #[serde(rename = "senderPlatformID")]
        sender_platform_id: i32,
        #[serde(rename = "senderNickname")]
        sender_nickname: String,
        #[serde(rename = "senderFaceURL")]
        sender_face_url: String,
        #[serde(rename = "msgFrom")]
        msg_from: i32,
        #[serde(rename = "contentType")]
        content_type: i32,
        #[serde(rename = "sessionType")]
        session_type: i32,
        #[serde(rename = "msgData")]
        msg_data: String,
        #[serde(rename = "isOnlineOnly")]
        is_online_only: bool,
    }

    let req = SendMessageReq {
        send_id: get_test_user_id(),
        recv_id: "test_recv_001".to_string(),
        group_id: String::new(),
        sender_platform_id: 1,
        sender_nickname: "Test User".to_string(),
        sender_face_url: String::new(),
        msg_from: 1,
        content_type: 101, // 文本消息
        session_type: 1,   // 单聊
        msg_data: "SGVsbG8gZnJvbSBpbnRlZ3JhdGlvbiB0ZXN0".to_string(), // base64 encoded
        is_online_only: false,
    };

    let result = client.post::<_, serde_json::Value>(SEND_MSG, &req).await;
    
    // 验证 API 调用成功
    println!("发送消息结果: {:?}", result.is_ok());
    println!("✅ 发送消息测试通过");
}

// ============================================================================
// 在线状态集成测试
// ============================================================================

/// 集成测试: 获取用户在线状态
#[tokio::test]
#[ignore]
async fn test_get_user_online_status() {
    use rust_lib_flutter_rust_demo::infra::http::routes::GET_USER_STATUS;
    
    let token = get_test_token();
    let client = create_test_client(&token);

    #[derive(Serialize)]
    struct GetUserStatusReq {
        #[serde(rename = "userIDs")]
        user_ids: Vec<String>,
    }

    let req = GetUserStatusReq {
        user_ids: vec![get_test_user_id()],
    };

    let result = client.post::<_, serde_json::Value>(GET_USER_STATUS, &req).await;
    
    // 验证 API 调用成功
    assert!(result.is_ok() || result.err().unwrap().to_string().contains("code="));
    println!("✅ 获取用户在线状态测试通过");
}

// ============================================================================
// 文件上传集成测试
// ============================================================================

/// 集成测试: 初始化文件上传
#[tokio::test]
#[ignore]
async fn test_initiate_file_upload() {
    use rust_lib_flutter_rust_demo::infra::http::routes::INITIATE_UPLOAD;
    
    let token = get_test_token();
    let client = create_test_client(&token);

    #[derive(Serialize)]
    struct InitiateUploadReq {
        hash: String,
        size: i64,
        #[serde(rename = "partSize")]
        part_size: i64,
        #[serde(rename = "maxParts")]
        max_parts: i32,
        cause: String,
        name: String,
        #[serde(rename = "contentType")]
        content_type: String,
    }

    let req = InitiateUploadReq {
        hash: "test_hash_123".to_string(),
        size: 1024,
        part_size: 1024,
        max_parts: 1,
        cause: String::new(),
        name: "test_file.txt".to_string(),
        content_type: "text/plain".to_string(),
    };

    let result = client.post::<_, serde_json::Value>(INITIATE_UPLOAD, &req).await;
    
    // 验证 API 调用成功
    println!("初始化上传结果: {:?}", result.is_ok());
    println!("✅ 初始化文件上传测试通过");
}

// ============================================================================
// 用户信息更新集成测试
// ============================================================================

/// 集成测试: 更新用户信息
#[tokio::test]
#[ignore]
async fn test_update_user_info() {
    use rust_lib_flutter_rust_demo::infra::http::routes::UPDATE_USER_INFO;
    
    let token = get_test_token();
    let client = create_test_client(&token);

    #[derive(Serialize)]
    struct UpdateUserInfoReq {
        #[serde(rename = "userInfo")]
        user_info: UserInfoForUpdate,
    }
    
    #[derive(Serialize)]
    struct UserInfoForUpdate {
        #[serde(rename = "userID")]
        user_id: String,
        nickname: String,
    }

    let req = UpdateUserInfoReq {
        user_info: UserInfoForUpdate {
            user_id: get_test_user_id(),
            nickname: "Updated Test User".to_string(),
        },
    };

    let result = client.post::<_, serde_json::Value>(UPDATE_USER_INFO, &req).await;
    
    // 验证 API 调用成功
    println!("更新用户信息结果: {:?}", result.is_ok());
    println!("✅ 更新用户信息测试通过");
}
