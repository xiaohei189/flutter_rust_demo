# 泛型同步器框架详细设计

> 来源：Go SDK `pkg/syncer/syncer.go` + `pkg/syncer/version_synchronizer.go`
> 用途：Rust SDK 同步器框架的实现参考

---

## 1. Go SDK 同步器框架概述

Go SDK 实现了两层同步器：

1. **Syncer（基础同步器）** — 实现 diff-reconcile 算法，对比服务端和本地数据，执行 insert/update/delete 操作
2. **VersionSynchronizer（版本同步器）** — 基于版本号的增量同步框架，管理版本状态，决定是增量同步还是全量同步

两层关系：`VersionSynchronizer` 内部调用 `Syncer` 完成实际的数据同步。

---

## 2. Syncer 结构体

### 2.1 泛型参数

```go
type Syncer[T, RESP any, V comparable] struct { ... }
```

| 泛型参数 | 含义 | 示例 |
|----------|------|------|
| `T` | 本地数据模型 | `*LocalFriend`, `*LocalGroup`, `*LocalConversation` |
| `RESP` | 服务端分页响应类型 | `*relation.GetPaginationFriendsResp` |
| `V` | UUID 类型（必须可比较） | `string`（用户 ID、群组 ID 等） |

### 2.2 字段定义

| 字段 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `insert` | `fn(ctx, server T) -> Result<()>` | ✅ | 插入一条新记录 |
| `update` | `fn(ctx, server T, local T) -> Result<()>` | ✅ | 更新一条已有记录 |
| `delete` | `fn(ctx, local T) -> Result<()>` | ✅ | 删除一条记录 |
| `uuid` | `fn(value T) -> V` | ✅ | 提取记录的唯一标识 |
| `equal` | `fn(server T, local T) -> bool` | - | 比较两条记录是否相等（默认用 `cmp.Equal`） |
| `notice` | `fn(ctx, state, server T, local T) -> Result<()>` | - | 同步状态通知回调 |
| `batchInsert` | `fn(ctx, servers Vec<T>) -> Result<()>` | - | 批量插入（用于 FullSync） |
| `deleteAll` | `fn(ctx, entity_id: &str) -> Result<()>` | - | 删除所有记录（用于 FullSync） |
| `batchPageReq` | `fn(entity_id: &str) -> PageReq` | - | 构建分页请求（用于 FullSync） |
| `batchPageRespConvertFunc` | `fn(resp: &RESP) -> Vec<T>` | - | 分页响应转换（用于 FullSync） |
| `reqApiRouter` | `String` | - | API 路由（用于 FullSync） |
| `fullSyncLimit` | `i64` | - | 全量同步分页大小 |
| `ts` | `String` | - | 类型名称（用于日志） |

### 2.3 同步状态常量

```go
const (
    Unchanged = 0  // 无变化
    Insert    = 1  // 新增
    Update    = 2  // 更新
    Delete    = 3  // 删除
)
```

---

## 3. Sync() 方法 — Diff-Reconcile 算法

### 3.1 算法流程

```
输入: serverData (服务端数据), localData (本地数据)
输出: 执行 insert/update/delete 操作

1. 如果 serverData 和 localData 都为空 → 直接返回

2. 将 localData 转换为 HashMap<UUID, T>
   localMap = { uuid(item) → item | item in localData }

3. 遍历 serverData 中的每一条 server 记录:
   id = uuid(server)
   local = localMap.get(id)

   情况 A: local 不存在
     → insert(server)
     → notice(Insert, server, nil)

   情况 B: local 存在 且 equal(server, local) == true
     → notice(Unchanged, local, server)
     → 从 localMap 中删除 id

   情况 C: local 存在 且 equal(server, local) == false
     → update(server, local)
     → notice(Update, server, local)
     → 从 localMap 中删除 id

4. localMap 中剩余的记录 = 服务端已不存在的本地记录
   遍历剩余记录:
     → delete(local)
     → notice(Delete, nil, local)
```

### 3.2 可选参数 `skipDeletionAndNotice`

| 参数位置 | 默认值 | 描述 |
|----------|--------|------|
| 第 1 个 | `false` | 跳过删除操作（会话同步时使用，会话不应被自动删除） |
| 第 2 个 | `false` | 跳过通知回调 |

### 3.3 Rust 实现伪代码

```rust
pub enum SyncState {
    Unchanged = 0,
    Insert = 1,
    Update = 2,
    Delete = 3,
}

pub struct Syncer<T, RESP, V>
where
    T: Clone,
    V: Eq + std::hash::Hash + Clone,
{
    insert: Box<dyn Fn(&T) -> Result<()>>,
    update: Box<dyn Fn(&T, &T) -> Result<()>>,
    delete: Box<dyn Fn(&T) -> Result<()>>,
    uuid: Box<dyn Fn(&T) -> V>,
    equal: Box<dyn Fn(&T, &T) -> bool>,
    notice: Option<Box<dyn Fn(SyncState, Option<&T>, Option<&T>) -> Result<()>>>,
    // ... 其他字段
}

impl<T, RESP, V> Syncer<T, RESP, V>
where
    T: Clone,
    V: Eq + std::hash::Hash + Clone,
{
    pub fn sync(
        &self,
        server_data: &[T],
        local_data: &[T],
        skip_deletion: bool,
        skip_notice: bool,
    ) -> Result<()> {
        if server_data.is_empty() && local_data.is_empty() {
            return Ok(());
        }

        // 1. 构建本地 Map
        let mut local_map: HashMap<V, &T> = local_data.iter()
            .map(|item| ((self.uuid)(item), item))
            .collect();

        // 2. 遍历服务端数据
        for server in server_data {
            let id = (self.uuid)(server);

            match local_map.remove(&id) {
                None => {
                    // 服务端有，本地无 → 插入
                    (self.insert)(server)?;
                    if !skip_notice {
                        self.on_notice(SyncState::Insert, Some(server), None)?;
                    }
                }
                Some(local) => {
                    if (self.equal)(server, local) {
                        // 完全相同 → 无变化
                        if !skip_notice {
                            self.on_notice(SyncState::Unchanged, Some(local), Some(server))?;
                        }
                    } else {
                        // 有变化 → 更新
                        (self.update)(server, local)?;
                        if !skip_notice {
                            self.on_notice(SyncState::Update, Some(server), Some(local))?;
                        }
                    }
                }
            }
        }

        // 3. 处理本地剩余记录（服务端已删除）
        if !skip_deletion {
            for (_id, local) in &local_map {
                (self.delete)(local)?;
                if !skip_notice {
                    self.on_notice(SyncState::Delete, None, Some(local))?;
                }
            }
        }

        Ok(())
    }
}
```

---

## 4. FullSync() 方法 — 全量同步

### 4.1 算法流程

```
输入: entityID (实体标识)
输出: 本地数据完全替换为服务端数据

1. deleteAll(entityID)  // 清空本地表

2. batchReq = batchPageReq(entityID)  // 构建分页请求

3. 分页拉取服务端数据:
   loop {
     resp = POST(reqApiRouter, batchReq)
     items = batchPageRespConvertFunc(resp)
     if items.is_empty() { break }

     if items.len() >= fullSyncLimit {
       batchInsert(items)  // 批量插入
     } else {
       for item in items {
         insert(item)  // 逐条插入
       }
     }

     // 更新分页游标，继续下一页
   }
```

### 4.2 Rust 实现要点

```rust
impl<T, RESP, V> Syncer<T, RESP, V> {
    pub async fn full_sync(&self, entity_id: &str) -> Result<()> {
        // 1. 清空本地数据
        (self.delete_all)(entity_id).await?;

        // 2. 构建分页请求
        let mut req = (self.batch_page_req)(entity_id);

        // 3. 分页拉取并插入
        loop {
            let resp: RESP = self.http_client
                .post(&self.req_api_router, &req)
                .await?;

            let items = (self.batch_page_resp_convert_func)(&resp);
            if items.is_empty() {
                break;
            }

            if items.len() as i64 >= self.full_sync_limit {
                // 批量插入
                (self.batch_insert)(&items).await?;
            } else {
                // 逐条插入
                for item in &items {
                    (self.insert)(item).await?;
                }
            }

            // 如果返回数量不足一页，说明已是最后一页
            if (items.len() as i64) < self.full_sync_limit {
                break;
            }

            // 更新分页游标...
        }

        Ok(())
    }
}
```

---

## 5. VersionSynchronizer — 增量同步框架

### 5.1 结构体定义

```go
type VersionSynchronizer[V, R any] struct {
    Ctx                context.Context
    DB                 db_interface.VersionSyncModel
    TableName          string                        // 本地表名
    EntityID           string                        // 实体 ID（用户 ID / 群组 ID）
    Key                func(V) string                // 提取本地模型的唯一键
    Local              func() ([]V, error)           // 获取本地所有数据
    ServerVersion      func() R                      // 从推送通知获取服务端版本（可选）
    Server             func(*LocalVersionSync) (R, error) // 从服务端拉取增量数据
    Full               func(R) bool                  // 判断是否需要全量同步
    Version            func(R) (string, uint64)      // 从响应中提取 versionID 和 version
    Delete             func(R) []string              // 从响应中提取要删除的 ID 列表
    Update             func(R) []V                   // 从响应中提取要更新的数据
    Insert             func(R) []V                   // 从响应中提取要插入的数据
    ExtraData          func(R) any                   // 提取额外数据（可选）
    ExtraDataProcessor func(ctx, data) error         // 处理额外数据（可选）
    Syncer             func(server, local []V) error // 调用 Syncer.Sync()
    FullSyncer         func(ctx) error               // 调用 Syncer.FullSync()
    FullID             func(ctx) ([]string, error)    // 获取全部 ID 列表
    IDOrderChanged     func(R) bool                  // ID 顺序是否变化
}
```

### 5.2 IncrementalSync() — 增量同步流程

```
1. 获取本地版本信息:
   lvs = DB.GetVersionSync(TableName, EntityID)

2. 从服务端获取增量数据:
   如果 ServerVersion != nil（来自推送通知）:
     resp = ServerVersion()  // 使用推送的数据
   否则:
     resp = Server(lvs)      // 主动拉取增量数据

3. 提取变更:
   delIDs = Delete(resp)      // 要删除的 ID
   changes = Update(resp)     // 要更新的数据
   insert = Insert(resp)      // 要插入的数据
   extraData = ExtraData(resp) // 额外数据

4. 如果所有变更都为空 且 不需要全量同步 且 无额外数据:
   → 直接返回（无变更）

5. 判断是否需要全量同步:
   如果 Full(resp) == true:
     → FullSyncer(ctx)       // 执行全量同步
     → UIDList = FullID(ctx)  // 重新获取完整 ID 列表
   否则:
     a. 从 UIDList 中移除 delIDs
     b. 将 insert 合并到 changes
     c. 将 changes 中的新 ID 添加到 UIDList
     d. 获取本地数据 Local()
     e. 构建完整的 server 数据集（合并 changes、移除 delIDs）
     f. 调用 Syncer(server, local) 执行 diff 同步
     g. 如果有额外数据，调用 ExtraDataProcessor

6. 如果 IDOrderChanged(resp):
   → UIDList = FullID(ctx)  // 刷新 ID 顺序

7. 更新版本信息:
   lvs.VersionID, lvs.Version = Version(resp)
   DB.SetVersionSync(lvs)
```

### 5.3 CheckVersionSync() — 推送通知触发的同步

当收到服务端推送通知时，使用 `CheckVersionSync()` 而非 `IncrementalSync()`：

```
1. 获取本地版本信息
2. 使用 ServerVersion()（推送的数据）
3. 提取变更
4. 比较版本号:
   - versionID 不匹配 → 回退到 IncrementalSync()
   - version == lvs.Version + 1 → 增量同步（快速路径）
   - version <= lvs.Version → 忽略（旧数据）
   - version > lvs.Version + 1 → 版本跳跃，回退到 IncrementalSync()
```

---

## 6. 所有同步器实例汇总

### 6.1 Syncer 实例（基础 diff 同步）

| 实例名称 | 类型 T | UUID 类型 V | 用途 | 创建位置 |
|----------|--------|-------------|------|----------|
| `friendSyncer` | `*LocalFriend` | `string` | 好友列表 diff 同步 | `internal/relation/` |
| `blackSyncer` | `*LocalBlack` | `string` | 黑名单 diff 同步 | `internal/relation/` |
| `friendRequestSyncer` | `*LocalFriendRequest` | `string` | 好友申请 diff 同步 | `internal/relation/` |
| `groupSyncer` | `*LocalGroup` | `string` | 群组列表 diff 同步 | `internal/group/` |
| `groupMemberSyncer` | `*LocalGroupMember` | `string` | 群成员 diff 同步 | `internal/group/` |
| `groupRequestSyncer` | `*LocalGroupRequest` | `string` | 群组申请 diff 同步 | `internal/group/` |
| `conversationSyncer` | `*LocalConversation` | `string` | 会话列表 diff 同步 | `internal/conversation_msg/` |

### 6.2 VersionSynchronizer 实例（增量同步）

| 实例名称 | 本地模型 | 服务端响应 | 触发方式 | FullSync API |
|----------|----------|-----------|----------|-------------|
| 好友增量同步 | `LocalFriend` | `GetIncrementalFriendsResp` | 拉取 / 推送通知 | `get_friend_list` → `get_full_friend_user_ids` |
| 群组增量同步 | `LocalGroup` | `GetIncrementalJoinGroupResp` | 拉取 / 推送通知 | `get_joined_group_list` → `get_full_join_group_ids` |
| 群成员增量同步 | `LocalGroupMember` | `GetIncrementalGroupMemberResp` | 拉取 / 推送通知（批量） | `get_group_member_list` → `get_full_group_member_user_ids` |
| 会话增量同步 | `LocalConversation` | `GetIncrementalConversationResp` | 拉取 / 推送通知 | `get_all_conversations` → `get_full_conversation_ids` |

### 6.3 同步器详细配置

#### 好友同步器

```go
// IncrementalSync 配置
TableName:  "local_friends"
EntityID:   loginUserID
Key:        FriendUserID
Local:      db.GetAllFriendList()
Server:     getIncrementalFriends(version, versionID)
Full:       resp.Full
Version:    (resp.VersionID, resp.Version)
Delete:     resp.Delete
Update:     Batch(ServerFriendToLocalFriend, resp.Update)
Insert:     Batch(ServerFriendToLocalFriend, resp.Insert)
Syncer:     friendSyncer.Sync()
FullSyncer: friendSyncer.FullSync()
FullID:     getFullFriendUserIDs() → resp.UserIDs
IDOrderChanged: resp.SortVersion > 0

// FullSync 分页 API
reqApiRouter: "/friend/get_friend_list"
batchPageReq: GetPaginationFriendsReq{UserID, Pagination}
```

#### 群组同步器

```go
TableName:  "local_groups"
EntityID:   loginUserID
Key:        GroupID
Local:      db.GetJoinedGroupListDB()
Server:     getIncrementalJoinGroup(version, versionID)
Full:       resp.Full
Version:    (resp.VersionID, resp.Version)
Delete:     resp.Delete
Update:     Batch(ServerGroupToLocalGroup, resp.Update)
Insert:     Batch(ServerGroupToLocalGroup, resp.Insert)
Syncer:     groupSyncer.Sync()
FullSyncer: groupSyncer.FullSync()
FullID:     getFullJoinGroupIDs() → resp.GroupIDs
IDOrderChanged: resp.SortVersion > 0
```

#### 群成员同步器

```go
TableName:  "local_group_entities_version"  // 特殊表名，群组和成员共用
EntityID:   groupID                          // 每个群组独立版本
Key:        UserID
Local:      db.GetGroupMemberListByGroupID(groupID)
Server:     getIncrementalGroupMemberBatch(groupIDs)
Full:       resp.Full
Version:    (resp.VersionID, resp.Version)
Delete:     resp.Delete（UserID 列表）
Update:     Batch(ServerGroupMemberToLocalGroupMember, resp.Update)
Insert:     Batch(ServerGroupMemberToLocalGroupMember, resp.Insert)
ExtraData:  resp.Group（附带的群组信息变更）
ExtraDataProcessor: 更新本地群组信息
Syncer:     groupMemberSyncer.Sync()
FullSyncer: groupMemberSyncer.FullSync()
FullID:     getFullGroupMemberUserIDs(groupID) → resp.UserIDs
IDOrderChanged: resp.SortVersion > 0
```

#### 会话同步器

```go
TableName:  "local_conversations"
EntityID:   loginUserID
Key:        ConversationID
Local:      db.GetAllConversations()
Server:     getIncrementalConversationFromServer(version, versionID)
Full:       resp.Full
Version:    (resp.VersionID, resp.Version)
Delete:     resp.Delete
Update:     Batch(ServerConversationToLocal, resp.Update)
Insert:     Batch(ServerConversationToLocal, resp.Insert)
Syncer:     conversationSyncer.Sync(skipDeletion=true)  // 会话不自动删除
FullSyncer: 特殊逻辑：
  - 如果本地无会话 → FullSync
  - 如果本地有会话 → 拉取全部服务端会话 → Sync（保持本地独有的会话）
FullID:     getAllConversationIDsFromServer() → resp.ConversationIDs
```

---

## 7. Rust 实现建议

### 7.1 泛型同步器设计

Rust 没有 Go 的泛型函数语法，推荐使用 trait object 或 enum dispatch：

```rust
/// 同步状态
pub enum SyncState {
    Unchanged,
    Insert,
    Update,
    Delete,
}

/// 基础同步器 trait
pub trait SyncerCallbacks<T> {
    fn insert(&self, server: &T) -> Result<()>;
    fn update(&self, server: &T, local: &T) -> Result<()>;
    fn delete(&self, local: &T) -> Result<()>;
    fn uuid(&self, value: &T) -> String;
    fn equal(&self, server: &T, local: &T) -> bool;
    fn notice(&self, state: SyncState, server: Option<&T>, local: Option<&T>) -> Result<()>;
}

/// 基础同步器
pub struct Syncer<T> {
    callbacks: Box<dyn SyncerCallbacks<T>>,
}

impl<T: Clone> Syncer<T> {
    pub fn sync(
        &self,
        server_data: &[T],
        local_data: &[T],
        skip_deletion: bool,
        skip_notice: bool,
    ) -> Result<()> {
        // diff-reconcile 算法实现
        todo!()
    }

    pub fn full_sync(&self, entity_id: &str) -> Result<()> {
        // 全量同步实现
        todo!()
    }
}
```

### 7.2 版本同步器设计

```rust
/// 增量同步响应 trait
pub trait IncrementalResp {
    fn version_id(&self) -> &str;
    fn version(&self) -> u64;
    fn is_full(&self) -> bool;
    fn delete_ids(&self) -> Vec<String>;
}

/// 版本同步器
pub struct VersionSynchronizer<V, R> {
    pub table_name: String,
    pub entity_id: String,
    pub key_fn: Box<dyn Fn(&V) -> String>,
    pub local_fn: Box<dyn Fn() -> Result<Vec<V>>>,
    pub server_fn: Option<Box<dyn Fn(&LocalVersionSync) -> Result<R>>>,
    pub server_version_fn: Option<Box<dyn Fn() -> R>>,
    pub full_fn: Box<dyn Fn(&R) -> bool>,
    pub version_fn: Box<dyn Fn(&R) -> (String, u64)>,
    pub delete_fn: Box<dyn Fn(&R) -> Vec<String>>,
    pub update_fn: Box<dyn Fn(&R) -> Vec<V>>,
    pub insert_fn: Box<dyn Fn(&R) -> Vec<V>>,
    pub syncer: Box<dyn Fn(&[V], &[V]) -> Result<()>>,
    pub full_syncer: Box<dyn Fn() -> Result<()>>,
    pub full_id_fn: Box<dyn Fn() -> Result<Vec<String>>>,
    pub id_order_changed_fn: Option<Box<dyn Fn(&R) -> bool>>,
    pub db: Arc<dyn VersionSyncDao>,
}

impl<V: Clone, R> VersionSynchronizer<V, R> {
    pub fn incremental_sync(&self) -> Result<()> {
        // 增量同步实现
        todo!()
    }

    pub fn check_version_sync(&self) -> Result<()> {
        // 推送通知触发的同步
        todo!()
    }
}
```

### 7.3 复合键支持

群成员同步器使用 `group_id` 作为 EntityID，`user_id` 作为 UUID。对于需要复合键的场景，可以：

```rust
// 方案 1: 使用 String 拼接
fn uuid(member: &LocalGroupMember) -> String {
    format!("{}:{}", member.group_id, member.user_id)
}

// 方案 2: 使用 (String, String) 元组
fn uuid(member: &LocalGroupMember) -> (String, String) {
    (member.group_id.clone(), member.user_id.clone())
}
```

### 7.4 异步回调

Go SDK 中同步器的回调是同步函数，在 Rust 中建议使用 `async-trait`：

```rust
#[async_trait]
pub trait SyncerCallbacks<T: Send + Sync> {
    async fn insert(&self, server: &T) -> Result<()>;
    async fn update(&self, server: &T, local: &T) -> Result<()>;
    async fn delete(&self, local: &T) -> Result<()>;
    fn uuid(&self, value: &T) -> String;
    fn equal(&self, server: &T, local: &T) -> bool;
    async fn notice(&self, state: SyncState, server: Option<&T>, local: Option<&T>) -> Result<()>;
}
```

### 7.5 会话同步的特殊处理

会话同步器的 `Sync()` 调用时 `skipDeletion=true`，这意味着本地独有的会话不会被删除。这是因为：

1. 用户可能在本地创建了草稿、置顶等状态
2. 会话可能因为服务端清理而不存在，但本地仍需保留
3. `FullSync` 时会检查本地是否已有会话数据，决定是全量替换还是增量合并

```rust
// 会话 FullSync 的特殊逻辑
async fn conversation_full_sync(&self) -> Result<()> {
    let local_conversations = self.db.get_all_conversations().await?;

    if local_conversations.is_empty() {
        // 本地无数据，直接全量同步
        self.syncer.full_sync(&self.login_user_id).await
    } else {
        // 本地有数据，拉取服务端全部会话后 diff
        let resp = self.http.get_all_conversations().await?;
        let server: Vec<LocalConversation> = resp.conversations
            .into_iter()
            .map(ServerConversationToLocal)
            .collect();
        self.syncer.sync(&server, &local_conversations, true, false).await
    }
}
```

### 7.6 群成员同步的批量处理

群成员同步是批量进行的，每次最多同步 `MaxSyncPullNumber` 个群组的成员：

```rust
async fn incr_sync_group_and_member(&self, group_ids: Vec<String>) -> Result<()> {
    let max_sync_num = MAX_SYNC_PULL_NUMBER;
    let mut remaining: HashSet<String> = group_ids.into_iter().collect();

    while !remaining.is_empty() {
        let mut batch = Vec::new();
        for group_id in &remaining {
            if batch.len() >= max_sync_num {
                break;
            }
            let lvs = self.db.get_version_sync("local_group_entities_version", group_id).await;
            batch.push(GetIncrementalGroupMemberReq {
                group_id: group_id.clone(),
                version_id: lvs.as_ref().map(|v| v.version_id.clone()).unwrap_or_default(),
                version: lvs.as_ref().map(|v| v.version).unwrap_or(0),
            });
        }

        let responses = self.http.get_incremental_group_member_batch(&batch).await?;

        for (group_id, resp) in responses {
            self.sync_group_and_member(&group_id, &resp).await?;
            remaining.remove(&group_id);
        }
    }
    Ok(())
}
```

---

## 8. 同步流程时序图

### 8.1 登录后首次同步

```
Client                    Server                    Local DB
  |                         |                          |
  |----Login--------------->|                          |
  |<---Token---------------|                          |
  |                         |                          |
  |--- GetNewestSeq ------->|                          |
  |<-- Seq ----------------|                          |
  |                         |                          |
  |=== 增量同步（4 个并行）====|                          |
  |                         |                          |
  |--- IncrSyncFriends ---->|                          |
  |<-- IncrementalFriends --|                          |
  |                         |---- INSERT/UPDATE ------->|
  |                         |                          |
  |--- IncrSyncGroups ----->|                          |
  |<-- IncrementalGroups ---|                          |
  |                         |---- INSERT/UPDATE ------->|
  |                         |                          |
  |--- IncrSyncMembers --->|                           |
  |<-- IncrementalMembers -|                           |
  |                         |---- INSERT/UPDATE ------->|
  |                         |                          |
  |--- IncrSyncConvos ----->|                          |
  |<-- IncrementalConvos --|                           |
  |                         |---- INSERT/UPDATE ------->|
  |                         |                          |
  |=== MsgSyncBegin ========|                          |
  |--- PullMsgByRange ----->|                          |
  |<-- Messages ------------|                           |
  |                         |---- INSERT -------------->|
  |=== MsgSyncEnd =========|                           |
  |                         |                          |
```

### 8.2 推送通知触发同步

```
Client                    Server                    Local DB
  |                         |                          |
  |<--- PushMsg (Notif) ----|                          |
  |                         |                          |
  |--- CheckVersionSync --->|                          |
  |<-- IncrementalData -----|                           |
  |                         |---- INSERT/UPDATE ------->|
  |                         |                          |
  |--- notify UI ---------->|                          |
```

---

## 9. 错误处理与重试策略

1. **网络错误**: 指数退避重试（最多 3 次）
2. **版本不匹配**: 自动降级到全量同步
3. **数据库错误**: 立即终止同步，记录日志
4. **解析错误**: 跳过当前记录，继续处理下一条

```rust
// 重试策略
async fn with_retry<F, Fut, T>(max_retries: u32, mut f: F) -> Result<T>
where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = Result<T>>,
{
    let mut retries = 0;
    loop {
        match f().await {
            Ok(val) => return Ok(val),
            Err(e) if retries < max_retries => {
                retries += 1;
                let delay = Duration::from_millis(100 * 2u64.pow(retries));
                tokio::time::sleep(delay).await;
            }
            Err(e) => return Err(e),
        }
    }
}
```
