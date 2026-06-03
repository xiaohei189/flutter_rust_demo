# 08 - 群组模块（Group）详细设计

> 对标 Go SDK: `internal/group/`
> 本文档为 Rust SDK 重写提供完整的设计参考，涵盖结构体定义、方法列表、同步机制、通知处理、数据库表结构及与当前 Rust 实现的差距分析。

---

## 1. 模块职责

群组模块负责管理用户参与的群组及其成员关系，是 IM SDK 中最复杂的模块之一。主要职责包括：

- **群组 CRUD**：创建、获取、更新、解散群组
- **群成员管理**：邀请、踢出、设置成员信息、角色管理（群主/管理员/普通成员）
- **群申请流程**：加入申请、接受/拒绝、获取申请列表
- **群组增量同步**：双层同步（群组列表 + 群成员）
- **群通知处理**：处理 20 种群组相关通知消息
- **群成员缓存**：基于 LRU 的成员信息缓存
- **通知去重**：基于 NotificationFilter 的 UUID 去重

---

## 2. Go SDK 对标文件

| 文件 | 职责 |
|------|------|
| `group.go` | 结构体定义、Syncer 初始化 |
| `api.go` | 公开 API 方法 |
| `server_api.go` | HTTP API 调用封装 |
| `incremental_sync.go` | 增量同步（VersionSynchronizer） |
| `full_sync.go` | 全量同步 |
| `notification.go` | 通知消息处理（20 种） |
| `conversion.go` | Server 模型 ↔ 本地模型转换 |
| `filter.go` | NotificationFilter 去重实现 |
| `cache.go` | 群成员缓存 + DataFetcher 集成 |

---

## 3. Group 结构体字段

```go
type Group struct {
    listener               func() OnGroupListener                                   // 群组事件监听器
    loginUserID            string                                                   // 当前登录用户 ID
    db                     db_interface.DataBase                                     // 数据库接口
    groupSyncer            *Syncer[*LocalGroup, GetJoinedGroupListResp, string]      // 群组同步器
    groupMemberSyncer      *Syncer[*LocalGroupMember, GetGroupMemberListResp, [2]string] // 群成员同步器
    conversationEventQueue chan common.Cmd2Value                                     // 会话事件队列
    groupSyncMutex         sync.Mutex                                               // 群组同步互斥锁
    listenerForService     OnListenerForService                                     // 服务层监听器
    groupMemberCache       *Cache[string, *LocalGroupMember]                        // 群成员缓存
    groupInfoCache         *Cache[string, *LocalGroup]                              // 群信息缓存
    filter                 *NotificationFilter                                      // 通知去重过滤器
}
```

### Rust 对应结构体设计

```rust
pub struct GroupManager {
    db: Arc<SqlitePool>,                                    // SQLite 连接池
    user_id: Arc<RwLock<String>>,                           // 当前登录用户 ID
    event_bus: Arc<EventBus>,                               // 事件总线
    sync_mutex: Arc<tokio::sync::Mutex<()>>,                // 群组同步互斥锁
    group_dao: GroupDao,                                    // 群组 DAO
    sync_version_dao: SyncVersionDao,                       // 版本同步 DAO
    group_info_cache: Arc<RwLock<LruCache<String, LocalGroup>>>,      // 群信息 LRU 缓存
    group_member_cache: Arc<RwLock<LruCache<String, LocalGroupMember>>>, // 群成员 LRU 缓存
    notification_filter: Arc<tokio::sync::Mutex<NotificationFilter>>,    // 通知去重过滤器
}
```

---

## 4. 完整方法列表

### 4.1 群组 CRUD

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `CreateGroup` | `(ctx, req *CreateGroupReq) (*GroupInfo, error)` | 创建群组（操作后 IncrSyncJoinGroup + IncrSyncGroupAndMember） |
| `GetJoinedGroupList` | `(ctx) ([]*LocalGroup, error)` | 获取已加入的群组列表 |
| `GetJoinedGroupListPage` | `(ctx, offset, count int32) ([]*LocalGroup, error)` | 分页获取已加入的群组 |
| `GetSpecifiedGroupsInfo` | `(ctx, groupIDs []string) ([]*LocalGroup, error)` | 获取指定群组信息（本地优先 + 服务端补全） |
| `GetSpecifiedGroupsInfoSafe` | `(ctx, groupIDs []string) ([]*LocalGroup, error)` | 安全版本（不写入本地存储） |
| `SearchGroups` | `(ctx, param SearchGroupsParam) ([]*LocalGroup, error)` | 搜索群组（按群名/群ID搜索） |
| `SetGroupInfo` | `(ctx, groupInfo *SetGroupInfoExReq) error` | 设置群组信息（操作后 IncrSyncJoinGroup） |
| `FetchGroupOrError` | `(ctx, groupID string) (*LocalGroup, error)` | 获取群组信息，不存在时返回错误 |

### 4.2 群成员管理

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `GetGroupMemberList` | `(ctx, groupID string, filter, offset, count int32) ([]*LocalGroupMember, error)` | 获取群成员列表（支持角色过滤） |
| `GetGroupMemberListByJoinTimeFilter` | `(ctx, groupID, offset, count, joinTimeBegin, joinTimeEnd, userIDs) ([]*LocalGroupMember, error)` | 按加入时间过滤群成员 |
| `GetSpecifiedGroupMembersInfo` | `(ctx, groupID, userIDList) ([]*LocalGroupMember, error)` | 获取指定群成员信息 |
| `GetGroupMemberOwnerAndAdmin` | `(ctx, groupID) ([]*LocalGroupMember, error)` | 获取群主和管理员列表 |
| `SearchGroupMembers` | `(ctx, searchParam) ([]*LocalGroupMember, error)` | 搜索群成员 |
| `SetGroupMemberInfo` | `(ctx, info *SetGroupMemberInfo) error` | 设置群成员信息（操作后 IncrSyncGroupAndMember） |
| `KickGroupMember` | `(ctx, groupID, reason, userIDList) error` | 踢出群成员（操作后 IncrSyncGroupAndMember） |
| `InviteUserToGroup` | `(ctx, groupID, reason, userIDList) error` | 邀请用户入群（操作后 IncrSyncGroupAndMember） |
| `TransferGroupOwner` | `(ctx, groupID, newOwnerUserID) error` | 转让群主（操作后 IncrSyncGroupAndMember） |
| `ChangeGroupMemberMute` | `(ctx, groupID, userID, mutedSeconds) error` | 设置/取消群成员禁言 |
| `IsJoinGroup` | `(ctx, groupID) (bool, error)` | 检查是否已加入群组 |
| `GetUsersInGroup` | `(ctx, groupID, userIDList) ([]string, error)` | 检查指定用户是否在群组中 |

### 4.3 群组操作

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `JoinGroup` | `(ctx, groupID, reqMsg, joinSource, ex) error` | 申请加入群组 |
| `QuitGroup` | `(ctx, groupID) error` | 退出群组（操作后 IncrSyncJoinGroup） |
| `DismissGroup` | `(ctx, groupID) error` | 解散群组（操作后 IncrSyncJoinGroup） |
| `ChangeGroupMute` | `(ctx, groupID, isMute) error` | 设置/取消群组全局禁言（操作后 IncrSyncGroupAndMember） |

### 4.4 群申请

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `GetGroupApplicationListAsRecipient` | `(ctx, req) ([]*LocalGroupRequest, error)` | 获取收到的入群申请列表 |
| `GetGroupApplicationListAsApplicant` | `(ctx, req) ([]*LocalGroupRequest, error)` | 获取自己发出的入群申请列表 |
| `AcceptGroupApplication` | `(ctx, groupID, fromUserID, handleMsg) error` | 接受入群申请 |
| `RefuseGroupApplication` | `(ctx, groupID, fromUserID, handleMsg) error` | 拒绝入群申请 |
| `HandlerGroupApplication` | `(ctx, req) error` | 处理入群申请（内部方法） |
| `GetGroupApplicationUnhandledCount` | `(ctx, req) (int32, error)` | 获取未处理的入群申请数量 |

### 4.5 同步

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `IncrSyncJoinGroup` | `(ctx) error` | 群组列表增量同步 |
| `IncrSyncGroupAndMember` | `(ctx, groupIDs ...string) error` | 群组+成员增量同步（批量） |
| `IncrSyncJoinGroupMember` | `(ctx) error` | 所有已加入群组的成员增量同步 |
| `SyncAllJoinedGroupsAndMembersWithLock` | `(ctx) error` | 全量同步群组+成员（加锁版本） |

### 4.6 缓存相关

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `GetGroupMembersInfo` | `(ctx, groupID, userIDs) (map[string]*LocalGroupMember, error)` | 带缓存的群成员信息获取 |
| `GetGroupMembersInfoFunc` | `(ctx, groupID, userIDs, fetchFunc) (map, error)` | 自定义获取函数的缓存版本 |

### 4.7 检查

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `CheckLocalGroupFullSync` | `(ctx) (bool, error)` | 检查本地群组是否已全量同步 |
| `CheckGroupMemberFullSync` | `(ctx, groupID) (bool, error)` | 检查指定群组成员是否已全量同步 |

---

## 5. groupSyncer + groupMemberSyncer 配置

### 5.1 groupSyncer

```go
groupSyncer = syncer.New2[*LocalGroup, GetJoinedGroupListResp, string](
    UUID: func(value *LocalGroup) string {
        return value.GroupID
    },
    Insert: db.InsertGroup(ctx, value) + groupInfoCache.Store,
    Delete: db.DeleteGroupAllMembers + db.DeleteVersionSync + db.DeleteGroup + groupInfoCache.Delete,
    Update: db.UpdateGroup(ctx, server) + groupInfoCache.Store,
    BatchInsert: db.BatchInsertGroup + groupInfoCache.StoreAll,
    DeleteAll: groupInfoCache.DeleteAll + db.DeleteAllGroup,
    Notice: {
        Insert → OnJoinedGroupAdded + 更新会话头像昵称
        Delete → OnJoinedGroupDeleted
        Update → 若解散: OnGroupDismissed + 删除所有成员
                 若更新: OnGroupInfoChanged + 更新会话头像昵称
    },
    FullSyncLimit: 1000,
    PageReq: GetJoinedGroupListReq{FromUserID, ShowNumber: 100},
    PageRespConvert: ServerGroupToLocalGroup,
    ReqApiRouter: api.GetJoinedGroupList.Route(),
)
```

### 5.2 groupMemberSyncer

```go
groupMemberSyncer = syncer.New2[*LocalGroupMember, GetGroupMemberListResp, [2]string](
    UUID: func(value *LocalGroupMember) [2]string {
        return [...]string{value.GroupID, value.UserID}
    },
    Insert: db.InsertGroupMember(ctx, value),
    Delete: db.DeleteGroupMember(ctx, value.GroupID, value.UserID),
    Update: groupMemberCache.Delete(key) + db.UpdateGroupMember(ctx, server),
    BatchInsert: db.BatchInsertGroupMember,
    DeleteAll: db.DeleteGroupAllMembers(ctx, groupID),
    Notice: {
        Insert → OnGroupMemberAdded + 更新消息头像昵称
        Delete → OnGroupMemberDeleted
        Update → OnGroupMemberInfoChanged + 更新消息/会话头像昵称
    },
    FullSyncLimit: 1000,
    PageReq: GetGroupMemberListReq{GroupID, ShowNumber: 100},
    PageRespConvert: ServerGroupMemberToLocalGroupMember,
    ReqApiRouter: api.GetGroupMemberList.Route(),
)
```

---

## 6. 增量同步流程

### 6.1 IncrSyncJoinGroup（群组列表增量同步）

```
1. 从 local_sync_version 表读取当前 version 和 versionID（key=loginUserID, table=local_groups）
2. 调用 getIncrementalJoinGroup API
3. 如果 resp.Full == true → 执行 groupSyncer.FullSync（全量同步）
4. 否则执行增量同步：
   a. 处理 resp.Delete 中的群组（触发 groupSyncer.Sync）
   b. 处理 resp.Insert 和 resp.Update 中的群组
5. 更新 version/versionID
```

### 6.2 IncrSyncGroupAndMember（群组+成员增量同步）

```
1. 遍历需要同步的 groupID 列表
2. 对每个 groupID：
   a. 从 local_sync_version 读取该群组成员的 version（table=local_group_entities_version）
   b. 构建 GetIncrementalGroupMemberReq
3. 批量调用 getIncrementalGroupMemberBatch API（每次最多 MaxSyncPullNumber 个）
4. 对每个群组的响应：
   a. 调用 syncGroupAndMember 执行增量同步
   b. 处理 ExtraData（群组信息变更）
   c. 处理 SortVersion 变化
5. 如果还有未同步的群组，继续下一批
```

### 6.3 syncGroupAndMember（单个群组成员同步）

```
1. 创建 VersionSynchronizer（与好友增量同步类似）
2. 如果 resp.Full == true → groupMemberSyncer.FullSync
3. 否则增量处理 Insert/Update/Delete
4. 处理 ExtraData（群组信息更新）→ 同步到 groupSyncer
5. 处理 SortVersion 变化
```

### 6.4 onlineSyncGroupAndMember（在线同步）

```
当收到群通知时，直接使用通知中的数据进行同步，无需再次请求服务端：
1. 构建 VersionSynchronizer，使用 ServerVersion 而非 Server 回调
2. 调用 CheckVersionSync（而非 IncrementalSync）
3. 传入通知中的 delete/update/insert 数据和群组信息
```

---

## 7. NotificationFilter 去重

### 7.1 实现

```go
type NotificationFilter struct {
    lock    sync.Mutex
    data    *simplelru.LRU[string, time.Time]  // UUID → 上次执行时间
    timeout time.Duration                        // 10 秒超时
}

func (f *NotificationFilter) ShouldExecute(uuid string) bool {
    f.lock.Lock()
    defer f.lock.Unlock()
    now := time.Now()
    if last, exists := f.data.Get(uuid); exists && now.Sub(last) <= f.timeout {
        return false  // 10 秒内重复 UUID，不执行
    }
    f.data.Add(uuid, now)
    return true
}
```

### 7.2 配置

```go
const (
    NotificationFilterCacheSize = 1024   // LRU 缓存容量
    NotificationFilterTimeout   = 10 * time.Second  // 去重超时
)
```

### 7.3 应用场景

仅用于以下 3 种通知（因为这些通知由服务端转发，可能重复到达）：

| 通知类型 | 值 | 说明 |
|----------|-----|------|
| `JoinGroupApplicationNotification` | 1503 | 入群申请通知 |
| `GroupApplicationAcceptedNotification` | 1505 | 入群申请被接受 |
| `GroupApplicationRejectedNotification` | 1506 | 入群申请被拒绝 |

### 7.4 Rust 实现建议

```rust
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
        if let Some(&last) = self.data.peek(uuid) {
            if now.duration_since(last) <= self.timeout {
                return false;
            }
        }
        self.data.put(uuid.to_string(), now);
        true
    }
}
```

---

## 8. 所有 20 种群通知处理表

| 编号 | 常量名 | 值 | Tips 类型 | 处理逻辑 | 同步方式 |
|------|--------|-----|-----------|----------|----------|
| 1 | `GroupCreatedNotification` | 1501 | `GroupCreatedTips` | 同步群组列表 + 成员 | `IncrSyncJoinGroup` + `IncrSyncGroupAndMember` |
| 2 | `GroupInfoSetNotification` | 1502 | `GroupInfoSetTips` | 同步群组信息 | `onlineSyncGroupAndMember` |
| 3 | `JoinGroupApplicationNotification` | 1503 | `JoinGroupApplicationTips` | 通知 + 去重 | `OnGroupApplicationAdded` + filter |
| 4 | `MemberQuitNotification` | 1504 | `MemberQuitTips` | 若自己退出→同步群列表；否则同步成员 | `IncrSyncJoinGroup` 或 `onlineSyncGroupAndMember` |
| 5 | `GroupApplicationAcceptedNotification` | 1505 | `GroupApplicationAcceptedTips` | 通知 + 去重 | `OnGroupApplicationAccepted` + filter |
| 6 | `GroupApplicationRejectedNotification` | 1506 | `GroupApplicationRejectedTips` | 通知 + 去重 | `OnGroupApplicationRejected` + filter |
| 7 | `GroupOwnerTransferredNotification` | 1507 | `GroupOwnerTransferredTips` | 同步新旧群主信息 | `onlineSyncGroupAndMember` + SortVersion=changed |
| 8 | `MemberKickedNotification` | 1508 | `MemberKickedTips` | 若自己被踢→同步群列表；否则同步被踢成员 | `IncrSyncJoinGroup` 或 `onlineSyncGroupAndMember` |
| 9 | `MemberInvitedNotification` | 1509 | `MemberInvitedTips` | 若自己被邀请→同步群列表+成员；否则同步新成员 | 两者都可能 |
| 10 | `MemberEnterNotification` | 1510 | `MemberEnterTips` | 若自己进入→同步群列表+成员；否则同步新成员 | 两者都可能 |
| 11 | `GroupDismissedNotification` | 1511 | `GroupDismissedTips` | 通知 + 同步群列表 | `OnGroupDismissed` + `IncrSyncJoinGroup` |
| 12 | `GroupMemberMutedNotification` | 1512 | `GroupMemberMutedTips` | 同步被禁言成员 | `onlineSyncGroupAndMember` |
| 13 | `GroupMemberCancelMutedNotification` | 1513 | `GroupMemberCancelMutedTips` | 同步取消禁言成员 | `onlineSyncGroupAndMember` |
| 14 | `GroupMutedNotification` | 1514 | `GroupMutedTips` | 同步群组信息 | `onlineSyncGroupAndMember` |
| 15 | `GroupCancelMutedNotification` | 1515 | `GroupCancelMutedTips` | 同步群组信息 | `onlineSyncGroupAndMember` |
| 16 | `GroupMemberInfoSetNotification` | 1516 | `GroupMemberInfoSetTips` | 同步成员信息 | `onlineSyncGroupAndMember` + SortVersion |
| 17 | `GroupMemberSetToAdminNotification` | 1517 | `GroupMemberInfoSetTips` | 同步成员角色 | `onlineSyncGroupAndMember` + SortVersion |
| 18 | `GroupMemberSetToOrdinaryUserNotification` | 1518 | `GroupMemberInfoSetTips` | 同步成员角色 | `onlineSyncGroupAndMember` + SortVersion |
| 19 | `GroupInfoSetAnnouncementNotification` | 1519 | `GroupInfoSetAnnouncementTips` | 同步群组公告 | `onlineSyncGroupAndMember` |
| 20 | `GroupInfoSetNameNotification` | 1520 | `GroupInfoSetNameTips` | 同步群组名称 | `onlineSyncGroupAndMember` |

### 通知处理流程总结

```
DoNotification(ctx, msg)
├── 1503/1505/1506 → NotificationFilter 去重 → 触发回调
└── 其他通知
    ├── 获取 groupSyncMutex 锁
    ├── 根据 content_type 匹配
    ├── 解析对应 Tips
    └── 执行同步操作（IncrSyncJoinGroup / IncrSyncGroupAndMember / onlineSyncGroupAndMember）
```

---

## 9. 数据库表

### 9.1 local_groups 表

```sql
CREATE TABLE IF NOT EXISTS local_groups (
    group_id                   TEXT PRIMARY KEY,       -- 群组 ID
    name                       TEXT NOT NULL DEFAULT '', -- 群组名称
    notification               TEXT NOT NULL DEFAULT '', -- 群公告
    introduction               TEXT NOT NULL DEFAULT '', -- 群简介
    face_url                   TEXT NOT NULL DEFAULT '', -- 群头像
    create_time                INTEGER NOT NULL DEFAULT 0, -- 创建时间
    status                     INTEGER NOT NULL DEFAULT 0, -- 状态（0:正常, 1:封禁, 2:解散）
    creator_user_id            TEXT NOT NULL DEFAULT '', -- 创建者 ID
    group_type                 INTEGER NOT NULL DEFAULT 0, -- 群类型
    owner_user_id              TEXT NOT NULL DEFAULT '', -- 群主 ID
    member_count               INTEGER NOT NULL DEFAULT 0, -- 成员数量
    ex                         TEXT NOT NULL DEFAULT '', -- 扩展字段
    attached_info              TEXT NOT NULL DEFAULT '', -- 附加信息
    need_verification          INTEGER NOT NULL DEFAULT 0, -- 加入是否需要验证
    look_member_info           INTEGER NOT NULL DEFAULT 0, -- 是否可查看成员信息
    apply_member_friend        INTEGER NOT NULL DEFAULT 0, -- 加群时是否自动加好友
    notification_update_time   INTEGER NOT NULL DEFAULT 0, -- 公告更新时间
    notification_user_id       TEXT NOT NULL DEFAULT ''  -- 公告更新者
);
```

### 9.2 local_group_members 表

```sql
CREATE TABLE IF NOT EXISTS local_group_members (
    group_id            TEXT NOT NULL,     -- 群组 ID
    user_id             TEXT NOT NULL,     -- 用户 ID
    nickname            TEXT NOT NULL DEFAULT '', -- 群内昵称
    user_group_face_url TEXT NOT NULL DEFAULT '', -- 群内头像
    role_level          INTEGER NOT NULL DEFAULT 0, -- 角色（1:普通, 2:管理员, 3:群主）
    join_time           INTEGER NOT NULL DEFAULT 0, -- 加入时间
    join_source         INTEGER NOT NULL DEFAULT 0, -- 加入来源
    inviter_user_id     TEXT NOT NULL DEFAULT '', -- 邀请者 ID
    mute_end_time       INTEGER NOT NULL DEFAULT 0, -- 禁言结束时间
    operator_user_id    TEXT NOT NULL DEFAULT '', -- 操作者 ID
    ex                  TEXT NOT NULL DEFAULT '', -- 扩展字段
    attached_info       TEXT NOT NULL DEFAULT '', -- 附加信息
    PRIMARY KEY (group_id, user_id)
);
```

### 9.3 local_sync_version 表（群组版本同步用）

```sql
-- 版本同步表，用于增量同步
-- 群组列表: key = loginUserID, table_name = "local_groups"
-- 群成员:   key = groupID,      table_name = "local_group_entities_version"
```

---

## 10. Server ↔ Local 模型转换

### 10.1 ServerGroupToLocalGroup

```go
func ServerGroupToLocalGroup(info *sdkws.GroupInfo) *LocalGroup {
    return &LocalGroup{
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
        MemberCount:            int32(info.MemberCount),
        Ex:                     info.Ex,
        NeedVerification:       info.NeedVerification,
        LookMemberInfo:         info.LookMemberInfo,
        ApplyMemberFriend:      info.ApplyMemberFriend,
        NotificationUpdateTime: info.NotificationUpdateTime,
        NotificationUserID:     info.NotificationUserID,
    }
}
```

### 10.2 ServerGroupMemberToLocalGroupMember

```go
func ServerGroupMemberToLocalGroupMember(info *sdkws.GroupMemberFullInfo) *LocalGroupMember {
    return &LocalGroupMember{
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

### 10.3 ServerGroupRequestToLocalGroupRequest

```go
func ServerGroupRequestToLocalGroupRequest(info *sdkws.GroupRequest) *LocalGroupRequest {
    return &LocalGroupRequest{
        GroupID:       info.GroupInfo.GroupID,
        GroupName:     info.GroupInfo.GroupName,
        Notification:  info.GroupInfo.Notification,
        Introduction:  info.GroupInfo.Introduction,
        GroupFaceURL:  info.GroupInfo.FaceURL,
        CreateTime:    info.GroupInfo.CreateTime,
        Status:        info.GroupInfo.Status,
        CreatorUserID: info.GroupInfo.CreatorUserID,
        GroupType:     info.GroupInfo.GroupType,
        OwnerUserID:   info.GroupInfo.OwnerUserID,
        MemberCount:   int32(info.GroupInfo.MemberCount),
        UserID:        info.UserInfo.UserID,
        Nickname:      info.UserInfo.Nickname,
        UserFaceURL:   info.UserInfo.FaceURL,
        HandleResult:  info.HandleResult,
        ReqMsg:        info.ReqMsg,
        HandledMsg:    info.HandleMsg,
        ReqTime:       info.ReqTime,
        HandleUserID:  info.HandleUserID,
        HandledTime:   info.HandleTime,
        Ex:            info.Ex,
        JoinSource:    info.JoinSource,
        InviterUserID: info.InviterUserID,
    }
}
```

---

## 11. Rust 当前实现分析

### 11.1 已实现的功能

| 功能 | 状态 | 文件位置 |
|------|------|----------|
| 获取已加入群组列表（内存） | ✅ 已实现 | `core/group/manager.rs::get_joined_group_list` |
| 同步群组列表 | ✅ 已实现 | `core/group/manager.rs::sync_groups` |
| 获取群组信息 | ✅ 已实现 | `core/group/manager.rs::get_groups_info` |
| 创建群组 | ✅ 已实现 | `core/group/manager.rs::create_group` |
| 加入/退出/解散群组 | ✅ 已实现 | `core/group/manager.rs` |
| 设置群组信息 | ✅ 已实现 | `core/group/manager.rs::set_group_info` |
| 群成员列表获取 | ✅ 已实现 | `core/group/manager.rs::get_group_member_list` |
| 获取群成员信息 | ✅ 已实现 | `core/group/manager.rs::get_group_members_info` |
| 踢出群成员 | ✅ 已实现 | `core/group/manager.rs::kick_group_member` |
| 邀请用户入群 | ✅ 已实现 | `core/group/manager.rs::invite_user_to_group` |
| 设置群成员信息 | ✅ 已实现 | `core/group/manager.rs::set_group_member_info` |
| 群申请列表 | ✅ 已实现 | `core/group/manager.rs::get_group_application_list` |
| 接受/拒绝群申请 | ✅ 已实现 | `core/group/manager.rs` |
| GroupDao（CRUD） | ✅ 已实现 | `infra/database/group_dao.rs` |

### 11.2 缺失/待改进的功能

| 功能 | 状态 | 说明 |
|------|------|------|
| **VersionSynchronizer 双层同步** | ❌ 缺失 | 没有 groupSyncer + groupMemberSyncer |
| **IncrSyncJoinGroup** | ❌ 缺失 | 群组列表增量同步 |
| **IncrSyncGroupAndMember** | ❌ 缺失 | 群组+成员增量同步（批量） |
| **onlineSyncGroupAndMember** | ❌ 缺失 | 基于通知数据的在线同步 |
| **NotificationFilter** | ❌ 缺失 | 通知去重（LRU + 10s 超时） |
| **通知处理（20 种）** | ❌ 缺失 | DoNotification 完全未实现 |
| **群组/成员信息缓存** | ❌ 缺失 | 没有 LRU 缓存机制 |
| **SearchGroups** | ❌ 缺失 | 搜索群组未实现 |
| **SearchGroupMembers** | ❌ 缺失 | 搜索群成员未实现 |
| **ChangeGroupMute** | ❌ 缺失 | 群组全局禁言未实现 |
| **ChangeGroupMemberMute** | ❌ 缺失 | 群成员禁言未实现 |
| **TransferGroupOwner** | ❌ 缺失 | 转让群主未实现 |
| **GetGroupMemberOwnerAndAdmin** | ❌ 缺失 | 获取群主管理员未实现 |
| **IsJoinGroup / GetUsersInGroup** | ❌ 缺失 | 成员关系检查未实现 |
| **GetGroupApplicationUnhandledCount** | ❌ 缺失 | 未处理申请计数未实现 |
| **CheckLocalGroupFullSync** | ❌ 缺失 | 全量同步检查未实现 |
| **通知→会话/消息联动** | ❌ 缺失 | 群变更后未更新会话和消息 |
| **DataFetcher 本地优先** | ❌ 缺失 | 查询逻辑未使用 DataFetcher |
| **SortVersion 处理** | ❌ 缺失 | 群成员排序变化未处理 |

---

## 12. 重写建议

### 12.1 架构改造

```
GroupManager
├── group_dao: GroupDao               // 群组/成员数据访问
├── sync_version_dao: SyncVersionDao  // 版本同步
├── event_bus: EventBus               // 事件分发
├── sync_mutex: Mutex                 // 同步互斥锁
├── group_info_cache: LruCache        // 群信息缓存
├── group_member_cache: LruCache      // 群成员缓存
├── notification_filter: Filter       // 通知去重
└── 核心方法
    ├── incr_sync_join_group()           // 群组列表增量同步
    ├── incr_sync_group_and_member()     // 群组+成员增量同步
    ├── online_sync_group_and_member()   // 在线同步
    ├── sync_group_and_member()          // 单群组同步
    ├── do_notification()                // 通知处理
    └── ... (所有公开 API)
```

### 12.2 关键实现要点

1. **双层同步是核心**：群组列表和群成员使用独立的版本号
   - 群组列表: `local_sync_version WHERE table_name='local_groups' AND entity_id=loginUserID`
   - 群成员: `local_sync_version WHERE table_name='local_group_entities_version' AND entity_id=groupID`

2. **批量同步**：`IncrSyncGroupAndMember` 支持批量请求多个群组的成员增量

3. **通知分类处理**：
   - 1503/1505/1506：通知类，使用 NotificationFilter 去重
   - 其他：数据同步类，使用 onlineSyncGroupAndMember 直接同步

4. **SortVersion**：当群成员排序变化时（如群主转让），需要传递 SortVersion

5. **ExtraData**：群成员增量同步可能附带群组信息更新（如成员数变化）

---

## 13. 测试用例

### 13.1 单元测试

```rust
#[tokio::test]
async fn test_group_crud() {
    // 1. 创建 GroupDao，执行 upsert_group
    // 2. 验证 get_group 返回正确数据
    // 3. 验证 delete_group 后数据不存在
}

#[tokio::test]
async fn test_member_crud() {
    // 1. 创建 GroupDao，执行 upsert_member
    // 2. 验证 get_members 返回正确数据
    // 3. 验证 delete_member 后数据不存在
    // 4. 验证 delete_members_by_group 清空群成员
}

#[tokio::test]
async fn test_notification_filter_dedup() {
    // 1. 创建 NotificationFilter（timeout=10s）
    // 2. 第一次 should_execute("uuid-1") → true
    // 3. 第二次 should_execute("uuid-1") → false（10s 内）
    // 4. should_execute("uuid-2") → true（不同 UUID）
}

#[tokio::test]
async fn test_server_to_group_info_conversion() {
    // 验证 ServerGroupToLocalGroup 转换正确
}

#[tokio::test]
async fn test_server_to_group_member_conversion() {
    // 验证 ServerGroupMemberToLocalGroupMember 转换正确
}

#[tokio::test]
async fn test_incr_sync_join_group() {
    // 1. Mock HTTP API 返回增量群组数据
    // 2. 调用 incr_sync_join_group
    // 3. 验证数据库中群组数据正确更新
    // 4. 验证 version 记录正确更新
}

#[tokio::test]
async fn test_notification_handler_group_created() {
    // 1. 模拟 GroupCreatedNotification 消息
    // 2. 调用 do_notification
    // 3. 验证触发了正确的同步操作
}

#[tokio::test]
async fn test_notification_handler_member_kicked() {
    // 1. 模拟 MemberKickedNotification（非自己被踢）
    // 2. 调用 do_notification
    // 3. 验证群成员被正确移除
}

#[tokio::test]
async fn test_group_member_cache() {
    // 1. 缓存群成员信息
    // 2. 验证缓存命中
    // 3. 更新群成员信息
    // 4. 验证缓存已清除
}
```

### 13.2 集成测试

```rust
#[tokio::test]
async fn test_create_group_then_sync() {
    // 1. 创建群组
    // 2. 触发 IncrSyncJoinGroup
    // 3. 触发 IncrSyncGroupAndMember
    // 4. 验证群组和成员数据完整
}

#[tokio::test]
async fn test_kick_member_then_notification() {
    // 1. 踢出群成员
    // 2. 收到 MemberKickedNotification
    // 3. 验证本地成员列表已更新
}

#[tokio::test]
async fn test_full_sync_then_incr_sync_group() {
    // 1. 首次同步（全量）
    // 2. 服务端新增成员
    // 3. 增量同步
    // 4. 验证新成员已同步到本地
}
```
