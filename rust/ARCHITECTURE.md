# Rust SDK 架构指南

> ⚠️ **【迁移中】目标五层架构（api/sdk/core/event/infra/domain）。当前 `domain/` 与 `infra/`（db/http/cache/logger/file/util）已迁入**；`client, connection, conversation, event, ffi, friend, group, message, user` 等仍为扁平模块，后续按计划迁入 `core/sdk/api`。
> 现状与规划的对照见 [docs/README.md](../docs/README.md#架构对齐现状-2026-08)。

## 分层架构（从底层到上层）

`
api/         FFI 桥接层 — 供 flutter_rust_bridge 生成的代码调用
sdk/         SDK 外观层 — 对外暴露统一 API
core/        核心业务逻辑 — 连接管理、消息收发、会话同步
event/       事件总线 — 模块间解耦通信（广播 + 点对点）
infra/       基础设施 — 数据库、HTTP 客户端、缓存、文件、日志
domain/      领域层 — 实体、端口、仓储接口、错误、常量
`

## 异步边界 (Async Boundary)

### 必须 async 的层

| 层 | 原因 |
|----|------|
| infra/database/ | SQLite 数据库操作（使用 sqlx + tokio） |
| infra/http/ | HTTP/HTTPS 网络请求（使用 reqwest） |
| core/connection/ | WebSocket 长连接、心跳、重连 |
| core/message/send/ 和 eceive/ | 网络 I/O + 数据库写入 |
| infra/logger/ | 文件日志写入（使用 tracing-appender） |

### 应该 sync 的层

| 层 | 原因 |
|----|------|
| domain/ | 纯数据模型、枚举、常量，无 I/O |
| vent/ | 内存消息传递，无阻塞操作 |
| infra/cache/ | 内存缓存操作（LRU HashMap） |
| 纯计算逻辑 | 序列化/反序列化、校验、转换 |

### 选择指南

1. **函数签名**：如果函数内部有任何 .await 调用，标记为 sync fn
2. **锁选择**：
   - 读多写少 + 持锁时间短 → std::sync::RwLock（当前 UserId 的做法）
   - 写频繁或持锁时间长 → 	okio::sync::RwLock
   - 简单互斥 → std::sync::Mutex（如 EventSender 的 tx 字段）
3. **避免**：sync fn 包装同步阻塞操作（如 std::sync::RwLock::read()），这不会阻塞 tokio 工作线程，但会误导调用方

## 事件系统

### EventBus vs EventSender

| 特性 | EventBus | EventSender |
|------|----------|-------------|
| 模式 | 广播 (broadcast) | 点对点 (mpsc) |
| 订阅者 | 多个 | 单一 |
| 背压 | 滞后丢弃 | 无界 |
| 事件丢失 | 可能 | 不会 |

### 选择指南

- 需要多个模块同时收到同一事件 -> EventBus
- 需要确保事件不丢失 -> EventSender
- 登录前的事件缓冲 -> EventSender（先创建 channel，再设置 sender）

## 依赖注入

SDK 不使用 DI 容器。所有组件通过 OpenIMClientBuilder 在 uild() 中手动创建和注入。

`ust
// 组件创建集中在 builder.rs 的一个方法中
pub async fn build(self) -> Result<OpenIMClient> {
    let event_bus = Arc::new(EventBus::new());
    let context = Arc::new(RuntimeContext::new(...).await?);
    let connection = Arc::new(ConnectionManager::new(...));
    // ... 12+ 个组件依次创建
}
`

## 配置管理

连接参数（心跳间隔、重连延迟等）集中定义在 core/connection/manager.rs 中作为 pub const。
SDK 初始化参数在 sdk/config.rs 的 ClientConfig 中。

## 五层迁移计划（api/sdk/core/domain/infra）

> 目标：把当前扁平结构逐步收拢到 `api/ sdk/ core/ domain/ infra/` 五个目录，每层有 `mod.rs`，依赖只允许上层引用下层。

### 现状模块归属映射

| 当前模块 | 目标层 | 说明 |
|----------|--------|------|
| `ffi/`、`frb_generated.rs`、`lib.rs` 的对外函数 | `api/` | FFI 桥接与 frb 绑定入口 |
| `client/`、`builder`、连接/会话/消息/好友/群组/用户的对外入口 | `sdk/` | SDK 外观与 `OpenIMClient` 组装 |
| `connection/`、`conversation/`、`message/send`、`message/receive`、`message/operate`、`file/upload`、`user/online` | `core/` | 连接、收发、同步、上传等核心业务 |
| `event/` | `core/event/` 或独立 `event/` | 事件总线（广播 + 点对点） |
| `model/`、`constant/`、`error/` | `domain/` | 数据模型、枚举、错误类型 |
| `db/`、`http/`、`cache/`、`logger/`、`file/`、`util.rs` | `infra/` | 存储、网络、缓存、日志等基础设施 |

### 迁移步骤（每步保持 `cargo test --lib` 与 `cargo clippy` 通过）

1. 建立五个目录与 `mod.rs`，先只做 re-export，不改业务代码。
2. 移动 `domain/`（`model/ constant/ error/`）并更新引用。
3. 移动 `infra/`（`db/ http/ cache/ logger/ file/ util.rs`）并更新引用。
4. 移动 `core/`（`connection/ conversation/ message/ file/upload user/online event/`）并更新引用。
5. 移动 `sdk/`（`client/` 与入口组装）。
6. 收口 `api/`（`ffi/` 与 `lib.rs` 导出），确认 frb 生成不受影响。
7. 删除空目录，整理依赖方向，补齐 `docs/sdk-spec/` 与 `rust/ARCHITECTURE.md` 现状标注。
8. 验收：`rust/scripts/test-fast.ps1`（单元 + 离线 + clippy）全绿；需要时跑 smoke 集成。

### 边界规则

- `domain/` 不依赖 `infra/ core/ sdk/ api/`。
- `infra/` 不依赖 `core/ sdk/ api/`（可依赖 `domain/` 的类型）。
- `core/` 只依赖 `domain/` 与 `infra/`。
- `sdk/` 依赖 `core/ domain/ infra/`，作为对外外观。
- `api/` 只做 FFI 适配，调用 `sdk/` 或 `core/`，不承载业务。
