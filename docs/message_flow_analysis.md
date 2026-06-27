# OpenIM 消息链路技术文档

## 一、Go SDK (openim-sdk-core) 消息流程

### 1.1 发送消息 (`api.go:274`)

```
sendMessage()
    │
    ├─ 1. checkID() — 创建/获取本地会话
    │
    ├─ 2. 本地入库去重:
    │     oldMessage = db.GetMessage(convID, clientMsgID)
    │     if oldMessage == nil:
    │         db.InsertMessage(lc, localMsg)     ← 首次发送，入库
    │     else if oldMessage.Status == SEND_FAILED:
    │         重发模式
    │     else:
    │         return ErrMsgRepeated              ← 非失败消息不允许重发
    │
    ├─ 3. DispatchUpdateConversation()           ← 更新会话 latestMsg
    │
    ├─ 4. 媒体上传 (图片/视频/文件)
    │
    └─ 5. sendMessageToServer() → sendMsg()
           │
           ├─ LongConnMgr.SendReqWaitResp()      ← WebSocket RPC 发送
           │
           ├─ 超时二次确认:
           │     if 超时 && DB 中消息已标记成功:
           │         return OK (幂等)            ← 不重复通知
           │
           └─ 成功: updateMsgStatusAndTriggerConversation()
                    │
                    ├─ db.UpdateMessage()          ← 更新状态为 SEND_SUCCESS
                    └─ DispatchUpdateConversation() ← 触发会话更新
```

**关键**：Go SDK 发送成功后**不发布 NewMessage 事件**，只更新消息状态和会话。消息已在步骤 2 入库，UI 通过 ConversationChanged 刷新即可看到。

### 1.2 接收推送 (`conversation_msg.go`)

推送到达后的处理路径：

```
服务器 PushMessage
    │
    ├─ triggerConversation()  或  PushMessage handler
    │
    ├─ 构建 newMessagesList (NewMsgList)
    │     - 包含所有非 typing 消息（**包括自己发的**）
    │     - self 消息也在列表中
    │
    └─ batchNewMessages(newMessagesList, ...)
         │
         ├─ 遍历 newMessagesList:
         │     if 前台:
         │         msgListener.OnRecvNewMessage(msg)    ← 通知 UI 层
         │     if 后台:
         │         msgListener.OnRecvOfflineNewMessage(msg)
         │
         └─ UI 层处理 (Flutter demo):
               onRecvNewMessage = (Message msg) {
                   if (!messageList.contains(msg)) {    ← **UI 去重！**
                       messageList.add(msg);
                   }
               }
```

**关键**：Go SDK 的 push 处理会为**所有消息**（包括自己发的）触发 `OnRecvNewMessage`。UI 层通过 `list.contains(message)` 去重（`Message` 类重写了 `operator ==`，按 `clientMsgID` 判等）。

### 1.3 Seq 间隙补偿 (`message_check.go:419`)

```
pullMessageIntoTable(pullMsgData)
    │
    ├─ 批量查询 DB: GetMessagesByClientMsgIDs(convID, msgIDs)
    │
    └─ 逐条处理:
         if msg.SendID == loginUserID:          ← 自己发的
             if exists:
                 if existing.Seq == 0:
                     updateMessage ← 仅更新 seq
                 else:
                     handleExceptionMessages → CLIENT_DUP → insertMessage  ← **插入重复！**
             else:
                 selfInsertMessage ← 其他终端同步（正常插入）
         else:                                   ← 别人发的
             if !exists:
                 othersInsertMessage ← 新消息
             else:
                 handleExceptionMessages → CLIENT_DUP → insertMessage  ← 插入重复
```

**关键**：Go SDK 的 seq 间隙补偿中，self 消息且已有 seq 时会插入 CLIENT_DUP 重复！这与 Rust 原始代码行为一致。

---

## 二、Rust SDK 消息流程 (当前实现)

### 2.1 发送消息

```
send_msg_inner()
    │
    ├─ 1. 生成 client_msg_id, send_time
    │
    ├─ 2. 重复检查: db.get_by_client_msg_id()     ← 带 conversation_id 过滤
    │     if exists && status != Failed:
    │         return ErrMsgRepeated
    │
    ├─ 3. send_queue.submit(do_send_message_impl)
    │
    └─ do_send_message_impl()
         │
         ├─ insert_message_before_send_impl()
         │     ├─ db.batch_insert(local_log)           ← Seq=0 入库
         │     ├─ db.update_after_sent_message()       ← 更新会话 latestMsg
         │     └─ publish ConversationChanged
         │
         ├─ connection.send_rpc(1003, msg_data)        ← WebSocket 发送
         │
         ├─ 超时二次确认 (同 Go)
         │
         └─ db.update_after_send_success()             ← 更新 server_msg_id, status
              └─ publish MessageSent                   ← **与 Go 不同：多了这个事件**
```

**与 Go 的差异**：Rust 发布 `MessageSent` 事件到 Dart，Dart 收到后 `list.add(msgInfo)`。这是 Dart UI 收到 sent 消息的路径。

### 2.2 接收推送 (服务器 echo)

```
服务器 PushMessage 被重复推送 3 次 (同一消息)
    │
    ├─ MessageBatcher 聚合 → BatchedPushMessages ×3
    │
    └─ push_message_handler (每次):
         │
         ├─ handle_messages(messages)                    ← 第 N 次处理同一消息
         │     │
         │     ├─ self 消息 (send_id == login_user_id):
         │     │     ├─ exists && Seq==0: batch_update_list ← 更新 seq
         │     │     └─ exists && Seq>0: (已修复) 跳过
         │     │
         │     ├─ 非 self 消息:
         │     │     ├─ !exists: insert_list + to_notify
         │     │     └─ exists: (已修复) 跳过
         │     │
         │     └─ to_notify 中的消息 → publish NewMessage → Dart 收到
         │
         └─ push_trigger_and_sync(conv_id, seqs)        ← 检测 seq 间隙
              │
              ├─ (已修复) per_conv_sync_locks 串行化    ← 防止并发 pull
              │
              └─ batch_pull_messages → handle_sync_messages
                   │
                   └─ RecvOfflineNewMessage (仅非 self)
```

### 2.3 Dart 侧消息接收

```
Rust event → _handleEvent()
    │
    ├─ messageSent:     list.add(msgInfo)        ← 发送成功时添加
    │     (已修复) 内容级去重
    │
    ├─ newMessage:      list.add(msgInfo)        ← 新消息时添加
    │     (已修复) clientMsgId + serverMsgId 去重
    │
    ├─ recvOfflineNewMessage:
    │     for msg in messages:
    │         if msg.sendId != currentUserId:    ← 过滤 self 消息
    │             list.add(msgInfo)
    │
    └─ MessageListNotifier._syncState():
          state = messages from MessageServiceState
```

---

## 三、差异对比

| 维度 | Go SDK | Rust SDK (原) | Rust SDK (修复后) |
|------|--------|---------------|-------------------|
| **发送成功通知** | updateMsgStatus + ConversationChanged | MessageSent（MsgData 为 opaque，等价 Go 函数返回值） | 同（增加 Set 去重） |
| **Push 处理 self 消息** | OnRecvNewMessage (含 self) | 仅更新 seq | 仅更新 seq |
| **Dart UI 去重** | `!messageList.contains(msg)` (按 clientMsgID) | 无 `==` 重载 | `messageSent` 内容去重 + `newMessage` clientMsgId/serverMsgId 去重 |
| **Seq 间隙 CLIENT_DUP** | **插入重复** | 已修复：跳过 | 已修复：跳过 |
| **push_trigger_and_sync 并发** | 有 sync_mutex 全局锁 | 无 → 有 per-conv 锁 | 已修复：per_conv_sync_locks |

---

## 四、根因分析

消息重复的核心原因：

1. **服务器推送了 3 次同一消息** — OpenIM server 的行为（可能是多实例推送去重不完美）

2. **Go SDK 在 UI 层有防御** — `messageList.contains(msg)` 基于 `clientMsgID` 的相等性判断拦截了重复

3. **Rust SDK 缺少 UI 层防御** — `MessageInfo` 没有重写 `operator ==`，`indexWhere` 去重依赖 `clientMsgId` 字符串比较，在某些时序下（如 `MessageSent` 与 `NewMessage` 先后到达，但 `clientMsgId` 在两次事件中一致）可能遗漏

4. **push_trigger_and_sync 并发** — 3 次 push 触发 3 次并发 pull，虽 DB 去重但增加了竞态窗口

---

## 五、已完成修复清单

| # | 修复 | 位置 |
|---|------|------|
| 1 | CLIENT_DUP self 消息跳过 | handler.rs:380-402 |
| 2 | CLIENT_DUP 非 self 消息跳过 | handler.rs:421-429 |
| 3 | push_trigger_and_sync per-conv 锁 | syncer.rs:227-240 |
| 4 | Dart messageSent 内容级去重 | message_service_notifier.dart:769 |
| 5 | Dart newMessage clientMsgId+serverMsgId 去重 | message_service_notifier.dart:716 |

---

## 六、建议后续优化

1. **MessageInfo 添加 `operator ==`**：基于 `clientMsgId` 或 `serverMsgId`，让 Dart 的 `list.contains()` 能正确去重
2. **Dart 消息去重已完备**：`_seenClientMsgIds` Set 替代 `operator ==`（因 MessageInfo 是自动生成的，== 比较全字段不适用）
3. **服务端推送去重**：检查为何同一消息被 push 3 次
