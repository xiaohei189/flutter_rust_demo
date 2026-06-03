# 回调/监听器体系完整参考

> 本文档完整记录 Go SDK 的所有监听器接口定义、Rust SdkEvent 映射关系、事件触发时机以及当前实现状态。

---

## 1. Go SDK 监听器接口定义

Go SDK 定义在 `open_im_sdk_callback/callback_client.go` 中，共有 12 个监听器接口。

### 1.1 基础接口

```go
// 所有回调的基础接口
type Base interface {
    OnError(errCode int32, errMsg string)
    OnSuccess(data string)
}

// 带进度的发送回调
type SendMsgCallBack interface {
    Base
    OnProgress(progress int)
}
```

### 1.2 OnConnListener（连接监听器，6 个方法）

```go
type OnConnListener interface {
    OnConnecting()                          // 正在连接
    OnConnectSuccess()                      // 连接成功
    OnConnectFailed(errCode int32, errMsg string)  // 连接失败
    OnKickedOffline()                       // 被踢下线
    OnUserTokenExpired()                    // Token 过期
    OnUserTokenInvalid(errMsg string)       // Token 无效
}
```

### 1.3 OnAdvancedMsgListener（高级消息监听器，6 个方法）

```go
type OnAdvancedMsgListener interface {
    OnRecvNewMessage(message string)                    // 收到新消息
    OnRecvC2CReadReceipt(msgReceiptList string)         // 收到 C2C 已读回执
    OnNewRecvMessageRevoked(messageRevoked string)      // 收到消息撤回通知
    OnRecvOfflineNewMessage(message string)             // 收到离线新消息
    OnMsgDeleted(message string)                        // 消息被删除
    OnRecvOnlineOnlyMessage(message string)             // 收到仅在线消息
}
```

### 1.4 OnConversationListener（会话监听器，8 个方法）

```go
type OnConversationListener interface {
    OnSyncServerStart(reinstalled bool)                   // 服务端同步开始
    OnSyncServerFinish(reinstalled bool)                  // 服务端同步完成
    OnSyncServerProgress(progress int)                    // 服务端同步进度
    OnSyncServerFailed(reinstalled bool)                  // 服务端同步失败
    OnNewConversation(conversationList string)            // 新会话创建
    OnConversationChanged(conversationList string)        // 会话信息变更
    OnTotalUnreadMessageCountChanged(totalUnreadCount int32)  // 总未读数变化
    OnConversationUserInputStatusChanged(change string)   // 输入状态变化
}
```

### 1.5 OnGroupListener（群组监听器，11 个方法）

```go
type OnGroupListener interface {
    OnJoinedGroupAdded(groupInfo string)          // 加入了新群
    OnJoinedGroupDeleted(groupInfo string)        // 退出/被踢出群
    OnGroupMemberAdded(groupMemberInfo string)    // 群成员加入
    OnGroupMemberDeleted(groupMemberInfo string)  // 群成员被踢出
    OnGroupApplicationAdded(groupApplication string)    // 收到入群申请
    OnGroupApplicationDeleted(groupApplication string)  // 入群申请被删除
    OnGroupInfoChanged(groupInfo string)          // 群信息变更
    OnGroupDismissed(groupInfo string)            // 群被解散
    OnGroupMemberInfoChanged(groupMemberInfo string)    // 群成员信息变更
    OnGroupApplicationAccepted(groupApplication string) // 入群申请被接受
    OnGroupApplicationRejected(groupApplication string) // 入群申请被拒绝
}
```

### 1.6 OnFriendshipListener（好友监听器，9 个方法）

```go
type OnFriendshipListener interface {
    OnFriendApplicationAdded(friendApplication string)     // 收到好友申请
    OnFriendApplicationDeleted(friendApplication string)   // 好友申请被删除
    OnFriendApplicationAccepted(friendApplication string)  // 好友申请被接受
    OnFriendApplicationRejected(friendApplication string)  // 好友申请被拒绝
    OnFriendAdded(friendInfo string)                       // 新好友添加
    OnFriendDeleted(friendInfo string)                     // 好友被删除
    OnFriendInfoChanged(friendInfo string)                 // 好友信息变更
    OnBlackAdded(blackInfo string)                         // 加入黑名单
    OnBlackDeleted(blackInfo string)                       // 移出黑名单
}
```

### 1.7 OnUserListener（用户监听器，2 个方法）

```go
type OnUserListener interface {
    OnSelfInfoUpdated(userInfo string)           // 自己信息更新
    OnUserStatusChanged(userOnlineStatus string) // 用户在线状态变化
}
```

### 1.8 OnCustomBusinessListener（自定义业务监听器，1 个方法）

```go
type OnCustomBusinessListener interface {
    OnRecvCustomBusinessMessage(businessMessage string)  // 收到自定义业务消息
}
```

### 1.9 OnMessageKvInfoListener（消息 KV 信息监听器，1 个方法）

```go
type OnMessageKvInfoListener interface {
    OnMessageKvInfoChanged(messageChangedList string)  // 消息 KV 信息变更
}
```

### 1.10 OnListenerForService（服务聚合监听器，5 个方法）

```go
type OnListenerForService interface {
    OnGroupApplicationAdded(groupApplication string)
    OnGroupApplicationAccepted(groupApplication string)
    OnFriendApplicationAdded(friendApplication string)
    OnFriendApplicationAccepted(friendApplication string)
    OnRecvNewMessage(message string)
}
```

### 1.11 OnSignalingListener（信令监听器，10 个方法）

```go
type OnSignalingListener interface {
    OnReceiveNewInvitation(receiveNewInvitationCallback string)
    OnInviteeAccepted(inviteeAcceptedCallback string)
    OnInviteeAcceptedByOtherDevice(inviteeAcceptedCallback string)
    OnInviteeRejected(inviteeRejectedCallback string)
    OnInviteeRejectedByOtherDevice(inviteeRejectedCallback string)
    OnInvitationCancelled(invitationCancelledCallback string)
    OnInvitationTimeout(invitationTimeoutCallback string)
    OnHangUp(hangUpCallback string)
    OnRoomParticipantConnected(onRoomParticipantConnectedCallback string)
    OnRoomParticipantDisconnected(onRoomParticipantDisconnectedCallback string)
}
```

### 1.12 UploadFileCallback（文件上传回调，8 个方法）

```go
type UploadFileCallback interface {
    Open(size int64)
    PartSize(partSize int64, num int)
    HashPartProgress(index int, size int64, partHash string)
    HashPartComplete(partsHash string, fileHash string)
    UploadID(uploadID string)
    UploadPartComplete(index int, partSize int64, partHash string)
    UploadComplete(fileSize int64, streamSize int64, storageSize int64)
    Complete(size int64, url string, typ int)
}
```

---

## 2. Rust SdkEvent 映射

### 2.1 映射总览

Rust SDK 使用统一的 `SdkEvent` 枚举替代 Go SDK 的多个监听器接口。所有回调通过 `EventBus` 广播。

| Go SDK 监听器 | Go 回调方法 | Rust SdkEvent 变体 | 映射状态 |
|-------------|-----------|-------------------|---------|
| **OnConnListener** | `OnConnecting()` | `SdkEvent::Connecting` | ✅ |
| | `OnConnectSuccess()` | `SdkEvent::Connected` | ✅ |
| | `OnConnectFailed(errCode, errMsg)` | `SdkEvent::ConnectFailed { error }` | ✅ |
| | `OnKickedOffline()` | `SdkEvent::KickedOffline { reason }` | ✅ |
| | `OnUserTokenExpired()` | `SdkEvent::TokenExpired` | ✅ |
| | `OnUserTokenInvalid(errMsg)` | `SdkEvent::TokenExpired` | ✅ 合并 |
| **OnAdvancedMsgListener** | `OnRecvNewMessage(message)` | `SdkEvent::NewMessage { message }` | ✅ |
| | `OnRecvC2CReadReceipt(list)` | — | ❌ 未实现 |
| | `OnNewRecvMessageRevoked(info)` | `SdkEvent::MessageRevoked { .. }` | ✅ |
| | `OnRecvOfflineNewMessage(msg)` | `SdkEvent::NewMessage { message }` | ✅ 合并 |
| | `OnMsgDeleted(message)` | `SdkEvent::MessagesDeleted { .. }` | ✅ |
| | `OnRecvOnlineOnlyMessage(msg)` | — | ❌ 未实现 |
| **OnConversationListener** | `OnSyncServerStart(reinstalled)` | `SdkEvent::SyncStarted` | ✅ |
| | `OnSyncServerFinish(reinstalled)` | `SdkEvent::SyncFinished` | ✅ |
| | `OnSyncServerProgress(progress)` | `SdkEvent::SyncProgress { .. }` | ✅ |
| | `OnSyncServerFailed(reinstalled)` | `SdkEvent::SyncFailed { error }` | ✅ |
| | `OnNewConversation(list)` | `SdkEvent::NewConversation { .. }` | ✅ |
| | `OnConversationChanged(list)` | `SdkEvent::ConversationChanged { .. }` | ✅ |
| | `OnTotalUnreadMessageCountChanged(count)` | `SdkEvent::TotalUnreadCountChanged { .. }` | ✅ |
| | `OnConversationUserInputStatusChanged(change)` | — | ❌ 未实现 |
| **OnGroupListener** | `OnJoinedGroupAdded(info)` | `SdkEvent::GroupCreated { .. }` | ✅ |
| | `OnJoinedGroupDeleted(info)` | — | ❌ 未实现 |
| | `OnGroupMemberAdded(info)` | `SdkEvent::GroupMemberAdded { .. }` | ✅ |
| | `OnGroupMemberDeleted(info)` | `SdkEvent::GroupMemberDeleted { .. }` | ✅ |
| | `OnGroupApplicationAdded(app)` | `SdkEvent::GroupApplicationAdded { .. }` | ✅ |
| | `OnGroupApplicationDeleted(app)` | — | ❌ 未实现 |
| | `OnGroupInfoChanged(info)` | `SdkEvent::GroupInfoChanged { .. }` | ✅ |
| | `OnGroupDismissed(info)` | `SdkEvent::GroupDismissed { .. }` | ✅ |
| | `OnGroupMemberInfoChanged(info)` | `SdkEvent::GroupMemberInfoChanged { .. }` | ✅ |
| | `OnGroupApplicationAccepted(app)` | `SdkEvent::GroupApplicationApproved { .. }` | ✅ |
| | `OnGroupApplicationRejected(app)` | `SdkEvent::GroupApplicationRejected { .. }` | ✅ |
| **OnFriendshipListener** | `OnFriendApplicationAdded(app)` | `SdkEvent::FriendApplicationAdded { .. }` | ✅ |
| | `OnFriendApplicationDeleted(app)` | — | ❌ 未实现 |
| | `OnFriendApplicationAccepted(app)` | `SdkEvent::FriendApplicationApproved { .. }` | ✅ |
| | `OnFriendApplicationRejected(app)` | `SdkEvent::FriendApplicationRejected { .. }` | ✅ |
| | `OnFriendAdded(info)` | `SdkEvent::FriendAdded { .. }` | ✅ |
| | `OnFriendDeleted(info)` | `SdkEvent::FriendDeleted { .. }` | ✅ |
| | `OnFriendInfoChanged(info)` | `SdkEvent::FriendInfoUpdated { .. }` | ✅ |
| | `OnBlackAdded(info)` | `SdkEvent::BlackAdded { .. }` | ✅ |
| | `OnBlackDeleted(info)` | `SdkEvent::BlackDeleted { .. }` | ✅ |
| **OnUserListener** | `OnSelfInfoUpdated(info)` | `SdkEvent::UserInfoUpdated { .. }` | ✅ |
| | `OnUserStatusChanged(status)` | `SdkEvent::UserStatusChanged { .. }` | ✅ |
| **OnCustomBusinessListener** | `OnRecvCustomBusinessMessage(msg)` | `SdkEvent::CustomEvent { .. }` | ✅ |
| **OnMessageKvInfoListener** | `OnMessageKvInfoChanged(list)` | — | ❌ 未实现 |
| **OnSignalingListener** | (全部 10 个方法) | — | ❌ 未实现 |

### 2.2 Rust 实现架构

```
Go SDK 架构:
  Listener 回调 → Flutter/Dart 层注册回调函数 → 逐个调用

Rust SDK 架构:
  内部模块 → EventBus::publish(SdkEvent) → EventSubscription → StreamSink → Dart Stream
```

Rust 使用 `EventBus`（基于 `tokio::sync::broadcast`）统一所有事件：

```rust
// rust/src/domain/event/bus.rs
pub struct EventBus {
    sender: broadcast::Sender<SdkEvent>,
}

impl EventBus {
    pub fn publish(&self, event: SdkEvent) {
        let _ = self.sender.send(event);
    }

    pub fn subscribe(&self) -> EventSubscription {
        EventSubscription {
            receiver: self.sender.subscribe(),
        }
    }
}
```

---

## 3. 事件触发时机完整表

### 3.1 连接事件

| 事件 | 触发模块 | 触发时机 | 触发位置代码 |
|------|---------|---------|------------|
| `Connecting` | ConnectionManager | WebSocket 开始连接 | `do_connect()` 方法开头 |
| `Connected` | ConnectionManager | WebSocket 连接成功 | `do_connect()` 方法成功后 |
| `Disconnected` | ConnectionManager | 连接断开（多种原因） | `read_loop` 中 Close/Error/None |
| `ConnectFailed` | ConnectionManager | 连接失败 | `do_connect()` 方法失败时 |
| `Reconnecting` | ConnectionManager | 开始重连尝试 | `reconnect_loop` 中 |
| `KickedOffline` | ConnectionManager | 被踢下线 | `handle_kicked()` 方法 |
| `TokenExpired` | ConnectionManager | Token 过期 | WebSocket 握手返回 TokenExpired |

### 3.2 消息事件

| 事件 | 触发模块 | 触发时机 | 触发位置代码 |
|------|---------|---------|------------|
| `PushMessage` | ConnectionManager (read_loop) | 收到推送消息（JSON 格式） | `read_loop` 中解析 OpenIMResp |
| `PushMessages` | ConnectionManager (read_loop) | 收到结构化推送消息（Binary） | `read_loop` 中解析 PushMessages |
| `PushNotificationMessages` | ConnectionManager (read_loop) | 收到通知消息推送（Binary） | `read_loop` 中解析 notification_msgs |
| `NewMessage` | MessageHandler | 新消息入库后 | `handle_messages()` 方法 |
| `MessageSent` | OpenIMClient | 消息发送成功 | `do_send_message()` 方法 |
| `MessageSendFailed` | OpenIMClient | 消息发送失败 | `do_send_message()` 方法 |
| `MessageRevoked` | MessageService | 消息被撤回 | `revoke_message()` 方法 |
| `MessagesDeleted` | MessageService | 消息被删除 | `delete_messages()` 方法 |

### 3.3 同步事件

| 事件 | 触发模块 | 触发时机 | 触发位置代码 |
|------|---------|---------|------------|
| `SyncStarted` | MessageSyncer | 消息同步开始 | `sync_on_login()` / `sync_after_reconnect()` |
| `SyncProgress` | MessageSyncer | 同步进度更新 | `pull_and_handle_messages()` |
| `SyncFinished` | MessageSyncer | 消息同步完成 | `sync_on_login()` / `sync_after_reconnect()` |
| `SyncFailed` | MessageSyncer | 消息同步失败 | `sync_on_login()` / `sync_after_reconnect()` |

### 3.4 会话事件

| 事件 | 触发模块 | 触发时机 | 触发位置代码 |
|------|---------|---------|------------|
| `ConversationChanged` | ConversationManager / ConversationSyncer | 会话信息变更 | `update_conversation` / `sync_full` |
| `ConversationDeleted` | ConversationManager | 会话被删除 | `delete_conversation()` |
| `NewConversation` | ConversationSyncer | 新会话同步 | `sync_full()` |
| `TotalUnreadCountChanged` | ConversationManager | 总未读数变化 | `update_unread_count()` |

### 3.5 好友事件

| 事件 | 触发模块 | 触发时机 | 触发位置代码 |
|------|---------|---------|------------|
| `FriendApplicationAdded` | FriendManager | 收到好友申请（从推送通知） | 通知消息处理 |
| `FriendApplicationApproved` | FriendManager | 好友申请被接受 | `accept_friend_application()` |
| `FriendApplicationRejected` | FriendManager | 好友申请被拒绝 | `refuse_friend_application()` |
| `FriendAdded` | FriendManager | 好友添加成功 | `add_friend()` / 增量同步 |
| `FriendDeleted` | FriendManager | 好友被删除 | `delete_friend()` / 增量同步 |
| `FriendInfoUpdated` | FriendManager | 好友信息变更 | 增量同步 |
| `BlackAdded` | FriendManager | 加入黑名单 | `add_black()` |
| `BlackDeleted` | FriendManager | 移出黑名单 | `remove_black()` |

### 3.6 群组事件

| 事件 | 触发模块 | 触发时机 | 触发位置代码 |
|------|---------|---------|------------|
| `GroupCreated` | GroupManager | 加入新群 | 增量同步 |
| `GroupInfoChanged` | GroupManager | 群信息变更 | 增量同步 / `set_group_info()` |
| `GroupMemberAdded` | GroupManager | 群成员加入 | 增量同步 / `invite_group_members()` |
| `GroupMemberDeleted` | GroupManager | 群成员被踢出 | 增量同步 / `kick_group_members()` |
| `GroupApplicationAdded` | GroupManager | 收到入群申请 | 通知消息处理 |
| `GroupApplicationApproved` | GroupManager | 入群申请被接受 | `accept_group_application()` |
| `GroupApplicationRejected` | GroupManager | 入群申请被拒绝 | `refuse_group_application()` |
| `GroupDismissed` | GroupManager | 群被解散 | 增量同步 |
| `GroupMemberInfoChanged` | GroupManager | 群成员信息变更 | 增量同步 |
| `GroupMuted` | GroupManager | 群被全员禁言 | 通知消息处理 |
| `GroupCancelMuted` | GroupManager | 群取消全员禁言 | 通知消息处理 |
| `GroupMemberMuted` | GroupManager | 群成员被禁言 | 通知消息处理 |
| `GroupMemberCancelMuted` | GroupManager | 群成员取消禁言 | 通知消息处理 |
| `GroupOwnerTransferred` | GroupManager | 群主转让 | 通知消息处理 |

### 3.7 用户事件

| 事件 | 触发模块 | 触发时机 | 触发位置代码 |
|------|---------|---------|------------|
| `UserInfoUpdated` | UserManager | 自己信息更新 | `update_self_user_info()` |
| `UserStatusChanged` | OnlineStatusManager | 用户在线状态变化 | 在线状态订阅回调 |

### 3.8 生命周期事件

| 事件 | 触发模块 | 触发时机 | 触发位置代码 |
|------|---------|---------|------------|
| `LoginSuccess` | OpenIMClient | 登录成功 | `login()` 方法末尾 |
| `Logout` | OpenIMClient | 登出 | `logout()` 方法 |
| `TokenExpired` | ConnectionManager | Token 过期 | WebSocket 握手失败 |

---

## 4. Rust 当前事件实现状态

### 4.1 已发布事件（30 个）

| 事件 | 发布模块 | 代码位置 |
|------|---------|---------|
| `Connecting` | ConnectionManager | `manager.rs:do_connect()` |
| `Connected` | ConnectionManager | `manager.rs:do_connect()` |
| `Disconnected` | ConnectionManager | `manager.rs:read_loop / disconnect` |
| `Reconnecting` | ConnectionManager | `manager.rs:reconnect_loop` |
| `KickedOffline` | ConnectionManager | `manager.rs:handle_kicked()` |
| `TokenExpired` | ConnectionManager | `manager.rs:do_connect()` |
| `PushMessage` | ConnectionManager | `manager.rs:read_loop` |
| `PushMessages` | ConnectionManager | `manager.rs:read_loop` |
| `PushNotificationMessages` | ConnectionManager | `manager.rs:read_loop` |
| `NewMessage` | MessageHandler | `handler.rs:handle_messages()` |
| `MessageSent` | OpenIMClient | `message.rs:do_send_message()` |
| `MessageSendFailed` | OpenIMClient | `message.rs:do_send_message()` |
| `MessageRevoked` | MessageService | `service.rs:revoke_message()` |
| `MessagesDeleted` | MessageService | `service.rs:delete_messages()` |
| `SyncStarted` | MessageSyncer | `syncer.rs:sync_on_login/sync_after_reconnect` |
| `SyncProgress` | MessageSyncer | `syncer.rs:pull_and_handle_messages` |
| `SyncFinished` | MessageSyncer | `syncer.rs:sync_on_login/sync_after_reconnect` |
| `SyncFailed` | MessageSyncer | `syncer.rs:sync_on_login/sync_after_reconnect` |
| `ConversationChanged` | ConversationManager | `manager.rs / message.rs` |
| `NewConversation` | ConversationSyncer | `syncer.rs:sync_full` |
| `TotalUnreadCountChanged` | ConversationManager | `manager.rs:update_unread_count` |
| `FriendAdded` | FriendManager | (内部) |
| `FriendDeleted` | FriendManager | (内部) |
| `FriendInfoUpdated` | FriendManager | (内部) |
| `FriendApplicationAdded` | FriendManager | (内部) |
| `FriendApplicationApproved` | FriendManager | (内部) |
| `FriendApplicationRejected` | FriendManager | (内部) |
| `BlackAdded` | FriendManager | (内部) |
| `BlackDeleted` | FriendManager | (内部) |
| `LoginSuccess` | OpenIMClient | `client.rs:login()` |
| `Logout` | OpenIMClient | `client.rs:logout()` |

### 4.2 已定义但未发布的事件（12 个）

| 事件 | 说明 | Go SDK 对应回调 |
|------|------|---------------|
| `ConnectFailed` | 连接失败 | `OnConnectFailed` |
| `ConversationDeleted` | 会话被删除 | (无直接对应) |
| `GroupCreated` | 加入新群 | `OnJoinedGroupAdded` |
| `GroupInfoChanged` | 群信息变更 | `OnGroupInfoChanged` |
| `GroupMemberAdded` | 群成员加入 | `OnGroupMemberAdded` |
| `GroupMemberDeleted` | 群成员被踢出 | `OnGroupMemberDeleted` |
| `GroupApplicationAdded` | 收到入群申请 | `OnGroupApplicationAdded` |
| `GroupApplicationApproved` | 入群申请被接受 | `OnGroupApplicationAccepted` |
| `GroupApplicationRejected` | 入群申请被拒绝 | `OnGroupApplicationRejected` |
| `GroupDismissed` | 群被解散 | `OnGroupDismissed` |
| `GroupMemberInfoChanged` | 群成员信息变更 | `OnGroupMemberInfoChanged` |
| `CustomEvent` | 自定义业务事件 | `OnRecvCustomBusinessMessage` |

### 4.3 完全缺失的事件（未定义也未实现）

| Go SDK 回调 | 对应功能 | 优先级 |
|------------|---------|--------|
| `OnRecvC2CReadReceipt` | C2C 已读回执 | P1 |
| `OnRecvOnlineOnlyMessage` | 仅在线消息 | P2 |
| `OnConversationUserInputStatusChanged` | 输入状态变化 | P1 |
| `OnJoinedGroupDeleted` | 退出/被踢出群 | P1 |
| `OnGroupApplicationDeleted` | 入群申请被删除 | P2 |
| `OnFriendApplicationDeleted` | 好友申请被删除 | P2 |
| `OnMessageKvInfoChanged` | 消息 KV 信息变更 | P2 |
| `OnSignalingListener` (全部 10 个) | 信令相关 | P3 |
| 群禁言/取消禁言事件 | 群管理操作 | P2 |
| `GroupMemberMuted` | 群成员禁言 | P2 |
| `GroupMemberCancelMuted` | 群成员取消禁言 | P2 |
| `GroupOwnerTransferred` | 群主转让 | P2 |

### 4.4 实现状态统计

| 类别 | 已实现 | 已定义未发布 | 完全缺失 | 合计 |
|------|--------|-----------|---------|------|
| 连接事件 | 5 | 1 | 0 | 6 |
| 消息事件 | 6 | 0 | 2 | 8 |
| 同步事件 | 4 | 0 | 0 | 4 |
| 会话事件 | 3 | 1 | 1 | 5 |
| 好友事件 | 6 | 0 | 1 | 7 |
| 黑名单事件 | 2 | 0 | 0 | 2 |
| 群组事件 | 0 | 6 | 6 | 12 |
| 用户事件 | 1 | 0 | 0 | 1 |
| 信令事件 | 0 | 0 | 10 | 10 |
| 生命周期事件 | 2 | 0 | 0 | 2 |
| 自定义事件 | 0 | 1 | 0 | 1 |
| **合计** | **29** | **9** | **20** | **58** |

---

## 5. 事件总线设计参考

### 5.1 Rust EventBus 实现

```rust
// rust/src/domain/event/bus.rs
use tokio::sync::broadcast;

const EVENT_CHANNEL_CAPACITY: usize = 1024;

pub struct EventBus {
    sender: broadcast::Sender<SdkEvent>,
}

impl EventBus {
    pub fn new() -> Self {
        let (sender, _) = broadcast::channel(EVENT_CHANNEL_CAPACITY);
        Self { sender }
    }

    pub fn publish(&self, event: SdkEvent) {
        let _ = self.sender.send(event);  // 忽略无接收者的错误
    }

    pub fn subscribe(&self) -> EventSubscription {
        EventSubscription {
            receiver: self.sender.subscribe(),
        }
    }
}

pub struct EventSubscription {
    receiver: broadcast::Receiver<SdkEvent>,
}

impl EventSubscription {
    pub async fn next(&mut self) -> Option<SdkEvent> {
        loop {
            match self.receiver.recv().await {
                Ok(event) => return Some(event),
                Err(broadcast::error::RecvError::Lagged(n)) => {
                    tracing::warn!("Event bus lagged, dropped {} events", n);
                    // 继续循环，不返回 None
                }
                Err(broadcast::error::RecvError::Closed) => {
                    return None;
                }
            }
        }
    }
}
```

### 5.2 Go SDK vs Rust SDK 监听器架构对比

```
Go SDK 架构:
┌─────────────────────────────────────────────────────┐
│                    UserContext                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│  │OnConn    │  │OnMsg     │  │OnConv    │  ...     │
│  │Listener  │  │Listener  │  │Listener  │         │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘         │
│       │             │             │                  │
│  ┌────▼─────────────▼─────────────▼────┐           │
│  │     各模块内部直接调用 listener       │           │
│  │  listener.OnRecvNewMessage(msg)     │           │
│  │  listener.OnConversationChanged(c)  │           │
│  └─────────────────────────────────────┘           │
│                                                     │
│  Flutter 侧注册:                                    │
│  sdk.SetAdvancedMsgListener(OnAdvancedMsgListener)  │
│  sdk.SetConversationListener(OnConversationListener)│
└─────────────────────────────────────────────────────┘

Rust SDK 架构:
┌─────────────────────────────────────────────────────┐
│                   OpenIMClient                      │
│                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│  │MessageHdl│  │ConvSyncer│  │FriendMgr │  ...     │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘         │
│       │             │             │                  │
│  ┌────▼─────────────▼─────────────▼────┐           │
│  │         EventBus::publish()          │           │
│  │  bus.publish(SdkEvent::NewMessage)   │           │
│  │  bus.publish(SdkEvent::ConvChanged)  │           │
│  └──────────────────┬──────────────────┘           │
│                     │                               │
│  ┌──────────────────▼──────────────────┐           │
│  │    broadcast::channel (1024容量)     │           │
│  └──────────────────┬──────────────────┘           │
│                     │                               │
│  ┌──────────────────▼──────────────────┐           │
│  │   StreamSink → Dart Stream          │           │
│  │   event_stream(sink) 方法           │           │
│  └─────────────────────────────────────┘           │
│                                                     │
│  Flutter 侧:                                       │
│  client.eventStream().listen((event) { ... })      │
│  // 统一的事件流，按 event 类型分发                   │
└─────────────────────────────────────────────────────┘
```

### 5.3 设计优势

| 特性 | Go SDK (多 Listener) | Rust SDK (EventBus) |
|------|---------------------|---------------------|
| 注册方式 | 每种类型单独注册 | 单一 `event_stream()` |
| 类型安全 | 字符串传递，运行时解析 | 强类型枚举，编译时检查 |
| 扩展性 | 新增 Listener 需修改接口 | 新增 SdkEvent 变体即可 |
| 多订阅者 | 每种类型只有一个 Listener | broadcast 支持多个订阅者 |
| 错误处理 | 回调异常影响其他回调 | publish 失败不影响业务 |

### 5.4 Flutter/Dart 侧使用示例

```dart
// Dart 侧监听事件流
final stream = client.eventStream();
stream.listen((event) {
  switch (event) {
    case LoginSuccess(:final userId):
      print('登录成功: $userId');
    case NewMessage(:final message):
      print('收到新消息: ${message.content}');
    case MessageSent(:final clientMsgId):
      print('消息发送成功: $clientMsgId');
    case KickedOffline(:final reason):
      print('被踢下线: $reason');
    case TokenExpired():
      print('Token 过期，请重新登录');
    case ConversationChanged(:final conversations):
      print('会话变化: ${conversations.length}');
    case FriendAdded(:final friends):
      print('新好友: ${friends.length}');
    case GroupMemberAdded(:final groupId, :final memberIds):
      print('群 $groupId 新增成员: $memberIds');
    case SyncStarted():
      print('开始同步...');
    case SyncFinished():
      print('同步完成');
    default:
      print('其他事件: ${event.runtimeType}');
  }
});
```
