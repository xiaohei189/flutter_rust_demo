# 回调/监听器体系完整参考

> 本文档记录 Rust SDK 的 **Listener trait 回调体系**：6 个 Listener trait 的定义、与 Go SDK 回调的映射、
> 事件流向（Service → Listener → EventHub → Dart Stream）、触发时机与实现状态。
> 旧版 `SdkEvent` 枚举 + `EventBus` 广播已于重构中移除，事件统一经 Listener 回调对外分发。

---

## 1. Rust Listener traits（统一回调契约）

所有 trait 要求 `Send + Sync`，方法均有默认空实现——外部接入只需覆写关心的回调，可包在 `Arc<dyn XxxListener>` 中注入。

源码位置：`rust/src/event/events/`（每个领域一个文件）。

### 1.1 ConnectionListener — 连接（connection.rs，9 个）

| 回调 | 说明 |
|------|------|
| `on_connecting()` | 开始连接 |
| `on_connected()` | 连接成功 |
| `on_disconnected(reason: &str)` | 连接断开 |
| `on_connect_failed(err_code: i32, error: &str)` | 连接失败（含服务端错误码） |
| `on_kicked_offline(reason: &str)` | 被踢下线 |
| `on_token_expired()` | Token 过期 |
| `on_token_invalid(error: &str)` | Token 无效（非过期类错误） |
| `on_reconnecting(attempt: u32, max_attempts: u32)` | 开始重连 |
| `on_login_success(user_id: &str)` | 登录成功 |
| `on_logout()` | 登出 |

### 1.2 ConversationListener — 会话（conversation.rs，10 个）

| 回调 | 说明 |
|------|------|
| `on_changed(conversations: &[LocalConversation])` | 会话变更 |
| `on_deleted(ids: &[String])` | 会话删除 |
| `on_new(conversations: &[LocalConversation])` | 新会话（预留） |
| `on_total_unread_count_changed(count: i64)` | 总未读数变化 |
| `on_sync_started(reinstalled: bool)` / `on_sync_finished(reinstalled: bool)` | 同步开始/完成（含重装标志） |
| `on_sync_failed(reinstalled: bool, error: &str)` | 同步失败（含重装标志） |
| `on_sync_progress(progress: i32, message: &str)` | 同步进度 |
| `on_user_input_status_changed(conversation_id, user_id, platform_ids: &[i32])` | 输入状态（typing） |
| `on_update_latest_message_read_state(conversation_id: &str)` | 最新消息已读状态 |

### 1.3 FriendListener — 好友（friend.rs，8 个）

| 回调 | 说明 |
|------|------|
| `on_added(friends: &[FriendInfo])` | 好友新增/同步 |
| `on_deleted(friend_json: &str)` | 好友删除（完整好友信息 JSON） |
| `on_info_changed(friends: &[FriendInfo])` | 好友信息变更（预留） |
| `on_black_added(black_json: &str)` / `on_black_deleted(black_json: &str)` | 黑名单增删（黑名单信息 JSON） |
| `on_application_added(user_id: &str)` / `on_application_deleted(user_id: &str)` | 好友申请新增/删除 |
| `on_application_accepted(user_id: &str)` / `on_application_rejected(user_id: &str)` | 申请被接受/拒绝 |

### 1.4 GroupListener — 群组（group.rs，9 个）

| 回调 | 说明 |
|------|------|
| `on_joined_group_added(group: &GroupInfo)` | 加入新群（预留） |
| `on_joined_group_deleted(group: &GroupInfo)` | 退群/被踢（预留） |
| `on_group_info_changed(group: &GroupInfo)` | 群信息变更（预留） |
| `on_member_added(member: &GroupMember)` / `on_member_deleted(member: &GroupMember)` | 成员增删 |
| `on_member_info_changed(member: &GroupMember)` | 成员信息变更 |
| `on_group_read_receipt(receipts: &[GroupReadReceipt])` | 群已读回执（预留） |
| `on_application_added(group_id: &str)` / `on_application_deleted(group_id: &str)` | 入群申请新增/删除 |
| `on_application_approved(group_id: &str)` / `on_application_rejected(group_id: &str)` | 申请被接受/拒绝 |
| `on_dismissed(group: &GroupInfo)` | 群组解散 |

### 1.5 UserListener — 用户/在线状态（user.rs，2 个）

| 回调 | 说明 |
|------|------|
| `on_user_info_updated(user: &UserInfo)` | 用户资料更新 |
| `on_user_status_changed(user_id: &str, status: i32, platform_ids: &[i32])` | 在线状态变化 |

### 1.6 MessageListener — 消息（message.rs，6 个，对齐 Go SDK MsgListener）

| 回调 | 说明 |
|------|------|
| `on_new_message(conversation_id, message: &MessageInfo)` | 收到新消息（实时/同步） |
| `on_offline_new_message(conversation_id, message: &MessageInfo)` | 收到离线新消息 |
| `on_online_only_message(conversation_id, message: &MessageInfo)` | 收到 online-only 消息 |
| `on_message_revoked(event: &MessageEvent)` | 消息被撤回 |
| `on_c2c_read_receipt(receipts: &[MessageReceipt])` | C2C 已读回执 |
| `on_message_deleted(conversation_id: &str, client_msg_ids: &[String])` | 消息被删除 |
| `on_send_failed(client_msg_id: &str, error: &str)` | 消息发送失败 |
| `on_upload_progress(client_msg_id: &str, progress: u8, total_size: u64, uploaded_size: u64)` | 上传进度（预留，当前直接走 sink） |

---

## 2. 事件流向

```
Service（core/*）
  │  只依赖 Listener trait（构造时注入 Arc<dyn XxxListener>）
  ▼
Listener 回调  ←—————————————— 唯一出口
  │
  ▼
EventHub（rust/src/event/hub.rs，SDK 内置实现全部 6 个 trait）
  │  回调 → 领域事件 → 写入各 mpsc 通道
  ▼
connection / conversation / friend / group / user / message 通道
  │
  ├─→ api/client.rs：StreamSink → Dart 4 个 stream
  │      connectionStream / conversationStream / friendStream / groupStream
  │      messageStream / userStream 已开放（2026-08-07 起）
  └─→ 外部 SDK：实现 Listener trait 后经 builder 注入（见第 6 节）
```

要点：

- 各 Service 不再持有 `EventSender`/`EventBus`，只在构造时注入 `Arc<dyn XxxListener>`。
- `EventHub` 是 Listener 回调的 Flutter 侧实现；外部接入可叠加自定义实现。
- Dart 侧保持 stream 形态（FRB StreamSink），事件源头已全部收敛到回调契约。

---

## 3. Go SDK → Rust 映射

| Go SDK 监听器 | Go 回调方法 | Rust Listener 回调 | 状态 |
|-------------|-----------|-------------------|------|
| **OnConnListener** | `OnConnecting()` | `on_connecting()` | ✅ |
| | `OnConnectSuccess()` | `on_connected()` | ✅ |
| | `OnConnectFailed(errCode, errMsg)` | `on_connect_failed(err_code, error)` | ✅ |
| | `OnKickedOffline()` | `on_kicked_offline()` | ✅ |
| | `OnUserTokenExpired()` | `on_token_expired()` | ✅ |
| | `OnUserTokenInvalid(errMsg)` | `on_token_invalid(error)` | ✅ |
| **OnAdvancedMsgListener** | `OnRecvNewMessage(message)` | `on_new_message()` | ✅ |
| | `OnRecvC2CReadReceipt(list)` | `on_c2c_read_receipt()` | ✅ |
| | `OnNewRecvMessageRevoked(info)` | `on_message_revoked()` | ✅ |
| | `OnRecvOfflineNewMessage(msg)` | `on_offline_new_message()` | ✅ |
| | `OnMsgDeleted(message)` | `on_message_deleted()` | ✅ |
| | `OnRecvOnlineOnlyMessage(msg)` | `on_online_only_message()` | ✅ |
| **OnConversationListener** | `OnSyncServerStart(reinstalled)` | `on_sync_started(reinstalled)` | ✅ |
| | `OnSyncServerFinish(reinstalled)` | `on_sync_finished(reinstalled)` | ✅ |
| | `OnSyncServerProgress(progress)` | `on_sync_progress()` | ✅ |
| | `OnSyncServerFailed(reinstalled)` | `on_sync_failed(reinstalled, error)` | ✅ |
| | `OnNewConversation(list)` | `on_new()` | 预留 |
| | `OnConversationChanged(list)` | `on_changed()` | ✅ |
| | `OnTotalUnreadMessageCountChanged(count)` | `on_total_unread_count_changed()` | ✅ |
| | `OnConversationUserInputStatusChanged(change)` | `on_user_input_status_changed()` | ✅ |
| **OnGroupListener** | `OnJoinedGroupAdded(info)` | `on_joined_group_added()` | 预留 |
| | `OnJoinedGroupDeleted(info)` | `on_joined_group_deleted()` | 预留 |
| | `OnGroupMemberAdded(info)` | `on_member_added(member)` | ✅ |
| | `OnGroupMemberDeleted(info)` | `on_member_deleted(member)` | ✅ |
| | `OnGroupApplicationAdded(app)` | `on_application_added()` | ✅ |
| | `OnGroupApplicationDeleted(app)` | `on_application_deleted()` | ✅ |
| | `OnGroupInfoChanged(info)` | `on_group_info_changed()` | 预留 |
| | `OnGroupDismissed(info)` | `on_dismissed()` | ✅ |
| | `OnGroupMemberInfoChanged(info)` | `on_member_info_changed()` | ✅ |
| | `OnGroupApplicationAccepted(app)` | `on_application_approved()` | ✅ |
| | `OnGroupApplicationRejected(app)` | `on_application_rejected()` | ✅ |
| **OnFriendshipListener** | `OnFriendApplicationAdded(app)` | `on_application_added()` | ✅ |
| | `OnFriendApplicationDeleted(app)` | `on_application_deleted()` | ✅ |
| | `OnFriendApplicationAccepted(app)` | `on_application_accepted()` | ✅ |
| | `OnFriendApplicationRejected(app)` | `on_application_rejected()` | ✅ |
| | `OnFriendAdded(info)` | `on_added()` | ✅ |
| | `OnFriendDeleted(info)` | `on_deleted()` | ✅ |
| | `OnFriendInfoChanged(info)` | `on_info_changed()` | 预留 |
| | `OnBlackAdded(info)` | `on_black_added()` | ✅ |
| | `OnBlackDeleted(info)` | `on_black_deleted()` | ✅ |
| **OnUserListener** | `OnSelfInfoUpdated(info)` | `on_user_info_updated()` | ✅ |
| | `OnUserStatusChanged(status)` | `on_user_status_changed()` | ✅ |
| **OnCustomBusinessListener** | `OnRecvCustomBusinessMessage(msg)` | — | ❌ 未实现 |
| **OnMessageKvInfoListener** | `OnMessageKvInfoChanged(list)` | — | ❌ 未实现 |
| **OnSignalingListener** | （全部 10 个） | — | ❌ 未实现 |
| **UploadFileCallback** | （上传回调 8 个） | — | ❌ 未实现 |

---

## 4. 事件触发时机

### 4.1 连接（ConnectionListener）

| 回调 | 触发模块 | 触发时机 |
|------|---------|---------|
| `on_connecting` | ConnectionManager（connector.rs） | `do_connect()` 开始 WebSocket 连接 |
| `on_connected` | ConnectionManager（connector.rs） | 认证成功、写入 writer 后 |
| `on_disconnected` | ConnectionManager / connector / reader | 断线、手动 disconnect、认证失败 |
| `on_kicked_offline` | ConnectionManager / reader | 握手返回 1506、收到 KICK_ONLINE 推送 |
| `on_token_expired` | ConnectionManager（connector.rs） | 握手返回 1507 |
| `on_reconnecting` | ConnectionManager（manager.rs） | 重连循环每次尝试前 |
| `on_login_success` | OpenIMClient | `login()` 末尾 |
| `on_logout` | OpenIMClient / reader | `logout()`、收到 LOGOUT 推送 |

### 4.2 会话（ConversationListener）

| 回调 | 触发模块 | 触发时机 |
|------|---------|---------|
| `on_changed` | ConversationService / Syncer / MessageHandler / receipt / revoke / sdk(client/message) | 会话 upsert、消息入库后的会话更新、已读回执、本地发送乐观更新 |
| `on_deleted` | ConversationService / Syncer | 删除会话 |
| `on_total_unread_count_changed` | MessageHandler（receipt.rs / publish_total_unread_count_changed） | 已读回执、批量处理完成后 |
| `on_sync_started/finished/failed/progress` | MessageSyncer | 登录/重连同步流程 |
| `on_user_input_status_changed` | MessageHandler | 收到 typing 消息 |
| `on_update_latest_message_read_state` | MessageService（read.rs） | 已读触发 unreadChangeTrigger |

### 4.3 好友（FriendListener）

| 回调 | 触发模块 | 触发时机 |
|------|---------|---------|
| `on_added` | FriendService | 全量/增量同步 |
| `on_deleted` | FriendService | `delete_friend()` |
| `on_black_added` / `on_black_deleted` | FriendService | `add_black()` / `remove_black()` |
| `on_application_added/accepted/rejected` | NotificationHandler | 好友申请通知（1201/1202/1203） |

### 4.4 群组（GroupListener）

| 回调 | 触发模块 | 触发时机 |
|------|---------|---------|
| `on_application_added/approved/rejected` | NotificationHandler | 入群申请通知（1503/1505/1506） |
| `on_joined_group_added/deleted` | NotificationHandler / GroupService | 群创建、退群/解散通知 |
| `on_group_info_changed` | NotificationHandler | 群信息/群主/禁言等通知同步后 |
| `on_member_added/deleted` | NotificationHandler | 成员邀请/进入/退出/踢出通知 |

### 4.5 用户（UserListener）

| 回调 | 触发模块 | 触发时机 |
|------|---------|---------|
| `on_user_info_updated` | UserService / NotificationHandler | `update_self_user_info()`、1303 用户信息更新通知 |
| `on_user_status_changed` | OnlineStatusService / ConnectionManager | 订阅用户在线状态、WS 2005 在线状态推送 |

### 4.6 消息（MessageListener）

| 回调 | 触发模块 | 触发时机 |
|------|---------|---------|
| `on_new_message` | MessageHandler | 新消息入库后（实时推送/同步/离线） |
| `on_message_revoked` | MessageHandler（revoke.rs） | 收到撤回通知 |
| `on_c2c_read_receipt` | MessageHandler（receipt.rs） | 单聊已读回执 |
| `on_message_deleted` | MessageService（delete.rs） | `apply_local_delete()` |
| `on_send_failed` | OpenIMClient（sdk/client/message.rs） | 消息发送失败并落库 |

---

## 5. 实现状态统计

| 领域 | 已发布 | 已定义未发布（预留） | 未实现 |
|------|--------|-------------------|--------|
| 连接 ConnectionListener | 10 | 0 | 0 |
| 会话 ConversationListener | 9 | 1（new） | 0 |
| 好友 FriendListener | 8 | 1（info_changed） | 0 |
| 群组 GroupListener | 11 | 0 | 0 |
| 用户 UserListener | 2 | 0 | 0 |
| 消息 MessageListener | 7 | 1（upload_progress） | 0 |
| 其他 | — | — | KV/信令/自定义业务/上传回调 |

---

## 6. 外部接入示例

实现一个 Listener trait 并注入（所有方法都有默认实现，只覆写需要的）：

```rust
use rust_lib_flutter_rust_demo::event::events::message::MessageListener;
use rust_lib_flutter_rust_demo::model::message::MessageInfo;
use std::sync::Arc;

struct ExternalSdkSink {
    // 外部 SDK 自己的输出通道
}

impl MessageListener for ExternalSdkSink {
    fn on_new_message(&self, _conversation_id: &str, message: &MessageInfo) {
        // 转发到外部 SDK
    }
    fn on_send_failed(&self, client_msg_id: &str, error: &str) {
        // 处理发送失败
    }
}
```

注册方式：SDK 内部默认注入 `EventHub`（Flutter 流实现）。外部接入需要在
`OpenIMClientBuilder` 上开放 `with_xxx_listener(...)` 注入点（当前尚未开放，按需扩展）：

```rust
let client = OpenIMClientBuilder::new(config)
    .with_message_listener(Arc::new(ExternalSdkSink))
    // .with_connection_listener(...) / .with_conversation_listener(...) 等
    .build()
    .await?;
```
