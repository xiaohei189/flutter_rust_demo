# 07 - 好友/关系模块（Relation）详细设计

> 对标 Go SDK: `internal/relation/`
> 本文档为 Rust SDK 重写提供完整的设计参考，涵盖结构体定义、方法列表、同步机制、通知处理、数据库表结构及与当前 Rust 实现的差距分析。

---

## 1. 模块职责

好友/关系模块负责管理用户之间的社交关系，是 IM SDK 的核心模块之一。主要职责包括：

- **好友列表管理**：CRUD 操作、分页查询、搜索、指定好友信息获取
- **好友申请流程**：发送申请、接受/拒绝申请、获取申请列表（作为申请人/接收人）、未处理申请计数
- **黑名单管理**：添加/移除黑名单、获取黑名单列表
- **好友增量同步**：基于 VersionSynchronizer 的增量同步机制
- **全量同步**：首次登录或重装时的全量好友同步
- **好友通知处理**：处理 10 种好友相关通知消息

---

## 2. Go SDK 对标文件

| 文件 | 职责 |
|------|------|
| `relation.go` | 结构体定义、Syncer 初始化 |
| `api.go` | 公开 API 方法 |
| `server_api.go` | HTTP API 调用封装 |
| `incremental_sync.go` | 增量同步（VersionSynchronizer） |
| `sync.go` | 黑名单全量同步 |
| `notification.go` | 通知消息处理 |
| `conversion.go` | Server 模型 ↔ 本地模型转换 |

---

## 3. Relation 结构体字段

```go
type Relation struct {
    friendshipListener     open_im_sdk_callback.OnFriendshipListenerSdk  // 好友事件监听器
    loginUserID            string                                        // 当前登录用户 ID
    db                     db_interface.DataBase                         // 数据库接口
    user                   *user.User                                    // 用户模块引用（用于清除用户缓存）
    friendSyncer           *syncer.Syncer[*LocalFriend, GetPaginationFriendsResp, [2]string]  // 好友同步器
    blackSyncer            *syncer.Syncer[*LocalBlack, NoResp, [2]string]                     // 黑名单同步器
    conversationEventQueue chan common.Cmd2Value                          // 会话事件队列
    listenerForService     open_im_sdk_callback.OnListenerForService      // 服务层监听器
    relationSyncMutex      sync.Mutex                                    // 关系同步互斥锁
}
```

### Rust 对应结构体设计

```rust
pub struct RelationManager {
    db: Arc<SqlitePool>,                         // SQLite 连接池
    user_id: Arc<RwLock<String>>,                // 当前登录用户 ID
    friends: Arc<RwLock<Vec<LocalFriend>>>,      // 本地好友缓存
    blacks: Arc<RwLock<Vec<LocalBlack>>>,        // 本地黑名单缓存
    event_bus: Arc<EventBus>,                    // 事件总线
    sync_mutex: Arc<tokio::sync::Mutex<()>>,     // 同步互斥锁
    friend_dao: FriendDao,                       // 好友 DAO
    black_dao: BlackDao,                         // 黑名单 DAO
    sync_version_dao: SyncVersionDao,            // 版本同步 DAO
}
```

---

## 4. 完整方法列表

### 4.1 好友信息查询

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `GetSpecifiedFriendsInfo` | `(ctx, friendUserIDList []string, filterBlack bool) ([]*LocalFriend, error)` | 获取指定好友信息，可过滤黑名单用户 |
| `GetFriendList` | `(ctx, filterBlack bool) ([]*LocalFriend, error)` | 获取完整好友列表，可过滤黑名单用户 |
| `GetFriendListPage` | `(ctx, offset, count int32, filterBlack bool) ([]*LocalFriend, error)` | 分页获取好友列表 |
| `SearchFriends` | `(ctx, param *SearchFriendsParam) ([]*SearchFriendItem, error)` | 搜索好友（支持按昵称/UserID/备注搜索） |
| `CheckFriend` | `(ctx, friendUserIDList []string) ([]*UserIDResult, error)` | 检查指定用户是否为好友（返回 0=非好友, 1=好友） |

### 4.2 好友申请

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `AddFriend` | `(ctx, req *ApplyToAddFriendReq) error` | 发送好友申请 |
| `AcceptFriendApplication` | `(ctx, param *ProcessFriendApplicationParams) error` | 接受好友申请 |
| `RefuseFriendApplication` | `(ctx, param *ProcessFriendApplicationParams) error` | 拒绝好友申请 |
| `RespondFriendApply` | `(ctx, req *RespondFriendApplyReq) error` | 响应好友申请（内部方法，同意后触发 IncrSyncFriends） |
| `GetFriendApplicationListAsRecipient` | `(ctx, req *GetFriendApplicationListAsRecipientReq) ([]*LocalFriendRequest, error)` | 获取收到的好友申请列表 |
| `GetFriendApplicationListAsApplicant` | `(ctx, req *GetFriendApplicationListAsApplicantReq) ([]*LocalFriendRequest, error)` | 获取自己发出的好友申请列表 |
| `GetFriendApplicationUnhandledCount` | `(ctx, req *GetSelfUnhandledApplyCountReq) (int32, error)` | 获取未处理的好友申请数量 |

### 4.3 好友操作

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `DeleteFriend` | `(ctx, friendUserID string) error` | 删除好友（操作后触发 IncrSyncFriends） |
| `UpdateFriends` | `(ctx, req *UpdateFriendsReq) error` | 更新好友信息（如备注，操作后触发 IncrSyncFriends） |

### 4.4 黑名单

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `AddBlack` | `(ctx, blackUserID string, ex string) error` | 添加黑名单（操作后触发 SyncAllBlackList） |
| `RemoveBlack` | `(ctx, blackUserID string) error` | 移除黑名单（操作后触发 SyncAllBlackList） |
| `GetBlackList` | `(ctx) ([]*LocalBlack, error)` | 获取黑名单列表 |

### 4.5 同步

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `IncrSyncFriends` | `(ctx) error` | 好友增量同步 |
| `IncrSyncFriendsWithLock` | `(ctx) error` | 加锁版本的增量同步 |
| `SyncAllBlackList` | `(ctx) error` | 黑名单全量同步 |
| `SyncAllBlackListWithoutNotice` | `(ctx) error` | 黑名单全量同步（不触发通知） |

---

## 5. friendSyncer 配置

### 5.1 Syncer 类型

```go
// Syncer[*LocalFriend, GetPaginationFriendsResp, [2]string]
// 泛型参数：本地实体类型, 服务端响应类型, UUID 类型
friendSyncer = syncer.New2[*LocalFriend, GetPaginationFriendsResp, [2]string](...)
```

### 5.2 UUID 配置

```go
WithUUID(func(value *LocalFriend) [2]string {
    return [...]string{value.OwnerUserID, value.FriendUserID}
})
```

UUID 由 `[OwnerUserID, FriendUserID]` 组成，确保好友关系的唯一性。

### 5.3 CRUD 回调

| 回调 | 实现 |
|------|------|
| **Insert** | `db.InsertFriend(ctx, value)` |
| **Delete** | `db.DeleteFriendDB(ctx, value.FriendUserID)` |
| **Update** | 先清除用户缓存 `user.UserCache().Delete(server.FriendUserID)`，再 `db.UpdateFriend(ctx, server)` |
| **BatchInsert** | `db.BatchInsertFriend(ctx, values)` |
| **DeleteAll** | `db.DeleteAllFriend(ctx)` |

### 5.4 Notice 回调（事件通知）

```go
WithNotice(func(ctx, state, server, local) {
    switch state {
    case syncer.Insert:
        // 1. 触发 OnFriendAdded 事件
        friendshipListener.OnFriendAdded(*server)
        // 2. 若有备注则用备注覆盖昵称
        // 3. 更新会话的头像和昵称 (UpdateConFaceUrlAndNickName)
        // 4. 更新消息的头像和昵称 (UpdateMsgFaceUrlAndNickName)
    case syncer.Delete:
        // 触发 OnFriendDeleted 事件
        friendshipListener.OnFriendDeleted(*local)
    case syncer.Update:
        // 1. 触发 OnFriendInfoChanged 事件
        friendshipListener.OnFriendInfoChanged(*server)
        // 2. 若昵称/头像/备注有变化，更新会话和消息的头像昵称
    }
})
```

### 5.5 blackSyncer 配置

```go
blackSyncer = syncer.New[*LocalBlack, NoResp, [2]string](
    Insert:  db.InsertBlack(ctx, value),
    Delete:  db.DeleteBlack(ctx, value.BlockUserID),
    Update:  db.UpdateBlack(ctx, server),
    UUID:    [OwnerUserID, BlockUserID],
    Notice: Insert → OnBlackAdded, Delete → OnBlackDeleted
)
```

### 5.6 分页与全量配置

```go
WithBatchPageReq(func(entityID) page.PageReq {
    return &GetPaginationFriendsReq{
        UserID: entityID,
        Pagination: &RequestPagination{ShowNumber: 100},
    }
})
WithBatchPageRespConvertFunc(func(resp) []*LocalFriend {
    return datautil.Batch(ServerFriendToLocalFriend, resp.FriendsInfo)
})
WithReqApiRouter(api.GetFriendList.Route())
WithFullSyncLimit(friendSyncLimit)  // 10000
```

---

## 6. IncrSyncFriends 流程

### 6.1 VersionSynchronizer 配置

```go
friendSyncer := syncer.VersionSynchronizer[*LocalFriend, *GetIncrementalFriendsResp]{
    Ctx:       ctx,
    DB:        r.db,
    TableName: r.friendListTableName(),    // "local_friends"
    EntityID:  r.loginUserID,
    Key:       func(friend) string { return friend.FriendUserID },
    Local:     func() ([]*LocalFriend, error) { return r.db.GetAllFriendList(ctx) },
    Server:    func(version) (*GetIncrementalFriendsResp, error) {
        return r.getIncrementalFriends(ctx, &GetIncrementalFriendsReq{
            UserID:    r.loginUserID,
            Version:   version.Version,
            VersionID: version.VersionID,
        })
    },
    Full:        func(resp) bool { return resp.Full },
    Version:     func(resp) (string, uint64) { return resp.VersionID, resp.Version },
    Delete:      func(resp) []string { return resp.Delete },
    Update:      func(resp) []*LocalFriend { return datautil.Batch(ServerFriendToLocalFriend, resp.Update) },
    Insert:      func(resp) []*LocalFriend { return datautil.Batch(ServerFriendToLocalFriend, resp.Insert) },
    Syncer:      func(server, local) error { return r.friendSyncer.Sync(ctx, server, local, nil) },
    FullSyncer:  func(ctx) error { return r.friendSyncer.FullSync(ctx, r.loginUserID) },
    FullID:      func(ctx) ([]string, error) { return r.getFullFriendUserIDs(...) },
    IDOrderChanged: func(resp) bool { return resp.SortVersion > 0 },
}
return friendSyncer.IncrementalSync()
```

### 6.2 增量同步流程

```
1. 从 local_sync_version 表读取当前 version 和 versionID
2. 如果 version 不存在，执行全量同步
3. 调用 getIncrementalFriends API 获取增量数据
4. 如果 resp.Full == true，执行全量同步（friendSyncer.FullSync）
5. 否则，执行增量操作：
   a. 删除 resp.Delete 中的用户（通过 friendSyncer.Sync）
   b. 插入/更新 resp.Insert 和 resp.Update 中的用户
6. 更新 version 和 versionID 到 local_sync_version 表
7. 如果 resp.SortVersion > 0（排序变化），额外处理
```

### 6.3 同步互斥锁

所有需要同步的操作（AcceptFriendApplication, DeleteFriend, UpdateFriends, AddBlack, RemoveBlack）都在操作完成后获取 `relationSyncMutex` 锁，然后调用对应的同步方法。

---

## 7. 通知处理

### 7.1 通知类型表

| 常量名 | 值 | 说明 | 处理逻辑 |
|--------|-----|------|----------|
| `FriendApplicationNotification` | 1301 | 好友申请通知 | 触发 `OnFriendApplicationAdded` |
| `FriendApplicationApprovedNotification` | 1302 | 好友申请被接受 | 触发 `OnFriendApplicationAccepted` + `IncrSyncFriends` |
| `FriendApplicationRejectedNotification` | 1303 | 好友申请被拒绝 | 触发 `OnFriendApplicationRejected` |
| `FriendAddedNotification` | 1304 | 好友添加通知 | 检查是否涉及当前用户，`IncrSyncFriends` |
| `FriendDeletedNotification` | 1305 | 好友删除通知 | 检查 fromUserID == loginUserID，`IncrSyncFriends` |
| `FriendRemarkSetNotification` | 1306 | 好友备注设置 | 检查 fromUserID == loginUserID，`IncrSyncFriends` |
| `FriendInfoUpdatedNotification` | 1307 | 好友信息更新 | 检查 userID != loginUserID，`IncrSyncFriends` |
| `BlackAddedNotification` | 1308 | 黑名单添加 | 检查 fromUserID == loginUserID，`SyncAllBlackList` |
| `BlackDeletedNotification` | 1309 | 黑名单移除 | 检查 fromUserID == loginUserID，`SyncAllBlackList` |
| `FriendsInfoUpdateNotification` | 1310 | 多好友信息更新 | 检查 toUserID == loginUserID，`IncrSyncFriends` |

### 7.2 通知处理流程

```rust
// DoNotification 入口
fn do_notification(ctx, msg: &MsgData) -> Result<()> {
    // 获取 relationSyncMutex 锁（确保通知处理的串行化）
    match msg.content_type {
        FriendApplicationNotification => { /* 解析 tips → OnFriendApplicationAdded */ }
        FriendApplicationApprovedNotification => {
            /* 解析 tips → OnFriendApplicationAccepted → IncrSyncFriends */
        }
        FriendApplicationRejectedNotification => {
            /* 解析 tips → OnFriendApplicationRejected */
        }
        FriendAddedNotification => {
            /* 解析 tips → 检查涉及当前用户 → IncrSyncFriends */
        }
        FriendDeletedNotification => {
            /* 解析 tips → 检查 fromUserID → IncrSyncFriends */
        }
        FriendRemarkSetNotification => {
            /* 解析 tips → 检查 fromUserID → IncrSyncFriends */
        }
        FriendInfoUpdatedNotification => {
            /* 解析 tips → 检查 userID != loginUserID → IncrSyncFriends */
        }
        BlackAddedNotification => {
            /* 解析 tips → 检查 fromUserID → SyncAllBlackList */
        }
        BlackDeletedNotification => {
            /* 解析 tips → 检查 fromUserID → SyncAllBlackList */
        }
        FriendsInfoUpdateNotification => {
            /* 解析 tips → 检查 toUserID → IncrSyncFriends */
        }
    }
}
```

---

## 8. 数据库表

### 8.1 local_friends 表

```sql
CREATE TABLE IF NOT EXISTS local_friends (
    owner_user_id    TEXT NOT NULL,     -- 好友关系拥有者（当前用户）
    friend_user_id   TEXT NOT NULL,     -- 好友用户 ID
    remark           TEXT NOT NULL DEFAULT '',   -- 好友备注
    create_time      INTEGER NOT NULL DEFAULT 0, -- 创建时间
    add_source       INTEGER NOT NULL DEFAULT 0, -- 添加来源
    operator_user_id TEXT NOT NULL DEFAULT '',    -- 操作者用户 ID
    nickname         TEXT NOT NULL DEFAULT '',    -- 好友昵称
    face_url         TEXT NOT NULL DEFAULT '',    -- 好友头像 URL
    ex               TEXT NOT NULL DEFAULT '',    -- 扩展字段
    attached_info    TEXT NOT NULL DEFAULT '',    -- 附加信息
    is_pinned        INTEGER NOT NULL DEFAULT 0,  -- 是否置顶
    PRIMARY KEY (owner_user_id, friend_user_id)
);
```

**字段与 Go 对应关系：**

| Rust 字段 | Go 字段 | 说明 |
|-----------|---------|------|
| `owner_user_id` | `OwnerUserID` | 好友关系拥有者 |
| `friend_user_id` | `FriendUserID` | 好友用户 ID |
| `remark` | `Remark` | 好友备注 |
| `create_time` | `CreateTime` | 创建时间戳 |
| `add_source` | `AddSource` | 添加来源 |
| `operator_user_id` | `OperatorUserID` | 操作者 |
| `nickname` | `Nickname` | 好友昵称 |
| `face_url` | `FaceURL` | 好友头像 |
| `ex` | `Ex` | 扩展字段 |
| `attached_info` | `AttachedInfo` | 附加信息 |
| `is_pinned` | `IsPinned` | 是否置顶 |

### 8.2 local_blacks 表

```sql
CREATE TABLE IF NOT EXISTS local_blacks (
    owner_user_id    TEXT NOT NULL,     -- 黑名单拥有者
    block_user_id    TEXT NOT NULL,     -- 被拉黑用户 ID
    nickname         TEXT NOT NULL DEFAULT '',   -- 被拉黑用户昵称
    face_url         TEXT NOT NULL DEFAULT '',    -- 被拉黑用户头像
    create_time      INTEGER NOT NULL DEFAULT 0, -- 拉黑时间
    add_source       INTEGER NOT NULL DEFAULT 0, -- 拉黑来源
    operator_user_id TEXT NOT NULL DEFAULT '',    -- 操作者
    ex               TEXT NOT NULL DEFAULT '',    -- 扩展字段
    attached_info    TEXT NOT NULL DEFAULT '',    -- 附加信息
    PRIMARY KEY (owner_user_id, block_user_id)
);
```

---

## 9. Server ↔ Local 模型转换

### 9.1 ServerFriendToLocalFriend

```go
func ServerFriendToLocalFriend(info *sdkws.FriendInfo) *LocalFriend {
    return &LocalFriend{
        OwnerUserID:    info.OwnerUserID,
        FriendUserID:   info.FriendUser.UserID,
        Remark:         info.Remark,
        CreateTime:     info.CreateTime,
        AddSource:      info.AddSource,
        OperatorUserID: info.OperatorUserID,
        Nickname:       info.FriendUser.Nickname,
        FaceURL:        info.FriendUser.FaceURL,
        Ex:             info.Ex,
        IsPinned:       info.IsPinned,
    }
}
```

### 9.2 ServerFriendRequestToLocalFriendRequest

```go
func ServerFriendRequestToLocalFriendRequest(info *sdkws.FriendRequest) *LocalFriendRequest {
    return &LocalFriendRequest{
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

### 9.3 ServerBlackToLocalBlack

```go
func ServerBlackToLocalBlack(info *sdkws.BlackInfo) *LocalBlack {
    return &LocalBlack{
        OwnerUserID:    info.OwnerUserID,
        BlockUserID:    info.BlackUserInfo.UserID,
        CreateTime:     info.CreateTime,
        AddSource:      info.AddSource,
        OperatorUserID: info.OperatorUserID,
        Nickname:       info.BlackUserInfo.Nickname,
        FaceURL:        info.BlackUserInfo.FaceURL,
        Ex:             info.Ex,
    }
}
```

---

## 10. Rust 当前实现分析

### 10.1 已实现的功能

| 功能 | 状态 | 文件位置 |
|------|------|----------|
| 好友列表获取（内存） | ✅ 已实现 | `core/friend/manager.rs` |
| 同步好友列表 | ✅ 已实现 | `core/friend/manager.rs::sync_friends` |
| 添加好友 | ✅ 已实现 | `core/friend/manager.rs::add_friend` |
| 删除好友 | ✅ 已实现 | `core/friend/manager.rs::delete_friend` |
| 黑名单管理 | ✅ 已实现 | `core/friend/manager.rs` |
| 好友申请列表 | ✅ 已实现 | `core/friend/manager.rs::get_friend_apply_list` |
| 接受/拒绝好友申请 | ✅ 已实现 | `core/friend/manager.rs` |
| FriendDao（CRUD） | ✅ 已实现 | `infra/database/friend_dao.rs` |
| BlackDao（CRUD） | ✅ 已实现 | `infra/database/black_dao.rs` |

### 10.2 缺失/待改进的功能

| 功能 | 状态 | 说明 |
|------|------|------|
| **VersionSynchronizer 增量同步** | ❌ 缺失 | 当前实现为简单的全量拉取替换，没有基于 version 的增量同步 |
| **全量同步 + 增量同步联动** | ❌ 缺失 | 没有 FullSyncLimit 判断和 FullID API 调用 |
| **friendSyncer 同步器** | ❌ 缺失 | 没有实现 Go SDK 中的 Syncer 回调机制 |
| **blackSyncer 同步器** | ❌ 缺失 | 黑名单同步直接替换内存，没有 Syncer |
| **通知处理** | ❌ 缺失 | 没有 DoNotification 实现，10 种通知未处理 |
| **分页查询** | ⚠️ 简化 | 当前只支持全量获取，不支持真正的分页+增量 |
| **搜索好友** | ❌ 缺失 | 没有 SearchFriends 实现 |
| **CheckFriend** | ❌ 缺失 | 没有好友状态检查 |
| **GetSpecifiedFriendsInfo** | ⚠️ 简化 | 未使用 DataFetcher，无本地优先逻辑 |
| **UpdateFriends** | ❌ 缺失 | 没有更新好友信息（如备注） |
| **GetFriendApplicationUnhandledCount** | ❌ 缺失 | 未实现未处理申请计数 |
| **通知→会话/消息联动** | ❌ 缺失 | 好友变更后未更新会话和消息的头像昵称 |
| **同步互斥锁** | ❌ 缺失 | 没有 relationSyncMutex 保护同步操作 |
| **DataFetcher 本地优先** | ❌ 缺失 | 没有先查本地、缺省从服务端拉取的逻辑 |
| **本地数据库持久化** | ⚠️ 部分 | FriendDao 有基础 CRUD，但 sync_friends 直接覆盖内存，未写入数据库 |

---

## 11. 重写建议

### 11.1 架构改造

```
RelationManager
├── friend_dao: FriendDao           // 好友数据访问
├── black_dao: BlackDao             // 黑名单数据访问
├── sync_version_dao: SyncVersionDao // 版本同步
├── event_bus: EventBus             // 事件分发
├── sync_mutex: Mutex               // 同步互斥锁
└── 核心方法
    ├── incr_sync_friends()         // 增量同步
    ├── sync_all_blacklist()        // 黑名单全量同步
    ├── do_notification()           // 通知处理
    └── ... (所有公开 API)
```

### 11.2 关键实现要点

1. **增量同步必须对齐 Go SDK 的 VersionSynchronizer**：
   - 读取 local_sync_version 获取 version/versionID
   - 调用 GetIncrementalFriends API
   - 根据 resp.Full 判断全量/增量
   - 增量时分别处理 Insert/Update/Delete
   - 更新 version 记录

2. **通知处理必须在同步互斥锁保护下执行**

3. **DataFetcher 模式**：查询时先查本地，缺失的从服务端拉取并缓存

4. **事件联动**：好友变更后需要更新关联会话和消息的头像昵称

---

## 12. 测试用例

### 12.1 单元测试

```rust
#[tokio::test]
async fn test_friend_crud() {
    // 1. 创建 FriendDao，执行 upsert
    // 2. 验证 get_all 返回正确数据
    // 3. 验证 get_by_id 返回正确数据
    // 4. 验证 delete 后数据不存在
}

#[tokio::test]
async fn test_black_crud() {
    // 1. 创建 BlackDao，执行 upsert
    // 2. 验证 get_all 返回正确数据
    // 3. 验证 delete 后数据不存在
}

#[tokio::test]
async fn test_server_to_friend_conversion() {
    // 验证 ServerFriendToLocalFriend 转换正确
}

#[tokio::test]
async fn test_check_friend() {
    // 1. 插入好友数据
    // 2. 调用 check_friend
    // 3. 验证返回正确的 is_friend 状态
}

#[tokio::test]
async fn test_incr_sync_friends() {
    // 1. Mock HTTP API 返回增量数据
    // 2. 调用 incr_sync_friends
    // 3. 验证数据库中数据正确更新
    // 4. 验证 version 记录正确更新
}

#[tokio::test]
async fn test_notification_handler() {
    // 1. 模拟 FriendApplicationNotification 消息
    // 2. 调用 do_notification
    // 3. 验证事件总线收到了 OnFriendApplicationAdded 事件
}

#[tokio::test]
async fn test_friend_search() {
    // 1. 插入多条好友数据
    // 2. 调用 search_friends（按昵称搜索）
    // 3. 验证搜索结果正确
}

#[tokio::test]
async fn test_filter_black_from_friend_list() {
    // 1. 插入好友和黑名单数据
    // 2. 调用 get_friend_list(filter_black=true)
    // 3. 验证黑名单用户被过滤
}
```

### 12.2 集成测试

```rust
#[tokio::test]
async fn test_full_sync_then_incr_sync() {
    // 1. 首次同步（全量）
    // 2. 服务端新增好友
    // 3. 增量同步
    // 4. 验证新好友已同步到本地
}

#[tokio::test]
async fn test_add_friend_then_accept() {
    // 1. 发送好友申请
    // 2. 接受好友申请
    // 3. 触发增量同步
    // 4. 验证好友列表中包含新好友
}
```
