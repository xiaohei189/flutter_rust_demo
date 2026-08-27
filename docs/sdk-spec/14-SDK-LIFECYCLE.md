# SDK 生命周期详细设计

> 本文档详细描述 OpenIM Rust SDK 的完整生命周期管理，包括初始化、登录、登出、Token 过期处理、
> 前后台切换等核心流程。所有设计严格对齐 Go SDK（openim-sdk-core）的实现逻辑。

---

## 1. 状态机定义

SDK 整体遵循以下状态转换：

```
                    ┌──────────┐
          InitSDK   │          │
         ─────────►│ NotExist │
                    │          │
                    └────┬─────┘
                         │
                    Login│
                         ▼
                    ┌──────────┐
                    │ Logging  │ ◄──── 正在初始化数据库、加载数据
                    └────┬─────┘
                         │
                  run()完成│
                         ▼
                    ┌──────────┐   Token过期/被踢   ┌──────────┐
                    │  Logged  │ ─────────────────► │ Logout   │
                    └────┬─────┘                    └────┬─────┘
                         │                               │
                    Logout│                        initResources
                         ▼                               │
                    ┌──────────┐                         ▼
                    │ Logout   │ ◄───────────────── 回到初始状态
                    └──────────┘
```

### Rust 状态枚举

```rust
// 对齐 Go SDK userRelated.go L54-58
pub const LOGOUT_STATUS: i32 = 1;
pub const LOGGING: i32 = 2;
pub const LOGGED: i32 = 3;

#[derive(Clone, Debug, PartialEq)]
pub enum LoginState {
    NotExist,   // 对应 LOGOUT_STATUS (初始/登出后)
    Logging,    // 对应 Logging
    Logged,     // 对应 Logged
    Logout,     // 对应登出过程
}
```

### Rust 实现建议

```rust
use std::sync::Arc;
use tokio::sync::RwLock;

pub struct LoginStateManager {
    state: Arc<RwLock<LoginState>>,
}

impl LoginStateManager {
    pub async fn get_state(&self) -> LoginState {
        self.state.read().await.clone()
    }

    pub async fn set_state(&self, state: LoginState) {
        *self.state.write().await = state;
    }

    pub async fn check_not_logged_in(&self) -> Result<()> {
        let state = self.get_state().await;
        if state == LoginState::Logged {
            return Err(anyhow::anyhow!("重复登录，请先登出"));
        }
        Ok(())
    }
}
```

---

## 2. InitSDK 流程

Go SDK 对应函数：`open_im_sdk/init_login.go` → `InitSDK()`

### 2.1 完整步骤

```
1. 解析 IMConfig JSON
   ├── apiAddr (必须包含 "http")
   ├── wsAddr (必须包含 "ws")
   ├── dataDir
   ├── platformID (必须 > 0)
   ├── logLevel
   ├── logFilePath
   ├── isLogStandardOutput
   └── logRemainCount

2. 初始化日志系统
   ├── 设置日志轮转（rotationTime = 24小时）
   ├── 配置日志保留数量
   └── 根据 platformID 设置平台名称

3. 校验地址格式
   ├── apiAddr 必须包含 "http" 前缀
   └── wsAddr 必须包含 "ws" 前缀

4. 存储配置到 UserContext.info
   ├── u.info.IMConfig = config
   └── u.connListener = listener

5. 初始化资源（initResources）
   ├── 创建 context.WithCancel
   ├── 设置前台上下文 fgCtx
   ├── 初始化 channel 队列
   │   ├── conversationEventQueue (容量: 1000)
   │   ├── msgSyncerCh (容量: 1000)
   │   └── loginMgrCh (容量: 1)
   ├── 创建 LongConnMgr
   ├── 设置 API 错误回调
   ├── 设置初始登录状态为 LogoutStatus
   ├── 创建各模块实例
   │   ├── user.NewUser(conversationEventQueue)
   │   ├── file.NewFile()
   │   ├── relation.NewRelation(conversationEventQueue, user)
   │   ├── group.NewGroup(conversationEventQueue)
   │   ├── third.NewThird(file)
   │   ├── msgSyncer.NewMsgSyncer(...)
   │   └── conversation.NewConversation(...)
   └── 设置监听器（setListener）
```

### 2.2 Rust 对应实现

```rust
// rust/src/domain/config.rs - ClientConfig（对应 Go SDK sdk_struct.IMConfig）
pub struct ClientConfig {
    pub user_id: String,
    pub token: String,
    pub platform_id: i32,          // 1:iOS, 2:Android, 3:Windows, 4:macOS, 5:Web, 6:MiniProgram, 7:Linux
    pub ws_url: Option<String>,
    pub api_base_url: String,
    pub upload_url: Option<String>,
    pub data_dir: String,
}

// rust/src/sdk/context.rs - RuntimeContext（对应 Go SDK UserContext 的核心字段）
pub struct RuntimeContext {
    pub config: ClientConfig,
    pub event_bus: Arc<EventBus>,
    pub cancel_token: CancellationToken,    // 对应 Go SDK 的 ctx/cancel
    pub user_id: Mutex<String>,
    pub operation_id: String,
    pub db_pool: SqlitePool,
    pub message_dao: Arc<MessageDao>,
    pub conversation_dao: Arc<ConversationDao>,
    pub sync_version_dao: Arc<SyncVersionDao>,
    pub sending_message_dao: Arc<SendingMessageDao>,
    pub http_client: Arc<HttpApiClient>,
}
```

---

## 3. Login 完整流程（最关键）

Go SDK 对应函数：`open_im_sdk/userRelated.go` → `login()` → `initialize()` → `run()`

### 3.1 登录流程详细步骤

```
login(userID, token)
│
├── Step 1: 检查登录状态
│   └── if getLoginStatus() == Logged → 返回 ErrLoginRepeat
│
├── Step 2: 设置状态为 Logging
│   └── setLoginStatus(Logging)
│
├── Step 3: 更新用户信息
│   ├── u.info.UserID = userID
│   └── u.info.Token = token
│
├── Step 4: initialize(ctx, userID) ──────────────────────────
│   │                                                       │
│   ├── 4.1 创建/打开数据库                                  │
│   │   └── db.NewDataBase(ctx, userID, dataDir, logLevel)  │
│   │       数据库路径: {dataDir}/openim_{userID}.db     │
│   │                                                       │
│   ├── 4.2 checkSendingMessage(ctx)                        │
│   │   ├── 获取所有 sending_messages                        │
│   │   ├── 遍历每条消息:                                    │
│   │   │   ├── 查询消息当前状态                              │
│   │   │   ├── if status == Sending → 更新为 SendFailed     │
│   │   │   ├── 更新会话的 latestMsg 状态                     │
│   │   │   └── 删除 sending_message 记录                    │
│   │   └── 崩溃恢复: 确保上次异常退出的消息不会卡在发送中       │
│   │                                                       │
│   ├── 4.3 设置各模块的 db + loginUserID                     │
│   │   ├── user.SetLoginUserID(userID)                     │
│   │   ├── user.SetDataBase(db)                            │
│   │   ├── file.SetLoginUserID(userID)                     │
│   │   ├── file.SetDataBase(db)                            │
│   │   ├── relation.SetDataBase(db)                        │
│   │   ├── relation.SetLoginUserID(userID)                 │
│   │   ├── group.SetDataBase(db)                           │
│   │   ├── group.SetLoginUserID(userID)                    │
│   │   ├── third.SetPlatform(platformID)                   │
│   │   ├── third.SetLoginUserID(userID)                    │
│   │   ├── msgSyncer.SetLoginUserID(userID)                │
│   │   ├── msgSyncer.SetDataBase(db)                       │
│   │   ├── conversation.SetLoginUserID(userID)             │
│   │   ├── conversation.SetDataBase(db)                    │
│   │   ├── conversation.SetPlatform(platformID)            │
│   │   └── conversation.SetDataDir(dataDir)                │
│   │                                                       │
│   └── 4.4 msgSyncer.LoadSeq(ctx)                          │
│       └── 从数据库加载所有会话的 max_seq 到内存              │
│                                                         │
├── Step 5: run(ctx) ─────────────────────────────────────
│   │                                                   │
│   ├── 5.1 longConnMgr.Run(ctx, fgCtx)                 │
│   │   ├── 启动 readPump（读取 WebSocket 消息）          │
│   │   ├── 启动 writePump（发送 WebSocket 消息）         │
│   │   └── 启动 heartbeat（心跳保活）                    │
│   │                                                   │
│   ├── 5.2 go msgSyncer.DoListener(ctx)                │
│   │   └── 监听 msgSyncerCh，处理消息同步指令            │
│   │                                                   │
│   ├── 5.3 go common.DoListener(ctx, conversation)     │
│   │   └── 监听 conversationEventQueue，处理会话事件     │
│   │                                                   │
│   └── 5.4 go logoutListener(ctx)                      │
│       └── 监听 loginMgrCh，处理登出指令                 │
│                                                     │
├── Step 6: 设置状态为 Logged
│   └── setLoginStatus(Logged)
│
└── 返回成功
```

### 3.2 Rust 实现

```rust
// rust/src/sdk/client/client.rs
impl OpenIMClient {
    pub async fn login(&self, user_id: &str, token: &str) -> Result<()> {
        // Step 1: 设置用户 ID 到各模块
        self.context.set_user_id(user_id.to_string());
        self.friend.set_user_id(user_id.to_string()).await;
        self.group.set_user_id(user_id.to_string()).await;
        self.message_handler.set_user_id(user_id.to_string());
        self.message_service.set_user_id(user_id.to_string());
        self.conversation_syncer.set_user_id(user_id.to_string()).await;
        self.file_uploader.set_login_user_id(user_id.to_string());

        // Step 2: 崩溃恢复 - 清理发送中的消息（对齐 Go SDK checkSendingMessage）
        self.cleanup_sending_messages().await;

        // Step 3: 建立 WebSocket 连接
        if let Some(ws_url) = &self.context.config.ws_url {
            self.connection.connect(ws_url, token, user_id, self.context.config.platform_id).await?;
            self.spawn_push_message_handler();
        }

        // Step 4: 会话全量同步
        if let Err(e) = self.conversation_syncer.sync_full().await {
            warn!("登录后会话全量同步失败: {}", e);
        }

        // Step 5: 异步触发消息同步（对齐 Go SDK msgSyncer.DoListener）
        tokio::spawn({
            let message_syncer = self.message_syncer.clone();
            async move {
                if let Err(e) = message_syncer.sync_on_login().await {
                    warn!("登录后消息同步失败: {}", e);
                }
            }
        });

        // Step 6: 发布登录成功事件
        self.event_bus.publish(SdkEvent::LoginSuccess {
            user_id: user_id.to_string(),
        });

        info!("用户登录成功: {}", user_id);
        Ok(())
    }
}
```

---

## 4. Logout 流程

Go SDK 对应函数：`open_im_sdk/userRelated.go` → `logout()`

### 4.1 完整步骤

```
logout(isTokenValid)
│
├── Step 1: 发送 DelUserPushTokenReq（仅当 token 有效时）
│   ├── 构建请求: DelUserPushTokenReq { UserID, PlatformID }
│   ├── 通过 longConnMgr.SendReqWaitResp 发送
│   ├── 超时时间: 20 秒
│   └── 失败仅 warn，不影响后续流程
│
├── Step 2: 取消所有异步任务
│   └── u.Exit()  // 调用 cancel()，所有监听 cancel_token 的 goroutine 退出
│
├── Step 3: 关闭数据库
│   └── u.db.Close(ctx)
│
├── Step 4: 重新初始化资源
│   └── u.initResources()
│       ├── 重新创建 ctx/cancel
│       ├── 重新设置 fgCtx
│       ├── 重新创建所有 channel
│       ├── 重新创建 LongConnMgr、MsgSyncer 等
│       └── 重新设置初始登录状态为 LogoutStatus
│
└── 完成
```

### 4.2 Rust 实现

```rust
// rust/src/sdk/client/core.rs
impl OpenIMClient {
    pub async fn logout(&self) -> Result<()> {
        // 发布登出事件
        self.connection.send(ConnectionEvent::Logout);

        // 清理各模块缓存
        self.user.clear().await;
        self.friend.clear().await;
        self.group.clear().await;
        self.online_status.clear_subscriptions().await?;

        // 断开 WebSocket 连接
        self.connection.disconnect().await;

        // 取消所有异步任务
        self.context.shutdown();  // 调用 cancel_token.cancel()

        // 关闭本地数据库
        self.context.close_db().await;

        info!("用户登出成功");
        Ok(())
    }
}
```

### 4.3 disconnect vs logout

| 操作 | disconnect | logout |
|------|-----------|--------|
| 断开 WebSocket | ✅ | ✅ |
| 取消所有 goroutine | ✅ (通过 cancel_token) | ✅ |
| 关闭数据库 | ❌ | ✅ |
| 清理缓存 | ❌ | ✅ |
| 发送 DelUserPushTokenReq | ❌ | ✅ (token 有效时) |
| 重新初始化资源 | ❌ | ✅ |

---

## 5. Token 过期/被踢处理

### 5.1 WebSocket 握手阶段的错误检测

Go SDK 在 `reConn()` 中检测 WebSocket 握手响应：

```go
// Go SDK interaction/long_conn_mgr.go
func (c *LongConnMgr) reConn(ctx context.Context) {
    // ...
    if errCode == sdkerrs.TokenExpiredError || errCode == sdkerrs.TokenKickedError {
        // Token 过期或被踢
        c.loginMgrCh <- common.Cmd2Value{...}
        return  // 停止重连
    }
}
```

### 5.2 logoutListener 处理

Go SDK 通过 `loginMgrCh` channel 触发登出：

```go
// Go SDK userRelated.go L278-301
func (u *UserContext) logoutListener(ctx context.Context) {
    for {
        select {
        case <-u.loginMgrCh:
            // 收到登出指令（Token 过期/被踢）
            err := u.logout(ctx, true)
        case <-ctx.Done():
            return
        }
    }
}
```

### 5.3 回调通知

Go SDK 通过 `OnConnListener` 通知上层：

| 回调方法 | 触发时机 | 参数 |
|---------|---------|------|
| `OnUserTokenExpired()` | Token 过期 | 无 |
| `OnUserTokenInvalid(errMsg)` | Token 无效 | 错误信息 |
| `OnKickedOffline()` | 被其他设备踢下线 | 无 |

### 5.4 Rust 实现

```rust
// ConnectionManager 中检测 Token 错误
pub async fn handle_kicked(&self, reason: String) {
    *self.is_manual_disconnect.write().await = true;
    *self.writer.write().await = None;
    *self.state.write().await = ConnectionState::Kicked;
    self.event_bus.publish(SdkEvent::KickedOffline { reason });
}

pub async fn handle_token_expired(&self) {
    *self.is_manual_disconnect.write().await = true;
    *self.writer.write().await = None;
    self.event_bus.publish(SdkEvent::TokenExpired);
}

// Rust SdkEvent 中的对应事件
pub enum SdkEvent {
    KickedOffline { reason: String },    // 对应 OnKickedOffline
    TokenExpired,                         // 对应 OnUserTokenExpired + OnUserTokenInvalid
    // ...
}
```

---

## 6. 后台切换处理

Go SDK 对应函数：`open_im_sdk/userRelated.go` → `setAppBackgroundStatus()`

### 6.1 完整流程

```
SetAppBackgroundStatus(isBackground)
│
├── 通知长连接管理器
│   └── longConnMgr.SetBackground(isBackground)
│
├── 如果回到前台 (isBackground = false)
│   ├── if StopGoroutineOnBackground:
│   │   ├── setFGCtx()  // 创建新的前台上下文
│   │   └── longConnMgr.ResumeForegroundTasks(ctx, fgCtx)
│   │       ├── 重启 readPump
│   │       └── 重启 heartbeat
│   └── 发送 SetAppBackgroundStatusReq 到服务端
│
├── 如果进入后台 (isBackground = true)
│   ├── if StopGoroutineOnBackground:
│   │   ├── fgCancel(cause)  // 取消前台上下文
│   │   └── longConnMgr.Close(ctx)  // 关闭 readPump 和 heartbeat
│   └── 发送 SetAppBackgroundStatusReq 到服务端
│
└── 如果回到前台，触发增量同步
    └── DispatchWakeUp → CmdWakeUpDataSync → msgSyncer 同步
```

### 6.2 Rust 实现建议

```rust
pub async fn set_app_background_status(&self, is_background: bool) -> Result<()> {
    self.connection.set_background(is_background).await;

    if !is_background {
        // 回到前台：重新启动读取和心跳
        self.connection.resume_foreground_tasks().await;

        // 发送状态到服务端
        let req = SetAppBackgroundStatusReq {
            user_id: self.context.get_user_id(),
            is_background: false,
        };
        let _: SetAppBackgroundStatusResp = self.connection
            .send_rpc(SET_BACKGROUND_STATUS, &req)
            .await?;

        // 触发增量同步
        self.message_syncer.sync_after_reconnect().await?;
    } else {
        // 进入后台：停止读取和心跳
        self.connection.pause_background_tasks().await;

        let req = SetAppBackgroundStatusReq {
            user_id: self.context.get_user_id(),
            is_background: true,
        };
        let _: SetAppBackgroundStatusResp = self.connection
            .send_rpc(SET_BACKGROUND_STATUS, &req)
            .await?;
    }

    Ok(())
}
```

### 6.3 readPump 的后台行为

当应用进入后台时，Go SDK 的 `readPump` 会通过 `fgCtx.Done()` 检测到前台上下文被取消并退出：

```go
// Go SDK interaction/long_conn_mgr.go
func (c *LongConnMgr) readPump(ctx context.Context, fgCtx context.Context, conn *websocket.Conn) {
    for {
        select {
        case <-ctx.Done():
            return
        case <-fgCtx.Done():
            return  // 后台时退出
        case message, ok := <-ch:
            // 处理消息...
        }
    }
}
```

---

## 7. 网络状态变化处理

Go SDK 对应函数：`open_im_sdk/init_login.go` → `NetworkStatusChanged()`

```go
func (u *UserContext) NetworkStatusChanged(ctx context.Context) {
    u.longConnMgr.Close(ctx)
}
```

当网络状态变化时（如从 WiFi 切换到 4G），SDK 直接关闭当前连接，由重连机制自动恢复。

### Rust 实现

```rust
pub async fn network_status_changed(&self) {
    self.connection.disconnect().await;
    // 重连机制会自动触发
}
```

---

## 8. WebSocket 连接管理

### 8.1 连接状态枚举

```rust
// rust/src/core/connection/manager.rs
pub enum ConnectionState {
    Disconnected,
    Connecting,
    Connected,
    Reconnecting,
    Kicked,
}
```

### 8.2 重连策略

| 参数 | 值 | 说明 |
|------|-----|------|
| `HEARTBEAT_INTERVAL` | 30 秒 | 心跳间隔 |
| `PONG_TIMEOUT` | 60 秒 | Pong 超时 |
| `RECONNECT_BASE_DELAY` | 1 秒 | 初始重连延迟 |
| `RECONNECT_MAX_DELAY` | 60 秒 | 最大重连延迟 |
| `MAX_RECONNECT_ATTEMPTS` | 300 | 最大重连次数 |
| `RPC_TIMEOUT` | 30 秒 | RPC 请求超时 |

### 8.3 重连延迟计算

```rust
fn calculate_reconnect_delay(&self, attempt: u32) -> Duration {
    let delay_secs = if attempt < 5 {
        1 << attempt                    // 1, 2, 4, 8, 16 秒
    } else if attempt < 10 {
        16 + (attempt - 5) * 4          // 20, 24, 28, 32, 36 秒
    } else {
        60                              // 固定 60 秒
    };
    Duration::from_secs(delay_secs as u64).min(RECONNECT_MAX_DELAY)
}
```

### 8.4 重连流程

```
连接断开 (Disconnected)
│
├── 重连循环启动
│   ├── 检查是否手动断开 → 是则停止
│   ├── 检查重连次数 >= MAX_RECONNECT_ATTEMPTS → 是则停止
│   ├── 计算延迟时间（指数退避）
│   ├── 发布 SdkEvent::Reconnecting { attempt, max_attempts }
│   ├── 等待延迟（可被 cancel 中断）
│   ├── 设置状态为 Reconnecting
│   ├── 调用 do_connect()
│   │   ├── 成功 → 重置重连次数，重新启动 readPump/heartbeat
│   │   └── 失败 → 设置状态为 Disconnected，发布 Disconnected 事件
│   └── 继续循环
│
└── 达到最大次数
    └── 发布 SdkEvent::Disconnected { reason: "max reconnect attempts" }
```

---

## 9. Rust 实现建议汇总

### 9.1 核心类型设计

```rust
use std::sync::Arc;
use tokio::sync::RwLock;
use tokio_util::sync::CancellationToken;

/// SDK 主客户端（对齐 Go SDK UserContext）
pub struct OpenIMClient {
    pub(crate) context: Arc<RuntimeContext>,
    pub(crate) connection: Arc<ConnectionManager>,
    pub(crate) user: Arc<UserManager>,
    pub(crate) friend: Arc<FriendManager>,
    pub(crate) group: Arc<GroupManager>,
    pub(crate) conversation: Arc<ConversationManager>,
    pub(crate) message_syncer: Arc<MessageSyncer>,
    pub(crate) message_handler: Arc<MessageHandler>,
    pub(crate) conversation_syncer: Arc<ConversationSyncer>,
    pub(crate) online_status: Arc<OnlineStatusManager>,
    pub(crate) file_uploader: Arc<FileUploader>,
    pub(crate) message_service: Arc<MessageService>,
    pub(crate) event_bus: Arc<EventBus>,
    pub(crate) cache: Arc<CacheManager>,
}
```

### 9.2 关键设计原则

| 原则 | 说明 |
|------|------|
| `CancellationToken` 统一管理 | 使用 `tokio_util::CancellationToken` 替代 Go SDK 的 `context.WithCancel`，实现优雅关闭 |
| `EventBus` 替代 channel + callback | 使用 `tokio::sync::broadcast` 替代 Go SDK 的 channel + listener 模式 |
| `Arc<T>` 共享所有权 | 各模块通过 `Arc` 共享，避免生命周期问题 |
| `tokio::spawn` 后台任务 | 替代 Go SDK 的 `go` 协程，支持优雅取消 |
| `RwLock` 保护可变状态 | 替代 Go SDK 的 `sync.Mutex`，支持异步读写 |

### 9.3 与 Go SDK 的关键差异

| Go SDK | Rust SDK | 说明 |
|--------|----------|------|
| `context.WithCancel` | `CancellationToken` | Go 的 context 嵌套更深，Rust 使用扁平化取消 |
| `chan common.Cmd2Value` | `broadcast::channel` | Go 使用命令模式，Rust 使用事件广播 |
| `sync.Mutex` | `tokio::sync::RwLock` | Go 的锁不跨 await，Rust 的 RwLock 支持异步 |
| `go func()` | `tokio::spawn` | Go 协程更轻量，Rust 需要显式管理 |
| 单例 `IMUserContext` | `OnceLock<Arc<OpenIMClient>>` | Go 使用全局变量，Rust 使用类型安全的单例 |
| JSON 字符串传递 | 强类型参数 | Go SDK 大量使用 JSON 字符串，Rust 使用结构体 |

---

## 10. 完整生命周期时序图

```
Flutter App                    Rust SDK                      Server
    │                              │                            │
    │── new(config) ──────────────►│                            │
    │                              │── 初始化 EventBus ──►      │
    │                              │── 初始化 RuntimeContext ──► │
    │                              │   ├── 创建数据库连接        │
    │                              │   └── 创建 HTTP 客户端     │
    │                              │── 创建各模块实例 ──►        │
    │◄── OpenIMClient ────────────│                            │
    │                              │                            │
    │── event_stream(sink) ──────►│                            │
    │                              │── 订阅 EventBus ──►        │
    │                              │                            │
    │── login(user_id, token) ───►│                            │
    │                              │── 设置各模块 user_id ──►   │
    │                              │── cleanup_sending_messages │
    │                              │── connect(ws_url, token) ─►│── WS 握手 ──►│
    │                              │◄── Connected ─────────────│             │
    │                              │── spawn_push_message_handler             │
    │                              │── conversation_syncer.sync_full() ──────►│
    │                              │── message_syncer.sync_on_login() ──────►│
    │                              │── publish(LoginSuccess) ──►│             │
    │◄── Stream: LoginSuccess ────│                            │
    │                              │                            │
    │  ... 正常使用中 ...          │                            │
    │                              │                            │
    │── send_text_message() ─────►│                            │
    │                              │── insert_message_before_send             │
    │                              │── send_rpc(1003, msg) ───►│── 处理消息 ──►│
    │                              │◄── UserSendMsgResp ──────│             │
    │                              │── update_after_send_success             │
    │                              │── publish(MessageSent) ──►│             │
    │◄── Stream: MessageSent ─────│                            │
    │                              │                            │
    │                              │◄── PushMessage ───────────│── 新消息推送 ──│
    │                              │── handle_messages ──►     │
    │                              │── publish(NewMessage) ──►│             │
    │◄── Stream: NewMessage ──────│                            │
    │                              │                            │
    │── logout() ────────────────►│                            │
    │                              │── 清理各模块缓存           │
    │                              │── 断开 WebSocket 连接      │
    │                              │── 关闭本地数据库            │
    │                              │── cancel_token.cancel()   │
    │                              │── publish(Logout) ──►     │
    │◄── Stream: Logout ──────────│                            │
```
