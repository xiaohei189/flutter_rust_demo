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

### [已取证 2026-10-24] OpenIM 是否对「被解散群的普通成员」投递 `GroupDismissedNotification`？

**结论：服务端有能力投递，但当前客户端拿不到——本端解散请求固定带 `deleteMember=true`，服务端在该分支下直接删成员、根本不发这条通知。**
因此普通成员只能靠重连后的群增量同步（`delete=1`）感知，与真机现象一致；「把兜底降级为低频对账」的前提（服务端无条件投递）不成立。

证据（服务端以本地 `open-im-server` 检出（v3.8.1-264-gbd5b7a0b0，部署镜像二进制构建于 2026-07-25）为准）：

- **只在 `deleteMember=false` 时发通知**：`internal/rpc/group/group.go:1443` `DismissGroup` 先 `db.DismissGroup(groupID, req.DeleteMember)`，随后 `if !req.DeleteMember { … notification.GroupDismissedNotification(…) }`（门控 `group.go:1466`，发通知 `group.go:1479`）；`deleteMember=true` 分支直接删掉全部群成员并跳过通知。非 admin 调用必须是群主（`group.go:1450` `not group owner`）。该逻辑在部署镜像构建前的最后一次改动（`7c242b849`，2026-06-04）即已如此，`internal/push/push_handler.go` 亦然。
- **通知是「可靠通知」而非易失推送**：`config/notification.yml` 的 `groupDismissed: { isSendMsg: true, reliabilityLevel: 1 }` 经 `pkg/common/config/parse.go:74-75` 映射为 history + persistent，会话类型 `ReadGroupChatType`（`pkg/notification/msg.go:48,96`）——它会落进群会话消息流，离线成员后续同步可取；本部署 `offlinePush.enable=false`，不涉及厂商离线推送。
- **推送侧会「顺带」删成员**：`internal/push/push_handler.go:313-327` 消费到该通知后先向群成员在线推送，再 `defer … DismissGroup(ctx, groupID, true)`。所以「通知」与「随后群同步 `delete=1`」是同一事件的两条产出，成员被删是通知触发的副作用（也解释了 `DismissGroup(false)` 不删成员、成员却仍会消失）。
- **本端发的是 `deleteMember=true`**：`rust/src/sdk/group/service.rs:355-361`（`DismissGroupReq` 定义见 `rust/src/infra/http/group.rs:122-127`）。服务端因此走 `deleteMember=true` 分支 → 不发通知。

本地真服对照实测（同一台 OpenIM，群主身份调 `/group/dismiss_group`，2026-10-24）：

| 解散参数 | `group.status` | 群成员 | `sg_<groupID>:0` 消息文档 content_type | 成员侧 `sg_*` 会话 |
| --- | --- | --- | --- | --- |
| `deleteMember=false`（群 `531013377` / `3356806382` / `159222815`） | 2 | 2 → 0（push 服务异步删除，实测 ≤2s） | `[1501, 1511]` | 保留 |
| `deleteMember=true`（群 `2836449022`） | 2 | 立即 0（RPC 内删除） | `[1501]` | 保留 |

旁证（真机 2026-10-24 被动解散的 5 个群 `3336319524 / 2508474771 / 1384312415 / 751394274 / 2916163586`）：全部 `group_member=0`、`status=2`、`sg_*` 会话仍在；
实验前全库每个群都有建群通知 1501，而 content_type=1511 的消息数为 **0**（实验后 1511 只来自上表 3 个手工建的群）——与「客户端一直在发 `deleteMember=true`」完全吻合。

**对设计的影响（已采纳）**：客户端已实现 `handle_group_dismissed`（`rust/src/core/message/notification.rs:153,483`），服务端在 `deleteMember=false` 时会投递并持久化 1511。
因此本变更把本端解散调用改为 `deleteMember=false`，恢复「解散 → 1511 → 成员端即时清理」的实时链路；成员记录由服务端 push 服务异步清理（实测 ≤2s），群同步仍会给出 `delete=1`。
「同步对账」继续保留，用于覆盖推送丢失、离线补拉失败以及历史遗留的孤儿会话。

**真机复现（变更前）**：被动解散后 logcat 中没有任何 1511/notification 记录，只有下一次重连的 `增量同步群组完成 ... delete=1`，随后会话列表仍保留该群，直到应用重启/再次同步。该片段作为任务 1.2 的证据。

未覆盖项：在线成员在解散瞬间收到 WS 推送未做端到端观测（由任务 1.2 的真机 logcat 佐证）；离线成员补拉 1511 依赖客户端增量消息同步，属客户端行为，本任务未验证。
