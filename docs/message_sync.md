# 消息同步方案文档

> 基于 Go SDK (`openim-sdk-core`) 实现分析，对比 Rust SDK 当前状态，明确差异与补齐计划。

---

## 一、消息同步提供的能力

消息同步是 IM SDK 的核心模块，负责保证**客户端本地消息与服务端数据最终一致**。具体提供以下能力：

| 能力 | 说明 |
|------|------|
| **登录后全量同步** | 登录成功后，拉取所有会话的缺失消息，补齐本地数据 |
| **重连后增量同步** | WebSocket 断线重连后，拉取断线期间的新增消息 |
| **推送消息实时处理** | 服务端推送新消息时，实时入库、去重、触发 UI 更新 |
| **推送消息 seq 校验** | 检查推送消息 seq 连续性，不连续时自动补拉缺失消息 |
| **重装后全量恢复** | 清除本地数据后重新登录，从服务端全量拉取历史消息 |
| **消息去重** | 通过 clientMsgId + seq 双重校验，避免重复消息入库 |
| **异常消息处理** | 处理 seq 间隙、已删除消息、重复消息等异常场景 |
| **会话同步** | 同步会话列表、未读数、已读 seq 等元数据 |
| **通知消息路由** | 区分普通消息和通知消息（好友申请、群组变更、已读回执等），分发到对应处理器 |

---

## 二、Go SDK 实现架构

### 2.1 核心组件关系

```
┌──────────────────────────────────────────────────────────┐
│                    WebSocket 层                           │
│  LongConnMgr.readPump() → handleMessage()               │
│    ├── PushMsg(2001) → doPushMsg() → MessageBatcher     │
│    ├── RPC 响应 → Syncer.NotifyResp()                    │
│    └── KickMsg/Logout → 错误处理                         │
└──────────────┬───────────────────────────────────────────┘
               │ MessageBatcher (聚合 50ms~1s)
               ▼
┌──────────────────────────────────────────────────────────┐
│              MsgSyncer (消息同步控制器)                    │
│  DoListener() 监听 PushMsgAndMaxSeqCh:                    │
│    ├── CmdConnSuccesss → doConnected()                   │
│    ├── CmdWakeUpDataSync → doWakeupDataSync()            │
│    ├── CmdIMMessageSync → doIMMessageSync()              │
│    └── CmdPushMsg → doPushMsg()                          │
│                                                          │
│  核心方法:                                               │
│    compareSeqsAndBatchSync() → seq 对比 + 分片拉取       │
│    syncAndTriggerMsgs() → 分批 PullMessageBySeqRange     │
│    pushTriggerAndSync() → 推送 seq 连续性检查 + 补拉      │
└──────────────┬───────────────────────────────────────────┘
               │ DispatchNewMessage / DispatchUpdateConversation
               ▼
┌──────────────────────────────────────────────────────────┐
│              Conversation (会话消息处理器)                 │
│  Work() 命令分发:                                        │
│    ├── CmdNewMsgCome → doMsgNew() (去重 + 入库 + 回调)   │
│    ├── CmdNotification → doNotificationManager()         │
│    ├── CmdUpdateConversation → doUpdateConversation()    │
│    ├── CmdSyncFlag → syncFlag() (同步阶段控制)           │
│    └── CmdSyncData → syncData() (数据同步)               │
│                                                          │
│  MaxSeqRecorder: 内存中记录每个会话的最大 seq             │
└──────────────────────────────────────────────────────────┘
```

### 2.2 同步触发时机

| 触发时机 | 入口函数 | 拉取数量 | 说明 |
|---------|---------|---------|------|
| WebSocket 连接成功 | `doConnected()` | `connectPullNums=1` | 仅拉取最新1条，快速同步 |
| App 从后台唤醒 | `doWakeupDataSync()` | `defaultPullNums=10` | 拉取10条，平衡实时性与性能 |
| 推送消息到达 | `doPushMsg()` | 按 gap 范围 | 检查 seq 连续性，不连续时补拉 |
| 手动触发同步 | `doIMMessageSync()` | `defaultPullNums=10` | 指定会话列表同步 |

### 2.3 重试与容错

```
doConnected():
  GetMaxSeqReq → 失败?
    → 重试1次 (1s delay)
    → 重试2次 (2s delay)
    → 重试3次 (4s delay)
    → 仍失败 → 发布 MsgSyncFailed

startSync():
  isSyncing=true → 5秒后自动释放锁
  防止并发同步导致数据不一致
```

---

## 三、WebSocket API 涉及

### 3.1 请求标识（ReqIdentifier）

| 标识 | 值 | 方向 | 说明 |
|------|-----|------|------|
| `GetNewestSeq` | 1001 | 请求 | 获取所有会话的最大 seq |
| `PullMsgByRange` | 1002 | 请求 | 按 seq 范围拉取消息 |
| `SendMsg` | 1003 | 请求 | 发送消息 |
| `PullMsgBySeqList` | 1005 | 请求 | 按 seq 列表拉取消息（历史消息补缺） |
| `GetConvMaxReadSeq` | 1006 | 请求 | 获取会话的 maxSeq 和 hasReadSeq |
| `PullConvLastMessage` | 1007 | 请求 | 拉取会话最后一条消息 |
| `PushMsg` | 2001 | 推送 | 服务端推送新消息 |

### 3.2 请求/响应结构

#### GetMaxSeqReq / GetMaxSeqResp

```protobuf
message GetMaxSeqReq {
  string userID = 1;
}

message GetMaxSeqResp {
  map<string, int64> maxSeqs = 1;  // conversationID → maxSeq
}
```

**用途**: 登录/重连后获取服务端各会话的最新 seq，与本地对比确定需要拉取的范围。

#### PullMessageBySeqsReq / PullMessageBySeqsResp

```protobuf
message SeqRange {
  string conversationID = 1;
  int64 begin = 2;
  int64 end = 3;
  int64 num = 4;        // 每个会话最多拉取的消息数
}

message PullMessageBySeqsReq {
  string userID = 1;
  repeated SeqRange seqRanges = 2;
  PullOrder order = 3;  // 0=Asc, 1=Desc
}

message PullMessageBySeqsResp {
  map<string, PullMsgs> msgs = 1;             // 普通消息
  map<string, PullMsgs> notificationMsgs = 2; // 通知消息
}

message PullMsgs {
  repeated MsgData msgs = 1;
  bool isEnd = 2;
  int64 endSeq = 3;
}
```

**用途**: 按会话和 seq 范围批量拉取消息，是消息同步的核心 API。

#### PushMessages（推送）

```protobuf
message PushMessages {
  map<string, PullMsgs> msgs = 1;             // 普通消息推送
  map<string, PullMsgs> notificationMsgs = 2; // 通知消息推送
}
```

**用途**: 服务端实时推送新消息，经 MessageBatcher 聚合后处理。

#### GetConversationsHasReadAndMaxSeqReq / Resp

```protobuf
message GetConversationsHasReadAndMaxSeqReq {
  string userID = 1;
  repeated string conversationIDs = 2;
}

message GetConversationsHasReadAndMaxSeqResp {
  map<string, HasReadSeqAndMaxSeq> seqs = 1;
}

message HasReadSeqAndMaxSeq {
  int64 maxSeq = 1;
  int64 hasReadSeq = 2;
}
```

**用途**: 同步会话的已读/未读状态，计算未读数。

---

## 四、数据库涉及

### 4.1 核心表结构

#### local_chat_logs（消息表）

| 字段 | 类型 | 说明 |
|------|------|------|
| `client_msg_id` | VARCHAR(64) PK | 客户端消息 ID |
| `server_msg_id` | VARCHAR(64) | 服务端消息 ID |
| `send_id` | VARCHAR(64) | 发送者 ID |
| `recv_id` | VARCHAR(64) INDEX | 接收者 ID |
| `sender_platform_id` | INT | 发送者平台 |
| `sender_nick_name` | VARCHAR(255) | 发送者昵称 |
| `sender_face_url` | VARCHAR(255) | 发送者头像 |
| `session_type` | INT | 会话类型 (1=单聊, 3=群聊, 4=通知) |
| `msg_from` | INT | 消息来源 (100=用户, 200=系统) |
| `content_type` | INT INDEX | 消息类型 (101=文本, 102=图片...) |
| `content` | VARCHAR(1000) | 消息内容 |
| `is_read` | BOOL | 是否已读 |
| `status` | INT | 状态 (1=发送中, 2=成功, 3=失败, 4=已删除) |
| `seq` | INT64 INDEX | 服务端分配的序列号 |
| `send_time` | INT64 INDEX | 发送时间戳 |
| `create_time` | INT64 | 创建时间戳 |
| `attached_info` | VARCHAR(1024) | 附加信息 |
| `ex` | VARCHAR(1024) | 扩展字段 |
| `local_ex` | VARCHAR(1024) | 本地扩展 |

#### local_conversations（会话表）

| 字段 | 类型 | 说明 |
|------|------|------|
| `conversation_id` | VARCHAR(128) PK | 会话 ID |
| `conversation_type` | INT | 会话类型 |
| `user_id` | VARCHAR(64) | 用户 ID |
| `group_id` | VARCHAR(128) | 群组 ID |
| `show_name` | VARCHAR(255) | 显示名称 |
| `face_url` | VARCHAR(255) | 头像 URL |
| `recv_msg_opt` | INT | 消息接收选项 |
| `unread_count` | INT32 | 未读消息数 |
| `group_at_type` | INT | @ 类型 |
| `latest_msg` | VARCHAR(1000) | 最新消息内容 |
| `latest_msg_send_time` | INT64 INDEX | 最新消息发送时间 |
| `draft_text` | TEXT | 草稿内容 |
| `draft_text_time` | INT64 | 草稿时间 |
| `is_pinned` | BOOL | 是否置顶 |
| `is_private_chat` | BOOL | 是否私密聊天 |
| `burn_duration` | INT32 | 阅后即焚时长 |
| `max_seq` | INT64 | 最大 seq |
| `min_seq` | INT64 | 最小 seq |
| `is_msg_destruct` | BOOL | 是否消息自毁 |
| `msg_destruct_time` | INT64 | 消息自毁时间 |

#### local_notification_seqs（通知序列表）

| 字段 | 类型 | 说明 |
|------|------|------|
| `conversation_id` | VARCHAR(128) PK | 会话 ID |
| `seq` | INT64 | 已处理的通知 seq |

#### local_seq（序列表）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | VARCHAR(64) PK | 标识 |
| `min_seq` | UINT32 | 最小 seq |

#### local_version_sync（版本同步表）

| 字段 | 类型 | 说明 |
|------|------|------|
| `table` | VARCHAR(64) PK | 表名 |
| `entity_id` | VARCHAR(64) PK | 实体 ID (如 userID) |
| `version_id` | VARCHAR(64) | 版本 ID |
| `version` | INT64 | 版本号 |
| `uid_list` | TEXT | UID 列表 |

#### local_sending_messages（发送中消息表）

| 字段 | 类型 | 说明 |
|------|------|------|
| `conversation_id` | VARCHAR(128) PK | 会话 ID |
| `client_msg_id` | VARCHAR(64) PK | 客户端消息 ID |

### 4.2 数据库操作（消息同步相关）

| 操作 | 方法 | 说明 |
|------|------|------|
| 批量插入消息 | `BatchInsertMessageList` | INSERT OR IGNORE，主键冲突自动跳过 |
| 单条插入消息 | `InsertMessage` | 插入单条消息 |
| 按 ClientMsgID 查询 | `GetMessagesByClientMsgIDs` | 去重：检查本地是否已有相同消息 |
| 按 Seq 查询 | `GetMessagesBySeqs` | 历史消息翻页时按 seq 获取 |
| 更新消息 | `UpdateMessage` / `UpdateColumnsMessage` | 更新 seq、status 等字段 |
| 批量更新消息 | 逐条 `UpdateMessage` 兜底 | 批量失败时逐条重试 |
| 标记已读(按 seq) | `MarkConversationMessageAsReadBySeqs` | 已读回执处理 |
| 标记已读(按 ID) | `MarkConversationMessageAsReadDB` | 已读回执处理 |
| 获取会话 seq | `CheckConversationNormalMsgSeq` | LoadSeq 时获取本地 maxSeq |
| 设置通知 seq | `SetNotificationSeq` | 更新通知消息处理进度 |
| 获取所有通知 seq | `GetNotificationAllSeqs` | LoadSeq 时加载通知 seq |
| 获取会话列表 | `GetAllConversationListDB` / `GetAllConversations` | 同步会话时获取本地数据 |
| 更新会话 | `UpdateOrCreateConversations` | 批量更新或插入会话 |
| 获取会话信息 | `GetConversation` | 查询单个会话 |

---

## 五、消息去重机制

### 5.1 推送消息去重（MsgSyncer 层）

```
pushTriggerAndSync(pushMsgs):
  for each (convID, msgs) in pushMsgs:
    lastSeq = msgs中最大seq
    expectedLast = syncedMaxSeqs[convID] + len(msgs)
    
    if lastSeq == expectedLast:
      → seq 连续，直接触发 doMsgNew
      → 更新 syncedMaxSeqs[convID] = lastSeq
    else if lastSeq > syncedMaxSeqs[convID]:
      → seq 有 gap，记录 [syncedMaxSeq+1, lastSeq] 待拉取
      → 先触发已有消息，再补拉 gap
    else:
      → 重复推送，跳过
```

### 5.2 拉取消息去重（Conversation 层）

```
pullMessageIntoTable(pullMsgData):
  // 1. 批量查询本地已有消息
  localMessages = GetMessagesByClientMsgIDs(convID, allMsgIDs)
  localMessagesMap = key by ClientMsgID
  
  // 2. 当前批次内去重
  processedMsgIDs = {}
  
  for each msg:
    if processedMsgIDs contains msg.ClientMsgID:
      → handleExceptionMessages (CLIENT_DUP)
      continue
    
    if msg.Status == MsgStatusHasDeleted:
      → handleExceptionMessages (DELETED)
      continue
    
    if msg.SendID == loginUserID:
      // 自己发的消息
      if localMessagesMap contains msg.ClientMsgID:
        if existing.Seq == 0:
          → updateMessage (补 seq)
        else:
          → handleExceptionMessages (SEQ_DUP)
      else:
        → selfInsertMessage (其他终端同步)
    else:
      // 别人发的消息
      if localMessagesMap contains msg.ClientMsgID:
        → handleExceptionMessages (CLIENT_DUP)
      else:
        → othersInsertMessage (正常新消息)
    
    processedMsgIDs[msg.ClientMsgID] = msg
```

### 5.3 异常消息处理（4 类）

| 异常类型 | 条件 | 处理方式 |
|---------|------|---------|
| `[SEQ_GAP_+{seq}]` | existingMsg=nil, ClientMsgID="" | 生成占位消息，ClientMsgID 加 seq 前缀 |
| `[DELETED]` | existingMsg=nil, Status=Deleted | 标记为已删除，保留原始 ClientMsgID |
| `[SEQ_DUP]` | existingMsg!=nil, Seq 相同 | 并发填充冲突，标记已删除 |
| `[CLIENT_DUP]` | existingMsg!=nil, Seq 不同 | 客户端重复发送，标记已删除 |

所有异常消息的 ClientMsgID 都会追加 8 位随机后缀以保证主键唯一。

### 5.4 未读计数逻辑

```
doMsgNew 中:
  if msg.SendID != loginUserID:
    if maxSeqRecorder.IsNewMsg(convID, msg.Seq):
      // seq > 当前记录的 maxSeq，是真正的新消息
      unreadCount = 1
      maxSeqRecorder.Incr(convID, 1)
    else:
      // 重复或旧消息，不增加未读数
      unreadCount = 0
```

---

## 六、同步阶段标志

| 标志 | 值 | 含义 |
|------|-----|------|
| `MsgSyncBegin` | 1001 | 普通消息同步开始 |
| `MsgSyncProcessing` | 1002 | 同步进行中 |
| `MsgSyncEnd` | 1003 | 普通消息同步结束 |
| `MsgSyncFailed` | 1004 | 同步失败 |
| `AppDataSyncStart` | 1005 | 重装后全量同步开始 |
| `AppDataSyncFinish` | 1006 | 重装后全量同步结束 |

### 重装 vs 正常同步的差异

| 维度 | 正常同步 | 重装同步 |
|------|---------|---------|
| 同步标志 | `MsgSyncBegin/End` | `AppDataSyncStart/Finish` |
| 通知消息 | 正常拉取处理 | 只更新 seq，不拉取消息体 |
| 会话触发 | `triggerConversation` | `triggerReinstallConversation` |
| 完成后操作 | 无 | 设置 `Installed=true`, `reinstalled=false` |
| 会话数据同步 | 不触发 | 同步群组、好友、会话等基础数据 |

---

## 七、关键常量

| 常量 | 值 | 说明 |
|------|-----|------|
| `connectPullNums` | 1 | 连接成功后每个会话拉取的消息数 |
| `defaultPullNums` | 10 | 唤醒/手动同步时每个会话拉取的消息数 |
| `SplitPullMsgNum` | 100 | 分片拉取阈值，累计消息数达 100 时触发一次 PullRPC |
| `PullMsgNumForReadDiffusion` | 50 | 已读扩散拉取量 |
| `pullMsgGoroutineLimit` | 10 | 拉取并发 goroutine 上限 |
| `maxConversations` | 500 | 最大支持会话数 |
| `maxBatchMessages` | 400 | MessageBatcher 批量上限 |
| `lowLoadMessageLimit` | 20 | 低负载阈值（10秒内少于20条） |
| `highLoadMessageLimit` | 200 | 高负载阈值 |
| `minAggregationDelay` | 50ms | 低负载聚合延迟 |
| `maxAggregationDelay` | 1s | 高负载聚合延迟 |

---

## 八、完整数据流

```
                        ┌─────────────────┐
                        │   服务端推送      │
                        └────────┬────────┘
                                 │ WebSocket Binary
                                 ▼
                    ┌────────────────────────┐
                    │  LongConnMgr           │
                    │  readPump()            │
                    │  → handleMessage()     │
                    │  → 解压 + 解码          │
                    │  → doPushMsg()         │
                    │    → proto.Unmarshal    │
                    └────────┬───────────────┘
                             │ PushMessages
                             ▼
                    ┌────────────────────────┐
                    │  MessageBatcher        │
                    │  Enqueue()             │
                    │  → 低负载: 直接 flush   │
                    │  → 高负载: 聚合 50ms~1s │
                    └────────┬───────────────┘
                             │ DispatchPushMsg
                             ▼
                    ┌────────────────────────┐
                    │  MsgSyncer             │
                    │  DoListener()          │
                    │  → doPushMsg()         │
                    │  → pushTriggerAndSync() │
                    │    ├─ seq 连续 → 直接触发│
                    │    └─ seq gap → 补拉     │
                    └────────┬───────────────┘
                             │ DispatchNewMessage
                             ▼
                    ┌────────────────────────┐
                    │  Conversation          │
                    │  Work(CmdNewMsgCome)   │
                    │  → doMsgNew()          │
                    │    ├─ 去重检查          │
                    │    ├─ 入库/更新         │
                    │    ├─ 未读计数          │
                    │    └─ 触发回调          │
                    └────────┬───────────────┘
                             │ OnRecvNewMessage
                             ▼
                    ┌────────────────────────┐
                    │  Flutter UI            │
                    │  Provider 更新状态      │
                    └────────────────────────┘
```

---

## 九、Rust SDK 当前实现 vs Go SDK 差异

### 9.1 架构对比

| 模块 | Go SDK | Rust SDK | 状态 |
|------|--------|----------|------|
| **MsgSyncer** | `interaction/msg_sync.go` | `core/message/syncer.rs` | ✅ 已实现 |
| **MessageHandler** | `conversation_msg/conversation_msg.go` doMsgNew | `core/message/handler.rs` | ✅ 已实现（简化） |
| **LongConnMgr** | `interaction/long_conn_mgr.go` | `core/connection/manager.rs` | ✅ 已实现 |
| **MessageBatcher** | `interaction/message_batcher.go` | 无 | ❌ 未实现 |
| **MaxSeqRecorder** | `conversation_msg/max_seq_recorder.go` | 内嵌在 syncer.rs | ⚠️ 合并实现 |
| **Notification处理** | `conversation_msg/notification.go` | handler.rs 内联 | ⚠️ 简化 |
| **消息连续性检查** | `conversation_msg/message_check.go` | 无 | ❌ 未实现 |
| **异常消息处理** | `handleExceptionMessages` | 简单 INSERT OR IGNORE | ⚠️ 简化 |
| **会话 Hash Read Seq 同步** | `conversation_msg/sync.go` | 无 | ❌ 未实现 |
| **会话增量同步** | `conversation_msg/incremental_sync.go` | 无 | ❌ 未实现 |
| **通用 Syncer 框架** | `pkg/syncer/` | 无 | ❌ 未实现 |

### 9.2 功能差异明细

#### A. 已实现（对齐 Go SDK）

| 功能 | Go SDK 位置 | Rust SDK 位置 | 差异说明 |
|------|------------|--------------|---------|
| GetMaxSeq 获取 | `msg_sync.go:429` | `syncer.rs:61` | ✅ 已对齐 |
| Seq 对比计算 | `msg_sync.go:280` | `syncer.rs:220` | ✅ 已对齐 |
| PullMessageBySeqRange | `msg_sync.go:668` | `syncer.rs:352` | ✅ 已对齐 |
| 推送消息 seq 连续性检查 | `msg_sync.go:378` | `syncer.rs:134` | ✅ 已对齐 |
| 增量同步（normal） | `msg_sync.go:507` | `syncer.rs:220` | ✅ 已对齐 |
| 消息入库去重 | `conversation_msg.go:260` | `handler.rs:84` | ⚠️ 简化版 |
| 会话创建/更新 | `conversation_msg.go:157` | `handler.rs:163` | ✅ 已对齐 |
| NewMessage 事件 | `conversation_msg.go:474` | `handler.rs:215` | ✅ 已对齐 |
| 已读回执处理 | `read_drawing.go:227` | `handler.rs:227` | ⚠️ 基本对齐，缺少群聊已读 |
| 同步锁 | `msg_sync.go:349` | `syncer.rs:32` | ✅ 已对齐（Mutex vs isSyncing） |

#### B. 未实现（需要补齐）

| 功能 | Go SDK 位置 | 重要性 | 说明 |
|------|------------|--------|------|
| **MessageBatcher 聚合** | `message_batcher.go` | P2 | 高负载场景下避免频繁处理，可后续补 |
| **重试机制** | `msg_sync.go:429` 3次重试+指数退避 | P1 | 连接同步失败时无重试，可能导致同步丢失 |
| **通知消息特殊处理** | `msg_sync.go:566` reinstall 时通知只更新 seq | P1 | 重装时通知消息会错误地拉取消息体 |
| **消息连续性检查** | `message_check.go:23-84` | P1 | 历史消息翻页时缺少 seq gap 检测和补拉 |
| **异常消息处理** | `message_check.go:369` 4类异常 | P1 | 当前仅 INSERT OR IGNORE，缺少异常标记 |
| **会话 Hash Read Seq** | `sync.go:30` | P1 | 未同步会话的 maxSeq/hasReadSeq，未读数不准 |
| **会话增量同步** | `incremental_sync.go:26` | P2 | 基于 VersionSynchronizer 的会话增量同步 |
| **MaxSeqRecorder.IsNewMsg** | `max_seq_recorder.go:47` | P1 | 未读计数依赖此判断，当前实现不完整 |
| **唤醒同步 pullNums** | `msg_sync.go:473` defaultPullNums=10 | P2 | 唤醒时拉取数量与连接时未区分 |
| **doIMMessageSync** | `msg_sync.go:485` | P2 | 手动触发指定会话同步 |
| **syncFlag 多阶段同步** | `sync.go:67` AppDataSyncStart 时同步群组/好友/会话 | P1 | 重装后缺少基础数据同步 |
| **前台/后台区分** | `newMessage:742` 区分在线/离线消息回调 | P2 | 前台/后台消息回调不同 |
| **拉取消息分片** | `syncAndTriggerMsgs:507` 按 SplitPullMsgNum=100 分片 | P1 | 当前按 batch_size=50 分片，逻辑正确但阈值不同 |

#### C. 过度实现（可简化）

| 功能 | 说明 |
|------|------|
| `batch_pull_messages_reinstall` | 与 `batch_pull_messages` 代码几乎完全重复，应合并 |
| `pull_and_handle_messages_reinstall` | 与 `pull_and_handle_messages` 代码几乎完全重复，应合并 |
| `sync_all_messages_reinstall` | 与 `sync_incremental_messages` 逻辑高度重叠，应合并 |
| `clone_for_task()` | 手动 clone 所有字段，可直接 `Arc::clone` |

### 9.3 数据库差异

| 表 | Go SDK | Rust SDK | 差异 |
|---|--------|----------|------|
| `local_chat_logs` | GORM 模型完整 | SQLite 模型基本对齐 | ✅ 字段一致 |
| `local_conversations` | 含 MaxSeq/MinSeq | 含 MaxSeq/MinSeq | ✅ 字段一致 |
| `local_notification_seqs` | 独立表 | 无 | ❌ 缺失 |
| `local_seq` | 存 MinSeq | 无 | ❌ 缺失 |
| `local_version_sync` | 版本同步表 | 无 | ❌ 缺失（会话增量同步用） |
| `local_sending_messages` | 发送中消息表 | 无 | ⚠️ 可选，发送状态管理用 |

### 9.4 优先补齐建议

#### P0 — 必须补齐（影响消息正确性）

1. **重试机制** — GetMaxSeq 失败时至少重试 2 次
2. **MaxSeqRecorder.IsNewMsg** — 未读计数准确性依赖此方法
3. **异常消息处理** — 至少区分 `CLIENT_DUP` 和 `DELETED`，避免重复消息
4. **syncFlag 多阶段同步** — 重装后同步群组/好友/会话基础数据

#### P1 — 应该补齐（影响用户体验）

5. **消息连续性检查** — 历史消息翻页时检测并补拉 seq gap
6. **会话 Hash Read Seq 同步** — 准确计算未读数
7. **重装时通知消息特殊处理** — 只更新 seq 不拉消息体
8. **唤醒同步用更大的 pullNums** — 区分连接和唤醒场景

#### P2 — 可后续补齐

9. **MessageBatcher** — 高负载聚合，初期可不需要
10. **会话增量同步** — VersionSynchronizer 框架
11. **前台/后台区分回调** — 影响离线消息展示

---

## 十、Rust 代码重构建议

### 10.1 合并重复方法

当前 syncer.rs 中以下方法高度重复，建议合并：

```
当前: 6 个方法 → 建议: 2 个方法

batch_pull_messages()          ┐
batch_pull_messages_reinstall() ┘ → do_batch_pull(seq_map, mode)

pull_and_handle_messages()          ┐
pull_and_handle_messages_reinstall() ┘ → pull_and_handle(seq_map, mode)

sync_incremental_messages()        ┐
sync_all_messages_reinstall()      ┘ → compute_need_sync(server_seqs, mode)
```

### 10.2 推荐的新 syncer 结构

```rust
enum SyncMode {
    Normal,      // 增量同步
    Reinstall,   // 重装全量
}

pub struct MessageSyncer {
    // ... 现有字段 ...

    /// 通用分片拉取入口
    async fn do_batch_pull(
        &self,
        seq_map: &HashMap<String, (i64, i64)>,
        mode: SyncMode,
    ) -> Result<()>;

    /// 构建拉取请求并执行
    async fn pull_messages(
        &self,
        seq_map: &HashMap<String, (i64, i64)>,
    ) -> Result<PullMessageBySeqsResp>;

    /// 计算需要同步的 seq 范围
    async fn compute_need_sync(
        &self,
        server_seqs: &HashMap<String, i64>,
    ) -> Result<HashMap<String, (i64, i64)>>;
}
```
