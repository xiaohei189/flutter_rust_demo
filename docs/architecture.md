# 项目架构文档

## 概述

Flutter + Rust 即时通讯应用，基于 OpenIM 协议，使用 `flutter_rust_bridge`
v2.12.0 进行跨语言通信。平台无关的 Rust 业务核心位于同级独立项目 `im-core`
crate；Flutter 只保留自己的 FFI 适配层，Dart 侧负责 UI 和状态管理。

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
│  lib/generated/rust/ ← 自动生成 → rust/src/api/ffi/  │
├─────────────────────────────────────────────────────┤
│  Flutter Rust Bridge 适配层 (rust/)                  │
│  ┌────────────────────────────────────────────────┐ │
│  │  api/          FFI 桥接层 (OpenIMBridgeClient)  │ │
│  ├────────────────────────────────────────────────┤ │
│  │  core/domain/infra/sdk                         │ │
│  │    FRB mirror 兼容模块（脚本生成）              │ │
│  └────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│  平台无关核心 (../im-core/)                          │
│  ┌────────────────────────────────────────────────┐ │
│  │  sdk/          SDK 入口 (OpenIMClient)          │ │
│  ├────────────────────────────────────────────────┤ │
│  │  core/         业务逻辑层                        │ │
│  │  ├─ connection  WebSocket 连接/心跳/重连/RPC     │ │
│  │  ├─ message     消息处理/发送/同步/搜索           │ │
│  │  ├─ conversation 会话管理                        │ │
│  │  ├─ event      事件总线/Listener/领域事件         │ │
│  │  └─ user        用户与在线状态                    │ │
│  ├────────────────────────────────────────────────┤ │
│  │  domain/       领域层                            │ │
│  │  ├─ model      数据模型（含 local.rs DB 模型）    │ │
│  │  ├─ error      错误类型 (SdkError)               │ │
│  │  └─ constant   枚举/常量                         │ │
│  ├────────────────────────────────────────────────┤ │
│  │  infra/        基础设施                          │ │
│  │  ├─ db         SQLite (sqlx) + DAO              │ │
│  │  ├─ http       HTTP 客户端 + API 路由            │ │
│  │  ├─ cache      内存缓存                          │ │
│  │  ├─ file       文件上传                          │ │
│  │  └─ logger     tracing + OpenTelemetry          │ │
│  ├────────────────────────────────────────────────┤ │
│  │  (openim-protocol 外部 crate 提供纯协议类型)     │ │
│  │  └─ prost + serde，无 Flutter/NSH 依赖           │ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

## 目录结构

### Dart 侧 (`lib/`)

| 目录 | 用途 |
|------|------|
| `lib/ui/<feature>/views/` | 各 feature 页面（`xxx_screen.dart`；早期 `lib/screens/` 已迁移） |
| `lib/ui/<feature>/view_models/`、`providers/`、`widgets/` | feature 内状态、依赖与小部件 |
| `lib/ui/core/widgets/` | 9 个共享 UI 组件（头像、卡片、状态视图等） |
| `lib/ui/core/theme/` | 主题与语义色板（`context.appColors`、`AppIconColors`） |
| `lib/ui/core/extensions/` | 扩展方法 |
| `lib/application/` | 状态与用例：`auth/`、`chat/`（`MessageServiceNotifier` 等）、`topics/` |
| `lib/data/repositories/` | Repository 实现（message/group/friend/topic 等） |
| `lib/data/services/` | 40+ 业务服务与 API 客户端（`im_client`、`topic_api` 等） |
| `lib/data/mappers/` | raw/generated 模型 ↔ 领域模型映射 |
| `lib/domain/` | 领域层：`models/`（Freezed 数据模型）、`message_sorting.dart` |
| `lib/providers/` | 基础设施依赖桥（`im_providers.dart` 等） |
| `lib/router/` | go_router 路由配置（按领域拆分 `*_routes.dart`） |
| `lib/core/utils/app_logger.dart` | 日志（`appLog`） |
| `lib/generated/rust/` | flutter_rust_bridge 自动生成的 Dart 绑定 |

### 目录组织与依赖方向

UI 按 feature 组织，application 按领域组织，data/domain 按类型组织，依赖方向固定为：

```text
UI (lib/ui) -> Application (lib/application) -> Data (lib/data) -> generated/rust
                     ↓
                Domain (lib/domain)
```

```text
lib/
├── application/        # 状态与用例（auth/ chat/ topics/）
├── core/utils/         # 基础工具（app_logger）
├── data/
│   ├── mappers/        # raw/generated ↔ domain 映射
│   ├── repositories/   # Repository 实现
│   └── services/       # API 客户端、本地存储封装
├── domain/
│   ├── models/         # 领域模型（Freezed）
│   └── message_sorting.dart
├── providers/          # Riverpod 基础设施依赖桥
├── router/             # go_router 路由（按领域拆分）
└── ui/
    ├── core/           # 共享 widgets、theme、extensions
    ├── auth/ chat/ contacts/ groups/ profile/
    ├── topics/ workbench/ shared/ shell/ previews/
    └── <feature>/{views,view_models,providers,widgets}/
```

当前会话、通讯录、群组、话题、工作台、认证与个人资料页面均按 feature 组织：`lib/ui/{chat,contacts,groups,topics,workbench,auth,profile}/`，共享组件、主题和扩展在 `lib/ui/core/`，聊天专属组件按职责在 `lib/ui/chat/widgets/{list,bubble,composer,menu,shared}/`，领域模型在 `lib/domain/models/`。状态与用例集中在 `lib/application/{auth,chat,topics}/`（`MessageServiceNotifier` 位于 `lib/application/chat/`），数据层统一走 `lib/data/repositories/` 与 `lib/data/services/`，FFI 数据操作收口到 Repository（如 `MessageRepository`、`TopicRepository`），设置与在线状态/文件打开收口到 `SettingsRepository`、`ChatAuxRepository`。`FriendService`、`GroupService`、`UserService` 已抽象为接口，便于 Repository 单测。

### Rust 侧 (`rust/src/`)

五层迁移已于 2026-08 完成（详见 [rust/ARCHITECTURE.md](../rust/ARCHITECTURE.md)）：

| 目录 | 用途 |
|------|------|
| `rust/src/api/ffi/` | FFI 桥接层，暴露给 Dart 的 API（`OpenIMBridgeClient` 等） |
| `rust/src/sdk/` | SDK 外观：`client/`（OpenIMClient/builder/context）、`friend/`、`group/` |
| `rust/src/core/` | 核心业务：`connection/`、`message/`（send/receive/operate）、`conversation/`、`event/`、`user/` |
| `rust/src/domain/` | 领域层：`model/`（含 `local.rs` DB 模型）、`constant/`、`error/`、`util.rs` |
| `rust/src/infra/` | 基础设施：`db/`（sqlx DAO）、`http/`、`cache/`、`file/`、`logger/` |
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

- **`MessageServiceNotifier`** — 核心状态源（`lib/application/chat/`），持有所有运行时状态：
  - 会话列表 `List<LocalConversation>`
  - 消息映射 `Map<String, List<MessageInfo>>` (按 conversationId)
  - 用户资料缓存 `Map<String, UserInfo>`
  - 连接状态、同步状态
- 派生状态由 Provider + `select` 计算，禁止用 `ref.listen` 把全局状态复制进本地 Notifier（纯展示格式化除外）；feature 级 Provider/Store 位于 `lib/ui/<feature>/providers/` 与 `lib/application/*/stores/`。

## 导航

使用 **go_router**（路由常量见 `lib/router/app_paths.dart`，按领域拆分 `*_routes.dart`）：

| 路由 | 页面 |
|------|------|
| `/` | SplashScreen（自动登录） |
| `/login`、`/register` | 登录 / 注册 |
| `/main` | MainScreen（底部 Tab） |
| `/chat/:id`、`/chat/:id/settings`、`/chat/:id/history` | 聊天详情 / 会话设置 / 历史消息 |
| `/group/:id/info`、`/group-list`、`/create-group`、`/group-applications` | 群资料 / 群列表 / 建群 / 群申请 |
| `/topic/:id`、`/topic-compose/:groupId`、`/topic-settings/:groupId`、`/topic-notifications`、`/topic-index-ops` | 话题详情 / 发布 / 话题群设置 / 话题通知 / 索引运维 |
| `/profile/my`、`/profile/user/:id`、`/account-settings` | 我的资料 / 用户资料 / 账号设置 |
| `/search`、`/scan`、`/qr` | 全局搜索 / 扫码 / 二维码 |
| `/friend-list`、`/friend-requests`、`/friend-setup/:userId`、`/add-contact`、`/contact-picker`、`/blacklist` | 好友与通讯录 |
| `/merge-message`、`/media/image`、`/media/video` | 合并转发详情 / 图片查看 / 视频播放 |

`NavigationService` 单例提供 `GlobalKey<NavigatorState>` 用于 Service 层无 Context 导航。

## IM 协议

### 连接流程

1. `OpenIMClientBuilder::build()` 创建所有 Manager、EventHub（含 6 个领域事件通道）、Cache、CancelToken
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

- **SQLite** 数据库：`{data_dir}/openim_{user_id}.db`（按用户隔离，对齐 Go SDK）
- **连接池**：sqlx，最大 5 连接
- **表**：`local_chat_logs`、`local_chat_log_reaction_extensions`、`local_conversations`、`local_users`、`local_stranger`、`local_friends`、`local_groups`、`local_group_members`、`local_blacks`、`local_notification_seqs`、`local_sending_messages`、`local_sync_version`、`local_uploads`、`local_app_sdk_version`

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
