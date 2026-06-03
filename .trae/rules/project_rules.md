# Flutter Rust Demo 项目全局约定

## 项目概述

本项目是一个基于 Rust + Flutter 的跨平台 IM 应用，使用 `flutter_rust_bridge` (v2.11.1) 进行 FFI 通信。

### 项目结构
- `lib/` - Flutter/Dart 代码
- `rust/` - Rust SDK 实现
- `rust/src/api/` - FFI 桥接层（`bridge_*.rs`）
- `rust/src/im/` - IM 核心逻辑
- `rust/src/im/client/` - 客户端核心（连接、消息、会话等）
- `rust/src/im/dao/` - 数据访问层（SQLite）
- `rust/src/im/http_client/` - HTTP API 客户端
- `rust/src/im/model/` - 数据模型

### 相关项目参考（均在 `../` 同级目录下）

#### 核心参考
- `../protocol` - OpenIM 协议定义项目（**数据模型与 API 契约的权威来源**，包含 `.proto` 和生成的 `.rs`/`.pb.go`）
- `../openim-sdk-core` - Go 版本 SDK（**IM 核心逻辑参考实现**，所有业务逻辑对齐此项目）
- `../open-im-server` - IM 服务端源码（消息路由、群组、推送等后端服务）

#### 官方 Demo / 客户端示例
- `../openim-flutter-demo` - 官方 Flutter 示例（登录/注册/聊天 UI 参考）
- `../openim-electron-demo` - 官方 Electron 桌面端示例
- `../open-im-android-demo` - 官方 Android 端示例

#### 基础设施与配套服务
- `../openim-docker` - Docker Compose 部署配置（一键启动所有服务）
- `../chat` - 账号中间件服务（注册/登录/验证码/Token 管理，含 chat-api 和 chat-rpc）
- `../chat-server` - WebSocket 网关服务（长连接管理、消息分发、频道/消息推送）

---

## flutter_rust_bridge 框架约定

### 1. 版本与配置

- 使用 `flutter_rust_bridge = "=2.11.1"`（锁定版本）
- 配置文件：`flutter_rust_bridge.yaml`（项目根目录）
- 生成的代码位于 `lib/src/rust/` 和 `rust/src/frb_generated.rs`
- **禁止手动编辑生成的文件**（`frb_generated.rs`, `frb_generated.dart` 等）

### 2. FFI 函数定义规范

#### 基本结构
```rust
/// 函数文档（会同步到 Dart 侧）
#[flutter_rust_bridge::frb]
pub async fn function_name(param: String) -> Result<ReturnType> {
    let client = get_current_client().await?;
    let result = client.read().await.some_method(&param).await;
    result
}
```

#### 关键规则
- 所有导出函数必须添加 `#[flutter_rust_bridge::frb]` 注解
- 函数名使用 `snake_case`，会自动转换为 Dart 的 `camelCase`
- 参数和返回值类型必须是 FRB 支持的类型
- 异步函数返回 `Result<T>`，错误会自动映射到 Dart 侧

### 3. 类型映射

| Rust 类型 | Dart 类型 | 说明 |
|-----------|-----------|------|
| `String` | `String` | 字符串 |
| `i32` | `int` | 32位整数 |
| `i64` | `BigInt` | 64位整数 |
| `bool` | `bool` | 布尔值 |
| `Vec<T>` | `List<T>` | 列表 |
| `Option<T>` | `T?` | 可空类型 |
| `HashMap<K, V>` | `Map<K, V>` | 映射 |
| `Result<T>` | `Future<T>` (throws) | 异步结果 |
| `StreamSink<T>` | `Stream<T>` | 事件流 |

### 4. 结构体导出规范

```rust
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserInfo {
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    pub is_online: bool,
}
```

- 必须实现 `Clone`（FRB 要求）
- 使用 `serde` 进行 JSON 序列化时，添加 `rename_all = "camelCase"`
- 字段名使用 `snake_case`，需要 camelCase 时使用 `#[serde(rename = "...")]`

### 5. Stream/事件流处理

```rust
use crate::frb_generated::StreamSink;
use tokio_stream::StreamExt;

/// 连接状态事件流
#[flutter_rust_bridge::frb]
pub async fn connection_event_stream(sink: StreamSink<ConnEvent>) -> Result<()> {
    let client = get_current_client().await?;
    let stream = client.write().await.subscribe_conn_events();
    tokio::spawn(async move {
        let mut stream = stream;
        while let Some(ev) = stream.next().await {
            let _ = sink.add(ev);
        }
    });
    Ok(())
}
```

- 事件类型必须实现 `serde::Serialize`
- 使用 `tokio::spawn` 在后台发送事件
- `StreamSink` 是 FRB 提供的类型，用于向 Dart 侧推送事件

### 6. 代码生成流程

```bash
# 1. 修改 Rust FFI 代码后
cd rust && cargo check

# 2. 重新生成绑定
flutter_rust_bridge_codegen

# 3. 验证 Dart 侧编译
flutter analyze
```

### 7. 常见错误处理

#### RwLock 生命周期问题
```rust
// 错误：guard 在 await 期间持有锁
pub async fn bad() -> Result<()> {
    let client = get_current_client().await?;
    client.read().await.some_async_method().await  // 编译错误
}

// 正确：先获取结果
pub async fn good() -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.some_async_method().await;
    result
}
```

#### 类型不匹配
```rust
// Rust 方法接受 &str，FRB 函数参数用 String
pub async fn add_friend(user_id: String) -> Result<()> {
    let client = get_current_client().await?;
    client.read().await.add_friend(&user_id).await  // 添加 &
}
```

---

## Rust 代码约定

### 1. 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 结构体 | PascalCase | `IMClient`, `LocalGroup` |
| 函数/方法 | snake_case | `get_friend_list`, `create_group` |
| 常量 | UPPER_SNAKE_CASE | `SDK_VERSION`, `MAX_RETRY_COUNT` |
| 模块文件 | snake_case | `connection_handle.rs`, `message_handle.rs` |
| FFI 桥接文件 | `bridge_*.rs` | `bridge_friend.rs`, `bridge_group.rs` |

### 2. FFI 桥接层约定

- 所有导出给 Flutter 的函数必须放在 `rust/src/api/` 目录
- 使用 `bridge_*.rs` 命名格式区分功能模块
- 所有公共 FFI 函数必须添加 `#[flutter_rust_bridge::frb]` 注解
- 函数签名使用 `String` 而非 `&str`（FRB 要求）
- 错误统一使用 `anyhow::Result<T>` 返回

```rust
/// 添加好友
#[flutter_rust_bridge::frb]
pub async fn add_friend(user_id: String, req_msg: String) -> Result<()> {
    let client = get_current_client().await?;
    let result = client.read().await.add_friend(&user_id, &req_msg).await;
    result
}
```

### 3. 异步模式

- 所有 IO 操作必须使用 `async/await`
- 使用 `tokio` 作为异步运行时
- 共享状态使用 `Arc<RwLock<T>>` 或 `Arc<Mutex<T>>`
- 避免在 `RwLockReadGuard` 生命周期内执行 `.await`

```rust
// 正确：先获取结果再返回
pub async fn get_friend_list(filter_black: bool) -> Result<Vec<FriendInfoBridge>> {
    let client = get_current_client().await?;
    let friends = client.read().await.get_friend_list(filter_black).await?;
    Ok(friends.into_iter().map(FriendInfoBridge::from).collect())
}

// 错误：guard 在 await 期间持有锁
pub async fn bad_example() -> Result<()> {
    let client = get_current_client().await?;
    client.read().await.some_method().await  // guard 生命周期问题
}
```

### 4. 错误处理

- 使用 `anyhow::Result<T>` 作为返回类型
- 使用 `?` 操作符传播错误
- 自定义错误使用 `thiserror` 派生
- 关键错误使用 `tracing::error!` 记录日志

```rust
use anyhow::{Result, anyhow};

pub async fn create_group(...) -> Result<LocalGroup> {
    let resp = api.create_group(req).await?;
    resp.group_info.ok_or_else(|| anyhow!("创建群组失败"))
}
```

### 5. 模块组织

```
rust/src/
├── api/              # FFI 桥接层
│   ├── mod.rs        # 模块导出
│   ├── bridge_client.rs
│   ├── bridge_friend.rs
│   └── bridge_group.rs
├── im/
│   ├── client/       # 客户端核心
│   │   ├── client.rs
│   │   ├── listeners.rs
│   │   └── online_status.rs
│   ├── dao/          # 数据访问层
│   ├── http_client/  # HTTP API
│   ├── model/        # 数据模型
│   └── syncer/       # 同步器
└── frb_generated.rs  # FRB 自动生成（勿手动编辑）
```

---

## Dart/Flutter 代码约定

### 1. 状态管理

- 使用 Riverpod 进行状态管理
- Provider 定义在 `lib/providers/` 目录
- 服务类定义在 `lib/services/` 目录

### 2. 路由

- 使用 GoRouter 进行路由管理
- 路由定义在 `lib/router/app_router.dart`

### 3. 模型

- 使用 `freezed` 生成不可变数据类
- 使用 `json_serializable` 进行 JSON 序列化

---

## 数据库约定

### 1. 迁移文件

- 位置：`rust/migrations/`
- 命名格式：`YYYYMMDDHHMMSS_description.sql`
- 每次修改只新增文件，不修改已有文件

### 2. DAO 层

- 每个表对应一个 DAO 文件
- 使用 `sqlx` 进行数据库操作
- 所有 DAO 方法返回 `Result<T>`

---

## 核心开发原则（强制）

### 1. 参考 Protocol 协议定义

`../protocol` 是 OpenIM 所有服务的**协议定义权威来源**，包含：
- `.proto` 文件 — gRPC/Protobuf 接口和消息定义
- `*.rs` 文件 — 已生成的 Rust 数据结构（如 `openim.msg.rs`、`openim.sdkws.rs` 等）
- `*.pb.go` 文件 — 已生成的 Go 数据结构

**核心原则：**
- **Rust 侧的数据模型必须与 protocol 中的 `.rs` 文件对齐**（字段名、类型、枚举值）
- 当不确定某个数据结构的字段含义时，**优先查看 protocol 中的 `.proto` 定义**
- 如果 Rust 侧需要新增数据模型，必须先确认 protocol 中对应的 proto 定义是否已存在
- protocol 中已生成的 Rust 结构体（如 `sdkws.rs`、`msg.rs`）可直接参考，确保字段一致性

### 2. 参考 Go SDK 实现

当需要实现 IM 相关功能时，**必须参考 `../openim-sdk-core` 中的对应实现**。核心原则：

- **不能自己随意创建逻辑** — 所有 IM 核心逻辑（消息收发、去重、乐观更新、会话同步、事件处理等）必须严格对齐 Go SDK
- **Go SDK 是唯一权威参考** — 当遇到设计决策时，优先查看 Go SDK 如何处理，直接移植而非重新设计
- **数据模型、字段含义、事件类型**必须与 Go SDK 保持一致

### 3. IM 核心逻辑在 Rust SDK 中实现

- **核心 IM 功能必须下沉到 Rust SDK**（`rust/src/sdk/` 和 `rust/src/core/`）
- **Flutter/Dart 层只做 UI 展示和状态绑定**，不扩散 IM 业务逻辑
- **消息去重、clientMsgId 匹配、乐观更新、发送状态管理**等逻辑必须在 Rust SDK 中完成
- Flutter 侧只负责：调用 FFI 函数、监听事件流、更新 UI 状态

### 4. 禁止事项

- 禁止在 Flutter 层创建 IM 核心业务逻辑（如消息去重、发送队列、clientMsgId 生成等）
- 禁止脱离 Go SDK 自行设计 IM 相关逻辑
- 禁止在 Dart 侧生成临时 ID（如 `sending_xxx`）来模拟乐观更新

---

## 开发流程

### 1. 修改 Rust 代码后

```bash
# 1. 检查编译
cd rust && cargo check

# 2. 生成 FFI 绑定
flutter_rust_bridge_codegen

# 3. 运行 Flutter
flutter run
```

### 2. 参考 Go SDK 实现

当需要实现新功能时，参考 `../openim-sdk-core` 中的对应实现：
- 方法签名保持一致
- 错误处理逻辑对齐
- 数据模型字段对应

---

## 代码审查检查点

- [ ] FFI 函数是否正确使用 `#[flutter_rust_bridge::frb]`
- [ ] 异步函数是否正确处理 `RwLock` 生命周期
- [ ] 错误是否使用 `anyhow::Result` 返回
- [ ] 新增数据库迁移是否正确命名
- [ ] 数据模型是否与 protocol 中的 `.proto` / `.rs` 定义对齐
- [ ] 模型是否与 Go SDK 对齐

---

## SDK 重写进度（简要）

> 完整文档：`docs/SDK_PROGRESS.md`，详细设计：`docs/sdk-spec/`

- Phase 1-4：**已完成**（基础设施、核心模块、集成测试、FFI 桥接）
- Phase 5（进行中）：
  - ✅ **P0+P1 全部完成**
  - ✅ **P2 部分完成**：消息/连接 FFI 补齐（转发/URL消息/未读数/已读标记/版本/用户ID/前后台/网络状态）
  - ⏳ **P2 待做**：MessageBatcher、双Lane队列、分页搜索、syncFlag多阶段同步
- 总体完成度：**~95%**
- FFI 覆盖：116 个函数 | Go SDK API 覆盖：88%
