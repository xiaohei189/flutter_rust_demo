# Tasks

## 1. 取证与契约确认

- [x] 1.1 在 OpenIM 服务端确认「群被他人解散」是否投递 `GroupDismissedNotification`（查 openim-rpc-group / msggateway 源码或二进制字符串），把结论写入 `design.md - Open Questions`；验证方式：给出源码位置或日志证据
- [x] 1.2 复现一次被动解散并保留日志（无推送、仅重连增量同步 `delete=1`），验证方式：真机 logcat 片段贴进变更说明

## 2. 事件路径收敛

- [x] 2.1 `handle_group_dismissed` 与 `handle_group_member_deleted`（自己是被移除者）统一走 `ConversationService::delete_conversation`，验证方式：单测断言发出 `ConversationEvent::Deleted`
- [x] 2.2 移除 `GroupService` 增量删除分支中的直接会话删除，避免双删与无事件删除，验证方式：`cargo test --lib group` 通过且日志只出现一次删除
- [x] 2.3 新增清理日志字段 `cleanup_source` / `group_id` / `conversation_id`，验证方式：真机日志可按来源过滤
- [x] 2.4 主动解散改用 `deleteMember=false`，恢复服务端 1511 通知链路（成员由 push 服务异步清理），验证方式：单测断言请求体 `deleteMember:false`，真机成员端收到 1511

## 3. 对账兜底

- [x] 3.1 实现 `ConversationService::reconcile_group_conversations(valid_group_ids, source)`，删除群表中不存在的 `sg_*` 会话并逐条广播 `Deleted`，验证方式：单测覆盖「群存在/不存在/重复执行」三种情况
- [x] 3.2 在群增量同步成功后触发对账（来源 `sync`），验证方式：真机重连后历史孤儿会话被清理
- [x] 3.3 首次登录在「群同步 + 会话同步」之后触发一次对账，验证方式：清空本地会话后登录，孤儿会话不再出现

## 4. UI 与会话列表

- [ ] 4.1 确认 Dart `conversationDeleted` 事件按 id 移除列表项（现有实现），补 widget/单测，验证方式：`flutter test` 对应用例通过
- [ ] 4.2 被动清理后无残留死群且无需重启，验证方式：真机截图 + logcat `cleanup_source=sync`

## 5. 集中验证

- [ ] 5.1 在集成工作区运行 `cargo test --lib group`、`cargo clippy --all-targets`，验证方式：全绿
- [ ] 5.2 运行 `flutter analyze lib test` 与相关 `flutter test` 用例，验证方式：全绿
- [ ] 5.3 真机双端回归：A 建群→转让→B 解散，A 端在**不重启**情况下会话消失，验证方式：截图 + 日志
- [ ] 5.4 回归主动路径：退群、主动解散仍正常且各只清理一次，验证方式：真机截图 + 日志

## Workflow follow-up

- 变更实现并验证通过后执行 `openspec archive fix-remote-group-dismiss`。
