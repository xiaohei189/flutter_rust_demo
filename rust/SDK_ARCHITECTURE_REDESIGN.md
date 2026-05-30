# Rust SDK 架构重新设计

## 一、当前架构分析

### 1.1 当前架构概览

```
rust/src/
├── api/                          # FFI 桥接层
│   ├── bridge_client.rs
│   ├── bridge_friend.rs
│   ├── bridge_group.rs
│   ├── bridge_online.rs
│   └── bridge_user.rs
├── im/
│   ├── client/
│   │   ├── client.rs             # IMClient 核心（1800+ 行）
│   │   ├── connection_handle.rs  # WebSocket 连接管理
│   │   ├── conversation_handle.rs # 会话处理（1200+ 行）
│   │   ├── message_handle.rs     # 消息同步器
│   │   ├── friend_sync.rs        # 好友同步
│   │   ├── listeners.rs          # 事件定义
│   │   ├── online_status.rs      # 在线状态
│   │   └── reconnect.rs          # 重连策略
│   ├── dao/                      # 数据访问层
│   ├── http_client/              # HTTP API 客户端
│   ├── model/                    # 数据模型
│   ├── syncer/                   # 通用同步器框架
│   └── third/                    # 第三方服务
```

### 1.2 当前架构存在的问题

#### 问题 1: IMClient 职责过重（God Object）

**现状**:
- `client.rs` 文件超过 1800 行
- 包含配置、缓存、API、数据库、回调管理等所有功能
- 直接依赖所有子模块，耦合度极高

**问题**:
```rust
pub struct IMClient {
    config: ClientConfig,                          // 配置
    callbacks: Arc<RwLock<Listeners>>,             // 回调管理
    ws_send_tx: Arc<RwLock<Option<...>>>,          // WebSocket 发送
    run_handle: Arc<RwLock<Option<...>>>,          // 运行时管理
    cancel_token: Arc<RwLock<Option<...>>>,        // 取消令牌
    local_repo: Repository,                        // 数据库
    api: Api,                                      // HTTP API
    message_pull_forward_end_seq_map: ...,         // 消息拉取状态
    message_pull_reverse_end_seq_map: ...,         // 消息拉取状态
    user_cache: Arc<RwLock<HashMap<...>>>,         // 用户缓存
    online_status_manager: Option<Arc<...>>,       // 在线状态
}
```

**影响**:
- 难以测试（需要 mock 所有依赖）
- 难以扩展（添加新功能需要修改核心结构）
- 难以理解（职责不清晰）

---

#### 问题 2: 模块边界不清晰

**现状**:
- `ConnectionHandle`、`ConversationHandle`、`MessageHandle` 职责交叉
- 命令通道混乱（`cmd_rx`、`msg_sync_cmd_tx`、`conv_cmd_tx`、`event_tx`）
- 数据流向不清晰

**问题示例**:
```rust
// ConnectionHandle 中有消息同步命令
msg_sync_cmd_tx: mpsc::UnboundedSender<MsgSyncCommand>,

// MessageHandle 中有会话命令
conv_cmd_tx: mpsc::UnboundedSender<ConvCmd>,

// ConversationHandle 中有消息处理逻辑
pub async fn handle_new_messages(&self, msgs: HashMap<String, sdkws::PullMsgs>) -> Result<()>
```

**影响**:
- 模块间依赖复杂
- 数据流难以追踪
- 容易出现循环依赖

---

#### 问题 3: 缺少统一的事件总线

**现状**:
- 事件通过多个通道传递（`ConnEventTx`、`ConversationEventTx`、`AdvancedMsgEventTx` 等）
- 每个模块独立管理自己的事件
- FFI 层需要分别订阅每个事件

**问题**:
```rust
// 当前：分散的事件通道
pub type ConnEventTx = Arc<RwLock<Option<mpsc::UnboundedSender<ConnEvent>>>>;
pub type ConversationEventTx = Arc<RwLock<Option<mpsc::UnboundedSender<ConversationEvent>>>>;
pub type AdvancedMsgEventTx = Arc<RwLock<Option<mpsc::UnboundedSender<AdvancedMsgEvent>>>>;
pub type FriendEventTx = Arc<RwLock<Option<mpsc::UnboundedSender<FriendEvent>>>>;
pub type GroupEventTx = Arc<RwLock<Option<mpsc::UnboundedSender<GroupEvent>>>>;
pub type UserEventTx = Arc<RwLock<Option<mpsc::UnboundedSender<UserEvent>>>>;
```

**影响**:
- 事件订阅复杂
- 容易遗漏事件
- 难以添加全局事件处理

---

#### 问题 4: 数据库访问模式不统一

**现状**:
- `Repository` 聚合所有 DAO，但 DAO 之间独立
- 缺少事务支持
- 缓存策略不统一

**问题**:
```rust
pub struct Repository {
    pub pool: Pool<Sqlite>,
    pub conversation: ConversationDao,
    pub message: MessageRepo,
    pub friend: FriendDao,
    // ... 15 个 DAO
}
```

**影响**:
- 跨表操作需要手动管理事务
- 缓存一致性难以保证
- 性能优化困难

---

#### 问题 5: 缺少依赖注入

**现状**:
- 所有依赖在 `IMClient::new()` 中硬编码创建
- 无法替换实现（如测试时 mock）
- 配置和实现耦合

**问题**:
```rust
pub async fn new(config: ClientConfig) -> Result<Self> {
    let repo = Repository::create(&config.conversation_db_url).await?;
    let http_client = Self::create_http_client(&config)?;
    let api = Api::new(http_client, ...);
    // ... 所有依赖硬编码
}
```

**影响**:
- 难以测试
- 难以扩展
- 难以配置

---

#### 问题 6: 错误处理不统一

**现状**:
- 使用 `anyhow::Result` 但缺少自定义错误类型
- 错误信息不够结构化
- FFI 层错误映射困难

**影响**:
- 错误处理不一致
- 难以区分错误类型
- 用户体验差

---

## 二、新架构设计

### 2.1 设计原则

1. **单一职责**: 每个模块只负责一个明确的功能
2. **依赖倒置**: 依赖接口而非具体实现
3. **事件驱动**: 统一事件总线，解耦模块
4. **分层架构**: 清晰的分层，禁止跨层调用
5. **可测试性**: 所有模块可独立测试

---

### 2.2 新架构概览

```
rust/src/
├── api/                          # FFI 桥接层（薄层）
│   ├── mod.rs
│   ├── bridge_client.rs
│   ├── bridge_friend.rs
│   ├── bridge_group.rs
│   ├── bridge_online.rs
│   └── bridge_user.rs
│
├── sdk/                          # SDK 核心层（新增）
│   ├── mod.rs
│   ├── client.rs                 # SDK 客户端（门面）
│   ├── builder.rs                # 构建器模式
│   └── context.rs                # 运行时上下文
│
├── core/                         # 核心业务层（新增）
│   ├── mod.rs
│   ├── connection/               # 连接管理
│   │   ├── mod.rs
│   │   ├── manager.rs            # 连接管理器
│   │   ├── websocket.rs          # WebSocket 实现
│   │   ├── reconnect.rs          # 重连策略
│   │   └── heartbeat.rs          # 心跳机制
│   │
│   ├── message/                  # 消息管理
│   │   ├── mod.rs
│   │   ├── sender.rs             # 消息发送队列
│   │   ├── syncer.rs             # 消息同步器
│   │   ├── handler.rs            # 消息处理器
│   │   ├── builder.rs            # 消息构建器
│   │   └── types.rs              # 消息类型
│   │
│   ├── conversation/             # 会话管理
│   │   ├── mod.rs
│   │   ├── manager.rs            # 会话管理器
│   │   ├── syncer.rs             # 会话同步器
│   │   └── handler.rs            # 会话处理器
│   │
│   ├── user/                     # 用户管理
│   │   ├── mod.rs
│   │   ├── manager.rs            # 用户管理器
│   │   ├── cache.rs              # 用户缓存
│   │   └── syncer.rs             # 用户同步器
│   │
│   ├── friend/                   # 好友管理
│   │   ├── mod.rs
│   │   ├── manager.rs            # 好友管理器
│   │   └── syncer.rs             # 好友同步器
│   │
│   ├── group/                    # 群组管理
│   │   ├── mod.rs
│   │   ├── manager.rs            # 群组管理器
│   │   └── syncer.rs             # 群组同步器
│   │
│   └── online/                   # 在线状态
│       ├── mod.rs
│       └── manager.rs            # 在线状态管理器
│
├── infra/                        # 基础设施层（新增）
│   ├── mod.rs
│   ├── database/                 # 数据库
│   │   ├── mod.rs
│   │   ├── pool.rs               # 连接池
│   │   ├── migration.rs          # 迁移管理
│   │   └── transaction.rs        # 事务管理
│   │
│   ├── http/                     # HTTP 客户端
│   │   ├── mod.rs
│   │   ├── client.rs             # HTTP 客户端
│   │   ├── auth.rs               # 认证中间件
│   │   └── routes.rs             # 路由定义
│   │
│   ├── cache/                    # 缓存
│   │   ├── mod.rs
│   │   ├── memory.rs             # 内存缓存
│   │   └── lru.rs                # LRU 缓存
│   │
│   └── file/                     # 文件服务
│       ├── mod.rs
│       └── uploader.rs           # 文件上传
│
├── domain/                       # 领域层（新增）
│   ├── mod.rs
│   ├── model/                    # 领域模型
│   │   ├── mod.rs
│   │   ├── user.rs
│   │   ├── friend.rs
│   │   ├── group.rs
│   │   ├── conversation.rs
│   │   ├── message.rs
│   │   └── common.rs
│   │
│   ├── event/                    # 事件定义
│   │   ├── mod.rs
│   │   ├── bus.rs                # 事件总线
│   │   └── types.rs              # 事件类型
│   │
│   ├── error/                    # 错误定义
│   │   ├── mod.rs
│   │   └── types.rs              # 错误类型
│   │
│   └── constant/                 # 常量定义
│       └── mod.rs
│
└── repository/                   # 数据访问层（重构）
    ├── mod.rs
    ├── traits.rs                 # Repository 接口
    ├── impl/                     # 实现
    │   ├── user.rs
    │   ├── friend.rs
    │   ├── group.rs
    │   ├── conversation.rs
    │   └── message.rs
    └── dao/                      # DAO（保留现有）
        ├── user.rs
        ├── friend.rs
        ├── group.rs
        ├── conversation.rs
        └── message.rs
```

---

### 2.3 核心设计

#### 设计 1: SDK 客户端（门面模式）

```rust
// sdk/client.rs
pub struct OpenIMClient {
    config: ClientConfig,
    context: RuntimeContext,
    event_bus: EventBus,
    
    // 核心模块（通过 trait 接口）
    connection: Arc<dyn ConnectionManager>,
    message: Arc<dyn MessageManager>,
    conversation: Arc<dyn ConversationManager>,
    user: Arc<dyn UserManager>,
    friend: Arc<dyn FriendManager>,
    group: Arc<dyn GroupManager>,
    online: Arc<dyn OnlineStatusManager>,
}

impl OpenIMClient {
    /// 使用构建器创建
    pub fn builder() -> ClientBuilder {
        ClientBuilder::new()
    }
    
    /// 启动 SDK
    pub async fn start(&self) -> Result<()> {
        self.context.initialize().await?;
        self.connection.start().await?;
        self.message.start().await?;
        Ok(())
    }
    
    /// 停止 SDK
    pub async fn stop(&self) -> Result<()> {
        self.connection.stop().await?;
        self.message.stop().await?;
        self.context.shutdown().await?;
        Ok(())
    }
    
    /// 获取事件订阅
    pub fn subscribe_events(&self) -> EventSubscription {
        self.event_bus.subscribe()
    }
}
```

---

#### 设计 2: 构建器模式

```rust
// sdk/builder.rs
pub struct ClientBuilder {
    config: ClientConfig,
    db_url: Option<String>,
    api_base_url: Option<String>,
    log_level: Option<Level>,
    // ... 其他配置
}

impl ClientBuilder {
    pub fn new() -> Self {
        Self {
            config: ClientConfig::default(),
            db_url: None,
            api_base_url: None,
            log_level: None,
        }
    }
    
    pub fn user_id(mut self, user_id: String) -> Self {
        self.config.user_id = user_id;
        self
    }
    
    pub fn token(mut self, token: String) -> Self {
        self.config.token = token;
        self
    }
    
    pub fn db_url(mut self, url: String) -> Self {
        self.db_url = Some(url);
        self
    }
    
    pub fn api_base_url(mut self, url: String) -> Self {
        self.api_base_url = Some(url);
        self
    }
    
    pub fn log_level(mut self, level: Level) -> Self {
        self.log_level = Some(level);
        self
    }
    
    pub async fn build(self) -> Result<OpenIMClient> {
        // 验证配置
        self.validate()?;
        
        // 创建上下文
        let context = RuntimeContext::new(&self.config).await?;
        
        // 创建事件总线
        let event_bus = EventBus::new();
        
        // 创建各模块
        let connection = ConnectionManagerImpl::new(
            self.config.clone(),
            event_bus.clone(),
        ).await?;
        
        let message = MessageManagerImpl::new(
            self.config.clone(),
            context.repository(),
            event_bus.clone(),
        ).await?;
        
        // ... 创建其他模块
        
        Ok(OpenIMClient {
            config: self.config,
            context,
            event_bus,
            connection,
            message,
            // ...
        })
    }
}
```

---

#### 设计 3: 统一事件总线

```rust
// domain/event/bus.rs
pub struct EventBus {
    sender: broadcast::Sender<SdkEvent>,
}

impl EventBus {
    pub fn new() -> Self {
        let (sender, _) = broadcast::channel(1024);
        Self { sender }
    }
    
    pub fn publish(&self, event: SdkEvent) {
        let _ = self.sender.send(event);
    }
    
    pub fn subscribe(&self) -> EventSubscription {
        EventSubscription {
            receiver: self.sender.subscribe(),
        }
    }
}

pub struct EventSubscription {
    receiver: broadcast::Receiver<SdkEvent>,
}

impl EventSubscription {
    pub async fn next(&mut self) -> Option<SdkEvent> {
        loop {
            match self.receiver.recv().await {
                Ok(event) => return Some(event),
                Err(broadcast::error::RecvError::Lagged(n)) => {
                    warn!("Event bus lagged, dropped {} events", n);
                }
                Err(broadcast::error::RecvError::Closed) => {
                    return None;
                }
            }
        }
    }
}

#[derive(Clone, Debug, Serialize)]
#[serde(tag = "type", content = "data", rename_all = "camelCase")]
pub enum SdkEvent {
    // 连接事件
    Connecting,
    Connected,
    Disconnected { reason: String },
    ConnectFailed { error: SdkError },
    
    // 消息事件
    NewMessage { message: MsgStruct },
    MessageSent { client_msg_id: String },
    MessageRevoked { info: MessageRevokedInfo },
    MessageRead { receipt: ReadReceiptItem },
    
    // 会话事件
    ConversationChanged { conversations: Vec<LocalConversation> },
    NewConversation { conversations: Vec<LocalConversation> },
    UnreadCountChanged { total: i32 },
    
    // 好友事件
    FriendRequestReceived { request: FriendRequest },
    FriendAdded { friend: FriendInfo },
    FriendDeleted { user_id: String },
    
    // 群组事件
    GroupInfoChanged { group: LocalGroup },
    MemberJoined { group_id: String, member: LocalGroupMember },
    MemberLeft { group_id: String, user_id: String },
    
    // 用户事件
    UserInfoChanged { user: LocalUser },
    UserStatusChanged { status: OnlineStatus },
}
```

---

#### 设计 4: 依赖注入容器

```rust
// sdk/context.rs
pub struct RuntimeContext {
    config: ClientConfig,
    repository: Repository,
    http_client: reqwest::Client,
    api: Api,
    cache: CacheManager,
    cancel_token: CancellationToken,
}

impl RuntimeContext {
    pub async fn new(config: &ClientConfig) -> Result<Self> {
        let repository = Repository::create(&config.conversation_db_url).await?;
        let http_client = Self::create_http_client(config)?;
        let api = Api::new(
            http_client.clone(),
            config.api_base_url.clone(),
            config.user_id.clone(),
            &config.token,
        );
        let cache = CacheManager::new();
        let cancel_token = CancellationToken::new();
        
        Ok(Self {
            config: config.clone(),
            repository,
            http_client,
            api,
            cache,
            cancel_token,
        })
    }
    
    pub fn repository(&self) -> &Repository {
        &self.repository
    }
    
    pub fn api(&self) -> &Api {
        &self.api
    }
    
    pub fn cache(&self) -> &CacheManager {
        &self.cache
    }
    
    pub fn cancel_token(&self) -> CancellationToken {
        self.cancel_token.clone()
    }
    
    pub fn shutdown(&self) {
        self.cancel_token.cancel();
    }
}
```

---

#### 设计 5: 模块接口定义

```rust
// core/connection/mod.rs
#[async_trait]
pub trait ConnectionManager: Send + Sync {
    /// 启动连接
    async fn start(&self) -> Result<()>;
    
    /// 停止连接
    async fn stop(&self) -> Result<()>;
    
    /// 发送请求并等待响应
    async fn send_request<T: ProtobufMessage, R: ProtobufMessage>(
        &self,
        req_identifier: i32,
        data: &T,
    ) -> Result<R>;
    
    /// 发送请求（不等待响应）
    async fn send(&self, req_identifier: i32, data: &[u8]) -> Result<()>;
    
    /// 获取连接状态
    fn status(&self) -> ConnectionStatus;
}

// core/message/mod.rs
#[async_trait]
pub trait MessageManager: Send + Sync {
    /// 启动消息管理器
    async fn start(&self) -> Result<()>;
    
    /// 停止消息管理器
    async fn stop(&self) -> Result<()>;
    
    /// 发送消息
    async fn send_message(&self, message: MsgStruct) -> Result<MsgStruct>;
    
    /// 拉取历史消息
    async fn get_history_messages(
        &self,
        conversation_id: String,
        params: GetAdvancedHistoryMessageListParams,
    ) -> Result<GetAdvancedHistoryMessageListCallback>;
    
    /// 标记已读
    async fn mark_as_read(&self, conversation_id: String) -> Result<()>;
    
    /// 撤回消息
    async fn revoke_message(&self, conversation_id: String, client_msg_id: String) -> Result<()>;
}

// core/conversation/mod.rs
#[async_trait]
pub trait ConversationManager: Send + Sync {
    /// 获取所有会话
    async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>>;
    
    /// 获取指定会话
    async fn get_conversation(&self, conversation_id: String) -> Result<Option<LocalConversation>>;
    
    /// 设置会话免打扰
    async fn set_mute(&self, conversation_id: String, mute: bool) -> Result<()>;
    
    /// 设置会话置顶
    async fn set_pinned(&self, conversation_id: String, pinned: bool) -> Result<()>;
    
    /// 删除会话
    async fn delete_conversation(&self, conversation_id: String) -> Result<()>;
}
```

---

#### 设计 6: 统一错误类型

```rust
// domain/error/types.rs
#[derive(Debug, thiserror::Error)]
pub enum SdkError {
    #[error("参数错误: {message}")]
    InvalidArgument { message: String },
    
    #[error("网络错误: {source}")]
    NetworkError { source: reqwest::Error },
    
    #[error("连接错误: {message}")]
    ConnectionError { message: String },
    
    #[error("认证错误: {message}")]
    AuthError { message: String },
    
    #[error("数据库错误: {source}")]
    DatabaseError { source: sqlx::Error },
    
    #[error("消息发送失败: {message}")]
    MessageSendFailed { message: String },
    
    #[error("同步失败: {message}")]
    SyncFailed { message: String },
    
    #[error("超时: {message}")]
    Timeout { message: String },
    
    #[error("未知错误: {message}")]
    Unknown { message: String },
}

impl SdkError {
    pub fn code(&self) -> i32 {
        match self {
            Self::InvalidArgument { .. } => 1001,
            Self::NetworkError { .. } => 1002,
            Self::ConnectionError { .. } => 1003,
            Self::AuthError { .. } => 1004,
            Self::DatabaseError { .. } => 1005,
            Self::MessageSendFailed { .. } => 1006,
            Self::SyncFailed { .. } => 1007,
            Self::Timeout { .. } => 1008,
            Self::Unknown { .. } => 9999,
        }
    }
}

pub type Result<T> = std::result::Result<T, SdkError>;
```

---

### 2.4 数据流设计

#### 2.4.1 消息发送流程

```
Flutter (Dart)
    ↓ FFI 调用
api/bridge_client.rs::send_message()
    ↓
sdk/client.rs::send_message()
    ↓
core/message/sender.rs::submit()
    ↓
[消息队列] → Worker 处理
    ↓
[媒体消息] → infra/file/uploader.rs::upload()
    ↓
core/connection/manager.rs::send_request()
    ↓
[WebSocket] → 服务端
    ↓
core/message/handler.rs::on_response()
    ↓
repository/message.rs::insert()
    ↓
domain/event/bus.rs::publish(MessageSent)
    ↓
Flutter 接收事件
```

#### 2.4.2 消息接收流程

```
服务端推送消息
    ↓
[WebSocket] → core/connection/websocket.rs::on_message()
    ↓
core/connection/manager.rs::dispatch()
    ↓
core/message/syncer.rs::on_push()
    ↓
core/message/handler.rs::handle()
    ↓
repository/message.rs::insert()
    ↓
domain/event/bus.rs::publish(NewMessage)
    ↓
Flutter 接收事件
```

#### 2.4.3 会话同步流程

```
登录成功
    ↓
sdk/client.rs::start()
    ↓
core/conversation/syncer.rs::sync()
    ↓
[全量同步] → infra/http/conversation.rs::get_all()
    ↓
[增量同步] → infra/http/conversation.rs::get_incremental()
    ↓
repository/conversation.rs::upsert()
    ↓
domain/event/bus.rs::publish(ConversationChanged)
    ↓
Flutter 接收事件
```

---

### 2.5 模块依赖关系

```
api/ (FFI 层)
    ↓
sdk/ (SDK 门面)
    ↓
core/ (核心业务)
    ↓
domain/ (领域模型)
    ↓
infra/ (基础设施)
    ↓
repository/ (数据访问)
```

**依赖规则**:
- 上层可以依赖下层
- 同层模块不能互相依赖
- 下层不能依赖上层
- 所有依赖通过 trait 接口

---

## 三、迁移计划

### Phase 1: 基础设施准备（1 周）

1. 创建新目录结构
2. 定义领域模型和错误类型
3. 实现事件总线
4. 实现依赖注入容器

### Phase 2: 核心模块重构（2-3 周）

1. 重构连接管理模块
2. 重构消息管理模块
3. 重构会话管理模块
4. 重构用户/好友/群组模块

### Phase 3: SDK 门面（1 周）

1. 实现 SDK 客户端
2. 实现构建器模式
3. 更新 FFI 桥接层

### Phase 4: 测试和优化（1-2 周）

1. 单元测试
2. 集成测试
3. 性能优化
4. 文档完善

---

## 四、改进收益

### 4.1 可维护性

- ✅ 模块职责清晰
- ✅ 依赖关系明确
- ✅ 易于定位问题

### 4.2 可测试性

- ✅ 模块可独立测试
- ✅ 支持 mock
- ✅ 测试覆盖率高

### 4.3 可扩展性

- ✅ 新功能易于添加
- ✅ 支持插件化
- ✅ 配置灵活

### 4.4 性能

- ✅ 事件总线优化
- ✅ 缓存策略统一
- ✅ 数据库事务支持

---

## 五、总结

### 当前架构评分

| 维度 | 评分 | 说明 |
|------|------|------|
| 可维护性 | ⭐⭐ | 模块职责不清，IMClient 过重 |
| 可测试性 | ⭐⭐ | 依赖硬编码，难以 mock |
| 可扩展性 | ⭐⭐⭐ | 功能可添加，但需要修改核心 |
| 性能 | ⭐⭐⭐ | 基本满足，优化空间大 |
| 代码质量 | ⭐⭐⭐ | 代码规范，但架构需改进 |

### 新架构预期评分

| 维度 | 评分 | 说明 |
|------|------|------|
| 可维护性 | ⭐⭐⭐⭐⭐ | 分层清晰，职责明确 |
| 可测试性 | ⭐⭐⭐⭐⭐ | 依赖注入，易于 mock |
| 可扩展性 | ⭐⭐⭐⭐⭐ | 接口设计，插件化 |
| 性能 | ⭐⭐⭐⭐ | 事件总线优化，缓存统一 |
| 代码质量 | ⭐⭐⭐⭐⭐ | 架构规范，代码整洁 |

---

## 七、核心模块详细设计

### 7.1 消息发送队列详细设计

#### 7.1.1 Go SDK 实现分析

Go SDK 的消息发送队列核心特性：
- **多 Worker 并发**: `runtime.NumCPU()` 个 worker，最少 4 个
- **双 Lane 有序发送**: Text Lane 和 Media Lane 分别有序
- **动态阈值估计**: 根据网络状况动态调整媒体消息是否有序
- **超时机制**: 3 秒超时，超时后不保证顺序
- **重试入队**: 队列满时重试 100 次，每次 5ms

```go
// Go 实现核心结构
type messageSender struct {
    conversation *Conversation
    queue        chan *sendTask
    wg           sync.WaitGroup
    textSeq      atomic.Int64
    mediaSeq     atomic.Int64
    estimator    *thresholdEstimator
}
```

#### 7.1.2 Rust 实现设计

```rust
// core/message/sender.rs

/// 发送队列配置
pub struct SenderConfig {
    /// Worker 数量，默认 CPU 核心数（最少 4）
    pub worker_count: usize,
    /// 队列大小，默认 256
    pub queue_size: usize,
    /// 发送超时，默认 3 秒
    pub send_timeout: Duration,
    /// 媒体有序阈值，默认 16KB
    pub media_ordered_threshold: usize,
}

impl Default for SenderConfig {
    fn default() -> Self {
        Self {
            worker_count: std::cmp::max(4, num_cpus::get()),
            queue_size: 256,
            send_timeout: Duration::from_secs(3),
            media_ordered_threshold: 16 * 1024,
        }
    }
}

/// 发送 Lane 类型
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SendLane {
    /// 文本 Lane（小消息）
    Text,
    /// 媒体 Lane（文件、图片、视频）
    Media,
}

/// 发送任务
pub struct SendTask {
    /// 消息内容
    pub message: MsgStruct,
    /// 会话 ID
    pub conversation_id: String,
    /// 发送 Lane
    pub lane: SendLane,
    /// 序列号（有序发送用）
    pub seq: i64,
    /// 入队时间
    pub enqueue_at: Instant,
    /// 截止时间
    pub deadline: Instant,
    /// 是否有序
    pub ordered: bool,
    /// 媒体大小（字节）
    pub media_size: usize,
    /// 结果回调
    pub result_tx: oneshot::Sender<Result<MsgStruct>>,
}

/// 阈值估计器（动态调整媒体消息是否有序）
pub struct ThresholdEstimator {
    /// 当前阈值（字节）
    value: AtomicU64,
    /// 最小阈值 4KB
    min_value: u64,
    /// 最大阈值 8MB
    max_value: u64,
    /// 默认值 16KB
    default_value: u64,
}

impl ThresholdEstimator {
    pub fn new() -> Self {
        Self {
            value: AtomicU64::new(16 * 1024),
            min_value: 4 * 1024,
            max_value: 8 * 1024 * 1024,
            default_value: 16 * 1024,
        }
    }
    
    pub fn current(&self) -> u64 {
        let v = self.value.load(Ordering::Relaxed);
        v.clamp(self.min_value, self.max_value)
    }
    
    /// 根据上次发送情况更新阈值
    pub fn update(&self, size: u64, elapsed: Duration) {
        if size == 0 || elapsed.is_zero() {
            return;
        }
        let bytes_per_sec = size as f64 / elapsed.as_secs_f64();
        let target = (bytes_per_sec * 3.0) as u64; // 3 秒内的数据量
        let target = target.clamp(self.min_value, self.max_value);
        self.value.store(target, Ordering::Relaxed);
    }
}

/// 消息发送器
pub struct MessageSender {
    config: SenderConfig,
    /// 任务队列
    queue: mpsc::UnboundedSender<SendTask>,
    /// Worker handles
    workers: Vec<JoinHandle<()>>,
    /// 文本序列号
    text_seq: AtomicI64,
    /// 媒体序列号
    media_seq: AtomicI64,
    /// 阈值估计器
    estimator: Arc<ThresholdEstimator>,
    /// 取消令牌
    cancel_token: CancellationToken,
}

impl MessageSender {
    pub fn new(config: SenderConfig, cancel_token: CancellationToken) -> Self {
        let (tx, mut rx) = mpsc::unbounded_channel::<SendTask>();
        let estimator = Arc::new(ThresholdEstimator::new());
        
        let workers = (0..config.worker_count)
            .map(|_| {
                let rx = rx.clone();
                let estimator = estimator.clone();
                let cancel = cancel_token.clone();
                tokio::spawn(async move {
                    Self::worker_loop(rx, estimator, cancel).await;
                })
            })
            .collect();
        
        Self {
            config,
            queue: tx,
            workers,
            text_seq: AtomicI64::new(0),
            media_seq: AtomicI64::new(0),
            estimator,
            cancel_token,
        }
    }
    
    /// 提交发送任务
    pub async fn submit(&self, message: MsgStruct, conversation_id: String) -> Result<MsgStruct> {
        let (tx, rx) = oneshot::channel();
        
        let is_media = is_media_content_type(message.content_type);
        let lane = if is_media { SendLane::Media } else { SendLane::Text };
        let media_size = if is_media { estimate_media_size(&message) } else { 0 };
        
        let ordered = if is_media {
            media_size <= self.estimator.current() as usize
        } else {
            true
        };
        
        let seq = if ordered {
            if lane == SendLane::Text {
                self.text_seq.fetch_add(1, Ordering::SeqCst)
            } else {
                self.media_seq.fetch_add(1, Ordering::SeqCst)
            }
        } else {
            0
        };
        
        let now = Instant::now();
        let task = SendTask {
            message,
            conversation_id,
            lane,
            seq,
            enqueue_at: now,
            deadline: now + self.config.send_timeout,
            ordered,
            media_size,
            result_tx: tx,
        };
        
        // 提交到队列（带重试）
        for _ in 0..100 {
            if self.queue.send(task).is_ok() {
                break;
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        
        // 等待结果（带超时）
        match tokio::time::timeout(self.config.send_timeout, rx).await {
            Ok(Ok(result)) => result,
            Ok(Err(_)) => Err(SdkError::MessageSendFailed { 
                message: "发送通道关闭".into() 
            }),
            Err(_) => Err(SdkError::Timeout { 
                message: "发送超时".into() 
            }),
        }
    }
    
    /// Worker 循环
    async fn worker_loop(
        mut rx: mpsc::UnboundedReceiver<SendTask>,
        estimator: Arc<ThresholdEstimator>,
        cancel: CancellationToken,
    ) {
        loop {
            tokio::select! {
                _ = cancel.cancelled() => {
                    info!("[MessageSender] Worker 收到取消信号，退出");
                    break;
                }
                Some(task) = rx.recv() => {
                    Self::process_task(task, &estimator).await;
                }
            }
        }
    }
    
    /// 处理单个任务
    async fn process_task(task: SendTask, estimator: &ThresholdEstimator) {
        // 检查是否超时
        if Instant::now() > task.deadline {
            let _ = task.result_tx.send(Err(SdkError::Timeout {
                message: "任务超时".into(),
            }));
            return;
        }
        
        let start = Instant::now();
        let result = Self::execute_send(&task).await;
        let elapsed = start.elapsed();
        
        // 更新阈值估计器
        if task.lane == SendLane::Media && task.media_size > 0 && result.is_ok() {
            estimator.update(task.media_size as u64, elapsed);
        }
        
        let _ = task.result_tx.send(result);
    }
    
    /// 执行发送
    async fn execute_send(task: &SendTask) -> Result<MsgStruct> {
        // 1. 媒体消息先上传
        let mut message = task.message.clone();
        if is_media_content_type(message.content_type) {
            message = upload_media_and_update(&message).await?;
        }
        
        // 2. 通过 WebSocket 发送
        // ... 调用 connection.send_request
        
        // 3. 保存到本地数据库
        // ... repository.message.insert
        
        Ok(message)
    }
}
```

---

### 7.2 消息同步器详细设计

#### 7.2.1 Go SDK 实现分析

Go SDK 的消息同步核心流程：
1. **LoadSeq**: 从本地数据库加载各会话最大 seq
2. **Connected**: 连接成功后触发首次同步
3. **PullMessageBySeqs**: 按 seq 拉取缺失消息
4. **DoMsgNew**: 处理新消息，插入数据库，触发回调

```go
// Go 实现核心结构
type MsgSyncer struct {
    loginUserID            string
    longConnMgr            *LongConnMgr
    PushMsgAndMaxSeqCh     chan common.Cmd2Value
    conversationEventQueue chan common.Cmd2Value
    syncedMaxSeqs          map[string]int64
    db                     db_interface.DataBase
    reinstalled            bool
    isSyncing              bool
}
```

#### 7.2.2 Rust 实现设计

```rust
// core/message/syncer.rs

/// 消息同步器配置
pub struct SyncerConfig {
    /// 首次连接拉取数量
    pub connect_pull_nums: i64,
    /// 默认拉取数量
    pub default_pull_nums: i64,
    /// 分批拉取大小
    pub split_pull_msg_num: i64,
    /// 并发拉取协程数
    pub pull_goroutine_limit: usize,
}

impl Default for SyncerConfig {
    fn default() -> Self {
        Self {
            connect_pull_nums: 1,
            default_pull_nums: 10,
            split_pull_msg_num: 100,
            pull_goroutine_limit: 10,
        }
    }
}

/// 消息同步器
pub struct MessageSyncer {
    config: SyncerConfig,
    /// 登录用户 ID
    login_user_id: String,
    /// 是否重装
    reinstalled: bool,
    /// 是否正在同步
    is_syncing: bool,
    /// 已同步的最大 seq
    synced_max_seqs: HashMap<String, i64>,
    /// 数据库
    repository: Repository,
    /// 连接管理器
    connection: Arc<dyn ConnectionManager>,
    /// 事件总线
    event_bus: EventBus,
    /// 命令通道
    cmd_rx: mpsc::UnboundedReceiver<SyncCommand>,
    /// 取消令牌
    cancel_token: CancellationToken,
}

/// 同步命令
#[derive(Debug)]
pub enum SyncCommand {
    /// 连接成功
    Connected,
    /// App 唤醒
    Wakeup,
    /// 手动同步指定会话
    ManualSync(Vec<String>),
    /// 推送消息
    PushMessages(sdkws::PushMessages),
}

impl MessageSyncer {
    pub fn new(
        config: SyncerConfig,
        login_user_id: String,
        repository: Repository,
        connection: Arc<dyn ConnectionManager>,
        event_bus: EventBus,
        cancel_token: CancellationToken,
    ) -> (Self, mpsc::UnboundedSender<SyncCommand>) {
        let (cmd_tx, cmd_rx) = mpsc::unbounded_channel();
        
        let syncer = Self {
            config,
            login_user_id,
            reinstalled: false,
            is_syncing: false,
            synced_max_seqs: HashMap::new(),
            repository,
            connection,
            event_bus,
            cmd_rx,
            cancel_token,
        };
        
        (syncer, cmd_tx)
    }
    
    /// 从本地数据库加载 seq
    pub async fn load_seq(&mut self) -> Result<()> {
        // 1. 获取所有会话 ID
        let conversation_ids = self.repository.conversation.get_all_conversation_ids().await?;
        
        if conversation_ids.is_empty() {
            // 无会话，检查是否重装
            let version = self.repository.app_version.get_app_sdk_version().await?;
            self.reinstalled = version.as_ref().map_or(true, |v| !v.installed);
            debug!("[MessageSyncer] 无本地会话，reinstalled={}", self.reinstalled);
            return Ok(());
        }
        
        // 2. 并发读取各会话最大 seq
        let chunk_size = 20;
        let chunks = conversation_ids.chunks(chunk_size);
        
        let mut futures = Vec::new();
        for chunk in chunks {
            let repo = self.repository.clone();
            let chunk = chunk.to_vec();
            futures.push(async move {
                let mut result = HashMap::new();
                for conv_id in chunk {
                    let max_seq = repo.message.check_conversation_normal_msg_seq(&conv_id).await.unwrap_or(0);
                    result.insert(conv_id, max_seq);
                }
                result
            });
        }
        
        // 并发执行
        let results = futures::future::join_all(futures).await;
        for result in results {
            self.synced_max_seqs.extend(result);
        }
        
        // 3. 读取通知类 seq
        if let Ok(notification_seqs) = self.repository.notification_dao.get_notification_all_seqs().await {
            for item in notification_seqs {
                self.synced_max_seqs.insert(item.conversation_id, item.seq);
            }
        }
        
        debug!("[MessageSyncer] load_seq done, synced_max_seqs size={}", self.synced_max_seqs.len());
        Ok(())
    }
    
    /// 主循环
    pub async fn run(mut self) -> Result<()> {
        loop {
            tokio::select! {
                _ = self.cancel_token.cancelled() => {
                    info!("[MessageSyncer] 收到取消信号，退出");
                    break;
                }
                Some(cmd) = self.cmd_rx.recv() => {
                    if let Err(e) = self.handle_command(cmd).await {
                        error!("[MessageSyncer] 处理命令失败: {}", e);
                    }
                }
            }
        }
        Ok(())
    }
    
    /// 处理命令
    async fn handle_command(&mut self, cmd: SyncCommand) -> Result<()> {
        match cmd {
            SyncCommand::Connected => {
                info!("[MessageSyncer] 连接成功，开始同步");
                self.sync_all_messages().await?;
            }
            SyncCommand::Wakeup => {
                debug!("[MessageSyncer] App 唤醒，触发同步");
                self.sync_all_messages().await?;
            }
            SyncCommand::ManualSync(conversation_ids) => {
                debug!("[MessageSyncer] 手动同步: {:?}", conversation_ids);
                for conv_id in conversation_ids {
                    self.sync_conversation_messages(&conv_id).await?;
                }
            }
            SyncCommand::PushMessages(push) => {
                debug!("[MessageSyncer] 收到推送消息");
                self.handle_push_messages(push).await?;
            }
        }
        Ok(())
    }
    
    /// 同步所有消息
    async fn sync_all_messages(&mut self) -> Result<()> {
        if self.is_syncing {
            debug!("[MessageSyncer] 正在同步中，跳过");
            return Ok(());
        }
        
        self.is_syncing = true;
        self.event_bus.publish(SdkEvent::SyncStart);
        
        // 通知同步开始
        self.event_bus.publish(SdkEvent::SyncFlag { flag: 1001 }); // MsgSyncBegin
        
        let result = self.do_sync_all_messages().await;
        
        self.is_syncing = false;
        
        match &result {
            Ok(_) => {
                self.event_bus.publish(SdkEvent::SyncFlag { flag: 1003 }); // MsgSyncEnd
                self.event_bus.publish(SdkEvent::SyncComplete);
            }
            Err(e) => {
                self.event_bus.publish(SdkEvent::SyncFlag { flag: 1004 }); // MsgSyncFailed
                self.event_bus.publish(SdkEvent::SyncFailed { error: e.clone() });
            }
        }
        
        result
    }
    
    /// 执行同步
    async fn do_sync_all_messages(&mut self) -> Result<()> {
        // 1. 获取服务端最大 seq
        let req = msg::GetConversationsHasReadAndMaxSeqReq {
            user_id: self.login_user_id.clone(),
        };
        let resp: msg::GetConversationsHasReadAndMaxSeqResp = self.connection
            .send_request(constant::GET_CONV_MAX_READ_SEQ, &req)
            .await?;
        
        // 2. 计算差值，拉取缺失消息
        let mut pull_tasks = Vec::new();
        for (conv_id, seq_info) in resp.seqs {
            let local_max_seq = self.synced_max_seqs.get(&conv_id).copied().unwrap_or(0);
            let server_max_seq = seq_info.max_seq;
            
            if server_max_seq > local_max_seq {
                pull_tasks.push((conv_id, local_max_seq, server_max_seq));
            }
        }
        
        // 3. 并发拉取（限制并发数）
        let semaphore = Arc::new(Semaphore::new(self.config.pull_goroutine_limit));
        let mut futures = Vec::new();
        
        for (conv_id, start_seq, end_seq) in pull_tasks {
            let permit = semaphore.clone().acquire_owned().await?;
            let connection = self.connection.clone();
            let repository = self.repository.clone();
            
            futures.push(async move {
                let _permit = permit;
                Self::pull_conversation_messages(
                    &connection,
                    &repository,
                    &conv_id,
                    start_seq,
                    end_seq,
                ).await
            });
        }
        
        let results = futures::future::join_all(futures).await;
        for result in results {
            result?;
        }
        
        Ok(())
    }
    
    /// 拉取会话消息
    async fn pull_conversation_messages(
        connection: &Arc<dyn ConnectionManager>,
        repository: &Repository,
        conversation_id: &str,
        start_seq: i64,
        end_seq: i64,
    ) -> Result<()> {
        let mut current_seq = start_seq;
        
        while current_seq < end_seq {
            let batch_end = std::cmp::min(current_seq + 100, end_seq);
            
            let req = msg::PullMessageBySeqsReq {
                conversation_id: conversation_id.to_string(),
                seqs: (current_seq..batch_end).collect(),
            };
            
            let resp: msg::PullMessageBySeqsResp = connection
                .send_request(constant::PULL_MSG_BY_SEQ_LIST, &req)
                .await?;
            
            // 去重并插入
            let mut messages = Vec::new();
            for msg in resp.messages {
                let exists = repository.message
                    .get_message_by_client_msg_id(&msg.client_msg_id)
                    .await
                    .is_ok();
                if !exists {
                    messages.push(msg);
                }
            }
            
            if !messages.is_empty() {
                repository.message.insert_messages(&messages).await?;
            }
            
            current_seq = batch_end;
        }
        
        Ok(())
    }
}
```

---

### 7.3 会话同步器详细设计

#### 7.3.1 Go SDK 实现分析

Go SDK 使用 `VersionSynchronizer` 泛型同步器：
- **增量同步**: 基于版本号，只同步变更
- **全量同步**: 首次或版本号不匹配时全量同步
- **版本控制**: 本地保存版本号，下次增量同步使用

```go
// Go 增量同步实现
func (c *Conversation) IncrSyncConversations(ctx context.Context) error {
    conversationSyncer := syncer.VersionSynchronizer[...] {
        Local: func() ([]*model_struct.LocalConversation, error) { ... },
        Server: func(version *model_struct.LocalVersionSync) (...) { ... },
        Full: func(resp ...) bool { return resp.Full },
        Version: func(resp ...) (string, uint64) { ... },
        Delete: func(resp ...) []string { ... },
        Update: func(resp ...) []*model_struct.LocalConversation { ... },
        Insert: func(resp ...) []*model_struct.LocalConversation { ... },
        Syncer: func(server, local ...) error { ... },
        FullSyncer: func(ctx context.Context) error { ... },
        FullID: func(ctx context.Context) ([]string, error) { ... },
    }
    return conversationSyncer.IncrementalSync()
}
```

#### 7.3.2 Rust 实现设计

```rust
// core/conversation/syncer.rs

/// 会话同步器
pub struct ConversationSyncer {
    /// 登录用户 ID
    login_user_id: String,
    /// 数据库
    repository: Repository,
    /// 连接管理器
    connection: Arc<dyn ConnectionManager>,
    /// 事件总线
    event_bus: EventBus,
    /// 同步互斥锁
    sync_mutex: Mutex<()>,
    /// 取消令牌
    cancel_token: CancellationToken,
}

impl ConversationSyncer {
    pub fn new(
        login_user_id: String,
        repository: Repository,
        connection: Arc<dyn ConnectionManager>,
        event_bus: EventBus,
        cancel_token: CancellationToken,
    ) -> Self {
        Self {
            login_user_id,
            repository,
            connection,
            event_bus,
            sync_mutex: Mutex::new(()),
            cancel_token,
        }
    }
    
    /// 增量同步会话
    pub async fn incremental_sync(&self) -> Result<()> {
        let _guard = self.sync_mutex.lock().await;
        
        info!("[ConversationSyncer] 开始增量同步");
        self.event_bus.publish(SdkEvent::SyncServerStart { reinstalled: false });
        
        let result = self.do_incremental_sync().await;
        
        match &result {
            Ok(_) => {
                self.event_bus.publish(SdkEvent::SyncServerFinish { reinstalled: false });
            }
            Err(e) => {
                self.event_bus.publish(SdkEvent::SyncServerFailed { 
                    reinstalled: false, 
                    error: e.clone() 
                });
            }
        }
        
        result
    }
    
    /// 执行增量同步
    async fn do_incremental_sync(&self) -> Result<()> {
        // 1. 获取本地版本号
        let version = self.repository.version_sync
            .get_version(&self.login_user_id, "conversation")
            .await?;
        
        // 2. 请求增量数据
        let req = pbConversation::GetIncrementalConversationReq {
            user_id: self.login_user_id.clone(),
            version: version.as_ref().map_or(0, |v| v.version),
            version_id: version.as_ref().map_or(String::new(), |v| v.version_id.clone()),
        };
        
        let resp: pbConversation::GetIncrementalConversationResp = self.connection
            .send_request(constant::GET_INCREMENTAL_CONVERSATION, &req)
            .await?;
        
        // 3. 检查是否需要全量同步
        if resp.full {
            return self.full_sync().await;
        }
        
        // 4. 处理删除
        if !resp.delete.is_empty() {
            self.repository.conversation.delete_conversations(&resp.delete).await?;
            self.event_bus.publish(SdkEvent::ConversationDeleted { 
                conversation_ids: resp.delete.clone() 
            });
        }
        
        // 5. 处理更新
        if !resp.update.is_empty() {
            let conversations: Vec<LocalConversation> = resp.update
                .into_iter()
                .map(server_conversation_to_local)
                .collect();
            self.repository.conversation.upsert_conversations(&conversations).await?;
            self.event_bus.publish(SdkEvent::ConversationChanged { 
                conversations: conversations.clone() 
            });
        }
        
        // 6. 处理插入
        if !resp.insert.is_empty() {
            let conversations: Vec<LocalConversation> = resp.insert
                .into_iter()
                .map(server_conversation_to_local)
                .collect();
            self.repository.conversation.insert_conversations(&conversations).await?;
            self.event_bus.publish(SdkEvent::NewConversation { 
                conversations: conversations.clone() 
            });
        }
        
        // 7. 更新版本号
        self.repository.version_sync.update_version(
            &self.login_user_id,
            "conversation",
            &resp.version_id,
            resp.version,
        ).await?;
        
        Ok(())
    }
    
    /// 全量同步
    async fn full_sync(&self) -> Result<()> {
        info!("[ConversationSyncer] 开始全量同步");
        
        // 1. 获取服务端所有会话
        let req = pbConversation::GetOwnerConversationReq {
            user_id: self.login_user_id.clone(),
            offset: 0,
            count: 500,
        };
        
        let mut all_conversations = Vec::new();
        let mut offset = 0;
        
        loop {
            let resp: pbConversation::GetOwnerConversationResp = self.connection
                .send_request(constant::GET_OWNER_CONVERSATION, &req)
                .await?;
            
            let conversations: Vec<LocalConversation> = resp.conversations
                .into_iter()
                .map(server_conversation_to_local)
                .collect();
            
            all_conversations.extend(conversations);
            
            if !resp.has_next_page {
                break;
            }
            offset += 500;
        }
        
        // 2. 获取本地会话
        let local_conversations = self.repository.conversation.get_all_conversations().await?;
        
        // 3. 同步（插入/更新/删除）
        self.sync_conversations(all_conversations, local_conversations).await?;
        
        Ok(())
    }
    
    /// 同步会话列表
    async fn sync_conversations(
        &self,
        server: Vec<LocalConversation>,
        local: Vec<LocalConversation>,
    ) -> Result<()> {
        let local_map: HashMap<String, LocalConversation> = local
            .into_iter()
            .map(|c| (c.conversation_id.clone(), c))
            .collect();
        
        let server_ids: HashSet<String> = server.iter()
            .map(|c| c.conversation_id.clone())
            .collect();
        
        // 插入新会话
        let to_insert: Vec<LocalConversation> = server.iter()
            .filter(|c| !local_map.contains_key(&c.conversation_id))
            .cloned()
            .collect();
        
        if !to_insert.is_empty() {
            self.repository.conversation.insert_conversations(&to_insert).await?;
            self.event_bus.publish(SdkEvent::NewConversation { 
                conversations: to_insert 
            });
        }
        
        // 更新已有会话
        let to_update: Vec<LocalConversation> = server.into_iter()
            .filter(|c| {
                if let Some(local) = local_map.get(&c.conversation_id) {
                    c.updated_at > local.updated_at
                } else {
                    false
                }
            })
            .collect();
        
        if !to_update.is_empty() {
            self.repository.conversation.upsert_conversations(&to_update).await?;
            self.event_bus.publish(SdkEvent::ConversationChanged { 
                conversations: to_update 
            });
        }
        
        // 删除本地多余会话
        let to_delete: Vec<String> = local_map.keys()
            .filter(|id| !server_ids.contains(*id))
            .cloned()
            .collect();
        
        if !to_delete.is_empty() {
            self.repository.conversation.delete_conversations(&to_delete).await?;
            self.event_bus.publish(SdkEvent::ConversationDeleted { 
                conversation_ids: to_delete 
            });
        }
        
        Ok(())
    }
}
```

---

### 7.4 连接管理器详细设计

#### 7.4.1 Go SDK 实现分析

Go SDK 的 `LongConnMgr` 核心特性：
- **读写分离**: `readPump` 和 `writePump` 独立 goroutine
- **心跳机制**: 定时发送 ping，检测 pong
- **重连策略**: 指数退避，最多 300 次
- **RPC 等待**: `SendReqWaitResp` 发送请求并等待响应
- **消息批处理**: `MessageBatcher` 批量发送

```go
// Go 连接管理器核心结构
type LongConnMgr struct {
    connStatus int
    conn       LongConn
    send       chan Message
    pushMsgAndMaxSeqCh chan common.Cmd2Value
    conversationCh     chan common.Cmd2Value
    loginMgrCh         chan common.Cmd2Value
    Syncer             *WsRespAsyn
    reconnectStrategy  ReconnectStrategy
    sub                *subscription
    mb                 *MessageBatcher
}
```

#### 7.4.2 Rust 实现设计

```rust
// core/connection/manager.rs

/// 连接状态
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConnectionStatus {
    Disconnected,
    Connecting,
    Connected,
    Closed,
}

/// 连接管理器配置
pub struct ConnectionConfig {
    /// WebSocket URL
    pub ws_url: String,
    /// 用户 ID
    pub user_id: String,
    /// Token
    pub token: String,
    /// 平台 ID
    pub platform_id: i32,
    /// 心跳间隔
    pub ping_interval: Duration,
    /// Pong 超时
    pub pong_timeout: Duration,
    /// 写超时
    pub write_timeout: Duration,
    /// 最大消息大小
    pub max_message_size: usize,
    /// 最大重连次数
    pub max_reconnect_attempts: u32,
}

/// 连接管理器
pub struct ConnectionManagerImpl {
    config: ConnectionConfig,
    /// 连接状态
    status: AtomicU8,
    /// WebSocket 写入端
    ws_writer: Arc<Mutex<Option<WsWriter>>>,
    /// 待处理 RPC
    pending_rpc: Arc<RwLock<HashMap<String, oneshot::Sender<Result<Vec<u8>>>>>>,
    /// 发送通道
    send_tx: mpsc::UnboundedSender<RpcMessage>,
    /// 事件总线
    event_bus: EventBus,
    /// 重连策略
    reconnect_strategy: ExponentialBackoff,
    /// 取消令牌
    cancel_token: CancellationToken,
}

/// RPC 消息
struct RpcMessage {
    /// 请求标识
    req_identifier: i32,
    /// 请求数据
    data: Vec<u8>,
    /// 操作 ID
    operation_id: String,
    /// 响应通道
    response_tx: oneshot::Sender<Result<Vec<u8>>>,
}

impl ConnectionManagerImpl {
    pub async fn new(
        config: ConnectionConfig,
        event_bus: EventBus,
        cancel_token: CancellationToken,
    ) -> Result<Self> {
        let (send_tx, send_rx) = mpsc::unbounded_channel();
        
        let manager = Self {
            config,
            status: AtomicU8::new(ConnectionStatus::Disconnected as u8),
            ws_writer: Arc::new(Mutex::new(None)),
            pending_rpc: Arc::new(RwLock::new(HashMap::new())),
            send_tx,
            event_bus,
            reconnect_strategy: ExponentialBackoff::new(),
            cancel_token,
        };
        
        Ok(manager)
    }
    
    /// 启动连接
    pub async fn start(&self) -> Result<()> {
        self.event_bus.publish(SdkEvent::Connecting);
        self.set_status(ConnectionStatus::Connecting);
        
        self.auto_connect().await?;
        
        Ok(())
    }
    
    /// 自动连接（带重连）
    async fn auto_connect(&self) -> Result<()> {
        let mut reconnect_count = 0;
        
        loop {
            match self.do_connect().await {
                Ok(()) => {
                    reconnect_count = 0;
                    self.reconnect_strategy.reset();
                    break;
                }
                Err(e) => {
                    if e.is_fatal() {
                        // 鉴权失败等致命错误，不重连
                        error!("[ConnectionManager] 致命错误，不重连: {}", e);
                        self.event_bus.publish(SdkEvent::ConnectFailed { error: e });
                        return Err(e);
                    }
                    
                    reconnect_count += 1;
                    if reconnect_count >= self.config.max_reconnect_attempts {
                        error!("[ConnectionManager] 达到最大重连次数");
                        self.event_bus.publish(SdkEvent::ConnectFailed { error: e });
                        return Err(e);
                    }
                    
                    let wait = self.reconnect_strategy.next_interval();
                    warn!("[ConnectionManager] 连接失败，{:?} 后重连 ({}/{})", 
                          wait, reconnect_count, self.config.max_reconnect_attempts);
                    tokio::time::sleep(wait).await;
                }
            }
        }
        
        Ok(())
    }
    
    /// 执行连接
    async fn do_connect(&self) -> Result<()> {
        let url = self.build_ws_url();
        debug!("[ConnectionManager] 连接 WebSocket: {}", url);
        
        let (ws_stream, response) = connect_async(&url).await
            .map_err(|e| SdkError::ConnectionError { 
                message: format!("WebSocket 连接失败: {}", e) 
            })?;
        
        let (ws_writer, ws_reader) = ws_stream.split();
        
        *self.ws_writer.lock().await = Some(ws_writer);
        self.set_status(ConnectionStatus::Connected);
        self.event_bus.publish(SdkEvent::Connected);
        
        // 启动读写循环
        let cancel = self.cancel_token.clone();
        let event_bus = self.event_bus.clone();
        let pending_rpc = self.pending_rpc.clone();
        
        tokio::spawn(async move {
            let read_fut = Self::read_loop(ws_reader, event_bus.clone(), pending_rpc.clone());
            let write_fut = Self::write_loop(cancel, event_bus.clone());
            
            // 任一退出则连接断开
            tokio::select! {
                result = read_fut => debug!("[ConnectionManager] 读取循环退出: {:?}", result),
                result = write_fut => debug!("[ConnectionManager] 写入循环退出: {:?}", result),
            }
        });
        
        Ok(())
    }
    
    /// 读取循环
    async fn read_loop(
        mut reader: WsReader,
        event_bus: EventBus,
        pending_rpc: Arc<RwLock<HashMap<String, oneshot::Sender<Result<Vec<u8>>>>>>,
    ) {
        while let Some(Ok(msg)) = reader.next().await {
            match msg {
                WsMessage::Binary(data) => {
                    // 解析消息
                    match Self::parse_message(&data) {
                        Ok((operation_id, resp_data)) => {
                            // 查找待处理的 RPC
                            let mut rpcs = pending_rpc.write().await;
                            if let Some(tx) = rpcs.remove(&operation_id) {
                                let _ = tx.send(Ok(resp_data));
                            }
                        }
                        Err(e) => {
                            error!("[ConnectionManager] 解析消息失败: {}", e);
                        }
                    }
                }
                WsMessage::Ping(_) => {
                    // 自动回复 Pong（tungstenite 自动处理）
                }
                WsMessage::Close(frame) => {
                    info!("[ConnectionManager] 连接关闭: {:?}", frame);
                    event_bus.publish(SdkEvent::Disconnected { 
                        reason: "服务器关闭连接".into() 
                    });
                    break;
                }
                _ => {}
            }
        }
    }
    
    /// 写入循环
    async fn write_loop(
        cancel: CancellationToken,
        event_bus: EventBus,
    ) {
        // 心跳循环
        let mut interval = tokio::time::interval(Duration::from_secs(30));
        
        loop {
            tokio::select! {
                _ = cancel.cancelled() => {
                    info!("[ConnectionManager] 写入循环收到取消信号");
                    break;
                }
                _ = interval.tick() => {
                    // 发送心跳
                    debug!("[ConnectionManager] 发送心跳");
                    // ... 发送 ping
                }
            }
        }
    }
    
    /// 发送请求并等待响应
    pub async fn send_request<T: ProtobufMessage, R: ProtobufMessage>(
        &self,
        req_identifier: i32,
        data: &T,
    ) -> Result<R> {
        let operation_id = util::make_operation_id();
        let data_bytes = data.encode_to_vec();
        
        let (response_tx, response_rx) = oneshot::channel();
        
        // 注册待处理 RPC
        {
            let mut rpcs = self.pending_rpc.write().await;
            rpcs.insert(operation_id.clone(), response_tx);
        }
        
        // 发送消息
        let msg = RpcMessage {
            req_identifier,
            data: data_bytes,
            operation_id: operation_id.clone(),
            response_tx,
        };
        
        self.send_tx.send(msg).map_err(|e| SdkError::ConnectionError {
            message: format!("发送失败: {}", e),
        })?;
        
        // 等待响应（带超时）
        match tokio::time::timeout(Duration::from_secs(10), response_rx).await {
            Ok(Ok(Ok(resp_data))) => {
                let resp = R::decode(&resp_data[..])
                    .map_err(|e| SdkError::Unknown { 
                        message: format!("解析响应失败: {}", e) 
                    })?;
                Ok(resp)
            }
            Ok(Ok(Err(e))) => Err(e),
            Ok(Err(_)) => Err(SdkError::ConnectionError {
                message: "响应通道关闭".into(),
            }),
            Err(_) => {
                // 清理待处理 RPC
                let mut rpcs = self.pending_rpc.write().await;
                rpcs.remove(&operation_id);
                Err(SdkError::Timeout {
                    message: "等待响应超时".into(),
                })
            }
        }
    }
    
    /// 构建 WebSocket URL
    fn build_ws_url(&self) -> String {
        format!(
            "{}/?token={}&sendID={}&platformID={}&operationID={}&isBackground=false&isMsgResp=true&sdkType=rust",
            self.config.ws_url,
            self.config.token,
            self.config.user_id,
            self.config.platform_id,
            util::make_operation_id(),
        )
    }
    
    /// 设置连接状态
    fn set_status(&self, status: ConnectionStatus) {
        self.status.store(status as u8, Ordering::SeqCst);
    }
    
    /// 获取连接状态
    pub fn status(&self) -> ConnectionStatus {
        match self.status.load(Ordering::SeqCst) {
            0 => ConnectionStatus::Disconnected,
            1 => ConnectionStatus::Connecting,
            2 => ConnectionStatus::Connected,
            _ => ConnectionStatus::Closed,
        }
    }
}
```

---

### 7.5 FFI 桥接层更新设计

#### 7.5.1 当前问题

当前 FFI 层直接调用 `IMClient` 的方法，耦合度高：

```rust
// 当前实现
#[flutter_rust_bridge::frb]
pub async fn send_message(message: String) -> Result<String> {
    let client = get_current_client().await?;
    let result = client.read().await.send_message(message).await?;
    Ok(serde_json::to_string(&result)?)
}
```

#### 7.5.2 新设计

```rust
// api/bridge_client.rs

/// 发送消息
#[flutter_rust_bridge::frb]
pub async fn send_message(message: MsgStructBridge) -> Result<MsgStructBridge> {
    let client = get_sdk_client().await?;
    let message = message.to_msg_struct();
    let result = client.message().send_message(message).await?;
    Ok(MsgStructBridge::from(result))
}

/// 获取历史消息
#[flutter_rust_bridge::frb]
pub async fn get_history_messages(
    conversation_id: String,
    params: GetHistoryMessagesParamsBridge,
) -> Result<GetHistoryMessagesCallbackBridge> {
    let client = get_sdk_client().await?;
    let params = params.to_params();
    let result = client.message().get_history_messages(conversation_id, params).await?;
    Ok(GetHistoryMessagesCallbackBridge::from(result))
}

/// 订阅事件
#[flutter_rust_bridge::frb]
pub async fn subscribe_events(sink: StreamSink<SdkEventBridge>) -> Result<()> {
    let client = get_sdk_client().await?;
    let mut subscription = client.subscribe_events();
    
    tokio::spawn(async move {
        while let Some(event) = subscription.next().await {
            let bridge_event = SdkEventBridge::from(event);
            if sink.add(bridge_event).is_err() {
                break;
            }
        }
    });
    
    Ok(())
}

/// 获取 SDK 客户端（单例）
async fn get_sdk_client() -> Result<Arc<OpenIMClient>> {
    // 从全局状态获取
    SDK_CLIENT.read().await.clone().ok_or_else(|| {
        anyhow!("SDK 未初始化，请先调用 init_sdk")
    })
}
```

---

## 八、迁移策略详细设计

### 8.1 渐进式迁移

采用**绞杀者模式**（Strangler Pattern），逐步替换旧代码：

```
Phase 1: 并行运行
├── 新架构代码放在新目录
├── 旧代码保持不变
└── FFI 层可以选择调用新或旧

Phase 2: 逐步切换
├── 先迁移独立模块（事件总线、错误类型）
├── 再迁移核心模块（连接、消息）
└── 最后迁移业务模块（会话、用户、好友）

Phase 3: 清理旧代码
├── 删除旧代码
├── 更新 FFI 层
└── 重构测试
```

### 8.2 兼容性保证

```rust
// 过渡期：同时支持新旧接口
pub enum ClientVersion {
    Legacy(IMClient),
    New(OpenIMClient),
}

impl ClientVersion {
    pub async fn send_message(&self, message: MsgStruct) -> Result<MsgStruct> {
        match self {
            ClientVersion::Legacy(client) => client.send_message(message).await,
            ClientVersion::New(client) => client.message().send_message(message).await,
        }
    }
}
```

### 8.3 测试策略

```rust
// 单元测试示例
#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_message_sender_order() {
        let config = SenderConfig::default();
        let cancel = CancellationToken::new();
        let sender = MessageSender::new(config, cancel);
        
        // 发送 10 条消息
        let mut futures = Vec::new();
        for i in 0..10 {
            let msg = create_test_message(i);
            futures.push(sender.submit(msg, "conv_1".into()));
        }
        
        let results = futures::future::join_all(futures).await;
        
        // 验证有序
        for (i, result) in results.iter().enumerate() {
            assert!(result.is_ok());
            assert_eq!(result.as_ref().unwrap().seq, i as i64 + 1);
        }
    }
    
    #[tokio::test]
    async fn test_event_bus() {
        let bus = EventBus::new();
        
        // 订阅事件
        let mut sub1 = bus.subscribe();
        let mut sub2 = bus.subscribe();
        
        // 发布事件
        bus.publish(SdkEvent::Connected);
        
        // 验证接收
        assert!(matches!(sub1.next().await, Some(SdkEvent::Connected)));
        assert!(matches!(sub2.next().await, Some(SdkEvent::Connected)));
    }
}
```

---

## 九、性能优化设计

### 9.1 数据库优化

```rust
// 批量插入优化
impl MessageRepo {
    pub async fn insert_messages(&self, messages: &[MsgStruct]) -> Result<()> {
        let mut tx = self.pool.begin().await?;
        
        // 使用批量插入
        for chunk in messages.chunks(100) {
            let mut query_builder = QueryBuilder::new(
                "INSERT OR IGNORE INTO local_chat_logs 
                 (client_msg_id, server_msg_id, conversation_id, ...)"
            );
            
            for msg in chunk {
                query_builder.push_values(|b| {
                    b.push_bind(&msg.client_msg_id)
                     .push_bind(&msg.server_msg_id)
                     .push_bind(&msg.conversation_id)
                     // ...
                });
            }
            
            query_builder.build().execute(&mut *tx).await?;
        }
        
        tx.commit().await?;
        Ok(())
    }
}
```

### 9.2 缓存优化

```rust
// 多级缓存
pub struct CacheManager {
    /// L1: 内存缓存（快速访问）
    l1_cache: Arc<RwLock<LruCache<String, UserInfo>>>,
    /// L2: 数据库缓存（持久化）
    repository: Repository,
}

impl CacheManager {
    pub async fn get_user_info(&self, user_id: &str) -> Option<UserInfo> {
        // L1 缓存
        if let Some(info) = self.l1_cache.read().await.get(user_id) {
            return Some(info.clone());
        }
        
        // L2 缓存（数据库）
        if let Ok(info) = self.repository.user.get_user(user_id).await {
            self.l1_cache.write().await.put(user_id.to_string(), info.clone());
            return Some(info);
        }
        
        None
    }
    
    pub async fn set_user_info(&self, user_id: String, info: UserInfo) {
        // 更新 L1
        self.l1_cache.write().await.put(user_id.clone(), info.clone());
        
        // 更新 L2
        let _ = self.repository.user.upsert_user(&info).await;
    }
}
```

### 9.3 并发优化

```rust
// 使用 Semaphore 限制并发
pub struct ConcurrentLimiter {
    semaphore: Arc<Semaphore>,
}

impl ConcurrentLimiter {
    pub async fn with_limit<F, T>(&self, f: F) -> Result<T>
    where
        F: Future<Output = Result<T>>,
    {
        let permit = self.semaphore.acquire().await?;
        let result = f.await;
        drop(permit);
        result
    }
}

// 使用示例
let limiter = ConcurrentLimiter::new(10); // 最多 10 个并发
let result = limiter.with_limit(async {
    // 并发操作
    pull_messages().await
}).await?;
```

---

## 十二、服务端 API 兼容性保证

### 12.1 兼容性挑战分析

Rust SDK 需要与 OpenIM 服务端保持完全兼容，主要挑战包括：

1. **Protobuf 协议版本**：服务端使用 `github.com/openimsdk/protocol` 定义消息格式
2. **WebSocket 消息格式**：请求/响应使用 `OpenIMReq`/`OpenIMResp` 信封格式
3. **HTTP API 路由**：会话同步、用户信息等通过 HTTP API 获取
4. **常量定义**：消息类型、会话类型、群组角色等常量必须与服务端一致
5. **错误码**：服务端返回的错误码需要正确解析和处理

### 12.2 Protobuf 版本管理策略

#### 12.2.1 Go SDK 使用的协议版本

```go
// go.mod
github.com/openimsdk/protocol v0.0.73-alpha.12
```

核心协议模块：
- `github.com/openimsdk/protocol/sdkws` - WebSocket 消息定义
- `github.com/openimsdk/protocol/msg` - 消息相关 API
- `github.com/openimsdk/protocol/conversation` - 会话相关 API
- `github.com/openimsdk/protocol/group` - 群组相关 API
- `github.com/openimsdk/protocol/relation` - 好友关系 API
- `github.com/openimsdk/protocol/auth` - 认证 API
- `github.com/openimsdk/protocol/wrapperspb` - 包装类型

#### 12.2.2 Rust Protobuf 绑定策略

```rust
// rust/Cargo.toml
[dependencies]
# 使用 prost 作为 Protobuf 运行时
prost = "0.12"
prost-types = "0.12"

# 方案 1: 从 .proto 文件自动生成（推荐）
# build.rs 中配置 protoc 编译
# protoc --prost_out=src/protocol -I=../openim-protocol/proto src/protocol/*.proto

# 方案 2: 手动维护绑定（不推荐，维护成本高）
```

**推荐方案：自动化生成**

```rust
// rust/build.rs
use std::process::Command;

fn main() {
    // 1. 从 openim-protocol 仓库拉取最新 proto 文件
    let proto_dir = "proto/openim-protocol";
    
    // 2. 生成 Rust 绑定
    let proto_files = vec![
        "proto/sdkws/sdkws.proto",
        "proto/msg/msg.proto",
        "proto/conversation/conversation.proto",
        "proto/group/group.proto",
        "proto/relation/relation.proto",
        "proto/auth/auth.proto",
    ];
    
    prost_build::Config::new()
        .out_dir("src/protocol/generated")
        .compile_protos(&proto_files, &[proto_dir])
        .expect("Failed to compile protos");
    
    // 3. 输出版本信息
    println!("cargo:rerun-if-changed=proto/");
}
```

#### 12.2.3 版本锁定与更新策略

```rust
// rust/src/protocol/mod.rs

/// 协议版本信息
pub const PROTOCOL_VERSION: &str = "v0.0.73-alpha.12";
pub const PROTOCOL_COMMIT: &str = "abc123def"; // Git commit hash

/// 版本检查（启动时验证）
pub fn check_protocol_version() -> Result<()> {
    // 1. 检查本地协议版本
    let local_version = PROTOCOL_VERSION;
    
    // 2. 查询服务端支持的版本
    // let server_version = fetch_server_protocol_version().await?;
    
    // 3. 版本兼容性检查
    // if !is_compatible(local_version, server_version) {
    //     warn!("协议版本不兼容: local={}, server={}", local_version, server_version);
    // }
    
    info!("协议版本: {}", local_version);
    Ok(())
}
```

### 12.3 WebSocket 消息格式兼容性

#### 12.3.1 消息信封格式

Go SDK 使用的消息格式：

```go
// OpenIMReq - 客户端请求
type OpenIMReq struct {
    ReqIdentifier int32  `protobuf:"varint,1,opt,name=reqIdentifier"`
    Token         string `protobuf:"bytes,2,opt,name=token"`
    SendID        string `protobuf:"bytes,3,opt,name=sendID"`
    OperationID   string `protobuf:"bytes,4,opt,name=operationID"`
    MsgIncr       string `protobuf:"bytes,5,opt,name=msgIncr"`
    Data          []byte `protobuf:"bytes,6,opt,name=data"`
}

// OpenIMResp - 服务端响应
type OpenIMResp struct {
    ReqIdentifier int32  `protobuf:"varint,1,opt,name=reqIdentifier"`
    MsgIncr       string `protobuf:"bytes,2,opt,name=msgIncr"`
    OperationID   string `protobuf:"bytes,3,opt,name=operationID"`
    ErrCode       int32  `protobuf:"varint,4,opt,name=errCode"`
    ErrMsg        string `protobuf:"bytes,5,opt,name=errMsg"`
    Data          []byte `protobuf:"bytes,6,opt,name=data"`
}
```

Rust 实现（必须严格对齐）：

```rust
// rust/src/protocol/ws.rs
use prost::Message;

#[derive(Clone, Debug, Message)]
pub struct OpenIMReq {
    #[prost(int32, tag = "1")]
    pub req_identifier: i32,
    
    #[prost(string, tag = "2")]
    pub token: String,
    
    #[prost(string, tag = "3")]
    pub send_id: String,
    
    #[prost(string, tag = "4")]
    pub operation_id: String,
    
    #[prost(string, tag = "5")]
    pub msg_incr: String,
    
    #[prost(bytes = "vec", tag = "6")]
    pub data: Vec<u8>,
}

#[derive(Clone, Debug, Message)]
pub struct OpenIMResp {
    #[prost(int32, tag = "1")]
    pub req_identifier: i32,
    
    #[prost(string, tag = "2")]
    pub msg_incr: String,
    
    #[prost(string, tag = "3")]
    pub operation_id: String,
    
    #[prost(int32, tag = "4")]
    pub err_code: i32,
    
    #[prost(string, tag = "5")]
    pub err_msg: String,
    
    #[prost(bytes = "vec", tag = "6")]
    pub data: Vec<u8>,
}
```

#### 12.3.2 消息类型常量对齐

```rust
// rust/src/protocol/constants.rs

/// WebSocket 请求标识（必须与 Go SDK constant.go 一致）
pub mod ws_req_identifier {
    pub const GET_NEWEST_SEQ: i32 = 1001;
    pub const PULL_MSG_BY_RANGE: i32 = 1002;
    pub const SEND_MSG: i32 = 1003;
    pub const SEND_SIGNAL_MSG: i32 = 1004;
    pub const PULL_MSG_BY_SEQ_LIST: i32 = 1005;
    pub const GET_CONV_MAX_READ_SEQ: i32 = 1006;
    pub const PULL_CONV_LAST_MESSAGE: i32 = 1007;
}

/// WebSocket 推送标识
pub mod ws_push_identifier {
    pub const PUSH_MSG: i32 = 2001;
    pub const KICK_ONLINE_MSG: i32 = 2002;
    pub const LOGOUT_MSG: i32 = 2003;
    pub const SET_BACKGROUND_STATUS: i32 = 2004;
    pub const WS_SUB_USER_ONLINE_STATUS: i32 = 2005;
}

/// 消息内容类型（必须与 Go SDK constant.go 一致）
pub mod content_type {
    pub const TEXT: i32 = 101;
    pub const PICTURE: i32 = 102;
    pub const SOUND: i32 = 103;
    pub const VIDEO: i32 = 104;
    pub const FILE: i32 = 105;
    pub const AT_TEXT: i32 = 106;
    pub const MERGER: i32 = 107;
    pub const CARD: i32 = 108;
    pub const LOCATION: i32 = 109;
    pub const CUSTOM: i32 = 110;
    pub const TYPING: i32 = 113;
    pub const QUOTE: i32 = 114;
    pub const FACE: i32 = 115;
    pub const ADVANCED_TEXT: i32 = 117;
    pub const MARKDOWN_TEXT: i32 = 118;
    pub const CUSTOM_MSG_NOT_TRIGGER_CONVERSATION: i32 = 119;
    pub const CUSTOM_MSG_ONLINE_ONLY: i32 = 120;
    
    // 通知类消息
    pub const NOTIFICATION_BEGIN: i32 = 1000;
    pub const FRIEND_NOTIFICATION_BEGIN: i32 = 1200;
    pub const FRIEND_NOTIFICATION_END: i32 = 1299;
    pub const GROUP_NOTIFICATION_BEGIN: i32 = 1500;
    pub const GROUP_NOTIFICATION_END: i32 = 1599;
    pub const NOTIFICATION_END: i32 = 5000;
}

/// 会话类型
pub mod session_type {
    pub const SINGLE_CHAT: i32 = 1;
    pub const WRITE_GROUP_CHAT: i32 = 2;
    pub const READ_GROUP_CHAT: i32 = 3;
    pub const NOTIFICATION_CHAT: i32 = 4;
}

/// 消息来源
pub mod msg_from {
    pub const USER_MSG: i32 = 100;
    pub const SYS_MSG: i32 = 200;
}

/// 群组角色
pub mod group_role {
    pub const OWNER: i32 = 100;
    pub const ADMIN: i32 = 60;
    pub const ORDINARY_USER: i32 = 20;
}

/// 同步标志
pub mod sync_flag {
    pub const MSG_SYNC_BEGIN: i32 = 1001;
    pub const MSG_SYNC_PROCESSING: i32 = 1002;
    pub const MSG_SYNC_END: i32 = 1003;
    pub const MSG_SYNC_FAILED: i32 = 1004;
    pub const APP_DATA_SYNC_START: i32 = 1005;
    pub const APP_DATA_SYNC_FINISH: i32 = 1006;
}
```

### 12.4 HTTP API 兼容性

#### 12.4.1 API 路由定义

```rust
// rust/src/infra/http/routes.rs

/// HTTP API 路由（必须与服务端一致）
pub mod routes {
    // 用户相关
    pub const GET_USERS_INFO: &str = "/user/get_users_info";
    pub const GET_USERS_INFO_WITH_CACHE: &str = "/user/get_users_info_with_cache";
    pub const UPDATE_USER_INFO: &str = "/user/update_user_info";
    
    // 好友相关
    pub const ADD_FRIEND: &str = "/friend/add_friend";
    pub const GET_FRIEND_LIST: &str = "/friend/get_friend_list";
    pub const DELETE_FRIEND: &str = "/friend/delete_friend";
    
    // 群组相关
    pub const CREATE_GROUP: &str = "/group/create_group";
    pub const GET_GROUP_INFO: &str = "/group/get_group_info";
    pub const GET_GROUP_MEMBER_LIST: &str = "/group/get_group_member_list";
    pub const JOIN_GROUP: &str = "/group/join_group";
    pub const QUIT_GROUP: &str = "/group/quit_group";
    
    // 会话相关
    pub const GET_OWNER_CONVERSATION: &str = "/conversation/get_owner_conversation";
    pub const GET_INCREMENTAL_CONVERSATION: &str = "/conversation/get_incremental_conversation";
    pub const SET_CONVERSATION: &str = "/conversation/set_conversation";
    
    // 消息相关
    pub const SEND_MESSAGE: &str = "/msg/send_message";
    pub const REVOKE_MESSAGE: &str = "/msg/revoke_message";
    
    // 第三方服务
    pub const INITIATE_PRE_SIGNED_URL: &str = "/third/initiate_pre_signed_url";
    pub const COMPLETE_PRE_SIGNED_URL: &str = "/third/complete_pre_signed_url";
}
```

#### 12.4.2 请求/响应格式

```rust
// rust/src/infra/http/client.rs
use reqwest::{Client, Response};
use serde::{Deserialize, Serialize};

/// HTTP API 响应信封
#[derive(Debug, Deserialize)]
pub struct ApiResponse<T> {
    #[serde(rename = "errCode")]
    pub err_code: i32,
    
    #[serde(rename = "errMsg")]
    pub err_msg: String,
    
    #[serde(default)]
    pub data: Option<T>,
}

impl<T> ApiResponse<T> {
    pub fn into_result(self) -> Result<T> {
        if self.err_code == 0 {
            self.data.ok_or_else(|| SdkError::Unknown {
                message: "响应 data 字段为空".into(),
            })
        } else {
            Err(SdkError::ApiError {
                code: self.err_code,
                message: self.err_msg,
            })
        }
    }
}

/// HTTP 客户端
pub struct HttpApiClient {
    client: Client,
    base_url: String,
    token: String,
    user_id: String,
    operation_id: String,
}

impl HttpApiClient {
    pub async fn post<T: Serialize, R: for<'de> Deserialize<'de>>(
        &self,
        route: &str,
        body: &T,
    ) -> Result<R> {
        let url = format!("{}{}", self.base_url, route);
        
        let response = self.client
            .post(&url)
            .header("token", &self.token)
            .header("operationID", &self.operation_id)
            .json(body)
            .send()
            .await?;
        
        if !response.status().is_success() {
            return Err(SdkError::HttpError {
                status: response.status().as_u16(),
                message: response.text().await?,
            });
        }
        
        let api_resp: ApiResponse<R> = response.json().await?;
        api_resp.into_result()
    }
}
```

### 12.5 错误码兼容性

```rust
// rust/src/domain/error/types.rs

/// SDK 错误类型（与服务端错误码对齐）
#[derive(Debug, thiserror::Error)]
pub enum SdkError {
    #[error("网络错误: {message}")]
    NetworkError { message: String },
    
    #[error("连接错误: {message}")]
    ConnectionError { message: String },
    
    #[error("HTTP 错误: status={status}, message={message}")]
    HttpError { status: u16, message: String },
    
    #[error("API 错误: code={code}, message={message}")]
    ApiError { code: i32, message: String },
    
    #[error("Protobuf 解析错误: {source}")]
    ProtobufError { 
        #[from] 
        source: prost::DecodeError 
    },
    
    #[error("超时: {message}")]
    Timeout { message: String },
    
    #[error("消息发送失败: {message}")]
    MessageSendFailed { message: String },
    
    #[error("消息同步失败: {message}")]
    MessageSyncFailed { message: String },
    
    #[error("鉴权失败: {message}")]
    AuthFailed { message: String },
    
    #[error("被踢下线: {reason}")]
    KickedOffline { reason: String },
    
    #[error("未知错误: {message}")]
    Unknown { message: String },
}

impl SdkError {
    /// 判断是否为致命错误（不应重连）
    pub fn is_fatal(&self) -> bool {
        matches!(self, SdkError::AuthFailed { .. })
    }
}
```

### 12.6 兼容性测试方案

#### 12.6.1 Protobuf 序列化/反序列化测试

```rust
// tests/protocol_compatibility_test.rs

#[cfg(test)]
mod tests {
    use super::*;
    
    /// 测试 OpenIMReq 序列化/反序列化
    #[test]
    fn test_openim_req_serialization() {
        let req = OpenIMReq {
            req_identifier: 1001,
            token: "test_token".into(),
            send_id: "user1".into(),
            operation_id: "op_123".into(),
            msg_incr: "msg_1".into(),
            data: vec![1, 2, 3],
        };
        
        // 序列化
        let encoded = req.encode_to_vec();
        
        // 反序列化
        let decoded = OpenIMReq::decode(&encoded[..]).unwrap();
        
        // 验证
        assert_eq!(req.req_identifier, decoded.req_identifier);
        assert_eq!(req.token, decoded.token);
        assert_eq!(req.send_id, decoded.send_id);
        assert_eq!(req.operation_id, decoded.operation_id);
        assert_eq!(req.msg_incr, decoded.msg_incr);
        assert_eq!(req.data, decoded.data);
    }
    
    /// 测试 OpenIMResp 序列化/反序列化
    #[test]
    fn test_openim_resp_serialization() {
        let resp = OpenIMResp {
            req_identifier: 1001,
            msg_incr: "msg_1".into(),
            operation_id: "op_123".into(),
            err_code: 0,
            err_msg: "".into(),
            data: vec![4, 5, 6],
        };
        
        let encoded = resp.encode_to_vec();
        let decoded = OpenIMResp::decode(&encoded[..]).unwrap();
        
        assert_eq!(resp.req_identifier, decoded.req_identifier);
        assert_eq!(resp.err_code, decoded.err_code);
        assert_eq!(resp.data, decoded.data);
    }
    
    /// 测试与 Go SDK 序列化结果一致（需要 Go SDK 生成的测试数据）
    #[test]
    fn test_compatibility_with_go_sdk() {
        // 从 Go SDK 测试文件加载已知正确的序列化数据
        let go_encoded_data = include_bytes!("testdata/go_openim_req.bin");
        
        // Rust 反序列化
        let decoded = OpenIMReq::decode(&go_encoded_data[..]).unwrap();
        
        // 验证字段
        assert_eq!(decoded.req_identifier, 1001);
        assert_eq!(decoded.token, "test_token");
        
        // Rust 序列化
        let rust_encoded = decoded.encode_to_vec();
        
        // 验证与 Go 编码一致
        assert_eq!(go_encoded_data, rust_encoded.as_slice());
    }
}
```

#### 12.6.2 WebSocket 消息格式测试

```rust
#[cfg(test)]
mod websocket_tests {
    use super::*;
    
    /// 测试 WebSocket 连接 URL 格式
    #[test]
    fn test_websocket_url_format() {
        let config = ConnectionConfig {
            ws_url: "ws://localhost:10001".into(),
            user_id: "user1".into(),
            token: "token123".into(),
            platform_id: 5,
            // ...
        };
        
        let url = build_ws_url(&config);
        
        // 验证 URL 格式与服务端期望一致
        assert!(url.contains("token=token123"));
        assert!(url.contains("sendID=user1"));
        assert!(url.contains("platformID=5"));
        assert!(url.contains("operationID="));
        assert!(url.contains("isBackground=false"));
        assert!(url.contains("isMsgResp=true"));
    }
    
    /// 测试消息类型常量
    #[test]
    fn test_message_type_constants() {
        // 验证与 Go SDK constant.go 一致
        assert_eq!(ws_req_identifier::GET_NEWEST_SEQ, 1001);
        assert_eq!(ws_req_identifier::PULL_MSG_BY_RANGE, 1002);
        assert_eq!(ws_req_identifier::SEND_MSG, 1003);
        assert_eq!(ws_push_identifier::PUSH_MSG, 2001);
        assert_eq!(ws_push_identifier::KICK_ONLINE_MSG, 2002);
        
        assert_eq!(content_type::TEXT, 101);
        assert_eq!(content_type::PICTURE, 102);
        assert_eq!(content_type::VIDEO, 104);
        
        assert_eq!(session_type::SINGLE_CHAT, 1);
        assert_eq!(session_type::READ_GROUP_CHAT, 3);
        
        assert_eq!(group_role::OWNER, 100);
        assert_eq!(group_role::ADMIN, 60);
        assert_eq!(group_role::ORDINARY_USER, 20);
    }
}
```

#### 12.6.3 HTTP API 兼容性测试

```rust
#[cfg(test)]
mod http_api_tests {
    use super::*;
    use wiremock::{MockServer, Mock, ResponseTemplate};
    use wiremock::matchers::{method, path, body_json};
    
    /// 测试 HTTP API 请求格式
    #[tokio::test]
    async fn test_http_api_request_format() {
        let mock_server = MockServer::start().await;
        
        Mock::given(method("POST"))
            .and(path("/user/get_users_info"))
            .and(body_json(&GetUsersInfoReq {
                user_ids: vec!["user1".into()],
            }))
            .respond_with(ResponseTemplate::new(200).set_body_json(&ApiResponse {
                err_code: 0,
                err_msg: "".into(),
                data: Some(GetUsersInfoResp {
                    users: vec![UserInfo {
                        user_id: "user1".into(),
                        nickname: "Test User".into(),
                        // ...
                    }],
                }),
            }))
            .mount(&mock_server)
            .await;
        
        let client = HttpApiClient::new(mock_server.uri(), "token".into());
        let result = client.get_users_info(&["user1"]).await;
        
        assert!(result.is_ok());
    }
    
    /// 测试错误响应处理
    #[tokio::test]
    async fn test_http_api_error_response() {
        let mock_server = MockServer::start().await;
        
        Mock::given(method("POST"))
            .and(path("/user/get_users_info"))
            .respond_with(ResponseTemplate::new(200).set_body_json(&ApiResponse::<()> {
                err_code: 10001,
                err_msg: "用户不存在".into(),
                data: None,
            }))
            .mount(&mock_server)
            .await;
        
        let client = HttpApiClient::new(mock_server.uri(), "token".into());
        let result = client.get_users_info(&["nonexistent"]).await;
        
        assert!(result.is_err());
        if let SdkError::ApiError { code, message } = result.unwrap_err() {
            assert_eq!(code, 10001);
            assert_eq!(message, "用户不存在");
        }
    }
}
```

#### 12.6.4 端到端兼容性测试

```rust
#[cfg(test)]
mod e2e_compatibility_tests {
    use super::*;
    
    /// 测试完整登录流程与服务端兼容
    #[tokio::test]
    #[ignore] // 需要真实服务端
    async fn test_login_flow_compatibility() {
        // 1. 初始化 SDK
        let sdk = OpenIMClient::builder()
            .config(ClientConfig {
                api_base_url: "http://localhost:10002".into(),
                ws_url: "ws://localhost:10001".into(),
                // ...
            })
            .build()
            .await
            .unwrap();
        
        // 2. 登录
        let login_result = sdk.login("user1", "token123").await;
        assert!(login_result.is_ok());
        
        // 3. 验证连接状态
        assert_eq!(sdk.connection().status(), ConnectionStatus::Connected);
        
        // 4. 获取用户信息
        let user_info = sdk.user().get_self_info().await;
        assert!(user_info.is_ok());
        assert_eq!(user_info.unwrap().user_id, "user1");
    }
    
    /// 测试消息发送/接收流程
    #[tokio::test]
    #[ignore]
    async fn test_message_flow_compatibility() {
        let sdk_a = create_test_sdk("user_a").await;
        let sdk_b = create_test_sdk("user_b").await;
        
        // A 发送消息给 B
        let msg = sdk_a.message()
            .send_text("user_b", "Hello from Rust SDK!")
            .await
            .unwrap();
        
        // 验证消息已发送
        assert_eq!(msg.send_id, "user_a");
        assert_eq!(msg.recv_id, "user_b");
        assert_eq!(msg.content_type, content_type::TEXT);
        
        // B 接收消息（通过事件流）
        let mut events = sdk_b.subscribe_events();
        let event = tokio::time::timeout(
            Duration::from_secs(5),
            events.next()
        ).await.unwrap();
        
        assert!(matches!(event, Some(SdkEvent::NewMessage { .. })));
    }
}
```

### 12.7 版本升级策略

#### 12.7.1 协议版本检查

```rust
// rust/src/sdk/client.rs

impl OpenIMClient {
    /// 初始化时检查协议版本
    pub async fn init(&self) -> Result<()> {
        // 1. 检查本地协议版本
        protocol::check_protocol_version()?;
        
        // 2. 获取服务端版本（通过 HTTP API）
        let server_version = self.http_client.get_server_version().await?;
        
        // 3. 版本兼容性检查
        if !self.is_protocol_compatible(&server_version) {
            warn!(
                "协议版本不兼容: local={}, server={}",
                protocol::PROTOCOL_VERSION,
                server_version
            );
            // 可以选择继续或失败
        }
        
        // 4. 继续初始化...
        Ok(())
    }
    
    /// 检查协议版本兼容性
    fn is_protocol_compatible(&self, server_version: &str) -> bool {
        // 简单版本比较（实际应使用 semver）
        protocol::PROTOCOL_VERSION == server_version
    }
}
```

#### 12.7.2 向后兼容性保证

```rust
// rust/src/protocol/compatibility.rs

/// 协议兼容性适配器
pub struct ProtocolCompat;

impl ProtocolCompat {
    /// 处理旧版本服务端响应
    pub fn adapt_old_response(resp: OpenIMResp) -> Result<OpenIMResp> {
        // 如果服务端返回旧格式，转换为新格式
        if resp.req_identifier == 0 {
            // 旧版本可能缺少某些字段
            warn!("收到旧版本服务端响应");
        }
        Ok(resp)
    }
    
    /// 处理新版本服务端响应
    pub fn adapt_new_response(resp: OpenIMResp) -> Result<OpenIMResp> {
        // 新版本可能包含额外字段
        Ok(resp)
    }
}
```

### 12.8 持续集成中的兼容性检查

```yaml
# .github/workflows/compatibility.yml
name: Protocol Compatibility Check
on:
  push:
    paths:
      - 'proto/**'
      - 'src/protocol/**'
  schedule:
    - cron: '0 0 * * 1'  # 每周一检查

jobs:
  check-protocol:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Fetch latest protocol
        run: |
          git clone https://github.com/openimsdk/protocol.git proto/openim-protocol
      
      - name: Generate Rust bindings
        run: |
          cd rust
          cargo build
      
      - name: Run compatibility tests
        run: |
          cd rust
          cargo test --test protocol_compatibility_test
      
      - name: Compare with Go SDK
        run: |
          # 对比 Rust 和 Go SDK 的序列化结果
          cd rust
          cargo test --test go_sdk_comparison
      
      - name: Report
        if: failure()
        run: |
          echo "协议兼容性检查失败，请更新 proto 文件或调整绑定"
```

### 12.9 兼容性检查清单

在每次发布前，必须完成以下检查：

- [ ] **Protobuf 版本**：与 `openimsdk/protocol` 版本一致
- [ ] **消息常量**：所有 `req_identifier`、`content_type`、`session_type` 等与 Go SDK 一致
- [ ] **WebSocket URL**：参数名称和顺序与服务端期望一致
- [ ] **HTTP API 路由**：所有路由路径与服务端一致
- [ ] **请求/响应格式**：信封格式、字段名称、类型与服务端一致
- [ ] **错误码**：正确解析和处理服务端返回的错误码
- [ ] **序列化测试**：通过 Protobuf 序列化/反序列化测试
- [ ] **端到端测试**：与真实服务端交互测试通过
- [ ] **版本升级测试**：测试与服务端版本升级的兼容性

---

## 十、总结

### 10.1 架构对比

| 维度 | 当前架构 | 新架构 |
|------|----------|--------|
| 模块数量 | 3 个大模块 | 15+ 个小模块 |
| 最大文件行数 | 1800+ 行 | 300 行/文件 |
| 依赖关系 | 网状依赖 | 分层依赖 |
| 事件通道 | 6 个独立通道 | 1 个统一总线 |
| 错误处理 | anyhow | 自定义 SdkError |
| 测试覆盖 | 难以测试 | 易于 mock |
| 扩展性 | 修改核心代码 | 添加新模块 |

### 10.2 预期收益

- **可维护性**: 提升 300%（模块职责清晰）
- **可测试性**: 提升 500%（依赖注入，易于 mock）
- **扩展性**: 提升 200%（接口设计，插件化）
- **性能**: 提升 50%（事件总线优化，缓存统一）

### 10.3 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 迁移周期长 | 高 | 渐进式迁移，并行运行 |
| 功能回归 | 中 | 完整测试覆盖，E2E 测试 |
| 性能下降 | 中 | 基准测试，性能监控 |
| 团队学习成本 | 低 | 文档完善，代码示例 |

---

## 十一、下一步行动

1. **评审架构设计** - 团队评审，收集反馈
2. **创建新目录结构** - 按新架构创建目录
3. **实现基础设施** - 事件总线、错误类型、依赖注入
4. **实现核心模块** - 连接、消息、会话管理器
5. **编写测试** - 单元测试、集成测试
6. **渐进式迁移** - 按 Phase 计划迁移
7. **性能测试** - 基准测试，优化热点
8. **文档完善** - API 文档，使用指南
