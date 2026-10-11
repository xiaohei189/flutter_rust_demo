# 会话列表 / 消息详情 功能补齐计划

> 状态：P0 全部完成并通过真机验证（2026-10-09，Android 模拟器 + flutter driver）
> 范围：Flutter UI 接线、已有 SDK 能力接通、必要的本地持久化
> 不涉及：Rust 协议层新增接口（P2 项单独立项）
> 盘点基线：2026-10-08 对 `lib/ui/chat` 全量核对（含 `暂未开放` 占位、假数据占位、传了回调但未渲染的死参数）

## 1. 背景

会话列表与消息详情的主链路已经可用：收发消息、历史分页、已读回执、撤回/删除/复制/重发、多选与逐条/合并转发、图片/视频/语音/文件/名片/位置/合并转发渲染、会话内本地搜索、草稿、置顶/免打扰/归档/标记。

剩余缺口集中在三类：

1. **UI 没接线**：能力已存在，入口缺失或点了没反应。
2. **半实现**：能点，但不落库、不闭环（退出即丢、没有后续页面）。
3. **整块缺失**：需要新协议或第三方服务。

本计划按这三类拆成 P0 / P1 / P2 三批，P0 只做零协议改动的接线与修复。

## 2. 能力分类（决定实现路径）

| 类别 | 说明 | 涉及项 |
|---|---|---|
| A. 零协议改动 | SDK/服务端能力已具备，只差 UI 接线 | 取消归档、全部已读、长按菜单缺项、分组管理、未读分割线 |
| B. SDK 已有，差 Repository/UI 接通 | `editMessage`、`setMessageLocalEx` 已 FFI 暴露到 Dart，`lib/data` 未使用 | 消息编辑、表情回复与置顶消息本地持久化、消息收藏 |
| C. 需新增协议或第三方 | 先定方案再动手 | 音视频通话、翻译、群已读成员详情、置顶消息跨端同步、云文档/任务/日程/定时消息/群机器人 |

关键事实：

- `editMessage`：`lib/generated/rust/ffi/message_advanced.dart`，Rust 实现 `rust/src/core/message/send/sender.rs`（当前为「构造新消息 + MQ 广播」，非原子编辑）。
- `setMessageLocalEx`：同上 FFI 文件；`ChatMessage` 领域模型目前**没有** `localEx` 字段，`lib/data/mappers/message_mapper.dart` 直接丢成空串，P1 需先补字段。
- `markAllConversationsAsRead`：`lib/application/chat/message_service_notifier.dart` 已实现，无任何 UI 调用方。

## 3. 缺口清单（盘点结论）

### 3.1 会话列表

| 功能 | 现状 | 位置 |
|---|---|---|
| 长按菜单缺项 | 归档/取消归档、移动分组、清空、删除的回调已传入但菜单未渲染 | `lib/ui/chat/widgets/list/chat_list_item_menu.dart` |
| 会话「标签」 | 已收敛到自定义分组（P0-4）：菜单项合并进「移动到分组」，设置页「标签」跳分组管理页 | 同上、`lib/ui/chat/views/chat_settings_screen.dart` |
| 列表「外部/智能体/机器人」胶囊 | 已删除假数据（P0-4），改为展示真实分组名 | `lib/ui/chat/widgets/list/chat_list_item_content.dart` |
| 分组面板筛选图标 | 已补齐（P0-3）：打开分组管理页 | `lib/ui/chat/widgets/list/group_filter_panel.dart` |
| 自定义分组 | 已补齐（P0-3）：支持重命名与拖动排序，仍只存本地 | `lib/ui/chat/providers/conversation_folder_provider.dart` |
| 会话搜索 | 全局搜索只有「消息/联系人/群组」，无会话维度与搜索历史 | `lib/ui/shared/views/search_screen.dart` |
| 全部已读 | 已补齐（P0-2）：工作台应用宫格入口 + 二次确认 | `lib/ui/workbench/views/workbench_screen.dart` |
| 设置页占位项 | 分享、添加标签页、群机器人、@所有人消息不提示、标签、添加到标记、单聊「+ 添加成员」、群二维码 | `lib/ui/chat/views/chat_settings_screen.dart` |

### 3.2 消息详情

| 功能 | 现状 | 位置 |
|---|---|---|
| 工具面板 9 项占位 | 创建话题、标记、Pin、复制消息链接、翻译、飞书内搜索、网页搜索、添加任务、导出到文档 | `lib/ui/chat/widgets/menu/message_tool_panel.dart` |
| 表情回复 / 置顶消息 | 只存在页面内存，退出即丢，不落库、不发给对方 | `lib/ui/chat/views/chat_detail_screen.dart` |
| 置顶消息栏 | 无顶部置顶消息栏与列表 | 同上 |
| 位置消息 | 只有经纬度弹窗，无地图与导航 | `lib/ui/chat/widgets/menu/chat_dialogs.dart` |
| 群已读 | 只有「已读 n/m」文本，无已读/未读成员详情 | `lib/ui/chat/widgets/bubble/message_bubble.dart` |
| 语音播放 | 无播放中状态、进度与停止入口 | `lib/ui/chat/widgets/bubble/parts/media_message_content.dart` |
| 音视频通话 | 全项目无通话代码，顶栏仅搜索/设置 | `lib/ui/chat/widgets/shared/chat_detail_app_bar.dart` |
| @所有人 | 群成员选择器无「所有人」选项 | `lib/ui/chat/widgets/composer/group_member_picker.dart` |
| 未读分割线 / 回到底部 | 无未读分割线、无「N 条新消息」悬浮按钮 | `lib/ui/chat/widgets/list/message_list.dart` |
| 附件面板占位 | 云文档、日程、定时消息、任务、开启边写边译、更多 | `lib/ui/chat/widgets/composer/chat_input.dart` |

## 4. 工作项清单

### 4.1 P0：接线与修复（零协议改动）

- [x] P0-1 补齐会话列表长按菜单：归档/取消归档、移动到分组、清空聊天记录、删除。
  - 菜单项按可用回调动态生成，项数变多后卡片受限高度并可内部滚动，位置校正加 `maxTop` 收敛避免越界。
  - 清空与删除补二次确认；「标签」占位改为明确提示，不再点了没反应。
  - `ChatListItem` 补传 `onMoveToFolder`（此前该回调在菜单侧完全断链）。
  - 测试：`test/ui/chat/chat_list_item_menu_test.dart` 新增入口展示、删除二次确认、取消归档三条用例。
- [x] P0-2 「全部已读」入口：工作台应用宫格新增入口，二次确认后调用 `markAllConversationsAsRead` 并刷新会话列表；`ChatListDialogs.confirmMarkAllRead` 承载交互。
  - 说明：只推进服务端已读，用户手动「标为未读」的本地标记不会被清掉。
- [x] P0-3 分组管理页：新增 `ConversationFolderManageScreen`，支持新建 / 重命名 / 拖动排序 / 删除；Notifier 补 `renameFolder`（重名、空名、不存在均拒绝）与 `reorderFolders`（集合不一致时忽略，避免误删分组）。
  - 入口：分组筛选面板右上角 tune 图标（此前是空实现）。
  - 返回列表时若当前筛选的分组已被删除/改名，自动退回「消息」。
  - 测试：`test/ui/chat/conversation_folder_manage_test.dart`（重命名保序、守卫、排序、空态与列表渲染）。
  - 设备验证（Android 模拟器，热重载 + flutter driver）：工作台入口、进入分组管理、新建 → 重启后仍在、重命名、删除确认均通过。
  - 顺带修复的设备问题：
    1. `ConversationFolderStore.save` 原来会过滤掉空分组，导致「新建的空分组重启后消失」；改为整表落盘，并补回归测试。
    2. 分组名输入弹窗原来手动持有 `TextEditingController` 并在弹窗返回时立刻 dispose，真机触发 `framework.dart` 的 `_dependents.isEmpty` 断言崩溃；改为 `TextFormField` 自带控制器。
    3. 分组面板「新建分组」ListTile 因外层有色 Container 触发 `ListTile background color or ink splashes may be invisible` 断言；补 `Material` 承载。
    4. 补「分组筛选」「分组管理」tooltip（可访问性 + 自动化定位）。
- [x] P0-4 标签收敛到分组（方案 A，2026-10-09 定）：
  - 删除按会话 ID 哈希的假胶囊，改为 `conversationFolderLabelProvider`（conversationId → 分组名）驱动真实分组胶囊。
  - 长按菜单「标签」与「移动到分组」合并，只保留后者；设置页「标签」跳分组管理页；删除重复且无效的「添加到标记」开关。
- [x] P0-5 未读分割线 + 「N 条新消息」回到底部按钮（纯前端计算）：
  - 进入会话时快照首条未读消息作为边界，之后已读回执把 isRead 翻成 true 也不消失；边界消息被删除时分割线一并失效。
  - 离开底部（reverse 列表 offset > 240）显示回到底部胶囊，带边界之后的条数；多选模式下不展示分割线。
  - **兜底**：OpenIM 的会话未读数与消息 `isRead` 可能不一致（跨端已读、历史数据）。真机排查发现演示库里会话记 1 条未读、其消息 `is_read` 却全是 1，于是补了「消息全已读但会话未读数 >0 时按未读数回数定位」的分支，进入会话时快照 `unreadCount` 传入列表。
  - 测试：`test/ui/chat/message_list_unread_divider_test.dart`（有未读 / 全已读 / 自发未读 / 快照语义 / 未读数兜底 / 回到底部胶囊）。
  - 真机验证：「同学聚会」出现「以下为新消息」且定位在首条未读上方；「xiaoming」上翻后右下出现回到底部胶囊，点击回到底部。

## 4.4 验证环境备忘

- Android 模拟器访问宿主机服务需要 `scripts/adb_reverse.ps1`（10001/10002/10008/10005），重装或 adb 重启后映射会丢失，表现为登录报 `Connection refused 127.0.0.1:10008`。
- 演示账号：手机号 `17764008284`（Windows 端 `shared_preferences.json` 里有记录），验证码固定 `666666`。
- 需要制造真实未读时用 `rust/scripts/seed-demo.ps1`（等价 `cargo test --test seed_demo -- --ignored`，目标手机号取 `OPENIM_DEMO_TARGET_PHONE`）。

### 4.2 P1：本地闭环（接通已有 SDK）

- [x] P1-1 表情回复与置顶消息持久化 + 顶部置顶消息栏（2026-10-10）。
  - **实现路径调整**：原计划走 SDK 的 message `local_ex`，实测走不通——`MessageInfo`（历史消息返回类型）没有 `localEx` 字段，而 `flutter_rust_bridge.yaml` 的 `rust_input: crate::ffi` 是旧模块路径（现为 `crate::api::ffi`），`flutter_rust_bridge_codegen generate` 会产出空壳绑定（已验证后回滚）。补 `local_ex` 需要先修 yaml 并全量重生成绑定，属于独立改造，不宜混在本次功能里。
  - 改为本地存储方案：新增 `MessageExtras`（领域模型）+ `MessageExtrasStore`（SharedPreferences，key = `conversationId|clientMsgId`）+ `messageExtrasProvider`，与自定义分组同一套机制。
  - 页面不再持有 `_messageReactions` / `_pinnedMessageIds` 内存态：表情与置顶直接读写本地扩展，退出会话、热重启后仍在。
  - 新增 `PinnedMessageBar`：会话顶部展示最近一条置顶消息，点击定位到该消息，右侧 ✕ 取消置顶；置顶消息不在当前分页范围时自动隐藏。
  - 测试：`test/ui/chat/message_extras_test.dart`（JSON 往返 / 落盘重启 / 置顶排序 / 脏数据）、`test/ui/chat/chat_message_actions_test.dart`（表情加/减/并存）。
  - 真机验证：会话内长按 → 置顶消息 → 顶栏出现置顶条；表情回复出现「👍 我」胶囊；热重启后两者都还在；点 ✕ 取消置顶后顶栏消失、表情保留。
- [ ] P1-2 消息编辑：**阻塞在 SDK**。`rust/src/core/message/send/sender.rs::edit_message` 是「用新内容构造一条新消息再 send_msg」，既没带原消息的 clientMsgId，也没设置任何修改标记（注释说会发 `MsgDataToModifyByMQ`，代码里没有）。直接接 UI 会变成「多发一条消息」而不是编辑。要么先补 SDK 的编辑协议（改发送侧携带原 msgID + 服务端修改通知），要么砍掉这条需求。
- [x] P1-3 消息标记（本地收藏，2026-10-10）：复用 P1-1 的本地扩展链路。
  - `MessageExtras` 增加 `flagged`；Notifier 增加 `toggleFlagged` / `flaggedMessageIds(conversationId)`。
  - 工具面板「标记」不再提示暂未开放：按状态显示「标记 / 取消标记」并写入本地扩展，操作后有「已标记 / 已取消标记」提示。
  - 气泡内展示「🏳 已标记」胶囊，退出会话/重启后仍在。
  - 测试：`test/ui/chat/message_extras_test.dart` 增加标记开关与按会话过滤用例。
  - 待补：独立的「标记消息」列表页（现在只能在会话里逐条看到标记态）。
- [ ] P1-4 群已读详情页：气泡已读计数可点开看成员名单；**前置**确认服务端是否提供 reader list 接口，拿不到则只做本地已读用户合并。
- [ ] P1-5 语音播放态：播放中动画 + 进度 + 停止。

### 4.3 P2：需新方案（单独立项）

- [ ] P2-0 修复 FFI codegen 配置（2026-10-10 排查，2026-10-11 补提交记录考古）：
  - **成因**：Rust 五层目录迁移（`10d81a7` 建骨架 → `05e8746` domain → `3346f15` infra → `424f18b` core → `0e7923d` sdk/api 收尾，2026-08-17～08-21）把 `rust/src/ffi/` 搬到 `rust/src/api/ffi/`，但**没有同步 `flutter_rust_bridge.yaml`**（该文件最后一次改动是 08-17 的 `9e23c53`），于是 `rust_input: crate::ffi` 指向了不存在的模块。
  - **当年怎么蒙混过关**：`0e7923d` 的 diff 显示 `rust/src/frb_generated.rs` 被**手工做路径替换**（`use crate::ffi::client::*` → `use crate::api::ffi::client::*`），Dart 侧生成树则停更在迁移前的 `7b99712`（08-19），此后从未重新生成 —— 「生成代码禁止手改」的约定在那次迁移里被打破且无人发现。
  - **现在的后果**：① 跑 codegen 只能产出 90 行空壳（原 13,618 行），Rust 侧新增字段进不了 Dart；② 桥接已出现漂移——Rust FFI 183 个函数 vs Dart 182 个，缺的正是 08-26 才加的 `logcatMakeWriter`（未被 Dart 引用，暂未暴露 bug）。
  - **修法**：改动 `rust_input` 后产物会按 Rust 模块树镜像成 `api/core/domain/infra/sdk` 五套目录，旧的 `ffi/ model/ event/ constant/` 变成未引用副本。两条路：A. 给 crate 加回顶层 `pub mod ffi`（`pub use crate::api::ffi::*`）保住扁平布局，改 31 处手写 import 的成本为 0；B. 接受镜像布局并迁移 31 个文件、27 个 `generated/rust/...` 路径前缀，重跑 `build_runner`。
  - **配套门禁**（建议加进 `AGENTS.md` 提交前清单）：跑一次 codegen 后 `git diff --exit-code -- lib/generated rust/src/frb_generated.rs`，不一致即失败，避免再次手改生成文件或忘记重生成。
- [ ] P2-1 @所有人：Rust 已有 `get_at_all_tag`，发送侧补 `atAllTag` 支持，成本小，可提前到 P1 尾。
- [ ] P2-2 音视频通话：LiveKit 接入（权限、来电弹窗、通话页），独立模块。
- [ ] P2-3 翻译 / 网页搜索 / 飞书内搜索：依赖第三方服务与「选中文本」上下文能力，先出方案。
- [ ] P2-4 云文档、任务、日程、定时消息、边写边译、群机器人、举报：均依赖外部系统，OpenIM 无对应协议；建议**从 UI 摘除**或保留占位并明确标注未排期。
- [ ] P2-5 置顶消息跨端同步：确认服务端是否支持消息级 Pin；不支持则用自定义消息（`content_type` 110）广播，与 P1-1 解耦。

## 5. 验收与验证方式

按仓库《迭代节奏》执行，避免全量重建与无谓测试：

- UI/样式/文案：Flutter MCP 热重载 + `get_widget_tree` + `get_offset` + 截图；必要时补组件测试。
- 逻辑改动（状态机/reducer/mapper/排序）：只跑相关单文件，如 `flutter test test/ui/chat/<file>.dart`。
- Rust/SDK 改动：`cargo test --lib <模块>`，必要时 `rust/scripts/test-fast.ps1`。
- 提交前：`scripts/check-architecture.ps1` + `scripts/check-design-tokens.ps1` 必须通过。

## 6. 风险与待确认

1. 群已读成员详情依赖服务端接口，当前 Rust HTTP 层没有 reader list 封装，需先确认。
2. 消息级 Pin 是否有服务端支持待确认；无则走自定义消息广播。
3. `editMessage` 当前实现是「发新消息 + MQ 广播」，不是原子编辑，需要确认对端展示与撤回交互是否可接受。
4. 会话标签与分组存在语义重叠，需先确定「标签 = 分组」还是「标签另建体系」，否则会出现两套相似的本地数据。
