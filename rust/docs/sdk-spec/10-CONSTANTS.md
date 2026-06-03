# 常量完整参考

> 来源：Go SDK `pkg/constant/constant.go`
> 用途：Rust SDK 重写时的常量对齐参考

---

## 1. WebSocket 请求标识符 (reqIdentifier)

用于 WebSocket 通信中的请求类型标识，客户端与服务端之间通过此值区分不同的消息类型。

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `GetNewestSeq` | 1001 | 获取最新序列号 |
| `PullMsgByRange` | 1002 | 按范围拉取消息 |
| `SendMsg` | 1003 | 发送消息 |
| `SendSignalMsg` | 1004 | 发送信令消息 |
| `PullMsgBySeqList` | 1005 | 按序列号列表拉取消息 |
| `GetConvMaxReadSeq` | 1006 | 获取会话最大已读序列号 |
| `PullConvLastMessage` | 1007 | 拉取会话最后一条消息 |
| `PushMsg` | 2001 | 推送消息（服务端→客户端） |
| `KickOnlineMsg` | 2002 | 踢下线消息 |
| `LogoutMsg` | 2003 | 登出消息 |
| `SetBackgroundStatus` | 2004 | 设置后台状态 |
| `WsSubUserOnlineStatus` | 2005 | 订阅用户在线状态 |

### Rust 实现建议

```rust
pub const GET_NEWEST_SEQ: i32 = 1001;
pub const PULL_MSG_BY_RANGE: i32 = 1002;
pub const SEND_MSG: i32 = 1003;
pub const SEND_SIGNAL_MSG: i32 = 1004;
pub const PULL_MSG_BY_SEQ_LIST: i32 = 1005;
pub const GET_CONV_MAX_READ_SEQ: i32 = 1006;
pub const PULL_CONV_LAST_MESSAGE: i32 = 1007;
pub const PUSH_MSG: i32 = 2001;
pub const KICK_ONLINE_MSG: i32 = 2002;
pub const LOGOUT_MSG: i32 = 2003;
pub const SET_BACKGROUND_STATUS: i32 = 2004;
pub const WS_SUB_USER_ONLINE_STATUS: i32 = 2005;
```

---

## 2. 消息内容类型 (ContentType)

消息体中 `contentType` 字段的取值范围。每种类型对应不同的消息元素结构。

| 常量名 | 值 | 描述 | 消息元素 |
|--------|-----|------|----------|
| `Text` | 101 | 文本消息 | `TextElem` |
| `Picture` | 102 | 图片消息 | `PictureElem` |
| `Sound` | 103 | 语音消息 | `SoundElem` |
| `Video` | 104 | 视频消息 | `VideoElem` |
| `File` | 105 | 文件消息 | `FileElem` |
| `AtText` | 106 | @文本消息 | `AtTextElem` |
| `Merger` | 107 | 合并转发消息 | `MergeElem` |
| `Card` | 108 | 名片消息 | `CardElem` |
| `Location` | 109 | 位置消息 | `LocationElem` |
| `Custom` | 110 | 自定义消息 | `CustomElem` |
| `Typing` | 113 | 输入状态消息 | `TypingElem` |
| `Quote` | 114 | 引用回复消息 | `QuoteElem` |
| `Face` | 115 | 表情消息 | `FaceElem` |
| `AdvancedText` | 117 | 富文本消息 | `AdvancedTextElem` |
| `MarkdownText` | 118 | Markdown 文本消息 | `MarkdownTextElem` |
| `CustomMsgNotTriggerConversation` | 119 | 自定义消息（不触发会话更新） | `CustomElem` |
| `CustomMsgOnlineOnly` | 120 | 自定义消息（仅在线推送，不存离线） | `CustomElem` |

### Rust 实现建议

使用 enum 表示，值与 i32 对齐：

```rust
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum ContentType {
    Text = 101,
    Picture = 102,
    Sound = 103,
    Video = 104,
    File = 105,
    AtText = 106,
    Merger = 107,
    Card = 108,
    Location = 109,
    Custom = 110,
    Typing = 113,
    Quote = 114,
    Face = 115,
    AdvancedText = 117,
    MarkdownText = 118,
    CustomNoTrigger = 119,
    CustomOnlineOnly = 120,
}
```

---

## 3. 通知内容类型 (Notification)

通知消息使用 `contentType` 的 1000-5000 范围。通知消息由系统自动发送，用于同步各类关系变更事件。

### 3.1 基础通知

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `NotificationBegin` | 1000 | 通知类型起始标记 |
| `NotificationEnd` | 5000 | 通知类型结束标记 |

### 3.2 好友相关通知 (1200-1299)

| 常量名 | 值 | 描述 | 对应操作 |
|--------|-----|------|----------|
| `FriendNotificationBegin` | 1200 | 好友通知起始 | - |
| `FriendApplicationApprovedNotification` | 1201 | 好友申请被同意通知 | `add_friend_response` |
| `FriendApplicationRejectedNotification` | 1202 | 好友申请被拒绝通知 | `add_friend_response` |
| `FriendApplicationNotification` | 1203 | 收到好友申请通知 | `add_friend` |
| `FriendAddedNotification` | 1204 | 好友添加成功通知 | - |
| `FriendDeletedNotification` | 1205 | 好友被删除通知 | `delete_friend` |
| `FriendRemarkSetNotification` | 1206 | 好友备注设置通知 | `set_friend_remark` |
| `BlackAddedNotification` | 1207 | 黑名单添加通知 | `add_black` |
| `BlackDeletedNotification` | 1208 | 黑名单移除通知 | `remove_black` |
| `FriendInfoUpdatedNotification` | 1209 | 好友信息更新通知 | - |
| `FriendsInfoUpdateNotification` | 1210 | 批量好友信息更新通知 | - |
| `FriendNotificationEnd` | 1299 | 好友通知结束 | - |
| `ConversationChangeNotification` | 1300 | 会话变更通知 | - |

### 3.3 用户相关通知 (1301-1399)

| 常量名 | 值 | 描述 | 对应操作 |
|--------|-----|------|----------|
| `UserNotificationBegin` | 1301 | 用户通知起始 | - |
| `UserInfoUpdatedNotification` | 1303 | 用户信息更新通知 | `SetSelfInfoTip` |
| `UserStatusChangeNotification` | 1304 | 用户状态变更通知 | - |
| `UserCommandAddNotification` | 1305 | 用户命令添加通知 | - |
| `UserCommandDeleteNotification` | 1306 | 用户命令删除通知 | - |
| `UserCommandUpdateNotification` | 1307 | 用户命令更新通知 | - |
| `UserNotificationEnd` | 1399 | 用户通知结束 | - |

### 3.4 群组相关通知 (1500-1599)

| 常量名 | 值 | 描述 | 对应操作 |
|--------|-----|------|----------|
| `GroupNotificationBegin` | 1500 | 群组通知起始 | - |
| `GroupCreatedNotification` | 1501 | 群组创建通知 | `create_group` |
| `GroupInfoSetNotification` | 1502 | 群组信息设置通知 | `set_group_info_ex` |
| `JoinGroupApplicationNotification` | 1503 | 加入群组申请通知 | `join_group` |
| `MemberQuitNotification` | 1504 | 成员退出通知 | `quit_group` |
| `GroupApplicationAcceptedNotification` | 1505 | 群组申请被接受通知 | `group_application_response` |
| `GroupApplicationRejectedNotification` | 1506 | 群组申请被拒绝通知 | `group_application_response` |
| `GroupOwnerTransferredNotification` | 1507 | 群主转让通知 | `transfer_group` |
| `MemberKickedNotification` | 1508 | 成员被踢出通知 | `kick_group` |
| `MemberInvitedNotification` | 1509 | 成员被邀请通知 | `invite_user_to_group` |
| `MemberEnterNotification` | 1510 | 成员加入通知 | - |
| `GroupDismissedNotification` | 1511 | 群组解散通知 | `dismiss_group` |
| `GroupMemberMutedNotification` | 1512 | 群成员被禁言通知 | `mute_group_member` |
| `GroupMemberCancelMutedNotification` | 1513 | 群成员取消禁言通知 | `cancel_mute_group_member` |
| `GroupMutedNotification` | 1514 | 群组全员禁言通知 | `mute_group` |
| `GroupCancelMutedNotification` | 1515 | 群组取消全员禁言通知 | `cancel_mute_group` |
| `GroupMemberInfoSetNotification` | 1516 | 群成员信息设置通知 | `set_group_member_info` |
| `GroupMemberSetToAdminNotification` | 1517 | 群成员设为管理员通知 | - |
| `GroupMemberSetToOrdinaryUserNotification` | 1518 | 群管理员降为普通成员通知 | - |
| `GroupInfoSetAnnouncementNotification` | 1519 | 群公告设置通知 | - |
| `GroupInfoSetNameNotification` | 1520 | 群名称设置通知 | - |
| `GroupNotificationEnd` | 1599 | 群组通知结束 | - |

### 3.5 会话/消息相关通知

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `ConversationPrivateChatNotification` | 1701 | 会话私聊设置变更通知 |
| `ClearConversationNotification` | 1703 | 清除会话消息通知 |
| `BusinessNotification` | 2001 | 业务通知 |
| `RevokeNotification` | 2101 | 消息撤回通知 |
| `DeleteMsgsNotification` | 2102 | 消息删除通知 |
| `HasReadReceipt` | 2200 | 已读回执通知 |

---

## 4. 会话类型 (SessionType)

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `SingleChatType` | 1 | 单聊 |
| `WriteGroupChatType` | 2 | 可写群聊（暂未启用） |
| `ReadGroupChatType` | 3 | 只读群聊 |
| `NotificationChatType` | 4 | 通知会话（系统消息） |

---

## 5. 消息来源 (MsgFrom)

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `UserMsgType` | 100 | 用户消息 |
| `SysMsgType` | 200 | 系统消息 |

---

## 6. 群组角色级别 (GroupRoleLevel)

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `GroupOwner` | 100 | 群主 |
| `GroupAdmin` | 60 | 管理员 |
| `GroupOrdinaryUsers` | 20 | 普通成员 |

### 群组筛选器

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `GroupFilterAll` | 0 | 所有成员 |
| `GroupFilterOwner` | 1 | 仅群主 |
| `GroupFilterAdmin` | 2 | 仅管理员 |
| `GroupFilterOrdinaryUsers` | 3 | 仅普通成员 |
| `GroupFilterAdminAndOrdinaryUsers` | 4 | 管理员 + 普通成员 |
| `GroupFilterOwnerAndAdmin` | 5 | 群主 + 管理员 |

### 群组申请响应

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `GroupResponseAgree` | 1 | 同意入群申请 |
| `GroupResponseRefuse` | -1 | 拒绝入群申请 |

### 好友申请响应

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `FriendResponseAgree` | 1 | 同意好友申请 |
| `FriendResponseRefuse` | -1 | 拒绝好友申请 |
| `FriendResponseDefault` | 0 | 默认（未处理） |

---

## 7. 同步标志 (SyncFlag)

数据同步过程中的状态通知值，通过 `CmdSyncFlag` 命令下发。

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `MsgSyncBegin` | 1001 | 消息同步开始 |
| `MsgSyncProcessing` | 1002 | 消息同步进行中 |
| `MsgSyncEnd` | 1003 | 消息同步结束 |
| `MsgSyncFailed` | 1004 | 消息同步失败 |
| `AppDataSyncStart` | 1005 | 应用数据同步开始 |
| `AppDataSyncFinish` | 1006 | 应用数据同步完成 |

---

## 8. 消息状态 (MsgStatus)

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `MsgStatusSending` | 1 | 发送中 |
| `MsgStatusSendSuccess` | 2 | 发送成功 |
| `MsgStatusSendFailed` | 3 | 发送失败 |
| `MsgStatusHasDeleted` | 4 | 已删除 |
| `MsgStatusFiltered` | 5 | 已过滤（敏感词等） |

---

## 9. 通道命令 (Cmd)

内部命令标识，用于事件总线通知不同模块。

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `CmdSyncData` | `"syncData"` | 数据同步命令 |
| `CmdSyncFlag` | `"syncFlag"` | 同步状态标志命令 |
| `CmdNotification` | `"notification"` | 通知命令 |
| `CmdMsgSyncInReinstall` | `"msgSyncInReinstall"` | 重装后消息同步命令 |
| `CmdNewMsgCome` | `"newMsgCome"` | 新消息到达命令 |
| `CmdUpdateConversation` | `"updateConversation"` | 更新会话命令 |
| `CmdUpdateMessage` | `"updateMessage"` | 更新消息命令 |
| `CmdPushMsg` | `"pushMsg"` | 推送消息命令 |
| `CmdConnSuccesss` | `"connSuccess"` | 连接成功命令 |
| `CmdWakeUpDataSync` | `"wakeUpDataSync"` | 唤醒数据同步命令 |
| `CmdIMMessageSync` | `"imMessageSync"` | IM 消息同步命令 |
| `CmdLogOut` | `"loginOut"` | 登出命令 |

---

## 10. 消息选项 (OptionsKey)

发送消息时 `options` map 中使用的 key，控制消息的存储和推送行为。

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `IsHistory` | `"history"` | 是否保存到消息漫游历史 |
| `IsPersistent` | `"persistent"` | 是否持久化存储 |
| `IsUnreadCount` | `"unreadCount"` | 是否计入未读数 |
| `IsConversationUpdate` | `"conversationUpdate"` | 是否更新会话（最后一条消息等） |
| `IsOfflinePush` | `"offlinePush"` | 是否进行离线推送 |
| `IsSenderSync` | `"senderSync"` | 发送端是否同步存储 |
| `IsNotPrivate` | `"notPrivate"` | 是否非私密消息（影响阅后即焚等） |
| `IsSenderConversationUpdate` | `"senderConversationUpdate"` | 发送端是否更新会话 |

### Rust 实现建议

```rust
pub struct MsgOptions;

impl MsgOptions {
    pub const IS_HISTORY: &'static str = "history";
    pub const IS_PERSISTENT: &'static str = "persistent";
    pub const IS_UNREAD_COUNT: &'static str = "unreadCount";
    pub const IS_CONVERSATION_UPDATE: &'static str = "conversationUpdate";
    pub const IS_OFFLINE_PUSH: &'static str = "offlinePush";
    pub const IS_SENDER_SYNC: &'static str = "senderSync";
    pub const IS_NOT_PRIVATE: &'static str = "notPrivate";
    pub const IS_SENDER_CONVERSATION_UPDATE: &'static str = "senderConversationUpdate";
}
```

---

## 11. 其他常量

### 11.1 群组状态 (GroupStatus)

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `GroupOk` | 0 | 正常状态 |
| `GroupBanChat` | 1 | 禁止聊天 |
| `GroupStatusDismissed` | 2 | 已解散 |
| `GroupStatusMuted` | 3 | 已禁言 |

### 11.2 群组类型 (GroupType)

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `NormalGroup` | 0 | 普通群 |
| `SuperGroup` | 1 | 超级群（大群） |
| `WorkingGroup` | 2 | 工作群 |

### 11.3 好友/黑名单关系

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `BlackRelationship` | 0 | 黑名单关系 |
| `FriendRelationship` | 1 | 好友关系 |

### 11.4 消息接收选项 (ReceiveMessage Opt)

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `ReceiveMessage` | 0 | 接收消息 |
| `NotReceiveMessage` | 1 | 不接收消息（当前未启用） |
| `ReceiveNotNotifyMessage` | 2 | 接收但不通知 |

### 11.5 在线状态

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `Online` | 1 | 在线 |
| `Offline` | 0 | 离线 |

### 11.6 会话变更类型

用于 UI 层监听会话列表变更时的事件类型区分。

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `AddConOrUpLatMsg` | 1 | 添加或更新最新消息 |
| `TotalUnreadMessageChanged` | 2 | 总未读消息数变更 |
| `UpdateConFaceUrlAndNickName` | 3 | 更新会话头像和昵称 |
| `UpdateLatestMessageReadState` | 4 | 更新最新消息已读状态 |
| `UpdateLatestMessageFaceUrlAndNickName` | 5 | 更新最新消息的头像和昵称 |
| `ConChange` | 6 | 会话变更 |
| `NewCon` | 7 | 新会话 |
| `ConChangeDirect` | 8 | 会话直接变更（不触发列表刷新） |
| `NewConDirect` | 9 | 新会话直接添加 |
| `UpdateMsgFaceUrlAndNickName` | 10 | 更新消息头像和昵称 |

### 11.7 已读状态

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `HasRead` | 1 | 已读 |
| `NotRead` | 0 | 未读 |

### 11.8 @提及模式

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `AtAllString` | `"AtAllTag"` | @所有人的标识字符串 |
| `AtNormal` | 0 | 普通模式 |
| `AtMe` | 1 | 仅@发送者 |
| `AtAll` | 2 | @所有人 |
| `AtAllAtMe` | 3 | @所有人且@发送者 |

### 11.9 关键词匹配模式

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `KeywordMatchOr` | 0 | 匹配任意关键词 |
| `KeywordMatchAnd` | 1 | 匹配所有关键词 |

### 11.10 拉取配置

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `SplitPullMsgNum` | 100 | 分段拉取消息数量 |
| `PullMsgNumForReadDiffusion` | 50 | 已读扩散拉取消息数量 |

### 11.11 其他

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `BigVersion` | `"v3"` | 大版本号标识 |
| `Uninitialized` | `-1001` | 未初始化标记 |

### 11.12 数据库表名前缀

| 常量名 | 值 | 描述 |
|--------|-----|------|
| `SuperGroupErrChatLogsTableNamePre` | `"local_sg_err_chat_logs_"` | 超级群错误消息日志表前缀 |
| `ChatLogsTableNamePre` | `"chat_logs_"` | 消息日志表前缀 |

---

## Rust 实现汇总建议

建议在 `rust/src/protocol/constants.rs` 或 `rust/src/domain/constant/` 下统一管理：

1. **枚举类型**（`SessionType`, `ContentType`, `MsgFrom`, `GroupType` 等）使用 Rust enum + `from_i32()` 方法
2. **i32 常量**（`reqIdentifier`, `MsgStatus`, `SyncFlag` 等）使用 `pub const`
3. **字符串常量**（`Cmd*`, `OptionsKey*`）使用 `pub const &str`
4. 所有 enum 实现 `Clone`, `Copy`, `Debug`, `PartialEq`, `Eq`, `Serialize`, `Deserialize`
5. 所有 enum 实现 `sqlx::Type<sqlx::Sqlite>` 以便直接用于数据库查询

现有 Rust 代码中已实现的 enum 参见 `rust/src/domain/constant/enums.rs`：
- `SessionType`（1-4）
- `ContentType`（101-120）
- `MsgFrom`（100, 200）
- `GroupType`（0-2）
- `MessageSendStatus`（1-4）

**需要补充的常量**：Notification 通知类型、GroupRoleLevel、SyncFlag、OptionsKey、Cmd 命令、会话变更类型、群组筛选器等。
