# 数据模型完整参考

> 来源：Go SDK `pkg/db/model_struct/data_model_struct.go`
> 用途：Rust SDK 重写时的数据模型对齐参考

---

## 目录

1. [LocalChatLog](#1-localchatlog) - 本地聊天记录
2. [LocalConversation](#2-localconversation) - 本地会话
3. [LocalUser](#3-localuser) - 本地用户
4. [LocalFriend](#4-localfriend) - 本地好友
5. [LocalFriendRequest](#5-localfriendrequest) - 本地好友申请
6. [LocalBlack](#6-localblack) - 本地黑名单
7. [LocalGroup](#7-localgroup) - 本地群组
8. [LocalGroupMember](#8-localgroupmember) - 本地群组成员
9. [LocalGroupRequest](#9-localgrouprequest) - 本地群组申请
10. [NotificationSeqs](#10-notificationseqs) - 通知序列号
11. [LocalVersionSync](#11-localversionsync) - 本地同步版本
12. [LocalAppSDKVersion](#12-localappsdkversion) - 本地 SDK 版本
13. [LocalSendingMessages](#13-localsendingmessages) - 本地发送中消息
14. [LocalUpload](#14-localupload) - 本地上传记录

---

## 1. LocalChatLog

**表名**: `local_chat_logs`
**用途**: 存储本地聊天消息记录，包括收发的所有消息。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `client_msg_id` | CHAR(64) | string | ✅ PK | - | 客户端生成的消息 ID |
| `server_msg_id` | CHAR(64) | string | - | - | 服务端生成的消息 ID |
| `send_id` | CHAR(64) | string | - | - | 发送者 ID |
| `recv_id` | CHAR(64) | string | - | `index_recv_id` | 接收者 ID（单聊为用户 ID，群聊为群 ID） |
| `sender_platform_id` | INTEGER | int32 | - | - | 发送者平台 ID |
| `sender_nick_name` | VARCHAR(255) | string | - | - | 发送者昵称 |
| `sender_face_url` | VARCHAR(255) | string | - | - | 发送者头像 URL |
| `session_type` | INTEGER | int32 | - | - | 会话类型 |
| `msg_from` | INTEGER | int32 | - | - | 消息来源（用户/系统） |
| `content_type` | INTEGER | int32 | - | `content_type_alone` | 消息内容类型 |
| `content` | VARCHAR(1000) | string | - | - | 消息内容（JSON 字符串） |
| `is_read` | BOOLEAN | bool | - | - | 是否已读 |
| `status` | INTEGER | int32 | - | - | 消息状态 |
| `seq` | INTEGER | int64 | - | `index_seq` | 消息序列号 |
| `send_time` | INTEGER | int64 | - | `index_send_time` | 发送时间戳 |
| `create_time` | INTEGER | int64 | - | - | 创建时间戳 |
| `attached_info` | VARCHAR(1024) | string | - | - | 附加信息（JSON） |
| `ex` | VARCHAR(1024) | string | - | - | 扩展字段 |
| `local_ex` | VARCHAR(1024) | string | - | - | 本地扩展字段 |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalChatLog {
    pub client_msg_id: String,       // 主键
    pub server_msg_id: String,
    pub send_id: String,
    pub recv_id: String,             // 索引: index_recv_id
    pub sender_platform_id: i32,
    pub sender_nick_name: String,
    pub sender_face_url: String,
    pub session_type: i32,
    pub msg_from: i32,
    pub content_type: i32,           // 索引: content_type_alone
    pub content: String,
    pub is_read: bool,
    pub status: i32,
    pub seq: i64,                    // 索引: index_seq
    pub send_time: i64,              // 索引: index_send_time
    pub create_time: i64,
    pub attached_info: String,
    pub ex: String,
    pub local_ex: String,
}
```

---

## 2. LocalConversation

**表名**: `local_conversations`
**用途**: 存储本地会话信息，包括单聊、群聊、通知会话等。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `conversation_id` | CHAR(128) | string | ✅ PK | - | 会话 ID |
| `conversation_type` | INTEGER | int32 | - | - | 会话类型 |
| `user_id` | CHAR(64) | string | - | - | 用户 ID |
| `group_id` | CHAR(128) | string | - | - | 群组 ID |
| `show_name` | VARCHAR(255) | string | - | - | 显示名称 |
| `face_url` | VARCHAR(255) | string | - | - | 头像 URL |
| `recv_msg_opt` | INTEGER | int32 | - | - | 消息接收选项 |
| `unread_count` | INTEGER | int32 | - | - | 未读消息数 |
| `group_at_type` | INTEGER | int32 | - | - | @消息类型 |
| `latest_msg` | VARCHAR(1000) | string | - | - | 最新消息（JSON） |
| `latest_msg_send_time` | INTEGER | int64 | - | `index_latest_msg_send_time` | 最新消息发送时间 |
| `draft_text` | TEXT | string | - | - | 草稿文本 |
| `draft_text_time` | INTEGER | int64 | - | - | 草稿时间 |
| `is_pinned` | BOOLEAN | bool | - | - | 是否置顶 |
| `is_private_chat` | BOOLEAN | bool | - | - | 是否私聊（阅后即焚） |
| `burn_duration` | INTEGER | int32 | - | - | 阅后即焚持续时间（默认 30 秒） |
| `is_not_in_group` | BOOLEAN | bool | - | - | 是否已不在群中 |
| `update_unread_count_time` | INTEGER | int64 | - | - | 更新未读数的时间 |
| `attached_info` | VARCHAR(1024) | string | - | - | 附加信息 |
| `ex` | VARCHAR(1024) | string | - | - | 扩展字段 |
| `max_seq` | INTEGER | int64 | - | - | 最大序列号 |
| `min_seq` | INTEGER | int64 | - | - | 最小序列号 |
| `msg_destruct_time` | INTEGER | int64 | - | - | 消息销毁时间（默认 604800 秒） |
| `is_msg_destruct` | BOOLEAN | bool | - | - | 是否启用消息销毁 |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalConversation {
    pub conversation_id: String,           // 主键
    pub conversation_type: i32,
    pub user_id: String,
    pub group_id: String,
    pub show_name: String,
    pub face_url: String,
    pub recv_msg_opt: i32,
    pub unread_count: i32,
    pub group_at_type: i32,
    pub latest_msg: String,
    pub latest_msg_send_time: i64,         // 索引: index_latest_msg_send_time
    pub draft_text: String,
    pub draft_text_time: i64,
    pub is_pinned: i32,                    // SQLite 用 i32 表示 bool
    pub is_private_chat: i32,
    pub burn_duration: i32,
    pub is_not_in_group: i32,
    pub update_unread_count_time: i64,
    pub attached_info: String,
    pub ex: String,
    pub max_seq: i64,
    pub min_seq: i64,
    pub is_msg_destruct: i32,
    pub msg_destruct_time: i64,
}
```

---

## 3. LocalUser

**表名**: `local_user`（通过 `TableName()` 推断）
**用途**: 存储用户信息缓存。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `user_id` | VARCHAR(64) | string | ✅ PK | - | 用户 ID |
| `name` | VARCHAR(255) | string | - | - | 昵称 |
| `face_url` | VARCHAR(255) | string | - | - | 头像 URL |
| `create_time` | INTEGER | int64 | - | - | 创建时间 |
| `app_manger_level` | INTEGER | int32 | - | - | 管理员级别 |
| `ex` | VARCHAR(1024) | string | - | - | 扩展字段 |
| `attached_info` | VARCHAR(1024) | string | - | - | 附加信息 |
| `global_recv_msg_opt` | INTEGER | int32 | - | - | 全局消息接收选项 |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalUser {
    pub user_id: String,               // 主键
    pub name: String,
    pub face_url: String,
    pub create_time: i64,
    pub app_manger_level: i32,
    pub ex: String,
    pub attached_info: String,
    pub global_recv_msg_opt: i32,
}
```

---

## 4. LocalFriend

**表名**: `local_friends`
**用途**: 存储好友关系信息。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `owner_user_id` | VARCHAR(64) | string | ✅ PK | - | 当前用户 ID |
| `friend_user_id` | VARCHAR(64) | string | ✅ PK | - | 好友用户 ID |
| `remark` | VARCHAR(255) | string | - | - | 好友备注 |
| `create_time` | INTEGER | int64 | - | - | 创建时间 |
| `add_source` | INTEGER | int32 | - | - | 添加来源 |
| `operator_user_id` | VARCHAR(64) | string | - | - | 操作者 ID |
| `name` | VARCHAR(255) | string | - | - | 好友昵称 |
| `face_url` | VARCHAR(255) | string | - | - | 好友头像 URL |
| `ex` | VARCHAR(1024) | string | - | - | 扩展字段 |
| `attached_info` | VARCHAR(1024) | string | - | - | 附加信息 |
| `is_pinned` | BOOLEAN | bool | - | - | 是否置顶 |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalFriend {
    pub owner_user_id: String,          // 主键 (联合)
    pub friend_user_id: String,         // 主键 (联合)
    pub remark: String,
    pub create_time: i64,
    pub add_source: i32,
    pub operator_user_id: String,
    pub nickname: String,
    pub face_url: String,
    pub ex: String,
    pub attached_info: String,
    pub is_pinned: i32,
}
```

---

## 5. LocalFriendRequest

**表名**: `local_friend_requests`（通过 Go 的 GORM 命名规则推断）
**用途**: 存储好友申请记录。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `from_user_id` | VARCHAR(64) | string | ✅ PK | - | 申请者 ID |
| `from_nickname` | VARCHAR(255) | string | - | - | 申请者昵称 |
| `from_face_url` | VARCHAR(255) | string | - | - | 申请者头像 |
| `to_user_id` | VARCHAR(64) | string | ✅ PK | - | 被申请者 ID |
| `to_nickname` | VARCHAR(255) | string | - | - | 被申请者昵称 |
| `to_face_url` | VARCHAR(255) | string | - | - | 被申请者头像 |
| `handle_result` | INTEGER | int32 | - | - | 处理结果（0=未处理, 1=同意, -1=拒绝） |
| `req_msg` | VARCHAR(255) | string | - | - | 申请消息 |
| `create_time` | INTEGER | int64 | - | - | 创建时间 |
| `handler_user_id` | VARCHAR(64) | string | - | - | 处理者 ID |
| `handle_msg` | VARCHAR(255) | string | - | - | 处理消息 |
| `handle_time` | INTEGER | int64 | - | - | 处理时间 |
| `ex` | VARCHAR(1024) | string | - | - | 扩展字段 |
| `attached_info` | VARCHAR(1024) | string | - | - | 附加信息 |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalFriendRequest {
    pub from_user_id: String,           // 主键 (联合)
    pub from_nickname: String,
    pub from_face_url: String,
    pub to_user_id: String,             // 主键 (联合)
    pub to_nickname: String,
    pub to_face_url: String,
    pub handle_result: i32,
    pub req_msg: String,
    pub create_time: i64,
    pub handler_user_id: String,
    pub handle_msg: String,
    pub handle_time: i64,
    pub ex: String,
    pub attached_info: String,
}
```

---

## 6. LocalBlack

**表名**: `local_blacks`（通过 Go 的 GORM 命名规则推断）
**用途**: 存储黑名单关系。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `owner_user_id` | VARCHAR(64) | string | ✅ PK | - | 当前用户 ID |
| `block_user_id` | VARCHAR(64) | string | ✅ PK | - | 被拉黑用户 ID |
| `nickname` | VARCHAR(255) | string | - | - | 被拉黑用户昵称 |
| `face_url` | VARCHAR(255) | string | - | - | 被拉黑用户头像 |
| `create_time` | INTEGER | int64 | - | - | 创建时间 |
| `add_source` | INTEGER | int32 | - | - | 添加来源 |
| `operator_user_id` | VARCHAR(64) | string | - | - | 操作者 ID |
| `ex` | VARCHAR(1024) | string | - | - | 扩展字段 |
| `attached_info` | VARCHAR(1024) | string | - | - | 附加信息 |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalBlack {
    pub owner_user_id: String,          // 主键 (联合)
    pub block_user_id: String,          // 主键 (联合)
    pub nickname: String,
    pub face_url: String,
    pub create_time: i64,
    pub add_source: i32,
    pub operator_user_id: String,
    pub ex: String,
    pub attached_info: String,
}
```

---

## 7. LocalGroup

**表名**: `local_groups`
**用途**: 存储用户加入的群组信息。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `group_id` | VARCHAR(64) | string | ✅ PK | - | 群组 ID |
| `name` | VARCHAR(255) | string | - | - | 群名称 |
| `notification` | VARCHAR(255) | string | - | - | 群公告 |
| `introduction` | VARCHAR(255) | string | - | - | 群简介 |
| `face_url` | VARCHAR(255) | string | - | - | 群头像 |
| `create_time` | INTEGER | int64 | - | - | 创建时间 |
| `status` | INTEGER | int32 | - | - | 群状态 |
| `creator_user_id` | VARCHAR(64) | string | - | - | 创建者 ID |
| `group_type` | INTEGER | int32 | - | - | 群类型 |
| `owner_user_id` | VARCHAR(64) | string | - | - | 群主 ID |
| `member_count` | INTEGER | int32 | - | - | 成员数 |
| `ex` | VARCHAR(1024) | string | - | - | 扩展字段 |
| `attached_info` | VARCHAR(1024) | string | - | - | 附加信息 |
| `need_verification` | INTEGER | int32 | - | - | 加入是否需要验证 |
| `look_member_info` | INTEGER | int32 | - | - | 是否允许查看成员信息 |
| `apply_member_friend` | INTEGER | int32 | - | - | 是否允许成员互相加好友 |
| `notification_update_time` | INTEGER | int64 | - | - | 公告更新时间 |
| `notification_user_id` | VARCHAR(64) | string | - | - | 公告更新者 ID |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalGroup {
    pub group_id: String,               // 主键
    pub name: String,
    pub notification: String,
    pub introduction: String,
    pub face_url: String,
    pub create_time: i64,
    pub status: i32,
    pub creator_user_id: String,
    pub group_type: i32,
    pub owner_user_id: String,
    pub member_count: i32,
    pub ex: String,
    pub attached_info: String,
    pub need_verification: i32,
    pub look_member_info: i32,
    pub apply_member_friend: i32,
    pub notification_update_time: i64,
    pub notification_user_id: String,
}
```

---

## 8. LocalGroupMember

**表名**: `local_group_members`
**用途**: 存储群组成员信息。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `group_id` | VARCHAR(64) | string | ✅ PK | - | 群组 ID |
| `user_id` | VARCHAR(64) | string | ✅ PK | - | 成员用户 ID |
| `nickname` | VARCHAR(255) | string | - | - | 成员昵称 |
| `user_group_face_url` | VARCHAR(255) | string | - | - | 成员在群内的头像 |
| `role_level` | INTEGER | int32 | - | `index_role_level` | 角色级别（100=群主, 60=管理员, 20=普通） |
| `join_time` | INTEGER | int64 | - | `index_join_time` | 加入时间 |
| `join_source` | INTEGER | int32 | - | - | 加入来源 |
| `inviter_user_id` | VARCHAR(64) | string | - | - | 邀请者 ID |
| `mute_end_time` | INTEGER | int64 | - | - | 禁言结束时间（默认 0） |
| `operator_user_id` | VARCHAR(64) | string | - | - | 操作者 ID |
| `ex` | VARCHAR(1024) | string | - | - | 扩展字段 |
| `attached_info` | VARCHAR(1024) | string | - | - | 附加信息 |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalGroupMember {
    pub group_id: String,               // 主键 (联合)
    pub user_id: String,                // 主键 (联合)
    pub nickname: String,
    pub face_url: String,               // 数据库列名: user_group_face_url
    pub role_level: i32,                // 索引: index_role_level
    pub join_time: i64,                 // 索引: index_join_time
    pub join_source: i32,
    pub inviter_user_id: String,
    pub mute_end_time: i64,
    pub operator_user_id: String,
    pub ex: String,
    pub attached_info: String,
}
```

---

## 9. LocalGroupRequest

**表名**: `local_group_requests`（通过 Go 的 GORM 命名规则推断）
**用途**: 存储群组入群申请记录。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `group_id` | VARCHAR(64) | string | ✅ PK | - | 群组 ID |
| `group_name` | VARCHAR(255) | string | - | - | 群名称 |
| `notification` | VARCHAR(255) | string | - | - | 群公告 |
| `introduction` | VARCHAR(255) | string | - | - | 群简介 |
| `face_url` | VARCHAR(255) | string | - | - | 群头像 |
| `create_time` | INTEGER | int64 | - | - | 创建时间 |
| `status` | INTEGER | int32 | - | - | 群状态 |
| `creator_user_id` | VARCHAR(64) | string | - | - | 创建者 ID |
| `group_type` | INTEGER | int32 | - | - | 群类型 |
| `owner_user_id` | VARCHAR(64) | string | - | - | 群主 ID |
| `member_count` | INTEGER | int32 | - | - | 成员数 |
| `user_id` | VARCHAR(64) | string | ✅ PK | - | 申请者用户 ID |
| `nickname` | VARCHAR(255) | string | - | - | 申请者昵称 |
| `user_face_url` | VARCHAR(255) | string | - | - | 申请者头像 |
| `handle_result` | INTEGER | int32 | - | - | 处理结果 |
| `req_msg` | VARCHAR(255) | string | - | - | 申请消息 |
| `handle_msg` | VARCHAR(255) | string | - | - | 处理消息 |
| `req_time` | INTEGER | int64 | - | - | 申请时间 |
| `handle_user_id` | VARCHAR(64) | string | - | - | 处理者 ID |
| `handle_time` | INTEGER | int64 | - | - | 处理时间 |
| `ex` | VARCHAR(1024) | string | - | - | 扩展字段 |
| `attached_info` | VARCHAR(1024) | string | - | - | 附加信息 |
| `join_source` | INTEGER | int32 | - | - | 加入来源 |
| `inviter_user_id` | VARCHAR(64) | string | - | - | 邀请者 ID |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalGroupRequest {
    pub group_id: String,               // 主键 (联合)
    pub group_name: String,
    pub notification: String,
    pub introduction: String,
    pub face_url: String,
    pub create_time: i64,
    pub status: i32,
    pub creator_user_id: String,
    pub group_type: i32,
    pub owner_user_id: String,
    pub member_count: i32,
    pub user_id: String,                // 主键 (联合)
    pub nickname: String,
    pub user_face_url: String,
    pub handle_result: i32,
    pub req_msg: String,
    pub handle_msg: String,
    pub req_time: i64,
    pub handle_user_id: String,
    pub handle_time: i64,
    pub ex: String,
    pub attached_info: String,
    pub join_source: i32,
    pub inviter_user_id: String,
}
```

---

## 10. NotificationSeqs

**表名**: `local_notification_seqs`
**用途**: 记录每个会话的通知序列号，用于增量同步通知消息。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `conversation_id` | CHAR(128) | string | ✅ PK | - | 会话 ID |
| `seq` | INTEGER | int64 | - | - | 最新通知序列号 |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct NotificationSeqs {
    pub conversation_id: String,        // 主键
    pub seq: i64,
}
```

---

## 11. LocalVersionSync

**表名**: `local_sync_version`
**用途**: 记录每个表/实体的增量同步版本号，用于增量同步。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `table_name` | VARCHAR(255) | string | ✅ PK | - | 表名 |
| `entity_id` | VARCHAR(255) | string | ✅ PK | - | 实体 ID（用户 ID / 群组 ID） |
| `version_id` | VARCHAR(255) | string | - | - | 版本唯一标识（每次全量同步时变化） |
| `version` | INTEGER | uint64 | - | - | 版本号（递增） |
| `create_time` | INTEGER | int64 | - | - | 创建时间 |
| `id_list` | TEXT | StringArray | - | - | 全量同步时的 ID 列表（JSON 数组） |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalVersionSync {
    pub table_name: String,             // 主键 (联合)
    pub entity_id: String,              // 主键 (联合)
    pub version_id: String,
    pub version: i64,
    pub create_time: i64,
    pub uid_list: String,               // JSON 数组，存储为 TEXT
}
```

**注意**: `uid_list` 在 Go 中是 `StringArray` 类型（实现了 `driver.Valuer` 和 `sql.Scanner`），在 Rust 中存储为 JSON 字符串，读写时需要手动序列化/反序列化。

---

## 12. LocalAppSDKVersion

**表名**: `local_app_sdk_version`
**用途**: 记录 SDK 版本信息，用于数据库迁移。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `version` | VARCHAR(255) | string | ✅ PK | - | SDK 版本号 |
| `installed` | BOOLEAN | bool | - | - | 是否已加载/安装 |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalAppSdkVersion {
    pub version: String,                // 主键
    pub installed: i32,                 // SQLite 用 i32 表示 bool
}
```

---

## 13. LocalSendingMessages

**表名**: `local_sending_messages`
**用途**: 记录发送中的消息，用于断线重连后恢复发送状态。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `conversation_id` | CHAR(128) | string | ✅ PK | - | 会话 ID |
| `client_msg_id` | CHAR(64) | string | ✅ PK | - | 客户端消息 ID |
| `ex` | VARCHAR(1024) | string | - | - | 扩展字段 |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalSendingMessages {
    pub conversation_id: String,        // 主键 (联合)
    pub client_msg_id: String,          // 主键 (联合)
    pub ex: String,
}
```

---

## 14. LocalUpload

**表名**: `local_uploads`
**用途**: 记录分片上传信息，用于断点续传。

| 字段名 | 类型 | Go 类型 | 主键 | 索引 | 描述 |
|--------|------|---------|------|------|------|
| `part_hash` | VARCHAR | string | ✅ PK | - | 分片哈希值 |
| `upload_id` | VARCHAR(1000) | string | - | - | 上传任务 ID |
| `upload_info` | VARCHAR(2000) | string | - | - | 上传信息（JSON） |
| `expire_time` | INTEGER | int64 | - | - | 过期时间 |
| `create_time` | INTEGER | int64 | - | - | 创建时间 |

### Rust 等价结构体

```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalUpload {
    pub part_hash: String,              // 主键
    pub upload_id: String,
    pub upload_info: String,
    pub expire_time: i64,
    pub create_time: i64,
}
```

---

## 转换函数参考

Go SDK 中的转换函数定义在 `pkg/converter/` 和 `internal/*/conversion.go` 中。Rust SDK 需要实现等价的转换逻辑。

### 1. ServerConversationToLocal / LocalConversationToServer

**源**: `pkg/converter/conversation.go`

```go
// 服务端 Conversation → 本地 LocalConversation
func ServerConversationToLocal(info *pbConversation.Conversation) *model_struct.LocalConversation {
    return &model_struct.LocalConversation{
        ConversationID:   info.ConversationID,
        ConversationType: info.ConversationType,
        UserID:           info.UserID,
        GroupID:          info.GroupID,
        RecvMsgOpt:       info.RecvMsgOpt,
        GroupAtType:      info.GroupAtType,
        IsPinned:         info.IsPinned,
        BurnDuration:     info.BurnDuration,
        IsPrivateChat:    info.IsPrivateChat,
        AttachedInfo:     info.AttachedInfo,
        Ex:               info.Ex,
        MsgDestructTime:  info.MsgDestructTime,
        IsMsgDestruct:    info.IsMsgDestruct,
    }
}

// 本地 LocalConversation → 服务端 Conversation
func LocalConversationToServer(info *model_struct.LocalConversation) *pbConversation.Conversation { ... }
```

**Rust 实现要点**:
- 服务端类型: `protocol::conversation::Conversation`（来自 proto 生成）
- 本地类型: `LocalConversation`
- `ShowName`、`FaceURL`、`LatestMsg`、`UnreadCount` 等为本地计算字段，不在转换中

### 2. ServerGroupToLocal

**源**: `pkg/converter/group.go`

```go
func ServerGroupToLocal(info *sdkws.GroupInfo) *model_struct.LocalGroup {
    return &model_struct.LocalGroup{
        GroupID:                info.GroupID,
        GroupName:              info.GroupName,
        Notification:           info.Notification,
        Introduction:           info.Introduction,
        FaceURL:                info.FaceURL,
        CreateTime:             info.CreateTime,
        Status:                 info.Status,
        CreatorUserID:          info.CreatorUserID,
        GroupType:              info.GroupType,
        OwnerUserID:            info.OwnerUserID,
        MemberCount:            int32(info.MemberCount),  // 注意类型转换
        Ex:                     info.Ex,
        NeedVerification:       info.NeedVerification,
        LookMemberInfo:         info.LookMemberInfo,
        ApplyMemberFriend:      info.ApplyMemberFriend,
        NotificationUpdateTime: info.NotificationUpdateTime,
        NotificationUserID:     info.NotificationUserID,
    }
}
```

### 3. ServerGroupMemberToLocal

**源**: `pkg/converter/group.go`

```go
func ServerGroupMemberToLocal(info *sdkws.GroupMemberFullInfo) *model_struct.LocalGroupMember {
    return &model_struct.LocalGroupMember{
        GroupID:        info.GroupID,
        UserID:         info.UserID,
        Nickname:       info.Nickname,
        FaceURL:        info.FaceURL,
        RoleLevel:      info.RoleLevel,
        JoinTime:       info.JoinTime,
        JoinSource:     info.JoinSource,
        InviterUserID:  info.InviterUserID,
        MuteEndTime:    info.MuteEndTime,
        OperatorUserID: info.OperatorUserID,
        Ex:             info.Ex,
    }
}
```

### 4. ServerGroupRequestToLocal

**源**: `pkg/converter/group.go`

```go
func ServerGroupRequestToLocal(info *sdkws.GroupRequest) *model_struct.LocalGroupRequest {
    return &model_struct.LocalGroupRequest{
        GroupID:       info.GroupInfo.GroupID,      // 嵌套在 GroupInfo 中
        GroupName:     info.GroupInfo.GroupName,
        // ... 其他群组字段从 info.GroupInfo 中获取
        UserID:        info.UserInfo.UserID,         // 嵌套在 UserInfo 中
        Nickname:      info.UserInfo.Nickname,
        UserFaceURL:   info.UserInfo.FaceURL,
        HandleResult:  info.HandleResult,
        // ... 其他处理字段
    }
}
```

**注意**: `GroupRequest` 中的群组信息和用户信息是嵌套结构，转换时需要分别提取。

### 5. ServerFriendToLocal

**源**: `pkg/converter/relation.go`

```go
func ServerFriendToLocal(info *sdkws.FriendInfo) *model_struct.LocalFriend {
    return &model_struct.LocalFriend{
        OwnerUserID:    info.OwnerUserID,
        FriendUserID:   info.FriendUser.UserID,   // 嵌套在 FriendUser 中
        Remark:         info.Remark,
        CreateTime:     info.CreateTime,
        AddSource:      info.AddSource,
        OperatorUserID: info.OperatorUserID,
        Nickname:       info.FriendUser.Nickname,  // 嵌套在 FriendUser 中
        FaceURL:        info.FriendUser.FaceURL,   // 嵌套在 FriendUser 中
        Ex:             info.Ex,
        IsPinned:       info.IsPinned,
    }
}
```

**注意**: `FriendInfo` 中用户信息嵌套在 `FriendUser` 字段中。

### 6. ServerBlackToLocal

**源**: `pkg/converter/relation.go`

```go
func ServerBlackToLocal(info *sdkws.BlackInfo) *model_struct.LocalBlack {
    return &model_struct.LocalBlack{
        OwnerUserID:    info.OwnerUserID,
        BlockUserID:    info.BlackUserInfo.UserID,  // 嵌套在 BlackUserInfo 中
        CreateTime:     info.CreateTime,
        AddSource:      info.AddSource,
        OperatorUserID: info.OperatorUserID,
        Nickname:       info.BlackUserInfo.Nickname,
        FaceURL:        info.BlackUserInfo.FaceURL,
        Ex:             info.Ex,
    }
}
```

### 7. ServerFriendRequestToLocal

**源**: `pkg/converter/relation.go`

```go
func ServerFriendRequestToLocal(info *sdkws.FriendRequest) *model_struct.LocalFriendRequest {
    return &model_struct.LocalFriendRequest{
        FromUserID:    info.FromUserID,
        FromNickname:  info.FromNickname,
        FromFaceURL:   info.FromFaceURL,
        ToUserID:      info.ToUserID,
        ToNickname:    info.ToNickname,
        ToFaceURL:     info.ToFaceURL,
        HandleResult:  info.HandleResult,
        ReqMsg:        info.ReqMsg,
        CreateTime:    info.CreateTime,
        HandlerUserID: info.HandlerUserID,
        HandleMsg:     info.HandleMsg,
        HandleTime:    info.HandleTime,
        Ex:            info.Ex,
    }
}
```

### 8. ServerUserToLocal

**源**: `pkg/converter/user.go`

```go
func ServerUserToLocal(info *sdkws.UserInfo) *model_struct.LocalUser {
    return &model_struct.LocalUser{
        UserID:           info.UserID,
        Nickname:         info.Nickname,
        FaceURL:          info.FaceURL,
        CreateTime:       info.CreateTime,
        Ex:               info.Ex,
        GlobalRecvMsgOpt: info.GlobalRecvMsgOpt,
    }
}
```

### 9. MsgDataToLocalChatLog

**源**: `pkg/converter/conversation.go`

```go
func MsgDataToLocalChatLog(info *sdkws.MsgData) *model_struct.LocalChatLog {
    local := &model_struct.LocalChatLog{
        ClientMsgID:      info.ClientMsgID,
        ServerMsgID:      info.ServerMsgID,
        SendID:           info.SendID,
        RecvID:           info.RecvID,
        SenderPlatformID: info.SenderPlatformID,
        SenderNickname:   info.SenderNickname,
        SenderFaceURL:    info.SenderFaceURL,
        SessionType:      info.SessionType,
        MsgFrom:          info.MsgFrom,
        ContentType:      info.ContentType,
        Content:          string(info.Content),  // []byte → String
        IsRead:           info.IsRead,
        Seq:              info.Seq,
        SendTime:         info.SendTime,
        CreateTime:       info.CreateTime,
        AttachedInfo:     info.AttachedInfo,
        Ex:               info.Ex,
    }
    // 特殊处理：如果 status >= MsgStatusHasDeleted，保持原值；否则设为 SendSuccess
    if info.Status >= constant.MsgStatusHasDeleted {
        local.Status = info.Status
    } else {
        local.Status = constant.MsgStatusSendSuccess
    }
    // 群聊消息：RecvID 使用 GroupID
    if info.SessionType == constant.WriteGroupChatType || info.SessionType == constant.ReadGroupChatType {
        local.RecvID = info.GroupID
    }
    return local
}
```

### 10. LocalChatLogToMsgStruct

**源**: `pkg/converter/conversation.go`

```go
func LocalChatLogToMsgStruct(local *model_struct.LocalChatLog) *sdk_struct.MsgStruct {
    msg := &sdk_struct.MsgStruct{
        ClientMsgID:      local.ClientMsgID,
        ServerMsgID:      local.ServerMsgID,
        // ... 直接映射字段
    }
    // 根据 ContentType 反序列化 Content JSON 到对应的消息元素
    PopulateMsgStructByContentType(msg)
    // 群聊消息：GroupID 使用 RecvID
    switch local.SessionType {
    case constant.WriteGroupChatType, constant.ReadGroupChatType:
        msg.GroupID = local.RecvID
    }
    return msg
}
```

### 11. MsgStructToLocalChatLog

**源**: `pkg/converter/conversation.go`

```go
func MsgStructToLocalChatLog(message *sdk_struct.MsgStruct) *model_struct.LocalChatLog {
    local := &model_struct.LocalChatLog{
        // ... 直接映射字段
    }
    // 根据 ContentType 序列化对应的消息元素到 Content JSON
    switch message.ContentType {
    case constant.Text:
        local.Content = utils.StructToJsonString(message.TextElem)
    // ... 其他类型
    }
    // 群聊消息：RecvID 使用 GroupID
    if message.SessionType == constant.WriteGroupChatType || message.SessionType == constant.ReadGroupChatType {
        local.RecvID = message.GroupID
    }
    local.AttachedInfo = utils.StructToJsonString(message.AttachedInfoElem)
    return local
}
```

### 12. MsgStructToMsgData

**源**: `pkg/converter/conversation.go`

```go
func MsgStructToMsgData(message *sdk_struct.MsgStruct, options map[string]bool) *sdkws.MsgData {
    data := &sdkws.MsgData{
        SendID:           message.SendID,
        RecvID:           message.RecvID,
        GroupID:          message.GroupID,
        ClientMsgID:      message.ClientMsgID,
        // ... 直接映射字段
        Content:          []byte(message.Content),  // String → []byte
        Options:          options,
    }
    // 如果有 @用户列表，从 AtTextElem 中提取
    if atElem := message.AtTextElem; atElem != nil && len(atElem.AtUserList) > 0 {
        data.AtUserIDList = append([]string(nil), atElem.AtUserList...)
    }
    return data
}
```

### 13. PopulateMsgStructByContentType

**源**: `pkg/converter/conversation.go`

根据 `ContentType` 将 `Content` JSON 字符串反序列化到对应的 `MsgStruct` 元素字段：

| ContentType | 目标字段 | 元素类型 |
|-------------|----------|----------|
| Text (101) | `TextElem` | `TextElem` |
| Picture (102) | `PictureElem` | `PictureElem` |
| Sound (103) | `SoundElem` | `SoundElem` |
| Video (104) | `VideoElem` | `VideoElem` |
| File (105) | `FileElem` | `FileElem` |
| AtText (106) | `AtTextElem` | `AtTextElem` |
| Merger (107) | `MergeElem` | `MergeElem` |
| Card (108) | `CardElem` | `CardElem` |
| Location (109) | `LocationElem` | `LocationElem` |
| Custom/119/120 | `CustomElem` | `CustomElem` |
| Typing (113) | `TypingElem` | `TypingElem` |
| Quote (114) | `QuoteElem` | `QuoteElem` |
| Face (115) | `FaceElem` | `FaceElem` |
| AdvancedText (117) | `AdvancedTextElem` | `AdvancedTextElem` |
| MarkdownText (118) | `MarkdownTextElem` | `MarkdownTextElem` |
| 其他 | `NotificationElem` | `NotificationElem` |

---

## Rust 实现建议

1. 所有模型使用 `#[derive(Debug, Clone, FromRow)]`
2. 布尔字段在 SQLite 中存储为 `INTEGER`（0/1），Rust 中使用 `i32`
3. 联合主键使用 `sqlx` 的 `PRIMARY KEY (col1, col2)` 语法
4. `content` 字段使用 `VARCHAR(1000)` 限制长度
5. 扩展字段统一使用 `VARCHAR(1024)` 或 `TEXT`
6. `uid_list`（`LocalVersionSync`）使用 `TEXT` 存储 JSON 数组，读写时手动序列化
