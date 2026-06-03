# 09 - 用户模块（User）详细设计

> 对标 Go SDK: `internal/user/`
> 本文档为 Rust SDK 重写提供完整的设计参考，涵盖结构体定义、方法列表、同步机制、缓存策略、通知处理、数据库表结构及与当前 Rust 实现的差距分析。

---

## 1. 模块职责

用户模块负责管理用户自身信息及其他用户信息的获取与缓存，是 IM SDK 的基础模块之一。主要职责包括：

- **自身信息管理**：获取/设置自身用户信息
- **用户信息查询**：批量获取其他用户信息
- **自身信息同步**：登录后同步服务端最新用户信息
- **用户缓存**：基于 UserCache 的高效缓存机制
- **用户在线状态处理**：处理用户上下线状态变更通知
- **用户通知处理**：处理用户信息更新通知

---

## 2. Go SDK 对标文件

| 文件 | 职责 |
|------|------|
| `user.go` | 结构体定义、Syncer 初始化、UserCache |
| `api.go` | 公开 API 方法（GetSelfUserInfo, SetSelfInfo, GetUsersInfo 等） |
| `server_api.go` | HTTP API 调用封装 |
| `full_sync.go` | SyncLoginUserInfo（登录用户信息同步） |
| `notification.go` | 通知消息处理 |
| `conversion.go` | Server 模型 ↔ 本地模型转换 |

---

## 3. User 结构体字段

```go
type User struct {
    db_interface.DataBase                           // 数据库接口（内嵌）
    loginUserID            string                   // 当前登录用户 ID
    listener               func() OnUserListener    // 用户事件监听器
    userSyncer             *Syncer[*LocalUser, NoResp, string]  // 用户同步器
    conversationEventQueue chan common.Cmd2Value     // 会话事件队列
    userCache              *UserCache[string, *LocalUser]       // 用户缓存
    once                   sync.Once                // 初始化锁（懒加载 UserCache）
}
```

### Rust 对应结构体设计

```rust
pub struct UserManager {
    db: Arc<SqlitePool>,                        // SQLite 连接池
    user_id: Arc<RwLock<String>>,               // 当前登录用户 ID
    event_bus: Arc<EventBus>,                   // 事件总线
    self_user: Arc<RwLock<Option<LocalUser>>>,  // 本地用户缓存
    user_cache: Arc<tokio::sync::RwLock<LruCache<String, LocalUser>>>,  // 用户信息 LRU 缓存
    user_dao: UserDao,                          // 用户 DAO
}
```

---

## 4. 完整方法列表

### 4.1 自身信息

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `GetSelfUserInfo` | `(ctx) (*LocalUser, error)` | 获取当前登录用户信息（通过 UserCache） |
| `SetSelfInfo` | `(ctx, userInfo *UserInfoWithEx) error` | 设置自身信息（调用服务端 API + 触发 SyncLoginUserInfo） |
| `SyncLoginUserInfo` | `(ctx) error` | 同步登录用户信息（从服务端拉取 + userSyncer.Sync） |
| `SyncLoginUserInfoWithoutNotice` | `(ctx) error` | 同步登录用户信息（不触发通知） |

### 4.2 用户信息查询

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `GetUsersInfo` | `(ctx, userIDs []string) ([]*PublicUser, error)` | 获取用户公开信息列表（带缓存 + 联动会话/消息更新） |
| `GetSingleUserFromServer` | `(ctx, userID string) (*LocalUser, error)` | 从服务端获取单个用户信息 |
| `GetUsersInfoFromServer` | `(ctx, userIDs []string) ([]*LocalUser, error)` | 从服务端批量获取用户信息 |
| `GetUserInfoWithCache` | `(ctx, cacheKey string) (*LocalUser, error)` | 带缓存的用户信息获取 |
| `GetUsersInfoWithCache` | `(ctx, cacheKeys []string) ([]*LocalUser, error)` | 批量带缓存的用户信息获取 |

### 4.3 用户在线状态

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `UserOnlineStatusChange` | `(users map[string][]int32)` | 处理用户在线状态变更（非 ctx 方法） |

### 4.4 客户端配置

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `GetUserClientConfig` | `(ctx) (map[string]string, error)` | 获取客户端配置 |

### 4.5 缓存

| 方法 | Go 签名 | 说明 |
|------|---------|------|
| `UserCache` | `() *UserCache[string, *LocalUser]` | 获取用户缓存实例（懒加载） |

---

## 5. userSyncer 配置

### 5.1 Syncer 类型

```go
// Syncer[*LocalUser, NoResp, string]
// 泛型参数：本地实体类型, 服务端响应类型（无响应）, UUID 类型
userSyncer = syncer.New[*LocalUser, NoResp, string](...)
```

### 5.2 UUID 配置

```go
func(user *LocalUser) string {
    return user.UserID
}
```

UUID 为用户 ID。

### 5.3 CRUD 回调

| 回调 | 实现 | 说明 |
|------|------|------|
| **Insert** | `db.InsertLoginUser(ctx, value)` | 插入登录用户 |
| **Delete** | `return fmt.Errorf("not support delete user %s", value.UserID)` | **不支持删除用户，返回错误** |
| **Update** | 先清除缓存 `UserCache().Delete(localUser.UserID)`，再 `db.UpdateLoginUser(ctx, serverUser)` | 更新前必须清除缓存 |

### 5.4 Notice 回调（事件通知）

```go
func(ctx, state, server, local) {
    switch state {
    case syncer.Update:
        // 1. 触发 OnSelfInfoUpdated 事件
        listener.OnSelfInfoUpdated(utils.StructToJsonString(server))
        // 2. 若昵称或头像有变化，更新会话和消息的头像昵称
        if server.Nickname != local.Nickname || server.FaceURL != local.FaceURL {
            DispatchUpdateConversation(UpdateConFaceUrlAndNickName, ...)
            DispatchUpdateMessage(UpdateMsgFaceUrlAndNickName, ...)
        }
    // 注意：Insert 和 Delete 不触发通知
    }
}
```

### 5.5 关键设计特点

1. **Delete 返回错误**：用户信息不允许删除，只能更新
2. **更新前清除缓存**：确保缓存一致性
3. **只在 Update 时触发通知**：Insert 不触发（首次登录不需要通知）
4. **条件性通知联动**：只有昵称或头像变化才更新会话/消息

---

## 6. UserCache 缓存机制

### 6.1 初始化（懒加载）

```go
func (u *User) UserCache() *UserCache[string, *LocalUser] {
    u.once.Do(func() {
        u.userCache = NewUserCache[string, *LocalUser](
            func(value *LocalUser) string { return value.UserID },  // Key 提取函数
            nil,  // 删除回调
            u.GetLoginUser,           // 本地数据源
            u.GetUsersInfoFromServer, // 远程数据源
        )
    })
    return u.userCache
}
```

### 6.2 缓存查询流程

```
UserCache.Fetch(ctx, userID)
├── 1. 检查内存缓存
│   ├── 命中 → 返回缓存数据
│   └── 未命中 → 继续
├── 2. 查询本地数据库 (GetLoginUser)
│   ├── 命中 → 缓存并返回
│   └── 未命中 → 继续
├── 3. 查询服务端 (GetUsersInfoFromServer)
│   ├── 命中 → 写入数据库 + 缓存 + 返回
│   └── 未命中 → 返回错误
```

### 6.3 BatchFetch 批量获取

```
UserCache.BatchFetch(ctx, userIDs)
├── 1. 批量检查内存缓存
├── 2. 未命中的查询数据库
├── 3. 仍未命中的批量查询服务端
├── 4. 写入数据库和缓存
└── 5. 返回所有结果
```

---

## 7. SyncLoginUserInfo 流程

### 7.1 标准版本

```go
func (u *User) SyncLoginUserInfo(ctx context.Context) error {
    // 1. 从服务端获取当前用户信息
    remoteUser, err := u.GetSingleUserFromServer(ctx, u.loginUserID)
    if err != nil { return err }

    // 2. 从本地数据库获取当前用户信息
    localUser, err := u.GetLoginUser(ctx, u.loginUserID)
    var localUsers []*LocalUser
    if err == nil {
        localUsers = []*LocalUser{localUser}
    }

    // 3. 使用 userSyncer.Sync 进行同步
    //    - 对比 remote 和 local 数据
    //    - 执行 Insert/Update/Delete 操作
    //    - 触发通知（OnSelfInfoUpdated + 会话/消息联动）
    return u.userSyncer.Sync(ctx, []*LocalUser{remoteUser}, localUsers, nil)
}
```

### 7.2 无通知版本

```go
func (u *User) SyncLoginUserInfoWithoutNotice(ctx context.Context) error {
    // 与标准版本相同，但 Sync 时传入 notice=false
    return u.userSyncer.Sync(ctx, []*LocalUser{remoteUser}, localUsers, nil, false, true)
}
```

### 7.3 调用时机

| 场景 | 方法 | 说明 |
|------|------|------|
| 登录成功后 | `SyncLoginUserInfo` | 同步最新用户信息 |
| 修改自身信息后 | `SyncLoginUserInfo` | `SetSelfInfo` 内部调用 |
| 收到用户信息更新通知 | `SyncLoginUserInfo` | `doNotification` 内部调用 |
| SDK 初始化（非首次） | `SyncLoginUserInfoWithoutNotice` | 避免初始化时触发大量通知 |

---

## 8. 通知处理

### 8.1 通知类型表

| 常量名 | 值 | Tips 类型 | 处理逻辑 |
|--------|-----|-----------|----------|
| `UserInfoUpdatedNotification` | 1401 | `UserInfoUpdatedTips` | 若 userID == loginUserID → SyncLoginUserInfo |

### 8.2 通知处理流程

```rust
fn do_notification(ctx, msg: &MsgData) -> Result<()> {
    match msg.content_type {
        UserInfoUpdatedNotification => {
            let tips: UserInfoUpdatedTips = unmarshal(msg.content)?;
            if tips.user_id == self.login_user_id {
                self.sync_login_user_info(ctx).await?;
            }
            // 如果不是当前用户，不做任何处理
        }
    }
    Ok(())
}
```

### 8.3 在线状态处理（非通知）

```go
func (u *User) UserOnlineStatusChange(users map[string][]int32) {
    for userID, platformIDs := range users {
        status := OnlineStatus{
            UserID:      userID,
            PlatformIDs: platformIDs,
            Status:      if len(platformIDs) == 0 { Offline } else { Online },
        }
        listener.OnUserStatusChanged(StructToJsonString(&status))
    }
}
```

---

## 9. GetUsersInfo 联动逻辑

`GetUsersInfo` 不仅返回用户信息，还会联动更新会话和消息：

```go
func (u *User) GetUsersInfo(ctx, userIDs) ([]*PublicUser, error) {
    // 1. 从缓存获取用户信息
    usersInfo, _ := u.GetUsersInfoWithCache(ctx, userIDs)
    res := datautil.Batch(LocalUserToPublicUser, usersInfo)

    // 2. 获取好友列表
    friendList, _ := u.GetFriendInfoList(ctx, userIDs)
    friendMap := datautil.SliceToMap(friendList, ...)

    // 3. 对于非好友用户，检查会话信息是否需要更新
    for _, userInfo := range res {
        if _, isFriend := friendMap[userInfo.UserID]; isFriend {
            continue  // 好友的头像昵称由 friendSyncer 管理
        }
        conversation, _ := u.GetConversationByUserID(ctx, userInfo.UserID)
        if conversation.ShowName != userInfo.Nickname || conversation.FaceURL != userInfo.FaceURL {
            // 4. 更新会话和消息的头像昵称
            DispatchUpdateConversation(UpdateConFaceUrlAndNickName, ...)
            DispatchUpdateMessage(UpdateMsgFaceUrlAndNickName, ...)
        }
    }
    return res, nil
}
```

---

## 10. 数据库表

### 10.1 local_users 表

```sql
CREATE TABLE IF NOT EXISTS local_users (
    user_id             TEXT PRIMARY KEY,        -- 用户 ID
    name                TEXT NOT NULL DEFAULT '', -- 用户昵称
    face_url            TEXT NOT NULL DEFAULT '', -- 头像 URL
    create_time         INTEGER NOT NULL DEFAULT 0, -- 创建时间
    app_manger_level    INTEGER NOT NULL DEFAULT 0, -- 管理员等级
    ex                  TEXT NOT NULL DEFAULT '', -- 扩展字段
    attached_info       TEXT NOT NULL DEFAULT '', -- 附加信息
    global_recv_msg_opt INTEGER NOT NULL DEFAULT 0  -- 全局消息接收选项
);
```

**字段与 Go 对应关系：**

| Rust 字段 | Go 字段 | 说明 |
|-----------|---------|------|
| `user_id` | `UserID` | 用户 ID |
| `name` | `Nickname` | 用户昵称 |
| `face_url` | `FaceURL` | 头像 URL |
| `create_time` | `CreateTime` | 创建时间戳 |
| `app_manger_level` | `AppMangerLevel` | 管理员等级 |
| `ex` | `Ex` | 扩展字段 |
| `attached_info` | `AttachedInfo` | 附加信息 |
| `global_recv_msg_opt` | `GlobalRecvMsgOpt` | 全局消息接收选项 |

---

## 11. Server ↔ Local 模型转换

### 11.1 ServerUserToLocalUser

```go
func ServerUserToLocalUser(user *sdkws.UserInfo) *LocalUser {
    return &LocalUser{
        UserID:          user.UserID,
        Nickname:        user.Nickname,
        FaceURL:         user.FaceURL,
        CreateTime:      user.CreateTime,
        Ex:              user.Ex,
        GlobalRecvMsgOpt: user.GlobalRecvMsgOpt,
        // AppMangerLevel 和 AttachedInfo 未从服务端同步
    }
}
```

### 11.2 LocalUserToPublicUser

```go
func LocalUserToPublicUser(user *LocalUser) *PublicUser {
    return &PublicUser{
        UserID:     user.UserID,
        Nickname:   user.Nickname,
        FaceURL:    user.FaceURL,
        Ex:         user.Ex,
        CreateTime: user.CreateTime,
    }
}
```

### 11.3 关键区别

- `LocalUser` 包含完整字段（含 GlobalRecvMsgOpt）
- `PublicUser` 是对外暴露的精简版本，不包含内部字段
- `UserInfoWithEx` 用于设置用户信息，支持部分字段更新

---

## 12. Rust 当前实现分析

### 12.1 已实现的功能

| 功能 | 状态 | 文件位置 |
|------|------|----------|
| 获取自身用户信息（内存） | ✅ 已实现 | `core/user/manager.rs::get_self_user_info` |
| 获取用户信息列表 | ✅ 已实现 | `core/user/manager.rs::get_users_info` |
| 更新自身信息 | ✅ 已实现 | `core/user/manager.rs::update_self_user_info` |
| 设置本地用户信息 | ✅ 已实现 | `core/user/manager.rs::set_self_user_info` |
| UserDao（CRUD） | ✅ 已实现 | `infra/database/user_dao.rs` |
| 在线状态处理 | ⚠️ 独立模块 | `core/online/manager.rs` |

### 12.2 缺失/待改进的功能

| 功能 | 状态 | 说明 |
|------|------|------|
| **userSyncer 同步器** | ❌ 缺失 | 没有实现 Syncer 机制（Insert/Update/Delete 回调） |
| **SyncLoginUserInfo** | ❌ 缺失 | 登录后未从服务端同步最新用户信息 |
| **UserCache 缓存** | ❌ 缺失 | 没有实现带本地优先 + 远程兜底的缓存策略 |
| **通知处理** | ❌ 缺失 | DoNotification 未实现，UserInfoUpdatedNotification 未处理 |
| **GetUserInfoWithCache** | ❌ 缺失 | 没有带缓存的查询方法 |
| **GetUsersInfoWithCache** | ❌ 缺失 | 没有批量带缓存的查询方法 |
| **GetSingleUserFromServer** | ⚠️ 简化 | 当前通过 HTTP 直接调用，但没有整合到缓存流程 |
| **GetUsersInfo 联动逻辑** | ❌ 缺失 | 获取用户信息后未联动更新会话/消息 |
| **条件性通知联动** | ❌ 缺失 | 用户信息变更后未更新关联会话和消息 |
| **OnSelfInfoUpdated 事件** | ❌ 缺失 | 未触发用户信息更新事件 |
| **用户数据持久化** | ⚠️ 部分 | UserDao 有基础功能，但 sync 逻辑未写入数据库 |

---

## 13. 重写建议

### 13.1 架构改造

```
UserManager
├── user_dao: UserDao               // 用户数据访问
├── event_bus: EventBus             // 事件分发
├── user_cache: LruCache            // 用户信息 LRU 缓存
├── self_user: Option<LocalUser>    // 当前用户信息
└── 核心方法
    ├── sync_login_user_info()      // 登录用户信息同步
    ├── get_self_user_info()        // 获取自身信息
    ├── set_self_info()             // 设置自身信息
    ├── get_users_info_with_cache() // 带缓存查询
    ├── do_notification()           // 通知处理
    └── user_online_status_change() // 在线状态处理
```

### 13.2 关键实现要点

1. **userSyncer 必须对齐 Go SDK**：
   - Delete 返回错误（不支持删除用户）
   - Update 前清除缓存
   - Notice 只在 Update 时触发

2. **UserCache 缓存策略**：
   - 内存缓存 → 本地数据库 → 服务端 API
   - 支持单条和批量查询
   - 缓存失效时自动从数据库或服务端重新加载

3. **SyncLoginUserInfo 必须在登录后执行**：
   - 获取服务端最新用户信息
   - 与本地数据对比
   - 通过 userSyncer.Sync 同步
   - 触发 OnSelfInfoUpdated 通知

4. **通知联动**：
   - 用户昵称/头像变化 → 更新会话和消息的头像昵称
   - 只更新非好友用户的会话（好友由 friendSyncer 管理）

5. **在线状态处理**：
   - 基于平台 ID 列表判断在线/离线
   - 触发 OnUserStatusChanged 事件

---

## 14. 测试用例

### 14.1 单元测试

```rust
#[tokio::test]
async fn test_user_dao_crud() {
    // 1. 创建 UserDao，执行 upsert
    // 2. 验证 get_by_id 返回正确数据
    // 3. 验证 delete 后数据不存在
}

#[tokio::test]
async fn test_server_to_user_conversion() {
    // 验证 ServerUserToLocalUser 转换正确
}

#[tokio::test]
async fn test_get_self_user_info() {
    // 1. 设置 self_user
    // 2. 调用 get_self_user_info
    // 3. 验证返回正确的用户信息
}

#[tokio::test]
async fn test_update_self_user_info() {
    // 1. 设置初始用户信息
    // 2. Mock HTTP API
    // 3. 调用 update_self_user_info
    // 4. 验证本地用户信息已更新
    // 5. 验证事件总线收到了 UserInfoUpdated 事件
}

#[tokio::test]
async fn test_sync_login_user_info() {
    // 1. Mock HTTP API 返回服务端用户信息
    // 2. 调用 sync_login_user_info
    // 3. 验证本地数据库已更新
    // 4. 验证缓存已更新
    // 5. 验证触发了 OnSelfInfoUpdated 事件
}

#[tokio::test]
async fn test_notification_handler_user_info_updated() {
    // 1. 模拟 UserInfoUpdatedNotification 消息
    // 2. 调用 do_notification
    // 3. 验证触发了 SyncLoginUserInfo
}

#[tokio::test]
async fn test_notification_handler_other_user() {
    // 1. 模拟 UserInfoUpdatedNotification（非当前用户）
    // 2. 调用 do_notification
    // 3. 验证没有触发 SyncLoginUserInfo
}

#[tokio::test]
async fn test_user_online_status_change() {
    // 1. 创建 UserManager
    // 2. 调用 user_online_status_change（用户上线）
    // 3. 验证触发了 OnUserStatusChanged 事件（status=Online）
    // 4. 调用 user_online_status_change（用户下线）
    // 5. 验证触发了 OnUserStatusChanged 事件（status=Offline）
}

#[tokio::test]
async fn test_user_cache_lookup_order() {
    // 1. 清空缓存
    // 2. 插入数据库
    // 3. 查询 → 验证从数据库加载
    // 4. 更新数据库
    // 5. 查询 → 验证缓存未命中，重新从数据库加载
}
```

### 14.2 集成测试

```rust
#[tokio::test]
async fn test_login_then_sync_user_info() {
    // 1. 模拟登录流程
    // 2. 调用 sync_login_user_info
    // 3. 验证用户信息完整同步
    // 4. 修改服务端用户信息
    // 5. 收到 UserInfoUpdatedNotification
    // 6. 验证本地信息已更新
}

#[tokio::test]
async fn test_set_self_info_then_sync() {
    // 1. 获取当前用户信息
    // 2. 修改昵称
    // 3. 调用 set_self_info
    // 4. 验证服务端已更新
    // 5. 验证本地信息已更新
    // 6. 验证事件已触发
}
```

---

## 15. 与其他模块的交互

### 15.1 与 Friend 模块的交互

```
UserManager.GetUsersInfo()
├── UserManager.GetUsersInfoWithCache()  // 获取用户信息
├── RelationManager.GetFriendInfoList()  // 获取好友列表
└── 根据好友关系决定是否更新会话头像昵称
    ├── 好友 → 不更新（由 friendSyncer 管理）
    └── 非好友 → 更新会话和消息的头像昵称
```

### 15.2 与 Conversation 模块的交互

```
UserManager.SyncLoginUserInfo()
└── userSyncer.Notice(Update)
    ├── OnSelfInfoUpdated(event_bus)
    ├── DispatchUpdateConversation(UpdateConFaceUrlAndNickName)
    └── DispatchUpdateMessage(UpdateMsgFaceUrlAndNickName)
```

### 15.3 与 Connection 模块的交互

```
ConnectionManager.OnLoginSuccess()
└── UserManager.SyncLoginUserInfo()  // 登录后同步用户信息
```

---

## 16. 事件类型定义

```rust
pub enum SdkEvent {
    // 用户相关事件
    UserInfoUpdated { user: UserInfo },
    UserStatusChanged { user_id: String, status: OnlineStatus },

    // 好友相关事件（UserManager 间接触发）
    // ...

    // 群组相关事件（UserManager 间接触发）
    // ...
}

pub enum OnlineStatus {
    Online,
    Offline,
}

pub struct OnlineStatusInfo {
    pub user_id: String,
    pub platform_ids: Vec<i32>,
    pub status: OnlineStatus,
}
```
