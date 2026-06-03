# 消息同步器模块详细设计 (MessageSyncer)

> 模块路径: `rust/src/core/message/syncer.rs`
> Go SDK 对标: `internal/interaction/msg_sync.go` (760 行)

---

## 1. 模块职责

消息同步器是 IM SDK 的核心数据一致性层，负责在客户端本地消息数据库与服务端之间保持消息同步。核心职责包括：

| 职责 | 说明 |
|------|------|
| 登录后全量消息同步 | 首次登录或重连后，从服务端拉取所有缺失消息 |
| 重连后增量消息同步 | 网络恢复后，仅拉取断线期间的新消息 |
| 实时推送消息接收 | 接收服务端 PushMsg 推送，触发消息入库与 UI 更新 |
| Seq gap 检测与补拉 | 检测推送消息的 seq 连续性，gap 时自动补拉 |
| 重装模式处理 | 应用卸载重装时的全量数据恢复（区分通知类消息） |
| 后台唤醒同步 | App 从后台唤醒时触发增量同步 |

---

## 2. Go SDK 对标分析

### 2.1 核心结构 MsgSyncer

```go
type MsgSyncer struct {
    loginUserID            string                // 当前登录用户 ID
    longConnMgr            *LongConnMgr          // 连接管理器引用
    PushMsgAndMaxSeqCh     chan common.Cmd2Value  // 推送消息 & maxSeq 通道
    conversationEventQueue chan common.Cmd2Value  // 会话事件通道（通知上层）
    syncedMaxSeqs          map[string]int64      // 内存中各会话已同步的最大 Seq
    syncedMaxSeqsLock      sync.RWMutex          // syncedMaxSeqs 读写锁
    db                     db_interface.DataBase  // 数据库接口
    reinstalled            bool                  // 是否为重装模式
    isSyncing              bool                  // 是否正在同步
    isSyncingLock          sync.Mutex            // 同步状态锁
}
```

### 2.2 关键常量

```go
const (
    connectPullNums       = 1     // 连接后单次拉取数量
    defaultPullNums       = 10    // 默认单次拉取数量
    SplitPullMsgNum       = 100   // 批量拉取拆分阈值
    pullMsgGoroutineLimit = 10    // 并发拉取协程数
    maxConversations      = 500   // 最大会话数
    synMaxConversations   = 100   // 同步最大会话数
)
```

### 2.3 核心数据流

```
MsgSyncer 的输入通道:
  ┌─────────────────────────────────────────────┐
  │  PushMsgAndMaxSeqCh (from LongConnMgr)       │
  │                                               │
  │  CmdConnSuccesss  → doConnected()            │
  │  CmdPushMsg       → doPushMsg()              │
  │  CmdWakeUpDataSync → doWakeupDataSync()      │
  │  CmdIMMessageSync → doIMMessageSync()        │
  └─────────────────────────────────────────────┘
                     │
                     ▼
  ┌─────────────────────────────────────────────┐
  │  conversationEventQueue (to ConversationMgr)│
  │                                               │
  │  DispatchNewMessage      → 新消息到达         │
  │  DispatchNotification    → 通知消息到达        │
  │  DispatchSyncFlag        → 同步状态变更        │
  │  DispatchSyncData        → 同步数据到达        │
  │  DispatchMsgSyncInReinstall → 重装同步消息     │
  └─────────────────────────────────────────────┘
```

---

## 3. 同步触发时机

| 触发事件 | Cmd 常量 | 处理函数 | 说明 |
|----------|----------|----------|------|
| 连接成功 | `CmdConnSuccesss` | `doConnected()` | 长连接建立后的首次全量同步 |
| 推送消息 | `CmdPushMsg` | `doPushMsg()` | 服务端主动推送新消息 |
| 后台唤醒 | `CmdWakeUpDataSync` | `doWakeupDataSync()` | App 从后台切回前台 |
| 手动触发 | `CmdIMMessageSync` | `doIMMessageSync()` | 按指定会话列表手动同步 |

---

## 4. 全量同步流程 (doConnected)

`doConnected` 是连接成功后的核心同步入口，负责从服务端获取最新 Seq 并补拉所有缺失消息。

```
连接成功 → CmdConnSuccesss
  │
  ├─ 1. 并发保护检查 (startSync)
  │    ├─ isSyncing = true  → 返回 false，跳过
  │    └─ isSyncing = false → 设置 true，启动 5s 定时器自动释放
  │
  ├─ 2. 发布同步开始事件
  │    ├─ reinstalled = true  → DispatchSyncFlag(AppDataSyncStart)
  │    └─ reinstalled = false → DispatchSyncFlag(MsgSyncBegin)
  │
  ├─ 3. 获取服务端最新 Seq（带重试）
  │    ├─ 请求: GetMaxSeqReq { user_id }
  │    ├─ RPC: reqIdentifier = GetNewestSeq (1001)
  │    ├─ 重试策略: 最多 3 次，指数退避 2s → 4s → 8s
  │    │    ├─ 第1次失败 → 等待 2s
  │    │    ├─ 第2次失败 → 等待 4s
  │    │    └─ 第3次失败 → DispatchSyncFlag(MsgSyncFailed)，返回
  │    └─ 响应: GetMaxSeqResp { max_seqs: map[convID]maxSeq }
  │
  ├─ 4. compareSeqsAndBatchSync(maxSeqs, connectPullNums=1)
  │    │
  │    ├─ if reinstalled:
  │    │    ├─ 分离通知会话 vs 普通会话
  │    │    ├─ 通知会话: 直接更新 seq 到 DB（不拉取内容）
  │    │    ├─ 普通会话: 计算 needSyncSeqMap
  │    │    ├─ syncAndTriggerReinstallMsgs()
  │    │    ├─ SetAppSDKVersion(Installed=true)
  │    │    └─ reinstalled = false
  │    │
  │    └─ if !reinstalled:
  │         ├─ 对比 syncedMaxSeqs vs serverMaxSeqs
  │         ├─ 计算 needSyncSeqMap: [localMax+1, serverMax]
  │         └─ syncAndTriggerMsgs()
  │
  └─ 5. 发布同步完成事件
       ├─ reinstalled = true  → DispatchSyncFlag(AppDataSyncFinish)
       └─ reinstalled = false → DispatchSyncFlag(MsgSyncEnd)
```

### 4.1 compareSeqsAndBatchSync 详细逻辑

```go
func (m *MsgSyncer) compareSeqsAndBatchSync(ctx context.Context, maxSeqToSync map[string]int64, pullNums int64) {
    // 1. 构建 needSyncSeqMap
    needSyncSeqMap := make(map[string][2]int64)

    if m.reinstalled {
        // 重装模式：分离通知会话和普通会话
        for conversationID, seq := range maxSeqToSync {
            if IsNotification(conversationID) {
                // 通知会话：只更新 seq，不拉取内容
                if seq != 0 {
                    // 批量写入 notification_seq 表
                    // 更新内存 syncedMaxSeqs
                }
            } else {
                // 普通会话：计算差值
                if syncedMaxSeq, ok := m.syncedMaxSeqs[conversationID]; ok {
                    if seq > syncedMaxSeq {
                        needSyncSeqMap[conversationID] = [2]int64{syncedMaxSeq + 1, seq}
                    }
                } else {
                    needSyncSeqMap[conversationID] = [2]int64{0, seq}
                }
            }
        }
        // 标记重装完成
        defer m.db.SetAppSDKVersion(ctx, &model_struct.LocalAppSDKVersion{Installed: true})
        defer func() { m.reinstalled = false }()
        _ = m.syncAndTriggerReinstallMsgs(ctx, needSyncSeqMap, pullNums)
    } else {
        // 普通模式
        for conversationID, maxSeq := range maxSeqToSync {
            if syncedMaxSeq, ok := m.syncedMaxSeqs[conversationID]; ok {
                if maxSeq > syncedMaxSeq {
                    needSyncSeqMap[conversationID] = [2]int64{syncedMaxSeq + 1, maxSeq}
                }
            } else {
                if maxSeq != 0 {
                    needSyncSeqMap[conversationID] = [2]int64{0, maxSeq}
                }
            }
        }
        _ = m.syncAndTriggerMsgs(ctx, needSyncSeqMap, pullNums)
    }
}
```

### 4.2 syncAndTriggerMsgs 批量拉取逻辑

```go
func (m *MsgSyncer) syncAndTriggerMsgs(ctx context.Context, seqMap map[string][2]int64, syncMsgNum int64) error {
    tempSeqMap := make(map[string][2]int64, 50)
    msgNum := 0

    for k, v := range seqMap {
        oneConversationSyncNum := v[1] - v[0] + 1
        tempSeqMap[k] = v

        // 普通会话取 min(差值, syncMsgNum)
        if IsNotification(k) {
            msgNum += int(oneConversationSyncNum)
        } else {
            msgNum += int(min(oneConversationSyncNum, syncMsgNum))
        }

        // 累计达到 SplitPullMsgNum=100 时触发一批拉取
        if msgNum >= SplitPullMsgNum {
            resp, err := m.pullMsgBySeqRange(ctx, tempSeqMap, syncMsgNum)
            _ = m.triggerConversation(ctx, resp.Msgs)
            _ = m.triggerNotification(ctx, resp.NotificationMsgs)
            // 更新 syncedMaxSeqs
            tempSeqMap = make(map[string][2]int64, 50)
            msgNum = 0
        }
    }

    // 处理剩余消息
    if len(tempSeqMap) > 0 {
        resp, err := m.pullMsgBySeqRange(ctx, tempSeqMap, syncMsgNum)
        _ = m.triggerConversation(ctx, resp.Msgs)
        _ = m.triggerNotification(ctx, resp.NotificationMsgs)
        // 更新 syncedMaxSeqs
    }
    return nil
}
```

---

## 5. 增量同步（推送消息处理）

### 5.1 doPushMsg 入口

```go
func (m *MsgSyncer) doPushMsg(ctx context.Context, push *sdkws.PushMessages) {
    // 分别处理普通消息和通知消息
    m.pushTriggerAndSync(ctx, push.Msgs, m.triggerConversation)
    m.pushTriggerAndSync(ctx, push.NotificationMsgs, m.triggerNotification)
}
```

### 5.2 pushTriggerAndSync 流程

```
pushTriggerAndSync(pushMessages, triggerFunc)
  │
  ├─ 遍历每个 conversationID 的推送消息
  │    │
  │    ├─ 1. 提取有效消息（seq > 0 的消息）
  │    │    └─ seq == 0 的消息直接触发（不参与 seq 连续性校验）
  │    │
  │    ├─ 2. 计算期望的最后 seq
  │    │    expectedLast = syncedMaxSeqs[convID] + len(msgs)
  │    │
  │    ├─ 3. seq 连续性判断
  │    │    ├─ lastSeq == expectedLast → 连续
  │    │    │    ├─ 直接触发 triggerFunc
  │    │    │    ├─ 更新 syncedMaxSeqs[convID] = lastSeq
  │    │    │    └─ 加入 res 结果集
  │    │    │
  │    │    └─ lastSeq > syncedMaxSeqs[convID] → 存在 gap
  │    │         └─ 记录到 needSyncSeqMap: [syncedMaxSeq+1, lastSeq]
  │    │
  │    └─ 4. 批量触发连续的消息
  │         triggerFunc(ctx, res)
  │
  └─ 5. 补拉 gap 消息
       syncAndTriggerMsgs(ctx, needSyncSeqMap, defaultPullNums=10)
```

**关键逻辑：**
- 推送消息到达时，先检查 seq 是否与本地已同步的 seq 连续
- **连续**：直接触发消息处理（入库 + 通知 UI）
- **不连续（gap）**：记录需要补拉的 seq 范围，然后通过 RPC 补拉缺失消息
- 通知消息（`n_` 前缀的会话）与普通消息分开处理

---

## 6. LoadSeq 流程

LoadSeq 在 SDK 启动时从数据库加载各会话的已同步 seq 到内存。

```
启动时调用 LoadSeq()
  │
  ├─ 1. 获取所有会话 ID 列表
  │    conversationIDList = db.GetAllConversationIDList()
  │
  ├─ 2. 重装模式检测
  │    ├─ conversationIDList 为空
  │    │    └─ 获取 AppSDKVersion → Installed == false → reinstalled = true
  │    └─ conversationIDList 非空 → reinstalled = false
  │
  ├─ 3. 并发加载各会话的最大 seq
  │    ├─ 分批处理: 每批 20 个会话
  │    ├─ 并发 goroutine 加载
  │    │    └─ db.CheckConversationNormalMsgSeq(convID) → maxSyncedSeq
  │    └─ 合并结果到 syncedMaxSeqs
  │
  ├─ 4. 加载通知会话的 seq
  │    ├─ db.GetNotificationAllSeqs()
  │    └─ 合并到 syncedMaxSeqs
  │
  └─ 5. 记录日志
       log.ZDebug(ctx, "loadSeq", "syncedMaxSeqs", m.syncedMaxSeqs)
```

---

## 7. 重装模式特殊处理

### 7.1 重装检测

```go
// LoadSeq 中检测
if len(conversationIDList) == 0 {
    version, err := m.db.GetAppSDKVersion(ctx)
    if version == nil || !version.Installed {
        m.reinstalled = true
    }
}
```

**判断逻辑：** 如果本地数据库中没有任何会话记录，且 AppSDKVersion 未标记 Installed=true，则认为是重装模式。

### 7.2 重装模式与普通模式的差异

| 行为 | 普通模式 | 重装模式 |
|------|----------|----------|
| 同步开始事件 | `MsgSyncBegin` | `AppDataSyncStart` |
| 同步完成事件 | `MsgSyncEnd` | `AppDataSyncFinish` |
| 失败事件 | `MsgSyncFailed` | `MsgSyncFailed` |
| 通知会话处理 | 正常拉取内容 | **仅更新 seq，不拉取内容** |
| 普通会话处理 | 增量拉取 | 全量拉取 |
| 消息触发 | `triggerConversation` | `triggerReinstallConversation`（带 Total 参数） |
| 完成标记 | 无 | `SetAppSDKVersion(Installed=true)` |

### 7.3 重装模式特殊流程

```go
func (m *MsgSyncer) syncAndTriggerReinstallMsgs(ctx context.Context, seqMap map[string][2]int64, syncMsgNum int64) error {
    total := len(seqMap)

    for k, v := range seqMap {
        // ... 批量拉取 ...
        resp, err := m.pullMsgBySeqRange(ctx, tempSeqMap, syncMsgNum)

        // 检查拉取的消息是否全部已删除
        m.checkMessagesAndGetLastMessage(ctx, resp.Msgs)

        // 使用重装专用触发函数
        _ = m.triggerReinstallConversation(ctx, resp.Msgs, total)

        // 通知消息正常触发
        _ = m.triggerNotification(ctx, resp.NotificationMsgs)
    }
}
```

### 7.4 checkMessagesAndGetLastMessage

重装模式下，如果某会话拉取到的消息全部已删除（`status >= MsgStatusHasDeleted`），则通过 `PullConvLastMessage` (1007) 获取该会话的最新有效消息替换。

```go
func (m *MsgSyncer) checkMessagesAndGetLastMessage(ctx context.Context, messages map[string]*sdkws.PullMsgs) {
    var conversationIDs []string
    for conversationID, message := range messages {
        allInValid := true
        for _, data := range message.Msgs {
            if data.Status < constant.MsgStatusHasDeleted {
                allInValid = false
                break
            }
        }
        if allInValid {
            conversationIDs = append(conversationIDs, conversationID)
        }
    }
    if len(conversationIDs) > 0 {
        resp, err := m.fetchLatestValidMessages(ctx, conversationIDs)
        for conversationID, message := range resp.Msgs {
            messages[conversationID] = &sdkws.PullMsgs{Msgs: []*sdkws.MsgData{message}}
        }
    }
}
```

---

## 8. Rust 实现架构图

```
┌──────────────────────────────────────────────────────────────────┐
│                       MessageSyncer                               │
│                                                                    │
│  ┌────────────────────────┐  ┌──────────────────────────────┐    │
│  │   Sync State Machine    │  │     SyncedMaxSeqs (内存)      │    │
│  │                          │  │  HashMap<String, i64>        │    │
│  │  ┌──────────┐           │  │  convID → max_seq            │    │
│  │  │ Idle     │ ◄────┐   │  │  (RwLock<HashMap>)           │    │
│  │  │          │      │   │  └──────────────────────────────┘    │
│  │  └─────┬────┘      │   │                                       │
│  │        │ sync_lock  │   │  ┌──────────────────────────────┐    │
│  │        ▼            │   │  │  Database Layer               │    │
│  │  ┌──────────┐      │   │  │  ├─ ConversationDao           │    │
│  │  │ Syncing  │──────┘   │  │  ├─ MessageDao                │    │
│  │  │          │ (5s timeout)│  │  └─ SyncVersionDao          │    │
│  │  └──────────┘           │  └──────────────────────────────┘    │
│  └────────────────────────┘                                        │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    数据流                                   │    │
│  │                                                            │    │
│  │  SdkEvent::Connected ──► sync_after_reconnect()           │    │
│  │                              │                             │    │
│  │                              ├─ get_server_max_seqs()      │    │
│  │                              │    └─ RPC(1001) GetMaxSeq   │    │
│  │                              │                             │    │
│  │                              ├─ compare & build sync_map   │    │
│  │                              │                             │    │
│  │                              └─ batch_pull_messages()      │    │
│  │                                   └─ RPC(1002) PullMsgs    │    │
│  │                                        └─ handle_pulled()  │    │
│  │                                             └─ MessageHandler│   │
│  │                                                            │    │
│  │  SdkEvent::PushMessage ──► (client.rs dispatch)          │    │
│  │       │                                                    │    │
│  │       ├─ MessageHandler.handle_messages()                  │    │
│  │       └─ push_trigger_and_sync(conv_id, seqs)              │    │
│  │            │                                               │    │
│  │            ├─ seq 连续 → 更新 synced_max_seqs             │    │
│  │            └─ seq gap → batch_pull_messages()              │    │
│  └──────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

---

## 9. 涉及的数据库表

### 9.1 local_conversations

```sql
-- 获取所有会话 ID 和 max_seq
-- DAO: ConversationDao.get_all_seq_pairs() → Vec<(String, i64)>
-- DAO: ConversationDao.update_max_seq(conv_id, max_seq)

CREATE TABLE local_conversations (
    conversation_id TEXT PRIMARY KEY,
    max_seq         INTEGER NOT NULL DEFAULT 0,
    min_seq         INTEGER NOT NULL DEFAULT 0,
    -- ... 其他会话字段
);
```

**用途：**
- `get_all_seq_pairs()` — LoadSeq 时获取所有会话的 (conversation_id, max_seq)
- `update_max_seq()` — 同步完成后更新服务端返回的 max_seq

### 9.2 local_chat_logs

```sql
-- 获取某会话的最大 seq
-- DAO: MessageDao.get_max_seq(conv_id) → i64
-- DAO: MessageDao.batch_insert(msgs)

CREATE TABLE local_chat_logs (
    conversation_id TEXT NOT NULL,
    server_msg_id   TEXT PRIMARY KEY,
    client_msg_id   TEXT NOT NULL,
    seq             INTEGER NOT NULL DEFAULT 0,
    -- ... 其他消息字段
);
```

**用途：**
- `get_max_seq()` — LoadSeq 时获取各会话本地最大消息 seq
- `batch_insert()` — 拉取消息后批量入库

### 9.3 local_notification_seqs

```sql
-- 获取所有通知会话的 seq
-- DAO: SyncVersionDao.get_notification_all_seqs()

CREATE TABLE local_notification_seqs (
    conversation_id TEXT PRIMARY KEY,
    seq             INTEGER NOT NULL DEFAULT 0
);
```

**用途：**
- `get_notification_all_seqs()` — LoadSeq 时加载通知会话的 seq
- 重装模式下，通知会话只更新此表，不拉取消息内容

### 9.4 local_app_sdk_version

```sql
-- 检测是否为重装模式
-- DAO: SyncVersionDao.is_reinstalled()
-- DAO: SyncVersionDao.mark_reinstall_complete(version)

CREATE TABLE local_app_sdk_version (
    id         INTEGER PRIMARY KEY,
    installed  BOOLEAN NOT NULL DEFAULT FALSE,
    version    TEXT,
    updated_at DATETIME
);
```

**用途：**
- `is_reinstalled()` — 本地无会话 + Installed=false → 重装模式
- `mark_reinstall_complete()` — 全量同步完成后标记 Installed=true

---

## 10. Rust 当前实现对比

### 10.1 已实现的功能

| 功能 | 状态 | 说明 |
|------|------|------|
| 获取服务端 maxSeq | ✅ 已实现 | `get_server_max_seqs()` → RPC(1001) |
| 增量消息拉取 | ✅ 已实现 | `sync_incremental_messages()` → RPC(1002) |
| 推送消息 seq 连续性检查 | ✅ 已实现 | `push_trigger_and_sync()` |
| 重装模式检测 | ✅ 已实现 | `sync_version_dao.is_reinstalled()` |
| 重装模式全量拉取 | ✅ 已实现 | `sync_all_messages_reinstall()` |
| 并发同步保护 | ✅ 已实现 | `sync_lock: Arc<Mutex<()>>` (try_lock) |
| 从 DB 加载 seq 到内存 | ✅ 已实现 | `load_synced_max_seqs()` |
| 推送消息触发同步 | ✅ 已实现 | 在 `client.rs` 的 push_message_handler 中处理 |

### 10.2 缺失的功能

| 功能 | Go SDK 实现 | Rust 当前状态 | 优先级 |
|------|-------------|---------------|--------|
| 连接成功同步 | `doConnected()` 发布 SyncBegin 事件 | 直接在 client.rs 调用 `sync_after_reconnect()` | 中 |
| 通知消息特殊处理 | 重装模式下通知会话只更新 seq 不拉内容 | 未区分通知/普通会话 | **高** |
| GetNewestSeq 重试 | 3 次重试，2s → 4s → 8s 指数退避 | 无重试机制 | **高** |
| LoadSeq 并发分批加载 | 每批 20 个会话，并发 goroutine | `load_synced_max_seqs()` 顺序加载 | 中 |
| 后台唤醒同步 | `CmdWakeUpDataSync` → `doWakeupDataSync()` | 未实现 | 中 |
| 手动触发同步 | `CmdIMMessageSync` → `doIMMessageSync()` | 未实现 | 低 |
| syncAndTriggerMsgs 批量拆分 | 每 100 条拆分一批拉取 | 每 50 条拆分 | 低 |
| checkMessagesAndGetLastMessage | 重装模式下检查已删除消息并替换 | 未实现 | 中 |
| AppDataSyncStart/Finish 事件 | 重装模式发布进度事件 | SyncStarted/SyncFinished 简化 | 中 |
| 5s 同步锁超时释放 | startSync 5s 后自动释放 isSyncing | try_lock 不释放 | 高 |
| GetConvMaxReadSeq 手动同步 | doIMMessageSync 通过 1006 拉取 | 未实现 | 低 |
| PullConvLastMessage | 重装时拉取最后有效消息 | 未实现 | 中 |
| SyncProgress 进度上报 | OnSyncProgress 回调 | SyncProgress 事件已定义 | 低 |
| GetLastMessageReq 拉取 | 重装时替换已删除消息 | 未实现 | 中 |

### 10.3 需要修改的部分

| 修改项 | 当前实现 | Go SDK 对标 | 说明 |
|--------|----------|-------------|------|
| 拉取分批阈值 | 50 条 | 100 条 (SplitPullMsgNum) | 对齐为 100 |
| 同步锁机制 | `try_lock()` (不等待) | `startSync()` (5s 超时释放) | 改为带超时的互斥锁 |
| 重连同步触发 | client.rs 直接调用 | MsgSyncer 监听 CmdConnSuccesss | 对齐事件驱动模式 |
| LoadSeq 加载方式 | 顺序加载 | 并发分批加载(20/batch) | 提升启动速度 |
| 推送消息处理 | client.rs 分发 | MsgSyncer.doPushMsg → pushTriggerAndSync | 对齐分层 |
| 连接参数获取 | 直接传参 | 通过 context 获取 | 对齐上下文模式 |

---

## 11. 测试用例设计

| 测试用例 | 描述 | 预期结果 | 优先级 |
|----------|------|----------|--------|
| `test_full_sync_after_login` | 登录后首次全量同步 | 获取服务端 maxSeq，对比本地 seq，拉取并入库所有缺失消息 | P0 |
| `test_incremental_sync_on_push` | 推送消息到达时增量同步 | seq 连续时直接入库；有 gap 时自动补拉缺失消息 | P0 |
| `test_gap_detection_and_pull` | 推送消息 seq 不连续 | 检测到 gap → RPC(1002) 补拉 → 补拉消息入库 | P0 |
| `test_gap_detection_no_gap` | 推送消息 seq 完全连续 | 直接触发消息处理，不发送 RPC | P0 |
| `test_reinstalled_mode_full_pull` | 重装模式下全量拉取 | 通知会话只更新 seq 不拉内容；普通会话全量拉取 | P0 |
| `test_reinstalled_mode_notification_only` | 重装模式下通知会话处理 | notification_seqs 表更新，不触发消息拉取 RPC | P1 |
| `test_reinstalled_mode_mark_complete` | 重装同步完成后标记 | `local_app_sdk_version.installed = true`，`reinstalled = false` | P1 |
| `test_get_max_seq_retry` | GetMaxSeq RPC 失败重试 | 第 1 次失败 → 等 2s → 第 2 次失败 → 等 4s → 第 3 次成功 | P0 |
| `test_get_max_seq_all_retry_fail` | GetMaxSeq 3 次全部失败 | 发布 MsgSyncFailed 事件，不进行同步 | P1 |
| `test_wakeup_sync` | 后台唤醒同步 | 获取服务端最新 Seq → 对比 → 增量拉取 | P1 |
| `test_concurrent_sync_protection` | 多个同步事件同时到达 | 仅一个同步执行，其余被跳过（5s 内） | P0 |
| `test_concurrent_sync_timeout_release` | 同步锁 5s 后自动释放 | 5s 后新同步事件可以获取锁并执行 | P1 |
| `test_load_seq_empty_db` | 空数据库 + Installed=false | `reinstalled = true`，syncedMaxSeqs 为空 | P1 |
| `test_load_seq_with_data` | 数据库有会话记录 | syncedMaxSeqs 正确加载，`reinstalled = false` | P0 |
| `test_load_seq_concurrent` | 大量会话(1000+)并发加载 | 分批(20/批)并发加载，无死锁，内存正确 | P1 |
| `test_load_notification_seqs` | 加载通知会话 seq | notification_seqs 正确合并到 syncedMaxSeqs | P1 |
| `test_sync_and_trigger_msgs_batch_split` | 超过 100 条消息分批拉取 | 按 SplitPullMsgNum=100 分批，每批独立 RPC | P1 |
| `test_sync_and_trigger_msgs_empty` | 无需同步的消息 | 直接返回 Ok(())，不发送 RPC | P2 |
| `test_push_msg_seq_zero` | 推送消息 seq=0 | seq=0 的消息直接触发，不参与连续性检查 | P1 |
| `test_check_deleted_messages_reinstall` | 重装模式拉取到已删除消息 | 通过 PullConvLastMessage(1007) 获取最新有效消息替换 | P1 |

---

## 附录：相关文件索引

| 文件 | 说明 |
|------|------|
| `rust/src/core/message/syncer.rs` | Rust 消息同步器实现 |
| `rust/src/sdk/client/client.rs` | 客户端主入口，包含 push_message_handler |
| `rust/src/domain/event/types.rs` | SdkEvent 事件定义（SyncStarted/SyncFinished 等） |
| `rust/src/domain/constant/types.rs` | msg_sync_status 常量定义 |
| `rust/src/infra/database/` | DAO 层实现 |
| Go SDK: `internal/interaction/msg_sync.go` | Go 消息同步器（760 行） |
| Go SDK: `pkg/constant/constant.go` | 常量定义（CmdConnSuccesss 等） |
| Go SDK: `pkg/common/notification.go` | Dispatch 系列辅助函数 |
| Protocol: `sdkws.proto` | GetMaxSeqReq/Resp, PullMessageBySeqsReq/Resp 定义 |

---

## 附录：Go SDK 事件常量对照

```go
// 同步状态
const (
    MsgSyncBegin      = 1001  // 普通同步开始
    MsgSyncProcessing = 1002  // 同步进行中
    MsgSyncEnd        = 1003  // 普通同步完成
    MsgSyncFailed     = 1004  // 同步失败
    AppDataSyncStart  = 1005  // 重装同步开始
    AppDataSyncFinish = 1006  // 重装同步完成
)

// Cmd 通道命令
const (
    CmdPushMsg        = "pushMsg"          // 推送消息
    CmdConnSuccesss   = "connSuccess"      // 连接成功
    CmdWakeUpDataSync = "wakeUpDataSync"   // 后台唤醒
    CmdIMMessageSync  = "imMessageSync"    // 手动触发
)
```

Rust 侧对应的事件:
```rust
// SdkEvent 枚举
SyncStarted,                          // 对应 MsgSyncBegin / AppDataSyncStart
SyncProgress { progress, message },   // 对应 OnSyncProgress
SyncFinished,                         // 对应 MsgSyncEnd / AppDataSyncFinish
SyncFailed { error },                 // 对应 MsgSyncFailed
Connected,                            // 对应 CmdConnSuccesss
```
