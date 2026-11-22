# Rust SDK 架构指南

> 当前 `rust/` 是 Cargo workspace：`im-core` 拥有平台无关业务核心，Flutter
> Rust Bridge 适配 crate 只保留 FFI 入口、FRB 生成代码和类型 mirror。

## Workspace 边界

```text
workspace/
  im-core/                   # 独立 Git/Cargo 项目，不依赖 Flutter、NSH 或本地 RPC
    Cargo.toml
    migrations/
    src/{core,domain,infra,sdk}
    tests/fixtures/
  flutter_rust_demo/rust/
    Cargo.toml                # Flutter FFI 适配 crate
    src/api/                  # Flutter 专属 FFI 入口
    src/frb_generated.rs      # FRB 生成代码
    src/{core,domain,infra,sdk} # 脚本生成的 FRB mirror 兼容模块
    scripts/generate-frb-mirrors.ps1
```

依赖方向固定为：

```
Flutter Dart -> Flutter FFI 适配 crate -> im-core
NSH TSX     -> NSH native 适配 crate   -> im-core
```

`im-core` 可以持有连接 OpenIM 服务端的 WebSocket 客户端和事件通道，但不得直接
包含 Flutter Rust Bridge、NSH 组件或某个项目的本地 WebSocket RPC 协议。

`openim-protocol` 同样保持中性：只包含 prost、serde 和协议字段映射。Flutter
需要暴露协议 DTO 时，在 Flutter 适配 crate 定义 mirror 或桥接 DTO；NSH 使用
自己的 native DTO，不向共享协议层反向添加桥接依赖。

## 分层架构（从底层到上层）

```
api/         FFI 桥接层 — 供 flutter_rust_bridge 生成的代码调用
sdk/         SDK 外观层 — 对外暴露统一 API（OpenIMClient / builder / client 子模块）
core/        核心业务逻辑 — 连接管理、消息收发、会话同步、事件分发
infra/       基础设施 — 数据库、HTTP 客户端、缓存、文件、日志
domain/      领域层 — 实体、错误、常量
```

## 异步边界 (Async Boundary)

### 必须 async 的层

| 层 | 原因 |
|----|------|
| infra/db/ | SQLite 数据库操作（使用 sqlx + tokio） |
| infra/http/ | HTTP/HTTPS 网络请求（使用 reqwest） |
| core/connection/ | WebSocket 长连接、心跳、重连 |
| core/message/send/ 和 core/message/receive/ | 网络 I/O + 数据库写入 |
| infra/logger/ | 文件日志写入（使用 tracing-appender） |

### 应该 sync 的层

| 层 | 原因 |
|----|------|
| domain/ | 纯数据模型、枚举、常量，无 I/O |
| core/event/ | 内存消息传递，无阻塞操作 |
| infra/cache/ | 内存缓存操作（LRU HashMap） |
| 纯计算逻辑 | 序列化/反序列化、校验、转换 |

### 选择指南

1. **函数签名**：如果函数内部有任何 `.await` 调用，标记为 `async fn`
2. **锁选择**：
   - 读多写少 + 持锁时间短 → `std::sync::RwLock`（当前 `UserId` 的做法）
   - 写频繁或持锁时间长 → `tokio::sync::RwLock`
   - 简单互斥 → `std::sync::Mutex`（如 `EventSender` 的 `tx` 字段）
3. **避免**：`async fn` 包装同步阻塞操作（如 `std::sync::RwLock::read()`），这不会阻塞 tokio 工作线程，但会误导调用方

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

SDK 不使用 DI 容器。所有组件通过 `OpenIMClientBuilder` 在 `build()` 中手动创建和注入。

```rust
// 组件创建集中在 sdk/client/builder.rs 的 build() 方法中
pub async fn build(self) -> Result<OpenIMClient> {
    let event_bus = Arc::new(EventBus::new());
    let context = Arc::new(RuntimeContext::new(...).await?);
    let connection = Arc::new(ConnectionManager::new(...));
    // ... 12+ 个组件依次创建
}
```

## 配置管理

连接参数（心跳间隔、重连延迟等）集中定义在 `core/connection/manager.rs` 中作为 pub const。
SDK 初始化参数在 `sdk/client/config.rs` 的 `ClientConfig` 中。

## 分层边界规则

- `domain/` 不依赖 `infra/ core/ sdk/ api/`。
- `infra/` 不依赖 `core/ sdk/ api/`（可依赖 `domain/` 的类型）。
- `core/` 只依赖 `domain/` 与 `infra/`。
- `sdk/` 依赖 `core/ domain/ infra/`，作为对外外观。
- `api/` 只做 FFI 适配，调用 `sdk/` 或 `core/`，不承载业务。

## 已知边界待办

目录迁移已完成，以下 cross-layer seam 作为后续清理项（当前不破坏编译与测试）：

- `core/message/operate/*` 引用 `sdk::client::{GetHistoryMessagesReq, GetHistoryMessagesResult, SearchMessagesReq}`：这三个是 SDK 契约 DTO，后续应下沉到 `domain/` 并让 frb 重新生成后移除 sdk 定义。
- `core/message/notification.rs` 引用 `sdk::friend::service::FriendService` / `sdk::group::service::GroupService` 具体类型：后续可在 `domain/` 定义端口 trait，由 sdk 实现，core 只依赖 trait。

## 迁移历史

2026-08-17～08-21 按 `domain → infra → core → sdk → api` 顺序完成五层迁移（原「模块归属映射 + 迁移步骤」清单已随迁移落地失效，不再保留）。验收方式：`rust/scripts/test-fast.ps1`（单元 + 离线 + clippy）。
