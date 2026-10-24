# Proposal

## Why

群主之外的人解散群、或自己被移出群时，客户端没有稳定的即时触发链路：真机日志显示「他人解散群」没有收到可用推送，只有下次登录/重连的增量群同步返回 `delete=1`，期间会话列表残留无法进入的死群。本地清理与 `ConversationEvent::Deleted` 已补齐，但触发时机仍依赖重连，群状态与列表可能长时间不一致。

## What Changes

- 明确群生命周期事件（被解散、被移出、主动退出/解散）在客户端的一致处理契约：群资料、成员缓存与 `sg_<groupID>` 会话在同一流程内清理，并广播会话删除事件。
- 为「被动移除」（非本端发起）补可靠触发链路：主路径为服务端群通知；服务端未投递时，由同步兜底（重连、列表刷新时对齐群集合与会话集合）完成清理。
- 增加可观测性：记录清理来源（`push` / `sync` / `local-action`）与结果，便于定位漏推。
- 补充回归驱动与自动化测试，覆盖主动与被动两条路径。
- 不改变主动退出/解散的既有 UI 行为与文案。

## Capabilities

### New Capabilities

- `group/lifecycle-sync`: 群生命周期变化（解散/被移出/退出）后的本地状态一致性、事件广播与同步兜底契约。

### Modified Capabilities

（无。当前仓库尚无既有 OpenSpec 能力，`openspec list --specs` 为空。）

## Impact

- Rust：`src/sdk/group/service.rs`、`src/core/message/notification.rs`、`src/core/conversation/service.rs`、`src/infra/http/group*.rs`
- Dart：`lib/application/chat/message_service_conversation_controller.dart`、`lib/ui/groups/*`
- 测试：Rust 单元测试、`test_driver/*` 真机回归脚本
- 服务端：OpenIM 群解散通知的投递目标与条件（需以日志与源码确认；不改服务端则以同步兜底保证一致性）
