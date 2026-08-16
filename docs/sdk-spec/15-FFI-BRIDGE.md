# FFI 桥接层设计参考

> ⚠️ **API 状态标注过时**：本文档的「❌ 未实现」标注为**早期基线**，多数标 ❌ 的 API（消息创建全系列、撤回/已读/删除、好友/群组申请、禁言、转发、Typing、会话设置、用户状态订阅等）**已实现**。
> FFI 实际覆盖情况以 **[docs/SDK_PROGRESS.md](../SDK_PROGRESS.md) 第 6 节** + 实际代码（`rust/src/ffi/`、`rust/src/client/`）为准。

> 本文档完整记录 Go SDK 公开 API 与 Rust FFI 桥接函数的对照关系，包括当前已实现的函数列表、
> 缺失的函数、事件流设计和类型映射。

---

## 1. 完整 API 对照表

以下按模块分组，列出 Go SDK 所有公开函数及对应的 Rust 实现状态。

### 1.1 init_login.go（生命周期管理，10 个函数）

| # | Go SDK 函数 | 参数 | Rust SDK 方法 | FFI 函数 | 状态 |
|---|------------|------|-------------|---------|------|
| 1 | `InitSDK(listener, operationID, config)` | OnConnListener, string, IMConfig JSON | `OpenIMClient::new(config)` | `OpenIMBridgeClient::new()` | ✅ 已实现 |
| 2 | `UnInitSDK(operationID)` | string | — | — | ❌ 未实现 |
| 3 | `GetSdkVersion()` | 无 | — | — | ❌ 未实现 |
| 4 | `Login(callback, operationID, userID, token)` | Base, string, string, string | `OpenIMClient::login(user_id, token)` | 在 `new()` 内部调用 | ✅ 已实现 |
| 5 | `Logout(callback, operationID)` | Base, string | `OpenIMClient::logout()` | `OpenIMBridgeClient::logout()` | ✅ 已实现 |
| 6 | `GetLoginStatus(operationID)` | string | — | — | ❌ 未实现 |
| 7 | `GetLoginUserID()` | 无 | `context.get_user_id()` | — | ❌ 未实现 |
| 8 | `SetAppBackgroundStatus(callback, operationID, isBackground)` | Base, string, bool | — | — | ❌ 未实现 |
| 9 | `NetworkStatusChanged(callback, operationID)` | Base, string | `connection.disconnect()` | — | ❌ 未实现 |
| 10 | `SetConnListener(listener)` | OnConnListener | — | — | ❌ 未实现（Rust 使用 EventBus） |

### 1.2 relation.go（好友关系，16 个函数）

| # | Go SDK 函数 | Rust SDK 方法 | FFI 函数 | 状态 |
|---|------------|-------------|---------|------|
| 1 | `GetSpecifiedFriendsInfo(callback, opID, userIDList, filterBlack)` | — | — | ❌ 未实现 |
| 2 | `GetFriendList(callback, opID, filterBlack)` | `friend.get_friend_list()` | `get_friend_list()` | ✅ 已实现 |
| 3 | `GetFriendListPage(callback, opID, offset, count, filterBlack)` | — | — | ❌ 未实现 |
| 4 | `SearchFriends(callback, opID, searchParam)` | — | — | ❌ 未实现 |
| 5 | `CheckFriend(callback, opID, userIDList)` | `friend.is_friend(user_id)` | `is_friend()` | ✅ 已实现 |
| 6 | `AddFriend(callback, opID, userIDReqMsg)` | `friend.add_friend(user_id, req_msg)` | `add_friend()` | ✅ 已实现 |
| 7 | `UpdateFriends(callback, opID, req)` | — | — | ❌ 未实现 |
| 8 | `DeleteFriend(callback, opID, friendUserID)` | `friend.delete_friend(user_id)` | `delete_friend()` | ✅ 已实现 |
| 9 | `GetFriendApplicationListAsRecipient(callback, opID, req)` | `friend.get_friend_apply_list()` | `get_friend_apply_list()` | ✅ 已实现 |
| 10 | `GetFriendApplicationListAsApplicant(callback, opID, req)` | — | — | ❌ 未实现 |
| 11 | `AcceptFriendApplication(callback, opID, userIDHandleMsg)` | `friend.accept_friend_application()` | `accept_friend_application()` | ✅ 已实现 |
| 12 | `RefuseFriendApplication(callback, opID, userIDHandleMsg)` | `friend.refuse_friend_application()` | `refuse_friend_application()` | ✅ 已实现 |
| 13 | `AddBlack(callback, opID, blackUserID, ex)` | `friend.add_black(user_id)` | `add_black()` | ✅ 已实现 |
| 14 | `GetBlackList(callback, opID)` | `friend.get_blacklist()` | `get_black_list()` | ✅ 已实现 |
| 15 | `RemoveBlack(callback, opID, removeUserID)` | `friend.remove_black(user_id)` | `remove_black()` | ✅ 已实现 |
| 16 | `GetFriendApplicationUnhandledCount(callback, opID, req)` | — | — | ❌ 未实现 |

### 1.3 group.go（群组操作，28 个函数）

| # | Go SDK 函数 | Rust SDK 方法 | FFI 函数 | 状态 |
|---|------------|-------------|---------|------|
| 1 | `CreateGroup(callback, opID, groupReqInfo)` | `group.create_group()` | `create_group()` | ✅ 已实现 |
| 2 | `JoinGroup(callback, opID, groupID, reqMsg, joinSource, ex)` | `group.join_group()` | `join_group()` | ✅ 已实现 |
| 3 | `QuitGroup(callback, opID, groupID)` | `group.quit_group()` | `quit_group()` | ✅ 已实现 |
| 4 | `DismissGroup(callback, opID, groupID)` | `group.dismiss_group()` | `dismiss_group()` | ✅ 已实现 |
| 5 | `ChangeGroupMute(callback, opID, groupID, isMute)` | — | — | ❌ 未实现 |
| 6 | `ChangeGroupMemberMute(callback, opID, groupID, userID, mutedSeconds)` | — | — | ❌ 未实现 |
| 7 | `TransferGroupOwner(callback, opID, groupID, newOwnerUserID)` | — | — | ❌ 未实现 |
| 8 | `KickGroupMember(callback, opID, groupID, reason, userIDList)` | `group.kick_group_member()` | `kick_group_members()` | ✅ 已实现 |
| 9 | `SetGroupInfo(callback, opID, groupInfo)` | `group.set_group_info()` | `set_group_info()` | ✅ 已实现 |
| 10 | `SetGroupMemberInfo(callback, opID, groupMemberInfo)` | — | — | ❌ 未实现 |
| 11 | `GetJoinedGroupList(callback, opID)` | `group.get_joined_group_list()` | `get_group_list()` | ✅ 已实现 |
| 12 | `GetJoinedGroupListPage(callback, opID, offset, count)` | — | — | ❌ 未实现 |
| 13 | `GetSpecifiedGroupsInfo(callback, opID, groupIDList)` | `group.get_groups_info()` | `get_groups_info()` | ✅ 已实现 |
| 14 | `SearchGroups(callback, opID, searchParam)` | — | — | ❌ 未实现 |
| 15 | `GetGroupMemberOwnerAndAdmin(callback, opID, groupID)` | — | — | ❌ 未实现 |
| 16 | `GetGroupMemberListByJoinTimeFilter(callback, ...)` | — | — | ❌ 未实现 |
| 17 | `GetSpecifiedGroupMembersInfo(callback, opID, groupID, userIDList)` | `group.get_group_members_info()` | `get_group_members_info()` | ✅ 已实现 |
| 18 | `GetGroupMemberList(callback, opID, groupID, filter, offset, count)` | `group.get_group_member_list()` | `get_group_members()` | ✅ 已实现 |
| 19 | `GetGroupApplicationListAsRecipient(callback, opID, req)` | `group.get_group_application_list()` | `get_group_application_list()` | ✅ 已实现 |
| 20 | `GetGroupApplicationListAsApplicant(callback, opID, req)` | — | — | ❌ 未实现 |
| 21 | `SearchGroupMembers(callback, opID, searchParam)` | — | — | ❌ 未实现 |
| 22 | `IsJoinGroup(callback, opID, groupID)` | — | — | ❌ 未实现 |
| 23 | `GetUsersInGroup(callback, opID, groupID, userIDList)` | — | — | ❌ 未实现 |
| 24 | `InviteUserToGroup(callback, opID, groupID, reason, userIDList)` | `group.invite_user_to_group()` | `invite_group_members()` | ✅ 已实现 |
| 25 | `AcceptGroupApplication(callback, opID, groupID, fromUserID, handleMsg)` | `group.accept_group_application()` | `accept_group_application()` | ✅ 已实现 |
| 26 | `RefuseGroupApplication(callback, opID, groupID, fromUserID, handleMsg)` | `group.refuse_group_application()` | `refuse_group_application()` | ✅ 已实现 |
| 27 | `CheckLocalGroupFullSync(callback, opID)` | — | — | ❌ 未实现 |
| 28 | `CheckGroupMemberFullSync(callback, opID, groupID)` | — | — | ❌ 未实现 |

### 1.4 user.go（用户操作，4 个函数）

| # | Go SDK 函数 | Rust SDK 方法 | FFI 函数 | 状态 |
|---|------------|-------------|---------|------|
| 1 | `GetUsersInfo(callback, opID, userIDs)` | `user.get_users_info(user_ids)` | `get_users_info()` | ✅ 已实现 |
| 2 | `SetSelfInfo(callback, opID, userInfo)` | `user.update_self_user_info()` | `update_user_profile()` | ✅ 已实现 |
| 3 | `GetSelfUserInfo(callback, opID)` | `user.get_self_user_info()` | — | ❌ 未实现（内部使用） |
| 4 | `GetUserClientConfig(callback, opID)` | — | — | ❌ 未实现 |

### 1.5 conversation_msg.go（会话与消息，40+ 个函数）

| # | Go SDK 函数 | Rust SDK 方法 | FFI 函数 | 状态 |
|---|------------|-------------|---------|------|
| 1 | `GetAllConversationList(callback, opID)` | `conversation_dao.get_all()` | `get_conversations()` | ✅ 已实现 |
| 2 | `GetConversationListSplit(callback, opID, offset, count)` | — | — | ❌ 未实现 |
| 3 | `GetOneConversation(callback, opID, sessionType, sourceID)` | `conversation_dao.get_by_id()` | `get_conversation()` | ✅ 已实现 |
| 4 | `GetMultipleConversation(callback, opID, conversationIDList)` | — | — | ❌ 未实现 |
| 5 | `SetConversation(callback, opID, conversationID, req)` | — | — | ❌ 未实现 |
| 6 | `HideConversation(callback, opID, conversationID)` | — | — | ❌ 未实现 |
| 7 | `SetConversationDraft(callback, opID, conversationID, draftText)` | `conversation.set_draft()` | `set_conversation_draft()` | ✅ 已实现 |
| 8 | `GetTotalUnreadMsgCount(callback, opID)` | — | — | ❌ 未实现 |
| 9 | `CreateTextMessage(opID, text)` | `MsgStruct::create_text_message()` | — | ✅ 内部使用 |
| 10 | `CreateAdvancedTextMessage(opID, text, entityList)` | `MsgStruct::create_advanced_text_message()` | `send_advanced_text_message()` | ✅ 已实现 |
| 11 | `CreateTextAtMessage(opID, text, atUserList, ...)` | — | — | ❌ 未实现 |
| 12 | `CreateLocationMessage(opID, desc, lon, lat)` | — | — | ❌ 未实现 |
| 13 | `CreateCustomMessage(opID, data, extension, desc)` | — | — | ❌ 未实现 |
| 14 | `CreateQuoteMessage(opID, text, message)` | — | — | ❌ 未实现 |
| 15 | `CreateAdvancedQuoteMessage(opID, ...)` | — | — | ❌ 未实现 |
| 16 | `CreateCardMessage(opID, cardInfo)` | — | — | ❌ 未实现 |
| 17 | `CreateVideoMessageFromFullPath(opID, ...)` | — | — | ❌ 未实现 |
| 18 | `CreateImageMessageFromFullPath(opID, path)` | — | — | ❌ 未实现 |
| 19 | `CreateSoundMessageFromFullPath(opID, path, dur)` | — | — | ❌ 未实现 |
| 20 | `CreateFileMessageFromFullPath(opID, path, name)` | — | — | ❌ 未实现 |
| 21 | `CreateImageMessage(opID, imagePath)` | `MsgStruct::create_image_message()` | `send_image_message()` | ✅ 已实现 |
| 22 | `CreateImageMessageByURL(opID, ...)` | — | — | ❌ 未实现 |
| 23 | `CreateSoundMessage(opID, path, dur)` | — | — | ❌ 未实现 |
| 24 | `CreateSoundMessageByURL(opID, info)` | — | — | ❌ 未实现 |
| 25 | `CreateVideoMessage(opID, ...)` | — | — | ❌ 未实现 |
| 26 | `CreateVideoMessageByURL(opID, info)` | — | — | ❌ 未实现 |
| 27 | `CreateFileMessage(opID, path, name)` | `MsgStruct::create_file_message()` | `send_file_message()` | ✅ 已实现 |
| 28 | `CreateFileMessageByURL(opID, info)` | — | — | ❌ 未实现 |
| 29 | `CreateMergerMessage(opID, msgList, title, summaryList)` | — | — | ❌ 未实现 |
| 30 | `CreateFaceMessage(opID, index, data)` | — | — | ❌ 未实现 |
| 31 | `CreateForwardMessage(opID, m)` | — | — | ❌ 未实现 |
| 32 | `SendMessage(callback, opID, msg, recvID, groupID, offlinePush, isOnlineOnly)` | `client.send_msg()` | 间接通过 `send_text_message` 等 | ✅ 已实现 |
| 33 | `SendMessageNotOss(callback, opID, ...)` | — | — | ❌ 未实现 |
| 34 | `FindMessageList(callback, opID, options)` | — | — | ❌ 未实现 |
| 35 | `GetAdvancedHistoryMessageList(callback, opID, options)` | `client.get_history_messages()` | `get_history_messages()` | ✅ 已实现 |
| 36 | `GetAdvancedHistoryMessageListReverse(callback, opID, options)` | — | — | ❌ 未实现 |
| 37 | `RevokeMessage(callback, opID, convID, clientMsgID)` | `message_service.revoke_message()` | `revoke_message()` | ✅ 已实现 |
| 38 | `TypingStatusUpdate(callback, opID, recvID, msgTip)` | — | — | ❌ 未实现 |
| 39 | `MarkConversationMessageAsRead(callback, opID, convID)` | `message_service.mark_conversation_as_read()` | `mark_conversation_as_read()` | ✅ 已实现 |
| 40 | `MarkAllConversationMessageAsRead(callback, opID)` | — | — | ❌ 未实现 |
| 41 | `MarkMessagesAsReadByMsgID(callback, opID, convID, clientMsgIDs)` | `message_service.mark_messages_as_read()` | `mark_messages_as_read()` | ✅ 已实现 |
| 42 | `DeleteMessageFromLocalStorage(callback, opID, convID, clientMsgID)` | — | — | ❌ 未实现 |
| 43 | `DeleteMessage(callback, opID, convID, clientMsgID)` | `message_service.delete_messages()` | `delete_messages()` | ✅ 已实现 |
| 44 | `HideAllConversations(callback, opID)` | — | — | ❌ 未实现 |
| 45 | `DeleteAllMsgFromLocalAndSvr(callback, opID)` | — | — | ❌ 未实现 |
| 46 | `DeleteAllMsgFromLocal(callback, opID)` | — | — | ❌ 未实现 |
| 47 | `ClearConversationAndDeleteAllMsg(callback, opID, convID)` | — | — | ❌ 未实现 |
| 48 | `DeleteConversationAndDeleteAllMsg(callback, opID, convID)` | `conversation.delete_conversation()` | `delete_conversation()` | ✅ 已实现 |
| 49 | `InsertSingleMessageToLocalStorage(callback, opID, msg, recvID, sendID)` | — | — | ❌ 未实现 |
| 50 | `InsertGroupMessageToLocalStorage(callback, opID, msg, groupID, sendID)` | — | — | ❌ 未实现 |
| 51 | `SearchLocalMessages(callback, opID, searchParam)` | `message_service.search_local_messages()` | `search_local_messages()` | ✅ 已实现 |
| 52 | `SetMessageLocalEx(callback, opID, convID, clientMsgID, localEx)` | — | — | ❌ 未实现 |
| 53 | `SearchConversation(callback, opID, searchParam)` | — | — | ❌ 未实现 |
| 54 | `ChangeInputStates(callback, opID, convID, focus)` | — | — | ❌ 未实现 |
| 55 | `GetInputStates(callback, opID, convID, userID)` | — | — | ❌ 未实现 |

### 1.6 online.go（在线状态，4 个函数）

| # | Go SDK 函数 | Rust SDK 方法 | FFI 函数 | 状态 |
|---|------------|-------------|---------|------|
| 1 | `SubscribeUsersStatus(callback, opID, userIDs)` | `online_status.subscribe()` | — | ❌ 未实现 |
| 2 | `UnsubscribeUsersStatus(callback, opID, userIDs)` | `online_status.unsubscribe()` | — | ❌ 未实现 |
| 3 | `GetSubscribeUsersStatus(callback, opID)` | — | — | ❌ 未实现 |
| 4 | `GetUserStatus(callback, opID, userIDs)` | `online_status.get_user_status()` | `get_user_status()` | ✅ 已实现 |

### 1.7 third.go（第三方服务，5 个函数）

| # | Go SDK 函数 | Rust SDK 方法 | FFI 函数 | 状态 |
|---|------------|-------------|---------|------|
| 1 | `UpdateFcmToken(callback, opID, fcmToken, expireTime)` | — | — | ❌ 未实现 |
| 2 | `SetAppBadge(callback, opID, appUnreadCount)` | — | — | ❌ 未实现 |
| 3 | `UploadLogs(callback, opID, line, ex, progress)` | — | — | ❌ 未实现 |
| 4 | `Logs(callback, opID, logLevel, file, line, msgs, err, keyAndValue)` | — | — | ❌ 未实现 |
| 5 | `UploadFile(callback, opID, req, progress)` | `file_uploader.upload_file()` | `upload_file()` | ✅ 已实现 |

### 1.8 listener.go（监听器设置，7 个函数）

| # | Go SDK 函数 | Rust 对应方式 | 状态 |
|---|------------|-------------|------|
| 1 | `SetGroupListener(listener)` | EventBus 事件 | ✅ 通过 SdkEvent |
| 2 | `SetConversationListener(listener)` | EventBus 事件 | ✅ 通过 SdkEvent |
| 3 | `SetAdvancedMsgListener(listener)` | EventBus 事件 | ✅ 通过 SdkEvent |
| 4 | `SetUserListener(listener)` | EventBus 事件 | ✅ 通过 SdkEvent |
| 5 | `SetFriendListener(listener)` | EventBus 事件 | ✅ 通过 SdkEvent |
| 6 | `SetCustomBusinessListener(listener)` | EventBus 事件 | ✅ 通过 SdkEvent |
| 7 | `SetMessageKvInfoListener(listener)` | EventBus 事件 | ❌ 未实现 |

---

## 2. FFI 函数设计规范

### 2.1 注解要求

所有导出给 Flutter/Dart 的函数必须添加 `#[flutter_rust_bridge::frb]` 注解：

```rust
#[flutter_rust_bridge::frb]
pub async fn function_name(param: String) -> Result<ReturnType> {
    // ...
}
```

### 2.2 命名规范

- Rust 函数名使用 `snake_case`
- FRB 自动生成 Dart 侧的 `camelCase` 方法名
- 示例：`send_text_message` → Dart 侧 `sendTextMessage()`

### 2.3 参数规则

- **所有参数使用值类型**（`String` 而非 `&str`），FRB 不支持引用类型
- 可选参数使用 `Option<T>`，Dart 侧映射为 `T?`
- 数组使用 `Vec<T>`，Dart 侧映射为 `List<T>`

### 2.4 返回值规则

- 同步函数直接返回值类型
- 异步函数返回 `Result<T>`（`anyhow::Result<T>`），错误自动映射到 Dart 侧的异常
- 空返回值使用 `Result<()>` 或无返回值

### 2.5 Stream 事件流

```rust
#[flutter_rust_bridge::frb]
pub async fn event_stream(&self, sink: StreamSink<SdkEvent>) -> Result<()> {
    let event_bus = self.inner.event_bus();
    tokio::spawn(async move {
        let mut subscription = event_bus.subscribe();
        while let Some(event) = subscription.next().await {
            let _ = sink.add(event);
        }
    });
    Ok(())
}
```

### 2.6 结构体导出

```rust
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExportedStruct {
    pub field_name: String,
    #[serde(rename = "fieldURL")]
    pub field_url: String,
}
```

- 必须实现 `Clone`（FRB 要求）
- 使用 `serde` 的 `rename_all = "camelCase"` 自动转换字段名
- `opaque` 标记的结构体不需要 `Serialize/Deserialize`

---

## 3. 当前已实现的 FFI 函数列表

### 3.1 OpenIMBridgeClient 方法（39 个）

#### 客户端生命周期（4 个）

| # | FFI 方法 | 功能 |
|---|---------|------|
| 1 | `new(config: ClientConfig)` | 创建客户端并登录 |
| 2 | `disconnect()` | 断开连接 |
| 3 | `logout()` | 登出 |
| 4 | `event_stream(sink: StreamSink<SdkEvent>)` | 订阅事件流 |

#### 消息操作（10 个）

| # | FFI 方法 | 功能 |
|---|---------|------|
| 5 | `send_text_message(text, source_id, session_type)` | 发送文本消息 |
| 6 | `send_markdown_message(text, source_id, session_type)` | 发送 Markdown 消息 |
| 7 | `send_advanced_text_message(text, entities, source_id, session_type)` | 发送富文本消息 |
| 8 | `send_image_message(file_path, source_id, session_type)` | 发送图片消息 |
| 9 | `get_history_messages(req: GetHistoryMessagesReq)` | 获取历史消息 |
| 10 | `revoke_message(req: RevokeMessageReq)` | 撤回消息 |
| 11 | `delete_messages(req: DeleteMessagesReq)` | 删除消息 |
| 12 | `mark_messages_as_read(req: MarkMessagesAsReadReq)` | 标记消息已读 |
| 13 | `mark_conversation_as_read(conversation_id, session_type)` | 标记会话已读 |
| 14 | `search_local_messages(req: SearchMessagesReq)` | 搜索本地消息 |

#### 会话操作（10 个）

| # | FFI 方法 | 功能 |
|---|---------|------|
| 15 | `get_conversations()` | 获取所有会话 |
| 16 | `get_conversation(conversation_id)` | 获取单个会话 |
| 17 | `update_conversation_unread_count(conversation_id, count)` | 更新未读数 |
| 18 | `set_conversation_pinned(conversation_id, is_pinned)` | 置顶/取消置顶 |
| 19 | `delete_conversation(conversation_id)` | 删除会话 |
| 20 | `set_conversation_draft(conversation_id, draft_text)` | 设置草稿 |
| 21 | `set_conversation_private(conversation_id, is_private)` | 设置私聊 |
| 22 | `get_pinned_conversations()` | 获取置顶会话 |
| 23 | `clear_conversation_draft(conversation_id)` | 清除草稿 |
| 24 | `mark_conversation_as_read(conversation_id, session_type)` | 标记会话已读 |

#### 好友操作（11 个）

| # | FFI 方法 | 功能 |
|---|---------|------|
| 25 | `get_friend_list()` | 获取好友列表 |
| 26 | `add_friend(user_id, req_msg)` | 添加好友 |
| 27 | `delete_friend(user_id)` | 删除好友 |
| 28 | `get_black_list()` | 获取黑名单 |
| 29 | `is_friend(user_id)` | 检查是否好友 |
| 30 | `add_black(user_id)` | 加入黑名单 |
| 31 | `remove_black(user_id)` | 移出黑名单 |
| 32 | `get_friend_apply_list()` | 获取好友申请列表 |
| 33 | `accept_friend_application(user_id)` | 接受好友申请 |
| 34 | `refuse_friend_application(user_id)` | 拒绝好友申请 |
| 35 | `get_friend_id_list()` | 获取好友 ID 列表 |

#### 群组操作（13 个）

| # | FFI 方法 | 功能 |
|---|---------|------|
| 36 | `get_group_list()` | 获取群组列表 |
| 37 | `create_group(group_name, group_type, member_ids)` | 创建群组 |
| 38 | `join_group(group_id, req_msg)` | 加入群组 |
| 39 | `quit_group(group_id)` | 退出群组 |
| 40 | `get_group_members(group_id)` | 获取群成员 |
| 41 | `invite_group_members(group_id, member_ids)` | 邀请入群 |
| 42 | `kick_group_members(group_id, member_ids)` | 踢出群成员 |
| 43 | `get_groups_info(group_ids)` | 获取群信息 |
| 44 | `set_group_info(group_id, name, face_url)` | 设置群信息 |
| 45 | `get_group_members_info(group_id, user_ids)` | 获取指定成员信息 |
| 46 | `dismiss_group(group_id)` | 解散群组 |
| 47 | `get_group_application_list()` | 获取入群申请 |
| 48 | `accept_group_application(group_id, user_id)` | 接受入群申请 |
| 49 | `refuse_group_application(group_id, user_id)` | 拒绝入群申请 |

#### 用户操作（3 个）

| # | FFI 方法 | 功能 |
|---|---------|------|
| 50 | `get_users_info(user_ids)` | 获取用户信息 |
| 51 | `update_user_profile(nickname, face_url, ex)` | 更新个人资料 |
| 52 | `get_user_status(user_ids)` | 获取在线状态 |

### 3.2 顶层函数（3 个）

| # | FFI 函数 | 功能 |
|---|---------|------|
| 1 | `init_logger(log_level: String)` | 初始化日志 |
| 2 | `set_log_directory(path: String)` | 设置日志目录 |
| 3 | `upload_file(file_path, file_name)` | 上传文件 |
| 4 | `upload_file_with_progress(file_path, file_name, sink)` | 带进度上传文件 |

---

## 4. 缺失的 FFI 函数

按优先级分类：

### P0 - 核心功能缺失

| Go SDK 函数 | 说明 |
|------------|------|
| `SetAppBackgroundStatus` | 前后台切换（影响消息接收） |
| `GetLoginStatus` | 查询登录状态 |
| `GetLoginUserID` | 获取当前登录用户 ID |
| `NetworkStatusChanged` | 网络状态变化通知 |
| `GetSelfUserInfo` | 获取自己的用户信息 |
| `MarkAllConversationMessageAsRead` | 全部标记已读 |
| `GetTotalUnreadMsgCount` | 获取总未读数 |

### P1 - 常用功能缺失

| Go SDK 函数 | 说明 |
|------------|------|
| `GetSpecifiedFriendsInfo` | 获取指定好友详情 |
| `SearchFriends` | 搜索好友 |
| `SearchGroups` | 搜索群组 |
| `SearchGroupMembers` | 搜索群成员 |
| `SearchConversation` | 搜索会话 |
| `GetConversationListSplit` | 分页获取会话列表 |
| `SetConversation` | 设置会话属性 |
| `HideConversation` | 隐藏会话 |
| `TypingStatusUpdate` | 输入状态更新 |
| `ChangeInputStates` | 输入状态变更 |
| `GetInputStates` | 获取输入状态 |
| `SubscribeUsersStatus` | 订阅用户在线状态 |
| `UnsubscribeUsersStatus` | 取消订阅 |
| `GetJoinedGroupListPage` | 分页获取群列表 |
| `GetGroupMemberOwnerAndAdmin` | 获取群主和管理员 |
| `ChangeGroupMute` | 群禁言 |
| `ChangeGroupMemberMute` | 群成员禁言 |
| `TransferGroupOwner` | 转让群主 |

### P2 - 扩展功能缺失

| Go SDK 函数 | 说明 |
|------------|------|
| `CreateQuoteMessage` | 创建引用消息 |
| `CreateCardMessage` | 创建名片消息 |
| `CreateMergerMessage` | 创建合并转发消息 |
| `CreateForwardMessage` | 创建转发消息 |
| `CreateFaceMessage` | 创建表情消息 |
| `CreateCustomMessage` | 创建自定义消息 |
| `CreateLocationMessage` | 创建位置消息 |
| `CreateTextAtMessage` | 创建 @消息 |
| `SetMessageLocalEx` | 设置消息本地扩展 |
| `InsertSingleMessageToLocalStorage` | 插入单聊消息到本地 |
| `InsertGroupMessageToLocalStorage` | 插入群聊消息到本地 |
| `DeleteAllMsgFromLocalAndSvr` | 删除所有消息（本地+服务端） |
| `ClearConversationAndDeleteAllMsg` | 清空会话消息 |
| `GetAdvancedHistoryMessageListReverse` | 反向获取历史消息 |
| `FindMessageList` | 查找消息列表 |
| `UpdateFcmToken` | 更新 FCM Token |
| `SetAppBadge` | 设置应用角标 |
| `UploadLogs` | 上传日志 |
| `SetGroupMemberInfo` | 设置群成员信息 |
| `GetGroupApplicationListAsApplicant` | 获取自己发起的入群申请 |

---

## 5. 事件流设计

### 5.1 EventStream 机制

Rust SDK 使用 `EventBus`（基于 `tokio::sync::broadcast`）统一管理所有事件，通过单一 `event_stream` 方法向 Dart 侧推送事件：

```rust
#[flutter_rust_bridge::frb]
pub async fn event_stream(&self, sink: StreamSink<SdkEvent>) -> Result<()> {
    let event_bus = self.inner.event_bus();
    tokio::spawn(async move {
        let mut subscription = event_bus.subscribe();
        while let Some(event) = subscription.next().await {
            let _ = sink.add(event);
        }
    });
    Ok(())
}
```

### 5.2 所有 SdkEvent 变体（42 个）

#### 连接事件（5 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `Connecting` | WebSocket 开始连接 | 无 |
| `Connected` | WebSocket 连接成功 | 无 |
| `Disconnected { reason }` | 连接断开 | 断开原因 |
| `ConnectFailed { error }` | 连接失败 | 错误信息 |
| `Reconnecting { attempt, max_attempts }` | 重连中 | 当前尝试次数/最大次数 |

#### 消息事件（6 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `PushMessage { req_identifier, data }` | 收到推送消息（原始数据） | 请求标识/数据 |
| `PushMessages { conversation_id, msgs, is_end, end_seq }` | 收到结构化推送消息 | 会话ID/消息列表/是否结束/结束seq |
| `PushNotificationMessages { conversation_id, msgs, is_end, end_seq }` | 收到通知消息推送 | 同上 |
| `NewMessage { message }` | 新消息入库 | ReceivedMessage |
| `MessageSent { client_msg_id, server_msg_id, ... }` | 消息发送成功 | 完整发送结果 |
| `MessageSendFailed { client_msg_id, error }` | 消息发送失败 | 客户端消息ID/错误 |

#### 消息操作事件（3 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `MessageRevoked { conversation_id, seq, client_msg_id }` | 消息被撤回 | 会话ID/序号/客户端消息ID |
| `MessagesDeleted { conversation_id, client_msg_ids }` | 消息被删除 | 会话ID/消息ID列表 |
| `RecvC2CReadReceipt { ... }` | C2C 已读回执 | (待完善) |

#### 同步事件（4 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `SyncStarted` | 同步开始 | 无 |
| `SyncProgress { progress, message }` | 同步进度 | 进度百分比/描述 |
| `SyncFinished` | 同步完成 | 无 |
| `SyncFailed { error }` | 同步失败 | 错误信息 |

#### 会话事件（4 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `ConversationChanged { conversations }` | 会话信息变化 | 会话列表 |
| `ConversationDeleted { conversation_ids }` | 会话被删除 | 会话ID列表 |
| `NewConversation { conversations }` | 新会话创建 | 会话列表 |
| `TotalUnreadCountChanged { count }` | 总未读数变化 | 新的未读总数 |

#### 好友事件（6 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `FriendApplicationAdded { application }` | 收到好友申请 | 申请信息 JSON |
| `FriendApplicationApproved { application }` | 好友申请被接受 | 申请信息 JSON |
| `FriendApplicationRejected { application }` | 好友申请被拒绝 | 申请信息 JSON |
| `FriendAdded { friends }` | 新好友添加 | 好友列表 |
| `FriendDeleted { friend_id }` | 好友被删除 | 好友用户ID |
| `FriendInfoUpdated { user_id }` | 好友信息更新 | 用户ID |

#### 黑名单事件（2 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `BlackAdded { user_id }` | 加入黑名单 | 用户ID |
| `BlackDeleted { black_id }` | 移出黑名单 | 黑名单用户ID |

#### 群组事件（11 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `GroupCreated { group_id }` | 加入新群 | 群组ID |
| `GroupInfoChanged { group_id }` | 群信息变更 | 群组ID |
| `GroupMemberAdded { group_id, member_ids }` | 群成员加入 | 群组ID/成员ID列表 |
| `GroupMemberDeleted { group_id, member_ids }` | 群成员被踢出 | 群组ID/成员ID列表 |
| `GroupApplicationAdded { application }` | 收到入群申请 | 申请信息 JSON |
| `GroupApplicationApproved { application }` | 入群申请被接受 | 申请信息 JSON |
| `GroupApplicationRejected { application }` | 入群申请被拒绝 | 申请信息 JSON |
| `GroupDismissed { group_id }` | 群被解散 | 群组ID |
| `GroupMuted { group_id }` | 群被全员禁言 | 群组ID |
| `GroupCancelMuted { group_id }` | 群取消全员禁言 | 群组ID |
| `GroupMemberInfoChanged { group_id, user_id }` | 群成员信息变更 | 群组ID/用户ID |

#### 群组扩展事件（4 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `GroupMemberMuted { group_id, user_id }` | 群成员被禁言 | 群组ID/用户ID |
| `GroupMemberCancelMuted { group_id, user_id }` | 群成员取消禁言 | 群组ID/用户ID |
| `GroupOwnerTransferred { group_id, new_owner_id }` | 群主转让 | 群组ID/新群主ID |

#### 用户事件（3 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `UserInfoUpdated { user }` | 自己信息更新 | UserInfo |
| `UserStatusChanged { user_id, status, platform_ids }` | 用户在线状态变化 | 用户ID/状态/平台列表 |

#### 连接安全事件（2 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `KickedOffline { reason }` | 被踢下线 | 原因 |
| `TokenExpired` | Token 过期 | 无 |

#### 生命周期事件（2 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `LoginSuccess { user_id }` | 登录成功 | 用户ID |
| `Logout` | 登出 | 无 |

#### 自定义事件（1 个）

| 变体 | 触发时机 | 字段 |
|------|---------|------|
| `CustomEvent { event_type, data }` | 自定义业务事件 | 事件类型/数据 |

---

## 6. 类型映射表

### 6.1 基础类型映射

| Rust 类型 | Dart 类型 | FRB 支持 | 说明 |
|-----------|-----------|---------|------|
| `String` | `String` | ✅ | UTF-8 字符串 |
| `i32` | `int` | ✅ | 32 位有符号整数 |
| `i64` | `BigInt` | ✅ | 64 位有符号整数 |
| `u32` | `int` | ✅ | 32 位无符号整数 |
| `bool` | `bool` | ✅ | 布尔值 |
| `f64` | `double` | ✅ | 64 位浮点数 |
| `Vec<T>` | `List<T>` | ✅ | 动态数组 |
| `Option<T>` | `T?` | ✅ | 可空类型 |
| `HashMap<K, V>` | `Map<K, V>` | ✅ | 键值对 |
| `Result<T>` | `Future<T>` (throws) | ✅ | 异步结果 |
| `StreamSink<T>` | `Stream<T>` | ✅ | 事件流 |

### 6.2 结构体映射

| Rust 结构体 | Dart 类型 | 说明 |
|------------|-----------|------|
| `ClientConfig` | `ClientConfig` | 客户端配置 |
| `OpenIMBridgeClient` | `OpenIMBridgeClient` | 桥接客户端（opaque） |
| `FriendApplyInfo` | `FriendApplyInfo` | 好友申请信息 |
| `GroupApplyInfo` | `GroupApplyInfo` | 群组申请信息 |
| `GetHistoryMessagesReq` | `GetHistoryMessagesReq` | 历史消息请求 |
| `GetHistoryMessagesResult` | `GetHistoryMessagesResult` | 历史消息结果 |
| `RevokeMessageReq` | `RevokeMessageReq` | 撤回消息请求 |
| `DeleteMessagesReq` | `DeleteMessagesReq` | 删除消息请求 |
| `MarkMessagesAsReadReq` | `MarkMessagesAsReadReq` | 标记已读请求 |
| `SearchMessagesReq` | `SearchMessagesReq` | 搜索消息请求 |
| `SdkEvent` | `SdkEvent` | SDK 事件枚举 |
| `ReceivedMessage` | `ReceivedMessage` | 接收到的消息 |
| `MessageInfo` | `MessageInfo` | 消息信息 |
| `Conversation` | `Conversation` | 会话信息 |
| `FriendInfo` | `FriendInfo` | 好友信息 |
| `GroupInfo` | `GroupInfo` | 群组信息 |
| `GroupMember` | `GroupMember` | 群成员信息 |
| `UserInfo` | `UserInfo` | 用户信息 |
| `OnlineStatus` | `OnlineStatus` | 在线状态 |
| `LocalChatLog` | `LocalChatLog` | 本地聊天记录 |
| `LocalConversation` | `LocalConversation` | 本地会话 |

### 6.3 枚举映射

| Rust 枚举 | Dart 类型 | 说明 |
|-----------|-----------|------|
| `SessionType` | `SessionType` | 会话类型（1:C2C, 2:Group） |
| `ContentType` | `ContentType` | 消息内容类型 |
| `MessageSendStatus` | `int` | 消息发送状态 |
| `GroupType` | `GroupType` | 群组类型 |
| `SdkEvent` | `SdkEvent` | SDK 事件 |
