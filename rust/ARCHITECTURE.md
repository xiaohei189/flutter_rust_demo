# Rust SDK 架构指南

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
