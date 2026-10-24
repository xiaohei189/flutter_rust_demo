# Design

## Context

见 `proposal.md - Why`。当前实现的约束：

- 群资料、成员缓存与会话分别由 `GroupService`、`ConversationService` 维护，二者在不同路径上被删除：本端操作走 SDK 方法，被动变化走 `NotificationHandler`，重连兜底走 `sync_groups_incremental`。
- `ConversationService::delete_conversation` 已会发出 `ConversationEvent::Deleted`，Dart 侧订阅后可从内存列表移除；但 `GroupService` 直接操作 `conversation_repo` 时不会发事件。
- OpenIM 服务端在群解散后仍保留成员侧 `conversation` 记录，因此仅依赖会话增量同步不会产生删除。

## Goals / Non-Goals

**Goals:**

- 所有「群不再可用」的路径都收敛到同一套本地清理语义（群行、成员缓存、会话、事件）。
- 被动路径在推送缺失时仍有确定性兜底，并在首次登录时清掉历史孤儿会话。
- 清理可观测、可幂等重复执行。

**Non-Goals:**

- 不修改 OpenIM 服务端行为，也不新增群协议字段。
- 不改变会话列表的排序、置顶、未读等既有语义。
- 不处理「新群成员端无会话」问题（另行提案）。

## Decisions

### 决策 1：以「群集合对账」作为兜底入口

新增 `ConversationService::reconcile_group_conversations(valid_group_ids, source)`：列出本地 `sg_*` 会话，删除群表中不存在的会话并逐条发出 `ConversationEvent::Deleted`。

- 为什么：服务端不会为解散群下发会话删除，且推送不可靠；对账不依赖通知，能同时清掉历史遗留死群。
- 触发时机：登录/重连完成「群同步 + 会话同步」之后，以及每次 `sync_groups_incremental` 成功后。
- 备选方案：仅依赖推送（已证明不可靠）；或在 `listConversations` 时过滤（治标，脏数据仍在库里，且会掩盖同步未完成的情况）。

### 决策 2：事件路径即时清理，与对账共用同一实现

`handle_group_dismissed` 与 `handle_group_member_deleted`（自己是被移除者）调用 `ConversationService::delete_conversation`，它负责删库 + 广播 `Deleted`；`GroupService` 的增量删除分支不再直接删会话。

- 为什么：避免两处删除逻辑漂移，也避免「删了库但 UI 不知道」。
- 备选方案：给 `GroupService` 注入会话监听器（构造签名扩散到 builder 与多处测试，收益不抵成本）。

### 决策 3：清理来源进入结构化日志

日志统一带上 `cleanup_source=push|sync|local_action`、`group_id`、`conversation_id`，用于确认漏推属于服务端还是客户端。

### 决策 4：幂等语义

删除不存在的行视为成功；`Deleted` 事件允许重复广播，Dart 侧按 id 移除，天然幂等。

## Risks / Trade-offs

- [对账误删尚未同步完成的群] → 只在群同步成功后执行对账，并要求以「群表当前集合」为准，而不是以本次增量结果为准。
- [服务端全量会话同步重新灌入孤儿会话] → 对账安排在会话同步之后；应用启动/重连流程需保证顺序。
- [推送与对账重复清理] → 幂等实现，日志按来源区分，便于统计漏推率。
- [跨端一致性延迟] → 兜底最迟在下一次重连生效；如需更实时，可再加定时对账，但会增加请求量。

## Migration Plan

1. 发布后首次登录即执行一次对账，清理历史孤儿会话（如当前真机上的 `sg_2508474771`、`sg_3336319524`）。
2. 无数据迁移、无 schema 变更；回滚只需移除对账调用。

## Open Questions

- OpenIM 是否对「被解散群的普通成员」投递 `GroupDismissedNotification`？若有条件投递，可后续把兜底降级为低频对账。
