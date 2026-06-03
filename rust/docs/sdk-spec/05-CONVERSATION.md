# 05 - 会话管理模块详细设计

> **参考实现**: `../openim-sdk-core/internal/conversation_msg/` (~3000 行，20 个文件)
> **协议定义**: `../protocol/conversation/`, `../protocol/msg/`
> **状态**: 本文档为 Rust SDK 重写参考规格

---

## 1. 模块职责

会话管理模块（`conversation_msg`）是 IM SDK 中**最复杂的模块**，负责：

| 职责 | 说明 |
|------|------|
| **会话 CRUD** | 获取列表、设置属性（置顶/免打扰/草稿）、删除、隐藏 |
| **会话同步** | 全量同步 + 基于 VersionSynchronizer 的增量同步 |
| **消息历史拉取** | 支持正序/反序，带 Gap 检测和自动填充 |
| **已读回执处理** | 单聊/群聊的已读状态同步 |
| **消息撤回处理** | 撤回消息并替换为 RevokeNotification |
| **消息删除处理** | 本地+服务端删除，支持批量和清空 |
| **正在输入状态** | Typing 状态的发送与接收（基于缓存 + 平台感知） |
| **消息搜索** | 按关键词/内容类型/时间范围搜索本地消息 |
| **消息发送** | 消息创建、文件上传、发送队列、状态更新 |
| **通知路由** | `Work()` 分发各种 Cmd 到对应处理器 |

---

## 2. Go SDK 对标分析

### 2.1 文件清单

```
internal/conversation_msg/
├── api.go                # 公开 API 方法（所有对外暴露的 SDK 接口）
├── conversation.go       # 核心结构体定义、构造函数、Syncer 初始化
├── conversation_msg.go   # 核心逻辑：消息处理(doMsgNew)、新消息通知、会话差异计算
├── conversion.go         # 数据模型转换（ServerConversation ↔ LocalChatLog）
├── create_message.go     # 消息创建与组装
├── delete.go             # 消息删除（本地/服务端/清空）
├── entering.go           # 正在输入状态管理（typing）
├── image.go              # 图片消息处理
├── incremental_sync.go   # 增量同步（IncrSyncConversations）
├── max_seq_recorder.go   # 内存中 MaxSeq 记录器
├── message_check.go      # 消息校验
├── notification.go       # 通知路由（Work）、同步标志处理、会话更新
├── progress.go           # 进度管理
├── read_drawing.go       # 已读回执处理
├── revoke.go             # 消息撤回处理
├── send_queue.go         # 消息发送队列
├── server_api.go         # 服务端 API 调用封装
└── sync.go               # SyncAllConversationHashReadSeqs
```

### 2.2 核心数据流

```
WebSocket Push → MsgSyncer
  → CmdNewMsgCome → Conversation.doMsgNew()
    → 解析消息 → 更新/插入 DB → 更新会话 LatestMsg → 触发 UI 回调

  → CmdNotification → Conversation.Work()
    → doNotificationManager()
      → 按 ContentType 分发到 relation/group/user/conversation

  → CmdSyncFlag → syncFlag()
    → MsgSyncBegin/End, AppDataSyncStart/Finish
```

---

## 3. Conversation 核心结构体

```go
type Conversation struct {
    *interaction.LongConnMgr                      // 长连接管理（继承）
    conversationSyncer          *syncer.Syncer     // 会话同步器（泛型：LocalConversation）
    db                          db_interface.DataBase // 数据库接口
    ConversationListener        func() OnConversationListener  // 会话事件监听器
    msgListener                 func() OnAdvancedMsgListener   // 消息事件监听器
    msgKvListener               func() OnMessageKvInfoListener // 消息 KV 监听器
    businessListener            func() OnCustomBusinessListener // 自定义业务监听器
    msgSyncerCh                 chan Cmd2Value     // 消息同步器命令通道
    conversationEventQueue      chan Cmd2Value     // 会话事件队列
    loginUserID                 string             // 当前登录用户 ID
    platform                    int32              // 当前平台 ID
    DataDir                     string             // 数据目录
    relation                    *relation.Relation // 好友关系模块引用
    group                       *group.Group       // 群组模块引用
    user                        *user.User         // 用户模块引用
    file                        *file.File         // 文件上传模块引用
    cache                       *Cache[string, *LocalConversation] // 会话缓存
    maxSeqRecorder              MaxSeqRecorder     // MaxSeq 内存记录器
    messagePullForwardEndSeqMap *ConversationSeqContextCache // 正序拉取结束 Seq 缓存
    messagePullReverseEndSeqMap *ConversationSeqContextCache // 反序拉取结束 Seq 缓存
    IsExternalExtensions        bool               // 外部扩展模式
    msgOffset                   int                // 重装同步偏移量
    progress                    int                // 初始同步进度
    conversationSyncMutex       sync.Mutex         // 会话同步互斥锁
    seqs                        map[string]*msg.Seqs // Seq 映射
    startTime                   time.Time          // 同步开始时间
    typing                      *typing            // 正在输入状态管理
    sender                      *messageSender     // 消息发送器（惰性初始化）
    senderOnce                  sync.Once          // 发送器单次初始化
}
```

### 3.1 关键依赖说明

| 字段 | 类型 | 用途 |
|------|------|------|
| `conversationSyncer` | `Syncer[*LocalConversation, *GetOwnerConversationResp, string]` | 泛型同步器，执行全量/增量同步 |
| `maxSeqRecorder` | `MaxSeqRecorder` | 内存中记录每个会话的最大 Seq，用于未读计数 |
| `messagePullForward/ReverseEndSeqMap` | `ConversationSeqContextCache` | 缓存每个会话正序/反序拉取的结束 Seq，避免重复拉取 |
| `conversationSyncMutex` | `sync.Mutex` | 保护会话同步的互斥锁，`doMsgNew` 和 `IncrSyncConversations` 都持有 |
| `typing` | `*typing` | 正在输入状态管理，使用 `go-cache` 做过期管理 |

---

## 4. 会话同步机制

### 4.1 Syncer 泛型同步器

Go SDK 使用 `syncer.Syncer` 泛型结构体执行全量同步：

```go
syncer.New2[*model_struct.LocalConversation, pbConversation.GetOwnerConversationResp, string](
    syncer.WithInsert(...)    // 新增回调 → batchAddFaceURLAndName + InsertConversation
    syncer.WithDelete(...)    // 删除回调 → DeleteConversation
    syncer.WithUpdate(...)    // 更新回调 → UpdateColumnsConversation（只更新指定列）
    syncer.WithUUID(...)      // 提取唯一键 → ConversationID
    syncer.WithEqual(...)     // 比较是否相等（13 个字段逐一比较）
    syncer.WithNotice(...)    // 通知回调 → 发送 ConChange 事件
    syncer.WithBatchInsert(...) // 批量插入回调
    syncer.WithDeleteAll(...) // 全部删除回调
    syncer.WithBatchPageReq(...)  // 分页请求（ShowNumber: 300）
    syncer.WithBatchPageRespConvertFunc(...) // 响应转换 → ServerConversationToLocal
    syncer.WithReqApiRouter(...)  // API 路由 → GetOwnerConversation
    syncer.WithFullSyncLimit(...) // 全量同步限制 → math.MaxInt64
)
```

### 4.2 VersionSynchronizer 增量同步

增量同步使用 `VersionSynchronizer[V, R]` 泛型结构体，关键字段：

| 泛型参数 | 实际类型 |
|----------|----------|
| `V` | `*model_struct.LocalConversation` |
| `R` | `*pbConversation.GetIncrementalConversationResp` |

核心流程（`IncrSyncConversations`）：

```
1. 从 DB 获取本地版本号 (LocalVersionSync)
2. 调用 getIncrementalConversationFromServer(version, versionID)
3. 如果 resp.Full == true → 执行 FullSyncer
4. 否则处理 delete/update/insert:
   - delete: 从 UIDList 中移除
   - update/insert: 合并到 server map
   - 从 DB 获取本地数据，合并 server 数据
   - 调用 Syncer(server, local) 执行差异同步
5. 更新版本号
```

### 4.3 增量同步详细流程

```rust
// Rust 伪代码 — IncrSyncConversations
async fn incr_sync_conversations(&self) -> Result<()> {
    let (version, version_id) = self.get_local_version().await?;
    let resp = self.get_incremental_from_server(version, &version_id).await?;

    if resp.full {
        return self.full_sync().await;
    }

    // 从 UIDList 中删除
    for id in &resp.delete {
        self.db.delete_conversation(id).await?;
    }

    // 合并 insert 和 update
    let mut server_map = HashMap::new();
    for s in resp.update.iter().chain(resp.insert.iter()) {
        let domain = server_to_domain(s.clone());
        server_map.insert(domain.conversation_id.clone(), domain);
    }

    // 获取本地所有会话
    let local = self.db.get_all_conversations().await?;
    // 执行 Syncer 差异同步（insert/update/delete DB 操作）
    self.syncer.sync(server, local).await?;

    // 更新版本号
    self.update_version(resp.version, resp.version_id).await?;
}
```

### 4.4 IDOrderChanged 机制

当 `resp.SortVersion > 0` 时（Go SDK 中暂未在 Conversation 模块使用，但框架支持），表示排序 ID 发生了变化（如群角色变更、好友列表重排），需要刷新 FullID 列表。

---

## 5. 消息历史拉取

### 5.1 getAdvancedHistoryMessageList

支持正序（`isReverse=false`，从旧到新）和反序（`isReverse=true`，从新到旧）拉取：

```
输入参数: GetAdvancedHistoryMessageListParams {
    conversation_id: String,
    start_client_msg_id: String,  // 可选，分页起始消息
    count: i32,                    // 每页数量
    view_type: i32,               // 视图类型（聊天/搜索）
}

流程:
1. 如果 StartClientMsgID 不为空:
   - 从 DB 获取该消息的 SendTime、Seq
   - 调用 handleEndSeq 设置正序/反序结束 Seq
2. 调用 fetchMessagesWithGapCheck 获取消息
3. 转换 LocalChatLog → MsgStruct
4. 过滤阅后即焚已过期消息
5. 排序后返回
```

### 5.2 fetchMessagesWithGapCheck Gap 检测

这是消息拉取中最复杂的部分：

```
1. 从 DB 拉取 count 条消息 (GetMessageList)
2. validateAndFillInternalGaps  — 检测并填充内部间隙
3. validateAndFillInterBlockGaps — 检测并填充块间间隙
4. validateAndFillEndBlockContinuity — 检测末尾连续性
5. shouldFetchMoreMessagesNum — 计算还需多少有效消息
6. 如果有效消息不足且未到末尾 → 递归拉取更多消息
```

**Gap 检测关键逻辑**:
- `shouldFetchMoreMessagesNum`: 统计有效消息数量（过滤 `Status >= MsgStatusHasDeleted`），更新正序/反序的 EndSeq 缓存
- 正序拉取：EndSeq 只能减小（向前推进）
- 反序拉取：EndSeq 只能增大（向后推进）
- 递归调用：如果有效消息不足，使用最后一条消息的 SendTime/Seq/ClientMsgID 继续拉取

### 5.3 EndSeq 缓存机制

```
messagePullForwardEndSeqMap: HashMap<(conversationID, viewType), i64>
messagePullReverseEndSeqMap: HashMap<(conversationID, viewType), i64>

- 首次进入会话时清空两个 Map
- 每次拉取后更新 EndSeq（带条件检查）
- 正序: newSeq < lastEndSeq 时才更新
- 反序: newSeq > lastEndSeq 时才更新
```

---

## 6. 已读回执处理

### 6.1 doReadDrawing（接收服务端推送）

```rust
// 当收到 ContentType == HasReadReceipt (2200) 时触发
async fn do_read_drawing(&self, msg: &MsgData) -> Result<()> {
    let tips: MarkAsReadTips = deserialize(msg.content)?;

    // 如果不是自己标记的已读
    if tips.mark_as_read_user_id != self.login_user_id {
        let messages = self.db.get_messages_by_seqs(&tips.conversation_id, &tips.seqs).await?;

        if conversation.conversation_type == SingleChatType {
            // 单聊：逐条更新已读状态
            for msg in messages {
                let mut attach = deserialize(msg.attached_info)?;
                attach.has_read_time = msg.send_time;
                msg.attached_info = serialize(attach);
                msg.is_read = true;
                self.db.update_message(&tips.conversation_id, &msg).await?;

                // 如果是最新消息，更新会话 LatestMsg
                if latest_msg.client_msg_id == msg.client_msg_id {
                    latest_msg.is_read = true;
                    self.db.update_conversation_latest_msg(conversation).await?;
                }
            }

            // 触发 OnRecvC2CReadReceipt 回调
            self.msg_listener.on_recv_c2c_read_receipt(message_receipt);
        } else {
            // 群聊/通知：调用 doUnreadCount
            self.do_unread_count(&conversation, tips.has_read_seq, tips.seqs).await?;
        }
    }
}
```

### 6.2 doUnreadCount（未读计数更新）

```
单聊:
  1. 通过 Seq 列表标记消息为已读 (MarkConversationMessageAsReadBySeqs)
  2. 计算新未读数: currentMaxSeq - hasReadSeq
  3. 更新会话 unread_count
  4. 如果最新消息的 Seq 在已读列表中 → UpdateLatestMessageReadState

群聊/通知:
  1. 直接设置 unread_count = 0

始终:
  → ConChange 事件
  → TotalUnreadMessageChanged 事件
```

### 6.3 markConversationMessageAsRead（主动标记已读）

```
1. 获取会话信息，检查 UnreadCount
2. 获取对方最大正常消息 Seq
3. 单聊:
   - 获取未读消息列表
   - 过滤出需要标记已读的消息（!isRead && sendID != loginUserID）
   - 调用服务端 markConversationAsReadServer
   - 更新 DB 标记
4. 群聊/通知:
   - 直接调用 markConversationAsReadServer
5. 设置 unread_count = 0
6. 触发 unreadChangeTrigger
```

---

## 7. 消息撤回处理

### 7.1 doRevokeMsg（接收服务端推送）

```rust
async fn do_revoke_msg(&self, msg: &MsgData) -> Result<()> {
    let tips: RevokeMsgTips = deserialize(msg.content)?;
    self.revoke_message(&tips).await
}

async fn revoke_message(&self, tips: &RevokeMsgTips) -> Result<()> {
    // 1. 获取被撤回的消息
    let revoked_msg = self.db.get_message_by_seq(&tips.conversation_id, tips.seq).await?;

    // 2. 获取撤回者信息
    let (revoker_role, revoker_nickname) = if tips.is_admin_revoke || tips.session_type == SingleChatType {
        // 单聊/管理员：获取用户名
        self.get_user_name_and_face_url(&tips.revoker_user_id).await?
    } else {
        // 群聊：获取群成员信息（含角色）
        let members = self.group.get_specified_group_members_info(&group_id, &[tips.revoker_user_id]).await?;
        (members[0].role_level, members[0].nickname)
    };

    // 3. 构建 MessageRevoked 结构
    let revoked = MessageRevoked {
        revoker_id: tips.revoker_user_id,
        revoker_role,
        client_msg_id: revoked_msg.client_msg_id,
        revoker_nickname,
        revoke_time: tips.revoke_time,
        source_message_send_time: revoked_msg.send_time,
        source_message_send_id: revoked_msg.send_id,
        source_message_sender_nickname: revoked_msg.sender_nickname,
        session_type: tips.session_type,
        seq: tips.seq,
        is_admin_revoke: tips.is_admin_revoke,
    };

    // 4. 更新 DB：替换消息内容为 RevokeNotification
    let notification = NotificationElem { detail: serialize(revoked) };
    self.db.update_message_by_seq(&tips.conversation_id, LocalChatLog {
        seq: tips.seq,
        content: serialize(notification),
        content_type: RevokeNotification,
    }).await?;

    // 5. 如果撤回的是最新消息 → 刷新会话 LatestMsg
    if latest_msg.seq <= tips.seq {
        let new_latest = self.db.get_message_list(&tips.conversation_id, 1, 0, 0, "", false).await?;
        self.db.update_columns_conversation(&tips.conversation_id, /* latest_msg 字段 */).await?;
    }

    // 6. 触发 OnNewRecvMessageRevoked 回调
    self.msg_listener.on_new_recv_message_revoked(serialize(revoked));

    // 7. 搜索所有引用该消息的 Quote 消息并更新
    let quote_msgs = self.db.search_all_message_by_content_type(&conversation_id, Quote).await?;
    for v in quote_msgs {
        self.quote_msg_revoke_handle(&conversation_id, &v, &revoked).await?;
    }
}
```

### 7.2 revokeOneMessage（主动撤回）

```
1. 获取消息，等待 Seq 同步（最多重试 5 次，每次间隔 2 秒）
2. 检查消息状态：只有 MsgStatusSendSuccess 才能撤回
3. 权限检查:
   - 单聊：只有发送者自己可以撤回
   - 群聊：发送者自己或群管理员可以撤回
4. 调用服务端 revokeMessageFromServer
5. 调用 revokeMessage 执行本地处理
```

### 7.3 quoteMsgRevokeHandle（引用消息更新）

```
当引用的消息被撤回时:
1. 解析引用消息的 QuoteElem
2. 检查 QuoteMessage.ClientMsgID 是否匹配被撤回消息
3. 替换引用消息的 Content 和 ContentType 为 RevokeNotification
4. 更新 DB
```

---

## 8. 消息删除处理

### 8.1 deleteMessage（单条删除）

```
1. 从 DB 获取消息
2. 如果 Seq == 0 或 Status == SendFailed → 仅本地删除
3. 否则 → 先调用 deleteMessagesFromServer，再本地删除
```

### 8.2 deleteMessageFromLocal（本地删除）

```
1. 更新消息 status 为 MsgStatusHasDeleted（软删除）
2. 如果消息未读且非自己发送 → 减少未读计数
3. 如果删除的是最新消息 → 获取新的最新活跃消息
4. 触发 OnMsgDeleted 回调
```

### 8.3 doDeleteMsgs（服务端推送删除）

```
当收到 ContentType == DeleteMsgsNotification (2102):
1. 反序列化 DeleteMsgsTips 获取 Seq 列表
2. 遍历每个 Seq:
   - 通过 Seq 获取消息
   - 调用 deleteMessageFromLocal 执行本地删除
```

### 8.4 doClearConversations（清空会话推送）

```
当收到 ContentType == ClearConversationNotification (1703):
1. 反序列化 ClearConversationTips 获取 ConversationIDs
2. 遍历每个 ConversationID:
   - 调用 clearConversationAndDeleteAllMsg
     - 设置 hasReadSeq = maxSeq
     - 删除所有消息
     - 执行 ClearConversation 回调
3. 触发 ConChange 和 TotalUnreadMessageChanged
```

### 8.5 clearConversationFromLocalAndServer（主动清空）

```
1. 验证会话存在
2. 调用 clearConversationMsgFromServer（先清服务端）
3. 调用 clearConversationAndDeleteAllMsg（清本地）
4. 触发事件
```

---

## 9. MaxSeqRecorder（最大 Seq 记录器）

### 9.1 数据结构

```go
type MaxSeqRecorder struct {
    seqs map[string]int64  // conversationID → maxSeq
    lock sync.RWMutex
}
```

### 9.2 核心方法

| 方法 | 签名 | 说明 |
|------|------|------|
| `Get` | `(conversationID) → int64` | 获取会话当前最大 Seq |
| `Set` | `(conversationID, seq)` | 设置会话最大 Seq |
| `Incr` | `(conversationID, num)` | 增加指定数量 |
| `IsNewMsg` | `(conversationID, seq) → bool` | 判断是否为新消息（seq > currentSeq） |

### 9.3 使用场景

- **doMsgNew**: 收到新消息时，通过 `IsNewMsg` 判断是否需要增加未读计数
- **Incr**: 新消息确认后增加 MaxSeq
- **doUnreadCount**: 通过 `Get` 获取当前 MaxSeq 计算未读数
- **SyncAllConversationHashReadSeqs**: 从服务端同步后通过 `Set` 更新

### 9.4 Rust 实现要点

```rust
use std::collections::HashMap;
use tokio::sync::RwLock;

pub struct MaxSeqRecorder {
    seqs: RwLock<HashMap<String, i64>>,
}

impl MaxSeqRecorder {
    pub fn new() -> Self { ... }
    pub async fn get(&self, conversation_id: &str) -> i64 { ... }
    pub async fn set(&self, conversation_id: &str, seq: i64) { ... }
    pub async fn incr(&self, conversation_id: &str, num: i64) { ... }
    pub async fn is_new_msg(&self, conversation_id: &str, seq: i64) -> bool { ... }
}
```

---

## 10. 正在输入状态（Typing）

### 10.1 数据结构

```go
type typing struct {
    send  *cache.Cache  // 发送状态缓存（10s 过期）
    state *cache.Cache  // 接收状态缓存（15s 过期）
    conv  *Conversation

    platformIDs   []int32        // 支持的平台 ID 列表
    platformIDSet map[int32]struct{} // 平台 ID 集合
}
```

### 10.2 核心流程

**发送 Typing 状态** (`ChangeInputStates`):
```
1. 获取会话信息
2. 检查 send 缓存:
   - focus=true 且已是 stateCodeSuccess → 跳过
   - focus=false 且已是 stateCodeEnd → 跳过
3. 设置/更新缓存
4. 发送 Typing 消息到服务端:
   - ContentType = Typing (113)
   - Options: 不存历史/不持久化/不同步发送者/不更新会话/不更新发送者会话/不计未读/不推送
5. 发送失败时删除缓存
```

**接收 Typing 状态** (`onNewMsg`):
```
1. 忽略自己发送的
2. 验证平台 ID 有效性
3. 如果 MsgTips == "yes":
   - 计算过期时间 (当前时间 + 10s)
   - 更新 state 缓存
   - 如果是新状态 → 触发 changes 回调
4. 如果 MsgTips == "no":
   - 删除 state 缓存
```

### 10.3 超时管理

| 常量 | 值 | 说明 |
|------|-----|------|
| `inputStatesSendTime` | 10s | 发送间隔 |
| `inputStatesTimeout` | 15s | 状态过期时间 |
| `inputStatesMsgTimeout` | 5s | 发送超时时间 |

state 缓存的 `OnEvicted` 回调在条目过期时触发 `changes`，通知 UI 某用户停止输入。

---

## 11. 消息搜索

### 11.1 searchLocalMessages

```
参数: SearchLocalMessagesParams {
    conversation_id: String,       // 可选，指定会话
    keyword_list: Vec<String>,     // 关键词列表
    keyword_list_match_type: int,  // 0=OR, 1=AND
    message_type_list: Vec<int>,   // 内容类型列表
    sender_user_id_list: Vec<String>, // 发送者列表
    search_time_position: i64,     // 搜索截止时间
    search_time_period: i64,       // 时间范围
    page_index: int,               // 页码
    count: int,                    // 每页数量
}
```

### 11.2 搜索流程

```
1. 清空搜索视图的 EndSeq 缓存
2. 计算时间范围（startTime/endTime）
3. 如果指定了 ConversationID:
   - 按内容类型搜索 (SearchMessageByContentType) 或
   - 按关键词搜索 (SearchMessageByKeyword)
4. 如果未指定 ConversationID:
   - 获取所有会话 ID
   - 并发搜索每个会话（goroutine 限制 10 个）
5. 对结果进行过滤 (filterMsg)
6. 按会话分组，统计消息数量
7. 按最新消息时间排序
```

### 11.3 消息过滤 (filterMsg)

根据 ContentType 匹配关键词：

| ContentType | 过滤逻辑 |
|-------------|----------|
| Text | 匹配 TextElem.Content |
| AtText | 匹配 AtTextElem.Text |
| File | 匹配 FileElem.FileName |
| Merger | 匹配 MergeElem.Title，递归匹配子消息 |
| Card | 匹配 CardElem.Nickname |
| Location | 匹配 LocationElem.Description |
| Custom | 匹配 CustomElem.Description |
| Quote | 匹配 QuoteElem.Text，递归匹配引用消息 |
| Picture/Sound/Video | 关键词列表为空则通过，否则过滤 |

---

## 12. 涉及的数据库表

### 12.1 local_conversations

```sql
CREATE TABLE local_conversations (
    conversation_id    TEXT PRIMARY KEY,
    conversation_type  INTEGER NOT NULL,
    user_id            TEXT,
    group_id           TEXT,
    show_name          TEXT,
    face_url           TEXT,
    recv_msg_opt       INTEGER DEFAULT 0,
    unread_count       INTEGER DEFAULT 0,
    group_at_type      INTEGER DEFAULT 0,
    latest_msg         TEXT,
    latest_msg_send_time INTEGER DEFAULT 0,
    draft_text         TEXT,
    draft_text_time    INTEGER DEFAULT 0,
    is_pinned          INTEGER DEFAULT 0,
    is_private_chat    INTEGER DEFAULT 0,
    burn_duration      INTEGER DEFAULT 0,
    is_not_in_group    INTEGER DEFAULT 0,
    update_unread_count_time INTEGER DEFAULT 0,
    attached_info      TEXT,
    ex                 TEXT,
    max_seq            INTEGER DEFAULT 0,
    min_seq            INTEGER DEFAULT 0,
    is_msg_destruct    INTEGER DEFAULT 0,
    msg_destruct_time  INTEGER DEFAULT 0
);
```

**主要操作**:
- `InsertConversation` — 新增会话
- `UpdateConversation` — 更新会话
- `UpdateColumnsConversation` — 更新指定列
- `BatchInsertConversationList` — 批量插入
- `BatchUpdateConversationList` — 批量更新
- `DeleteConversation` — 删除会话
- `DeleteAllConversation` — 删除所有会话
- `GetConversation` — 获取单个会话
- `GetMultipleConversationDB` — 获取多个会话
- `GetAllConversations` — 获取所有会话
- `GetConversationListSplitDB` — 分页获取
- `SetConversationDraftDB` — 设置草稿
- `RemoveConversationDraft` — 移除草稿
- `ResetConversation` — 重置会话
- `ClearConversation` — 清空会话
- `UpdateMaxSeq` — 更新最大 Seq
- `SetPinned` — 设置置顶

### 12.2 local_chat_logs

```sql
-- 每个会话对应一个独立的表
-- 表名格式: chat_logs_{conversationID}
```

**主要操作**:
- `InsertMessage` — 插入消息
- `BatchInsertMessageList` — 批量插入
- `UpdateMessage` — 更新消息
- `UpdateMessageBySeq` — 按 Seq 更新
- `UpdateColumnsMessage` — 更新指定列
- `UpdateMessageTimeAndStatus` — 更新时间和状态
- `GetMessage` — 获取消息（by ClientMsgID）
- `GetMessageBySeq` — 获取消息（by Seq）
- `GetMessageList` — 获取消息列表
- `GetMessagesBySeqs` — 按 Seq 列表获取
- `GetMessagesByClientMsgIDs` — 按 ClientMsgID 获取
- `GetUnreadMessage` — 获取未读消息
- `GetLatestValidServerMessage` — 获取最新有效服务端消息
- `GetLatestActiveMessage` — 获取最新活跃消息
- `MarkConversationMessageAsReadDB` — 标记已读
- `MarkConversationMessageAsReadBySeqs` — 按 Seq 标记已读
- `MarkDeleteConversationAllMessages` — 标记删除所有消息
- `DeleteConversationAllMessages` — 删除所有消息
- `SearchMessageByKeyword` — 按关键词搜索
- `SearchMessageByContentType` — 按类型搜索
- `SearchAllMessageByContentType` — 搜索所有该类型消息

### 12.3 local_notification_seqs

```sql
CREATE TABLE local_notification_seqs (
    conversation_id TEXT PRIMARY KEY,
    seq             INTEGER DEFAULT 0
);
```

**主要操作**:
- `SetNotificationSeq` — 设置通知 Seq
- `GetNotificationSeq` — 获取通知 Seq

---

## 13. Rust 当前实现对比

### 13.1 已实现

| 功能 | Go SDK | Rust 当前状态 | 完成度 |
|------|--------|--------------|--------|
| Conversation 模型 | ✅ | ✅ `domain/model/conversation.rs` | 100% |
| ConversationDao | ✅ | ✅ `infra/database/conversation_dao.rs` | 90% |
| ConversationManager | ✅ | ✅ `core/conversation/manager.rs` | 基本 CRUD |
| ConversationSyncer | ✅ | ✅ `core/conversation/syncer.rs` | 全量+增量 |
| ServerConversation 转换 | ✅ | ✅ syncer.rs 中 | 100% |
| 增量同步 (IncrSyncConversations) | ✅ | ✅ `sync_incremental` | 基本实现 |

### 13.2 未实现/待完善

| 功能 | Go SDK | Rust 当前状态 | 优先级 |
|------|--------|--------------|--------|
| **消息历史拉取** | `getAdvancedHistoryMessageList` + Gap 检测 | ❌ 未实现 | **P0** |
| **已读回执** | `doReadDrawing` + `doUnreadCount` | ❌ 未实现 | **P0** |
| **消息撤回** | `doRevokeMsg` + `revokeOneMessage` | ❌ 未实现 | **P0** |
| **消息删除** | `deleteMessage` + `doDeleteMsgs` + `doClearConversations` | ❌ 未实现 | **P0** |
| **MaxSeqRecorder** | 内存 Map + RWMutex | ❌ 未实现 | **P0** |
| **消息处理 (doMsgNew)** | 新消息去重、会话更新、未读计数 | ❌ 未实现 | **P0** |
| **正在输入** | Typing 状态发送/接收/缓存 | ❌ 未实现 | **P1** |
| **消息搜索** | `searchLocalMessages` | ❌ 未实现 | **P1** |
| **通知路由** | `Work()` + `doNotificationManager()` | ❌ 未实现 | **P0** |
| **SyncFlag 处理** | `syncFlag()` 全量/增量同步标志 | ❌ 未实现 | **P0** |
| **SyncAllConversationHashReadSeqs** | 会话 Hash+ReadSeq 同步 | ❌ 未实现 | **P1** |
| **消息发送** | 完整发送流程（文件上传+队列） | ❌ 未实现 | **P1** |
| **ShowName/FaceURL 补全** | 从好友/用户/群组信息补全 | ❌ 未实现 | **P1** |

### 13.3 差距分析

1. **同步器不完善**: Rust 的 ConversationSyncer 缺少 `syncer.Syncer` 泛型框架中的 Equal 比较、Notice 回调等机制
2. **缺少消息处理层**: 没有 `doMsgNew` 对应的新消息处理流程
3. **缺少 Gap 检测**: 消息拉取没有正序/反序的 EndSeq 缓存和递归拉取机制
4. **缺少 MaxSeqRecorder**: 没有内存级别的 Seq 追踪
5. **缺少通知分发**: 没有 Work() 命令分发机制

---

## 14. 测试用例

### 14.1 会话同步测试

```rust
#[tokio::test]
async fn test_incr_sync_conversations_full() {
    // 1. Mock 服务端返回 full=true
    // 2. 验证执行全量同步
    // 3. 验证本地会话被完全替换
}

#[tokio::test]
async fn test_incr_sync_conversations_partial() {
    // 1. Mock 服务端返回 insert=2, update=1, delete=1
    // 2. 验证增量同步正确处理
    // 3. 验证版本号更新
}

#[tokio::test]
async fn test_version_sync_id_mismatch() {
    // 1. 本地 versionID 与服务端不匹配
    // 2. 验证触发全量同步
}
```

### 14.2 消息拉取测试

```rust
#[tokio::test]
async fn test_get_advanced_history_message_list_forward() {
    // 1. 插入 10 条消息到 DB
    // 2. 正序拉取 5 条
    // 3. 验证返回顺序和数量
}

#[tokio::test]
async fn test_gap_detection_and_fill() {
    // 1. 插入消息，中间有 gaps（Seq 不连续）
    // 2. 验证 Gap 检测正确识别
    // 3. 验证自动填充（从服务端拉取）
}

#[tokio::test]
async fn test_reverse_pagination() {
    // 1. 插入 100 条消息
    // 2. 反序拉取第 50 条之后的消息
    // 3. 验证反序 EndSeq 缓存
}
```

### 14.3 已读回执测试

```rust
#[tokio::test]
async fn test_do_read_drawing_single_chat() {
    // 1. 插入未读消息
    // 2. 模拟接收 HasReadReceipt
    // 3. 验证消息标记为已读
    // 4. 验证 AttachedInfoElem.HasReadTime 更新
}

#[tokio::test]
async fn test_do_unread_count_group() {
    // 1. 设置会话 unread_count = 10
    // 2. 模拟群聊已读回执
    // 3. 验证 unread_count 更新
}
```

### 14.4 消息撤回测试

```rust
#[tokio::test]
async fn test_revoke_message_updates_content() {
    // 1. 插入一条正常消息
    // 2. 模拟撤回推送
    // 3. 验证消息内容替换为 RevokeNotification
    // 4. 验证 ContentType 变为 RevokeNotification
}

#[tokio::test]
async fn test_revoke_updates_conversation_latest_msg() {
    // 1. 插入消息作为会话最新消息
    // 2. 撤回该消息
    // 3. 验证会话 LatestMsg 更新为前一条消息
}

#[tokio::test]
async fn test_quote_msg_revoke_handle() {
    // 1. 插入一条消息 A
    // 2. 插入引用 A 的消息 B
    // 3. 撤回消息 A
    // 4. 验证消息 B 的引用内容更新为 RevokeNotification
}
```

### 14.5 MaxSeqRecorder 测试

```rust
#[tokio::test]
async fn test_max_seq_recorder() {
    let recorder = MaxSeqRecorder::new();

    assert_eq!(recorder.get("conv1").await, 0);
    assert!(recorder.is_new_msg("conv1", 1).await);

    recorder.set("conv1", 10).await;
    assert!(!recorder.is_new_msg("conv1", 5).await);
    assert!(recorder.is_new_msg("conv1", 11).await);

    recorder.incr("conv1", 5).await;
    assert_eq!(recorder.get("conv1").await, 15);
}
```

### 14.6 消息删除测试

```rust
#[tokio::test]
async fn test_delete_message_from_local() {
    // 1. 插入未读消息
    // 2. 调用 deleteMessageFromLocal
    // 3. 验证状态更新为 HasDeleted
    // 4. 验证未读计数减少
}

#[tokio::test]
async fn test_delete_latest_message_updates_conversation() {
    // 1. 插入消息作为最新消息
    // 2. 删除该消息
    // 3. 验证会话 LatestMsg 更新
}

#[tokio::test]
async fn test_do_delete_msgs_from_push() {
    // 1. 插入多条消息
    // 2. 模拟 DeleteMsgsNotification 推送
    // 3. 验证所有指定消息被删除
}
```

### 14.7 正在输入测试

```rust
#[tokio::test]
async fn test_typing_state_expiry() {
    // 1. 设置 focus=true 发送 typing 消息
    // 2. 等待 10s
    // 3. 验证 state 缓存过期
    // 4. 验证 OnConversationUserInputStatusChanged 回调
}
```
