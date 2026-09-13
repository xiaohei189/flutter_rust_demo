# 消息发送链路重构设计（对齐 Go SDK / 业界主流）

> 状态：Phase 1 已实施（`e1c9fb7`）；Phase 2/3 见下
> 目标：发送消息本地先上屏（乐观），状态由 SDK 权威驱动；架构与 Go SDK 同构，可扩展、可维护。
> 范围：`rust/src/core/message/send/**`、`lib/data/repositories/message_repository*`、`lib/application/chat/**`、`lib/ui/chat/**`

## 0. 实施进度

| 阶段 | 内容 | 状态 |
|---|---|---|
| Phase 1 | 两段式 create+send、`MessageSendPipeline` 乐观上屏、状态收敛、失败重发、单测 | ✅ `e1c9fb7` |
| Phase 2 | 僵尸 sending 兜底、上传进度统一、弱网实测 | ✅ `Phase 2` 提交 |
| Phase 3 | Rust 侧 emit 本地消息事件，Dart 只消费（可选最彻底形态） | ⏳ |

Phase 1 实测（模拟器 x64，断开 adb reverse 模拟服务不可达）：

- 断网发送 → 气泡立即出现并标为失败 + SnackBar「发送消息失败，点击消息可重发」，输入框已清空；
- 恢复网络后点失败标记重发 → 同一条变 ✓，无重复气泡；
- `client_msg_id` 全程一致（失败 `c507441374a2e1bb246a6774d2286bfd` → 重发成功同一 ID）。

Phase 2 实测（模拟器 x64，`docker pause openim-server` 模拟服务无响应/黑洞）：

- **僵尸发送兜底**：服务暂停时发文本 → 气泡停在「发送中」→ 杀进程 → 恢复服务并重启 App →
  日志 `登录时清理了 1 条sending消息`，气泡直接显示失败（不再无限转圈）→ 点重发成功；
- **上传进度统一**：`upload_progress` 事件首次按乐观气泡的 `clientMsgId` 上报
  （`client_msg_id=80e7cc58022a47bc4d7f9ae873e4ed13, progress=0 → 100`），进度、状态、去重同一把钥匙；
- **媒体本地预览**：上传未完成/失败时气泡直接用本地文件渲染（原先显示「图片地址为空」）；
- **媒体失败重发**：暂停 MinIO+服务端发图 → 本地预览 + 发送中 → 失败 → 恢复后点重发 → ✓ 且无重复气泡。

### 阈值

- 本地消息超过 `30s`（Dart `kStaleSendingTimeoutMs` / Rust `STALE_SENDING_RETRY_MS`）仍为
  「发送中」且无上传进度 → 视为僵尸，标为失败并允许重发（Rust 侧 `can_resend` 同步放宽，
  避免"UI 已标失败但 SDK 拒绝重发"）。

## 1. 现状问题

1. **发送是"等网络成功才上屏"**：`lib/ui/chat/view_models/message_view_model.dart` 的 `sendXxxMessage` 先 `await` 服务端返回，成功才 `_addSentMessage(result)`；失败只写 `state.error`。
   → 网络异常时列表里**什么都没有**，用户看到"没反应"。
2. **Rust 已做本地插入但没发事件**：`rust/src/core/message/send/sender.rs` 的 `insert_message_before_send_impl` 会以 `MessageSendStatus::Sending` 写本地库 + `sending_message` 表 + 乐观更新会话（emit `ConversationEvent::Changed`），但**不 emit `MessageEvent::NewMessage`**，Dart 侧也无从得知。
3. **失败不可见**：失败只写进 `MessageListState.error`，没有任何 UI 消费它；气泡红叹号（`MessageStatusIcon`）与列表重试（`retryFailedSend`）能力已存在却没被触发。

## 2. Go SDK / 业界做法（参考实现）

| 环节 | Go SDK / openim-flutter-demo | 我们现在 |
|---|---|---|
| 构造消息 | `CreateTextMessage/CreateAtTextMessage/...` → 本地消息（`clientMsgID`、`status=Sending`） | FFI 已有 `createTextMessage/...`（`ffi/message_builder.dart`），但发送路径没用 |
| 发送 | `SendMessage(message)` 发送**同一条**已创建消息 | `client.sendTextMessage(text:...)` 内部另建一条（clientMsgId 不同）；媒体走的是 `ffi_message_advanced.sendMessage` |
| 上屏时机 | demo `_sendMessage`：`messageList.add(message)` 立刻上屏，随后 `sendMessage` | 等服务端返回后才上屏 |
| 成功 | `oldMsg.update(newMsg)`（同一 clientMsgID 就地更新） | 插入服务端返回的新消息 |
| 失败 | 标 `failed`，点按重发 `_sendMessage(message..status = sending, addToUI: false)` | 丢弃，不加任何消息 |
| 崩溃恢复 | SDK `sending_message` 表 + 重连后补发 | Rust 已写 `sending_message` 表，但 Dart 无兜底 |

## 3. 目标架构

```
UI（气泡/状态图标/重试）                 ← 只渲染 status，不做发送决策
  ↑ state.messages
Application: MessageSendPipeline         ← 唯一发送入口（create → optimistic → send → 状态收敛）
  ├─ MessageServiceReducer.applySendStatus(state, clientMsgId, status)  ← 幂等状态收敛
  └─ MessageSendController               ← 组装参数、调用 Repository
  ↓
Data: MessageRepository                  ← createXxxMessage() + sendMessage(msg) 两段式（与 Go API 一一对应）
  ↓
Rust SDK: builder（本地消息） + send_message（本地落库 + WS 发送 + 状态事件）
```

### 3.1 发送状态机（唯一权威）

```
[本地创建] --create--> status=sending ──send 成功──> status=success(2)
                               │
                               └──send 失败/超时──> status=failed(3) ──点重发──> status=sending（同一条，不新增）
```

- 所有状态变化只经过 `applySendStatus`，**幂等**（同一 clientMsgId 重复置同一状态无副作用）。
- 状态来源有两个（返回值 / SDK 事件 `MessageEvent.sendFailed`、`uploadProgress`），两者都调用同一个 reducer，不产生双写差异。
- `clientMsgId` 全程沿用**本地生成**的那个，成功时用服务端返回的字段就地更新 → 不会出现重复气泡，回执/去重按 clientMsgId 自然命中。

### 3.2 与 Go 的映射

| Go | 本仓库（目标） |
|---|---|
| `CreateTextMessage` | `ffi/message_builder.dart#createTextMessage` |
| `SendMessage(msg)` | `ffi/message_advanced.dart#sendMessage(msg)` |
| `messageList.add(msg)` | `MessageSendPipeline` 里 `upsertSentMessage(乐观条)` |
| `oldMsg.update(newMsg)` | `applySendStatus(..., success) + 更新 serverMsgId/seq/sendTime` |
| `_senFailed` | `applySendStatus(..., failed)` + 失败提示 |
| 重发 `addToUI: false` | `retrySend(clientMsgId)`：只改状态为 sending，不新增条目 |

## 4. 落地步骤

### Phase 1：发送链路改两段式（本轮）

1. `MessageRepositorySendMixin`：`sendTextMessage/sendMarkdownMessage/sendAtTextMessage` 内部改为
   `createXxxMessage(...)` → `ffi_message_advanced.sendMessage(msg, sourceId, sessionType)`（媒体路径已是此形态，统一之）。
2. `MessageSendPipeline`（`lib/application/chat/message_send_pipeline.dart`，新建）：
   - `optimisticInsert(conversationId, msg)`：构造乐观 `ChatMessage` 并写入 state；
   - `send(...)`：成功 → 就地更新；失败 → `failed` + 返回错误；
   - `retry(clientMsgId)`：状态置 sending 后重发，不新增。
3. `MessageServiceReducer.applySendStatus`：新增幂等状态收敛（替代分散的 `applySendFailed` 特例）。
4. UI：失败弹 SnackBar（"发送失败，点消息可重发"）；气泡状态由 `MessageStatusIcon` 呈现（已具备）。

### Phase 2：健壮性

5. **僵尸 sending 兜底**：进入会话时扫描本地 `status==sending` 且 `sendTime` 超过阈值（30s）的条目标记为 failed。
6. 上传进度（`uploadProgress`）与状态条统一走同一 reducer；进度条渲染复用现有 `applyUploadProgress`。
7. 断网/弱网实测：发送中 → 失败 → 重发成功 三态截图；补 3 条单测（上屏即 sending / 成功不重复 / 失败可重发）。

### Phase 3：SDK 侧同构（可选，最彻底）

8. Rust 在 `insert_message_before_send_impl` 后 emit `MessageEvent::NewMessage`（本地消息），失败时 emit `sendFailed`，成功后 emit 状态更新事件；
   Dart 只消费事件、不自行构造状态 → 与 Go SDK 完全同构（UI 与 SDK 解耦，任何端复用同一套事件）。

## 5. 扩展指引：新增一种消息类型只需 3 步

1. Rust `builder.rs` 加 `create_xxx_message`（若已存在可跳过）；
2. Dart 调用处把 create 闭包交给 `MessageSendPipeline`（例如 `() => ffi.createImageMessage(...)`）；
3. 内容渲染组件（`message_content_builder.dart` 的 switch）加分支。

**发送状态机、乐观上屏、失败重试、进度、去重都不需要改动**。

## 6. 验收标准

- 断网发送：气泡**立刻出现**（转圈）→ 约 10s 内变红叹号 + SnackBar 提示，且条目保留可重发；
- 恢复网络重发：同一条变为 ✓，**不产生重复气泡**；
- 发送中杀进程再进会话：该条不再无限转圈（Phase 2 兜底为 failed）；
- `flutter test test`、`cargo test --lib` 全绿（既有 4 条失败除外）；
- 新增/修改逻辑均有单测覆盖（状态机幂等、成功替换、失败保留重发）。
