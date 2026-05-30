# Rust SDK 实施计划

基于 [SDK_ARCHITECTURE_REDESIGN.md](./SDK_ARCHITECTURE_REDESIGN.md) 拆分的可执行计划。

---

## 总体策略

采用**渐进式迁移**（绞杀者模式），分 4 个阶段完成：

| 阶段 | 目标 | 风险 | 预计工作量 |
|------|------|------|-----------|
| Phase 1 | 基础设施层 | 低 | 2-3 天 |
| Phase 2 | 核心模块 | 中 | 5-7 天 |
| Phase 3 | 业务模块 | 中 | 5-7 天 |
| Phase 4 | 迁移与优化 | 高 | 3-5 天 |

---

## Phase 1: 基础设施层（基础建设）

**目标**：搭建新架构的基础设施，不破坏现有功能

### Task 1.1: 创建新目录结构

**描述**：按照新架构创建目录和模块文件

**目录结构**：
```
rust/src/
├── api/                          # FFI 桥接层（保留现有）
├── sdk/                          # SDK 门面层（新增）
│   ├── mod.rs
│   ├── client.rs                 # OpenIMClient 门面
│   ├── builder.rs                # ClientBuilder
│   └── context.rs                # RuntimeContext
├── core/                         # 核心业务层（新增）
│   ├── mod.rs
│   ├── connection/               # 连接管理
│   │   ├── mod.rs
│   │   ├── manager.rs
│   │   ├── websocket.rs
│   │   ├── reconnect.rs
│   │   └── heartbeat.rs
│   ├── message/                  # 消息管理
│   │   ├── mod.rs
│   │   ├── sender.rs             # 消息发送队列
│   │   ├── syncer.rs             # 消息同步器
│   │   ├── handler.rs            # 消息处理器
│   │   └── types.rs
│   ├── conversation/             # 会话管理
│   │   ├── mod.rs
│   │   ├── manager.rs
│   │   └── syncer.rs
│   ├── user/                     # 用户管理
│   │   ├── mod.rs
│   │   └── manager.rs
│   ├── friend/                   # 好友管理
│   │   ├── mod.rs
│   │   └── manager.rs
│   ├── group/                    # 群组管理
│   │   ├── mod.rs
│   │   └── manager.rs
│   └── online/                   # 在线状态（已有，迁移）
├── domain/                       # 领域层（新增）
│   ├── mod.rs
│   ├── model/                    # 领域模型
│   │   ├── mod.rs
│   │   ├── user.rs
│   │   ├── friend.rs
│   │   ├── group.rs
│   │   ├── conversation.rs
│   │   └── message.rs
│   ├── event/                    # 事件系统
│   │   ├── mod.rs
│   │   ├── bus.rs                # 事件总线
│   │   └── types.rs              # 事件类型
│   ├── error/                    # 错误定义
│   │   ├── mod.rs
│   │   └── types.rs              # SdkError
│   └── constant/                 # 常量定义
│       ├── mod.rs
│       └── types.rs              # 消息类型、会话类型等
├── infra/                        # 基础设施层（新增）
│   ├── mod.rs
│   ├── database/                 # 数据库（已有 repository，迁移）
│   ├── http/                     # HTTP 客户端
│   │   ├── mod.rs
│   │   ├── client.rs
│   │   ├── routes.rs
│   │   └── auth.rs
│   ├── cache/                    # 缓存
│   │   ├── mod.rs
│   │   └── memory.rs
│   └── file/                     # 文件服务
│       ├── mod.rs
│       └── uploader.rs
└── protocol/                     # 协议层（新增）
    ├── mod.rs
    ├── constants.rs              # 协议常量
    ├── ws.rs                     # WebSocket 消息格式
    └── generated/                # Protobuf 生成代码
```

**验收标准**：
- [ ] 所有目录和 `mod.rs` 文件创建完成
- [ ] `cargo check` 通过（空模块）

---

### Task 1.2: 实现领域层 - 错误类型

**文件**：`domain/error/types.rs`

**描述**：定义统一的 SDK 错误类型，与服务端错误码对齐

**关键代码**：
```rust
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
    ProtobufError { #[from] source: prost::DecodeError },
    #[error("超时: {message}")]
    Timeout { message: String },
    #[error("消息发送失败: {message}")]
    MessageSendFailed { message: String },
    #[error("鉴权失败: {message}")]
    AuthFailed { message: String },
    #[error("被踢下线: {reason}")]
    KickedOffline { reason: String },
    #[error("未知错误: {message}")]
    Unknown { message: String },
}

impl SdkError {
    pub fn is_fatal(&self) -> bool {
        matches!(self, SdkError::AuthFailed { .. })
    }
}
```

**验收标准**：
- [ ] 所有错误类型定义完成
- [ ] `is_fatal()` 方法正确实现
- [ ] 单元测试通过

---

### Task 1.3: 实现领域层 - 常量定义

**文件**：`domain/constant/types.rs`

**描述**：定义所有协议常量，与 Go SDK `constant.go` 完全对齐

**关键常量**：
- WebSocket 请求标识（1001-1007）
- WebSocket 推送标识（2001-2005）
- 消息内容类型（101-120, 1000-5000）
- 会话类型（1-4）
- 消息来源（100, 200）
- 群组角色（100, 60, 20）
- 同步标志（1001-1006）

**验收标准**：
- [ ] 所有常量与 Go SDK 一致
- [ ] 单元测试验证常量值
- [ ] 文档注释完整

---

### Task 1.4: 实现领域层 - 事件总线

**文件**：`domain/event/bus.rs`, `domain/event/types.rs`

**描述**：实现统一事件总线，替代现有的 6 个独立通道

**关键代码**：
```rust
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

#[derive(Clone, Debug, Serialize)]
#[serde(tag = "type", content = "data", rename_all = "camelCase")]
pub enum SdkEvent {
    Connecting,
    Connected,
    Disconnected { reason: String },
    NewMessage { message: MsgStruct },
    MessageSent { client_msg_id: String },
    ConversationChanged { conversations: Vec<LocalConversation> },
    // ... 更多事件
}
```

**验收标准**：
- [ ] 事件发布/订阅功能正常
- [ ] 多订阅者接收事件正确
- [ ] 事件序列化正确（用于 FFI）
- [ ] 单元测试通过

---

### Task 1.5: 实现协议层 - Protobuf 绑定

**文件**：`protocol/`, `build.rs`

**描述**：配置 `prost-build` 从 `.proto` 文件生成 Rust 绑定

**步骤**：
1. 克隆 `openim-protocol` 仓库到 `proto/` 目录
2. 配置 `build.rs` 使用 `prost-build` 生成代码
3. 生成 `sdkws`, `msg`, `conversation`, `group`, `relation`, `auth` 模块

**验收标准**：
- [ ] `build.rs` 正确配置
- [ ] `cargo build` 自动生成代码
- [ ] 生成的代码可编译
- [ ] 序列化/反序列化测试通过

---

### Task 1.6: 实现协议层 - WebSocket 消息格式

**文件**：`protocol/ws.rs`

**描述**：定义 `OpenIMReq`/`OpenIMResp` 消息信封格式

**关键代码**：
```rust
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

**验收标准**：
- [ ] 序列化/反序列化正确
- [ ] 与 Go SDK 序列化结果一致（对比测试）
- [ ] 单元测试通过

---

### Task 1.7: 实现基础设施层 - HTTP 客户端

**文件**：`infra/http/client.rs`, `infra/http/routes.rs`

**描述**：实现 HTTP API 客户端，定义所有路由

**关键代码**：
```rust
pub struct HttpApiClient {
    client: reqwest::Client,
    base_url: String,
    token: String,
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
        
        let api_resp: ApiResponse<R> = response.json().await?;
        api_resp.into_result()
    }
}
```

**验收标准**：
- [ ] HTTP 请求/响应正确
- [ ] 错误处理正确
- [ ] Mock 测试通过
- [ ] 所有路由定义完成

---

### Task 1.8: 实现 SDK 层 - 依赖注入容器

**文件**：`sdk/context.rs`

**描述**：实现 `RuntimeContext` 管理所有依赖

**关键代码**：
```rust
pub struct RuntimeContext {
    config: ClientConfig,
    repository: Repository,
    http_client: HttpApiClient,
    event_bus: EventBus,
    cache: CacheManager,
    cancel_token: CancellationToken,
}

impl RuntimeContext {
    pub fn new(config: ClientConfig) -> Self {
        let event_bus = EventBus::new();
        let cache = CacheManager::new();
        let cancel_token = CancellationToken::new();
        // ...
        Self { /* ... */ }
    }
}
```

**验收标准**：
- [ ] 依赖正确注入
- [ ] 生命周期管理正确
- [ ] 单元测试通过

---

### Phase 1 验收

- [ ] 所有 Task 1.1-1.8 完成
- [ ] `cargo test` 全部通过
- [ ] `cargo clippy` 无警告
- [ ] 现有 FFI 层仍可正常工作（未破坏）

---

## Phase 2: 核心模块（关键功能）

**目标**：实现连接、消息、会话核心模块

### Task 2.1: 实现连接管理器

**文件**：`core/connection/manager.rs`, `core/connection/websocket.rs`

**描述**：实现 WebSocket 连接管理，支持自动重连、心跳

**关键功能**：
- WebSocket 连接/断开
- 读写分离（独立 read_loop/write_loop）
- 心跳机制（ping/pong）
- 指数退避重连策略
- 发送请求并等待响应（RPC 模式）

**验收标准**：
- [ ] 连接/断开功能正常
- [ ] 自动重连功能正常
- [ ] 心跳机制正常
- [ ] RPC 请求/响应正常
- [ ] 单元测试 + 集成测试通过

---

### Task 2.2: 实现消息发送队列

**文件**：`core/message/sender.rs`

**描述**：实现多 Worker 消息发送队列，支持有序发送

**关键功能**：
- 多 Worker 并发（CPU 核心数，最少 4 个）
- 双 Lane 有序发送（Text Lane / Media Lane）
- 动态阈值估计器
- 超时机制（3 秒）
- 重试入队（100 次，5ms 间隔）

**验收标准**：
- [ ] 文本消息有序发送
- [ ] 媒体消息按阈值有序/无序
- [ ] 超时处理正确
- [ ] 并发测试通过
- [ ] 性能测试达标

---

### Task 2.3: 实现消息同步器

**文件**：`core/message/syncer.rs`

**描述**：实现消息同步器，负责拉取和同步消息

**关键功能**：
- 从本地数据库加载各会话最大 seq
- 连接成功后触发首次同步
- 按 seq 拉取缺失消息
- 并发拉取（限制并发数）
- 同步状态事件通知

**验收标准**：
- [ ] seq 加载正确
- [ ] 首次同步正常
- [ ] 增量同步正常
- [ ] 并发拉取正常
- [ ] 事件通知正确

---

### Task 2.4: 实现消息处理器

**文件**：`core/message/handler.rs`

**描述**：处理接收到的消息，插入数据库，触发回调

**关键功能**：
- 解析推送消息
- 去重检查
- 插入数据库
- 更新会话最新消息
- 触发事件总线

**验收标准**：
- [ ] 消息解析正确
- [ ] 去重逻辑正确
- [ ] 数据库插入正确
- [ ] 会话更新正确
- [ ] 事件触发正确

---

### Task 2.5: 实现会话同步器

**文件**：`core/conversation/syncer.rs`

**描述**：实现会话增量/全量同步

**关键功能**：
- 增量同步（基于版本号）
- 全量同步（首次或版本不匹配）
- 版本控制
- 插入/更新/删除处理

**验收标准**：
- [ ] 增量同步正确
- [ ] 全量同步正确
- [ ] 版本更新正确
- [ ] 事件触发正确

---

### Task 2.6: 实现会话管理器

**文件**：`core/conversation/manager.rs`

**描述**：实现会话管理功能

**关键功能**：
- 获取会话列表
- 获取单个会话
- 设置会话属性（置顶、免打扰等）
- 删除会话

**验收标准**：
- [ ] 会话 CRUD 功能正常
- [ ] 属性设置正确
- [ ] 单元测试通过

---

### Phase 2 验收

- [ ] 所有 Task 2.1-2.6 完成
- [ ] `cargo test` 全部通过
- [ ] 连接 + 消息 + 会话完整流程测试通过
- [ ] 性能测试达标

---

## Phase 3: 业务模块（完整功能）

**目标**：实现用户、好友、群组等业务模块

### Task 3.1: 实现用户管理器

**文件**：`core/user/manager.rs`

**关键功能**：
- 获取用户信息
- 更新用户信息
- 用户缓存管理

**验收标准**：
- [ ] 用户信息获取正确
- [ ] 缓存功能正常
- [ ] 单元测试通过

---

### Task 3.2: 实现好友管理器

**文件**：`core/friend/manager.rs`

**关键功能**：
- 获取好友列表
- 添加好友
- 删除好友
- 处理好友请求
- 黑名单管理

**验收标准**：
- [ ] 好友 CRUD 功能正常
- [ ] 好友请求处理正确
- [ ] 黑名单功能正常
- [ ] 单元测试通过

---

### Task 3.3: 实现群组管理器

**文件**：`core/group/manager.rs`

**关键功能**：
- 创建群组
- 获取群组信息
- 更新群组信息
- 加入/退出群组
- 群成员管理
- 群组申请处理

**验收标准**：
- [ ] 群组 CRUD 功能正常
- [ ] 成员管理正确
- [ ] 群组申请处理正确
- [ ] 单元测试通过

---

### Task 3.4: 实现在线状态模块

**文件**：`core/online/`（迁移现有代码）

**描述**：迁移现有的在线状态模块到新架构

**验收标准**：
- [ ] 在线状态查询正常
- [ ] 订阅功能正常
- [ ] 事件触发正确

---

### Task 3.5: 实现文件上传服务

**文件**：`infra/file/uploader.rs`

**关键功能**：
- 初始化预签名 URL
- 上传文件
- 完成上传

**验收标准**：
- [ ] 文件上传功能正常
- [ ] 预签名 URL 获取正确
- [ ] 单元测试通过

---

### Phase 3 验收

- [ ] 所有 Task 3.1-3.5 完成
- [ ] `cargo test` 全部通过
- [ ] 完整业务流程测试通过（登录 → 添加好友 → 创建群组 → 发送消息）

---

## Phase 4: 迁移与优化（收尾工作）

**目标**：迁移 FFI 层，清理旧代码，性能优化

### Task 4.1: 实现 SDK 门面

**文件**：`sdk/client.rs`, `sdk/builder.rs`

**描述**：实现 `OpenIMClient` 门面，统一所有模块入口

**关键代码**：
```rust
pub struct OpenIMClient {
    context: Arc<RuntimeContext>,
    connection: Arc<ConnectionManagerImpl>,
    message_manager: Arc<MessageManagerImpl>,
    conversation_manager: Arc<ConversationManagerImpl>,
    user_manager: Arc<UserManagerImpl>,
    friend_manager: Arc<FriendManagerImpl>,
    group_manager: Arc<GroupManagerImpl>,
}

impl OpenIMClient {
    pub fn builder() -> ClientBuilder {
        ClientBuilder::new()
    }
    
    pub fn connection(&self) -> &Arc<ConnectionManagerImpl> {
        &self.connection
    }
    
    pub fn message(&self) -> &Arc<MessageManagerImpl> {
        &self.message_manager
    }
    // ...
}
```

**验收标准**：
- [ ] 门面模式正确实现
- [ ] 构建器模式正确实现
- [ ] 所有模块入口正确

---

### Task 4.2: 更新 FFI 桥接层

**文件**：`api/bridge_*.rs`

**描述**：更新 FFI 层调用新 SDK 门面

**关键变更**：
```rust
// 旧代码
#[flutter_rust_bridge::frb]
pub async fn send_message(message: String) -> Result<String> {
    let client = get_current_client().await?;
    let result = client.read().await.send_message(message).await?;
    Ok(serde_json::to_string(&result)?)
}

// 新代码
#[flutter_rust_bridge::frb]
pub async fn send_message(message: MsgStructBridge) -> Result<MsgStructBridge> {
    let client = get_sdk_client().await?;
    let message = message.to_msg_struct();
    let result = client.message().send_message(message).await?;
    Ok(MsgStructBridge::from(result))
}
```

**验收标准**：
- [ ] 所有 FFI 函数更新完成
- [ ] Flutter 侧调用正常
- [ ] 事件流正常

---

### Task 4.3: 迁移数据库层

**文件**：`infra/database/`（迁移现有 repository）

**描述**：将现有 `repository` 迁移到新架构

**验收标准**：
- [ ] 所有 DAO 方法迁移完成
- [ ] 数据库操作正常
- [ ] 测试通过

---

### Task 4.4: 清理旧代码

**描述**：删除旧的 `im/` 目录中的旧代码

**步骤**：
1. 确认所有功能已迁移
2. 删除旧代码
3. 更新 `mod.rs` 导出
4. 运行完整测试

**验收标准**：
- [ ] 旧代码完全删除
- [ ] 编译通过
- [ ] 所有测试通过

---

### Task 4.5: 性能优化

**描述**：优化数据库批量操作、缓存、并发

**优化点**：
- 数据库批量插入（100 条/批）
- 多级缓存（L1 内存 + L2 数据库）
- 并发限制（Semaphore）
- 消息批处理

**验收标准**：
- [ ] 性能测试达标
- [ ] 内存使用合理
- [ ] 无性能回归

---

### Task 4.6: 完整测试

**描述**：运行完整测试套件

**测试类型**：
- 单元测试
- 集成测试
- 端到端测试（需要真实服务端）
- 性能测试
- 兼容性测试

**验收标准**：
- [ ] 所有测试通过
- [ ] 代码覆盖率 > 80%
- [ ] 无性能回归
- [ ] 与服务端兼容性验证通过

---

### Task 4.7: 文档完善

**描述**：完善 API 文档和使用指南

**文档内容**：
- API 参考文档
- 使用示例
- 迁移指南
- 常见问题

**验收标准**：
- [ ] API 文档完整
- [ ] 示例代码可运行
- [ ] 迁移指南清晰

---

### Phase 4 验收

- [ ] 所有 Task 4.1-4.7 完成
- [ ] 旧代码完全清理
- [ ] 完整测试套件通过
- [ ] 文档完善
- [ ] 可以发布

---

## 执行顺序与依赖

```
Phase 1 (基础设施)
├── 1.1 目录结构
├── 1.2 错误类型
├── 1.3 常量定义
├── 1.4 事件总线
├── 1.5 Protobuf 绑定
├── 1.6 WebSocket 消息格式
├── 1.7 HTTP 客户端
└── 1.8 依赖注入容器

Phase 2 (核心模块)
├── 2.1 连接管理器 ← 依赖 1.5, 1.6, 1.4
├── 2.2 消息发送队列 ← 依赖 2.1
├── 2.3 消息同步器 ← 依赖 2.1, 1.8
├── 2.4 消息处理器 ← 依赖 2.3, 1.4
├── 2.5 会话同步器 ← 依赖 2.1, 1.7
└── 2.6 会话管理器 ← 依赖 2.5

Phase 3 (业务模块)
├── 3.1 用户管理器 ← 依赖 1.7, 1.8
├── 3.2 好友管理器 ← 依赖 1.7, 1.8
├── 3.3 群组管理器 ← 依赖 1.7, 1.8
├── 3.4 在线状态 ← 依赖 2.1
└── 3.5 文件上传 ← 依赖 1.7

Phase 4 (迁移与优化)
├── 4.1 SDK 门面 ← 依赖 Phase 2, Phase 3
├── 4.2 FFI 更新 ← 依赖 4.1
├── 4.3 数据库迁移 ← 依赖 Phase 2, Phase 3
├── 4.4 清理旧代码 ← 依赖 4.2, 4.3
├── 4.5 性能优化 ← 依赖 4.4
├── 4.6 完整测试 ← 依赖 4.5
└── 4.7 文档完善 ← 依赖 4.6
```

---

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Protobuf 生成失败 | 高 | 手动维护关键消息格式作为备选 |
| 连接管理器不稳定 | 高 | 充分测试重连逻辑，保留旧代码作为回退 |
| 消息发送队列性能不达标 | 中 | 调整 Worker 数量，优化队列实现 |
| FFI 层迁移后 Flutter 侧不兼容 | 中 | 保持接口签名一致，逐步迁移 |
| 数据库迁移引入 bug | 中 | 完整测试覆盖，对比新旧实现结果 |

---

## 下一步行动

1. **评审计划** - 确认任务拆分和优先级
2. **开始 Phase 1** - 从 Task 1.1 开始执行
3. **每日进度** - 更新任务状态
4. **阶段验收** - 每个 Phase 完成后进行验收
