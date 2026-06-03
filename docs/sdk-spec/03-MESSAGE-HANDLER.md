# 03 - 消息处理器模块详细设计

> 本文档为 Rust SDK 重写参考规范，详细描述消息处理器（MessageHandler）的设计与实现。
> Go SDK 对标文件：`internal/conversation_msg/conversation_msg.go`（约 955 行）

---

## 1. 模块职责

消息处理器是 IM SDK 的核心模块之一，负责：

- **消息入库**：收到推送/拉取的消息后，解析、去重并持久化到本地 SQLite
- **消息去重**：基于 `clientMsgID` 检查消息是否已存在，避免重复入库
- **会话自动创建/更新**：根据消息来源自动创建新会话或更新已有会话
- **未读数管理**：正确计算和维护每个会话的未读消息数
- **通知消息路由**：将通知类消息按 ContentType 分发到各业务模块（好友、群组、用户等）
- **已读回执处理**：处理来自其他设备或对端的已读回执

---

## 2. Go SDK 对标分析

### 2.1 核心文件

| 文件 | 行数 | 职责 |
|------|------|------|
| `conversation_msg.go` | 955 | 消息处理主逻辑（doMsgNew、diff、批量操作） |
| `notification.go` | 520 | Work() 事件分发、doNotificationManager 路由、syncData/syncFlag |
| `max_seq_recorder.go` | 52 | 内存 Seq 追踪器，防止未读数重复计数 |
| `send_queue.go` | 239 | 消息发送队列（详见 04-MESSAGE-SENDER.md） |

### 2.2 关键数据结构

```go
// Go SDK - Conversation 核心结构（conversation_msg.go L47-80）
type Conversation struct {
    *interaction.LongConnMgr
    db                          db_interface.DataBase
    conversationSyncer          *syncer.Syncer[...]
    ConversationListener        func() OnConversationListener
    msgListener                 func() OnAdvancedMsgListener
    msgSyncerCh                 chan common.Cmd2Value
    conversationEventQueue      chan common.Cmd2Value
    loginUserID                 string
    maxSeqRecorder              MaxSeqRecorder  // 内存 seq 追踪
    sender                      *messageSender  // 消息发送器
    // ...
}
```

```go
// Go SDK - MaxSeqRecorder（max_seq_recorder.go L19-52）
type MaxSeqRecorder struct {
    seqs map[string]int64  // conversationID → maxSeq
    lock sync.RWMutex
}

func (m *MaxSeqRecorder) IsNewMsg(conversationID string, seq int64) bool {
    m.lock.RLock()
    defer m.lock.RUnlock()
    return seq > m.seqs[conversationID]
}
```

---

## 3. doMsgNew 核心流程

`doMsgNew` 是消息处理器中最关键的函数，处理新到达的消息。以下是详细的分步说明。

### 3.1 整体流程图

```
消息到达
    │
    ▼
Step 1: 按 conversationID 分组
    │
    ▼
Step 2: 逐消息处理
    │  ├── 解析 Options
    │  ├── 处理 MsgStatusHasDeleted
    │  ├── PopulateMsgStructByContentType（反序列化内容）
    │  └── 按发送者路由
    │       ├── 自己发送 → 更新 seq / 处理异常
    │       └── 他人发送 → 检查去重 → 创建会话 / 增加未读
    │
    ▼
Step 3: 会话 Diff
    │  获取 DB 中已有会话 → diff() → 识别变更/新增会话
    │
    ▼
Step 4: 批量操作
    │  ├── batchUpdateMessageList（更新 seq 消息）
    │  ├── batchInsertMessageList（插入新消息）
    │  ├── BatchUpdateConversationList（更新变更会话）
    │  └── BatchInsertConversationList（插入新会话）
    │
    ▼
Step 5: 触发通知
    │  ├── newMessage → OnRecvNewMessage / OnRecvOfflineNewMessage
    │  ├── OnNewConversation
    │  ├── OnConversationChanged
    │  └── OnTotalUnreadMessageCountChanged
```

### 3.2 Step 1: 按会话分组并去重

```go
// Go SDK conversation_msg.go L250-L265
for conversationID, msgs := range allMsg {
    // 收集所有 clientMsgID
    clientIDs := make([]string, 0, len(msgs.Msgs))
    for _, msg := range msgs.Msgs {
        clientIDs = append(clientIDs, msg.ClientMsgID)
    }
    // 批量查询 DB 中已存在的消息
    clientMsgs, err := c.db.GetMessagesByClientMsgIDs(ctx, conversationID, clientIDs)
    clientMsgMap := datautil.SliceToMap(clientMsgs, func(e *LocalChatLog) string {
        return e.ClientMsgID
    })
}
```

**关键点：**
- 按 `conversationID` 分组后，对每个会话批量查询已存在的 `clientMsgID`
- 构建 `clientMsgMap`（clientMsgID → LocalChatLog），用于后续去重判断
- Rust 中对应方法：`message_dao.get_by_client_msg_ids()`

### 3.3 Step 2: 逐消息处理

#### 2a. 解析消息选项（Options）

```go
// Go SDK conversation_msg.go L273-L281
isHistory = utils.GetSwitchFromOptions(v.Options, constant.IsHistory)
isUnreadCount = utils.GetSwitchFromOptions(v.Options, constant.IsUnreadCount)
isConversationUpdate = utils.GetSwitchFromOptions(v.Options, constant.IsConversationUpdate)
isNotPrivate = utils.GetSwitchFromOptions(v.Options, constant.IsNotPrivate)
isSenderConversationUpdate = utils.GetSwitchFromOptions(v.Options, constant.IsSenderConversationUpdate)
```

| Option | 含义 | 默认 |
|--------|------|------|
| `IsHistory` | 是否为历史消息（非实时推送） | true |
| `IsUnreadCount` | 是否计入未读数 | true |
| `IsConversationUpdate` | 是否更新会话（最新消息、时间等） | true |
| `IsNotPrivate` | 是否为非私聊模式 | false |
| `IsSenderConversationUpdate` | 发送者是否也更新会话 | false |

#### 2b. 处理已删除消息

```go
// Go SDK conversation_msg.go L286-L292
if msg.Status == constant.MsgStatusHasDeleted {
    dbMessage := converter.MsgStructToLocalChatLog(msg)
    c.handleExceptionMessages(ctx, nil, dbMessage)
    exceptionMsg = append(exceptionMsg, dbMessage)
    insertMessage = append(insertMessage, dbMessage)
    continue
}
```

云端标记删除的消息直接插入本地，不更新会话和未读数。

#### 2c. 反序列化消息内容

```go
// Go SDK conversation_msg.go L297-L301
err := converter.PopulateMsgStructByContentType(msg)
// 根据 ContentType 将 JSON bytes 反序列化到对应的结构体字段
// 例如：101(Text) → TextElem, 102(Picture) → PictureElem, 103(Sound) → SoundElem ...
```

#### 2d. 按发送者路由 — 自己发送的消息

```go
// Go SDK conversation_msg.go L316-L356
if v.SendID == c.loginUserID {
    existingMsg, ok := clientMsgMap[msg.ClientMsgID]
    if ok {
        if existingMsg.Seq == 0 {
            // 本地有记录但 Seq 为 0（正在发送中）→ 更新 seq/status
            msg.Status = constant.MsgStatusFiltered
            updateMessage = append(updateMessage, converter.MsgStructToLocalChatLog(msg))
        } else {
            // 本地有记录且有 Seq → 异常处理（重复消息）
            dbMessage := converter.MsgStructToLocalChatLog(msg)
            c.handleExceptionMessages(ctx, existingMsg, dbMessage)
            insertMessage = append(insertMessage, dbMessage)
            exceptionMsg = append(exceptionMsg, dbMessage)
        }
    } else {
        // 本地无记录 → 其他终端同步来的消息
        // 构建会话结构体，根据 isConversationUpdate / isSenderConversationUpdate 决定是否更新
        lc := model_struct.LocalConversation{...}
        if isConversationUpdate && isSenderConversationUpdate {
            c.updateConversation(&lc, conversationSet)
        }
        if isHistory {
            selfInsertMessage = append(selfInsertMessage, ...)
        }
    }
}
```

#### 2e. 按发送者路由 — 他人发送的消息

```go
// Go SDK conversation_msg.go L357-L398
else {
    existingMsg, ok := clientMsgMap[msg.ClientMsgID]
    if !ok {
        // 新消息：创建会话、计算未读数
        lc := model_struct.LocalConversation{...}
        
        if isUnreadCount {
            if c.maxSeqRecorder.IsNewMsg(conversationID, msg.Seq) {
                isTriggerUnReadCount = true
                lc.UnreadCount = 1
                c.maxSeqRecorder.Incr(conversationID, 1)
            }
        }
        
        if isConversationUpdate {
            c.updateConversation(&lc, conversationSet)
            newMessages = append(newMessages, msg)
        }
        
        if isHistory {
            othersInsertMessage = append(othersInsertMessage, ...)
        }
    } else {
        // 已存在 → 异常处理
        dbMessage := converter.MsgStructToLocalChatLog(msg)
        c.handleExceptionMessages(ctx, existingMsg, dbMessage)
        insertMessage = append(insertMessage, dbMessage)
        exceptionMsg = append(exceptionMsg, dbMessage)
    }
}
```

### 3.4 Step 3: 会话 Diff

```go
// Go SDK conversation_msg.go L410-L427
list, err := c.db.GetMultipleConversationDB(ctx, conversationIDs)
m := datautil.SliceToMap(list, ...)

c.diff(ctx, m, conversationSet, conversationChangedSet, newConversationSet)
```

`diff()` 函数逻辑（conversation_msg.go L621-L647）：

```go
func (c *Conversation) diff(ctx context.Context, local, generated, cc, nc map[string]*LocalConversation) {
    for _, v := range generated {
        if localC, ok := local[v.ConversationID]; ok {
            // 已有会话 → 合并未读数，更新最新消息
            localC.UnreadCount = localC.UnreadCount + v.UnreadCount
            if v.LatestMsgSendTime > localC.LatestMsgSendTime {
                localC.LatestMsg = v.LatestMsg
                localC.LatestMsgSendTime = v.LatestMsgSendTime
            }
            cc[v.ConversationID] = localC  // changed
        } else {
            // 新会话 → 添加到 new set
            nc[v.ConversationID] = v  // new
        }
    }
}
```

### 3.5 Step 4: 批量数据库操作

```go
// Go SDK conversation_msg.go L430-L471
// 1. 批量更新已有消息的 seq
c.batchUpdateMessageList(ctx, updateMsg)

// 2. 批量插入新消息
c.batchInsertMessageList(ctx, insertMsg)

// 3. 批量更新已变更的会话
c.db.BatchUpdateConversationList(ctx, changedList)

// 4. 批量插入新会话
c.db.BatchInsertConversationList(ctx, newList)
```

### 3.6 Step 5: 触发通知事件

```go
// Go SDK conversation_msg.go L474-L498
// 1. 新消息通知（区分前台/后台）
c.newMessage(ctx, newMessages, conversationChangedSet, newConversationSet, onlineMap)

// 2. 新会话通知
if len(newConversationSet) > 0 {
    c.ConversationListener().OnNewConversation(data)
}

// 3. 会话变更通知
if len(conversationChangedSet) > 0 {
    c.ConversationListener().OnConversationChanged(data)
}

// 4. 总未读数变更通知
if isTriggerUnReadCount {
    c.OnTotalUnreadMessageCountChanged(ctx)
}
```

**新消息通知的前台/后台区分**（conversation_msg.go L739-L771）：

```
前台模式:
  - 遍历新消息列表
  - Typing 消息跳过
  - 在线消息 → OnRecvOnlineOnlyMessage（不入库，仅 UI 展示）
  - 其他消息 → OnRecvNewMessage（已入库）

后台模式:
  - 检查 GlobalRecvMsgOpt
  - 遍历新消息列表
  - RecvMsgOpt == ReceiveMessage → OnRecvOfflineNewMessage
```

---

## 4. MaxSeqRecorder 机制

### 4.1 设计目的

`MaxSeqRecorder` 是一个纯内存的序列号追踪器，用于防止同一消息的未读数被重复计数。

### 4.2 工作原理

```
消息到达（seq=5, isUnreadCount=true）
    │
    ▼
IsNewMsg("conv_1", 5)?
    │
    ├── seq(5) > currentSeq(3) → true → 未读数 +1, Incr("conv_1", 1)
    │
    └── seq(5) <= currentSeq(5) → false → 跳过
```

### 4.3 Go SDK 实现（max_seq_recorder.go 全文）

```go
type MaxSeqRecorder struct {
    seqs map[string]int64  // conversationID → 当前追踪的 maxSeq
    lock sync.RWMutex
}

func NewMaxSeqRecorder() MaxSeqRecorder {
    return MaxSeqRecorder{seqs: make(map[string]int64)}
}

func (m *MaxSeqRecorder) Get(conversationID string) int64 {
    m.lock.RLock()
    defer m.lock.RUnlock()
    return m.seqs[conversationID]
}

func (m *MaxSeqRecorder) Set(conversationID string, seq int64) {
    m.lock.Lock()
    defer m.lock.Unlock()
    m.seqs[conversationID] = seq
}

func (m *MaxSeqRecorder) Incr(conversationID string, num int64) {
    m.lock.Lock()
    defer m.lock.Unlock()
    m.seqs[conversationID] += num
}

func (m *MaxSeqRecorder) IsNewMsg(conversationID string, seq int64) bool {
    m.lock.RLock()
    defer m.lock.RUnlock()
    return seq > m.seqs[conversationID]
}
```

### 4.4 Rust 实现参考

```rust
use std::collections::HashMap;
use std::sync::RwLock;

pub struct MaxSeqRecorder {
    seqs: RwLock<HashMap<String, i64>>,
}

impl MaxSeqRecorder {
    pub fn new() -> Self {
        Self { seqs: RwLock::new(HashMap::new()) }
    }

    pub fn is_new_msg(&self, conversation_id: &str, seq: i64) -> bool {
        let seqs = self.seqs.read().unwrap();
        let current = seqs.get(conversation_id).copied().unwrap_or(0);
        seq > current
    }

    pub fn incr(&self, conversation_id: &str, num: i64) {
        let mut seqs = self.seqs.write().unwrap();
        *seqs.entry(conversation_id.to_string()).or_insert(0) += num;
    }

    pub fn get(&self, conversation_id: &str) -> i64 {
        let seqs = self.seqs.read().unwrap();
        seqs.get(conversation_id).copied().unwrap_or(0)
    }

    pub fn set(&self, conversation_id: &str, seq: i64) {
        let mut seqs = self.seqs.write().unwrap();
        seqs.insert(conversation_id.to_string(), seq);
    }
}
```

---

## 5. doNotificationManager 路由

通知消息按照 `ContentType` 的数值范围分发到不同的业务模块。

### 5.1 路由规则

```go
// Go SDK notification.go L116-L148
func (c *Conversation) doNotificationManager(c2v common.Cmd2Value) {
    for conversationID, msgs := range allMsg {
        for _, msg := range msgs.Msgs {
            if msg.ContentType > constant.FriendNotificationBegin && 
               msg.ContentType < constant.FriendNotificationEnd {
                c.relation.DoNotification(ctx, msg)       // 好友通知
            } else if msg.ContentType > constant.UserNotificationBegin && 
                      msg.ContentType < constant.UserNotificationEnd {
                c.user.DoNotification(ctx, msg)            // 用户通知
            } else if msg.ContentType > constant.GroupNotificationBegin && 
                      msg.ContentType < constant.GroupNotificationEnd {
                c.group.DoNotification(ctx, msg)           // 群组通知
            } else {
                c.DoNotification(ctx, msg)                  // 会话通知
            }
        }
        // 更新 notification seq
        if len(msgs.Msgs) != 0 {
            lastMsg := msgs.Msgs[len(msgs.Msgs)-1]
            c.db.SetNotificationSeq(ctx, conversationID, lastMsg.Seq)
        }
    }
}
```

### 5.2 ContentType 范围定义

| 范围 | 模块 | 说明 |
|------|------|------|
| 1200-1299 | relation（好友） | 好友申请、好友删除、黑名单变更等 |
| 1301-1399 | user（用户） | 用户信息变更、在线状态、用户命令等 |
| 1500-1599 | group（群组） | 群创建、成员进出、群信息变更等 |
| 1650-1699 | super group（超级群） | 超级群更新、消息删除等 |
| 1701-1704 | conversation（会话） | 私聊变更、未读通知、会话清理等 |
| 2000-2099 | business（业务） | 自定义业务通知 |
| 2101-2102 | conversation（会话） | 消息撤回、消息删除 |
| 2200 | conversation（会话） | 已读回执 |

### 5.3 Conversation.DoNotification 处理的类型

```go
// Go SDK notification.go L157-L175
func (c *Conversation) doNotification(ctx context.Context, msg *sdkws.MsgData) error {
    switch msg.ContentType {
    case constant.ConversationChangeNotification:       // 1300
        return c.DoConversationChangedNotification(ctx, msg)
    case constant.ConversationPrivateChatNotification:  // 1701
        return c.DoConversationIsPrivateChangedNotification(ctx, msg)
    case constant.BusinessNotification:                 // 2001
        return c.doBusinessNotification(ctx, msg)
    case constant.RevokeNotification:                   // 2101
        return c.doRevokeMsg(ctx, msg)
    case constant.ClearConversationNotification:         // 1703
        return c.doClearConversations(ctx, msg)
    case constant.DeleteMsgsNotification:               // 2102
        return c.doDeleteMsgs(ctx, msg)
    case constant.HasReadReceipt:                       // 2200
        return c.doReadDrawing(ctx, msg)
    }
}
```

---

## 6. Work() 事件分发

`Work()` 是消息处理模块的事件入口，从 `conversationEventQueue` channel 接收命令并分发处理。

### 6.1 命令分发表

```go
// Go SDK notification.go L46-L65
func (c *Conversation) Work(c2v common.Cmd2Value) {
    switch c2v.Cmd {
    case constant.CmdNewMsgCome:            → c.doMsgNew(c2v)            // 新消息到达
    case constant.CmdUpdateConversation:    → c.doUpdateConversation(c2v) // 更新会话
    case constant.CmdUpdateMessage:         → c.doUpdateMessage(c2v)      // 更新消息（头像/昵称）
    case constant.CmdNotification:          → c.doNotificationManager(c2v) // 通知消息路由
    case constant.CmdSyncData:              → c.syncData(c2v)            // 同步数据
    case constant.CmdSyncFlag:              → c.syncFlag(c2v)            // 同步标志（开始/结束/失败）
    case constant.CmdMsgSyncInReinstall:    → c.doMsgSyncByReinstalled(c2v) // 重装消息同步
    }
}
```

### 6.2 各命令详细说明

| 命令 | 触发时机 | 处理逻辑 |
|------|----------|----------|
| `CmdNewMsgCome` | WebSocket 推送新消息 / Pull 拉取结果 | 核心处理流程（见第 3 节） |
| `CmdUpdateConversation` | 会话状态变化（新消息更新 latestMsg、未读数变更等） | 根据 Action 类型更新会话字段并通知 |
| `CmdUpdateMessage` | 用户头像/昵称变更 | 更新相关会话中消息的 sender 信息 |
| `CmdNotification` | 收到通知类消息 | 按 ContentType 范围路由（见第 5 节） |
| `CmdSyncData` | 增量同步触发 | 同步会话、好友、群组等数据 |
| `CmdSyncFlag` | 同步开始/完成/失败标志 | 通知 UI 同步进度 |
| `CmdMsgSyncInReinstall` | 重装后全量消息同步 | 批量插入消息 + 更新会话 + 报告进度 |

### 6.3 syncFlag 处理（notification.go L67-L114）

```
AppDataSyncStart:
  ├── 并行: SyncAllJoinedGroupsAndMembers, IncrSyncFriends
  ├── 同步: IncrSyncConversations, SyncAllConversationHashReadSeqs
  ├── 并行: SyncLoginUserInfo, SyncAllBlackList
  └── 通知: OnSyncServerStart → OnSyncServerProgress(1→10)

AppDataSyncFinish:
  └── 通知: OnSyncServerProgress(100) → OnSyncServerFinish

MsgSyncBegin:
  └── 调用 syncData

MsgSyncFailed:
  └── 通知: OnSyncServerFailed

MsgSyncEnd:
  └── 通知: OnSyncServerFinish
```

### 6.4 syncData 处理（notification.go L411-L435）

```go
func (c *Conversation) syncData(c2v common.Cmd2Value) {
    c.conversationSyncMutex.Lock()
    defer c.conversationSyncMutex.Unlock()
    
    // 同步执行：SyncAllConversationHashReadSeqs
    // 异步执行（不等待）：
    //   - user.SyncLoginUserInfo
    //   - relation.SyncAllBlackList
    //   - group.SyncAllJoinedGroupsAndMembersWithLock
    //   - relation.IncrSyncFriendsWithLock
    //   - IncrSyncConversationsWithLock
}
```

---

## 7. Rust 实现状态

### 7.1 已实现

| 功能 | 文件 | 状态 | 说明 |
|------|------|------|------|
| 消息去重 | `core/message/handler.rs` | ✅ 已实现 | 基于 `client_msg_ids` 批量查询去重 |
| 消息入库 | `core/message/handler.rs` | ✅ 已实现 | `batch_insert` 批量插入 |
| 会话自动创建 | `core/message/handler.rs` | ✅ 已实现 | 消息到达时自动创建会话 |
| 会话更新 | `core/message/handler.rs` | ✅ 已实现 | `update_after_new_message` |
| 未读数管理 | `core/message/handler.rs` | ✅ 已实现 | 新会话 unread_count=1 |
| 消息同步 | `core/message/syncer.rs` | ✅ 已实现 | 增量同步 + 重装同步 + 推送触发 |
| 已读回执 | `core/message/handler.rs` | ✅ 已实现 | `handle_read_receipt` |
| 消息撤回 | `core/message/service.rs` | ✅ 已实现 | `revoke_message` |
| 消息删除 | `core/message/service.rs` | ✅ 已实现 | `delete_messages` |
| 标记已读 | `core/message/service.rs` | ✅ 已实现 | `mark_conversation_as_read` |
| 消息搜索 | `core/message/service.rs` | ✅ 已实现 | `search_local_messages` |
| 发送消息 | `sdk/client/message.rs` | ✅ 已实现 | 含媒体上传、乐观更新、超时重试 |
| Seq 连续性校验 | `core/message/syncer.rs` | ✅ 已实现 | `push_trigger_and_sync` |

### 7.2 未实现 / 待完善

| 功能 | 对标 Go SDK | 优先级 | 说明 |
|------|-------------|--------|------|
| MaxSeqRecorder | `max_seq_recorder.go` | 🔴 高 | 内存 seq 追踪器，防止未读数重复计数。当前实现缺少此机制 |
| Work() 事件分发 | `notification.go` L46-L65 | 🔴 高 | 缺少统一的命令分发机制（当前用 EventBus 替代） |
| doNotificationManager | `notification.go` L116-L148 | 🔴 高 | 通知消息按 ContentType 路由到各模块（好友/群组/用户） |
| MsgStatusHasDeleted | `conversation_msg.go` L286-L292 | 🟡 中 | 已删除消息的特殊处理 |
| Options 解析 | `conversation_msg.go` L273-L281 | 🟡 中 | 消息选项解析（IsHistory、IsUnreadCount 等） |
| doMsgSyncByReinstalled | `conversation_msg.go` L514-L606 | 🟡 中 | 重装后消息同步的特殊处理（含进度报告） |
| batchUpdateMessageList | `conversation_msg.go` L667-L711 | 🟡 中 | 批量更新消息 seq 并同步会话 latestMsg |
| diff() 会话对比 | `conversation_msg.go` L621-L647 | 🟡 中 | 会话变更检测和未读数合并 |
| OnRecvOfflineNewMessage | `conversation_msg.go` L739-L771 | 🟢 低 | 后台模式消息通知 |
| OnRecvOnlineOnlyMessage | `conversation_msg.go` L739-L771 | 🟢 低 | 在线消息通知（不入库） |
| Typing 消息处理 | `conversation_msg.go` L487-L493 | 🟢 低 | Typing 消息不存储、不计未读 |
| faceURLAndNicknameHandle | `conversation_msg.go` L844-L898 | 🟢 低 | 会话头像/昵称补全 |

---

## 8. 涉及的数据库表

### 8.1 local_chat_logs

```sql
CREATE TABLE local_chat_logs (
    conversation_id TEXT NOT NULL,
    client_msg_id   TEXT NOT NULL,
    server_msg_id   TEXT NOT NULL DEFAULT '',
    send_id         TEXT NOT NULL DEFAULT '',
    recv_id         TEXT NOT NULL DEFAULT '',
    sender_platform_id INTEGER NOT NULL DEFAULT 0,
    sender_nick_name TEXT NOT NULL DEFAULT '',
    sender_face_url TEXT NOT NULL DEFAULT '',
    session_type    INTEGER NOT NULL DEFAULT 0,
    msg_from        INTEGER NOT NULL DEFAULT 0,
    content_type    INTEGER NOT NULL DEFAULT 0,
    content         TEXT NOT NULL DEFAULT '',
    is_read         INTEGER NOT NULL DEFAULT 0,
    status          INTEGER NOT NULL DEFAULT 0,
    seq             INTEGER NOT NULL DEFAULT 0,
    send_time       INTEGER NOT NULL DEFAULT 0,
    create_time     INTEGER NOT NULL DEFAULT 0,
    attached_info   TEXT NOT NULL DEFAULT '',
    ex              TEXT NOT NULL DEFAULT '',
    local_ex        TEXT NOT NULL DEFAULT '',
    group_id        TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (conversation_id, client_msg_id)
);
```

**DAO 方法：**

| 方法 | SQL 操作 | 用途 |
|------|----------|------|
| `batch_insert` | INSERT OR IGNORE | 批量插入消息（自然去重） |
| `get_by_client_msg_ids` | SELECT ... WHERE client_msg_id IN (?) | 批量查询已有消息（去重） |
| `get_by_client_msg_id` | SELECT ... WHERE client_msg_id = ? | 单条查询 |
| `update` | UPDATE ... WHERE client_msg_id = ? | 更新 seq/status |
| `update_content_type` | UPDATE content_type WHERE client_msg_id = ? | 消息撤回 |
| `mark_as_read_by_seqs` | UPDATE is_read=1 WHERE seq IN (?) | 标记已读 |
| `mark_as_read_by_max_seq` | UPDATE is_read=1 WHERE seq <= ? | 按 maxSeq 标记已读 |
| `get_max_seq` | SELECT MAX(seq) WHERE conversation_id = ? | 获取会话最大 seq |
| `delete_by_client_msg_id` | DELETE WHERE client_msg_id = ? | 删除消息 |
| `update_send_status` | UPDATE status WHERE client_msg_id = ? | 更新发送状态 |
| `update_after_send_success` | UPDATE server_msg_id, send_time, status | 发送成功后更新 |
| `search_by_keyword` | SELECT ... WHERE content LIKE ? | 本地搜索 |

### 8.2 local_conversations

```sql
CREATE TABLE local_conversations (
    conversation_id         TEXT PRIMARY KEY,
    conversation_type       INTEGER NOT NULL DEFAULT 0,
    user_id                 TEXT NOT NULL DEFAULT '',
    group_id                TEXT NOT NULL DEFAULT '',
    show_name               TEXT NOT NULL DEFAULT '',
    face_url                TEXT NOT NULL DEFAULT '',
    latest_msg              TEXT NOT NULL DEFAULT '',
    latest_msg_send_time    INTEGER NOT NULL DEFAULT 0,
    unread_count            INTEGER NOT NULL DEFAULT 0,
    recv_msg_opt            INTEGER NOT NULL DEFAULT 0,
    is_pinned               INTEGER NOT NULL DEFAULT 0,
    is_private_chat         INTEGER NOT NULL DEFAULT 0,
    burn_duration           INTEGER NOT NULL DEFAULT 0,
    group_at_type           INTEGER NOT NULL DEFAULT 0,
    is_not_in_group         INTEGER NOT NULL DEFAULT 0,
    update_unread_count_time INTEGER NOT NULL DEFAULT 0,
    attached_info           TEXT NOT NULL DEFAULT '',
    ex                      TEXT NOT NULL DEFAULT '',
    draft_text              TEXT NOT NULL DEFAULT '',
    draft_text_time         INTEGER NOT NULL DEFAULT 0,
    max_seq                 INTEGER NOT NULL DEFAULT 0,
    min_seq                 INTEGER NOT NULL DEFAULT 0,
    is_msg_destruct         INTEGER NOT NULL DEFAULT 0,
    msg_destruct_time       INTEGER NOT NULL DEFAULT 0
);
```

**DAO 方法：**

| 方法 | SQL 操作 | 用途 |
|------|----------|------|
| `upsert` | INSERT OR REPLACE | 创建或更新会话 |
| `get_by_id` | SELECT ... WHERE conversation_id = ? | 查询单个会话 |
| `update_after_new_message` | UPDATE latest_msg, latest_msg_send_time, unread_count+1, max_seq | 新消息到达后更新 |
| `update_unread_count` | UPDATE unread_count = ? | 设置未读数（已读回执） |
| `update_after_sent_message` | UPDATE latest_msg, latest_msg_send_time | 发送消息后更新 |
| `get_total_unread_count` | SELECT SUM(unread_count) | 获取总未读数 |
| `update_max_seq` | UPDATE max_seq = ? | 更新会话最大 seq |
| `get_all_seq_pairs` | SELECT conversation_id, max_seq | 获取所有会话的 seq 对 |

### 8.3 local_sending_messages

```sql
CREATE TABLE local_sending_messages (
    conversation_id TEXT NOT NULL,
    client_msg_id   TEXT NOT NULL,
    ex              TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (conversation_id, client_msg_id)
);
```

用于追踪发送中的消息，登录时清理未完成的发送任务。

---

## 9. 测试用例

### 9.1 测试矩阵

| 测试用例 | 描述 | 已实现 | 文件 |
|----------|------|--------|------|
| `test_handle_messages` | 基本消息处理流程 | ✅ | handler.rs |
| `test_dedup_via_insert_ignore` | 消息去重（INSERT OR IGNORE） | ✅ | handler.rs |
| `test_tip_message_not_stored` | 通知消息不入库不计未读 | ✅ | handler.rs |
| `test_typing_message_not_stored_and_no_event` | Typing 消息不存储不发事件 | ✅ | handler.rs |
| `test_normal_message_increments_unread` | 普通消息增加未读数 | ✅ | handler.rs |
| `test_no_trigger_conv_stored_but_no_conv_update` | NoTriggerConv 消息不更新会话 | ✅ | handler.rs |
| `test_new_message_dedup` | 同一 clientMsgID 重复推送去重 | ❌ | - |
| `test_unread_count_increment` | 多条消息未读数正确累加 | ✅ | handler.rs |
| `test_self_sent_message` | 自己发的消息不增加未读数 | ✅ | handler.rs |
| `test_conversation_auto_create` | 新会话自动创建 | ✅ | handler.rs |
| `test_notification_dispatch_friend` | 好友通知正确路由 | ❌ | - |
| `test_notification_dispatch_group` | 群组通知正确路由 | ❌ | - |
| `test_read_receipt_handling` | 已读回执正确处理 | ❌ | - |
| `test_seq_range_protobuf` | protobuf 编解码正确性 | ✅ | syncer.rs |
| `test_pull_request_protobuf` | Pull 请求编解码正确性 | ✅ | syncer.rs |

### 9.2 缺失测试详细说明

#### test_new_message_dedup

```rust
// 测试场景：同一消息被推送两次
// 1. 第一次推送 msg_1 (clientMsgID="abc", seq=1) → 应入库
// 2. 第二次推送 msg_1 (clientMsgID="abc", seq=1) → 应被去重
// 3. 验证 DB 中只有一条记录
```

#### test_unread_count_increment（增强版）

```rust
// 测试场景：多条消息的未读数累加
// 1. 推送 msg_1 (seq=1, conv_1) → unread_count=1
// 2. 推送 msg_2 (seq=2, conv_1) → unread_count=2
// 3. 推送 msg_3 (seq=3, conv_1) → unread_count=3
// 4. 验证 MaxSeqRecorder 正确追踪 seq=3
```

#### test_notification_dispatch_friend

```rust
// 测试场景：好友申请通知
// 1. 构造 ContentType=1201 (FriendApplication) 的消息
// 2. 调用 doNotificationManager
// 3. 验证路由到 relation.DoNotification
// 4. 验证 FriendApplicationAdded 事件发布
```

#### test_notification_dispatch_group

```rust
// 测试场景：群成员变更通知
// 1. 构造 ContentType=1508 (MemberKicked) 的消息
// 2. 调用 doNotificationManager
// 3. 验证路由到 group.DoNotification
// 4. 验证 GroupMemberDeleted 事件发布
```

---

## 10. Rust 实现文件索引

| 文件 | 职责 |
|------|------|
| `rust/src/core/message/handler.rs` | 消息处理器核心（handle_messages、去重、入库、通知） |
| `rust/src/core/message/service.rs` | 消息服务（撤回、删除、标记已读、搜索） |
| `rust/src/core/message/syncer.rs` | 消息同步器（Pull 拉取、增量同步、重装同步） |
| `rust/src/core/message/types.rs` | 消息类型工具函数 |
| `rust/src/core/message/mod.rs` | 模块导出 |
| `rust/src/sdk/client/message.rs` | SDK 层消息 API（send_msg、get_history 等） |
| `rust/src/infra/database/message_dao.rs` | 消息 DAO 层（SQLite CRUD） |
| `rust/src/infra/database/conversation_dao.rs` | 会话 DAO 层 |
| `rust/src/infra/database/sending_message_dao.rs` | 发送中消息 DAO |
| `rust/src/domain/model/message.rs` | 消息数据模型（ReceivedMessage、MessageInfo） |
| `rust/src/domain/event/types.rs` | 事件定义（SdkEvent 枚举） |

---

## 11. 注意事项

### 11.1 RwLock 生命周期

```rust
// ✅ 正确：先获取结果再释放锁
let result = client.read().await.some_method().await;
drop(client_read); // 显式释放（如果需要）
// 后续操作

// ❌ 错误：guard 在 await 期间持有锁
client.read().await.some_async_method().await  // 编译错误
```

### 11.2 批量操作的事务性

当前 `batch_insert` 使用逐条 INSERT OR IGNORE，未来可考虑使用 SQLite 事务提升性能：

```rust
pub async fn batch_insert(&self, logs: &[LocalChatLog]) -> Result<()> {
    let mut tx = self.pool.begin().await?;
    for log in logs {
        sqlx::query("INSERT OR IGNORE INTO local_chat_logs ...")
            .bind(...)
            .execute(&mut *tx).await?;
    }
    tx.commit().await?;
    Ok(())
}
```

### 11.3 会话 Diff 与并发安全

Go SDK 使用 `conversationSyncMutex` 保护会话 diff 和批量操作。Rust 实现中应确保：

- `handle_messages` 中的会话创建/更新操作是原子的
- 多个并发消息批次不会导致未读数竞争
- 建议使用 `tokio::sync::Mutex` 保护会话级别的临界区
