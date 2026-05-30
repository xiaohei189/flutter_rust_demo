# Rust SDK 实施计划

基于 [SDK_ARCHITECTURE_REDESIGN.md](./SDK_ARCHITECTURE_REDESIGN.md) 拆分的可执行计划。

---

## 总体策略（从内到外）

```
内层                          外层
[基础设施] → [核心模块] → [业务模块] → [SDK门面+测试] → [FFI桥接]
```

**核心原则**：以 **Go SDK**（`D:\workspace\openim-sdk-core`）为权威参考，写全新干净的 Rust 代码。旧 `im/` 代码仅作参考（了解已踩过的坑），重构完成后**完全删除**。

| 参考来源 | 优先级 | 用法 |
|---------|--------|------|
| Go SDK (`openim-sdk-core`) | 🥇 第一 | 业务逻辑、接口签名、数据流 |
| 旧 `im/` 代码 | 🥈 第二 | 了解已尝试路径、避开已知坑 |
| `migrations/` + `openim-protocol` | 🥉 直接复用 | SQL 建表、protobuf 定义（这些是正确的）|

| 阶段 | 目标 | 状态 |
|------|------|------|
| Phase 1 | 基础设施层（新架构骨架） | ✅ 已完成 |
| Phase 2 | 核心模块实体化 | 🔴 待开始 |
| Phase 3 | 业务模块实体化 | 🔴 待开始 |
| Phase 4 | SDK 门面完善 + 集成测试 | 🔴 待开始 |
| Phase 5 | FFI 桥接层适配 + 删除旧代码 | 🔴 待开始 |

---

## Phase 1 完成情况

| 模块 | 文件 | 状态 |
|------|------|------|
| 错误类型 | `domain/error/types.rs` | ✅ `SdkError` + helper + From 转换 |
| 常量定义 | `domain/constant/types.rs` | ✅ 协议常量 |
| 事件总线 | `domain/event/bus.rs` + `types.rs` | ✅ broadcast channel 实现 |
| 协议层 | `protocol/` | ✅ 依赖 openim-protocol crate |
| HTTP 客户端 | `infra/http/client.rs` + `routes.rs` | ✅ reqwest + 路由表 |
| 依赖注入 | `sdk/context.rs` | ✅ RuntimeContext |
| 缓存 | `infra/cache/memory.rs` | ✅ 内存 KV |

---

## Phase 2: 核心模块实体化

**总体目标**：让新 `core/` 模块能真正跑通 连接 → 收消息 → 存数据库 → 发事件 全链路。

**当前状态**：所有 `core/` 模块都是纯内存占位实现。

### 数据库表结构（已有 migrations，直接复用）

| 表 | 迁移文件 | 关键字段 |
|----|---------|---------|
| local_conversations | 20250101000000_init_conv_friend.sql | conversation_id, max_seq, min_seq, ... |
| local_friends | 同上 | owner_user_id, friend_user_id |
| local_users | 20250214100000_add_local_users.sql | user_id, nickname, face_url |
| local_chat_logs | 20250216000000_local_chat_logs.sql | conversation_id, client_msg_id, seq, content_type, content |
| local_groups | 20250215000002_local_groups.sql | group_id, group_name |
| local_group_members | 20250215000003_local_group_members.sql | group_id, user_id |
| local_blacks | 20250215000006_local_blacks.sql | owner_user_id, block_user_id |
| local_sending_messages | 20250215000001_local_sending_messages.sql | 待发送消息队列 |

---

### Task 2.1: 数据库层 — Repository + DAO

**目标**：实现 `infra/database/` 模块，封装 sqlx 连接的 SQLite 数据库访问。

**当前状态**：`infra/database/mod.rs` 是空文件。

**Go SDK 参考**：
| Go 文件 | 内容 | 映射到的 Rust DAO |
|--------|------|------------------|
| `pkg/db/model/chat_log.go` | 消息表结构 | `message_dao.rs` |
| `pkg/db/model/conversation.go` | 会话表结构 | `conversation_dao.rs` |
| `pkg/db/model/user.go` | 用户表结构 | `user_dao.rs` |
| `pkg/db/model/friend.go` | 好友表结构 | `friend_dao.rs` |
| `pkg/db/model/group.go` | 群组表结构 | `group_dao.rs` |
| `pkg/db/model/black.go` | 黑名单表结构 | `black_dao.rs` |

**文件**：
```
infra/database/
├── mod.rs          # 模块导出
├── pool.rs         # 连接池初始化 + 自动迁移
├── models.rs       # 数据库实体（映射 local_chat_logs 等表）
├── message_dao.rs  # 消息增删查
├── conversation_dao.rs  # 会话增删查
├── user_dao.rs     # 用户增删查
├── friend_dao.rs   # 好友增删查
├── group_dao.rs    # 群组增删查
└── black_dao.rs    # 黑名单增删查
```

**已确定的设计**：
- DAO 粒度：每表一个文件，与 Go SDK model 文件一一对应
- 模型定义：`domain/model/` 下全新定义（不依赖旧 `im/model/`）
- 迁移执行：`sqlx::migrate!("migrations/")` 宏自动执行

**验收标准**：
- [ ] `pool.rs` 创建 SQLite 连接池 + 自动执行迁移
- [ ] 每个 DAO 的 CRUD 方法编译通过
- [ ] 单元测试通过（用 `sqlite::memory:` 测试）

---

### Task 2.2: 连接管理器 — 真实 WebSocket

**目标**：让 `core/connection/manager.rs` 使用 `tokio-tungstenite` 建立真实的 WebSocket 连接。

**Go SDK 参考**：`internal/interaction/long_conn_mgr.go`（长连接管理）、`internal/interaction/heartbeat.go`（心跳）

**当前状态**：有 connect/send/send_rpc/disconnect 方法，缺 read_loop、心跳、重连。

**设计**：
```rust
pub struct ConnectionManager {
    state: Arc<RwLock<ConnectionState>>,  // Disconnected/Connecting/Connected/Reconnecting
    event_bus: Arc<EventBus>,
    cancel_token: CancellationToken,
    writer: Arc<RwLock<Option<WsWriter>>>,
    pending_requests: Arc<RwLock<HashMap<String, oneshot::Sender<OpenIMResp>>>>,
    token: String,
    user_id: String,
}

impl ConnectionManager {
    fn new(event_bus: Arc<EventBus>, cancel_token: CancellationToken) -> Self;
    async fn connect(&self, ws_url: &str, token: &str, user_id: &str) -> Result<()>;
    async fn disconnect(&self);
    
    // 核心：发送请求并等待响应（JSON 信封 + protobuf data）
    async fn send_rpc<T: ProstMessage, R: ProstMessage + Default>(
        &self, req_identifier: i32, data: &T,
    ) -> Result<R>;
    
    // 内部：read_loop（接收+分发 RPC 响应/推送）
    // 内部：heartbeat（30s ping，60s 无 pong 断线重连）
    // 内部：reconnect（指数退避 1s→2s→4s...→60s）
}
```

**已确定的设计**：
- **消息格式**：JSON 信封 `{"reqIdentifier": ..., "sendID": ..., "data": ...}` + data 字段为 protobuf bytes
- **重连策略**：指数退避 1s→2s→4s→8s→16s→32s→60s（上限），参考 Go `long_conn_mgr.go`
- **心跳**：30s 间隔 ping，60s 无 pong 视为断线

**验收标准**：
- [ ] WebSocket 连接到真实服务器成功
- [ ] RPC 请求/响应正确（发消息得到回执）
- [ ] read_loop 正确分发推送消息
- [ ] 自动重连（断线后指数退避重连）
- [ ] 心跳保持 + pong 超时检测
- [ ] 事件（Connecting/Connected/Disconnected/ConnectFailed）正确发布

---

### Task 2.3: 消息处理器 — 收消息 + 写数据库

**目标**：让 `core/message/handler.rs` 收到推送消息后持久化到 SQLite。

**Go SDK 参考**：`internal/msg/msg_sync.go`（消息同步处理）、`internal/msg/msg_processor.go`（消息处理）

**当前状态**：LRU 内存去重，不写数据库。

**设计**：
```rust
pub struct MessageHandler {
    message_dao: Arc<MessageDao>,
    conversation_dao: Arc<ConversationDao>,
    event_bus: Arc<EventBus>,
}
```

**逻辑**（对齐 Go `msg_sync.go` 的 `handleNewMsg` 流程）：
1. ConnectionManager 的 read_loop 收到推送（push_identifier=2001）→ 解析 `sdkws::MsgData` 列表
2. 按 `conversation_id` 分组
3. 批量写入 `local_chat_logs`（`INSERT OR IGNORE`，靠 PK 去重）
4. 更新 `local_conversations.latest_msg`、`max_seq`、`unread_count`
5. 每条消息发布 `SdkEvent::NewMessage`

**去重**：数据库 PRIMARY KEY (conversation_id, client_msg_id) + INSERT OR IGNORE

**验收标准**：
- [ ] 消息正确写入 `local_chat_logs` 表
- [ ] 重复消息 INSERT OR IGNORE 正确跳过
- [ ] 会话 latest_msg/max_seq/unread_count 自动更新
- [ ] `SdkEvent::NewMessage` 正确发布

---

### Task 2.4: 消息同步器 — seq 拉取缺失消息

**目标**：从数据库读 seq，通过 WS 拉取缺失消息。

**Go SDK 参考**：`internal/msg/msg_sync.go`（`triggerPullMsgBySeq`、`pullMsgByRange`）

**当前状态**：内存 HashMap，不读数据库。

**设计逻辑**（对齐 Go `triggerPullMsgBySeq`）：
1. 从 `local_conversations` 读取各会话的 `max_seq`
2. 连接成功后（收到 `ConnEvent::Connected`），触发首次同步
3. 对每个会话，通过 WS `PULL_MSG_BY_RANGE`（req_identifier=1002）拉取 `(max_seq+1, server_max_seq)` 范围消息
4. 用 `Semaphore` 限制并发拉取数（如 5）
5. 拉到消息后交给 `MessageHandler::handle_push_messages()`

**首次同步**：本地无数据时，`max_seq=0`，拉取最近 N 条历史消息

**验收标准**：
- [ ] 从数据库正确加载各会话 max_seq
- [ ] 连接成功后自动触发首次同步
- [ ] 增量拉取 `(max_seq+1, server_max_seq)` 范围消息
- [ ] 并发拉取受 Semaphore 限制
- [ ] `SdkEvent::SyncStarted/SyncProgress/SyncFinished` 正确发布

---

### Task 2.5: 消息发送器 — 通过 WS 发送

**目标**：通过真实 WS 连接发送消息。

**Go SDK 参考**：`internal/msg/msg_sender.go`（消息发送队列）

**当前状态**：内存 channel，send_fn 是空占位。

**设计**：
- 持有 `Arc<ConnectionManager>`
- `send_message(msg: MsgStruct)` → 序列化 → `connection.send_rpc(SEND_MSG=1003, data)` → 等待响应
- 发送前写入 `local_sending_messages` 表（断线重发用）
- 成功：更新消息状态为 `SEND_SUCCESS`，发布 `SdkEvent::MessageSent`
- 失败：标记 `SEND_FAILED`，发布 `SdkEvent::MessageSendFailed`

**初版简化**：单 lane 发送（后续对齐 Go 的双 lane text/media 设计）

**验收标准**：
- [ ] 文本消息通过 WS `SEND_MSG` (1003) 成功发送
- [ ] 发送前写入 `local_sending_messages`
- [ ] `SdkEvent::MessageSent` / `MessageSendFailed` 正确发布

---

### Task 2.6: 会话管理 — 对接数据库

**目标**：让 `core/conversation/manager.rs` 读写 SQLite。

**Go SDK 参考**：`internal/conversation/conversation_mgr.go`

**当前状态**：内存 HashMap。

**设计**：直接对接 `ConversationDao` 的 CRUD，支持置顶/免打扰/草稿等属性设置。

**验收标准**：
- [ ] 会话列表从数据库正确读取
- [ ] upsert_conversation / delete_conversation 正确
- [ ] 置顶/免打扰/草稿设置正确

---

### Phase 2 验收

- [ ] `cargo check` 通过
- [ ] `cargo test --lib` 通过
- [ ] 连接 → 收消息 → 存数据库 → 发事件 全链路可运行

---

## Phase 3: 业务模块实体化

### Task 3.1: 用户管理器 — 对接 HTTP API

**Go SDK 参考**：`internal/user/user_mgr.go`

**当前状态**：内存 `Option<UserInfo>`。

**改造**：持有 `Arc<HttpApiClient>`，通过真实 HTTP 请求获取/更新用户信息。

### Task 3.2: 好友管理器 — 对接 HTTP API

**Go SDK 参考**：`internal/friend/friend_mgr.go`

**当前状态**：内存 HashMap。

**改造**：通过 HTTP API 管理好友/黑名单。

### Task 3.3: 群组管理器 — 对接 HTTP API

**Go SDK 参考**：`internal/group/group_mgr.go`

**当前状态**：内存 HashMap。

**改造**：通过 HTTP API 管理群组和成员。

### Task 3.4: 在线状态 — 对接 WebSocket 订阅

**Go SDK 参考**：`internal/online_status/online_status.go`

**当前状态**：内存 HashMap。

**改造**：通过 WebSocket 订阅/查询在线状态。

### Task 3.5: 文件上传

**Go SDK 参考**：`internal/file/file_uploader.go`

**当前状态**：空实现。

**改造**：预签名 URL → 上传文件 → 完成上传。

---

## Phase 4: SDK 门面完善 + 集成测试

### Task 4.1: 完善 OpenIMClient

- `ClientBuilder` 支持完整配置
- 生命周期管理（login → connect → sync → logout）

### Task 4.2: 集成测试

- 纯 Rust 集成测试（不依赖 Flutter）
- 测试用例：登录/连接/发消息/收消息/会话同步/好友CRUD

---

## Phase 5: FFI 桥接层 + 删除旧代码

### Task 5.1: FFI 桥接层

- 将 `api/bridge_*.rs` 从旧 `IMClient` 切换到新 `OpenIMClient`
- 保持 Flutter 侧接口兼容

### Task 5.2: 删除旧代码

- 删除 `im/` 目录（全部旧代码）
- 删除旧的 `api/bridge_*.rs`
- 清理 `Cargo.toml` 中不再需要的依赖

---

## 设计决策（已确定）

1. **权威参考**：Go SDK (`openim-sdk-core`) 为唯一业务逻辑来源
2. **模型层**：`domain/model/` 下全新定义，以 Go SDK `pkg/db/model/` 为参考
3. **DAO 粒度**：每表一个文件，与 Go SDK 的 model 文件一一对应
4. **消息发送队列**：初版单 lane 简单版，后续对齐 Go 双 lane
5. **重连策略**：指数退避（1s→2s→4s...→60s），参考 Go `long_conn_mgr.go`
6. **WS 消息格式**：JSON 信封 + protobuf data（对齐 Go SDK 和当前服务端）
7. **旧代码处理**：重构完成后 **完全删除** `im/` 目录 + 旧 `api/bridge_*.rs`

---

以上为最终计划，接下来开始 Phase 2 实施。
