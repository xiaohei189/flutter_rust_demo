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
| 长按菜单缺项 | 已补齐（P0-1）：置顶/取消置顶、归档/取消归档、移动分组、清空、删除均渲染；清空与删除带二次确认 | `lib/ui/chat/widgets/list/chat_list_item_menu.dart` |
| 会话「标签」 | 已收敛到自定义分组（P0-4）：菜单项合并进「移动到分组」，设置页「标签」跳分组管理页 | 同上、`lib/ui/chat/views/chat_settings_screen.dart` |
| 列表「外部/智能体/机器人」胶囊 | 已删除假数据（P0-4），改为展示真实分组名 | `lib/ui/chat/widgets/list/chat_list_item_content.dart` |
| 分组面板筛选图标 | 已补齐（P0-3）：打开分组管理页 | `lib/ui/chat/widgets/list/group_filter_panel.dart` |
| 自定义分组 | 已补齐（P0-3）：支持重命名与拖动排序，仍只存本地 | `lib/ui/chat/providers/conversation_folder_provider.dart` |
| 会话搜索 | 已补齐（2026-10-25）：新增「会话」分类（按会话名/群 ID/用户 ID 匹配本地会话，展示最近消息预览）与「最近搜索」（去重、最多 10 条、SharedPreferences 持久化、可清空） | `lib/ui/shared/views/search_screen.dart`、`lib/ui/shared/view_models/search_view_model.dart` |
| 全部已读 | 已补齐（P0-2）：工作台应用宫格入口 + 二次确认 | `lib/ui/workbench/views/workbench_screen.dart` |
| 设置页占位项 | 分享、举报、翻译助手、添加标签页、群机器人、@所有人消息不提示、添加到标记、单聊「+ 添加成员」、任务/Pin/群成员日历/云文档等仍为占位，点按统一提示「功能开发中，敬请期待」；群二维码已接通（聊天设置页与群信息页都可查看） | `lib/ui/chat/views/chat_settings_screen.dart` |

### 3.2 消息详情

| 功能 | 现状 | 位置 |
|---|---|---|
| 工具面板占位 | 复制消息链接已接通（2026-10-26：写剪贴板 + 深链定位）；标记/取消标记已本地持久化；与「置顶消息」语义重复的「Pin」占位已删除（保留已实现的置顶）；其余创建话题、翻译、飞书内搜索、网页搜索、添加任务、导出到文档仍为占位，点按统一提示「功能开发中，敬请期待」 | `lib/ui/chat/widgets/menu/message_tool_panel.dart` |
| 表情回复 / 置顶消息 | 表情回复与置顶都已本地持久化（`MessageExtrasStore`）：表情按 emoji 分组渲染、置顶可在消息操作里开关，重启后仍在；但都**不发给对端**（跨端不可见），置顶也没有「全部置顶消息」列表页 | `lib/ui/chat/views/chat_detail_screen.dart`、`lib/data/services/message_extras_store.dart` |
| 置顶消息栏 | 已实现（`PinnedMessageBar`）：顶部展示最近一条置顶、点击定位、右侧取消置顶；仅本地状态，无跨端同步 | `lib/ui/chat/widgets/list/pinned_message_bar.dart` |
| 位置消息 | 只有经纬度弹窗，无地图与导航 | `lib/ui/chat/widgets/menu/chat_dialogs.dart` |
| 群已读 | 只有「已读 n/m」文本，无已读/未读成员详情 | `lib/ui/chat/widgets/bubble/message_bubble.dart` |
| 语音播放 | 已实现：播放中显示停止图标与进度条，带播放状态判定 | `lib/ui/chat/widgets/bubble/parts/media_message_content.dart` |
| 音视频通话 | 全项目无通话代码，顶栏仅搜索/设置 | `lib/ui/chat/widgets/shared/chat_detail_app_bar.dart` |
| @所有人 | 已实现（P2-1，2026-10-19）：选择器置顶「所有人」，发送为 contentType=106 且带 `AtAllTag` | `lib/ui/chat/widgets/composer/group_member_picker.dart` |
| 未读分割线 / 回到底部 | 已实现（P0-5，2026-10-10）：进入会话快照未读边界，「以下为新消息」分割线 + 「N 条新消息」回到底部胶囊 | `lib/ui/chat/widgets/list/message_list.dart` |
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
- [x] P1-5 语音播放态（2026-10-11）：
  - `AudioPlayerService` 增加 `AudioPlaybackState`（ValueNotifier）：当前音源 / 播放中 / 位置 / 时长 / 进度；播放器实例改为**首次播放时才创建**（`AudioPlayer()` 构造即初始化平台通道，测试与预览环境会抛 MissingPluginException）。
  - 语音气泡订阅播放状态：播放中显示停止图标 + 进度条（进度条常驻，避免高度突变引起列表位移）；点同一条即停止（沿用服务原有 toggle 语义）。
  - 其它语音在播放时本条保持播放图标；离开会话时停掉播放（dispose 里用 initState 缓存的服务实例，避免 `ref` 在销毁后使用）。
  - 测试：`test/ui/chat/audio_message_test.dart`（状态语义 + 三种气泡表现）。
  - 真机：因并发编辑导致 App 处于中间态，未完成播放中的真机确认（见下）。
- [x] P1-3 尾巴：会话内「标记消息」列表（2026-10-11）：
  - 会话详情顶栏新增「标记消息」入口（bookmark 图标），弹出 `MarkedMessagesSheet`：列出本会话被本地标记的消息（头像/预览/发送人/时间），右侧「取消标记」，点击定位到原消息。
  - 更早历史里的标记消息会提示「还有 N 条更早的标记消息」并可逐页「加载更多」。
  - 定位失败（消息不在当前视图）时给明确提示，不再静默失败：`MessageListState.scrollToMessage` 改为返回 bool。
  - 测试：`test/ui/chat/marked_messages_sheet_test.dart`（列表/取消标记/空态）。
  - 真机验证：顶栏入口 → 弹层显示「标记消息 1 条」+ 正确内容与时间。
- [x] P1-6 复制消息链接（2026-10-26）：工具面板「复制消息链接」不再提示暂未开放，改为把消息深链写入剪贴板并提示「消息链接已复制」。
  - 深链格式：`flutterrustdemo:///chat/<conversationId>?message=<clientMsgId>`（空 host + 路径，直接复用已有的 `/chat/:id` 路由，见 `lib/ui/chat/utils/message_link.dart`）。
  - 链路：`lib/router/chat_routes.dart` 读 `?message=` → `ChatDetailScreen.initialMessageId` → 消息加载后延迟 120ms 调用 `_locateMessageById`（与「@我」定位同一套语义）；消息不在当前视图内时提示「该消息不在当前视图内，向上滚动可继续查找」。
  - Android 侧 `android/app/src/main/AndroidManifest.xml` 给 MainActivity 补 `flutterrustdemo` 的 `VIEW`/`BROWSABLE` intent-filter；iOS 未配置（当前只维护 Android 真机链路）。
  - 顺带收敛：工具面板其余占位统一为 1.6s「「xxx」功能开发中，敬请期待」；语音/表情/附件面板高度常量收敛到 `lib/ui/chat/widgets/composer/composer_panel_metrics.dart`。
  - 顺带收敛：删除工具面板里与「置顶消息」语义重复的「Pin」占位（`test/ui/chat/message_tool_panel_test.dart` 补断言）；会话设置页的「Pin」入口仍为占位，语义是「本会话置顶消息列表」，列入后续。
  - 测试：`test/ui/chat/message_link_test.dart`（生成/解析/非法链接），`test/ui/chat/message_tool_panel_test.dart` 补剪贴板断言。
  - 待办（真机验证）：设备被其他场景占用，未执行；恢复后跑
    `adb shell am start -a android.intent.action.VIEW -d "flutterrustdemo:///chat/<conversationId>?message=<clientMsgId>"`，
    预期直接进入该群聊并定位到消息。

### 4.3 P2：需新方案（单独立项）

- [x] P2-0 修复 FFI codegen 配置（2026-10-11 完成，方案 B）：
  - **成因**：Rust 五层目录迁移（`10d81a7` 建骨架 → `05e8746` domain → `3346f15` infra → `424f18b` core → `0e7923d` sdk/api 收尾，2026-08-17～08-21）把 `rust/src/ffi/` 搬到 `rust/src/api/ffi/`，但**没有同步 `flutter_rust_bridge.yaml`**（该文件最后一次改动是 08-17 的 `9e23c53`），于是 `rust_input: crate::ffi` 指向了不存在的模块。
  - **当年怎么蒙混过关**：`0e7923d` 的 diff 显示 `rust/src/frb_generated.rs` 被**手工做路径替换**（`use crate::ffi::client::*` → `use crate::api::ffi::client::*`），Dart 侧生成树则停更在迁移前的 `7b99712`（08-19），此后从未重新生成 —— 「生成代码禁止手改」的约定在那次迁移里被打破且无人发现。
  - **现在的后果**：① 跑 codegen 只能产出 90 行空壳（原 13,618 行），Rust 侧新增字段进不了 Dart；② 桥接已出现漂移——Rust FFI 183 个函数 vs Dart 182 个，缺的正是 08-26 才加的 `logcatMakeWriter`（未被 Dart 引用，暂未暴露 bug）。
  - **修法**：改动 `rust_input` 后产物会按 Rust 模块树镜像成 `api/core/domain/infra/sdk` 五套目录，旧的 `ffi/ model/ event/ constant/` 变成未引用副本。两条路：A. 给 crate 加回顶层 `pub mod ffi`（`pub use crate::api::ffi::*`）保住扁平布局，改 31 处手写 import 的成本为 0；B. 接受镜像布局并迁移 31 个文件、27 个 `generated/rust/...` 路径前缀，重跑 `build_runner`。
  - **配套门禁**（建议加进 `AGENTS.md` 提交前清单）：跑一次 codegen 后 `git diff --exit-code -- lib/generated rust/src/frb_generated.rs`，不一致即失败，避免再次手改生成文件或忘记重生成。
  - **已按方案 B 落地**（提交 `56cd9eb`）：
    - `flutter_rust_bridge.yaml` 的 `rust_input` 改为 `crate::api::ffi`；删除旧扁平生成树（34 个文件），生成树改为镜像 Rust 模块路径 `api/ core/ domain/ infra/ sdk/`。
    - 迁移 42 个手写文件的 101 处 `generated/rust` 引用（相对 + `package:` 两种写法）。
    - 新增 `scripts/check-codegen.ps1`（跑 codegen 后校验产物与仓库一致）并写入 `AGENTS.md` 提交前清单。
    - 验证：`flutter analyze` 干净；`flutter test` **433 全过**；`cargo build --lib` 通过；连续两次 codegen 产物逐字节一致；真机（Android 模拟器）登录 → 会话列表 → 消息详情 → 未读分割线/表情回复/消息标记全部正常，无运行时错误。
    - 遗留注意：新布局与 Rust 目录耦合，Rust 侧再动目录仍需同步迁移 Dart import —— 由 `check-codegen.ps1` 兜住（改完不重新生成会直接失败）。
- [x] P2-1 @所有人（2026-10-19）：工具栏 @ 选择器与实时 @ 列表均置顶「所有人」，选中后写入 `AtAllTag` 并插入 `@所有人 ` 文本；发送为 contentType=106，`atUserList/atUserIDList` 携带 `AtAllTag`，服务端据此计算 `groupAtType`。
  - 顺带修复：工具栏 @ 选人只改文本、没记 atUserId，导致发出普通文本；插入完整昵称后候选列表重新弹出的问题。
  - 测试：`test/ui/chat/group_member_picker_test.dart`、`test/ui/chat/composer_helpers_test.dart`；真机（模拟器）验证消息落库 `atUserIDList=["AtAllTag"]`。
  - 同批修复：全局客户端持有者由 `OnceLock` 改为可替换 `RwLock`。热重启/重登后 `sendMessage` 仍走旧客户端，表现为「服务端已收到、本地气泡不上屏」。
- [ ] P2-2 音视频通话：LiveKit 接入（权限、来电弹窗、通话页），独立模块。
- [ ] P2-3 翻译 / 网页搜索 / 飞书内搜索：依赖第三方服务与「选中文本」上下文能力，先出方案。
- [ ] P2-4 云文档、任务、日程、定时消息、边写边译、群机器人、举报：均依赖外部系统，OpenIM 无对应协议；建议**从 UI 摘除**或保留占位并明确标注未排期。
- [ ] P2-5 置顶消息跨端同步：确认服务端是否支持消息级 Pin；不支持则用自定义消息（`content_type` 110）广播，与 P1-1 解耦。

## 5. 群管理真机回归（2026-10-24）

环境：Mi 10 Pro（`849f6987`，登录「我」`2006526104`）+ 测试群 `658698100`，服务端为本地 Docker OpenIM。
回归脚本：`test_driver/group_manage_driver.dart`、`group_admin2_driver.dart`、`group_kick_driver.dart`。

### 5.1 已验证通过

| 功能 | 关键接口 | 结论 |
|---|---|---|
| 群成员角色展示 | `POST /group/get_group_member_list` | 群主/管理员/成员徽标正确，管理卡按当前用户角色出现 |
| 修改群名称 / 群描述 | `POST /group/set_group_info` | 200；查 MongoDB 确认 `group_name`、`introduction` 已落服务端 |
| 全员禁言 / 解除 | `POST /group/mute_group` | 开关往返正常 |
| 设置 / 取消管理员 | `POST /group/set_group_member_info` | 200；请求体为批量 `{"members":[...]}`，UI 徽标即时切换 |
| 邀请成员 | `POST /group/invite_user_to_group` | 200；成员数 3→4，成员列表出现被邀请人 |
| 踢出成员 | `POST /group/kick_group` | 200；成员数 4→3，列表中移除 |
| 单人禁言 / 取消禁言 | `POST /group/mute_group_member` / `cancel_mute_group_member` | 200 / 200，禁言 60s 后恢复 |
| 解散群 | `POST /group/dismiss_group` | 一次性测试群 200，返回会话列表且该会话即时移除 |
| 转让群主（跨端） | `POST /group/transfer_group` | 200；真机（原群主）降为成员、管理卡消失，模拟器（新群主）显示群主并可管理 |
| 新群主解散群 | 模拟器侧 `dismiss_group` | 200；解散前两端角色一致（小萌=群主、我/黄磊=成员） |
| 群公告 | `POST /group/set_group_info`（notification） | 200；Mongo 中 `notification` 已写入，设置页提示「群公告已更新」 |
| 群昵称 | `POST /group/set_group_member_info`（nickname） | 200；群信息成员列表显示「我-群昵称验证 / 群主」，Mongo 同步 |
| 群二维码 | 群信息 → 群二维码 | 页面正常渲染二维码 + 群 ID + 群名 |
| 退出群组 | `POST /group/quit_group` | 200；回到会话列表，`ConversationEvent::Deleted` 触发 `sg_<id>` 即时移除 |

### 5.2 回归中发现并修复

1. **群成员角色映射错误**（`3fd51a1`）：服务端 `roleLevel` 为 100/60/20，UI 按 3/2/1 判断，直接透传导致全员显示「成员」、群主管理卡不渲染。已在 SDK 层归一化（100→3、60→2、20→1），发请求时再反归一化。
2. **设置群成员信息请求体结构错误**：服务端要求 `{"members":[{"groupID","userID","roleLevel"}]}`，原实现发扁平对象，返回 `errCode=1001 ArgsError`，表现为「点了设管理员没反应」。
3. **群信息页不拉服务端资料**：群名取本地会话缓存、群描述硬编码「暂无描述」，重启 App 后即便服务端已改名/已写描述仍显示旧值。改为进入页面时调用 `get_groups_info` 以服务端为准刷新（`lib/ui/groups/views/group_info_screen.dart`、`lib/ui/groups/view_models/group_info_view_model.dart`）。
4. **群资料不落本地库**：`GroupService::get_groups_info` 只返回不落库、`set_group_info` 只改内存缓存，导致会话列表与群设置页的群名长期是旧值。改为拉取即落库（保留服务端不下发的本地字段），并把 `handle_group_info_changed` 里「刷新会话名称」安排在群资料落库之后。
5. **退群/解散后停在已失效页面**：两者都只 pop 一层，落在已退出/已解散的群设置或群聊页；且本地群资料与会话未清理，列表残留进不去的「死群」。改为回到会话列表，并在 SDK 侧删除本地群记录与 `sg_<groupID>` 会话（随后刷新会话列表）。
6. **转让群主请求缺 `oldOwnerUserID`**：服务端校验该字段非空，原请求只有 `groupID`+`newOwnerUserID`，返回 `errCode=1001 ArgsError`（表现为「点了转让群主没反应」）。已按当前登录用户补齐，并在转让后刷新本地群资料。
7. **群移除后的会话清理没有事件通知**：`ConversationEvent::Deleted` 在 Dart 侧只打日志、不从列表移除；群被解散/自己被移出时 SDK 也只删库不通知。现改为删除本地会话时发出 `Deleted`，Dart 侧按 id 从内存列表移除。

### 5.3 未覆盖

- ~~转让群主：会改变测试群权限，未在 `658698100` 上执行~~ → 已用一次性群 + 第二账号验证（见 5.1 / 5.4：A 建群 → 转让给黄磊 → 对方解散）。
- 聊天设置页的「群二维码 / 群成员日历 / 分享 / 群机器人」等入口仍为占位；群公告与群信息页的群二维码已可用（见 5.1）。

已知残留：

- ~~单人禁言在成员行上没有状态展示（只有 SnackBar 反馈）~~ → 已修复（2026-10-25，`34e3405`）：群成员行展示「禁言中 · 剩 N 分钟/小时/天」徽标，数据取自成员列表接口的 `muteEndTime`，到期自动消失；真机已验（黄磊行显示剩余时长，其他成员无徽标）。
- OpenIM 服务端在解散群后仍保留成员侧的会话记录，客户端只在本地清理；全量重装/全量会话同步后可能重新出现，后续应接服务端会话删除接口。目前由「群集合对账」（登录/群增量同步后按群表清理 `sg_*` 会话）兜住，见 5.4。
- ~~「他人解散群」的通知未在真机日志中出现，被动端清理只能在重连后发生~~ → 已定位并修复：本端解散固定带 `deleteMember=true`，服务端在该分支跳过 1511 通知；改为 `deleteMember=false` 后成员端可即时收到通知，详见 5.4。
- ~~新建群若没人发言，成员端没有该群会话~~ → 已修复（2026-10-25）：群增量同步的新增分支会补建本地 `sg_<groupID>` 会话（`GroupService::ensure_group_conversation`，经 ConversationService 广播 `Changed`），不再依赖 1501/1502 通知；本端建群也改走同一路径（此前直写会话表、不发事件）。群信息页在「本地无会话但服务端有群」时正常展示，不再误报「群组不存在」。真机验证：App 停止期间由他人建群（无消息），启动后群同步日志 `补建群会话`，会话列表顶部出现该群（暂无消息）。
- ~~退群/解散瞬间会话页仍在卸载中，会补发一次 `get_group_member_list` 并得到 NoPermissionError（仅日志噪音，不影响交互）~~ → 已修复（2026-10-25）：实际错误码是 `errCode=1002 NoPermissionError`（原文写的 1005 有误），修法是群已不在本地群表时成员视图模型直接短路，不再发请求。真机复现（转让群主后由对方解散）：该群的成员列表请求与 NoPermissionError 均不再出现，清理日志正常。
- ~~清理日志无法区分「真删」与「重复空删」~~ → 已修复（2026-10-25，`651422a`）：`ConversationRepository::delete` 返回影响行数，真删记 INFO `removed=true`，空删降级为 DEBUG `removed=false`；「每群只清理一次」可直接数 `removed=true` 的 INFO 行。
- ~~离线补拉的群解散通知（1511）会为已解散群建出本地会话；且 `get_groups_info` 会把 `status=2` 的群资料写回群表，对账又把它们当有效群~~ → 已修复（2026-10-25）：对账挪到消息同步之后再兜一次；`get_groups_info` 不再落库已解散群；对账会把内存/群表里残留的 `status=2` 群按群失效清理（群资料 + 成员缓存 + 会话）。真机验证：登录后 6 个已解散群全部清掉，本地群表 16→10、会话 25→23，剩余 10 群与服务端 `status=0` 一致。

### 5.4 群生命周期清理回归（2026-10-25，OpenSpec 变更 `fix-remote-group-dismiss`）

环境：Mi 10 Pro（`849f6987`，登录「我」`2006526104`，**横屏**，逻辑窗口 818×344dp）+ 本地 Docker OpenIM；对端动作由服务端接口按同一账号令牌发起（第二账号用演示账号「黄磊」`9850839580`，不占用设备登录态）。

验证结论（`cleanup_source` 取自真机 logcat）：

| 路径 | 操作 | 结果 |
|---|---|---|
| 被动解散（推送） | A 建群 → 转让给黄磊 → 黄磊 `dismiss_group(deleteMember=false)` | 成员端即时收到 1511 通知；`sg_<groupID>` 无需重启即从列表移除，日志 `cleanup_source=push`（同批还有 `sync` 对账），driver 断言 `GROUP_REMOTE_DISMISS_OK` |
| 历史孤儿会话 | 清空登录态后重新登录 | 登录对账一次清掉 6 个死群（含设计文档点名的 `sg_2508474771`、`sg_3336319524`），日志 `cleanup_source=sync, removed=6` |
| 主动退群 | 群主为黄磊、我在群内 → App 内「退出群组」 | `POST /group/quit_group` 200；本地清理一次（`cleanup_source=local_action`）后 `conversationDeleted`，回到会话列表 |
| 主动解散 | 我为群主 → 群信息 → 群管理 → 解散群组 | `POST /group/dismiss_group` 成功；本地清理一次（`cleanup_source=local_action`），服务端群成员清零（0） |

回归中发现并修复：

1. **横屏/小高度下「群管理」弹窗把最后一项挤出屏幕**：`showModalBottomSheet` 默认高度上限约为屏高的 9/16，横屏 344dp 下只有 ~212dp，而「群管理」弹窗内容约 269dp，`RenderFlex overflowed by 57 pixels`，「解散群组」不可点击（相同原因也让登录页按钮落到首屏之外）。已把群相关的 6 个底部弹窗统一改为可滚动容器（`_SheetBody`），装得下按内容高度、装不下可滚动。真机热重载后确认弹窗无溢出且能滚到「解散群组」完成解散。
2. 回归脚本适配：`group_transfer_owner_driver` 支持 `NEW_OWNER_ID`（默认小萌）、`group_dissolve_by_owner_driver` 支持从任意页面回到会话列表并在弹窗内滚动、新增 `login_driver` 验证码登录辅助（真机令牌被新登录顶掉时可自助恢复登录态）。

后续已补齐（同日）：

- 清理日志带 `removed=true/false`：真删记 INFO，空删降级 DEBUG，「只清理一次」可直接按 INFO 条数核对（`651422a`）。
- 群成员行展示禁言状态徽标（`34e3405`）。
- 群已不在本地群表时成员视图模型短路，退群/解散不再补发无效的成员列表请求（消除 `NoPermissionError` 噪音）。
- 离线补拉的 1511 会经「会话消息」通道建出孤儿会话：消息同步后再对一次账兜底，并清理本地残留的 `status=2` 群（群资料/成员/会话），同时不再把已解散群资料落库。
- 底部弹窗统一收敛到公共 `ScrollableSheetBody`（群相关 6 个 + 群信息「按加入时间筛选」+ 好友操作），并补 640×300 小窗口 widget 测试兜住「横屏/小高度下最后一项被裁切」的回归；`@ 选择群成员`（Flexible + ListView）与 2 项短弹窗保持原样。
- 无消息新群也会补建本地会话（群增量同步新增分支 + 本端建群统一走 `ensure_group_conversation`），成员端不再只能从「通讯录 → 我的群组」进入。
- 对账日志从「每群一行」聚合为一行：`已解散群对齐本地状态: cleanup_source=sync, count=6, groups=...`，一次清理多个死群时不再刷屏（`rust/src/sdk/group/service.rs`）。

## 6. 验收与验证方式

按仓库《迭代节奏》执行，避免全量重建与无谓测试：

- UI/样式/文案：Flutter MCP 热重载 + `get_widget_tree` + `get_offset` + 截图；必要时补组件测试。
- 逻辑改动（状态机/reducer/mapper/排序）：只跑相关单文件，如 `flutter test test/ui/chat/<file>.dart`。
- Rust/SDK 改动：`cargo test --lib <模块>`，必要时 `rust/scripts/test-fast.ps1`。
- 提交前：`scripts/check-architecture.ps1` + `scripts/check-design-tokens.ps1` 必须通过。

## 7. 风险与待确认

1. 群已读成员详情依赖服务端接口。已查本地 `open-im-server` 源码：只有 `GetHasReadSeqs` / `GetConversationsHasReadAndMaxSeq`（按用户查已读 seq），**没有「按消息查已读成员列表」的 API**；实时回执通知只覆盖在线期间。结论：当前服务端版本做不了可靠的已读成员详情，需先向服务端提需求或升级后再评估。
2. 消息级 Pin 是否有服务端支持待确认；无则走自定义消息广播。
3. `editMessage` 当前实现是「发新消息 + MQ 广播」，不是原子编辑，需要确认对端展示与撤回交互是否可接受。
4. 会话标签与分组存在语义重叠，需先确定「标签 = 分组」还是「标签另建体系」，否则会出现两套相似的本地数据。
