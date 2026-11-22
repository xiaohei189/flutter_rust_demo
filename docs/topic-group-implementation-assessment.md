# 话题群当前项目实现评估

> 状态：核心产品闭环已落地，生产化补强项见 §1.1
>
> 基线：[topic-group-product-spec.md](./topic-group-product-spec.md)
>
> 目标：按真实可用、多端一致的标准完成全量话题群能力，不以纯 UI 或本地模拟交付

## 1. 结论

目前已形成可运行的话题群主链路：

- 普通群与话题群共用 `sg_<groupID>` 会话，群模式保存在 `Group.ex.openim_topic`。
- `MsgData`、Rust 消息模型和 SQLite `local_chat_logs` 均增加 `topicID/topic_id`。
- 根消息满足 `topicID == clientMsgID`，回复的 `topicID` 指向根消息。
- OpenIM Server 新增 `openim.topic.TopicService`、StatefulSet 内的独立 topic RPC 进程和 Mongo 话题集合。
- 消息落库后由 msgtransfer 幂等索引话题；回复聚合从消息明细重算，失败重试可自愈。
- Flutter 已接入全部 / 我订阅的、发布根话题、回复、订阅、已读、Pin、关闭、重开、撤回和搜索 API。
- 话题卡片支持 Reaction，详情页使用现有 `MessageBubble` 渲染根消息和回复。
- 会话列表已接入服务端话题摘要和未读话题数，并支持整群话题标记已读。
- 会话详情按群模式分流到普通聊天或话题首页；群设置页可切换群模式。
- 普通群切到话题群时不追溯旧消息；切回普通群后继续普通收发，再切回话题群时旧话题仍保留。
- 发布和回复复用现有群聊编辑器，已支持 Markdown、@、引用、图片/多图、视频、语音、文件、位置、名片和按话题持久化草稿。
- 已实现订阅、单话题已读/未读、整群已读、Pin、关闭/重开、撤回、作者编辑、Reaction 和任务增删改状态。
- 已实现话题分享 sheet、复制深链、应用内话题卡片、系统深链以及登录前后挂起消费。
- Topic 索引具备持久化 outbox、初次失败重试、指数退避、死信保留和最近 7 天消息幂等对账。
- 个人事件使用群内 online-only 事件加 `targetUserID` 过滤；Rust 接收层已修复“自己发送的 online-only 事件被当作本地回显丢弃”的问题，并补了回归测试。
- 真实服务端 E2E 已验证双用户发布/回复、任务、订阅事件、阅读同步、作者编辑、非作者拒绝、模式往返和解散群。
- 搜索已支持作者、时间、开放/关闭、附件、任务和 Pin 组合筛选，并补齐游标分页。
- 服务端新增持久化话题通知集合和读状态 API；通知中心覆盖新话题、回复、@我、状态变更、编辑和任务事件，客户端保留本地离线投影与实时增量。
- 群设置已支持成员发布/回复权限、自动订阅和通知策略；服务端强制校验管理员权限，并阻止受限成员发送。
- 话题卡片已显示 @我 状态，读操作会清除该状态；已关闭、Pin 管理和只读历史消息都有独立入口。
- 话题群首页已按飞书视觉骨架重构：每个群使用独立主题色群头，全局交互仍保持品牌蓝；话题列表改为白色内容面板、全宽信息流、作者区、统一四操作栏和圆形发布按钮。
- 话题群更多菜单已统一为白色克制浮层，操作按设置/资料、内容管理、刷新分组，并补充图标、分隔线和紧凑行高。
- 会话详情路由已修复服务端群资料短暂丢失 `ex` 时错误降级为普通聊天的问题；本地已同步的话题模式作为可靠兜底。
- 话题卡“回复”会在卡片内展开编辑器，发送成功后收起并做短延时重刷，等待服务端完成回复聚合，避免计数短暂停留旧值。
- 话题卡“添加任务”和“编辑话题”已复用公共对话框，并在服务端返回后刷新卡片。
- 话题详情改为扁平讨论流：根消息和回复统一左对齐，使用作者、时间、正文结构，并以“N 条话题回复”分隔根消息与回复。
- Pin 与“置顶话题”已拆成独立服务端状态：Pin 负责独立集合，群级置顶负责首页顶部排序。
- 群设置支持分别限制成员 Pin 和群级置顶；受限成员取消置顶只写入个人 `groupPinnedHidden`，不会改变管理员和其他成员的群级置顶。
- 转发话题会抓取完整根消息正文并分页拉取全部回复，随卡片携带回复快照；接收方可在卡片中展开阅读，分页异常时会明确提示快照不完整及原始回复总数。
- 话题列表、详情、回复、任务、搜索和群摘要均已接入按账号隔离的本地只读缓存，服务不可达时回退缓存。
- 索引死信新增管理员查询、重试、删除 RPC/API 和客户端运维页，服务端校验 IM 管理员身份。

### 1.1 仍待生产化补强

- 完整多设备冷启动分享、大群性能、断网重连和服务重启专项回归。
- 群设置中的发布/回复权限、默认订阅策略和通知策略仍需从产品基线继续细化。

## 2. 当前实现事实

以下表格保留最初评估时的基线，用于说明为什么必须同时修改三端；“当前缺口”列描述的是改造前状态，现已由后续实施解决。

### 2.1 已存在

- 建群页有“群模式”入口。
- 群模式页可切换对话 / 话题并展示预览。
- `GroupMode` 领域枚举存在。
- 群模型、群成员、群设置、禁言、邀请、踢人等普通群能力完整。
- `local_groups` 表已有 `group_type` 和 `ex`。
- 消息模型 `ChatMessage` 和 Rust `MsgStruct` 已有 `ex`。
- `local_chat_logs` 已有 `ex` 和 `local_ex`。
- 会话支持 `ex` 并同步到服务端。
- 消息发送、历史分页、媒体、附件、@、引用和撤回已有可复用能力。

### 2.2 当前缺口

| 缺口 | 当前情况 |
|---|---|
| 模式未持久化 | 建群固定传 `groupType: 2`，ViewModel 未携带 `GroupMode` |
| 群扩展字段丢失 | Rust `GroupInfo`、Dart `Group` 没有 `ex` |
| 服务端转换丢失 | `server_to_group_info`、`group_info_to_local` 不保留 `ex` |
| 创群 FFI 不支持扩展 | 只有 name/type/memberIds |
| 群资料更新 FFI 不支持扩展 | `set_group_info` 没有 `ex` |
| 消息构造无话题元数据 | `createTextMessage` 等 builder 不接收 `ex` |
| 本地消息丢 ex | `messageFromMsgStruct` 当前固定返回 `ex: ''` |
| 无话题服务 | OpenIM 当前无 topic/thread/subscription API |
| 无话题缓存 | SQLite 没有 topics、topic_messages、topic_user_state |
| 无话题事件 | 只有 connection/message/conversation/friend/group/user 六类事件 |
| 无话题路由和页面 | 只有普通 ChatDetail 和 GroupInfo |

## 3. 架构选择

### 3.1 不采用

- 纯 Flutter 本地话题：无法多端一致。
- 每个话题创建一个群：成员、权限、通知和会话列表会失控。
- 把订阅、关闭和未读全部塞进 `Message.ex`：不可查询、不可并发控制。
- 运行期扫描所有群消息解析 `ex`：大群不可用。

### 3.2 推荐

推荐在 OpenIM Server 中新增独立话题域，或部署与 OpenIM 紧耦合的话题 sidecar：

```text
Flutter / Rust SDK
        │
        ├─ 普通消息、群成员、实时投递 → OpenIM
        └─ 话题列表、订阅、未读、状态 → Topic API
                                      │
                                      ├─ Group RPC
                                      ├─ Message RPC
                                      ├─ Topic DB
                                      ├─ Search Index
                                      └─ Notification
```

推荐优先采用“OpenIM Server 新增 topic 模块”，原因：

- 复用 Token 和群成员鉴权。
- 复用群、消息和通知 RPC。
- 可直接接入 before-send、after-save 和 revoke 回调。
- 不需要客户端再维护一套服务地址和认证体系。

若生产环境要求不改 OpenIM 上游，可改为独立 sidecar，但需要额外实现鉴权、内部 RPC 和部署。

### 3.3 服务端源码可修改时的最佳边界

既然 OpenIM Server 和 protocol 都可以修改，最终方案不应把 `ex` JSON 当作话题关系的事实来源。

推荐增加独立 `topic` RPC 领域，并把 `topic_id` 加入 `sdkws.MsgData`：

```text
Group RPC
  负责群成员、角色、群属性和群模式

Msg RPC / msgtransfer
  负责消息正文、seq、发送、持久化和实时投递

Topic RPC
  负责话题列表、话题状态、订阅、已读、Pin、搜索和通知路由

Topic DB
  只保存话题聚合、消息关系、用户状态和摘要
```

数据所有权：

- 群成员和角色归 Group。
- 消息正文和附件归 Msg。
- 话题业务状态归 Topic。
- 不复制消息正文，不复制成员体系。

`ex` 只保留 UI 扩展或过渡期兼容，不再承担核心话题关系。

## 4. 服务端改造

### 4.1 数据模型

需要新增以下核心集合或表：

```text
group_collaboration_profiles
  group_id
  mode
  mode_since_seq
  mode_version

topics
  topic_id
  group_id
  root_client_msg_id
  root_seq
  creator_id
  created_at
  last_reply_at
  last_reply_seq
  reply_count
  state
  pinned_at
  pinned_by
  root_preview
  recent_replies
  version

topic_messages
  topic_id
  client_msg_id
  seq
  sender_id
  send_time
  state

topic_user_state
  topic_id
  user_id
  subscribed
  last_read_seq
  updated_at

topic_feed_items
  group_id
  item_type
  item_id
  sort_time
  pinned_at

topic_tasks
  topic_id
  task_id
  created_by
  created_at

topic_events
  group_id
  version
  event_type
  payload
```

消息正文仍由 OpenIM 消息库保存。话题库只保存关系、摘要和话题业务状态，避免重复存储全部媒体消息。

### 4.2 话题与消息关系

协议增加可选字段：

```proto
message MsgData {
  // existing fields 1-23
  string topicID = 24;
}
```

根消息：

```text
clientMsgID = T1
topicID     = T1
```

回复：

```text
clientMsgID = M2
topicID     = T1
```

一个话题只有一条根消息，根消息通过 `topicID == clientMsgID` 识别。

兼容策略：

- 新客户端发送和读取 `topicID`。
- 迁移期服务端可以兼容读取旧格式 `ex.topic.id`。
- 所有新写入的消息必须落 `topicID` 字段。
- 默认兼容策略：旧客户端未携带 `topicID` 时，服务端可将该消息自动作为新话题根消息。
- 如果产品要求严格结构化讨论，也可在灰度期拒绝旧客户端发送，并提示升级。

修改消息协议时需要同步：

- `protocol/sdkws/sdkws.proto`
- protocol 的 Go/Rust 生成代码
- `pkg/apistruct/msg.go`
- `pkg/common/convert/msg.go`
- `pkg/common/storage/model/msg.go`
- `sdkws.MsgData` 所有请求、响应和同步路径
- 本项目 Rust SDK 和 flutter_rust_bridge 生成代码

### 4.3 写入与索引链路

```text
客户端发送群消息
  → Msg RPC before-send 校验成员、群模式、话题状态和权限
  → OpenIM 消息入库
  → msgtransfer 在 Mongo 落库成功后投递 topic-index MQ 事件
  → Topic RPC 幂等创建/更新话题索引
  → 更新最近回复、回复数、活动时间和 Feed
  → 推送话题状态事件
```

撤回：

```text
Msg RPC 撤回成功后投递 topic-index MQ 事件
  → 撤回回复：更新回复状态和预览
  → 撤回根消息：话题进入 revoked，通知客户端刷新
```

话题状态缓存：

- Topic RPC 将 `open/closed/revoked`、群模式和权限版本缓存到 Redis。
- Msg RPC before-send 只访问缓存，不阻塞在 Topic DB 查询上。
- 状态变更通过版本号失效缓存。

必须增加：

- 回调幂等键。
- MQ 消费重试和死信队列。
- 按 seq 的定期对账任务。
- 服务重启后恢复索引。

### 4.4 API

至少需要：

```text
GET    /topic/v1/groups/{groupID}/topics
GET    /topic/v1/topics/{topicID}
GET    /topic/v1/topics/{topicID}/replies
POST   /topic/v1/topics/{topicID}/read
POST   /topic/v1/topics/{topicID}/subscription
DELETE /topic/v1/topics/{topicID}/subscription
POST   /topic/v1/topics/{topicID}/pin
POST   /topic/v1/topics/{topicID}/close
POST   /topic/v1/topics/{topicID}/reopen
POST   /topic/v1/topics/{topicID}/revoke
POST   /topic/v1/topics/{topicID}/tasks
GET    /topic/v1/groups/{groupID}/search
GET    /topic/v1/groups/unread-summary
GET    /topic/v1/groups/{groupID}/sync
POST   /topic/v1/groups/{groupID}/mode
```

列表查询禁止 N+1：

- 一次查询话题。
- 一次联查当前用户状态。
- 一次补充最近回复和作者资料。
- 使用 opaque cursor，不使用 offset。

### 4.5 服务端工作项

1. 话题领域与数据库。
2. 群模式持久化和模式切换。
3. 话题 API 和用户状态 API。
4. 群成员角色鉴权。
5. 消息 before/after/revoke 回调。
6. 订阅、未读和角标汇总。
7. Pin、关闭、重开、撤回状态机。
8. 任务关联。
9. 搜索索引。
10. 实时事件和通知。
11. 回调重试和对账。
12. 单元、契约、并发和真实服务测试。

## 5. Rust SDK 改造

> 本节为实施前的设计清单（路径为规划路径）。实际落地：群模式字段在 `rust/src/domain/model/group.rs`、`rust/src/sdk/group/service.rs`、`rust/src/api/ffi/group.rs`；话题消息通过 `domain/model/message.rs` 的 `topic_id` 贯穿，话题状态由服务端 topic RPC 提供，客户端无独立 `sdk/topic/` 模块。

### 5.1 群模式

需要修改：

- `rust/src/domain/model/group.rs`
- `rust/src/infra/http/group.rs`
- `rust/src/sdk/group/service.rs`
- `rust/src/sdk/client/group.rs`
- `rust/src/api/ffi/group.rs`
- `rust/src/frb_generated.rs`（生成）

具体：

- `GroupInfo` 增加 `ex`、`group_type` 或已解析的 `mode`。
- `server_to_group_info` 保留 `ex` 和 `group_type`。
- `local_to_group_info`、`group_info_to_local` 完整往返。
- 创建群 FFI 接收结构化选项，避免继续增加位置参数。
- 更新群资料 FFI 接收 `ex`。
- 群信息变更事件携带模式。

注意：不要把 `group_type` 当群模式。群模式放在版本化 `ex` 或独立 profile 中。

### 5.2 话题 API

需要新增：

```text
rust/src/domain/model/topic.rs
rust/src/infra/http/topic.rs
rust/src/infra/http/topic_api.rs
rust/src/sdk/topic/service.rs
rust/src/sdk/client/topic.rs
rust/src/api/ffi/topic.rs
```

包含：

- Topic、TopicCard、TopicReplyPage、TopicUserState、TopicTask。
- 列表、详情、回复、订阅、已读、Pin、关闭、重开、撤回。
- 服务端错误和权限错误映射。

### 5.3 消息携带话题元数据

需要解决三个问题：

1. 消息构造器接收 `topicID`。
2. 本地乐观消息保留 `topicID`。
3. 重发和引用不丢失 `topicID`。

修改点：

- `MsgStruct`、`MessageInfo`、`LocalChatLog`、`MessageRepository` 增加 `topic_id`。
- `messageFromMsgStruct` 使用真实的 `topicID` 和 `ex`，不再固定清空。
- Message builder 增加 `topicID` 参数。
- `MessageSendPipeline`、`MessageRepository`、MessageServiceNotifier 增加 topicId。
- 只对话题群消息要求 topic 元数据。

### 5.4 本地缓存

新增迁移：

```text
local_topics
local_topic_messages
local_topic_user_state
local_topic_sync_checkpoint
```

新增 DAO 和 Repository：

- 按群、Tab 和游标查询话题。
- 查询最近两条回复摘要。
- 缓存订阅和已读位置。
- 缓存话题同步版本。
- 本地搜索。

消息处理流程增加：

- 消息入库后解析话题元数据。
- 实时更新当前话题卡片摘要和最近回复。
- 不因本地投影失败阻断普通消息入库。
- 启动或重连时通过 Topic API 对账。

### 5.5 事件

新增话题事件：

- TopicCreated。
- TopicUpdated。
- TopicReplyAdded。
- TopicStateChanged。
- TopicSubscriptionChanged。
- TopicUnreadChanged。
- TopicDeleted。

事件可以复用现有 StreamSink 模式。群级状态必须由服务端版本驱动，不能只依赖消息解析。

### 5.6 FFI 和生成

- 所有话题 API 通过 data/repository 边界暴露。
- 修改 Rust API 后运行 `flutter_rust_bridge_codegen generate`。
- 运行 `scripts/check-codegen.ps1`。
- 不在 `lib/generated` 手改。

## 6. Flutter 改造

> 本节为实施前的设计清单（路径为规划路径）。实际落地：模型在 `lib/domain/models/topic.dart`（含 user state/task/卡片类型），数据层在 `lib/data/mappers/topic_mapper.dart`、`lib/data/repositories/topic_repository.dart`、`lib/data/services/topic_api.dart`；状态与页面在 `lib/ui/topics/`（`view_models/`、`views/`、`providers/`），未单独建 `lib/application/topic/`。

### 6.1 领域模型和 Repository

新增：

```text
lib/domain/models/topic.dart
lib/domain/models/topic_user_state.dart
lib/domain/models/topic_task.dart
lib/data/mappers/topic_mapper.dart
lib/data/repositories/topic_repository.dart
lib/data/services/topic_service.dart
```

`Group` 增加模式字段。

### 6.2 状态层

新增独立的话题状态源：

```text
lib/application/topic/topic_service_notifier.dart
lib/application/topic/topic_service_state.dart
lib/application/topic/stores/topic_list_store.dart
lib/application/topic/stores/topic_detail_store.dart
lib/application/topic/stores/topic_user_state_store.dart
```

原则：

- 话题列表、订阅、未读是独立领域状态。
- 不复用 ChatMessage Store 作为唯一状态源。
- 消息 Service 只负责接收消息，话题 Service 消费消息事件更新卡片。
- 同一话题详情只保留一个状态源。

### 6.3 路由

新增：

```text
/topic-group/:conversationId
/topic/:topicId
/topic-group/:conversationId/search
/topic-group/:conversationId/settings
```

增加一个会话详情路由包装器：

- 读取群模式。
- 对话模式进入现有 ChatDetailScreen。
- 话题模式进入 TopicGroupScreen。
- 模式未加载时显示稳定 loading，不先闪普通聊天页。

### 6.4 页面和组件

新增：

```text
lib/ui/topics/views/topic_group_screen.dart
lib/ui/topics/views/topic_detail_screen.dart
lib/ui/topics/views/topic_composer_screen.dart
lib/ui/topics/views/topic_search_screen.dart
lib/ui/topics/views/topic_manage_screen.dart
lib/ui/topics/widgets/topic_card.dart
lib/ui/topics/widgets/topic_header.dart
lib/ui/topics/widgets/topic_action_bar.dart
lib/ui/topics/widgets/topic_more_menu.dart
lib/ui/topics/widgets/topic_reply_preview.dart
lib/ui/topics/widgets/topic_status_banner.dart
```

复用：

- 头像、群信息头、分享。
- 消息内容渲染和媒体预览。
- @选择器、附件、表情和 Markdown 编辑能力。
- 现有错误提示、骨架屏和设计 token。

### 6.5 现有页面接入

- 建群 ViewModel 将群模式传给 Repository。
- 群信息页增加群模式展示和切换。
- 会话列表按群模式选择点击目标。
- 会话摘要支持“发布话题”“回复话题”。
- 未读角标改用话题服务汇总。
- 通知点击进入话题详情。
- 搜索接入话题搜索结果。

### 6.6 任务

如果已有任务系统，话题只保留 `taskId` 关联；如果没有，需要额外建设任务服务。任务不是话题服务的附属 UI 卡片，必须能独立查询、分配和更新。

## 7. 不建议改动的部分

- 不新增 OpenIM 会话类型。
- 不修改普通单聊和普通群消息流。
- 不复制一套群成员体系。
- 不在 UI 里直接调用 FFI 或 Topic HTTP。
- 不把全部消息内容复制到话题库。
- 不把 Pin、订阅、关闭和未读存进 `Message.ex`。

## 8. 改动规模

按全量真实可用能力、包含服务端、Rust SDK、Flutter UI、任务、搜索、通知和测试估算：

| 领域 | 预计新增/修改文件 | 手写代码量 | 预计人日 |
|---|---:|---:|---:|
| OpenIM 话题服务 | 25–40 | 3500–6000 行 | 20–30 |
| Rust SDK / FFI / 本地缓存 | 15–25 | 1800–3000 行 | 10–16 |
| Flutter 页面和状态 | 30–45 | 4000–7000 行 | 18–28 |
| 测试与真实服务器验证 | 20–35 | 2500–4500 行 | 10–16 |
| 合计 | 90–145 | 11800–20500 行 | 58–90 |

生成代码、迁移和资源不计入手写代码量。

假设：

- 1 名熟悉项目的全栈开发者：约 12–18 周。
- 3 人并行，前端 / Rust / 服务端各 1 人：约 5–8 周。
- 若任务、搜索、通知或权限系统另行建设，工期继续增加。

## 9. 实施顺序

全量功能不裁剪，按依赖顺序落地：

1. 竞品待确认规则和产品评审。
2. 服务端话题数据模型、API、鉴权和回调。
3. 服务端单元、契约和并发测试。
4. Rust 群模式持久化和话题 API。
5. 消息话题元数据、实时事件和本地缓存。
6. Flutter 模型、Repository 和状态层。
7. 话题首页、卡片、详情和发布。
8. 订阅、未读、Pin、关闭、撤回和分享。
9. 任务、搜索、通知和深链。
10. 多设备、离线、大群和服务重启测试。
11. codegen、架构检查、design token 检查和全量回归。

## 10. 主要风险

### 10.1 服务端状态成为第二套消息系统

若话题服务重复存全部消息，必须额外处理编辑、撤回、媒体和权限同步。推荐只存关系、摘要和话题状态。

### 10.2 未读冲突

OpenIM 群会话未读和话题未读不是同一口径。消息列表必须由话题服务汇总，否则角标会翻倍或不一致。

### 10.3 回调丢失

after-save 和 revoke 回调都可能失败，必须有 outbox、重试和 seq 对账。

### 10.4 模式切换

旧普通消息不能自动变话题。必须记录切换点，并保留历史消息入口。

### 10.5 权限越权

Topic API、话题搜索、任务和深链都要校验当前用户仍是群成员；不能只校验登录 Token。

### 10.6 大群性能

话题列表必须使用服务端索引和游标分页。不能为每张话题卡分别查询消息。

## 11. 验证计划

### 11.1 单元和契约

- 群模式序列化、存储和同步。
- Topic API DTO 映射。
- 话题状态机。
- 订阅幂等。
- 阅读游标只增不减。
- 游标分页无重复和遗漏。
- 权限矩阵。

### 11.2 Rust 和数据库

- SQLite 迁移。
- 消息话题投影幂等。
- 回调重复写入不产生重复话题。
- 消息撤回后卡片摘要更新。
- 本地缓存与服务端版本对账。

### 11.3 Flutter

- 普通群 / 话题群路由分流。
- 全部 / 我订阅的。
- 卡片最近回复。
- 订阅、Pin、关闭、撤回菜单。
- 空态、加载、失败和权限态。
- 键盘、附件、媒体和 @。

### 11.4 真实服务

- 两账号、两设备发布和回复。
- 多设备订阅和已读同步。
- 群成员被踢、退群和群解散。
- 服务重启后索引恢复。
- 回调丢失后的对账。
- 非成员深链访问。

## 12. 提交前门禁

- `scripts/check-architecture.ps1`
- `scripts/check-design-tokens.ps1`
- `scripts/check-codegen.ps1`（修改 Rust API 后必须）
- 相关 Flutter 单文件测试
- 相关 Rust 模块测试
- 真实 OpenIM 服务集成测试

## 13. 本轮验证记录

验证日期：2026-11-02（Asia/Shanghai）。

- `flutter analyze lib test`：通过。
- `flutter test test`：542 项通过。
- `cargo test --lib`：434 项通过。
- `cargo test --test topic_tests -- --ignored --test-threads=1`：使用本地源码构建并重新创建的 `openim-server:local` 镜像跑通真实双用户完整链路，包括话题收发、SQLite `topic_id`、聚合、摘要/未读、Pin/Reaction、任务分配与完成、订阅事件、阅读同步、作者编辑、非作者拒绝、非成员深链拒绝、被踢成员权限拒绝、普通群与话题群往返以及解散群。
- OpenIM 改动相关 Go 包（`pkg/topic`、`internal/rpc/topic`、`internal/api`、`cmd`、`pkg/rpcli`、`internal/rpc/msg`、`internal/msgtransfer`）：通过。
- `scripts/check-architecture.ps1`：通过。
- `scripts/check-design-tokens.ps1`：通过。
- `flutter_rust_bridge_codegen generate`：已重新生成并在本轮修复了生成物滞后；`check-codegen.ps1` 在未提交状态会把生成物改动与 HEAD 比较，因此需将生成文件与源码一并提交后才能得到绿色结果。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- `flutter build apk --release`：通过，产物为 `build/app/outputs/flutter-apk/app-release.apk`（123,920,473 bytes，SHA-256 `3472DF1B8EC0D2C168E2024118D19A05B0A10B159508A349354634861F4B28D2`）；`apksigner` 验证通过，但当前 release 仍使用 Android Debug 证书，只适合联调/验收，正式发布前必须替换签名。
- 真机 Mi 10 Pro：最新 release 安装并启动后验证了独立话题群主题色、飞书式群头、白色内容面板、全宽话题卡、作者信息与四等分操作栏；会话摘要、全局通知角标、持久通知中心、全部已读、群设置、搜索高级筛选、通知深链、话题详情任务、Reaction、作者已编辑标记和草稿恢复均正常。
- 服务端停止时，真机通过话题深链仍可读取账号隔离缓存中的详情、任务、Reaction 和回复；服务恢复后重新打开同一深链可继续从服务端加载。
- 真机运行时错误：当前 release 进程日志中未发现 `FATAL EXCEPTION`、`E/flutter`、未处理异常、布局溢出或连接丢失。
- 真机截图：[飞书式话题群首页](../build/topic_feishu_aligned_release_group2.png)、[飞书式更多菜单](../build/topic_group_menu_release.png)、[通知中心](../build/topic_release_notifications3.png)、[群设置](../build/topic_release_settings.png)、[高级筛选](../build/topic_release_filters3.png)、[通知深链详情](../build/topic_release_deeplink.png)、[服务停止时缓存详情](../build/topic_release_offline2.png)、[服务恢复后重新加载](../build/topic_release_reconnected2.png)。
- 最新扩展的持久通知、成员发布/回复权限、Pin/附件/@我组合搜索和死信 API 已在重新创建的服务端镜像上通过真实 E2E。本轮同时修复 Topic RPC 启动命令未加载 `share.yml`、导致内部群成员查询缺少 IM 管理员上下文的问题；修复后新话题和回复通知均能持久化并读取。
