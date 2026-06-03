# 06 - 通知系统详细设计

> **参考实现**: `../openim-sdk-core/internal/conversation_msg/notification.go` + `internal/relation/notification.go` + `internal/group/notification.go` + `internal/user/notification.go`
> **协议定义**: `../protocol/sdkws/`, `../protocol/constant/`
> **状态**: 本文档为 Rust SDK 重写参考规格

---

## 1. 模块职责

通知系统是 IM SDK 的**事件分发核心**，负责：

| 职责 | 说明 |
|------|------|
| **命令分发** | `Work()` 方法根据 Cmd 类型分发到不同处理器 |
| **通知路由** | 按 ContentType 范围将通知分发到 relation/group/user/conversation 模块 |
| **同步标志处理** | 处理 MsgSyncBegin/End、AppDataSyncStart/Finish 等同步状态标志 |
| **会话更新分发** | `doUpdateConversation()` 根据 Action 类型执行不同更新逻辑 |
| **消息更新分发** | `doUpdateMessage()` 处理消息头像/昵称更新 |
| **通知去重** | `NotificationFilter` 基于 UUID + LRU 的去重机制 |

---

## 2. 通知路由架构

### 2.1 整体数据流

```
WebSocket Push → MsgSyncer
  → MsgSyncer.C 频道
    → Conversation.Work(c2v)
```

### 2.2 Work() 命令路由

```
Work(c2v Cmd2Value):
  switch c2v.Cmd:
  ├── CmdNewMsgCome         → doMsgNew(c2v)           // 新消息到达
  ├── CmdUpdateConversation → doUpdateConversation(c2v) // 会话更新
  ├── CmdUpdateMessage      → doUpdateMessage(c2v)     // 消息更新
  ├── CmdNotification       → doNotificationManager(c2v) // 通知管理
  ├── CmdSyncData           → syncData(c2v)            // 数据同步
  ├── CmdSyncFlag           → syncFlag(c2v)            // 同步标志
  └── CmdMsgSyncInReinstall → doMsgSyncByReinstalled(c2v) // 重装同步
```

### 2.3 通知分发路由 (doNotificationManager)

```
doNotificationManager(c2v):
  遍历所有会话的通知消息:
    for each msg:
      ┌─────────────────────────────────────────────────────────┐
      │  ContentType 范围判断                                    │
      ├─────────────────────────────────────────────────────────┤
      │  1200-1299 (FriendNotification)                         │
      │    → relation.DoNotification(ctx, msg)                  │
      │                                                         │
      │  1301-1399 (UserNotification)                           │
      │    → user.DoNotification(ctx, msg)                      │
      │                                                         │
      │  1500-1599 (GroupNotification)                          │
      │    → group.DoNotification(ctx, msg)                     │
      │                                                         │
      │  其他                                                    │
      │    → conversation.DoNotification(ctx, msg)              │
      └─────────────────────────────────────────────────────────┘
    最后更新通知 Seq:
      db.SetNotificationSeq(conversationID, lastMsg.Seq)
```

---

## 3. 好友通知 (1200-1299)

### 3.1 完整路由表

| ContentType | 值 | Tips 类型 | 动作 | 说明 |
|-------------|-----|-----------|------|------|
| `FriendApplicationApprovedNotification` | 1201 | `FriendApplicationApprovedTips` | 触发 `OnFriendApplicationAccepted` + `IncrSyncFriends` | 好友申请被接受 |
| `FriendApplicationRejectedNotification` | 1202 | `FriendApplicationRejectedTips` | 触发 `OnFriendApplicationRejected` | 好友申请被拒绝 |
| `FriendApplicationNotification` | 1203 | `FriendApplicationTips` | 触发 `OnFriendApplicationAdded` | 收到好友申请 |
| `FriendAddedNotification` | 1204 | `FriendAddedTips` | `IncrSyncFriends` | 新好友添加 |
| `FriendDeletedNotification` | 1205 | `FriendDeletedTips` | `IncrSyncFriends` | 好友删除 |
| `FriendRemarkSetNotification` | 1206 | `FriendInfoChangedTips` | `IncrSyncFriends` | 好友备注设置 |
| `BlackAddedNotification` | 1207 | `BlackAddedTips` | `SyncAllBlackList` | 加入黑名单 |
| `BlackDeletedNotification` | 1208 | `BlackDeletedTips` | `SyncAllBlackList` | 移出黑名单 |
| `FriendInfoUpdatedNotification` | 1209 | `UserInfoUpdatedTips` | `IncrSyncFriends` | 单个好友信息更新 |
| `FriendsInfoUpdateNotification` | 1210 | `FriendsInfoUpdateTips` | `IncrSyncFriends` | 多个好友信息更新 |

### 3.2 处理逻辑

```rust
// Rust 伪代码
async fn do_notification(&self, msg: &MsgData) -> Result<()> {
    // 获取关系同步锁
    self.relation_sync_mutex.lock().await;

    match msg.content_type {
        // 1203 - 收到好友申请
        1203 => {
            let tips: FriendApplicationTips = deserialize(msg.content)?;
            self.friendship_listener.on_friend_application_added(
                server_to_local_friend_request(tips.request)
            );
        }

        // 1201 - 好友申请被接受
        1201 => {
            let tips: FriendApplicationApprovedTips = deserialize(msg.content)?;
            if let Some(req) = tips.request {
                self.friendship_listener.on_friend_application_accepted(
                    server_to_local_friend_request(req)
                );
            }
            self.relation.incr_sync_friends().await?;
        }

        // 1202 - 好友申请被拒绝
        1202 => {
            let tips: FriendApplicationRejectedTips = deserialize(msg.content)?;
            self.friendship_listener.on_friend_application_rejected(
                server_to_local_friend_request(tips.request)
            );
        }

        // 1204 - 新好友添加
        1204 => {
            let tips: FriendAddedTips = deserialize(msg.content)?;
            if let Some(friend) = &tips.friend {
                // 只有与自己相关的好友变更才同步
                if friend.friend_user.user_id == self.login_user_id
                    || friend.owner_user_id == self.login_user_id {
                    self.relation.incr_sync_friends().await?;
                }
            }
        }

        // 1205 - 好友删除
        1205 => {
            let tips: FriendDeletedTips = deserialize(msg.content)?;
            if let Some(ids) = &tips.from_to_user_id {
                if ids.from_user_id == self.login_user_id {
                    self.relation.incr_sync_friends().await?;
                }
            }
        }

        // 1206 - 好友备注设置
        1206 => {
            let tips: FriendInfoChangedTips = deserialize(msg.content)?;
            if let Some(ids) = &tips.from_to_user_id {
                if ids.from_user_id == self.login_user_id {
                    self.relation.incr_sync_friends().await?;
                }
            }
        }

        // 1209 - 好友信息更新（非自己）
        1209 => {
            let tips: UserInfoUpdatedTips = deserialize(msg.content)?;
            if tips.user_id != self.login_user_id {
                self.relation.incr_sync_friends().await?;
            }
        }

        // 1210 - 多个好友信息更新
        1210 => {
            let tips: FriendsInfoUpdateTips = deserialize(msg.content)?;
            if tips.from_to_user_id.to_user_id == self.login_user_id {
                self.relation.incr_sync_friends().await?;
            }
        }

        // 1207 - 加入黑名单
        1207 => {
            let tips: BlackAddedTips = deserialize(msg.content)?;
            if tips.from_to_user_id.from_user_id == self.login_user_id {
                self.relation.sync_all_black_list().await?;
            }
        }

        // 1208 - 移出黑名单
        1208 => {
            let tips: BlackDeletedTips = deserialize(msg.content)?;
            if tips.from_to_user_id.from_user_id == self.login_user_id {
                self.relation.sync_all_black_list().await?;
            }
        }

        _ => return Err(anyhow!("unknown friend notification type: {}", msg.content_type))
    }
    Ok(())
}
```

### 3.3 关键注意事项

1. **互斥锁**: 所有好友通知处理前需要获取 `relationSyncMutex`，避免并发冲突
2. **用户过滤**: 多数通知需要检查 `loginUserID` 是否与通知相关
3. **自动同步**: 大多数通知触发 `IncrSyncFriends` 进行增量同步
4. **黑名单通知**: 触发 `SyncAllBlackList` 全量同步黑名单

---

## 4. 用户通知 (1301-1399)

### 4.1 完整路由表

| ContentType | 值 | Tips 类型 | 动作 | 说明 |
|-------------|-----|-----------|------|------|
| `UserInfoUpdatedNotification` | 1303 | `UserInfoUpdatedTips` | 如果是自己: `SyncLoginUserInfo`; 否则: 忽略 | 用户信息更新 |
| `UserStatusChangeNotification` | 1304 | — | 未实现 | 用户状态变更 |
| `UserCommandAddNotification` | 1305 | — | 未实现 | 用户命令添加 |
| `UserCommandDeleteNotification` | 1306 | — | 未实现 | 用户命令删除 |
| `UserCommandUpdateNotification` | 1307 | — | 未实现 | 用户命令更新 |

### 4.2 处理逻辑

```rust
async fn do_notification(&self, msg: &MsgData) -> Result<()> {
    match msg.content_type {
        1303 => { // UserInfoUpdatedNotification
            let tips: UserInfoUpdatedTips = deserialize(msg.content)?;
            if tips.user_id == self.login_user_id {
                self.sync_login_user_info().await?;
            }
            // 其他用户的信息更新 → 忽略（不是自己的）
        }
        _ => return Err(anyhow!("unknown user notification type: {}", msg.content_type))
    }
    Ok(())
}
```

---

## 5. 群组通知 (1500-1599)

### 5.1 完整路由表

| ContentType | 值 | Tips 类型 | 动作 | 需要锁 |
|-------------|-----|-----------|------|--------|
| `GroupCreatedNotification` | 1501 | `GroupCreatedTips` | `IncrSyncJoinGroup` + `IncrSyncGroupAndMember` | ✅ |
| `GroupInfoSetNotification` | 1502 | `GroupInfoSetTips` | `onlineSyncGroupAndMember` | ✅ |
| `JoinGroupApplicationNotification` | 1503 | `JoinGroupApplicationTips` | 触发 `OnGroupApplicationAdded` + 去重检查 | ❌ (filter) |
| `MemberQuitNotification` | 1504 | `MemberQuitTips` | 自己退出: `IncrSyncJoinGroup`; 否则: `onlineSyncGroupAndMember` | ✅ |
| `GroupApplicationAcceptedNotification` | 1505 | `GroupApplicationAcceptedTips` | 触发 `OnGroupApplicationAccepted` + 去重检查 | ❌ (filter) |
| `GroupApplicationRejectedNotification` | 1506 | `GroupApplicationRejectedTips` | 触发 `OnGroupApplicationRejected` + 去重检查 | ❌ (filter) |
| `GroupOwnerTransferredNotification` | 1507 | `GroupOwnerTransferredTips` | `onlineSyncGroupAndMember` (含新旧群主) | ✅ |
| `MemberKickedNotification` | 1508 | `MemberKickedTips` | 自己被踢: `IncrSyncJoinGroup`; 否则: `onlineSyncGroupAndMember` | ✅ |
| `MemberInvitedNotification` | 1509 | `MemberInvitedTips` | 自己被邀请: `IncrSyncJoinGroup` + `IncrSyncGroupAndMember`; 否则: `onlineSyncGroupAndMember` | ✅ |
| `MemberEnterNotification` | 1510 | `MemberEnterTips` | 自己进入: `IncrSyncJoinGroup` + `IncrSyncGroupAndMember`; 否则: `onlineSyncGroupAndMember` | ✅ |
| `GroupDismissedNotification` | 1511 | `GroupDismissedTips` | 触发 `OnGroupDismissed` + `IncrSyncJoinGroup` | ✅ |
| `GroupMemberMutedNotification` | 1512 | `GroupMemberMutedTips` | `onlineSyncGroupAndMember` | ✅ |
| `GroupMemberCancelMutedNotification` | 1513 | `GroupMemberCancelMutedTips` | `onlineSyncGroupAndMember` | ✅ |
| `GroupMutedNotification` | 1514 | `GroupMutedTips` | `onlineSyncGroupAndMember` | ✅ |
| `GroupCancelMutedNotification` | 1515 | `GroupCancelMutedTips` | `onlineSyncGroupAndMember` | ✅ |
| `GroupMemberInfoSetNotification` | 1516 | `GroupMemberInfoSetTips` | `onlineSyncGroupAndMember` | ✅ |
| `GroupMemberSetToAdminNotification` | 1517 | `GroupMemberInfoSetTips` | `onlineSyncGroupAndMember` | ✅ |
| `GroupMemberSetToOrdinaryUserNotification` | 1518 | `GroupMemberInfoSetTips` | `onlineSyncGroupAndMember` | ✅ |
| `GroupInfoSetAnnouncementNotification` | 1519 | `GroupInfoSetAnnouncementTips` | `onlineSyncGroupAndMember` | ✅ |
| `GroupInfoSetNameNotification` | 1520 | `GroupInfoSetNameTips` | `onlineSyncGroupAndMember` | ✅ |

### 5.2 通知分类

群组通知分为两大类：

**A. 需要锁的通知 (1501, 1502, 1504, 1507-1520)**

这些通知需要获取 `groupSyncMutex` 锁，涉及数据同步：

```rust
async fn do_notification(&self, msg: &MsgData) -> Result<()> {
    match msg.content_type {
        // 1501 - 群组创建
        1501 => {
            let tips: GroupCreatedTips = deserialize(msg.content)?;
            self.incr_sync_join_group().await?;
            self.incr_sync_group_and_member(&tips.group.group_id).await?;
        }

        // 1502 - 群信息设置
        1502 => {
            let tips: GroupInfoSetTips = deserialize(msg.content)?;
            self.online_sync_group_and_member(
                &tips.group.group_id,
                None, None, None,
                Some(tips.group),
                GroupSortIDUnchanged,
                tips.group_member_version,
                tips.group_member_version_id,
            ).await?;
        }

        // 1504 - 成员退出
        1504 => {
            let tips: MemberQuitTips = deserialize(msg.content)?;
            if tips.quit_user.user_id == self.login_user_id {
                self.incr_sync_join_group().await?;
            } else {
                self.online_sync_group_and_member(
                    &tips.group.group_id,
                    Some(vec![tips.quit_user]),
                    None, None,
                    Some(tips.group),
                    GroupSortIDUnchanged,
                    tips.group_member_version,
                    tips.group_member_version_id,
                ).await?;
            }
        }

        // 1507 - 群主转移
        1507 => {
            let tips: GroupOwnerTransferredTips = deserialize(msg.content)?;
            self.online_sync_group_and_member(
                &tips.group.group_id,
                None,
                Some(vec![tips.new_group_owner, tips.old_group_owner_info]),
                None,
                Some(tips.group),
                GroupSortIDChanged,  // 注意：排序变化
                tips.group_member_version,
                tips.group_member_version_id,
            ).await?;
        }

        // ... 其他通知类型
        _ => return Err(anyhow!("unknown group notification type: {}", msg.content_type))
    }
    Ok(())
}
```

**B. 需要去重的通知 (1503, 1505, 1506)**

这些通知使用 `NotificationFilter` 去重，不需要锁：

```rust
// 1503 - 加入群组申请
1503 => {
    let tips: JoinGroupApplicationTips = deserialize(msg.content)?;
    if self.filter.should_execute(&tips.uuid) {
        self.listener.on_group_application_added(
            serialize(server_to_local_group_request(tips.group, tips.request))
        );
    }
}

// 1505 - 群组申请被接受
1505 => {
    let tips: GroupApplicationAcceptedTips = deserialize(msg.content)?;
    if self.filter.should_execute(&tips.uuid) {
        self.listener.on_group_application_accepted(
            serialize(server_to_local_group_request(tips.group, tips.request))
        );
    }
}

// 1506 - 群组申请被拒绝
1506 => {
    let tips: GroupApplicationRejectedTips = deserialize(msg.content)?;
    if self.filter.should_execute(&tips.uuid) {
        self.listener.on_group_application_rejected(
            serialize(server_to_local_group_request(tips.group, tips.request))
        );
    }
}
```

### 5.3 onlineSyncGroupAndMember 参数说明

```rust
async fn online_sync_group_and_member(
    &self,
    group_id: &str,
    kicked_users: Option<Vec<GroupMemberFullInfo>>,  // 被移除的成员
    updated_users: Option<Vec<GroupMemberFullInfo>>, // 变更的成员
    invited_users: Option<Vec<GroupMemberFullInfo>>, // 被邀请的成员
    group_info: Option<GroupFullInfo>,               // 群组信息变更
    group_sort_version: i32,                         // 排序版本变化
    member_version: u64,                             // 成员版本号
    member_version_id: String,                       // 成员版本 ID
) -> Result<()>;
```

---

## 6. 会话通知（其他范围）

### 6.1 完整路由表

| ContentType | 值 | Tips 类型 | 动作 | 说明 |
|-------------|-----|-----------|------|------|
| `ConversationChangeNotification` | 1300 | `ConversationUpdateTips` | `IncrSyncConversations` | 会话属性变更 |
| `ConversationPrivateChatNotification` | 1701 | `ConversationSetPrivateTips` | `IncrSyncConversations` | 会话私密聊天设置变更 |
| `ClearConversationNotification` | 1703 | `ClearConversationTips` | `doClearConversations` | 清空会话消息 |
| `BusinessNotification` | 2001 | `NotificationElem` | `OnRecvCustomBusinessMessage` | 自定义业务消息 |
| `RevokeNotification` | 2101 | `RevokeMsgTips` | `doRevokeMsg` | 消息撤回 |
| `DeleteMsgsNotification` | 2102 | `DeleteMsgsTips` | `doDeleteMsgs` | 消息删除 |
| `HasReadReceipt` | 2200 | `MarkAsReadTips` | `doReadDrawing` | 已读回执 |

### 6.2 处理逻辑

```rust
async fn do_notification(&self, msg: &MsgData) -> Result<()> {
    match msg.content_type {
        // 1300 - 会话变更通知
        1300 => {
            // _tips: ConversationUpdateTips = deserialize(msg.content)?;
            self.conversation_sync_mutex.lock().await;
            self.incr_sync_conversations().await?;
        }

        // 1701 - 私聊设置变更
        1701 => {
            // _tips: ConversationSetPrivateTips = deserialize(msg.content)?;
            self.conversation_sync_mutex.lock().await;
            self.incr_sync_conversations().await?;
        }

        // 1703 - 清空会话
        1703 => {
            let tips: ClearConversationTips = deserialize(msg.content)?;
            for conversation_id in &tips.conversation_ids {
                self.clear_conversation_and_delete_all_msg(conversation_id, false, |cid| {
                    self.db.clear_conversation(cid)
                }).await?;
            }
            self.do_update_conversation(ConChange, tips.conversation_ids);
            self.do_update_conversation(TotalUnreadMessageChanged);
        }

        // 2001 - 自定义业务消息
        2001 => {
            let notification: NotificationElem = deserialize(msg.content)?;
            self.business_listener.on_recv_custom_business_message(notification.detail);
        }

        // 2101 - 消息撤回
        2101 => {
            self.do_revoke_msg(msg).await?;
        }

        // 2102 - 消息删除
        2102 => {
            self.do_delete_msgs(msg).await?;
        }

        // 2200 - 已读回执
        2200 => {
            self.do_read_drawing(msg).await?;
        }

        _ => return Err(anyhow!("unknown conversation notification type: {}", msg.content_type))
    }
    Ok(())
}
```

---

## 7. syncFlag 同步标志处理

### 7.1 标志常量

| 标志 | 值 | 说明 |
|------|-----|------|
| `MsgSyncBegin` | 1001 | 消息同步开始 |
| `MsgSyncProcessing` | 1002 | 消息同步进行中 |
| `MsgSyncEnd` | 1003 | 消息同步结束 |
| `MsgSyncFailed` | 1004 | 消息同步失败 |
| `AppDataSyncStart` | 1005 | 应用数据同步开始 |
| `AppDataSyncFinish` | 1006 | 应用数据同步完成 |

### 7.2 处理流程

```rust
async fn sync_flag(&self, c2v: Cmd2Value) -> Result<()> {
    let sync_flag = c2v.value.sync_flag;

    match sync_flag {
        // 1005 - 应用数据同步开始
        AppDataSyncStart => {
            self.conversation_listener.on_sync_server_start(true);
            self.conversation_listener.on_sync_server_progress(1);

            // 阶段 1: 异步等待 — 并发同步群组和好友
            tokio::join!(
                self.group.sync_all_joined_groups_and_members(),
                self.relation.incr_sync_friends(),
            );
            self.add_init_progress(4); // +40% of InitSyncProgress
            self.conversation_listener.on_sync_server_progress(self.progress);

            // 阶段 2: 同步等待 — 顺序同步会话和已读 Seq
            self.incr_sync_conversations().await?;
            self.sync_all_conversation_hash_read_seqs().await?;
            self.add_init_progress(6); // +60% of InitSyncProgress
            self.conversation_listener.on_sync_server_progress(self.progress);

            // 阶段 3: 异步不等待 — 后台同步用户信息和黑名单
            tokio::spawn(self.user.sync_login_user_info_without_notice());
            tokio::spawn(self.relation.sync_all_black_list_without_notice());
        }

        // 1006 - 应用数据同步完成
        AppDataSyncFinish => {
            self.progress = 100;
            self.conversation_listener.on_sync_server_progress(100);
            self.conversation_listener.on_sync_server_finish(true);
        }

        // 1001 - 消息同步开始
        MsgSyncBegin => {
            self.conversation_listener.on_sync_server_start(false);
            self.sync_data(c2v).await;
        }

        // 1003 - 消息同步结束
        MsgSyncEnd => {
            self.conversation_listener.on_sync_server_finish(false);
        }

        // 1004 - 消息同步失败
        MsgSyncFailed => {
            self.conversation_listener.on_sync_server_failed(false);
        }

        _ => {}
    }
    Ok(())
}
```

### 7.3 syncData（数据同步）

```rust
async fn sync_data(&self, _c2v: Cmd2Value) {
    self.conversation_sync_mutex.lock().await;

    // 同步执行
    self.sync_all_conversation_hash_read_seqs().await;

    // 异步不等待
    tokio::spawn(self.user.sync_login_user_info());
    tokio::spawn(self.relation.sync_all_black_list());
    tokio::spawn(self.group.sync_all_joined_groups_and_members());
    tokio::spawn(self.relation.incr_sync_friends());
    tokio::spawn(self.incr_sync_conversations());
}
```

### 7.4 InitSyncProgress 进度管理

```
总进度范围: 10% (InitSyncProgress)
分配:
  AppDataSyncStart:
    阶段 1 (asyncWait): +40% of InitSyncProgress = 4%
    阶段 2 (syncWait):  +60% of InitSyncProgress = 6%
  AppDataSyncFinish:
    强制设置为 100%

同步函数执行模式:
  syncWait    — 顺序执行，等待完成
  asyncWait   — 并发执行，等待全部完成
  asyncNoWait — 并发执行，不等待
```

---

## 8. 会话更新分发 (doUpdateConversation)

### 8.1 Action 类型路由

```rust
async fn do_update_conversation(&self, c2v: Cmd2Value) {
    let node = c2v.value;

    match node.action {
        // 1 - 新增或更新最新消息
        AddConOrUpLatMsg => {
            let lc: LocalConversation = node.args;
            match self.db.get_conversation(&lc.conversation_id) {
                Ok(existing) => {
                    // 如果新消息更新或 clientMsgID 相同 → 更新
                    if lc.latest_msg_send_time >= existing.latest_msg_send_time
                        || get_latest_msg_client_id(&lc.latest_msg) == get_latest_msg_client_id(&existing.latest_msg)
                    {
                        self.db.update_columns_conversation(&node.con_id, /* latest_msg 字段 */)?;
                        self.conversation_listener.on_conversation_changed(serialize(vec![existing]));
                    }
                }
                Err(_) => {
                    // 会话不存在 → 插入新会话
                    self.db.insert_conversation(&lc)?;
                    self.conversation_listener.on_new_conversation(serialize(vec![lc]));
                }
            }
        }

        // 2 - 未读总数变更
        TotalUnreadMessageChanged => {
            let count = self.db.get_total_unread_msg_count()?;
            self.conversation_listener.on_total_unread_message_count_changed(count);
        }

        // 3 - 更新会话头像和昵称
        UpdateConFaceUrlAndNickName => {
            let st: SourceIDAndSessionType = node.args;
            // 根据 SessionType 构建 conversationID
            // 更新 FaceURL 和 ShowName
            self.db.update_conversation(&lc)?;
        }

        // 4 - 更新最新消息已读状态
        UpdateLatestMessageReadState => {
            let conversation_id = node.con_id;
            let mut latest_msg = deserialize(self.db.get_conversation(&conversation_id)?.latest_msg)?;
            latest_msg.is_read = true;
            self.db.update_columns_conversation(&conversation_id, /* latest_msg 字段 */)?;
        }

        // 5 - 更新最新消息头像和昵称
        UpdateLatestMessageFaceUrlAndNickName => {
            let args: UpdateMessageInfo = node.args;
            // 如果最新消息的 SendID == 变更的 UserID → 更新
        }

        // 6 - 会话变更（通用）
        ConChange => {
            let conversation_ids: Vec<String> = node.args;
            let conversations = self.db.get_multiple_conversations(&conversation_ids)?;
            let valid: Vec<_> = conversations.into_iter()
                .filter(|c| c.latest_msg_send_time != 0)
                .collect();
            self.conversation_listener.on_conversation_changed(serialize(valid));
        }

        // 7 - 新会话（通用）
        NewCon => {
            let cid_list: Vec<String> = node.args;
            let c_lists = self.db.get_multiple_conversations(&cid_list)?;
            self.conversation_listener.on_new_conversation(serialize(c_lists));
        }

        // 8 - 会话变更（直接传 JSON）
        ConChangeDirect => {
            let json: String = node.args;
            self.conversation_listener.on_conversation_changed(json);
        }

        // 9 - 新会话（直接传 JSON）
        NewConDirect => {
            let json: String = node.args;
            self.conversation_listener.on_new_conversation(json);
        }
    }
}
```

### 8.2 Action 常量定义

| Action | 值 | 说明 |
|--------|-----|------|
| `AddConOrUpLatMsg` | 1 | 新增会话或更新最新消息 |
| `TotalUnreadMessageChanged` | 2 | 未读总数变更 |
| `UpdateConFaceUrlAndNickName` | 3 | 更新会话头像和昵称 |
| `UpdateLatestMessageReadState` | 4 | 更新最新消息已读状态 |
| `UpdateLatestMessageFaceUrlAndNickName` | 5 | 更新最新消息头像和昵称 |
| `ConChange` | 6 | 会话变更（通用） |
| `NewCon` | 7 | 新会话（通用） |
| `ConChangeDirect` | 8 | 会话变更（直接 JSON） |
| `NewConDirect` | 9 | 新会话（直接 JSON） |
| `UpdateMsgFaceUrlAndNickName` | 10 | 更新消息头像和昵称 |

---

## 9. 消息更新分发 (doUpdateMessage)

```rust
async fn do_update_message(&self, c2v: Cmd2Value) {
    let node = c2v.value;

    match node.action {
        UpdateMsgFaceUrlAndNickName => {
            let args: UpdateMessageInfo = node.args;

            match args.session_type {
                SingleChatType => {
                    if args.user_id == self.login_user_id {
                        // 自己信息变更 → 更新所有单聊会话中的消息
                        let all_single_cids = self.db.get_all_single_conversation_id_list()?;
                        for cid in all_single_cids {
                            self.db.update_msg_sender_face_url_and_nickname(
                                &cid, &args.user_id, &args.face_url, &args.nickname
                            )?;
                        }
                    } else {
                        // 对方信息变更 → 只更新该会话
                        let cid = self.get_conversation_id_by_session_type(&args.user_id, SingleChatType);
                        self.db.update_msg_sender_face_url_and_nickname(&cid, &args.user_id, &args.face_url, &args.nickname)?;
                    }
                }

                ReadGroupChatType => {
                    let cid = self.get_conversation_id_by_session_type(&args.group_id, ReadGroupChatType);
                    self.db.update_msg_sender_face_url_and_nickname(&cid, &args.user_id, &args.face_url, &args.nickname)?;
                }

                NotificationChatType => {
                    let cid = self.get_conversation_id_by_session_type(&args.user_id, NotificationChatType);
                    self.db.update_msg_sender_face_url_and_nickname(&cid, &args.user_id, &args.face_url, &args.nickname)?;
                }
            }
        }
    }
}
```

---

## 10. NotificationFilter 去重机制

### 10.1 数据结构

```go
type NotificationFilter struct {
    lock    sync.Mutex
    data    *simplelru.LRU[string, time.Time]  // UUID → 上次处理时间
    timeout time.Duration                       // 去重超时时间
}
```

### 10.2 核心方法

| 方法 | 签名 | 说明 |
|------|------|------|
| `NewNotificationFilter` | `(size int, timeout time.Duration)` | 创建过滤器，指定 LRU 容量和超时时间 |
| `ShouldExecute` | `(uuid string) → bool` | UUID 在超时时间内未处理过 → true，同时记录当前时间 |
| `ExecuteIfNew` | `(uuid string, fn func())` | 如果 ShouldExecute 为 true → 执行 fn |

### 10.3 使用场景

仅用于群组通知中的 1503/1505/1506：

```
1503 (JoinGroupApplicationNotification)    → filter.ShouldExecute(tips.uuid)
1505 (GroupApplicationAcceptedNotification) → filter.ShouldExecute(tips.uuid)
1506 (GroupApplicationRejectedNotification) → filter.ShouldExecute(tips.uuid)
```

### 10.4 Rust 实现

```rust
use lru::LruCache;
use std::time::{Duration, Instant};

pub struct NotificationFilter {
    lock: tokio::sync::Mutex<()>,
    data: LruCache<String, Instant>,
    timeout: Duration,
}

impl NotificationFilter {
    pub fn new(size: usize, timeout: Duration) -> Self {
        Self {
            lock: tokio::sync::Mutex::new(()),
            data: LruCache::new(size),
            timeout,
        }
    }

    pub async fn should_execute(&self, uuid: &str) -> bool {
        let mut guard = self.lock.lock().await;
        let now = Instant::now();

        if let Some(&last_time) = self.data.get(uuid) {
            if now.duration_since(last_time) <= self.timeout {
                return false;
            }
        }

        self.data.put(uuid.to_string(), now);
        true
    }

    pub async fn execute_if_new<F: FnOnce()>(&self, uuid: &str, f: F) {
        if self.should_execute(uuid).await {
            f();
        }
    }
}
```

---

## 11. SyncAllConversationHashReadSeqs

### 11.1 功能说明

在消息同步开始时，从服务端获取所有会话的 HasReadSeq 和 MaxSeq，更新本地未读计数。

### 11.2 流程

```
1. 调用服务端 GetConversationsHasReadAndMaxSeq
   → 返回 HashMap<conversationID, {MaxSeq, HasReadSeq}>

2. 获取本地所有会话

3. 遍历服务端返回的 seqs:
   a. 更新 MaxSeqRecorder
   b. 计算 unreadCount = MaxSeq - HasReadSeq
   c. 如果本地会话存在且 UnreadCount 不同 → 更新 DB + 记录 conversationChangedIDs
   d. 如果本地会话不存在 → 记录 conversationIDsNeedSync

4. 对于不存在的会话:
   a. 调用 getConversationsByIDsFromServer 获取会话信息
   b. batchAddFaceURLAndName 补全显示名称
   c. 批量插入 DB

5. 触发 ConChange 和 TotalUnreadMessageChanged 事件
```

---

## 12. Rust 当前实现对比

### 12.1 已实现

| 功能 | Go SDK | Rust 当前状态 | 完成度 |
|------|--------|--------------|--------|
| EventBus 事件总线 | ✅ (Cmd2Value Channel) | ✅ `domain/event/bus.rs` | 100% |
| SdkEvent 枚举 | ✅ | ✅ `domain/event/types.rs` | 基本定义 |
| 会话变更事件 | ✅ | ✅ `SdkEvent::ConversationChanged` | 100% |
| 会话删除事件 | ✅ | ✅ `SdkEvent::ConversationDeleted` | 100% |
| 同步事件 | ✅ | ✅ `SdkEvent::SyncStarted/Finished/Failed` | 100% |
| 未读计数事件 | ✅ | ✅ `SdkEvent::TotalUnreadCountChanged` | 100% |

### 12.2 未实现/待完善

| 功能 | Go SDK | Rust 当前状态 | 优先级 |
|------|--------|--------------|--------|
| **Work() 命令路由** | ✅ 完整分发 | ❌ 未实现 | **P0** |
| **doNotificationManager** | ✅ 通知分发 | ❌ 未实现 | **P0** |
| **好友通知处理 (1200-1299)** | ✅ 完整实现 | ❌ 未实现 | **P0** |
| **用户通知处理 (1301-1399)** | ✅ 完整实现 | ❌ 未实现 | **P1** |
| **群组通知处理 (1500-1599)** | ✅ 完整实现（20种） | ❌ 未实现 | **P0** |
| **会话通知处理** | ✅ 完整实现 | ❌ 未实现 | **P0** |
| **syncFlag 处理** | ✅ 完整实现 | ❌ 未实现 | **P0** |
| **doUpdateConversation** | ✅ 9种 Action | ❌ 未实现 | **P0** |
| **doUpdateMessage** | ✅ 头像/昵称更新 | ❌ 未实现 | **P1** |
| **syncData** | ✅ 并发同步 | ❌ 未实现 | **P0** |
| **SyncAllConversationHashReadSeqs** | ✅ 完整实现 | ❌ 未实现 | **P1** |
| **NotificationFilter** | ✅ LRU + 超时 | ❌ 未实现 | **P1** |
| **InitSyncProgress** | ✅ 进度管理 | ❌ 未实现 | **P1** |
| **ConversationListener 回调** | ✅ OnConversationChanged 等 | ❌ 未实现 | **P0** |
| **MsgListener 回调** | ✅ OnRecvNewMessage 等 | ❌ 未实现 | **P0** |

### 12.3 差距分析

1. **缺少命令分发层**: Rust 事件总线只有 EventBus 发布/订阅，缺少 Go SDK 的 `Work()` + `Cmd2Value` 分发模式
2. **缺少通知路由**: 没有按 ContentType 范围分发到各模块的机制
3. **缺少 Listener 回调体系**: 没有 `OnConversationListener`、`OnAdvancedMsgListener` 等回调接口
4. **缺少同步标志处理**: 没有 MsgSyncBegin/End、AppDataSyncStart/Finish 的处理
5. **缺少会话更新分发**: 没有 `doUpdateConversation` 的 9 种 Action 处理

---

## 13. Rust 重写建议

### 13.1 架构建议

```
rust/src/core/conversation/
├── mod.rs
├── manager.rs       # 会话 CRUD
├── syncer.rs        # 会话同步
├── notification.rs  # 通知路由和处理 ← 新增
├── work.rs          # Work() 命令分发 ← 新增
└── update.rs        # 会话/消息更新分发 ← 新增

rust/src/core/relation/
├── notification.rs  # 好友通知处理 ← 新增

rust/src/core/group/
├── notification.rs  # 群组通知处理 ← 新增

rust/src/core/user/
├── notification.rs  # 用户通知处理 ← 新增

rust/src/domain/event/
├── types.rs         # 扩展 SdkEvent 枚举
└── listener.rs      # Listener 回调定义 ← 新增
```

### 13.2 SdkEvent 扩展建议

```rust
pub enum SdkEvent {
    // 已有
    SyncStarted,
    SyncFinished,
    SyncFailed { error: String },
    ConversationChanged { conversations: Vec<Conversation> },
    ConversationDeleted { conversation_ids: Vec<String> },
    TotalUnreadCountChanged { count: i64 },

    // 新增 — 消息相关
    NewMessage { message: MsgStruct },
    OfflineNewMessage { messages: Vec<MsgStruct> },
    OnlineOnlyMessage { messages: Vec<MsgStruct> },
    MessageDeleted { messages: Vec<MsgStruct> },
    MessageRevoked { revoke_info: MessageRevoked },
    C2CReadReceipt { receipts: Vec<MessageReceipt> },

    // 新增 — 好友相关
    FriendApplicationAdded { request: LocalFriendRequest },
    FriendApplicationAccepted { request: LocalFriendRequest },
    FriendApplicationRejected { request: LocalFriendRequest },

    // 新增 — 群组相关
    GroupApplicationAdded { request: LocalGroupRequest },
    GroupApplicationAccepted { request: LocalGroupRequest },
    GroupApplicationRejected { request: LocalGroupRequest },
    GroupDismissed { group_info: LocalGroup },

    // 新增 — 同步相关
    SyncServerStart { is_app_data: bool },
    SyncServerProgress { progress: i32 },
    SyncServerFinish { is_app_data: bool },
    SyncServerFailed { is_app_data: bool },

    // 新增 — 输入状态
    ConversationUserInputStatusChanged { data: InputStatesChangedData },

    // 新增 — 自定义业务
    CustomBusinessMessage { detail: String },
}
```

### 13.3 NotificationFilter 在 Rust 中的使用

```rust
// 在 GroupManager 中初始化
pub struct GroupManager {
    // ...
    filter: NotificationFilter,
}

impl GroupManager {
    pub fn new(...) -> Self {
        Self {
            // ...
            filter: NotificationFilter::new(100, Duration::from_secs(10)),
        }
    }
}

// 在通知处理中使用
1503 => {
    let tips: JoinGroupApplicationTips = deserialize(msg.content)?;
    if self.filter.should_execute(&tips.uuid).await {
        self.listener.on_group_application_added(serialize(data));
    }
}
```

---

## 14. 测试用例

### 14.1 命令分发测试

```rust
#[tokio::test]
async fn test_work_dispatches_cmd_new_msg_come() {
    // 1. 创建 Conversation 实例
    // 2. 发送 CmdNewMsgCome 命令
    // 3. 验证 doMsgNew 被调用
}

#[tokio::test]
async fn test_work_dispatches_cmd_notification() {
    // 1. 创建通知消息
    // 2. 发送 CmdNotification 命令
    // 3. 验证 doNotificationManager 被调用
}

#[tokio::test]
async fn test_work_dispatches_cmd_sync_flag() {
    // 1. 发送 CmdSyncFlag + MsgSyncBegin
    // 2. 验证 syncFlag 被调用
    // 3. 验证 OnSyncServerStart(false) 被触发
}
```

### 14.2 通知路由测试

```rust
#[tokio::test]
async fn test_notification_manager_routes_friend_notification() {
    // 1. 创建 ContentType=1203 的通知消息
    // 2. 调用 doNotificationManager
    // 3. 验证 relation.DoNotification 被调用
}

#[tokio::test]
async fn test_notification_manager_routes_group_notification() {
    // 1. 创建 ContentType=1501 的通知消息
    // 2. 调用 doNotificationManager
    // 3. 验证 group.DoNotification 被调用
}

#[tokio::test]
async fn test_notification_manager_routes_user_notification() {
    // 1. 创建 ContentType=1303 的通知消息
    // 2. 调用 doNotificationManager
    // 3. 验证 user.DoNotification 被调用
}

#[tokio::test]
async fn test_notification_manager_routes_conversation_notification() {
    // 1. 创建 ContentType=2101 的通知消息
    // 2. 调用 doNotificationManager
    // 3. 验证 conversation.DoNotification 被调用
}

#[tokio::test]
async fn test_notification_manager_updates_notification_seq() {
    // 1. 创建多条通知消息
    // 2. 调用 doNotificationManager
    // 3. 验证最后一条消息的 Seq 被写入 DB
}
```

### 14.3 好友通知测试

```rust
#[tokio::test]
async fn test_friend_application_notification() {
    // 1. 模拟收到 ContentType=1203 的通知
    // 2. 验证 OnFriendApplicationAdded 被触发
    // 3. 验证传入正确的 FriendRequest 数据
}

#[tokio::test]
async fn test_friend_added_notification_triggers_sync() {
    // 1. 模拟收到 ContentType=1204 的通知
    // 2. 验证 IncrSyncFriends 被调用
}

#[tokio::test]
async fn test_friend_deleted_notification_filters_non_self() {
    // 1. 模拟收到 ContentType=1205，FromUserID != loginUserID
    // 2. 验证 IncrSyncFriends 未被调用
}

#[tokio::test]
async fn test_black_added_notification() {
    // 1. 模拟收到 ContentType=1207 的通知
    // 2. 验证 SyncAllBlackList 被调用
}
```

### 14.4 群组通知测试

```rust
#[tokio::test]
async fn test_group_created_notification() {
    // 1. 模拟收到 ContentType=1501 的通知
    // 2. 验证 IncrSyncJoinGroup 和 IncrSyncGroupAndMember 被调用
}

#[tokio::test]
async fn test_member_quit_self() {
    // 1. 模拟收到 ContentType=1504，QuitUserID == loginUserID
    // 2. 验证 IncrSyncJoinGroup 被调用
}

#[tokio::test]
async fn test_member_quit_others() {
    // 1. 模拟收到 ContentType=1504，QuitUserID != loginUserID
    // 2. 验证 onlineSyncGroupAndMember 被调用
}

#[tokio::test]
async fn test_group_application_notification_with_filter() {
    // 1. 模拟收到 ContentType=1503，uuid="test-uuid"
    // 2. 验证 OnGroupApplicationAdded 被触发

    // 3. 再次模拟收到相同 uuid 的通知
    // 4. 验证 OnGroupApplicationAdded 未被触发（去重）
}

#[tokio::test]
async fn test_group_owner_transferred() {
    // 1. 模拟收到 ContentType=1507 的通知
    // 2. 验证 onlineSyncGroupAndMember 被调用
    // 3. 验证更新了新旧群主信息
}
```

### 14.5 syncFlag 测试

```rust
#[tokio::test]
async fn test_sync_flag_app_data_sync_start() {
    // 1. 模拟 CmdSyncFlag + AppDataSyncStart
    // 2. 验证 OnSyncServerStart(true) 被触发
    // 3. 验证各同步函数被调用
    // 4. 验证进度更新
}

#[tokio::test]
async fn test_sync_flag_app_data_sync_finish() {
    // 1. 模拟 CmdSyncFlag + AppDataSyncFinish
    // 2. 验证 progress = 100
    // 3. 验证 OnSyncServerFinish(true) 被触发
}

#[tokio::test]
async fn test_sync_flag_msg_sync_begin() {
    // 1. 模拟 CmdSyncFlag + MsgSyncBegin
    // 2. 验证 OnSyncServerStart(false) 被触发
    // 3. 验证 syncData 被调用
}

#[tokio::test]
async fn test_sync_flag_msg_sync_failed() {
    // 1. 模拟 CmdSyncFlag + MsgSyncFailed
    // 2. 验证 OnSyncServerFailed(false) 被触发
}
```

### 14.6 会话更新分发测试

```rust
#[tokio::test]
async fn test_update_conversation_add_or_update_latest_msg() {
    // 1. 模拟 AddConOrUpLatMsg 动作（新会话）
    // 2. 验证 InsertConversation 被调用
    // 3. 验证 OnNewConversation 被触发
}

#[tokio::test]
async fn test_update_conversation_total_unread_changed() {
    // 1. 设置一些会话的 unread_count
    // 2. 模拟 TotalUnreadMessageChanged 动作
    // 3. 验证 OnTotalUnreadMessageCountChanged 被触发
    // 4. 验证返回正确的总数
}

#[tokio::test]
async fn test_update_conversation_con_change() {
    // 1. 插入测试会话
    // 2. 模拟 ConChange 动作
    // 3. 验证 OnConversationChanged 被触发
    // 4. 验证只包含 latest_msg_send_time != 0 的会话
}
```

### 14.7 NotificationFilter 测试

```rust
#[tokio::test]
async fn test_notification_filter_first_execution() {
    let filter = NotificationFilter::new(10, Duration::from_secs(10));

    assert!(filter.should_execute("uuid-1").await);
}

#[tokio::test]
async fn test_notification_filter_duplicate_within_timeout() {
    let filter = NotificationFilter::new(10, Duration::from_secs(10));

    assert!(filter.should_execute("uuid-1").await);
    assert!(!filter.should_execute("uuid-1").await); // 重复，超时内
}

#[tokio::test]
async fn test_notification_filter_different_uuids() {
    let filter = NotificationFilter::new(10, Duration::from_secs(10));

    assert!(filter.should_execute("uuid-1").await);
    assert!(filter.should_execute("uuid-2").await); // 不同 UUID
}

#[tokio::test]
async fn test_notification_filter_lru_eviction() {
    let filter = NotificationFilter::new(2, Duration::from_secs(10));

    assert!(filter.should_execute("uuid-1").await);
    assert!(filter.should_execute("uuid-2").await);
    assert!(filter.should_execute("uuid-3").await); // uuid-1 被驱逐

    // uuid-1 被 LRU 驱逐后，再次执行应该返回 true
    assert!(filter.should_execute("uuid-1").await);
}

#[tokio::test]
async fn test_execute_if_new() {
    let filter = NotificationFilter::new(10, Duration::from_secs(10));
    let called = Arc::new(Mutex::new(false));

    let called_clone = called.clone();
    filter.execute_if_new("uuid-1", move || {
        *called_clone.lock().unwrap() = true;
    }).await;
    assert!(*called.lock().unwrap());

    // 重复执行
    let called_clone = called.clone();
    filter.execute_if_new("uuid-1", move || {
        *called_clone.lock().unwrap() = true; // 不应该执行
    }).await;
    // 值保持为 true（未被重置）
}
```
