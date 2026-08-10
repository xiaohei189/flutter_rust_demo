# UI 与目录组织优化计划

> 状态：进行中
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
├── data/                  # 按类型组织，OK
├── domain/models/         # 按类型组织，OK
├── providers/             # 全局平铺，功能级 Provider 与全局 Provider 混放
├── router/
├── screens/               # 空目录，疑似迁移残留
├── src/rust/              # FRB 生成代码与手写 FFI 混放
└── ui/
    ├── core/
    ├── auth/
    ├── chat/
    ├── contacts/
    ├── discover/
    ├── groups/
    └── profile/
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
- [ ] A5：FRB 生成代码与手写代码隔离，生成代码放入 `lib/generated/rust/` 或 `lib/src/rust/generated/`，并在 AGENTS/README 标注禁止手改。
- [ ] A6：统一 feature 目录为 `views/ + view_models/ + widgets/`。
- [ ] A7：明确跨功能页面的 owner：`search_screen.dart`、`scan_screen.dart`、`qr_code_screen.dart` 放到 `ui/shared/` 或指定 feature。
- [ ] A8：测试目录按 `test/ui/<feature>/` 镜像，`test/fakes/` 改为 `test/support/fakes/`。

### 4.2 B 组：P0 架构分层

- [ ] B1：拆分 `ChatDetailScreen`。
  - 新建 `ChatDetailViewModel`，负责发送、草稿、引用、已读、多选、搜索等状态。
  - 拆分输入区、引用栏、多选栏、消息搜索面板、媒体操作等子组件。
  - 页面只保留布局、滚动、导航和简单的 UI 状态。
- [ ] B2：页面加载编排收敛到 feature ViewModel / Notifier。
  - `ContactsScreen`、`GroupListScreen`、`FriendRequestsScreen`、`BlacklistScreen`、`FriendListScreen` 不再在 `initState` 直接编排多个 provider。
  - View 只 watch 状态，加载由 ViewModel 暴露的方法或生命周期驱动。
- [ ] B3：登录/注册流程抽成 `AuthViewModel`。
  - 把 `MessageService.initialize`、凭证保存、倒计时、错误提示从 Screen 移到 ViewModel。
  - Screen 只做表单校验、按钮状态和跳转。
- [ ] B4：会话列表用户资料预计算。
  - 在 `conversationListProvider` 或对应 ViewModel 中维护 `Map<userId, User>`。
  - `ChatListScreen.itemBuilder` 不再逐项调用 `getUserProfile`。

### 4.3 C 组：P1 设计系统

- [ ] C1：补充 dark theme 和主题 token。
  - 在 `AppTheme` 中增加 `darkTheme`。
  - 建立统一的颜色、字体、圆角、间距、阴影 token。
- [ ] C2：替换页面中的硬编码颜色。
  - 优先处理 `Colors.white`、`Colors.grey`、`Colors.red`、`Color(0xFF...)`。
  - 改用 `AppTheme` 或 `ThemeExtension`，为深色模式铺路。
- [ ] C3：统一圆角与间距规范。
  - 收敛 `CardLayout`、附件面板、气泡、日期标签等圆角值。
  - 以 `AppTheme` 暴露统一 radius 和 spacing 常量。
- [ ] C4：清理重复页面与死代码。
  - 合并 `ProfileScreen` 与 `MainScreen._MineScreen` 的职责，删除未使用页面。

### 4.4 D 组：P2 性能

- [ ] D1：会话列表 key 修复。
  - 移除 `ValueKey<int>(conversations.length)`。
  - 列表外层使用稳定 key，列表项使用 `conversationId` 作为 key。
- [ ] D2：消息预览与日期缓存。
  - `latestMessagePreview` 不再在每次 build 中重新解析 JSON。
  - 会话/消息模型或 Notifier 中缓存预览文本、格式化时间。
  - `MessageList` 的日期分隔符预计算，避免每个消息重复 `DateFormat`。
- [ ] D3：统一图片组件。
  - 新增共享图片组件，支持占位、错误态、`loadingBuilder`、`frameBuilder`、`cacheWidth`。
  - 替换 `MessageBubble`、`MediaViewer`、`UserAvatar` 中的裸 `Image.network` / `NetworkImage`。
  - 评估是否引入 `cached_network_image` 作为统一缓存方案。
- [ ] D4：聊天记录搜索防抖。
  - `onChanged: _search` 增加 300-400ms 防抖。
  - 增加请求序号或取消机制，丢弃过期响应。

### 4.5 E 组：P3 UX、无障碍与导航

- [ ] E1：聊天页标题点击行为。
  - 实现 `ChatDetailScreen` 标题点击进入聊天设置或查找聊天记录。
- [ ] E2：系统返回处理。
  - 为 `ChatDetailScreen` 增加 `PopScope`，系统返回时保存草稿、标记已读、退订在线状态。
- [ ] E3：搜索结果跳转。
  - 搜索结果的点击从 `AlertDialog` 改为定位到消息上下文。
- [ ] E4：扫码链接处理。
  - 明确“暂不支持打开链接”的行为：支持 URL 预览/打开，或从 UI 隐藏该入口。
- [ ] E5：统一空态、加载态、错误态。
  - 建立 `EmptyState`、`ErrorState`、`SkeletonList` 等共享组件。
  - 通讯录、群组、好友等页面统一使用。
- [ ] E6：无障碍基础。
  - 为图标按钮补充 `Semantics` 标签。
  - 检查 10-12px 小字与固定尺寸组件在系统大字号下的溢出。
  - 全局设置合理的 textScale 上限。
- [ ] E7：本地化基础。
  - 引入 `flutter_localizations` + `intl`，准备 arb 文件。
  - 当前硬编码中文文案逐步迁移到 `l10n`。
- [ ] E8：导航一致性。
  - 统一使用 GoRouter，替换零散的 `Navigator.push` / `PageRouteBuilder`。
  - `/profile/user/:id` 支持纯 ID 深链，不依赖 `extra` 传对象。
  - 生产环境关闭 `debugLogDiagnostics`。

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
