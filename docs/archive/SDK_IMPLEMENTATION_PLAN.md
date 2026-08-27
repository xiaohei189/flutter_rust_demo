# Rust SDK 实施计划

基于全新架构的 SDK 实施计划。

---

## 总体策略（从内到外）

```
内层                          外层
[基础设施] → [核心模块] → [业务模块] → [SDK门面+测试] → [FFI桥接]
```

**核心原则**：以 **Go SDK**（`../openim-sdk-core`）为权威参考，写全新干净的 Rust 代码。

| 参考来源 | 优先级 | 用法 |
|---------|--------|------|
| Go SDK (`openim-sdk-core`) | 🥇 第一 | 业务逻辑、接口签名、数据流 |
| `migrations/` + `openim-protocol` | � 直接复用 | SQL 建表、protobuf 定义 |

| 阶段 | 目标 | 状态 |
|------|------|------|
| Phase 1 | 基础设施层（新架构骨架） | ✅ 已完成 |
| Phase 2 | 核心模块实体化 | ✅ 已完成 |
| Phase 3 | 业务模块实体化 + 集成测试 | ✅ 3.1/3.2/3.3/3.4 完成 |
| Phase 4 | FFI 桥接层完善 | ✅ 已完成 |

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

## Phase 2 完成情况

| 模块 | 功能 | 状态 | 说明 |
|------|------|------|------|
| 连接管理器 | WebSocket 连接、心跳、重连 | ✅ 完成 | 指数退避重连、踢下线处理 |
| 消息处理器 | 收消息 + 写数据库 | ✅ 完成 | 支持 12 种消息类型 |
| 消息发送器 | WS 发送消息 | ✅ 完成 | protobuf 编码 |
| 消息同步器 | seq 拉取缺失消息 | ✅ 完成 | 增量同步 |
| 会话管理 | 对接数据库 | ✅ 完成 | SQLite 持久化 |
| 好友管理 | 内存管理 | ✅ 完成 | 待集成测试 |
| 群组管理 | 内存管理 | ✅ 完成 | 待集成测试 |
| 用户管理 | 内存管理 | ✅ 完成 | 待集成测试 |
| 在线状态 | 内存管理 | ✅ 完成 | 待集成测试 |
| 文件上传 | HTTP 上传 | ✅ 完成 | 预签名 URL |

### 已验证功能

| 测试项 | 状态 | 说明 |
|--------|------|------|
| 消息收发 | ✅ 通过 | 12 种消息类型验证 |
| 连接状态变更 | ✅ 通过 | Connected → Disconnected |
| 断线重连 | ✅ 通过 | 指数退避策略 |
| 踢下线处理 | ✅ 完成 | Kicked 状态 + 事件 |
| 好友列表同步 | ✅ 通过 | 含 null 响应处理 |
| 添加/删除好友 | ✅ 通过 | HTTP API 验证 |
| 黑名单管理 | ✅ 通过 | 添加/移除 |
| 群组列表同步 | ✅ 通过 | 含 null 响应处理 |
| 创建群组 | ✅ 通过 | 含成员邀请 |
| 群组信息管理 | ✅ 通过 | 修改群信息 |
| 群组成员管理 | ✅ 通过 | 邀请/踢出成员 |
| 会话列表同步 | ✅ 通过 | 消息触发会话创建 |
| 未读消息计数 | ✅ 通过 | 累加/标记已读/清零 |
| 会话置顶/免打扰 | ✅ 通过 | 设置/取消 |
| 会话删除 | ✅ 通过 | 删除后验证不存在 |
| 消息撤回 | ✅ 通过 | 撤回后 content_type 更新为 2101 |
| 消息删除 | ✅ 通过 | 删除后数据库记录清除 |
| 消息已读标记 | ✅ 通过 | is_read 字段更新 |

---

## Phase 3: 业务模块集成测试

### Task 3.1: 好友功能集成测试

**测试用例**：
- [x] 好友列表同步
- [x] 添加好友
- [x] 删除好友
- [x] 好友申请处理（接受/拒绝）
- [x] 黑名单管理（添加/移除）

**文件**：`rust/tests/integration.rs` - `test_friend_*`

### Task 3.2: 群组功能集成测试

**测试用例**：
- [x] 群组列表同步
- [x] 创建群组
- [x] 加入/退出群组
- [x] 群组成员管理（邀请/踢出）
- [x] 群组信息管理

**文件**：`rust/tests/integration.rs` - `test_group_*`

### Task 3.3: 会话功能集成测试

**测试用例**：
- [x] 会话列表同步
- [x] 未读消息计数
- [x] 会话置顶/免打扰
- [x] 会话删除

**文件**：`rust/tests/integration.rs` - `test_conversation_*`

### Task 3.4: 消息高级功能集成测试

**测试用例**：
- [x] 消息撤回
- [x] 消息删除
- [x] 已读回执
- [ ] 消息转发

**文件**：`rust/tests/integration.rs` - `test_message_revoke/delete/mark_read`

**新增模块**：
- `core/message/service.rs` - 消息服务（撤回、删除、已读）
- `message_dao` 新增方法：`delete_by_client_msg_id`, `update_content_type`, `mark_as_read_by_seqs`
- `SdkEvent` 新增事件：`MessagesDeleted`

---

## Phase 4: FFI 桥接层完善 ✅ 已完成

### Task 4.1: 完善 FFI 桥接 ✅ 已完成

- [x] 重构为集成模式：所有操作集成到 OpenIMBridgeClient
- [x] 清理无用桥接文件（bridge_friend, bridge_group, bridge_online, bridge_user, file, simple, test_upload）
- [x] 好友功能 FFI 完整对接
- [x] 群组功能 FFI 完整对接
- [x] 会话功能 FFI 完整对接
- [x] 消息高级功能 FFI 对接
- [x] 用户功能 FFI 对接

### Task 4.2: Flutter 对接 🔴 待开始

- [ ] Riverpod 状态管理
- [ ] GoRouter 路由
- [ ] UI 组件开发

---

## 项目结构

```
rust/src/
├── api/              # FFI 桥接层
│   ├── bridge_client.rs
│   ├── bridge_friend.rs
│   ├── bridge_group.rs
│   ├── bridge_online.rs
│   ├── bridge_user.rs
│   └── mod.rs
├── core/             # 核心模块
│   ├── connection/   # 连接管理
│   ├── conversation/ # 会话管理
│   ├── file/         # 文件上传
│   ├── friend/       # 好友管理
│   ├── group/        # 群组管理
│   ├── message/      # 消息处理
│   ├── online/       # 在线状态
│   └── user/         # 用户管理
├── domain/           # 领域层
│   ├── constant/     # 常量定义
│   ├── error/        # 错误类型
│   ├── event/        # 事件总线
│   ├── model/        # 数据模型
│   └── config.rs     # 配置
├── infra/            # 基础设施
│   ├── cache/        # 内存缓存
│   ├── database/     # SQLite DAO
│   ├── file/         # 文件操作
│   └── http/         # HTTP 客户端
├── protocol/         # 协议层
│   └── ws.rs         # WebSocket 协议
├── sdk/              # SDK 门面
│   ├── builder.rs
│   ├── client.rs
│   └── context.rs
└── lib.rs
```

---

## 设计决策（已确定）

1. **权威参考**：Go SDK (`openim-sdk-core`) 为唯一业务逻辑来源
2. **模型层**：`domain/model/` 下全新定义，以 Go SDK `pkg/db/model/` 为参考
3. **DAO 粒度**：每表一个文件，与 Go SDK 的 model 文件一一对应
4. **消息发送队列**：初版单 lane 简单版，后续对齐 Go 双 lane
5. **重连策略**：指数退避（1s→2s→4s...→60s），参考 Go `long_conn_mgr.go`
6. **WS 消息格式**：JSON 信封 + protobuf data（对齐 Go SDK 和当前服务端）
7. **旧代码处理**：已完全删除 `im/` 目录

---

## 当前执行进度

**正在执行**: Task 3.4 - 消息高级功能集成测试 ✅ 已完成

### 下一步计划

1. ~~实现消息撤回测试 (`test_message_recall`)~~ ✅ 完成
2. ~~实现消息删除测试 (`test_message_delete`)~~ ✅ 完成
3. ~~实现已读回执测试 (`test_message_read_receipt`)~~ ✅ 完成
4. 实现消息转发测试 (`test_message_forward`)
5. 开始 Phase 4: FFI 桥接层完善

### 修复记录（2024-05-30）

- 修复登录流程：`login()` 内部自动连接
- 修复 `user_id` 管理：使用 `Arc<RwLock<String>>`
- 修复 6+ API 字段名与 protobuf 对齐
- 所有响应结构体添加 `Default` trait 处理 null 值
- 修复会话创建逻辑：消息处理器在收到新消息时自动创建会话记录
- 修复测试中 conversation_id 格式：`si_{send_id}_{recv_id}`
- 新增消息服务模块：`core/message/service.rs`（撤回、删除、已读）
- 新增 DAO 方法：`delete_by_client_msg_id`, `update_content_type`, `mark_as_read_by_seqs`
- 新增 SdkEvent 事件：`MessagesDeleted`
- 修复 `MessageHandler` 暴露 `message_dao()` 方法供测试使用
- **重构 FFI 桥接层为集成模式**：所有操作集成到 `OpenIMBridgeClient`
- 删除无用桥接文件：bridge_friend, bridge_group, bridge_online, bridge_user, file, simple, test_upload
- 修复类型引用：使用 domain model 替代不存在的内部类型（BlackInfo, GroupMemberInfo）
- 修复方法签名：对齐内部 SDK 的实际方法签名
- 会话操作返回 LocalConversation（FFB 可序列化）
- 重新生成 FFI Dart 绑定代码

---

## Phase 5: 完整 API 覆盖与 Flutter 对接（当前阶段）

### 🔴 背景

三层 API 覆盖审计结果（2026-05-30）：

| 层级 | 应有 API | 已实现 | 完成率 |
|------|---------|--------|-------|
| HTTP Route | 50 | 50 | 100%（定义完整） |
| Core Manager | 64 | 25 | **39%** |
| FFI Bridge | 64 | 21 | **33%** |
| Event Bus（事件发布） | 22 种 | 10 种 | **45%** |

**核心问题**：
1. 会话同步器（syncer）空实现 → 登录后无法拉取服务端会话 → **Flutter 白屏**
2. 消息发送不写本地数据库 → 发完消息刷新就丢
3. 好友/群申请流程完全缺失 → Flutter 好友请求页面无数据
4. 事件总线定义了事件但 55% 未发布 → Flutter listener 收不到回调
5. 15 个 Manager 已有实现但 FFI 未暴露

---

### 优先级定义

| 级别 | 含义 | 目标 |
|------|------|------|
| **P0** 🔴 | 阻塞 Flutter 基本功能 | 登录→会话列表→聊天→好友群组基础流程跑通 |
| **P1** 🟡 | 影响完整业务流程 | 审批流、搜索、富媒体消息 |
| **P2** 🟢 | 功能增强 | 禁言、转让群、全局设置 |

---

### Task 5.0: 会话同步器重写（P0 🔴）

> **现状**：`pull_conversations_from_server` / `pull_all_conversations_from_server` 返回空 vec
> **目标**：通过 HTTP API `/conversation/get_conversation_list_split` 拉取服务端会话

**实现内容**：
- [ ] 在 `conversation/syncer.rs` 中实现 `pull_conversations_from_server(version: i64)` 调用 `/conversation/get_incremental_conversation`
- [ ] 实现 `pull_all_conversations_from_server()` 调用 `/conversation/get_conversation_list_split`
- [ ] 拉取后写入 `ConversationDao`（upsert）
- [ ] 拉取后发布 `SdkEvent::ConversationChanged`
- [ ] 登录完成后自动触发 `sync_full()`
- [ ] 发布 `SdkEvent::SyncStarted / SyncProgress / SyncFinished / SyncFailed`
- [ ] 补全集成测试：`test_conversation_sync_full`

**涉及文件**：`core/conversation/syncer.rs`, `core/conversation/manager.rs`, `infra/http/routes.rs`（已有 route）

---

### Task 5.1: 消息发送本地持久化（P0 🔴）

> **现状**：`send_message` 发送后不写 `LocalChatLog`，不更新会话 latestMsg
> **目标**：发送成功后在本地创建聊天记录并更新对应会话

**实现内容**：
- [ ] `send_message` 成功后调用 `MessageDao.insert()` 写本地
- [ ] 更新会话 latest_msg / latest_msg_send_time / unread_count
- [ ] 发布 `SdkEvent::MessageSent` 事件
- [ ] 发送失败发布 `SdkEvent::MessageSendFailed`
- [ ] 发送进度支持发布 `SdkEvent`（可选）
- [ ] 补全集成测试：`test_message_send_and_local_persist`

**涉及文件**：`core/message/sender.rs`, `core/message/service.rs`, `infra/database/`

---

### Task 5.2: 好友申请流程实现（P0 🔴）

> **现状**：Route 有 `/friend/get_friend_apply_list`、`/friend/accept_friend_apply`、`/friend/refuse_friend_apply`，Manager 无实现
> **目标**：支持好友申请列表查询、接受、拒绝

**实现内容**：
- [ ] `FriendManager::get_friend_apply_list()` → `/friend/get_friend_apply_list`
- [ ] `FriendManager::accept_friend_application(user_id)` → `/friend/accept_friend_apply`
- [ ] `FriendManager::refuse_friend_application(user_id)` → `/friend/refuse_friend_apply`
- [ ] 发布 `SdkEvent::FriendApplicationAdded/Approved/Rejected`
- [ ] FFI 暴露：`accept_friend_application()` / `refuse_friend_application()` / `get_friend_application_list()`
- [ ] 补全集成测试

**涉及文件**：`core/friend/manager.rs`, `api/bridge_client.rs`

---

### Task 5.3: 群组申请流程实现（P0 🔴）

> **现状**：Route 有 `/group/get_group_application_list`、`/group/accept_group_application`、`/group/refuse_group_application`，Manager 无实现

**实现内容**：
- [ ] `GroupManager::get_group_application_list()` → `/group/get_group_application_list`
- [ ] `GroupManager::accept_group_application(group_id, user_id)` → `/group/accept_group_application`
- [ ] `GroupManager::refuse_group_application(group_id, user_id)` → `/group/refuse_group_application`
- [ ] 发布 `SdkEvent::GroupApplicationAdded/Approved/Rejected`
- [ ] FFI 暴露对应方法
- [ ] 补全集成测试

**涉及文件**：`core/group/manager.rs`, `api/bridge_client.rs`

---

### Task 5.4: 事件总线补齐（P0 🔴）

> **现状**：22 种事件变体，仅 10 种实际发布
> **目标**：补齐 Flutter listener 依赖的关键事件

**实现内容**：
- [ ] `SdkEvent::NewConversation` — 在会话同步/创建时发布
- [ ] `SdkEvent::TotalUnreadCountChanged` — 在未读数变更时聚合发布
- [ ] `SdkEvent::MessageSent / MessageSendFailed` — 见 Task 5.1
- [ ] `SdkEvent::KickedOffline` — 在 WS 层踢下线时发布
- [ ] `SdkEvent::TokenExpired` — 在 WS 层 token 过期时发布
- [ ] `SdkEvent::UserStatusChanged` — 收到用户状态推送时发布
- [ ] `SdkEvent::FriendInfoUpdated` — 在好友信息变更时发布
- [ ] `SdkEvent::GroupMemberAdded/Deleted/InfoChanged` — 在群成员变更时发布
- [ ] `SdkEvent::SyncProgress / SyncFailed` — 见 Task 5.0

**涉及文件**：`domain/event/types.rs`, `core/connection/`, `core/conversation/`, `core/friend/`, `core/group/`

---

### Task 5.5: FFI 桥接补齐已实现的 Manager 方法（P1 🟡）

> **现状**：Manager 已实现但 FFI 未暴露的有 6 个

| Manager 方法 | FFI 暴露 | 优先级 |
|-------------|---------|-------|
| `is_friend(user_id)` | ❌ | 🟡 P1 |
| `get_groups_info(group_ids)` | ❌ | 🟡 P1 |
| `set_group_info(updates)` | ❌ | 🟡 P1 |
| `get_group_members_info(group_id, user_ids)` | ❌ | 🟡 P1 |
| `dismiss_group(group_id)` | ❌ | 🟡 P1 |
| `set_private_chat(conv_id, is_private)` | ❌ | 🟡 P1 |

**实现内容**：
- [ ] 在 `bridge_client.rs` 中逐项添加对应 FFI 方法
- [ ] 方法名对齐 Flutter SDK 命名习惯
- [ ] 重新生成绑定代码

---

### Task 5.6: 用户状态订阅（P1 🟡）

> **现状**：Route 有 `/user/subscribe_users_status` / `/user/unsubscribe_users_status` / `/user/get_user_status` / `/user/get_subscribe_users_status`，Manager 无实现
> **目标**：监听用户在线状态变化

**实现内容**：
- [ ] `UserManager::subscribe_users_status(user_ids)` → `/user/subscribe_users_status`
- [ ] `UserManager::unsubscribe_users_status(user_ids)` → `/user/unsubscribe_users_status`
- [ ] `UserManager::get_user_status(user_ids)` → `/user/get_user_status`
- [ ] 发布 `SdkEvent::UserStatusChanged`
- [ ] FFI 暴露
- [ ] 补全集成测试

**涉及文件**：`core/user/manager.rs`, `api/bridge_client.rs`

---

### Task 5.7: 富媒体消息创建（P1 🟡）

> **现状**：只支持发送纯文本消息，图片/文件/语音/视频/位置/自定义/转发均无
> **目标**：支持创建并发送各类富媒体消息

**实现内容**：
- [ ] `ImageMessage::create_from_path(path)` → 构造 protobuf MsgData(content_type=pic)
- [ ] `FileMessage::create_from_path(path, filename)` → content_type=file
- [ ] `SoundMessage::create_from_path(path, duration)` → content_type=sound
- [ ] `VideoMessage::create_from_path(path, duration, snapshot)` → content_type=video
- [ ] `LocationMessage::create(desc, lat, lng)` → content_type=location
- [ ] `CustomMessage::create(data, extension, desc)` → content_type=custom
- [ ] `ForwardMessage::create(original_msg)` → content_type=forward
- [ ] 所有类型通过 `send_message()` 统一发送
- [ ] 文件上传逻辑（预签名 URL）：接入 `/third/initiate_upload` / `/third/complete_upload`
- [ ] 补全集成测试

**涉及文件**：新建 `core/message/creator.rs` 或 `core/message/types.rs` 扩展

---

### Task 5.8: 本地消息搜索（P1 🟡）

> **现状**：无 search_local_messages 实现
> **目标**：支持按关键字/消息类型搜索本地消息

**实现内容**：
- [ ] `MessageDao::search(keyword, type_filter, start_time, end_time, offset, count)`
- [ ] `MessageService::search_local_messages()`
- [ ] FFI 暴露
- [ ] 补全单元测试

**涉及文件**：`infra/database/message_dao.rs`, `core/message/service.rs`

---

### Task 5.9: 群组高级管理（P2 🟢）

> **现状**：Route 有但 Manager 无实现

**实现内容**：
- [ ] `GroupManager::transfer_group_owner(group_id, new_owner_id)` → `/group/transfer_group_owner`
- [ ] `GroupManager::mute_group(group_id)` / `unmute_group(group_id)` → `/group/mute_group` / `/group/cancel_mute_group`
- [ ] `GroupManager::mute_group_member(group_id, user_id, seconds)` / `unmute_group_member(group_id, user_id)` → `/group/mute_group_member` / `/group/cancel_mute_group_member`
- [ ] 发布对应 SdkEvent
- [ ] FFI 暴露
- [ ] 补全集成测试

**涉及文件**：`core/group/manager.rs`, `api/bridge_client.rs`

---

### Task 5.10: 全局设置与通用功能（P2 🟢）

**实现内容**：
- [ ] `UserManager::set_global_msg_recv_opt(opt)` → `/user/set_global_msg_recv_opt`（P2）
- [ ] 上传接口：`upload_file()` / `upload_file_with_progress()` 使用 `/third/initiate_upload` + `/third/complete_upload`（P2）
- [ ] `ConversationManager::set_conversation(...)` → `/conversation/set_conversation`（P2）
- [ ] `ConversationManager::get_conversation_ids()` → `/conversation/get_conversation_ids`（P2）
- [ ] `ConversationManager::mark_conversation_as_read(conv_id, seq)` → `/conversation/mark_conversation_as_read`（P2）

---

### Task 5.11: 集成测试全覆盖（伴随 Task 5.0~5.10）

**新增集成测试用例**：

| 测试 | 对应 Task |
|------|----------|
| `test_conversation_sync_full` | 5.0 |
| `test_conversation_sync_incremental` | 5.0 |
| `test_message_send_persist` | 5.1 |
| `test_message_send_failed_event` | 5.1 |
| `test_friend_apply_flow(apply/approve/reject)` | 5.2 |
| `test_group_apply_flow(apply/approve/reject)` | 5.3 |
| `test_is_friend` | 5.5 |
| `test_user_status_subscribe` | 5.6 |
| `test_create_image_message` | 5.7 |
| `test_search_local_messages` | 5.8 |
| `test_transfer_group_owner` | 5.9 |
| `test_mute_group` | 5.9 |
| `test_set_global_recv_msg_opt` | 5.10 |

---

### 📋 优先级总览

| Task | 描述 | 优先级 | 预估文件数 |
|------|------|-------|----------|
| **5.0** | 会话同步器重写 | **🔴 P0** | 3 |
| **5.1** | 消息发送本地持久化 | **🔴 P0** | 3 |
| **5.2** | 好友申请流程 | **🔴 P0** | 2 |
| **5.3** | 群组申请流程 | **🔴 P0** | 2 |
| **5.4** | 事件总线补齐 | **🔴 P0** | 5 |
| **5.5** | FFI 补齐已实现方法 | 🟡 P1 | 1 |
| **5.6** | 用户状态订阅 | 🟡 P1 | 2 |
| **5.7** | 富媒体消息创建 | 🟡 P1 | 3 |
| **5.8** | 本地消息搜索 | 🟡 P1 | 2 |
| **5.9** | 群组高级管理 | 🟢 P2 | 2 |
| **5.10** | 全局设置与通用功能 | 🟢 P2 | 3 |
| **5.11** | 集成测试全覆盖 | 伴随 | 1 |

---

### 🚩 推荐执行顺序

```
Week 1（P0 阻塞项）：
  5.0 会话同步器 → 5.1 消息持久化 → 5.4 事件总线

Week 2（P0 继续 + P1）：
  5.2 好友申请 → 5.3 群组申请 → 5.5 FFI 补齐

Week 3（P1）：
  5.6 用户状态订阅 → 5.7 富媒体消息 → 5.8 本地搜索

Week 4（P2 + 验收）：
  5.9 群组高级 → 5.10 全局设置 → 全量集成测试
```

---

<div align="center">

**更新日期：2026-05-30 | 当前进度：P0 任务进行中**

### ✅ 已完成

| Task | 状态 | 完成内容 |
|------|------|---------|
| **5.0 会话同步器** | ✅ 已完成 | 重写 syncer，接入 HTTP API `/conversation/get_all_conversations` 和 `/conversation/get_incremental_conversations`，写入 DAO，发布会话变更事件，登录后自动全量同步 |
| **5.1 消息持久化** | ✅ 已完成 | `send_message` 成功后自动写 `LocalChatLog` 到 MessageDao，更新会话 latest_msg/send_time（不计未读数），修复路由路径适配服务端 |
| **5.4 事件补齐** | ✅ 已完成 | 补齐 `SyncFailed`（syncer 错误处理）、`MessageSendFailed`（发送失败）、`TotalUnreadCountChanged`（同步完成后） |

### 🔴 P0 剩余

| Task | 状态 |
|------|------|
| **5.2 好友申请流程** | ⏳ 待开始 |
| **5.3 群组申请流程** | ⏳ 待开始 |

</div>
