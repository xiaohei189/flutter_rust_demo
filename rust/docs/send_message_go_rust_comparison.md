# Go / Rust 发送消息逻辑对比

基于 **openim-sdk-core**（Go）与 **flutter_rust_demo/rust**（Rust）当前实现整理。

---

## 1. 入口与参数

| 项目 | Go | Rust |
|------|----|------|
| 主入口 | `SendMessage(ctx, s *MsgStruct, recvID, groupID, p *OfflinePushInfo, isOnlineOnly bool)` | `send_message(&self, msg_data: MsgData, is_online_only: bool) -> Result<SendMsgResp>` |
| 会话/消息来源 | 内部 `checkID(ctx, s, recvID, groupID, options)` 得到 `lc`（LocalConversation），并可能改写 `s`（如 SendID、SessionType） | 调用方传入已填好的 `MsgData`，内部用 `conversation_id_from_msg_data(&msg_data)` 得到 conversation_id |
| 仅在线 | `isOnlineOnly bool`，为 true 时不做本地落库、不更新会话，并设置 options 通知服务端 | `is_online_only: bool`，行为与 Go 对齐 |

---

## 2. 发前（!isOnlineOnly / !is_online_only）

| 步骤 | Go | Rust | 说明 |
|------|----|------|------|
| 会话 ID | `checkID` 内根据 recvID/groupID 得到 `lc.ConversationID` | `conversation_id_from_msg_data(&msg_data)` | 一致：单聊 si_、群聊 sg_ 等 |
| 重发校验 | `GetMessage(lc.ConversationID, s.ClientMsgID)` | `get_by_client_msg_id(&conversation_id, &msg_data.client_msg_id)` | 一致 |
| 首次发送 | 无旧记录：`InsertMessage(localMessage)` + `InsertSendingMessage(...)` | 无旧记录：`insert_message(&local_log)`（status=SENDING）+ `sending_messages.insert(...)` | 一致。Rust 使用 INSERT OR REPLACE，重发时也会写入一条 SENDING |
| 重发（原消息 SendFailed） | 有旧记录且 Status==SendFailed：仅 `InsertSendingMessage`，不再 InsertMessage、不更新会话 | 有旧记录且 status==SEND_FAILED 时仅 `sending_messages.insert`，不 insert_message、不更新会话 | **已对齐** |
| 会话更新 | 仅首次发送时 `lc.LatestMsg` + `DispatchUpdateConversation` | 仅首次发送时 `upsert_conversation` + `try_emit_conversation_event(ConversationChanged)` | 一致 |

---

## 3. 媒体消息（图片/语音/视频/文件等）

| 项目 | Go | Rust |
|------|----|------|
| 处理位置 | `SendMessage` 内 switch ContentType：上传、写 URL、序列化 Content，失败时调 `updateMsgStatusAndTriggerConversation(..., MsgStatusSendFailed, ...)` | 不在 `send_message` 内处理：由上层先上传、组好 MsgData（含 content/URL），再调 `send_message` |
| 媒体后更新本地 | Picture/Sound/Video/File 上传成功后，若 !isOnlineOnly 则 `UpdateMessage(ctx, lc.ConversationID, localMessage)` | 无（消息体在上层已准备好） |

即：**发前落库 + 发送中表 + 会话更新** 的时机和条件与 Go 一致；媒体上传与 content 组装在 Go 是 SendMessage 内完成，在 Rust 由上层完成。

---

## 4. 发往服务端（sendMessageToServer / send_ws_req）

| 步骤 | Go | Rust |
|------|----|------|
| isOnlineOnly 时 options | `SetSwitchFromOptions(options, IsHistory, false)` 等 7 项（IsPersistent, IsSenderSync, IsConversationUpdate, IsSenderConversationUpdate, IsUnreadCount, IsOfflinePush） | `msg_data.options = HashMap` 写入相同 7 个 key（constant::IS_HISTORY 等）为 false | 一致 |
| 请求体 | `wsMsgData`（MsgData），含 Options、Content、OfflinePushInfo 等 | `msg_data`（MsgData）直接作为 WS 请求体 | 一致 |
| 发送 | `sendMsg(ctx, s, &wsMsgData, &sendMsgResp)` → `LongConnMgr.SendReqWaitResp(SendMsg, wsMsgData, sendMsgResp)` | `send_ws_req(WS_SEND_MSG, &msg_data)` | 一致 |

---

## 5. 发后：WS 响应处理（sendMsg）

| 情况 | Go | Rust |
|------|----|------|
| 响应失败 | 若超时且 !isOnlineOnly：查库若已 SendSuccess 则用库内数据返回；否则 `updateMsgStatusAndTriggerConversation(..., MsgStatusSendFailed)` | 若错误含 "ws rpc timeout" 且 !is_online_only：查库若已 SEND_SUCCESS 则返回 Ok(库内数据)；否则 `update_msg_status_and_trigger_conversation(..., SEND_FAILED)` | **已对齐** |
| 响应成功 + 无 Modify | `s.SendTime/Status/ServerMsgID` 赋值；在 go func 里 `updateMsgStatusAndTriggerConversation(..., SendTime, MsgStatusSendSuccess, ...)` | `update_message_time_and_status`，再 `delete(sending_messages)`、`update_conversation_latest_msg`、`try_emit_conversation_event` | 一致 |
| 响应成功 + 有 Modify | `chatLog := MsgDataToLocalChatLog(sendMsgResp.Modify)`，`*s = *LocalChatLogToMsgStruct(chatLog)`，`db.UpdateMessage(conversationID, chatLog)`；然后 go func 里同样 `updateMsgStatusAndTriggerConversation` | `msg_data_to_local_chat_log(modify)`，`update_message(&conversation_id, &log)`，再与无 Modify 相同：delete sending、update_conversation_latest_msg、emit event | 一致 |

---

## 6. updateMsgStatusAndTriggerConversation / update_msg_status_and_trigger_conversation

| 步骤 | Go | Rust |
|------|----|------|
| isOnlineOnly | 若 true 直接 return | 仅在 !is_online_only 时进入发后更新逻辑（本函数在 Rust 只在非仅在线路径调用） | 一致 |
| 更新消息状态 | `UpdateMessageTimeAndStatus(conversationID, clientMsgID, serverMsgID, sendTime, status)` | `update_message_time_and_status(...)` | 一致 |
| 发送中表 | `DeleteSendingMessage(conversationID, clientMsgID)` | `sending_messages.delete(...)` | 一致 |
| 会话 | `lc.LatestMsg = StructToJsonString(s)`，`lc.LatestMsgSendTime = sendTime`，`DispatchUpdateConversation(AddConOrUpLatMsg, *lc)` | `update_conversation_latest_msg` + `get_conversation_by_id` 取 conv，`try_emit_conversation_event(ConversationChanged)` | 一致 |

---

## 7. 差异小结

| 项目 | 说明 |
|------|------|
| **重发** | Go：重发只 `InsertSendingMessage`，不再次 InsertMessage、不再次更新会话。Rust：重发会 `insert_message`（REPLACE 为 SENDING）并再次 `upsert_conversation` + 触发会话事件，即多一次「发送中」的会话更新。 |
| **超时兜底** | Go：发送失败且为网络超时时，若 !isOnlineOnly 会再查库，若该消息已 SendSuccess 则用库内数据当作成功返回。Rust：暂无该逻辑，失败即返回 Err。 |
| **媒体** | Go 在 SendMessage 内完成上传与 content 组装；Rust 由上层先组好 MsgData 再发，职责划分不同但发前/发后本地逻辑对齐。 |

---

## 8. 流程简图（非仅在线）

```
Go:  checkID → [GetMessage → InsertMessage + InsertSendingMessage | 重发: InsertSendingMessage]
     → [媒体上传/UpdateMessage]
     → sendMessageToServer [isOnlineOnly 则设 options]
     → sendMsg (WS)
     → 失败: updateMsgStatusAndTriggerConversation(failed) [或超时查库]
     → 成功: [Modify: UpdateMessage] → go: updateMsgStatusAndTriggerConversation(success)

Rust: conversation_id
     → [get_by_client_msg_id → 非重发则 insert_message + sending_messages.insert]
     → [is_online_only 则设 msg_data.options]
     → send_ws_req(WS_SEND_MSG)
     → 失败: update_msg_status_and_trigger_conversation(failed)
     → 成功: [Modify: update_message] → update_message_time_and_status → delete sending → update_conversation_latest_msg → emit
```

以上为当前 Go / Rust 发送消息处理逻辑的对比与差异说明。
