# OpenIM Rust SDK — 统一技术文档与进度追踪

> 权威参考：Go SDK (`openim-sdk-core`)  |  协议来源：`openim-protocol` crate
> 最后更新：2026-06-04

---

## 1. 项目概述

OpenIM Rust SDK 是**客户端 IM 核心引擎**，通过 `flutter_rust_bridge` (v2.11.1) 为 Flutter 提供 FFI 接口。

### 1.1 职责边界

| 负责 | 不负责 |
|------|--------|
| 消息收发（12+ 种消息类型） | UI 展示、路由导航 |
| 会话管理（单聊/群聊/通知会话） | 状态管理（Flutter Riverpod） |
| 关系管理（好友、群组、用户） | 网络层实现（reqwest/tungstenite） |
| 连接管理（WS/心跳/重连） | 持久化底层（SQLite 由 sqlx 封装） |
| 数据持久化（本地 SQLite） | 推送通知（FCM/APNs） |
| 状态同步（增量/全量） | |

### 1.2 通信方式

```
┌──────────────┐                    ┌──────────────────┐
│              │  WebSocket（实时）  │                  │
│  Rust SDK    │ ─────────────────→ │  chat-server     │
│              │  HTTP API（管理）   │  （WS 网关）      │
│              │ ─────────────────→ │  open-im-server  │
└──────────────┘                    └──────────────────┘
```

---

## 2. 分层架构

```
┌───────────────────────────────────────────────────────┐
│  Flutter/Dart UI (Riverpod + GoRouter)                │
├───────────────────────────────────────────────────────┤
│  FFI Bridge (api/)                                    │
│  OpenIMBridgeClient — 统一 FFI 入口，106 个 #[frb] 方法 │
├───────────────────────────────────────────────────────┤
│  SDK Facade (sdk/client/)                             │
│  OpenIMClient + 各领域 facade                         │
├───────────────────────────────────────────────────────┤
│  Core Business (core/)                                │
│  connection/ message/ conversation/ friend/ group/    │
│  user/ online/ notification/ file/                    │
├───────────────────────────────────────────────────────┤
│  Domain (domain/)                                     │
│  model(6) + event(40+ SdkEvent) + error + constant   │
├───────────────────────────────────────────────────────┤
│  Infrastructure (infra/)                              │
│  database(10 DAO) + http(50+ routes) + cache         │
└───────────────────────────────────────────────────────┘
```

**依赖规则**：上层 → 下层，禁止反向依赖，禁止跨层调用（api/ 必须经过 sdk/）。

### 模块间通信

| 源 → 目标 | 方式 |
|-----------|------|
| connection → message | EventBus 推送 `PushMessages` |
| message/syncer → message/handler | 直接方法调用 |
| message/handler → conversation/manager | 直接调用（更新会话） |
| friend/group/user → EventBus | 发布领域事件 |
| 所有 core 模块 → infra/ | 通过 `RuntimeContext` 获取 |

---

## 3. Go SDK 模块映射

### 核心业务层

| Go SDK | Rust 模块 | 关键文件 |
|--------|-----------|---------|
| `internal/interaction/long_conn_mgr.go` | `core/connection/` | `manager.rs` + `heartbeat.rs` + `reconnect.rs` |
| `internal/interaction/message_batcher.go` | — | ❌ 未实现 |
| `internal/conversation_msg/msg_sync.go` | `core/message/syncer.rs` | 消息同步器 |
| `internal/conversation_msg/conversation_msg.go` | `core/message/handler.rs` | 消息处理器（doMsgNew） |
| `internal/conversation_msg/send_queue.go` | `core/message/service.rs` | 消息发送 |
| `internal/conversation_msg/notification.go` | `core/notification/handler.rs` | 通知路由（41 种） |
| `internal/conversation_msg/incremental_sync.go` | `core/conversation/syncer.rs` | 会话增量同步 |
| `internal/relation/relation.go` | `core/friend/manager.rs` | 好友管理 |
| `internal/group/group.go` | `core/group/manager.rs` | 群组管理 |
| `internal/user/user.go` | `core/user/manager.rs` | 用户管理 |

### 基础设施层

| Go SDK | Rust 模块 |
|--------|-----------|
| `pkg/db/` | `infra/database/`（10 个 DAO） |
| `pkg/network/` | `infra/http/`（client + 50 routes） |
| `pkg/cache/` | `infra/cache/memory.rs` |
| `pkg/syncer/` | 待实现（泛型 Syncer 框架） |

---

## 4. 各模块实现状态

### 4.1 连接管理 `core/connection/` — 95%

| 功能 | Go SDK | Rust | 状态 |
|------|--------|------|------|
| WebSocket 连接 | `ws_default.go` | `manager.rs` | ✅ |
| 心跳保活（Ping/Pong） | `long_conn_mgr.go` | `heartbeat.rs` | ✅ |
| 断线重连（循环退避 [1,2,4,8,16]s，最大 300 次） | `reconnect.go` | `reconnect.rs` | ✅ |
| RPC 请求/响应匹配 | `long_conn_mgr.go` | `manager.rs` | ✅ |
| 消息推送接收 | `long_conn_mgr.go` | `manager.rs` | ✅ |
| 踢下线 + Token 过期处理 | `long_conn_mgr.go` | `manager.rs` | ✅ |
| 连接状态事件 | ✅ | `SdkEvent::Connected/Disconnected` | ✅ |
| **MessageBatcher 推送聚合** | `message_batcher.go` | — | ❌ P2 |
| **压缩/编码** | `compressor.go` + `encoder.go` | — | ❌ P2 |

### 4.2 消息模块 `core/message/` — 85%

| 功能 | Go SDK | Rust | 状态 |
|------|--------|------|------|
| 创建文本/Markdown/高级文本消息 | `create_message.go` | `service.rs` + `domain/model/msg_struct.rs` | ✅ |
| 发送消息（WS） | `send_queue.go` | `service.rs` | ✅ |
| 消息发送本地持久化 | ✅ | `service.rs` | ✅ |
| 消息同步（seq 拉取） | `msg_sync.go` | `syncer.rs` | ✅ |
| 消息接收处理（去重+入库） | `notification.go` | `handler.rs` | ✅ |
| 消息撤回/删除 | `revoke.go` + `delete.go` | `service.rs` | ✅ |
| 已读回执 | `read_drawing.go` | `service.rs` | ✅ |
| 获取历史消息 | `api.go` | `sdk/client/message.rs` | ✅ |
| 本地消息搜索 | `api.go` | `service.rs` | ✅ |
| 15 种消息元素结构体 | `sdk_struct.go` | `domain/model/msg_struct.rs` | ✅ |
| **seq gap 异常消息处理（4 类）** | `message_check.go` | — | ❌ **P0** |
| **双 Lane 发送队列** | `send_queue.go` | 当前单 lane | ❌ P1 |
| **消息发送进度回调** | `progress.go` | — | ❌ P1 |
| **正在输入（Typing）** | `entering.go` | `send_typing()` FFI | ✅ |
| **消息转发** | `api.go` | `forward_message()` FFI | ✅ |

### 4.3 会话模块 `core/conversation/` — 80%

| 功能 | Go SDK | Rust | 状态 |
|------|--------|------|------|
| 会话 CRUD | `conversation.go` | `manager.rs` | ✅ |
| 会话全量/增量同步 | `incremental_sync.go` | `syncer.rs` | ✅ |
| 置顶/免打扰/草稿 | ✅ | `manager.rs` | ✅ |
| 未读消息计数 | ✅ | `manager.rs` | ✅ |
| 会话删除 | ✅ | `manager.rs` | ✅ |
| **会话标记已读联动** | ✅ 完整联动 | ⚠️ 部分实现 | ⚠️ |
| **会话 Hash Read Seq 同步** | `sync.go:30` | — | ❌ P1 |
| **会话增量同步（VersionSynchronizer）** | `incremental_sync.go:26` | — | ❌ P1 |
| **会话信息设置（set_conversation）** | ✅ | `set_conversation()` FFI | ✅ |

### 4.4 通知模块 `core/notification/` — 95%

路由规则（按 `content_type` 范围分发）：

| 范围 | 类型 | 处理器 | 事件 |
|------|------|--------|------|
| 1201-1210 | 好友通知 | `friend/manager.rs` | FriendApplicationAdded/Deleted, FriendAdded, FriendDeleted, BlackAdded/Deleted |
| 1301-1399 | 用户通知 | `user/manager.rs` | UserInfoUpdated |
| 1501-1510 | 群组通知 | `group/manager.rs` | GroupCreated, GroupInfoChanged, GroupMemberAdded/Deleted, GroupDismissed, GroupOwnerTransferred, GroupApplicationAdded/Approved/Rejected |
| 1000-1099 | 会话通知 | `conversation/manager.rs` | ConversationChanged |

> 406 行完整实现，覆盖好友/用户/群组三大类通知，含 Protobuf 解码和 EventBus 事件发布。

### 4.5 好友模块 `core/friend/` — 95%

| 功能 | Go SDK | Rust | 状态 |
|------|--------|------|------|
| 好友列表获取 | `api.go` | `manager.rs` | ✅ |
| 添加/删除好友 | `api.go` | `manager.rs` | ✅ |
| 好友列表同步 | `sync.go` | `manager.rs` | ✅ |
| 黑名单管理 | `api.go` | `manager.rs` | ✅ |
| 好友申请列表（接收方） | `api.go` | `manager.rs` + FFI | ✅ |
| 好友申请列表（申请方） | `api.go` | `manager.rs` + FFI | ✅ |
| 接受/拒绝好友申请 | `api.go` | `manager.rs` + FFI | ✅ |
| 好友通知处理 | `notification.go` | `notification/handler.rs` | ✅ |
| 判断是否好友 | `api.go` | `manager.rs` + FFI | ✅ |
| 获取未处理申请数 | `api.go` | `manager.rs` + FFI | ✅ |
| **好友增量同步（VersionSynchronizer）** | `incremental_sync.go` | — | ❌ P1 |
| **搜索好友** | `api.go` | — | ❌ P2 |

### 4.6 群组模块 `core/group/` — 100%

| 功能 | Go SDK | Rust | 状态 |
|------|--------|------|------|
| 群组列表/创建/信息 | `api.go` | `manager.rs` + FFI | ✅ |
| 邀请/踢出成员 | `api.go` | `manager.rs` + FFI | ✅ |
| 退出/解散群组 | `api.go` | `manager.rs` + FFI | ✅ |
| 群组列表同步 | `full_sync.go` | `manager.rs` | ✅ |
| 群组申请流程（接收方/申请方） | `api.go` | `manager.rs` + FFI | ✅ |
| 群组通知处理（20 种） | `notification.go` | `notification/handler.rs` | ✅ |
| 修改群组信息 | `api.go` | `manager.rs` + FFI | ✅ |
| 群组成员列表 | `api.go` | `manager.rs` + FFI | ✅ |
| 群主转让 | `api.go` | `manager.rs` + FFI | ✅ |
| 群组禁言 | `api.go` | `manager.rs` + FFI | ✅ |
| 成员禁言 | `api.go` | `manager.rs` + FFI | ✅ |
| 获取未处理申请数 | `api.go` | `manager.rs` + FFI | ✅ |
| 设置群成员信息 | `api.go` | `manager.rs` + FFI | ✅ |
| 分页获取群列表 | `api.go` | `manager.rs` + FFI | ✅ |
| 搜索群组/群成员 | `api.go` | `manager.rs` + FFI | ✅ |
| 获取群主和管理员 | `api.go` | `manager.rs` + FFI | ✅ |
| 按加入时间筛选成员 | `api.go` | `manager.rs` + FFI | ✅ |
| 获取指定用户在群中 | `api.go` | `manager.rs` + FFI | ✅ |
| 检查本地同步状态 | `api.go` | `manager.rs` + FFI | ✅ |
| **群组增量同步** | `incremental_sync.go` | — | ❌ P1 |

### 4.7 用户模块 `core/user/` — 90%

| 功能 | Go SDK | Rust | 状态 |
|------|--------|------|------|
| 获取/更新用户信息 | `api.go` | `manager.rs` + FFI | ✅ |
| 用户信息缓存 | `full_sync.go` | `manager.rs` | ✅ |
| 用户通知处理 | `notification.go` | `notification/handler.rs` | ✅ |
| 全局消息接收设置 | `api.go` | `manager.rs` + FFI | ✅ |
| **用户状态订阅/取消** | `api.go` | Manager 有，FFI 未暴露 | ⚠️ |

### 4.8 在线状态 `core/online/` — 95%

| 功能 | Go SDK | Rust | 状态 |
|------|--------|------|------|
| 查询用户状态 | ✅ | `manager.rs` + FFI | ✅ |
| 订阅/取消订阅 | ✅ | `manager.rs` | ✅ |

### 4.9 文件上传 `core/file/` — 85%

| 功能 | Go SDK | Rust | 状态 |
|------|--------|------|------|
| 文件上传（预签名 URL） | `upload.go` | `uploader.rs` | ✅ |
| **上传进度回调** | `progress.go` | — | ❌ P1 |
| **分片上传** | `upload.go` | — | ❌ P2 |

### 4.10 基础设施 `infra/` — 95%

| 功能 | Go SDK | Rust | 状态 |
|------|--------|------|------|
| HTTP 客户端 + Token 认证 | `pkg/network/` | `http/client.rs` + `auth.rs` | ✅ |
| HTTP 路由表（50+ API） | ✅ | `http/routes.rs` | ✅ |
| SQLite 连接池 | `pkg/db/` | `database/pool.rs` | ✅ |
| 10 个 DAO | `pkg/db/*_model.go` | `database/*_dao.rs` | ✅ |
| 内存缓存 | `pkg/cache/` | `cache/memory.rs` | ✅ |

---

## 5. 消息同步架构详解

### 5.1 同步触发时机

| 触发 | 入口 | 拉取数量 | Go SDK 常量 |
|------|------|---------|------------|
| WS 连接成功 | `doConnected()` | 1 条/会话 | `connectPullNums=1` |
| App 后台唤醒 | `doWakeupDataSync()` | 10 条/会话 | `defaultPullNums=10` |
| 推送消息到达 | `doPushMsg()` | 按 gap 范围 | — |
| 手动触发 | `doIMMessageSync()` | 10 条/会话 | `defaultPullNums=10` |

### 5.2 数据流

```
服务端推送 → WebSocket → ConnectionManager → MessageBatcher(聚合) → MsgSyncer
  ├─ seq 连续 → 直接触发 doMsgNew
  └─ seq gap  → 补拉 [syncedMaxSeq+1, gapSeq] → 再触发 doMsgNew

doMsgNew → 去重(clientMsgID) → 入库 → 更新会话 → 未读计数 → EventBus → Flutter UI
```

### 5.3 去重机制

| 层级 | 去重方式 | 说明 |
|------|---------|------|
| MsgSyncer 层 | seq 连续性检查 | `pushTriggerAndSync` 对比 `syncedMaxSeqs` |
| Conversation 层 | clientMsgID 数据库查询 | `pullMessageIntoTable` 批量去重 |
| 当前批次内 | `processedMsgIDs` HashMap | 避免同批次重复处理 |

### 5.4 缺失的同步能力

| 能力 | Go SDK 位置 | 优先级 | 说明 |
|------|------------|--------|------|
| ~~异常消息处理（4 类）~~ | `message_check.go` | ~~P0~~ ✅ | `handle_exception_messages` 已实现 |
| ~~重试机制~~ | `msg_sync.go:429` | ~~P1~~ ✅ | `get_server_max_seqs` 3 次重试+指数退避 |
| ~~MaxSeqRecorder.IsNewMsg~~ | `max_seq_recorder.go:47` | ~~P1~~ ✅ | `MaxSeqRecorder` 已实现 |
| ~~会话 Hash Read Seq 同步~~ | `sync.go:30` | ~~P1~~ ✅ | `sync_conversation_hash_read_seqs` 已实现 |
| syncFlag 多阶段同步 | `sync.go:67` | P2 | 重装后同步群组/好友/会话基础数据 |
| 通知消息重装特殊处理 | `msg_sync.go:566` | P2 | 重装时通知只更新 seq，不拉消息体 |
| 唤醒同步 pullNums 区分 | `msg_sync.go:473` | P2 | 唤醒时拉取数量与连接时区分 |
| MessageBatcher 聚合 | `message_batcher.go` | P2 | 高负载场景避免频繁处理 |

---

## 6. FFI 桥接覆盖

### 6.1 Go SDK API 对照（114 个函数）

#### 生命周期（10 个）

| Go SDK | Rust FFI | 状态 |
|--------|----------|------|
| `InitSDK` | `OpenIMBridgeClient::new()` | ✅ |
| `Login` | 在 `new()` 内部 | ✅ |
| `Logout` | `logout()` | ✅ |
| `UnInitSDK` | — | ❌ |
| `GetSdkVersion` | — | ❌ |
| `GetLoginStatus` | `get_connection_state()` | ✅ |
| `GetLoginUserID` | — | ❌ |
| `SetAppBackgroundStatus` | — | ❌ |
| `NetworkStatusChanged` | — | ❌ |
| `SetConnListener` | EventBus 替代 | — |

#### 好友（16 个）

| Go SDK | Rust FFI | 状态 |
|--------|----------|------|
| `GetFriendList` | `get_friend_list()` | ✅ |
| `CheckFriend` | `is_friend()` + `check_friend()` | ✅ |
| `AddFriend` | `add_friend()` | ✅ |
| `DeleteFriend` | `delete_friend()` | ✅ |
| `GetFriendApplicationListAsRecipient` | `get_friend_apply_list()` | ✅ |
| `GetFriendApplicationListAsApplicant` | `get_friend_apply_list_as_applicant()` | ✅ |
| `AcceptFriendApplication` | `accept_friend_application()` | ✅ |
| `RefuseFriendApplication` | `refuse_friend_application()` | ✅ |
| `AddBlack` | `add_black()` | ✅ |
| `GetBlackList` | `get_black_list()` | ✅ |
| `RemoveBlack` | `remove_black()` | ✅ |
| `GetFriendApplicationUnhandledCount` | `get_friend_application_unhandled_count()` | ✅ |
| `GetSpecifiedFriendsInfo` | — | ❌ |
| `GetFriendListPage` | — | ❌ |
| `SearchFriends` | — | ❌ |
| `UpdateFriends` | — | ❌ |

#### 群组（28 个）

| Go SDK | Rust FFI | 状态 |
|--------|----------|------|
| `CreateGroup` | `create_group()` | ✅ |
| `JoinGroup` | `join_group()` | ✅ |
| `QuitGroup` | `quit_group()` | ✅ |
| `DismissGroup` | `dismiss_group()` | ✅ |
| `KickGroupMember` | `kick_group_members()` | ✅ |
| `SetGroupInfo` | `set_group_info()` | ✅ |
| `GetJoinedGroupList` | `get_group_list()` | ✅ |
| `GetSpecifiedGroupsInfo` | `get_groups_info()` | ✅ |
| `GetSpecifiedGroupMembersInfo` | `get_group_members_info()` | ✅ |
| `GetGroupMemberList` | `get_group_members()` | ✅ |
| `GetGroupApplicationListAsRecipient` | `get_group_application_list()` + `get_group_application_list_as_recipient()` | ✅ |
| `GetGroupApplicationListAsApplicant` | `get_group_application_list_as_applicant()` | ✅ |
| `AcceptGroupApplication` | `accept_group_application()` | ✅ |
| `RefuseGroupApplication` | `refuse_group_application()` | ✅ |
| `InviteUserToGroup` | `invite_group_members()` | ✅ |
| `ChangeGroupMute` | `mute_group()` | ✅ |
| `ChangeGroupMemberMute` | `mute_group_member()` | ✅ |
| `TransferGroupOwner` | `transfer_group_owner()` | ✅ |
| `IsJoinGroup` | `is_in_group()` | ✅ |
| `GetGroupApplicationUnhandledCount` | `get_group_application_unhandled_count()` | ✅ |
| `SetGroupMemberInfo` | `set_group_member_info()` | ✅ |
| `GetJoinedGroupListPage` | `get_joined_group_list_page()` | ✅ |
| `SearchGroups` | `search_groups()` | ✅ |
| `GetGroupMemberOwnerAndAdmin` | `get_group_member_owner_and_admin()` | ✅ |
| `GetGroupMemberListByJoinTimeFilter` | `get_group_member_list_by_join_time_filter()` | ✅ |
| `SearchGroupMembers` | `search_group_members()` | ✅ |
| `GetUsersInGroup` | `get_users_in_group()` | ✅ |
| `CheckLocalGroupFullSync` | `check_local_group_full_sync()` | ✅ |
| `CheckGroupMemberFullSync` | `check_group_member_full_sync()` | ✅ |

#### 消息（28 个）

| Go SDK | Rust FFI | 状态 |
|--------|----------|------|
| `CreateTextMessage` | `send_text_message()` (一步) | ✅ |
| `CreateImageMessage` | `send_image_message()` | ✅ |
| `CreateSoundMessage` | `send_sound_message()` | ✅ |
| `CreateVideoMessage` | `send_video_message()` | ✅ |
| `CreateFileMessage` | `send_file_message()` | ✅ |
| `CreateAtTextMessage` | `send_at_text_message()` | ✅ |
| `CreateCustomMessage` | `send_custom_message()` | ✅ |
| `CreateMarkdownMessage` | `send_markdown_message()` | ✅ |
| `CreateAdvancedTextMessage` | `send_advanced_text_message()` | ✅ |
| `SendMessage` | 内部调用 | ✅ |
| `GetAdvancedHistoryMessageList` | `get_history_messages()` | ✅ |
| `RevokeMessage` | `revoke_message()` | ✅ |
| `DeleteMessageFromLocalAndSvr` | `delete_messages()` | ✅ |
| `MarkMessagesAsReadByMsgID` | `mark_messages_as_read()` | ✅ |
| `SearchLocalMessages` | `search_local_messages()` | ✅ |
| `CreateQuoteMessage` | `send_quote_message()` | ✅ |
| `CreateMergerMessage` | `send_merger_message()` | ✅ |
| `CreateCardMessage` | `send_card_message()` | ✅ |
| `CreateLocationMessage` | `send_location_message()` | ✅ |
| `CreateFaceMessage` | `send_face_message()` | ✅ |
| `ForwardMessage` | `forward_message()` | ✅ |
| `TypingStatusUpdate` | `send_typing()` | ✅ |
| 其余 10 个 | — | ❌ |

#### 会话（10 个）

| Go SDK | Rust FFI | 状态 |
|--------|----------|------|
| `GetAllConversationList` | `get_conversations()` | ✅ |
| `SetConversationPinned` | `set_conversation_pinned()` | ✅ |
| `SetConversationDraft` | `set_conversation_draft()` | ✅ |
| `DeleteConversation` | `delete_conversation()` | ✅ |
| `MarkConversationMessageAsRead` | `mark_conversation_as_read()` | ✅ |
| `GetTotalUnreadMsgCount` | `get_total_unread_msg_count()` | ✅ |
| `GetConversation` | `get_conversation()` | ✅ |
| `GetConversations` | `get_conversations()` | ✅ |
| `SetConversation` | `set_conversation()` | ✅ |
| `GetConversationIDBySessionType` | `get_conversation_id_by_session_type()` | ✅ |

### 6.2 覆盖率统计

| 层级 | 应有 | 已实现 | 完成率 |
|------|------|--------|--------|
| Go SDK 公开 API | 114 | ~98 | **86%** |
| Core Manager 方法 | 64 | ~66 | **100%** |
| FFI Bridge 函数 | ~106 | 106 | **100%** |
| 事件发布 | 40+ 种定义 | ~35 种实际发布 | **88%** |
| 测试覆盖 | 30 个文件有 `#[cfg(test)]` | 覆盖 Core/Domain/Infra 各层 | — |

---

## 7. 实施计划与状态

### 7.1 Phase 完成情况

| Phase | 名称 | 状态 | 说明 |
|-------|------|------|------|
| Phase 1 | 基础设施层 | ✅ **完成** | 错误类型、常量、事件总线、协议层、HTTP 客户端、依赖注入、缓存 |
| Phase 2 | 核心模块实体化 | ✅ **完成** | 连接管理、消息收发、会话/好友/群组/用户/在线状态、文件上传 |
| Phase 3 | 集成测试 | ✅ **完成** | 4 个 Task（3.1-3.4），消息转发除外 |
| Phase 4 | FFI 桥接层 | ✅ **完成** | 重构为集成模式，~45 个 FFI 函数 |
| Phase 5 | 完整 API 覆盖 | 🔴 **进行中** | 见下方详细任务 |

### 7.2 Phase 5 任务详情

#### 🔴 P0 — 阻塞 Flutter 基本功能

| Task | 描述 | 状态 | 备注 |
|------|------|------|------|
| 5.0 | 会话同步器重写 | ✅ 完成 | 全量+增量同步，版本号追踪 |
| 5.1 | 消息发送本地持久化 | ✅ 完成 | sending_messages 表 |
| 5.2 | 好友申请流程实现 | ✅ 完成 | Core + SDK + FFI 全链路 |
| 5.3 | 群组申请流程实现 | ✅ 完成 | Core + SDK + FFI 全链路 |
| 5.4 | 事件总线补齐 | ✅ 完成 | 40+ 种 SdkEvent |

> **P0 全部完成。**

#### 🟡 P1 — 影响完整业务流程

| Task | 描述 | 状态 | 备注 |
|------|------|------|------|
| 5.5 | FFI 桥接补齐 Manager 方法 | ✅ 完成 | 76 个 FRB 函数已实现 |
| 5.6 | 用户状态订阅 | ✅ 完成 | Core + FFI 已实现 |
| 5.8 | 本地消息搜索 | ✅ 完成 | `search_local_messages` 已实现 |
| **5.A** | **异常消息处理（4 类）** | ✅ 完成 | `handle_exception_messages` — SEQ_GAP/DELETED/SEQ_DUP/CLIENT_DUP |
| **5.B** | **重试机制（GetMaxSeq 3 次重试）** | ✅ 完成 | `get_server_max_seqs` 含指数退避 2s→4s |
| **5.C** | **MaxSeqRecorder.IsNewMsg** | ✅ 完成 | `MaxSeqRecorder` 结构体 + `is_new_msg`/`incr`/`set`/`get` |
| **5.D** | **会话 Hash Read Seq 同步** | ✅ 完成 | `ConversationSyncer::sync_conversation_hash_read_seqs` |
| 5.7 | 富媒体消息 SDK 层暴露 | ✅ 完成 | 引用/合并/名片/位置/表情（SDK + FFI） |

> **P1 全部完成。**

#### 🟢 P2 — 功能增强

| Task | 描述 | 状态 | 备注 |
|------|------|------|------|
| 5.9 | 群组高级管理（分页、搜索） | ✅ **完成** | 分页获取群列表、搜索群组/群成员、群主管理员、按时间筛选、同步检查 |
| 5.10 | 全局设置与通用功能 | ⏳ **待开始** | |
| 5.11 | 集成测试全覆盖 | ⏳ **待开始** | 30 个文件已有单元测试，需补齐集成测试 |
| 5.E | MessageBatcher 推送聚合 | ⏳ **待开始** | 高负载场景 |
| 5.F | syncFlag 多阶段同步 | ⏳ **待开始** | 重装后基础数据同步 |
| 5.G | 双 Lane 发送队列 | ⏳ **待开始** | 消息保序 |
| 5.H | 前台/后台区分回调 | ✅ 完成 | `set_app_background_status` FFI 已暴露 |
| 5.I | 消息/连接 FFI 补齐 | ✅ 完成 | 转发/URL消息/未读数/已读标记/版本/用户ID/前后台/网络状态 |

### 7.3 SDK 对齐计划（Go SDK API 对齐）

| 阶段 | 内容 | 状态 |
|------|------|------|
| 阶段一：API 对齐 | 消息创建+发送两步走、clientMsgID MD5、status 初始化、initBasicInfo | ✅ 已完成 |
| 阶段二：事件对齐 | 撤回通知事件、seq gap 检测补拉、消息异常处理 | ⚠️ 撤回已实现，seq gap 待做 |
| 阶段三：字段补齐 | LocalEx、OfflinePush、LastMinSeq、Markdown | ✅ 已完成 |
| 阶段四：功能补齐 | 各消息类型 Elem 结构、完整性测试 | ✅ 已完成（15 种 Elem 结构体） |

---

## 8. 已知技术债务

### 8.1 代码质量

| 问题 | 位置 | 说明 |
|------|------|------|
| syncer 方法重复 | `core/message/syncer.rs` | `batch_pull_messages` / `pull_and_handle_messages` / `sync_incremental_messages` 各有 reinstall 变体，应合并 |
| builder.rs 空文件 | `sdk/builder.rs` | 未实现 Builder 模式 |
| protocol/constants.rs 空文件 | `protocol/constants.rs` | 未使用 |
| infra/file/uploader.rs 空文件 | `infra/file/uploader.rs` | 实际上传在 core/file/ |

### 8.2 缺失的数据库表

| 表 | Go SDK | Rust SDK | 用途 |
|---|--------|----------|------|
| `local_notification_seqs` | ✅ | ❌ | 通知 seq 追踪 |
| `local_seq` | ✅ | ❌ | MinSeq 存储 |
| `local_version_sync` | ✅ | ⚠️ 有 DAO 无完整表 | 版本同步（会话/好友/群组增量同步） |

---

## 9. 核心设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 权威参考 | Go SDK (`openim-sdk-core`) | 所有 IM 逻辑对齐 Go 实现 |
| 协议绑定 | `openim-protocol` crate | 与服务端 Protobuf 完全对齐 |
| 数据库 | SQLite + `sqlx` | 跨平台，异步，内存模式支持测试 |
| 事件总线 | `tokio::broadcast` | 解耦模块间通信，40+ 种事件 |
| FFI 框架 | `flutter_rust_bridge` v2.11.1 | 自动生成绑定 |
| 异步运行时 | `tokio` + `Arc<RwLock<T>>` | 禁止 guard 内 .await |
| 错误处理 | `anyhow::Result<T>` + `SdkError` | 内部传播 + FFI 结构化 |
| 连接管理 | WS (JSON 信封 + protobuf data) | 与 Go SDK 一致 |
| 重连策略 | 循环退避 [1,2,4,8,16]s，最大 300 次 | 对齐 Go SDK |
| 同步器 | 泛型 Syncer + VersionSynchronizer | 对齐 Go SDK pkg/syncer |

---

## 10. 参考项目

| 项目 | 路径 | 用途 |
|------|------|------|
| Go SDK | `../openim-sdk-core` | IM 核心逻辑唯一权威参考 |
| Protocol | `../protocol` | Protobuf 定义 + 生成代码 |
| IM Server | `../open-im-server` | 服务端源码 |
| Docker | `../openim-docker` | 部署配置 |
| Flutter Demo | `../openim-flutter-demo` | UI 参考 |

---

## 附录 A：常量速查

### WebSocket 标识符

| 标识 | 值 | 说明 |
|------|-----|------|
| `GetNewestSeq` | 1001 | 获取所有会话最大 seq |
| `PullMsgByRange` | 1002 | 按 seq 范围拉取消息 |
| `SendMsg` | 1003 | 发送消息 |
| `PullMsgBySeqList` | 1005 | 按 seq 列表拉取消息 |
| `GetConvMaxReadSeq` | 1006 | 获取会话 maxSeq/hasReadSeq |
| `PushMsg` | 2001 | 服务端推送新消息 |

### ContentType

| 值 | 类型 |
|----|------|
| 101 | 文本 |
| 102 | 图片 |
| 103 | 语音 |
| 104 | 视频 |
| 105 | 文件 |
| 106 | @消息 |
| 107 | 引用 |
| 108 | 合并转发 |
| 109 | 名片 |
| 110 | 位置 |
| 111 | 表情 |
| 112 | 自定义 |
| 113 | 富文本 |
| 114 | Markdown |

### NotificationType

| 范围 | 类型 |
|------|------|
| 1200-1299 | 好友通知 |
| 1300-1399 | 用户通知 |
| 1500-1599 | 群组通知 |

### MsgStatus

| 值 | 含义 |
|----|------|
| 1 | 发送中 (Sending) |
| 2 | 发送成功 (Success) |
| 3 | 发送失败 (Failed) |
| 4 | 已删除 (Deleted) |

---

<div align="center">

**文档版本：v1.0 | 合并自 22 个分散文档 | 2026-06-04**

</div>
