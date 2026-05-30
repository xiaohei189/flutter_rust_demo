# OpenIMClient 重构计划：添加业务方法，完成门面模式

## 问题

`OpenIMClient` 目前仅提供 6 个生命周期方法（`new`、`connect`、`disconnect`、`login`、`logout`、`event_bus`），所有业务操作都需要通过直接访问其 `pub` 内部管理器字段实现。这导致：
- 封装性差，外部代码依赖内部结构
- `OpenIMBridgeClient` 中存在大量重复的转发逻辑
- 不符合门面模式的设计初衷

## 目标

让 `OpenIMClient` 真正成为统一的 API 门面，包含所有业务方法。

---

## 步骤 1：给 `OpenIMClient` 添加所有业务方法

### 1.1 添加消息相关方法

| 方法 | 来源（bridge_client.rs） | 说明 |
|------|--------------------------|------|
| `send_message` | L179-L215 | 发送消息 |
| `get_history_messages` | L219-L250 | 获取历史消息 |
| `revoke_message` | L254-L265 | 撤回消息 |
| `delete_messages` | L269-L275 | 删除消息 |
| `mark_messages_as_read` | L279-L290 | 标记已读 |
| `search_local_messages` | L294-L304 | 本地搜索消息 |

### 1.2 添加会话相关方法

| 方法 | 来源（bridge_client.rs） | 说明 |
|------|--------------------------|------|
| `get_conversations` | L310-L313 | 获取所有会话 |
| `get_conversation` | L317-L320 | 获取单个会话 |
| `update_conversation_unread_count` | L324-L330 | 更新未读数 |
| `set_conversation_pinned` | L334-L340 | 设置置顶 |
| `delete_conversation` | L344-L350 | 删除会话 |
| `set_conversation_draft` | L354-L360 | 设置草稿 |
| `set_conversation_private` | L364-L370 | 设置私聊模式 |

### 1.3 添加好友相关方法

| 方法 | 来源（bridge_client.rs） | 说明 |
|------|--------------------------|------|
| `get_friend_list` | L376-L378 | 获取好友列表 |
| `add_friend` | L382-L384 | 添加好友 |
| `delete_friend` | L388-L390 | 删除好友 |
| `get_black_list` | L394-L396 | 获取黑名单 |
| `is_friend` | L400-L402 | 判断是否为好友 |
| `add_black` | L406-L408 | 添加黑名单 |
| `remove_black` | L412-L414 | 移除黑名单 |
| `get_friend_apply_list` | L418-L428 | 好友申请列表 |
| `accept_friend_application` | L432-L434 | 接受好友申请 |
| `refuse_friend_application` | L438-L440 | 拒绝好友申请 |

### 1.4 添加群组相关方法

| 方法 | 来源（bridge_client.rs） | 说明 |
|------|--------------------------|------|
| `get_group_list` | L446-L448 | 获取群组列表 |
| `create_group` | L452-L470 | 创建群组 |
| `join_group` | L474-L476 | 加入群组 |
| `quit_group` | L480-L482 | 退出群组 |
| `get_group_members` | L486-L492 | 获取群成员 |
| `invite_group_members` | L496-L502 | 邀请成员 |
| `kick_group_members` | L506-L512 | 踢出成员 |
| `get_groups_info` | L516-L518 | 获取群信息 |
| `set_group_info` | L522-L535 | 设置群信息 |
| `get_group_members_info` | L539-L543 | 获取成员信息 |
| `dismiss_group` | L547-L549 | 解散群组 |
| `get_group_application_list` | L553-L563 | 群申请列表 |
| `accept_group_application` | L567-L569 | 接受群申请 |
| `refuse_group_application` | L573-L575 | 拒绝群申请 |

### 1.5 添加用户相关方法

| 方法 | 来源（bridge_client.rs） | 说明 |
|------|--------------------------|------|
| `get_users_info` | L581-L583 | 获取用户信息 |
| `update_user_profile` | L587-L600 | 更新用户资料 |

### 1.6 添加辅助（getter）方法

- `user_id() -> String` — 获取当前用户 ID
- `platform_id() -> i32` — 获取平台 ID
- `subscribe_events(...)` — 事件订阅（用于替换 `event_stream`）

---

## 步骤 2：简化 `OpenIMBridgeClient`

将 `bridge_client.rs` 中所有方法改为直接调用 `self.inner.<method>()`：

**之前：**
```rust
pub async fn add_friend(&self, user_id: String, req_msg: String) -> Result<()> {
    map_err(self.inner.friend.add_friend(user_id, Some(req_msg)).await)
}
```

**之后：**
```rust
pub async fn add_friend(&self, user_id: String, req_msg: String) -> Result<()> {
    self.inner.add_friend(user_id, req_msg).await
}
```

> `map_err` 辅助函数也可以随之移除。

---

## 步骤 3：将 `OpenIMClient` 字段改为非 `pub`

将 `client.rs` 中的结构体字段从 `pub` 改为非 `pub`（私有），防止外部直接访问管理器。

需要确保：
1. `event_bus` 已有 `pub fn event_bus()` getter，可以去掉 `pub`
2. `context` 需要添加 getter 方法暴露 `user_id`、`platform_id` 等必要属性
3. 其他管理器字段（`connection`, `user`, `friend`, `group`, `conversation`, `message_sender` 等）全部改为非 `pub`

> **注意**：如果某些外部代码（如测试）确实需要直接访问管理器，可以先保留 `pub`，待后续逐步收敛。

---

## 步骤 4：更新测试代码

将测试代码中形如 `sdk.friend.add_friend(...)` 的调用改为 `sdk.add_friend(...)`。

涉及文件：
- `tests/friend_tests.rs` — `sdk.friend.*` 调用
- `tests/group_tests.rs` — `sdk.group.*` 调用
- `tests/conversation_tests.rs` — `sdk.conversation.*` 调用
- `tests/user_tests.rs` — `sdk.user.*` 调用
- `tests/connection_tests.rs` — 相关调用

---

## 风险与注意事项

1. **`context.user_id` 的锁访问**：`bridge_client.rs` 中 `send_message` 等方法直接 `self.inner.context.user_id.lock().unwrap()`。需要通过 `OpenIMClient` 的 getter 方法替代。
2. **`message_handler.message_dao()` 的访问**：`get_history_messages` 中通过此方式获取 DAO。需要改为 `OpenIMClient` 方法封装。
3. **`conversation.dao()` 的访问**：`get_conversations` 和 `get_conversation` 中通过此方式获取 DAO。同样需要封装。
4. **方法签名变动**：`OpenIMClient` 的方法签名可能与 `OpenIMBridgeClient` 的 FRB 方法签名略有不同（如入参类型不同），需要适配。

---

## 验收标准

- [ ] `cargo check` 通过
- [ ] `cargo test` 通过
- [ ] 所有业务方法都在 `OpenIMClient` 上可调用
- [ ] `OpenIMBridgeClient` 中的每个方法都是一行转发调用
- [ ] 字段可见性降低（至少核心管理器字段不再 `pub`）
