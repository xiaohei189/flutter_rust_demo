# OpenIM Rust SDK 完整重写参考文档

> 本文档集是 OpenIM Rust SDK 从零重写的完整技术规范，以 Go SDK（`openim-sdk-core`）为唯一权威参考。
> 
> 所有内容均经过 Go SDK 源码交叉校验，常量值、方法签名、数据流等关键事实已验证准确。

---

## 文档导航

| # | 文件名 | 说明 | 关键内容 |
|---|--------|------|----------|
| 00 | [00-OVERVIEW.md](./00-OVERVIEW.md) | **整体架构** | 系统全景、分层架构图、模块依赖、核心数据流、功能点清单、实施状态 |
| 01 | [01-CONNECTION.md](./01-CONNECTION.md) | **连接管理器** | WebSocket 连接、心跳保活(24s)、断线重连(循环退避)、RPC 匹配、推送分发 |
| 02 | [02-MESSAGE-SYNC.md](./02-MESSAGE-SYNC.md) | **消息同步器** | 全量/增量同步、Seq gap 检测、重装模式、后台唤醒同步 |
| 03 | [03-MESSAGE-HANDLER.md](./03-MESSAGE-HANDLER.md) | **消息处理器** | doMsgNew 核心流程、去重、会话更新、未读数管理、通知路由 |
| 04 | [04-MESSAGE-SENDER.md](./04-MESSAGE-SENDER.md) | **消息发送器** | 双 Lane 保序、阈值估计、Worker Pool、推送聚合器(MessageBatcher) |
| 05 | [05-CONVERSATION.md](./05-CONVERSATION.md) | **会话管理** | 会话 CRUD、版本同步、消息历史、已读回执、撤回/删除处理 |
| 06 | [06-NOTIFICATION.md](./06-NOTIFICATION.md) | **通知系统** | ContentType 范围路由、41 种通知类型、同步标志、去重机制 |
| 07 | [07-FRIEND.md](./07-FRIEND.md) | **好友模块** | 好友 CRUD、申请流程、黑名单、增量同步(VersionSynchronizer) |
| 08 | [08-GROUP.md](./08-GROUP.md) | **群组模块** | 群组 CRUD、成员管理、申请流程、20 种群通知处理 |
| 09 | [09-USER.md](./09-USER.md) | **用户模块** | 用户信息管理、自身同步、用户缓存、在线状态 |
| 10 | [10-CONSTANTS.md](./10-CONSTANTS.md) | **常量参考** | 所有 WS 标识符、ContentType(101-2200+)、Notification(1000-5000)、同步标志等 |
| 11 | [11-DATA-MODELS.md](./11-DATA-MODELS.md) | **数据模型** | 14 个数据模型完整定义、Server↔Local 转换函数 |
| 12 | [12-HTTP-API.md](./12-HTTP-API.md) | **HTTP API** | 74 个 API 路由完整列表、请求/响应类型 |
| 13 | [13-SYNCER-FRAMEWORK.md](./13-SYNCER-FRAMEWORK.md) | **同步器框架** | 泛型 Syncer、VersionSynchronizer、6 个同步器实例 |
| 14 | [14-SDK-LIFECYCLE.md](./14-SDK-LIFECYCLE.md) | **SDK 生命周期** | InitSDK、Login(6步)、Logout、Token 管理、前后台切换 |
| 15 | [15-FFI-BRIDGE.md](./15-FFI-BRIDGE.md) | **FFI 桥接** | Go SDK 114 个 API 对照、55 个 FFI 函数清单、Listener → Dart stream 桥接 |
| 16 | [16-LISTENERS.md](./16-LISTENERS.md) | **监听器体系** | 6 个 Listener trait（44 个回调）、Go SDK 映射、触发时机与实现状态 |

---

## 阅读顺序建议

### 从零开始实现（推荐）

```
第 1 步：理解全局
  └── 00-OVERVIEW.md              ← 必读，理解整体架构和设计决策

第 2 步：掌握核心数据流
  ├── 14-SDK-LIFECYCLE.md         ← 理解 Login/Logout 流程
  ├── 01-CONNECTION.md            ← WebSocket 连接基础
  ├── 02-MESSAGE-SYNC.md          ← 消息同步核心
  ├── 03-MESSAGE-HANDLER.md       ← 消息入库处理
  └── 05-CONVERSATION.md          ← 会话管理

第 3 步：通知与同步体系
  ├── 06-NOTIFICATION.md          ← 通知路由（关键）
  ├── 13-SYNCER-FRAMEWORK.md      ← 通用同步器模式
  └── 04-MESSAGE-SENDER.md        ← 消息发送机制

第 4 步：业务模块
  ├── 07-FRIEND.md                ← 好友关系
  ├── 08-GROUP.md                 ← 群组管理
  └── 09-USER.md                  ← 用户管理

第 5 步：参考手册（按需查阅）
  ├── 10-CONSTANTS.md             ← 常量速查
  ├── 11-DATA-MODELS.md           ← 数据模型速查
  ├── 12-HTTP-API.md              ← API 路由速查
  ├── 15-FFI-BRIDGE.md            ← FFI 函数对照
  └── 16-LISTENERS.md             ← 事件监听速查
```

### 从 Go SDK 移植特定功能

```
1. 查阅 00-OVERVIEW.md §5「Go SDK ↔ Rust 模块映射表」→ 定位 Rust 模块
2. 查阅对应模块文档中的「Go SDK 对标分析」章节
3. 对照 Go SDK 源码 + Rust 当前实现，按文档中的架构图和流程实现
```

---

## Go SDK 源码映射

### 核心业务层

| Go SDK 路径 | Go SDK 功能 | Rust 模块 | 文档 |
|-------------|-------------|-----------|------|
| `internal/interaction/long_conn_mgr.go` | WebSocket 连接管理 | `core/connection/manager.rs` | 01-CONNECTION.md |
| `internal/interaction/reconnect.go` | 断线重连 | `core/connection/reconnect.rs` | 01-CONNECTION.md |
| `internal/interaction/message_batcher.go` | 推送消息聚合 | `core/connection/manager.rs` | 04-MESSAGE-SENDER.md |
| `internal/interaction/msg_sync.go` | 消息同步器 | `core/message/syncer.rs` | 02-MESSAGE-SYNC.md |
| `internal/conversation_msg/conversation_msg.go` | 消息处理+会话 | `core/message/handler.rs` | 03-MESSAGE-HANDLER.md |
| `internal/conversation_msg/send_queue.go` | 消息发送队列 | `core/message/service.rs` | 04-MESSAGE-SENDER.md |
| `internal/conversation_msg/notification.go` | 通知分发 | `core/message/handler.rs` | 06-NOTIFICATION.md |
| `internal/conversation_msg/incremental_sync.go` | 会话增量同步 | `core/conversation/syncer.rs` | 05-CONVERSATION.md |
| `internal/conversation_msg/revoke.go` | 消息撤回 | `core/message/service.rs` | 05-CONVERSATION.md |
| `internal/conversation_msg/read_drawing.go` | 已读回执 | `core/message/service.rs` | 05-CONVERSATION.md |
| `internal/conversation_msg/create_message.go` | 消息创建 | `core/message/service.rs` | 04-MESSAGE-SENDER.md |
| `internal/relation/relation.go` | 好友关系管理 | `core/friend/manager.rs` | 07-FRIEND.md |
| `internal/relation/notification.go` | 好友通知 | `core/friend/manager.rs` | 06-NOTIFICATION.md |
| `internal/group/group.go` | 群组管理 | `core/group/manager.rs` | 08-GROUP.md |
| `internal/group/notification.go` | 群组通知(20种) | `core/group/manager.rs` | 06-NOTIFICATION.md |
| `internal/user/user.go` | 用户管理 | `core/user/manager.rs` | 09-USER.md |
| `internal/third/file/upload.go` | 文件上传 | `core/file/uploader.rs` | (无专门文档) |

### 基础设施层

| Go SDK 路径 | Rust 路径 | 文档 |
|-------------|-----------|------|
| `pkg/syncer/syncer.go` | `infra/syncer/` (待实现) | 13-SYNCER-FRAMEWORK.md |
| `pkg/db/` | `infra/database/` | 11-DATA-MODELS.md |
| `pkg/api/api.go` | `infra/http/routes.rs` | 12-HTTP-API.md |
| `pkg/constant/constant.go` | `domain/constant/` | 10-CONSTANTS.md |
| `pkg/converter/` | `core/*/conversion.rs` (待实现) | 11-DATA-MODELS.md |

### SDK 门面层

| Go SDK 路径 | Rust 路径 | 文档 |
|-------------|-----------|------|
| `open_im_sdk/init_login.go` | `sdk/client/client.rs` | 14-SDK-LIFECYCLE.md |
| `open_im_sdk/caller.go` | `api/bridge_client.rs` | 15-FFI-BRIDGE.md |
| `open_im_sdk_callback/` | `domain/event/types.rs` | 16-LISTENERS.md |

---

## 实施状态对照表

### Phase 完成情况

| Phase | 名称 | 状态 | 说明 |
|-------|------|------|------|
| Phase 1 | 基础设施层 | ✅ 已完成 | 错误类型、常量、事件体系、协议层、HTTP 客户端、依赖注入、缓存 |
| Phase 2 | 核心模块实体化 | ✅ 已完成 | 连接管理、消息收发、会话/好友/群组/用户/在线状态、文件上传 |
| Phase 3 | 集成测试 | ✅ 已完成 | 4 个 Task（3.1-3.4），消息转发除外 |
| Phase 4 | FFI 桥接层 | ✅ 已完成 | 重构为集成模式，112 个 FFI 函数 |
| Phase 5 | 完整 API 覆盖 | 🟢 进行中 | 剩余：消息编辑接收端等 |

### 三层 API 覆盖审计

| 层级 | 应有 | 已实现 | 完成率 |
|------|------|--------|--------|
| HTTP Route | 74 | 50 | **68%** |
| Core Manager | 64 | 25 | **39%** |
| FFI Bridge | 114 (Go SDK) | 112 | **98%** |
| Listener 回调 | 44 个方法定义 | 40 个实际触发 | **91%** |

### Phase 5 任务状态

| Task | 描述 | 优先级 | 状态 |
|------|------|--------|------|
| 5.0 | 会话同步器重写 | 🔴 P0 | ✅ 已完成 |
| 5.1 | 消息发送本地持久化 | 🔴 P0 | ✅ 已完成 |
| 5.2 | 好友申请流程实现 | 🔴 P0 | ✅ 已完成 |
| 5.3 | 群组申请流程实现 | 🔴 P0 | ✅ 已完成 |
| 5.4 | 事件总线补齐 | 🔴 P0 | ✅ 已完成 |
| 5.5 | FFI 桥接补齐 | 🟡 P1 | ✅ 已完成 |
| 5.6 | 用户状态订阅 | 🟡 P1 | ✅ 已完成 |
| 5.7 | 富媒体消息创建 | 🟡 P1 | ✅ 已完成 |
| 5.8 | 本地消息搜索 | 🟡 P1 | ✅ 已完成 |
| 5.9 | 群组高级管理 | 🟢 P2 | ✅ 已完成 |
| 5.10 | 全局设置与通用功能 | 🟢 P2 | ✅ 已完成 |
| 5.11 | 集成测试全覆盖 | 伴随 | ✅ 已完成（CI + hermetic） |

---

## 目录结构速查

```
rust/src/
├── api/                    # FFI 桥接层（55 个函数）
├── sdk/client/             # SDK 门面（OpenIMClient + 各领域 facade）
├── core/
│   ├── connection/         # 连接管理（WS、心跳、重连、RPC）
│   ├── message/            # 消息（handler + syncer + sender + service）
│   ├── conversation/       # 会话（manager + syncer）
│   ├── friend/             # 好友管理
│   ├── group/              # 群组管理
│   ├── user/               # 用户管理
│   ├── online/             # 在线状态
│   └── file/               # 文件上传
├── domain/
│   ├── model/              # 6 个领域模型
│   ├── event/              # 事件总线（50 种事件）
│   ├── error/              # 错误类型
│   └── constant/           # 常量
├── infra/
│   ├── database/           # SQLite DAO（10 个）
│   ├── http/               # HTTP 客户端 + 74 个路由
│   ├── cache/              # 内存缓存
│   └── file/               # 文件操作
└── 协议绑定              # 外部 openim-protocol crate（WS 帧见 core/connection/ws.rs）
```

---

## 关键设计决策

| 决策 | 选择 | 文档位置 |
|------|------|----------|
| 权威参考 | Go SDK (`openim-sdk-core`) | 00-OVERVIEW.md §8 |
| 协议绑定 | `openim-protocol` crate | 10-CONSTANTS.md |
| 数据库 | SQLite + `sqlx` | 11-DATA-MODELS.md |
| 事件系统 | Listener trait 单一出口 + EventHub（mpsc 领域通道） | 16-LISTENERS.md |
| FFI 框架 | `flutter_rust_bridge` v2.11.1 | 15-FFI-BRIDGE.md |
| 异步运行时 | `tokio` | 01-CONNECTION.md |
| 连接管理 | WebSocket (JSON 信封 + protobuf) | 01-CONNECTION.md |
| 重连策略 | 循环退避 [1,2,4,8,16]s，最大 300 次 | 01-CONNECTION.md |
| 同步器 | 泛型 Syncer + VersionSynchronizer | 13-SYNCER-FRAMEWORK.md |

---

## 参考项目

| 项目 | 路径 | 用途 |
|------|------|------|
| Go SDK | `../openim-sdk-core` | IM 核心逻辑唯一权威参考 |
| Protocol | `../protocol` | Protobuf 定义 + 生成代码 |
| IM Server | `../open-im-server` | 服务端源码 |
| Docker | `../openim-docker` | 部署配置 |
| Chat 中间件 | `../chat` | 账号/Token 管理 |
| WS 网关 | `../chat-server` | 长连接管理 |
| Flutter Demo | `../openim-flutter-demo` | UI 参考 |

---

<div align="center">

**文档版本：v2.0 | 最后更新：2026-06-03 | 共 18 个文档，约 12,000 行**

</div>
