# Rust SDK 实施计划

基于全新架构的 SDK 实施计划。

---

## 总体策略（从内到外）

```
内层                          外层
[基础设施] → [核心模块] → [业务模块] → [SDK门面+测试] → [FFI桥接]
```

**核心原则**：以 **Go SDK**（`D:\workspace\openim-sdk-core`）为权威参考，写全新干净的 Rust 代码。

| 参考来源 | 优先级 | 用法 |
|---------|--------|------|
| Go SDK (`openim-sdk-core`) | 🥇 第一 | 业务逻辑、接口签名、数据流 |
| `migrations/` + `openim-protocol` | � 直接复用 | SQL 建表、protobuf 定义 |

| 阶段 | 目标 | 状态 |
|------|------|------|
| Phase 1 | 基础设施层（新架构骨架） | ✅ 已完成 |
| Phase 2 | 核心模块实体化 | ✅ 已完成 |
| Phase 3 | 业务模块实体化 + 集成测试 | ✅ 3.1/3.2/3.3/3.4 完成 |
| Phase 4 | FFI 桥接层完善 | 🔴 待开始 |

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

## Phase 4: FFI 桥接层完善

### Task 4.1: 完善 FFI 桥接

- [ ] 好友功能 FFI 完整对接
- [ ] 群组功能 FFI 完整对接
- [ ] 会话功能 FFI 完整对接
- [ ] 消息高级功能 FFI 对接

### Task 4.2: Flutter 对接

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
