# 00 - 整体架构

> OpenIM Rust SDK 的系统全景、分层架构、核心数据流、模块映射与实施状态。

> [!NOTE] 事件体系已重构：旧的 `SdkEvent` 枚举 / `EventBus` 广播已废弃，当前以 **Listener trait → EventHub → 领域通道** 为准（见 [16-LISTENERS.md](./16-LISTENERS.md)）。本文档中的事件相关图示为历史版本，遇到冲突以 16-LISTENERS.md 和源码为准。

---

## 1. 系统全景

### 1.1 SDK 定位

OpenIM Rust SDK 是**客户端 IM 核心引擎**，负责：

- **消息收发**：文本、图片、视频、文件、自定义等 12+ 种消息类型的创建、发送、接收、同步
- **会话管理**：单聊/群聊/通知会话的创建、同步、未读计数、置顶/免打扰
- **关系管理**：好友列表、好友申请、黑名单、群组列表、群组成员、群组申请
- **连接管理**：WebSocket 长连接、心跳保活、断线重连（指数退避）、踢下线处理
- **数据持久化**：本地 SQLite 存储消息、会话、好友、群组数据，支持离线查看
- **状态同步**：增量/全量同步机制，确保客户端与服务端数据一致

SDK **不负责** UI 展示、路由导航、状态管理——这些由 Flutter/Dart 层完成。

### 1.2 与服务端的交互方式

SDK 通过两种协议与 OpenIM 服务端通信：

```
┌──────────────┐                              ┌──────────────────┐
│              │   WebSocket（实时通信）         │                  │
│  Rust SDK    │ ────────────────────────────→  │  chat-server     │
│              │   消息推送、RPC 请求/响应       │  （WebSocket 网关）│
│              │                              │                  │
│              │   HTTP API（数据管理）          │                  │
│              │ ────────────────────────────→  │  open-im-server  │
│              │   RESTful CRUD、同步接口       │  （IM 服务端）    │
└──────────────┘                              └──────────────────┘
```

| 通信方式 | 用途 | 消息格式 | 典型操作 |
|----------|------|----------|----------|
| **WebSocket** | 实时消息推送、发送消息、RPC 请求/响应 | JSON 信封 + Protobuf data | 发消息、拉消息、心跳、踢下线通知 |
| **HTTP API** | 数据管理、批量查询、配置设置 | JSON Request/Response | 登录、获取好友列表、创建群组、同步会话 |

### 1.3 与 Flutter 的集成方式

通过 `flutter_rust_bridge` (v2.11.1) FFI 框架实现 Rust ↔ Dart 通信：

```
Flutter/Dart UI
    ↓ FFI 调用（自动生成的绑定代码）
api/bridge_client.rs    ← OpenIMBridgeClient（统一 FFI 入口）
    ↓ 委托
sdk/client/             ← OpenIMClient（SDK 门面）
    ↓ 调用
core/*/                 ← 各核心模块
    ↓ 事件推送
SdkEvent → StreamSink → Dart Stream → Flutter UI 更新
```

**关键约束**：
- 所有 FFI 函数必须添加 `#[flutter_rust_bridge::frb]` 注解
- 参数类型使用 `String`（非 `&str`），返回类型使用 `Result<T>`
- 异步事件通过 `StreamSink<SdkEvent>` 推送到 Dart 侧
- 禁止手动编辑 `frb_generated.rs` / `frb_generated.dart`

---

## 2. 分层架构图

```
┌─────────────────────────────────────────────────────────────┐
│                 Flutter/Dart UI Layer                         │
│            (Riverpod 状态管理 + GoRouter 路由)                │
├─────────────────────────────────────────────────────────────┤
│                 FFI Bridge Layer (api/)                       │
│            OpenIMBridgeClient — 统一 FFI 入口                 │
│            所有 #[frb] 函数定义于此                           │
├─────────────────────────────────────────────────────────────┤
│                 SDK Facade Layer (sdk/)                       │
│            OpenIMClient — SDK 门面                            │
│            ClientBuilder — 构建器模式                         │
│            RuntimeContext — 依赖注入容器                       │
├─────────────────────────────────────────────────────────────┤
│                 Core Business Layer (core/)                   │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐     │
│  │  Connection   │ │   Message    │ │  Conversation    │     │
│  │  Manager      │ │   Syncer     │ │  Syncer          │     │
│  │  WebSocket    │ │   Handler    │ │  Manager         │     │
│  │  Reconnect    │ │   Service    │ │                  │     │
│  └──────────────┘ └──────────────┘ └──────────────────┘     │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐     │
│  │   Friend     │ │    Group     │ │     User         │     │
│  │   Manager    │ │    Manager   │ │     Manager      │     │
│  └──────────────┘ └──────────────┘ └──────────────────┘     │
│  ┌──────────────┐ ┌──────────────┐                          │
│  │   Online     │ │    File      │                          │
│  │   Manager    │ │   Uploader   │                          │
│  └──────────────┘ └──────────────┘                          │
├─────────────────────────────────────────────────────────────┤
│                 Domain Layer (domain/)                        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐     │
│  │    Model     │ │    Event     │ │     Error        │     │
│  │  (6 个模型)  │ │  EventBus    │ │   SdkError       │     │
│  └──────────────┘ └──────────────┘ └──────────────────┘     │
│  ┌──────────────┐ ┌──────────────┐                          │
│  │   Constant   │ │    Config    │                          │
│  │  (枚举+常量) │ │ ClientConfig │                          │
│  └──────────────┘ └──────────────┘                          │
├─────────────────────────────────────────────────────────────┤
│              Infrastructure Layer (infra/)                    │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐     │
│  │    HTTP      │ │   SQLite     │ │     Cache        │     │
│  │  Client      │ │   Database   │ │   (Memory)       │     │
│  │  Routes      │ │  (10 DAO)    │ │                  │     │
│  │  Auth        │ │              │ │                  │     │
│  └──────────────┘ └──────────────┘ └──────────────────┘     │
│  ┌──────────────┐                                           │
│  │    File      │                                           │
│  │  Uploader    │                                           │
│  └──────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

### 分层规则

| 规则 | 说明 |
|------|------|
| **上层可依赖下层** | `api/` → `sdk/` → `core/` → `domain/` → `infra/` |
| **同层可互相依赖** | `core/` 内各模块可通过 `RuntimeContext` 互相访问 |
| **下层禁止依赖上层** | `infra/` 不能引用 `core/` 或 `sdk/` 的类型 |
| **禁止跨层调用** | `api/` 直接调用 `core/` 是违规的，必须经过 `sdk/` |

---

## 3. 模块依赖关系图

```
                        ┌─────────┐
                        │  api/   │  FFI 桥接层
                        └────┬────┘
                             │
                        ┌────▼────┐
                        │  sdk/   │  SDK 门面层
                        └────┬────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
         ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
         │connection│   │message  │   │conversa-│  核心业务层
         └────┬────┘   └────┬────┘   │tion     │
              │              │        └────┬────┘
              │              │             │
              │         ┌────▼────┐        │
              │         │handler  │        │
              │         │syncer   │        │
              │         │service  │        │
              │         └────┬────┘        │
              │              │             │
    ┌─────────┼──────────────┼─────────────┼─────────┐
    │         │              │             │         │
┌───▼──┐ ┌───▼──┐     ┌────▼────┐   ┌───▼──┐ ┌───▼──┐
│friend│ │group │     │  user   │   │online│ │ file │
│  mgr │ │ mgr  │     │   mgr   │   │ mgr  │ │upload│
└───┬──┘ └───┬──┘     └────┬────┘   └───┬──┘ └───┬──┘
    │         │              │           │         │
    └─────────┴──────────────┴───────────┴─────────┘
                             │
                        ┌────▼────┐
                        │ domain/ │  领域层
                        │ model   │
                        │ event   │
                        │ error   │
                        └────┬────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
         ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
         │  http/  │   │database/│   │ cache/  │  基础设施层
         │ client  │   │ 10 DAO  │   │ memory  │
         │ routes  │   │  pool   │   │         │
         └─────────┘   └─────────┘   └─────────┘
```

### 模块间通信方式

| 源模块 | 目标模块 | 通信方式 |
|--------|----------|----------|
| `core/connection/` | `core/message/` | 事件总线推送 `PushMessages` |
| `core/message/syncer` | `core/message/handler` | 直接方法调用 |
| `core/message/handler` | `core/conversation/manager` | 直接方法调用（更新会话） |
| `core/friend/manager` | `domain/event/bus` | 发布 `FriendAdded/Deleted` 等事件 |
| `core/group/manager` | `domain/event/bus` | 发布 `GroupCreated/InfoChanged` 等事件 |
| `core/user/manager` | `domain/event/bus` | 发布 `UserInfoUpdated` 等事件 |
| `sdk/client` | 所有 `core/*` 模块 | 通过 `RuntimeContext` 获取引用 |
| `api/bridge_client` | `sdk/client` | 直接调用 `OpenIMClient` 方法 |
| 所有核心模块 | `infra/database/` | 通过 `RuntimeContext.database()` 获取 DAO |
| 所有核心模块 | `infra/http/` | 通过 `RuntimeContext.api()` 获取 HTTP 客户端 |

---

## 4. 核心数据流

### 4.1 消息发送流

```
Flutter UI
  │  用户点击发送
  ▼
api/bridge_client.rs::send_text_message(text, source_id, session_type)
  │  FFI 调用
  ▼
sdk/client/message.rs::send_text_message()
  │  组装 MsgData
  ▼
core/message/service.rs::send_message()
  │  1. 生成 clientMsgID（MD5 哈希）
  │  2. 填充基础字段（sendID, sendTime, platformID...）
  │  3. 写入本地数据库（status = sending）
  │  4. 编码为 Protobuf
  ▼
core/connection/manager.rs::send_request(SEND_MSG, data)
  │  通过 WebSocket 发送 JSON 信封 + Protobuf data
  ▼
chat-server（WebSocket 网关）
  │  路由到消息服务
  ▼
open-im-server（IM 服务端）
  │  1. 消息存储
  │  2. 推送给接收方
  │  3. 返回响应（serverMsgID, seq）
  ▼
core/message/service.rs 收到响应
  │  1. 更新本地消息（serverMsgID, seq, status = sent）
  │  2. 更新会话 latestMsg
  ▼
domain/event/bus.rs::publish(SdkEvent::MessageSent { ... })
  │  事件推送
  ▼
Flutter 通过 Stream 接收事件 → 更新 UI
```

### 4.2 消息接收流

```
open-im-server（IM 服务端）
  │  推送新消息
  ▼
chat-server（WebSocket 网关）
  │  转发到客户端
  ▼
core/connection/websocket.rs::on_message()
  │  解析 JSON 信封 → 提取 PushMessages
  ▼
core/connection/manager.rs::dispatch()
  │  根据 req_identifier 分发
  ▼
core/message/syncer.rs::on_push_messages()
  │  1. 解析 Protobuf MsgData
  │  2. 检测 seq 连续性（gap 检测）
  ▼
core/message/handler.rs::handle_push_messages()
  │  1. 去重检查（clientMsgID）
  │  2. 消息类型分发（普通消息 vs 通知消息）
  │  3. 写入本地数据库
  │  4. 更新会话最新消息和未读计数
  ▼
domain/event/bus.rs::publish(SdkEvent::NewMessage { message })
  │  事件推送
  ▼
Flutter 通过 Stream 接收事件 → 显示新消息
```

### 4.3 会话同步流

```
SDK 登录成功
  │
  ▼
sdk/client.rs::login()
  │  触发全量同步
  ▼
core/conversation/syncer.rs::sync_full()
  │
  ├─→ 发布 SdkEvent::SyncStarted
  │
  │  1. 获取本地版本号
  │  2. 调用 HTTP API /conversation/get_all_conversations
  │  3. 或调用 /conversation/get_incremental_conversations
  │
  ▼
infra/http/client.rs::post(GET_ALL_CONVERSATION_LIST, req)
  │  HTTP 请求到 open-im-server
  ▼
open-im-server 返回会话列表
  │
  ▼
core/conversation/syncer.rs::sync_conversations()
  │  1. 对比服务端与本地数据
  │  2. 插入新会话 → INSERT
  │  3. 更新变更会话 → UPSERT
  │  4. 删除多余会话 → DELETE
  │  5. 更新版本号
  ▼
infra/database/conversation_dao.rs（SQLite 持久化）
  │
  ▼
domain/event/bus.rs::publish(SdkEvent::ConversationChanged { conversations })
  │  + SdkEvent::NewConversation { conversations }
  │  + SdkEvent::TotalUnreadCountChanged { count }
  │
  ▼
Flutter 接收事件 → 更新会话列表 UI
```

### 4.4 通知分发流

```
open-im-server（IM 服务端）
  │  推送通知类消息（content_type >= 1000）
  ▼
core/connection/websocket.rs → core/message/syncer.rs
  │
  ▼
core/message/handler.rs::handle_notification_message()
  │  根据 content_type 范围路由到对应处理器
  │
  ├─→ 好友通知（1200-1299）
  │     └── core/friend/manager.rs::do_notification()
  │           ├── 好友申请 (1201) → SdkEvent::FriendApplicationAdded
  │           ├── 好友申请已读 (1202)
  │           ├── 接受好友申请 (1205) → SdkEvent::FriendAdded
  │           ├── 拒绝好友申请 (1206) → SdkEvent::FriendApplicationRejected
  │           ├── 删除好友 (1207) → SdkEvent::FriendDeleted
  │           ├── 黑名单添加 (1209) → SdkEvent::BlackAdded
  │           └── 黑名单移除 (1210) → SdkEvent::BlackDeleted
  │
  ├─→ 群组通知（1500-1599）
  │     └── core/group/manager.rs::do_notification()
  │           ├── 创建群组 (1501) → SdkEvent::GroupCreated
  │           ├── 群组信息变更 (1502) → SdkEvent::GroupInfoChanged
  │           ├── 邀请入群 (1503) → SdkEvent::GroupMemberAdded
  │           ├── 被踢出群 (1504) → SdkEvent::GroupMemberDeleted
  │           ├── 退出群组 (1505)
  │           ├── 解散群组 (1506) → SdkEvent::GroupDismissed
  │           ├── 群主转让 (1507) → SdkEvent::GroupOwnerTransferred
  │           ├── 群组申请 (1508) → SdkEvent::GroupApplicationAdded
  │           ├── 接受群组申请 (1509) → SdkEvent::GroupApplicationApproved
  │           └── 拒绝群组申请 (1510) → SdkEvent::GroupApplicationRejected
  │
  └─→ 用户通知 / 会话通知
        └── core/user/manager.rs / core/conversation/manager.rs
```

---

## 5. Go SDK 模块 ↔ Rust 模块映射表

### 5.1 核心业务层映射

| Go SDK 模块 | Go SDK 关键文件 | Rust 模块 | Rust 关键文件 |
|-------------|-----------------|-----------|---------------|
| **连接管理** (`internal/interaction/`) | `long_conn_mgr.go`, `long_connection.go`, `reconnect.go`, `ws_default.go` | `core/connection/` | `manager.rs`, `websocket.rs`, `reconnect.rs`, `heartbeat.rs` |
| **消息处理** (`internal/conversation_msg/`) | `create_message.go`, `send_queue.go`, `sync.go`, `message_check.go` | `core/message/` | `service.rs`, `syncer.rs`, `handler.rs`, `types.rs` |
| **消息 API** (`internal/conversation_msg/`) | `api.go`, `server_api.go`, `revoke.go`, `delete.go`, `read_drawing.go` | `core/message/` | `service.rs`（撤回/删除/已读/搜索） |
| **会话管理** (`internal/conversation_msg/`) | `conversation.go`, `incremental_sync.go`, `conversation_msg.go` | `core/conversation/` | `manager.rs`, `syncer.rs` |
| **好友关系** (`internal/relation/`) | `relation.go`, `sync.go`, `notification.go`, `incremental_sync.go` | `core/friend/` | `manager.rs` |
| **群组管理** (`internal/group/`) | `group.go`, `full_sync.go`, `incremental_sync.go`, `notification.go`, `filter.go` | `core/group/` | `manager.rs` |
| **用户管理** (`internal/user/`) | `user.go`, `full_sync.go`, `notification.go` | `core/user/` | `manager.rs` |
| **在线状态** (`internal/interaction/`) | `online.go`, `subscription.go` | `core/online/` | `manager.rs` |
| **文件上传** (`internal/third/file/`) | `upload.go`, `file.go`, `progress.go` | `core/file/` + `infra/file/` | `uploader.rs` |

### 5.2 基础设施层映射

| Go SDK 模块 | Go SDK 关键文件 | Rust 模块 | Rust 关键文件 |
|-------------|-----------------|-----------|---------------|
| **数据库** (`pkg/db/`) | `db_init.go`, `chat_log_model.go`, `conversation_model.go`, `friend_model.go`, `group_model.go`, `user_model.go`, `version_sync.go` | `infra/database/` | `pool.rs`, `message_dao.rs`, `conversation_dao.rs`, `friend_dao.rs`, `group_dao.rs`, `user_dao.rs`, `sync_version_dao.rs` |
| **HTTP 客户端** (`pkg/network/`) | `http_client.go`, `new_http.go` | `infra/http/` | `client.rs`, `routes.rs`, `auth.rs` |
| **缓存** (`pkg/cache/`) | `cache.go`, `user_cache.go`, `conversation_seq_cache.go` | `infra/cache/` | `memory.rs` |

### 5.3 领域层映射

| Go SDK 模块 | Go SDK 关键文件 | Rust 模块 | Rust 关键文件 |
|-------------|-----------------|-----------|---------------|
| **数据模型** (`pkg/db/model_struct/`) | `data_model_struct.go`, `chat_log_model.go`, `conversation_model.go`, `friend_model.go`, `group_model.go`, `user_model.go` | `domain/model/` | `message.rs`, `conversation.rs`, `friend.rs`, `group.rs`, `user.rs`, `msg_struct.rs` |
| **常量** (`pkg/constant/`) | `constant.go` | `domain/constant/` | `types.rs`, `enums.rs` |
| **错误** (`pkg/sdkerrs/`) | `code.go`, `error.go`, `predefine.go` | `domain/error/` | `types.rs` |
| **事件/回调** (`open_im_sdk_callback/`, `open_im_sdk/listener.go`) | `callback_client.go`, `listener.go` | `domain/event/` | `bus.rs`, `types.rs` |
| **配置** (`pkg/cliconf/`) | `client_config.go` | `domain/` | `config.rs` |

### 5.4 门面层映射

| Go SDK 模块 | Go SDK 关键文件 | Rust 模块 | Rust 关键文件 |
|-------------|-----------------|-----------|---------------|
| **SDK 入口** (`open_im_sdk/`) | `caller.go`, `init_login.go`, `em.go` | `sdk/` | `client/client.rs`, `builder.rs`, `context.rs` |
| **消息操作** (`open_im_sdk/`) | `conversation_msg.go` | `sdk/client/` | `message.rs` |
| **好友操作** (`open_im_sdk/`) | `relation.go` | `sdk/client/` | `friend.rs` |
| **群组操作** (`open_im_sdk/`) | `group.go` | `sdk/client/` | `group.rs` |
| **用户操作** (`open_im_sdk/`) | `user.go` | `sdk/client/` | `user.rs` |
| **会话操作** (`open_im_sdk/`) | `conversation_msg.go` | `sdk/client/` | `conversation.rs` |
| **在线状态** (`open_im_sdk/`) | `online.go` | `sdk/client/` | `online_status.rs` |
| **FFI 层** (`open_im_sdk/`) | `caller.go`（Go 的 FFI 入口） | `api/` | `bridge_client.rs` |

---

## 6. 功能点全景清单

### 6.1 连接管理 (`core/connection/`)

| 功能 | Go SDK | Rust 实现 | 状态 |
|------|--------|-----------|------|
| WebSocket 连接建立 | ✅ `ws_default.go` | ✅ `websocket.rs` | ✅ |
| 心跳保活（Ping/Pong） | ✅ `long_conn_mgr.go` | ✅ `heartbeat.rs` | ✅ |
| 断线重连（指数退避） | ✅ `reconnect.go` | ✅ `reconnect.rs` | ✅ |
| RPC 请求/响应（SendReqWaitResp） | ✅ `long_conn_mgr.go` | ✅ `manager.rs` | ✅ |
| 消息推送接收 | ✅ `long_conn_mgr.go` | ✅ `manager.rs` | ✅ |
| 踢下线处理 | ✅ `long_conn_mgr.go` | ✅ `manager.rs` | ✅ |
| Token 过期处理 | ✅ `long_conn_mgr.go` | ✅ `manager.rs` | ✅ |
| 连接状态事件 | ✅ | ✅ `SdkEvent::Connected/Disconnected` | ✅ |
| 消息批处理（MessageBatcher） | ✅ `message_batcher.go` | ❌ 未实现 | ❌ |
| 压缩/编码（Compressor/Encoder） | ✅ `compressor.go`, `encoder.go` | ❌ 未实现 | ❌ |

### 6.2 消息模块 (`core/message/`)

| 功能 | Go SDK | Rust 实现 | 状态 |
|------|--------|-----------|------|
| 创建文本消息 | ✅ `create_message.go` | ✅ `service.rs` | ✅ |
| 创建 Markdown 消息 | ✅ `create_message.go` | ✅ `service.rs` | ✅ |
| 创建高级文本消息 | ✅ `create_message.go` | ✅ `service.rs` | ✅ |
| 发送消息（WS） | ✅ `send_queue.go` | ✅ `service.rs` | ✅ |
| 消息发送本地持久化 | ✅ | ✅ `service.rs` | ✅ |
| 消息同步（seq 拉取） | ✅ `msg_sync.go` | ✅ `syncer.rs` | ✅ |
| 消息接收处理 | ✅ `notification.go` | ✅ `handler.rs` | ✅ |
| 消息撤回 | ✅ `revoke.go` | ✅ `service.rs` | ✅ |
| 消息删除 | ✅ `delete.go` | ✅ `service.rs` | ✅ |
| 已读回执 | ✅ `read_drawing.go` | ✅ `service.rs` | ✅ |
| 获取历史消息 | ✅ `api.go` | ✅ `message.rs`(sdk) | ✅ |
| 消息去重（clientMsgID） | ✅ `message_check.go` | ✅ `handler.rs` | ✅ |
| 双 Lane 发送队列 | ✅ `send_queue.go` | ❌ 当前单 lane | ❌ |
| 消息发送进度回调 | ✅ `progress.go` | ❌ 未实现 | ❌ |
| 正在输入通知（Typing） | ✅ `entering.go` | ❌ 未实现 | ❌ |
| seq Gap 检测补拉 | ✅ `msg_sync.go` | ❌ 未实现 | ❌ |
| 消息转发 | ✅ `api.go` | ❌ 未实现 | ❌ |
| 本地消息搜索 | ✅ `api.go` | ❌ 未实现 | ❌ |

### 6.3 会话模块 (`core/conversation/`)

| 功能 | Go SDK | Rust 实现 | 状态 |
|------|--------|-----------|------|
| 会话管理器 | ✅ `conversation.go` | ✅ `manager.rs` | ✅ |
| 会话全量同步 | ✅ `incremental_sync.go` | ✅ `syncer.rs` | ✅ |
| 会话增量同步 | ✅ `incremental_sync.go` | ✅ `syncer.rs` | ✅ |
| 会话列表获取 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 会话置顶/免打扰 | ✅ | ✅ `manager.rs` | ✅ |
| 未读消息计数 | ✅ | ✅ `manager.rs` | ✅ |
| 会话删除 | ✅ | ✅ `manager.rs` | ✅ |
| 会话标记已读 | ✅ | ⚠️ 部分实现 | ⚠️ |
| 会话信息设置（set_conversation） | ✅ | ❌ 未实现 | ❌ |
| 会话 ID 列表获取 | ✅ | ❌ 未实现 | ❌ |

### 6.4 好友模块 (`core/friend/`)

| 功能 | Go SDK | Rust 实现 | 状态 |
|------|--------|-----------|------|
| 好友列表获取 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 添加好友 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 删除好友 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 好友列表同步 | ✅ `sync.go` | ✅ `manager.rs` | ✅ |
| 黑名单管理 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 好友申请列表 | ✅ `api.go` | ❌ 未实现 | ❌ |
| 接受好友申请 | ✅ `api.go` | ❌ 未实现 | ❌ |
| 拒绝好友申请 | ✅ `api.go` | ❌ 未实现 | ❌ |
| 好友通知处理 | ✅ `notification.go` | ❌ 未实现 | ❌ |
| 好友增量同步 | ✅ `incremental_sync.go` | ❌ 未实现 | ❌ |
| 判断是否好友 | ✅ `api.go` | ⚠️ Manager 有实现，FFI 未暴露 | ⚠️ |

### 6.5 群组模块 (`core/group/`)

| 功能 | Go SDK | Rust 实现 | 状态 |
|------|--------|-----------|------|
| 群组列表获取 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 创建群组 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 获取群组信息 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 邀请成员 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 踢出成员 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 群组列表同步 | ✅ `full_sync.go` | ✅ `manager.rs` | ✅ |
| 退出群组 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 修改群组信息 | ✅ `api.go` | ⚠️ Manager 有实现，FFI 未暴露 | ⚠️ |
| 群组成员列表 | ✅ `api.go` | ⚠️ Manager 有实现，FFI 未暴露 | ⚠️ |
| 群组申请列表 | ✅ `api.go` | ❌ 未实现 | ❌ |
| 接受群组申请 | ✅ `api.go` | ❌ 未实现 | ❌ |
| 拒绝群组申请 | ✅ `api.go` | ❌ 未实现 | ❌ |
| 群组通知处理 | ✅ `notification.go` | ❌ 未实现 | ❌ |
| 群组增量同步 | ✅ `incremental_sync.go` | ❌ 未实现 | ❌ |
| 解散群组 | ✅ `api.go` | ⚠️ Manager 有实现，FFI 未暴露 | ⚠️ |
| 转让群主 | ✅ `api.go` | ❌ 未实现 | ❌ |
| 群组禁言 | ✅ `api.go` | ❌ 未实现 | ❌ |
| 成员禁言 | ✅ `api.go` | ❌ 未实现 | ❌ |

### 6.6 用户模块 (`core/user/`)

| 功能 | Go SDK | Rust 实现 | 状态 |
|------|--------|-----------|------|
| 获取用户信息 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 更新用户信息 | ✅ `api.go` | ✅ `manager.rs` | ✅ |
| 用户信息缓存 | ✅ `full_sync.go` | ✅ `manager.rs` | ✅ |
| 用户状态订阅 | ✅ `api.go` | ❌ 未实现 | ❌ |
| 用户状态取消订阅 | ✅ `api.go` | ❌ 未实现 | ❌ |
| 获取用户状态 | ✅ `api.go` | ❌ 未实现 | ❌ |
| 用户通知处理 | ✅ `notification.go` | ❌ 未实现 | ❌ |
| 全局消息接收设置 | ✅ `api.go` | ❌ 未实现 | ❌ |

### 6.7 文件上传 (`core/file/` + `infra/file/`)

| 功能 | Go SDK | Rust 实现 | 状态 |
|------|--------|-----------|------|
| 文件上传（预签名 URL） | ✅ `upload.go` | ✅ `uploader.rs` | ✅ |
| 上传进度回调 | ✅ `progress.go` | ❌ 未实现 | ❌ |
| 分片上传 | ✅ `upload.go` | ❌ 未实现 | ❌ |

### 6.8 基础设施 (`infra/`)

| 功能 | Go SDK | Rust 实现 | 状态 |
|------|--------|-----------|------|
| HTTP 客户端 | ✅ `pkg/network/` | ✅ `http/client.rs` | ✅ |
| HTTP 路由表（50 个 API） | ✅ | ✅ `http/routes.rs` | ✅ 100% |
| Token 认证 | ✅ | ✅ `http/auth.rs` | ✅ |
| SQLite 连接池 | ✅ `pkg/db/db_init.go` | ✅ `database/pool.rs` | ✅ |
| 消息 DAO | ✅ `chat_log_model.go` | ✅ `database/message_dao.rs` | ✅ |
| 会话 DAO | ✅ `conversation_model.go` | ✅ `database/conversation_dao.rs` | ✅ |
| 好友 DAO | ✅ `friend_model.go` | ✅ `database/friend_dao.rs` | ✅ |
| 群组 DAO | ✅ `group_model.go` | ✅ `database/group_dao.rs` | ✅ |
| 用户 DAO | ✅ `user_model.go` | ✅ `database/user_dao.rs` | ✅ |
| 黑名单 DAO | ✅ `black_model.go` | ✅ `database/black_dao.rs` | ✅ |
| 同步版本 DAO | ✅ `version_sync.go` | ✅ `database/sync_version_dao.rs` | ✅ |
| 发送中消息 DAO | ✅ `sending_messages_model.go` | ✅ `database/sending_message_dao.rs` | ✅ |
| 内存缓存 | ✅ `pkg/cache/` | ✅ `cache/memory.rs` | ✅ |

---

## 7. 当前 Rust 实施状态

### 7.1 已完成项（Phase 1-4）

#### Phase 1：基础设施层 ✅

| 模块 | 文件 | 状态 | 说明 |
|------|------|------|------|
| 错误类型 | `domain/error/types.rs` | ✅ | `SdkError` + helper + From 转换 |
| 常量定义 | `domain/constant/types.rs` | ✅ | 协议常量、枚举值 |
| 事件总线 | `domain/event/bus.rs` + `types.rs` | ✅ | broadcast channel，44 种事件变体 |
| 协议层 | `openim-protocol` crate | ✅ | 外部 crate（`../../protocol`） |
| HTTP 客户端 | `infra/http/client.rs` + `routes.rs` | ✅ | reqwest + 50 个路由 |
| 依赖注入 | `sdk/context.rs` | ✅ | RuntimeContext |
| 缓存 | `infra/cache/memory.rs` | ✅ | 内存 KV |

#### Phase 2：核心模块实体化 ✅

| 模块 | 功能 | 状态 |
|------|------|------|
| 连接管理器 | WebSocket 连接、心跳、重连 | ✅ |
| 消息处理器 | 收消息 + 写数据库 | ✅ 支持 12 种消息类型 |
| 消息发送器 | WS 发送消息 | ✅ |
| 消息同步器 | seq 拉取缺失消息 | ✅ |
| 会话管理 | 对接数据库 | ✅ |
| 好友管理 | 内存管理 | ✅ |
| 群组管理 | 内存管理 | ✅ |
| 用户管理 | 内存管理 | ✅ |
| 在线状态 | 内存管理 | ✅ |
| 文件上传 | HTTP 上传 | ✅ |

#### Phase 3：集成测试 ✅

| Task | 测试范围 | 状态 |
|------|----------|------|
| 3.1 好友功能 | 列表同步、添加/删除、申请处理、黑名单 | ✅ |
| 3.2 群组功能 | 列表同步、创建、加入/退出、成员管理、信息管理 | ✅ |
| 3.3 会话功能 | 列表同步、未读计数、置顶/免打扰、删除 | ✅ |
| 3.4 消息高级功能 | 撤回、删除、已读回执 | ✅（消息转发除外） |

#### Phase 4：FFI 桥接层 ✅

| 任务 | 状态 |
|------|------|
| 重构为集成模式（OpenIMBridgeClient） | ✅ |
| 好友功能 FFI 对接 | ✅ |
| 群组功能 FFI 对接 | ✅ |
| 会话功能 FFI 对接 | ✅ |
| 消息高级功能 FFI 对接 | ✅ |
| 用户功能 FFI 对接 | ✅ |

### 7.2 Phase 5 剩余项（当前阶段）

#### 🔴 P0 — 阻塞 Flutter 基本功能

| Task | 任务 | 状态 | 预估工时 |
|------|------|------|----------|
| 5.0 | 会话同步器重写 | ✅ 已完成 | — |
| 5.1 | 消息发送本地持久化 | ✅ 已完成 | — |
| 5.4 | 事件总线补齐 | ✅ 已完成 | — |
| **5.2** | **好友申请流程实现** | ⏳ 待开始 | 2 天 |
| **5.3** | **群组申请流程实现** | ⏳ 待开始 | 2 天 |

#### 🟡 P1 — 影响完整业务流程

| Task | 任务 | 状态 | 预估工时 |
|------|------|------|----------|
| **5.5** | FFI 桥接补齐已实现 Manager 方法 | ⏳ 待开始 | 1 天 |
| **5.6** | 用户状态订阅 | ⏳ 待开始 | 2 天 |
| **5.7** | 富媒体消息创建（图片/文件/语音/视频） | ⏳ 待开始 | 3 天 |
| **5.8** | 本地消息搜索 | ⏳ 待开始 | 1 天 |

#### 🟢 P2 — 功能增强

| Task | 任务 | 状态 | 预估工时 |
|------|------|------|----------|
| **5.9** | 群组高级管理（转让群主、禁言） | ⏳ 待开始 | 2 天 |
| **5.10** | 全局设置与通用功能 | ⏳ 待开始 | 2 天 |
| **5.11** | 集成测试全覆盖 | ⏳ 待开始 | 2 天 |

### 7.3 各模块完成度估算

```
基础设施层 (infra/)
  HTTP 路由 .............. 100%  ██████████████████████████████
  数据库 DAO ............. 100%  ██████████████████████████████
  缓存 .................. 100%  ██████████████████████████████
  文件上传 ...............  80%  ████████████████████████░░░░░░

领域层 (domain/)
  数据模型 ............... 100%  ██████████████████████████████
  事件总线 ...............  90%  ███████████████████████████░░░
  错误类型 ............... 100%  ██████████████████████████████
  常量定义 ............... 100%  ██████████████████████████████

核心业务层 (core/)
  连接管理 ...............  95%  █████████████████████████████░
  消息模块 ...............  80%  ████████████████████████░░░░░░
  会话模块 ...............  75%  ███████████████████████░░░░░░░
  好友模块 ...............  50%  ███████████████░░░░░░░░░░░░░░░
  群组模块 ...............  50%  ███████████████░░░░░░░░░░░░░░░
  用户模块 ...............  30%  █████████░░░░░░░░░░░░░░░░░░░░░
  在线状态 ...............  40%  ████████████░░░░░░░░░░░░░░░░░░
  文件上传 ...............  40%  ████████████░░░░░░░░░░░░░░░░░░

SDK 门面层 (sdk/)
  OpenIMClient ...........  85%  ██████████████████████████░░░░
  构建器模式 .............  90%  ███████████████████████████░░░
  RuntimeContext .......... 100%  ██████████████████████████████

FFI 桥接层 (api/)
  OpenIMBridgeClient .....  70%  █████████████████████░░░░░░░░░

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  总体完成度 .............  ~60%  ██████████████████░░░░░░░░░░░░
```

---

## 8. 关键设计决策

### 8.1 权威参考：Go SDK 是唯一来源

> **原则：Go SDK（`openim-sdk-core`）是 IM 核心逻辑的唯一权威参考。**

- 所有业务逻辑（消息收发、去重、同步、通知处理）必须对齐 Go SDK 实现
- 数据模型、字段含义、事件类型必须与 Go SDK 保持一致
- 遇到设计决策时，优先查看 Go SDK 如何处理，直接移植而非重新设计
- 不允许自行发明 IM 相关逻辑

### 8.2 协议绑定：openim-protocol crate

> **原则：使用 `openim-protocol` crate 获取 Protobuf 定义，确保与服务端完全对齐。**

- `openim-protocol` 提供 Rust 版本的 Protobuf 结构体（`sdkws.rs`、`msg.rs` 等）
- WebSocket 消息格式（`OpenIMReq`/`OpenIMResp`）必须与 Go SDK 和服务端一致
- HTTP API 路由路径、请求/响应格式必须与服务端一致
- 消息类型常量（`content_type`、`session_type`、`group_role`）必须与协议定义一致

### 8.3 数据库：SQLite via sqlx

> **原则：使用 SQLite 作为本地持久化存储，通过 sqlx 异步访问。**

- 每个表一个 DAO 文件，与 Go SDK 的 model 文件一一对应
- 使用 `sqlx::SqlitePool` 管理连接池
- 迁移文件位于 `rust/migrations/`，命名格式 `YYYYMMDDHHMMSS_description.sql`
- 支持内存数据库模式（`:memory:`）用于测试

### 8.4 事件：统一广播事件总线

> **原则：使用 `tokio::broadcast` 实现统一事件总线，解耦模块间通信。**

- 所有 SDK 事件通过 `SdkEvent` 枚举统一定义（当前 44 种变体）
- 任何模块可通过 `EventBus::publish()` 发布事件
- FFI 层通过 `EventBus::subscribe()` 获取事件流，推送到 Flutter
- 事件命名规范：`DomainAction` 格式（如 `MessageSent`、`FriendAdded`）

### 8.5 FFI：flutter_rust_bridge v2.11.1

> **原则：使用 flutter_rust_bridge v2.11.1（锁定版本）实现 Rust ↔ Dart 通信。**

- 所有 FFI 函数添加 `#[flutter_rust_bridge::frb]` 注解
- 统一入口 `OpenIMBridgeClient`，避免分散的桥接文件
- 异步事件通过 `StreamSink<SdkEvent>` 推送
- 类型映射：`String` ↔ `String`、`i32` ↔ `int`、`i64` ↔ `BigInt`、`Vec<T>` ↔ `List<T>`、`Option<T>` ↔ `T?`

### 8.6 异步模式：tokio + Arc/RwLock

> **原则：所有 IO 操作使用 async/await，共享状态使用 `Arc<RwLock<T>>`。**

- 异步运行时：`tokio`
- 共享状态：`Arc<RwLock<T>>`（读多写少场景）或 `Arc<Mutex<T>>`（写多场景）
- **关键约束**：禁止在 `RwLockReadGuard` 生命周期内执行 `.await`，必须先获取结果再释放锁
- 取消机制：使用 `tokio_util::sync::CancellationToken`

### 8.7 错误处理：anyhow

> **原则：使用 `anyhow::Result<T>` 统一错误处理，通过 `?` 传播错误。**

- 内部模块统一使用 `anyhow::Result<T>`
- FFI 层通过 `.map_err(|e| anyhow::anyhow!("{}", e))` 转换错误
- `SdkError` 用于需要结构化错误信息的场景
- 关键错误使用 `tracing::error!` 记录日志

---

## 附录：术语表

| 术语 | 含义 |
|------|------|
| **clientMsgID** | 客户端生成的消息唯一标识，用于去重和匹配 |
| **serverMsgID** | 服务端分配的消息唯一标识 |
| **seq** | 消息序列号，用于增量同步时确定消息顺序 |
| **conversationID** | 会话唯一标识，单聊格式 `si_{sendID}_{recvID}`，群聊格式 `sg_{groupID}` |
| **content_type** | 消息内容类型：101=文本, 102=图片, 103=语音, 104=视频, 105=文件, ... |
| **session_type** | 会话类型：1=单聊, 2=写群聊, 3=读群聊, 4=通知 |
| **msg_from** | 消息来源：100=用户消息, 200=系统消息 |
| **SDK Event** | SDK 向 Flutter 推送的事件，通过 broadcast channel 分发 |
| **RuntimeContext** | 依赖注入容器，持有数据库、HTTP 客户端、缓存等共享资源 |
| **EventBus** | 统一事件总线，基于 `tokio::broadcast` 实现 |
| **Phase** | 实施阶段，Phase 1-4 已完成，Phase 5 进行中 |
| **FFI** | Foreign Function Interface，Rust 与 Dart 之间的函数调用接口 |
| **FRB** | flutter_rust_bridge 的缩写 |

---

<div align="center">

**文档版本：v1.0 | 最后更新：2026-06-03 | 当前阶段：Phase 5（P0 剩余好友/群组申请流程）**

</div>
