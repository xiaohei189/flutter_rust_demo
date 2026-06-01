# Rust SDK → Go SDK 对齐计划

> 目标：Rust SDK 在 API 设计、功能覆盖、行为逻辑上与 Go SDK 对齐

---

## 阶段划分

```
阶段一：API 对齐（高优先级，不影响现有功能）
├── 消息创建 + 发送两步走
├── 消息结构化 Elem
└── clientMsgID 自动生成

阶段二：事件对齐（高优先级，影响消息撤回等）
├── 撤回通知事件
├── 消息异常处理
└── seq gap 检测补拉

阶段三：字段补齐（中优先级）
├── LocalEx
├── OfflinePush
├── LastMinSeq
└── Markdown 消息

阶段四：功能补齐（中低优先级）
├── typing 事件
├── 多媒体消息独立结构
└── 全面测试覆盖
```

---

## 阶段一：API 对齐（预计 3-4 天）

### 1.1 消息创建 + 发送两步走

**当前 Rust**：
```rust
send_message(SendMessageReq{ content_type, content, ... }) → MsgData
```

**目标 Go**：
```rust
// 步骤 1：创建消息
let msg = sdk.create_text_message(text).await?;   // SDK 内部生成 clientMsgID
// 步骤 2：发送消息
let sent = sdk.send_message(msg, recv_id, group_id).await?;
```

**任务**：
- [ ] 定义 `SendMessageReq` 改为独立的创建方法 + 发送方法
- [ ] `create_text_message(text)` → 生成 `MsgStruct` 类型
- [ ] `send_message(msg_struct, recv_id, group_id)` → 发送
- [ ] 保留旧接口兼容（或直接替换）

### 1.2 clientMsgID 生成对齐

**当前 Rust**：用户传入 `Option<String>`，默认 `msg_{now_ms}`

**目标 Go**：SDK 内部 `utils.GetMsgID(sendID)` → `MD5(nanoTime + sendID + random)`

**任务**：
- [ ] 实现 `utils::get_msg_id(send_id: &str) → String`（MD5 哈希，对齐 Go）
- [ ] 在 `create_text_message` 中自动调用

### 1.3 发送状态初始化

**当前 Rust**：消息创建时未设置 `status`

**目标 Go**：初始化时 `status = MsgStatusSending(1)`

**任务**：
- [ ] 创建消息时 `status` 初始化为 `1`
- [ ] `PendingMessage` / `LocalChatLog` 中 `status` 默认值

### 1.4 消息创建时字段填充

**当前 Rust**：`PendingMessage` 在 `sender.rs` 中构造

**目标 Go**：`initBasicInfo` 统一填充 `sendID`/`sendTime`/`createTime`/`platformID`/`senderNickname`/`senderFaceURL`

**任务**：
- [ ] 抽取 `init_basic_info` 公共方法
- [ ] 消息创建时自动填充所有基础字段

---

## 阶段二：消息接收与事件对齐（预计 3-4 天）

### 2.1 撤回通知事件

**当前 Rust**：
```rust
revoke_message(RevokeMessageReq)  // 只更新数据库，没推事件
```

**目标 Go**：
```
RevokeMessage
  → 更新 DB: status = MsgStatusHasDeleted(4)
  → doUpdateConversation(ConChange)           ← ConversationChanged
  → OnRecvNewMessages(revokeMessage)           ← 推送撤回消息通知
```

**任务**：
- [ ] 撤回后推送 `NewMessage` 事件（撤回消息类型）
- [ ] 撤回后推送 `ConversationChanged` 事件

### 2.2 seq gap 检测补拉

**当前 Rust**：`push_message_handler` 简单插入，无 gap 检测

**目标 Go**：`push_trigger_and_sync` → 发现 seq 不连续 → 自动补拉

**任务**：
- [ ] 消息接收时检测 seq 连续性
- [ ] 发现 gap 时自动调用 `batch_pull_messages` 补拉
- [ ] gap 消息用占位符填充

### 2.3 消息异常处理

**当前 Rust**：无

**目标 Go**：`handleExceptionMessages` 处理 4 种异常

**任务**：
- [ ] seq gap（占位符填充）
- [ ] 重复 clientMsgID + 不同 seq（保留新消息）
- [ ] 重复 clientMsgID + 相同 seq（跳过）
- [ ] 已删除消息（标记 deleted）

---

## 阶段三：字段补齐（预计 2-3 天）

### 3.1 LocalEx

**当前 Rust**：`LocalChatLog` 和 `MessageInfo` 均无 `local_ex`

**目标 Go**：`local_ex` 用于存储本地扩展信息

**任务**：
- [ ] `LocalChatLog` 增加 `local_ex` 字段
- [ ] `MessageInfo` 增加 `local_ex` 字段
- [ ] FFI 桥接传递该字段
- [ ] 数据库迁移（ALTER TABLE）

### 3.2 OfflinePush

**当前 Rust**：`MessageInfo` 无 `offline_push`

**目标 Go**：`offlinePush` 用于离线推送配置

**任务**：
- [ ] `MessageInfo` / `MsgStruct` 增加 `offline_push` 字段
- [ ] `SendMessageReq`（新版）增加离线推送参数

### 3.3 LastMinSeq（同步用）

**当前 Rust**：`GetHistoryMessagesReq` 无此字段

**目标 Go**：`GetAdvancedHistoryMessageListParams.LastMinSeq` 用于服务端同步

**任务**：
- [ ] `GetHistoryMessagesReq` 增加 `last_min_seq` 字段
- [ ] 同步时记录并传回

### 3.4 Markdown 消息

**当前 Rust**：无

**目标 Go**：`MarkdownTextElem` 结构化类型

**任务**：
- [ ] `create_markdown_message(text)` 方法
- [ ] Markdown 内容的独立结构体

---

## 阶段四：功能补齐（预计 2-3 天）

### 4.1 各消息类型独立 Elem 结构

**当前 Rust**：所有消息类型统一 JSON 字符串

**目标 Go**：每种消息类型有独立结构体

**任务**：
- [ ] 定义 `TextElem`、`PictureElem`、`QuoteElem` 等结构体
- [ ] 每种类型对应的 `create_xxx_message` 方法
- [ ] `content` 字段改为 Elem 的 JSON 序列化结果（兼容现有格式）

### 4.2 完整性测试

- [ ] 撤回消息测试
- [ ] 群聊消息测试
- [ ] 各消息类型创建测试
- [ ] seq gap 补拉测试

---

## 时间线

```
第 1 周：阶段一（API 对齐）
  周一：消息创建 + 发送两步走
  周二：clientMsgID 生成 + 状态初始化
  周三：字段填充对齐
  周四：测试 + 修复

第 2 周：阶段二（事件对齐）
  周一：撤回通知事件
  周二：seq gap 检测补拉
  周三：消息异常处理
  周四：测试 + 修复

第 3 周：阶段三（字段补齐）
  周一：LocalEx + OfflinePush
  周二：LastMinSeq + Markdown
  周三：测试 + 修复

第 4 周：阶段四（功能补齐）
  周一~周二：各消息类型 Elem 结构
  周三：全面测试
  周四：回归 + 文档更新
```

## 参考文件

| 文件 | 内容 |
|------|------|
| [sdk_diff.md](file:///c:/Users/11456/workspace/flutter_rust_demo/docs/sdk_diff.md) | 完整差异对比 |
| [message.rs](file:///c:/Users/11456/workspace/flutter_rust_demo/rust/src/sdk/client/message.rs) | Rust SDK 当前实现 |
| [api.go](file:///D:/workspace/openim-sdk-core/internal/conversation_msg/api.go) | Go SDK 参考实现 |
| [create_message.go](file:///D:/workspace/openim-sdk-core/internal/conversation_msg/create_message.go) | Go SDK 消息创建 |
| [sdk_struct.go](file:///D:/workspace/openim-sdk-core/sdk_struct/sdk_struct.go) | Go SDK MsgStruct 定义 |
| [handler.rs](file:///c:/Users/11456/workspace/flutter_rust_demo/rust/src/core/message/handler.rs) | Rust 消息处理 |
