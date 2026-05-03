# CLAUDE.md - Claude Code Agent 规范

## 项目概述
Flutter + Rust 即时通讯应用，使用 flutter_rust_bridge 进行跨语言通信。

## 关键命令

```bash
# 运行开发服务器
flutter run -d windows

# 编译发布版本
flutter build windows

# 检查 Rust 代码
cd rust && cargo check

# 重新生成 Rust Bridge（修改 Rust API 后）
flutter_rust_bridge_codegen generate

# 运行测试
flutter test
```

## 代码修改规则

### Dart 侧修改
1. 模型类使用 Freezed 生成，修改后运行 `dart run build_runner build`
2. UI 组件优先使用 StatelessWidget，状态用 Riverpod 管理
3. 颜色/样式从 `AppTheme` 获取，不硬编码
4. 导航使用 `NavigationService` 或 `go_router`，不直接用 Navigator

### Rust 侧修改
1. 公开 API 需添加 `#[flutter_rust_bridge::frb(sync)]` 或 `#[flutter_rust_bridge::frb]` 宏
2. 修改 Rust API 后必须重新生成 bridge 代码
3. 错误处理使用 `Result<T, E>`，避免 panic
4. IM 相关数据存储统一用 SQLite（Rust 侧 sqlx）

### 跨语言边界
1. Dart 不直接操作 IM 数据库，所有 IM 操作通过 Rust API
2. 文件路径传递使用字符串，Rust 侧解析为 PathBuf
3. 大文件传输使用流式接口，避免内存复制

## 文件创建位置

| 类型 | 位置 | 示例 |
|------|------|------|
| 页面 | `lib/screens/` | `chat_screen.dart` |
| 组件 | `lib/widgets/` | `message_bubble.dart` |
| 服务 | `lib/services/` | `auth_service.dart` |
| 模型 | `lib/models/` | `user.dart` |
| Rust API | `rust/src/api/` | `auth.rs` |
| Rust 业务 | `rust/src/im/` | `client.rs` |

## 测试要求
- 新增业务逻辑需配套单元测试（Rust 侧）
- UI 组件需提供 Widget 测试（可选但推荐）
- 核心流程（登录、发消息）需有集成测试覆盖

## 提交前检查
- [ ] `flutter analyze` 无警告
- [ ] `cargo clippy` 无警告
- [ ] 相关测试通过
- [ ] 手动验证 UI 正常（如修改了界面）
