# Go SDK vs Rust SDK 差异文档

> 对比版本：openim-sdk-core v3.x（Go） vs flutter_rust_demo 当前实现（Rust）

---

## 模块 1：消息发送

### 1.1 API 设计模式

| 维度 | Go SDK | Rust SDK |
|------|--------|----------|
| 模式 | 两步走：`CreateXxxMessage` + `SendMessage` | 一步走：`send_message(SendMessageReq)` |
| 消息构建 | 每种消息类型有独立的 `CreateXxxMessage` 方法 | 统一 `send_message`，`content_type` + `content`(JSON) 区分 |
| clientMsgID | SDK 内部自动生成（UUID） | 用户传入 `Option<String>`，默认时间戳 |
| 返回类型 | `(*MsgStruct, error)` | `Result<MsgData, SdkError>` |

### 1.2 Go 创建消息 → 发送

```go
// 步骤 1：创建消息（SDK 自动生成 clientMsgID、填充 sendID/sendTime 等）
msg, err := sdk.CreateTextMessage(ctx, "Hello World")
// msg.ClientMsgID = utils.GetMsgID(loginUserID)  ← UUID

// 步骤 2：发送消息
sent, err := sdk.SendMessage(ctx, msg, recvID, groupID)
```

### 1.3 Rust 发送消息

```rust
// 一步发送（用户自己构造 content 的 JSON + 可选传入 clientMsgID）
let req = SendMessageReq {
    recv_id: "user2".into(),
    group_id: "".into(),
    session_type: SessionType::SingleChat,
    content_type: ContentType::Text,
    content: r#"{"content":"Hello World"}"#.into(),
    client_msg_id: Some("uuid".into()),  // 可选，不传则 SDK 用时间戳
};
let msg = sdk.send_message(req).await?;
```

### 1.4 消息内容表示

**Go SDK**：结构化的 Elem 对象
```go
type MsgStruct struct {
    ContentType int32        // 101 = 文本
    TextElem    *TextElem    // 结构化文本
    PictureElem *PictureElem // 结构化图片
    // ... 每种消息类型有独立 struct
}
// TextElem = { Content: "Hello" }
```

**Rust SDK**：统一 JSON 字符串
```rust
pub struct MessageInfo {
    pub content_type: i32,  // 101 = 文本
    pub content: String,    // 统一 JSON 字符串
}
// content = r#"{"content":"Hello"}"#
```

### 1.5 消息类型覆盖

| 消息类型 | Go SDK | Rust SDK |
|---------|--------|----------|
| 文本 (`Text`) | ✅ `TextElem` | ✅ JSON |
| 图片 (`Picture`) | ✅ `PictureElem` | ❌ 无独立结构 |
| 语音 (`Sound`) | ✅ `SoundElem` | ❌ 无独立结构 |
| 视频 (`Video`) | ✅ `VideoElem` | ❌ 无独立结构 |
| 文件 (`File`) | ✅ `FileElem` | ❌ 无独立结构 |
| @消息 (`AtText`) | ✅ `AtTextElem` | ❌ 无独立结构 |
| 引用 (`Quote`) | ✅ `QuoteElem` | ❌ 无独立结构 |
| 合并转发 (`Merge`) | ✅ `MergeElem` | ❌ 无独立结构 |
| 名片 (`Card`) | ✅ `CardElem` | ❌ 无独立结构 |
| 位置 (`Location`) | ✅ `LocationElem` | ❌ 无独立结构 |
| 表情 (`Face`) | ✅ `FaceElem` | ❌ 无独立结构 |
| 自定义 (`Custom`) | ✅ `CustomElem` | ❌ 无独立结构 |
| 富文本 (`AdvancedText`) | ✅ `AdvancedTextElem` | ❌ 无独立结构 |
| **Markdown** | ✅ `MarkdownTextElem` | ❌ **缺失** |
| 通知 (`Notification`) | ✅ `NotificationElem` | ❌ 无独立结构 |

### 1.6 发送状态

| 维度 | Go SDK | Rust SDK |
|------|--------|----------|
| 初始化状态 | `constant.MsgStatusSending(1)` | 未显式设置 |
| 状态字段 | `MsgStruct.Status` | `MessageInfo.status`（已映射） |
| 事件 | `OnMsgProgress` / `OnNewMessage` | `MessageSent` / `MessageSendFailed` |

---

## 模块 2：消息接收与事件

### 2.1 消息去重

| 维度 | Go SDK | Rust SDK |
|------|--------|----------|
| 去重字段 | `ClientMsgID`（数据库主键） | `client_msg_id`（数据库主键） ✅ |
| 发送者去重 | 自己发的消息不触发 `OnNewMessage` | 自己发的消息不触发 `NewMessage` ✅ |
| 异常处理 | `handleExceptionMessages` — 处理 seq gap、重复、删除 | ❌ **缺失** |

### 2.2 事件类型

| 事件 | Go SDK | Rust SDK |
|------|--------|----------|
| 新消息 | `OnNewMessage(MsgStruct[])` | `NewMessage { message: MessageInfo }` |
| 发送成功 | `OnMsgProgress(clientMsgID, sendStatus)` | `MessageSent { client_msg_id, status }` |
| 发送失败 | `OnMsgProgress(clientMsgID, sendStatus)` | `MessageSendFailed { client_msg_id, err_code }` |
| 已读通知 | `OnConversationChanged(Conversation[])` | `ConversationChanged { conversations }` |
| 总未读 | `OnTotalUnreadMsgCountChanged(int)` | `TotalUnreadCountChanged { count }` |
| 同步完成 | `OnSyncServerStart` / `OnSyncServerFinish` | `SyncFinished` |
| 键盘输入 | `OnRecvNewMessages(TypingMsg)` | ❌ **缺失** |

---

## 模块 3：消息同步

### 3.1 同步机制

| 机制 | Go SDK | Rust SDK |
|------|--------|----------|
| 首次登录全量同步 | `sync_on_login` → `pullMessageIntoTable` | `sync_full` → `sync_on_login` |
| 重装模式 | `doMsgSyncByReinstalled` — 拉取全部 seq | `sync_all_messages_reinstall` |
| 增量同步 | `sync_after_reconnect` — 对比本地 maxSeq | `sync_incremental_messages` |
| seq gap 检测 | `push_trigger_and_sync` — 发现 gap 自动补拉 | ❌ **缺失** |
| 批量拉取 | `pullMessageBySeqs` — 按 seq 范围拉取 | `batch_pull_messages` |
| 同步完成事件 | `OnSyncServerFinish` | `SyncFinished` ✅ |

### 3.2 首屏启动初始化流程

**Go SDK 初始化顺序**：
```
login → syncAllConversations → SyncServerStart → 
  sync_on_login (reinstalled=true → 全量拉取 / reinstalled=false → 增量) →
    pullMessageIntoTable → 去重插入数据库 →
SyncServerFinish
```

**Rust SDK 初始化顺序**：
```
login → sync_full → sync_on_login → 
  max_seqs 对比 → 拉取消息 → SyncFinished
```

### 3.3 mark_conversation_as_read 的联动

**Go SDK**：
```
markConversationMessageAsRead
  → DB update: unread_count = 0
  → doUpdateConversation(ConChange)   → 推送 ConversationChanged
  → doUpdateConversation(TotalUnreadMessageChanged) → 推送总未读变更
```

**Rust SDK**：
```
mark_conversation_as_read
  → DB update: unread_count = 0, is_read = 1 ✅
  → event_bus.publish(ConversationChanged) ✅
  → event_bus.publish(TotalUnreadCountChanged) ✅
```

---

## 模块 4：历史消息

### 4.1 API 对比

| 维度 | Go SDK | Rust SDK |
|------|--------|----------|
| 函数 | `GetAdvancedHistoryMessageList(params)` | `get_history_messages(GetHistoryMessagesReq)` |
| 参数 | `{ StartClientMsgID, Count, ConversationID, LastMinSeq }` | `{ conversation_id, start_client_msg_id, count }` |
| 返回 | `{ IsEnd, Messages, NotificationSeq }` | `{ messages, is_end }` |
| 分页锚点 | `StartClientMsgID` → 查 sendTime | `start_client_msg_id` → 查 send_time ✅ |
| SQL 查询 | `WHERE send_time < startTime ORDER BY send_time DESC LIMIT count` | ✅ 同 |
| hasMore | `len < count → isEnd = true` | ✅ 同 |
| LastMinSeq | 服务端同步用 | ❌ **缺失** |

### 4.2 数据库查询

**Go SDK**：
```sql
SELECT * FROM local_chat_logs 
WHERE conversation_id = ? AND (send_time < ? OR ? = 0) 
ORDER BY send_time DESC LIMIT ?
```

**Rust SDK**：✅ 已对齐

---

## 模块 5：数据库模型

### 5.1 LocalChatLog 字段

| 字段 | Go SDK | Rust SDK |
|------|--------|----------|
| `client_msg_id` | ✅ 主键 | ✅ 主键 |
| `server_msg_id` | ✅ | ✅ |
| `send_time` | ✅ | ✅ |
| `create_time` | ✅ | ✅ |
| `session_type` | ✅ | ✅ |
| `send_id` | ✅ | ✅ |
| `recv_id` | ✅ | ✅ |
| `sender_nick_name` | ✅ | ✅ |
| `sender_face_url` | ✅ | ✅ |
| `group_id` | ✅ | ✅ |
| `content_type` | ✅ | ✅ |
| `content` | ✅ | ✅ |
| `seq` | ✅ | ✅ |
| `status` | ✅ | ✅ |
| `is_read` | ✅ | ✅ |
| `attached_info` | ✅ | ✅ |
| `ex` | ✅ | ✅ |
| `local_ex` | ✅ | ❌ **缺失** |
| `msg_from` | ✅ | ✅ |
| `sender_platform_id` | ✅ | ✅ |

### 5.2 索引

**Go SDK**：`conversation_id` + `send_time` 有联合索引

**Rust SDK**：需确认

---

## 模块 6：消息撤回

| 维度 | Go SDK | Rust SDK |
|------|--------|----------|
| 撤回函数 | `RevokeMessage(ctx, conversationID, clientMsgID)` | `revoke_message(RevokeMessageReq{seq, clientMsgId})` |
| 撤回通知 | `OnRecvNewMessages(revokeMsg)` + `ConversationChanged` | ❌ **缺失**（撤回后事件未推送） |
| 数据库更新 | `status = MsgStatusHasDeleted(4)` | ✅ `status = 4` |

---

## 模块 7：缺失功能汇总

| # | 功能 | Go SDK | Rust SDK | 重要性 |
|---|------|--------|----------|--------|
| 1 | Markdown 消息 | `MarkdownTextElem` | ❌ 缺失 | 高 |
| 2 | 消息撤回通知事件 | `OnRecvNewMessages` 推送撤回消息 | ❌ 缺失 | 高 |
| 3 | seq gap 检测补拉 | `push_trigger_and_sync` | ❌ 缺失 | 高 |
| 4 | 各消息类型独立 Elem 结构 | 14 种结构化类型 | ❌ 统一 JSON 字符串 | 中 |
| 5 | OfflinePush | `OfflinePushInfo` | ❌ 缺失 | 中 |
| 6 | LocalEx | `local_ex` 字段 | ❌ 缺失 | 中 |
| 7 | LastMinSeq（同步用） | `GetAdvancedHistoryMessageListParams` | ❌ 缺失 | 中 |
| 8 | 键盘输入事件（typing） | `TypingElem` / `OnRecvNewMessages` | ❌ 缺失 | 低 |
| 9 | 异常消息处理 | `handleExceptionMessages` | ❌ 缺失 | 低 |
