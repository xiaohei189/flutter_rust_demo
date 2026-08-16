# 项目架构文档

## 概述

Flutter + Rust 即时通讯应用，基于 OpenIM 协议，使用 `flutter_rust_bridge` v2.11.1 进行跨语言通信。Rust 侧实现完整的 IM SDK，Dart 侧负责 UI 和状态管理。

## 分层架构

```
┌─────────────────────────────────────────────────────┐
│  Flutter UI (lib/)                                   │
│  ┌───────────┐ ┌──────────┐ ┌───────────────────┐   │
│  │  Screens  │ │  Widgets │ │  Theme (AppTheme)  │   │
│  └───────────┘ └──────────┘ └───────────────────┘   │
│  ┌───────────┐ ┌──────────┐ ┌───────────────────┐   │
│  │   Models  │ │  Router  │ │    Extensions      │   │
│  └───────────┘ └──────────┘ └───────────────────┘   │
├─────────────────────────────────────────────────────┤
│  State Management (Riverpod)                         │
│  ┌──────────────────────────────────────────────┐   │
│  │       MessageServiceNotifier (核心)           │   │
│  │  ┌─────────┐ ┌──────────┐ ┌──────────────┐  │   │
│  │  │ Conv.   │ │ Messages │ │ User Profiles │  │   │
│  │  │ List    │ │ (per ID) │ │ (缓存)        │  │   │
│  │  └─────────┘ └──────────┘ └──────────────┘  │   │
│  └──────────────────────────────────────────────┘   │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐     │
│  │  Conv.   │ │ Message  │ │ Connection/Friend│     │
│  │ Provider │ │ Provider │ │ /Group Providers │     │
│  └──────────┘ └──────────┘ └──────────────────┘     │
├─────────────────────────────────────────────────────┤
│  Services (lib/data/services/)                            │
│  ┌──────────┐ ┌──────────────┐ ┌────────────────┐   │
│  │ ImClient │ │ Navigation   │ │ User/Friend/    │   │
│  │ (单例)   │ │ Service      │ │ Group Services  │   │
│  └──────────┘ └──────────────┘ └────────────────┘   │
├─────────────────────────────────────────────────────┤
│  flutter_rust_bridge (FFI)                           │
│  lib/generated/rust/ ← 自动生成 → rust/src/api/      │
├─────────────────────────────────────────────────────┤
│  Rust SDK (rust/src/)                                │
│  ┌────────────────────────────────────────────────┐ │
│  │  api/          FFI 桥接层 (OpenIMBridgeClient)  │ │
│  ├────────────────────────────────────────────────┤ │
│  │  sdk/          SDK 入口 (OpenIMClient)          │ │
│  ├────────────────────────────────────────────────┤ │
│  │  core/         业务逻辑层                        │ │
│  │  ├─ connection  WebSocket 连接/心跳/重连         │ │
│  │  ├─ message     消息处理/发送/同步               │ │
│  │  ├─ conversation 会话管理                        │ │
│  │  ├─ friend      好友管理                         │ │
│  │  ├─ group       群组管理                         │ │
│  │  ├─ user        用户管理                         │ │
│  │  ├─ online      在线状态                         │ │
│  │  ├─ notification 通知处理                        │ │
│  │  └─ file        文件上传                         │ │
│  ├────────────────────────────────────────────────┤ │
│  │  domain/       领域模型                          │ │
│  │  ├─ model      数据模型                          │ │
│  │  ├─ event      事件总线/事件类型                  │ │
│  │  ├─ error      错误类型 (SdkError)               │ │
│  │  ├─ listener   监听器接口/适配器                  │ │
│  │  ├─ config     配置 (ClientConfig)               │ │
│  │  └─ constant   枚举/常量                         │ │
│  ├────────────────────────────────────────────────┤ │
│  │  infra/        基础设施                          │ │
│  │  ├─ database   SQLite (sqlx) + DAO              │ │
│  │  ├─ http       HTTP 客户端 + API 路由            │ │
│  │  ├─ cache      内存缓存                          │ │
│  │  ├─ file       文件上传                          │ │
│  │  └─ logger     tracing + OpenTelemetry          │ │
│  ├────────────────────────────────────────────────┤ │
│  │  (openim-protocol 外部 crate 提供协议类型)      │ │
│  │  └─ openim_protocol 重导出 + WS 类型             │ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

## 目录结构

### Dart 侧 (`lib/`)

| 目录 | 用途 |
|------|------|
| `lib/ui/<feature>/views/` | 各 feature 页面（早期曾用 `lib/screens/`，已迁移到 feature 目录） |
| `lib/ui/core/widgets/` | 18 个可复用 UI 组件 |
| `lib/data/services/` | 13 个业务服务（IM 客户端、消息、用户等） |
| `lib/providers/` | Riverpod 状态管理 |
| `lib/data/` | 数据层：Repository 等（好友功能已作为 pilot 落地） |
| `lib/domain/` | 领域层：领域模型、Use Case |
| `lib/ui/` | feature 化 UI：views、view_models |
| `lib/domain/models/` | Freezed 数据模型 |
| `lib/router/` | go_router 路由配置 |
| `lib/ui/core/theme/` | AppTheme 颜色/样式 |
| `lib/ui/core/utils/` | 工具类（日志、存储） |
| `lib/ui/core/extensions/` | 扩展方法 |
| `lib/generated/rust/` | flutter_rust_bridge 自动生成的 Dart 绑定 |

### 目标目录结构（渐进迁移）

UI 按 feature 组织，Data/Domain 按类型组织，依赖方向固定为：

```text
UI (views/view_models) -> Domain (domain/models/use_cases) -> Data (repositories/services) -> FFI
```

```text
lib/
├── data/
│   ├── models/         # API/raw 模型
│   ├── repositories/   # Repository 实现
│   └── data/services/       # API 客户端、本地存储封装
├── domain/
│   ├── models/         # 领域模型
│   └── use_cases/      # 复杂业务逻辑（按需）
└── ui/
    ├── core/           # 共享 widgets、theme、view_models
    ├── auth/
    ├── profile/
    ├── contacts/
    ├── groups/
    ├── chat/
    │   ├── view_models/
    │   └── views/
    └── discover/
```

当前联系人、群组、聊天、认证、个人资料和发现页面已按 feature 组织：`lib/ui/contacts/`、`lib/ui/groups/`、`lib/ui/chat/`、`lib/ui/auth/`、`lib/ui/profile/`、`lib/ui/discover/`，共享组件、主题和扩展在 `lib/ui/core/`，聊天专属组件在 `lib/ui/chat/widgets/`，领域模型在 `lib/domain/models/`。数据层统一走 `lib/data/repositories/` 与 `lib/data/services/`，`MessageServiceNotifier` 位于 `lib/ui/chat/view_models/`，FFI 数据操作收口到 `MessageRepository`，设置与在线状态/文件打开收口到 `SettingsRepository`、`ChatAuxRepository`。`FriendService`、`GroupService`、`UserService` 已抽象为接口，便于 Repository 单测。

### Rust 侧 (`rust/src/`)

> ⚠️ **实际为扁平结构**，下表"目标"列为规划中的五层（见 CLAUDE.md），**迁移未完成**。

| 目录 | 用途 |
|------|------|
| `rust/src/`（**实际**） | 扁平平铺：`cache, client, connection, constant, conversation, db, error, event, ffi, file, friend, group, http, logger, message, model, user` |
| `rust/src/api/`（目标） | FFI 桥接层，暴露给 Dart 的 API |
| `rust/src/sdk/`（目标） | SDK 入口，组装所有核心模块 |
| `rust/src/core/`（目标） | 核心业务逻辑（连接、消息、会话、好友、群组等） |
| `rust/src/domain/`（目标） | 领域模型、事件、错误、配置 |
| `rust/src/infra/`（目标） | 基础设施（数据库、HTTP、缓存、日志） |
| `openim-protocol` crate（`../../protocol`） | 协议层（OpenIM protobuf） |

## 数据流

### 发送消息

```
[ChatDetailScreen]
  → ChatInput.onSend
  → MessageServiceNotifier.sendTextMessage()
  → OpenImBridgeClient.sendTextMessage()  // FFI
  → OpenIMClient.send_text_message()
  → MessageService: 创建 protobuf MsgData, 写入 SQLite (status=Sending)
  → ConnectionManager: WebSocket 发送 (protobuf + gzip)
  → 服务器响应: 更新 DB status=Sent, 通知 UI
```

### 接收消息

```
[Server] --WebSocket-->
  → ConnectionManager: 接收 protobuf PushMessages
  → MessageBatcher: 批量暂存
  → MessageHandler: 解析消息类型, 写入 SQLite
  → 发布 ConversationEvent 到 mpsc channel
  → StreamSink → Dart Stream
  → MessageServiceNotifier: 更新状态
  → Riverpod 通知 UI 重建
```

### 事件系统

```
事件流向:
  Core Service → Listener trait（唯一出口）→ EventHub → 领域事件通道 → StreamSink → Dart Stream
```

## 状态管理

使用 **Riverpod** (`flutter_riverpod` v2.4.9)：

- **`MessageServiceNotifier`** — 核心 StateNotifier，持有所有运行时状态：
  - 会话列表 `List<LocalConversation>`
  - 消息映射 `Map<String, List<MessageInfo>>` (按 conversationId)
  - 用户资料缓存 `Map<String, UserInfo>`
  - 连接状态、同步状态
- 其他 Provider（`ConversationListNotifier`, `MessageListNotifier`, `ConnectionNotifier` 等）通过 `ref.listen(messageServiceProvider)` 监听核心状态变化，派生各自的专用状态

## 导航

使用 **go_router** v14.0.0：

| 路由 | 页面 |
|------|------|
| `/` | SplashScreen（自动登录） |
| `/login` | LoginScreen |
| `/main` | MainScreen（底部 Tab） |
| `/chat/:id` | ChatDetailScreen |
| `/chat/:id/settings` | ChatSettingsScreen |
| `/group/:id/info` | GroupInfoScreen |
| `/profile/my` | MyProfileScreen |
| `/profile/user/:id` | UserProfileScreen |
| `/search` | SearchScreen |
| `/friend-list` | FriendListScreen |
| `/friend-requests` | FriendRequestsScreen |
| `/group-list` | GroupListScreen |
| `/create-group` | CreateGroupScreen |
| `/add-contact` | AddContactScreen |
| `/contact-picker` | ContactPickerScreen |

`NavigationService` 单例提供 `GlobalKey<NavigatorState>` 用于 Service 层无 Context 导航。

## IM 协议

### 连接流程

1. `OpenIMClient::new()` 创建所有 Manager、EventHub（含 6 个领域事件通道）、Cache、CancelToken
2. EventHub 在登录前创建，事件从登录起即被缓存，防止丢失
3. `connect()` 建立 WebSocket 连接到 `ws://host:10001`
4. 发送 protobuf 登录请求，启动心跳（30s 间隔，60s pong 超时）
5. 连接成功后：`sync_friends()`, `sync_groups_incremental()`, `incr_sync_conversations()`

### 通信方式

- **WebSocket** (端口 10001)：实时消息推送、RPC 调用
- **HTTP REST** (端口 10002)：用户/好友/群组/会话 CRUD、文件上传

### 消息类型 (ContentType)

| 类型 | 值 | 说明 |
|------|-----|------|
| Text | 101 | 文本消息 |
| Picture | 102 | 图片 |
| Sound | 103 | 语音 |
| Video | 104 | 视频 |
| File | 105 | 文件 |
| AtText | 106 | @消息 |
| Merger | 107 | 合并转发 |
| Card | 108 | 名片 |
| Location | 109 | 位置 |
| Quote | 114 | 引用回复 |
| Face | 115 | 表情 |
| Typing | 113 | 正在输入 |

### 会话类型 (SessionType)

| 类型 | 值 | 说明 |
|------|-----|------|
| SingleChat | 1 | 单聊 |
| WriteGroupChat | 2 | 读写群聊 |
| ReadGroupChat | 3 | 只读群聊 |
| NotificationChat | 4 | 通知会话 |

## 数据持久化

- **SQLite** 数据库：`{data_dir}/openim_{platform_id}.db`
- **连接池**：sqlx，最大 5 连接
- **表**：`local_chat_logs`, `local_conversations`, `local_users`, `local_friends`, `local_groups`, `local_group_members`, `local_blacks`, `notification_seqs`, `sending_messages`, `sync_versions`, `uploads`

## 日志/追踪

### Dart 侧

- `app_logger.dart`：使用 `logger` 包，`[file:line]` 格式输出到控制台和文件

### Rust 侧

- **框架**：`tracing` + `tracing-subscriber` + `tracing-opentelemetry` + `opentelemetry`
- **输出**：文件（`tracing-appender` rolling daily）+ 控制台（ANSI 彩色）+ JSON
- **OTel 集成**：`OtelTraceIdLayer` 在 `on_enter` 时从 span extensions 提取 trace_id 并记录到 span 字段
- **宏**：`sdk_info!`, `sdk_debug!`, `sdk_warn!`, `sdk_error!`, `sdk_span!`
- **Span**：`#[tracing::instrument]` 标注关键桥接方法

## 跨语言桥接

- **配置**：`flutter_rust_bridge.yaml`
- **Opaque 类型**：`OpenIMBridgeClient` 标记 `#[frb(opaque)]`，Dart 不可检查内部
- **异步**：所有桥接方法 `pub async fn` 返回 `Result<T>`
- **事件流**：`StreamSink<T>` 将 Rust mpsc channel 转发到 Dart Stream
- **序列化**：Rust 类型 `#[derive(Serialize, Deserialize)]` + `#[serde(rename_all = "camelCase")]`
- **代码生成**：修改 Rust API 后运行 `flutter_rust_bridge_codegen generate`
