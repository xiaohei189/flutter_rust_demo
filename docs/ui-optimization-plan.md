# UI 与目录组织优化计划

> 状态：已实施（A-E 全部完成，Windows 集成测试通过）
> 范围：Flutter UI 层、目录组织、测试目录镜像
> 不涉及：Rust SDK、OpenIM 服务端协议、后端接口改动

## 1. 背景与目标

当前项目的 UI 已经具备较好的基础：`IndexedStack` 保持 Tab 状态、输入框使用 `ValueNotifier` 减少重建、已读标记有防抖、会话列表和消息列表使用 `ListView.builder`。

但按照 `flutter-apply-architecture-best-practices` 的分层要求，仍有以下主要缺口：

- UI 层混入业务逻辑和直接数据访问，最大的 `ChatDetailScreen` 超过 1800 行。
- 功能级 Provider 全局平铺，feature 内部目录不统一。
- 只有 light theme，大量硬编码颜色，后续深色模式成本高。
- 列表 key、图片加载、JSON 预览解析等存在性能隐患。
- 系统返回、聊天标题点击、搜索结果跳转等 UX 行为不完整。
- 无障碍、本地化、空态/错误态未形成统一规范。

本计划的目标是把这些问题拆成可独立验收的工作项，按阶段落地。

## 2. 现状判断

### 2.1 目录结构现状

```text
lib/
├── data/
│   ├── config/
│   ├── repositories/
│   └── services/
├── domain/models/
├── generated/rust/        # FRB + Freezed 生成代码，禁止手改
├── providers/             # 仅保留全局 Provider
├── router/
└── ui/
    ├── core/
    ├── shared/
    │   ├── views/
    │   └── widgets/
    ├── shell/
    ├── auth/views
    ├── chat/{providers, view_models, views, widgets}
    ├── contacts/{providers, view_models, views, widgets}
    ├── discover/{views, widgets}
    ├── groups/{providers, view_models, views, widgets}
    └── profile/{providers, view_models, views, widgets}
```

### 2.2 主要问题

| 问题 | 位置 | 说明 |
|------|------|------|
| UI 层直接编排加载 | `lib/ui/contacts/views/contacts_screen.dart`、`lib/ui/groups/views/group_list_screen.dart` 等 | 多个页面在 `initState` 直接调用多个 notifier |
| 页面过厚 | `lib/ui/chat/views/chat_detail_screen.dart` | 发送、草稿、搜索、媒体、@、多选转发都在一个 State |
| 登录注册逻辑写在页面 | `lib/ui/auth/views/login_screen.dart`、`register_screen.dart` | 页面直接初始化 MessageService |
| 功能级 Provider 平铺 | `lib/providers/` | 无法体现 feature 归属 |
| 硬编码颜色 | `lib/ui/contacts/views/contacts_screen.dart`、`lib/ui/auth/views/login_screen.dart` 等 | 深色模式改造成本高 |
| 列表性能隐患 | `lib/ui/chat/views/chat_list_screen.dart`、`chat_list_item.dart` | 整表 key、逐项 JSON 解析 |
| 图片无统一缓存组件 | `lib/ui/chat/widgets/message_bubble.dart` 等 | 无 loading、无 cacheWidth |
| 搜索无防抖 | `lib/ui/chat/views/chat_detail_screen.dart` | 每次输入直接查询 |
| 系统返回未处理 | `lib/ui/chat/views/chat_detail_screen.dart` | 没有 `PopScope`，草稿/已读只在 AppBar 返回时保存 |
| 测试目录未镜像 | `test/` | 部分 widget 测试仍平铺在顶层 |

## 3. 目标目录结构

```text
lib/
├── app/                       # 应用壳、启动、路由、全局注入
│   ├── app.dart
│   ├── router/
│   └── providers/
├── data/
│   ├── repositories/
│   └── services/
├── domain/
│   ├── models/
│   └── use_cases/             # 仅在有复杂业务逻辑时启用
├── generated/rust/            # FRB 生成代码，禁止手改
└── ui/
    ├── core/                  # 只放主题、共享组件、共享工具
    └── features/
        ├── auth/
        │   ├── views/
        │   └── view_models/
        ├── chat/
        │   ├── views/
        │   ├── view_models/
        │   └── widgets/
        ├── contacts/
        │   ├── views/
        │   ├── view_models/
        │   └── widgets/
        ├── discover/
        │   ├── views/
        │   └── view_models/
        ├── groups/
        │   ├── views/
        │   ├── view_models/
        │   └── widgets/
        └── profile/
            ├── views/
            ├── view_models/
            └── widgets/
```

测试目录镜像：

```text
test/
├── support/fakes/             # 统一存放 Fake Repository / Service
├── data/                      # 镜像 lib/data
├── domain/                    # 镜像 lib/domain
└── ui/
    ├── chat/
    ├── contacts/
    ├── groups/
    └── profile/
```

## 4. 工作项清单

### 4.1 A 组：目录与结构清理

- [x] A1：确认并清理空目录 `lib/screens/`、`lib/domain/models/models/`。
- [x] A2：删除或合并未使用的 `lib/ui/profile/views/profile_screen.dart`，确认没有测试或路由引用。
- [x] A3：将 `lib/ui/core/main_screen.dart` 移动到应用壳位置，如 `lib/app/main_screen.dart` 或 `lib/ui/shell/main_screen.dart`。
- [x] A4：将登录存储、Host 配置等从 `ui/core/utils/` 迁移到 `data/` 或 `app/config/`。
- [x] A5：FRB 生成代码与手写代码隔离，生成代码放入 `lib/generated/rust/`，并在 AGENTS/README 标注禁止手改。
- [x] A6：统一 feature 目录为 `views/ + view_models/ + widgets/`，已从 contacts/groups/profile/discover/shared 抽取独立小组件；auth 的 `view_models/` 随 B3 补齐。
- [x] A7：明确跨功能页面的 owner：`search_screen.dart`、`scan_screen.dart`、`qr_code_screen.dart` 放到 `ui/shared/views/`。
- [x] A8：测试目录按 `test/ui/<feature>/` 镜像，`test/fakes/` 改为 `test/support/fakes/`。

### 4.2 B 组：P0 架构分层

- [x] B1：拆分 `ChatDetailScreen`。
  - 新建 `ChatDetailViewModel`，负责发送、草稿、引用、已读、多选、搜索等状态。
  - 拆分输入区、引用栏、多选栏、消息搜索面板等子组件。
  - 页面只保留布局、滚动、导航和媒体选择器。
- [x] B2：页面加载编排收敛到 feature ViewModel / Notifier。
  - `ContactsScreen`、`GroupListScreen`、`FriendRequestsScreen`、`BlacklistScreen`、`FriendListScreen` 不再在 `initState` 直接编排多个 provider。
  - View 只 watch 状态，首次加载由 Notifier `build` 的 `Future.microtask` 驱动。
- [x] B3：登录/注册流程抽成 `AuthViewModel`。
  - `MessageService.initialize`、凭证保存、倒计时、错误提示已从 Screen 移到 ViewModel。
  - Screen 只做表单校验、按钮状态和跳转。
- [x] B4：会话列表用户资料预计算。
  - 新增 `conversationUserProfilesProvider` 维护单聊用户资料缓存。
  - `ChatListScreen.itemBuilder` 不再逐项调用 `getUserProfile`。

### 4.3 C 组：P1 设计系统

- [x] C1：补充 dark theme 和主题 token。
  - 已完成：`AppTheme.darkTheme`、语义色板 `AppColors`、颜色/字体/圆角/间距/阴影 token，入口已接入 `ThemeMode.system`。
- [x] C2：替换页面中的硬编码颜色。
  - 已把 `AppTheme.*` 颜色常量全面切换到 `context.appColors.*`，覆盖核心组件、主界面、聊天页、通讯录、群组、个人资料、登录注册、搜索等。
  - 保留气泡/媒体/角标上的功能性白黑对比色（如蓝底白字、媒体查看器黑底）。
- [x] C3：统一圆角与间距规范。
  - `AppTheme.radiusSm/Md/Lg` 与 `spacingXs/Sm/Md/Lg/Xl` 已建立，CardLayout、附件面板、日期标签、筛选栏等核心组件已使用。
  - 气泡大圆角保留为消息视觉特征，不强行改为小圆角。
- [x] C4：清理重复页面与死代码。
  - 已删除未使用的 `ProfileScreen`，`MainScreen._MineScreen` 作为唯一“我的”入口。

### 4.4 D 组：P2 性能

- [x] D1：会话列表 key 修复。
  - 移除 `ValueKey<int>(conversations.length)`，改用稳定 `PageStorageKey`。
- [x] D2：消息预览与日期缓存。
  - `latestMessagePreview` 与时间格式化抽到 `conversation_display.dart`，并由 `ConversationListNotifier` 统一缓存。
  - `MessageList` 日期分隔符一次预计算，不再逐消息重复 `DateFormat`。
- [x] D3：统一图片组件。
  - 新增 `AppImage`，支持网络/本地/asset、占位、错误态与 `cacheWidth`。
  - 替换 `MessageBubble`、`MediaViewer`、`UserAvatar` 中的裸图片加载。
- [x] D4：聊天记录搜索防抖。
  - `ChatMessageSearchSheet` 与全局 `SearchScreen` 均增加 300ms 防抖和过期响应丢弃。

### 4.5 E 组：P3 UX、无障碍与导航

- [x] E1：聊天页标题点击行为。
  - `ChatDetailScreen` 标题点击进入聊天设置。
- [x] E2：系统返回处理。
  - `ChatDetailScreen` 已增加 `PopScope`，系统返回时保存草稿、标记已读、退订在线状态。
- [x] E3：搜索结果跳转。
  - `MessageList` 支持按 `clientMsgId` 定位，搜索结果点击后关闭面板并滚动到对应消息。
- [x] E4：扫码链接处理。
  - 扫码链接改为“复制链接”对话框，不再显示“暂不支持”。
- [x] E5：统一空态、加载态、错误态。
  - 新增 `EmptyState`/`ErrorState` 共享组件，已用于好友、黑名单、群组等页面。
- [x] E6：无障碍基础。
  - 全局设置 `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)`，降低大字号溢出风险。
- [x] E7：本地化基础。
  - 已加入 `l10n.yaml`、`app_en.arb`/`app_zh.arb`，启用 `generate: true` 并接入 `AppLocalizations`。
  - 已迁移应用标题、底部 Tab、登录/注册标题；其余文案按模块持续迁移。
- [x] E8：导航一致性。
  - 生产环境关闭 `debugLogDiagnostics`，改为 `kDebugMode` 控制。
  - `/profile/user/:id` 支持纯 ID 深链，不依赖 `extra` 传对象。
  - 新增 `/qr`、`/merge-message`、`/media/image`、`/media/video` 路由，联系人选择器支持 title 参数。
  - 主要业务导航与媒体全屏预览已统一到 GoRouter。

## 5. 实施顺序

### Phase 1：结构与清理

执行 A 组全部工作项。本阶段不改变业务行为，以目录迁移和死代码清理为主。

退出条件：

- 目录结构符合第 3 节目标结构。
- 空目录与死代码清理完成。
- 测试目录镜像完成。

### Phase 2：P0 架构分层

执行 B 组全部工作项。优先做 B1 `ChatDetailScreen` 拆分，再处理页面加载编排和登录流程。

退出条件：

- Screen 不再直接编排业务加载。
- `ChatDetailScreen` 行数显著下降，子组件可独立阅读。
- 现有单元/组件测试全部通过。

### Phase 3：P2 性能

执行 D 组全部工作项。优先做 D1 和 D2，改动小、收益直接。

退出条件：

- 会话列表滚动和消息列表滚动不再因数量变化整表重建。
- 预览和时间格式化不再在 build 中重复计算。
- 图片统一组件覆盖消息、媒体查看器、头像。

### Phase 4：P1 设计系统

执行 C 组全部工作项。建议在 D 组之后做，避免在性能改造期间频繁改样式。

退出条件：

- 深色模式可全局切换，主要页面无硬编码浅色背景。
- 颜色、圆角、间距、文本样式统一来自主题 token。

### Phase 5：P3 UX、无障碍与导航

执行 E 组全部工作项。按 UX 行为、无障碍、导航三个小批次推进。

退出条件：

- 系统返回行为正确。
- 聊天标题、搜索结果、扫码结果有明确交互。
- 主要页面通过基础无障碍检查。
- 路由统一使用 GoRouter。

## 6. 验收标准

- `flutter analyze` 无新增 warning/error。
- `flutter test test` 全部通过。
- 目录结构符合第 3 节目标结构。
- UI 层不再直接调用 Repository / Service 编排业务流。
- 主要页面在 light/dark 两种主题下均可正常阅读。
- 会话列表滚动、历史消息加载、图片列表在长列表下无明显卡顿。
- 系统返回聊天页时草稿和已读状态正确。

## 7. 验证方式

```powershell
flutter pub get
flutter analyze
flutter test test
```

涉及导航、返回、搜索跳转的改动，补充对应 widget test；涉及长列表和图片的改动，手动在模拟器/真机验证；涉及目录迁移的 PR，使用 `git diff --stat` 确认没有意外文件改动。

## 8. 风险与注意事项

- `ChatDetailScreen` 拆分是最高风险项：涉及 FFI 调用、dispose 顺序、草稿与已读逻辑，建议拆分时保持行为不变，分多次 PR。
- Provider 迁移会触及大量 import，建议与 B 组一起做，避免重复搬运。
- 深色模式不是纯换色：需要同步处理气泡、图片、输入区、弹窗的对比度。
- FRB 生成代码迁移后必须重新跑 codegen，确认没有手写文件被覆盖。
- 测试目录迁移后检查 CI/脚本是否引用旧路径。

## 9. 参考文件

- `docs/conventions.md`
- `docs/architecture.md`
- `.agents/skills/flutter-apply-architecture-best-practices/SKILL.md`

## 10. 追加优化进度

- [x] P0-1：SearchScreen 拆分 SearchViewModel 并补测试。
- [x] P0-2：拆分 shell 的“我的”页与菜单组件。
- [x] P0-3：拆分 contact_picker / chat_settings / group_info 大文件。
- [x] P1-1：MessageList 消息 key 缓存淘汰。
- [x] P1-2：图片磁盘缓存与气泡时间/宽度缓存。
- [x] P1-3：常见页面标题与搜索文案迁移到 l10n。
- [x] P2：补充共享组件 widget 测试与核心图标按钮 Semantics。
- [x] P3：按阶段整理提交与文档状态。

## 11. 下一批优化计划

> 状态：P0 已实施
> 目标：继续收敛剩余 UI 直连数据层，补齐大页面 ViewModel，再推进设计 token、本地化和测试覆盖。

### 11.1 P0：剩余页面架构分层

- [x] P0-A：`AccountSettingsScreen` 拆分 `AccountSettingsViewModel`。
  - 应用锁、生物识别、本地通知、语言、全局免打扰写入迁移到 ViewModel。
  - Screen 只保留开关交互、对话框、SnackBar 与布局。
  - 补充 ViewModel 单元测试。
- [x] P0-B：`GroupInfoScreen` 拆分 `GroupInfoViewModel`。
  - 群资料编辑、群成员管理、转让、解散等 Repository 调用迁移到 ViewModel。
  - Screen 只保留成员筛选、对话框、SnackBar 与布局。
  - 补充 ViewModel 单元测试。
- [x] P0-C：`FriendSetupScreen` 拆掉直接 FFI/MessageService 访问。
  - 好友关系、拉黑、会话定位等操作下沉到 Repository / ViewModel。
- [x] P0-D：`ChatListScreen`、`ContactPickerScreen`、`ChatDetailScreen` 残留编排收敛。
  - `ChatListScreen` 筛选与会话操作迁入 `ChatListViewModel`。
  - `ContactPickerScreen` 加载、过滤、选中迁入 `ContactPickerViewModel`。
  - `ChatDetailScreen` 好友选择与文件打开迁入 `ChatDetailViewModel`。

### 11.2 P1：设计系统与本地化

- [ ] P1-A：清理剩余 `Colors.white/black` 与 `Color(0x...)`，迁移到语义 token。
- [ ] P1-B：把聊天设置、群资料、好友资料、设置页硬编码中文迁移到 ARB。

### 11.3 P2：测试覆盖

- [ ] P2-A：为 `group_info_screen`、`account_settings_screen`、`friend_setup_screen` 补 widget test。
- [ ] P2-B：为 `contact_picker_screen`、`chat_settings_screen` 补关键交互 widget test。

### 11.4 P3：大文件拆分

- [x] P3-A：`MessageBubble` 按消息类型拆分。
  - 新增 `message_parts/`，文本/Markdown/媒体/名片/合并/位置/引用分别独立。
- [x] P3-B：`ChatInput` 拆附件面板、格式栏、快捷操作区。
  - 表情面板拆为 `EmojiPanel`，Markdown 格式栏拆为 `MarkdownFormatBar`。
- [x] P3-C：`ChatDetailScreen` 剩余媒体、多选、转发面板继续拆分。
  - 媒体选择、位置、文件、视频、语音、名片操作拆入 `ChatMediaActions`。
  - 多选栏、转发选择、媒体查看器已由独立组件承载。
- [ ] P3-D：`MessageServiceNotifier` 按连接、消息、会话、群组职责拆分。
  - 已完成：`MessageServiceState` 独立文件、时间规范化独立 helper。
  - 已完成：消息/会话状态变更抽成 `MessageServiceReducer` 并补单测。
  - 待完成：连接/会话等 IO 方法职责级拆分。
