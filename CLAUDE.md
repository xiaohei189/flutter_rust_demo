# 先分析问题，给出改进建议或者探讨后，需要确认才能修改代码
# CLAUDE.md - Claude Code Agent 规范

## 项目概述
Flutter + Rust 即时通讯应用，基于 OpenIM 协议，使用 flutter_rust_bridge v2.11.1 进行跨语言通信。

详细架构见 [docs/architecture.md](docs/architecture.md)，编码规范见 [docs/conventions.md](docs/conventions.md)。

## 关键命令

```bash
# 检查 Rust 代码
cd rust && cargo check

# 检查 Rust 代码风格
cd rust && cargo clippy

# 检查 Dart 代码
flutter analyze

# 运行测试
cd rust && cargo test
flutter test

# 重新生成 Rust Bridge（修改 Rust API 后必须执行）
flutter_rust_bridge_codegen generate

# 重新生成 Freezed 模型（修改 Dart 模型后必须执行）
dart run build_runner build

# 运行开发服务器
flutter run -d windows
```

## 分层架构

```
Flutter UI (lib/screens/, lib/widgets/)
    ↕
Riverpod 状态管理 (lib/providers/)
    ↕
Dart 服务层 (lib/services/)
    ↕
flutter_rust_bridge FFI (lib/src/rust/ ←→ rust/src/api/)
    ↕
Rust SDK 入口 (rust/src/sdk/)
    ↕
Rust 核心业务 (rust/src/core/)  ←→  基础设施 (rust/src/infra/)
```

## 代码修改规则

### Dart 侧
1. 模型类使用 Freezed 生成，修改后运行 `dart run build_runner build`
2. 页面用 `ConsumerStatefulWidget`，纯渲染组件用 `StatelessWidget`
3. 状态管理用 Riverpod，核心状态在 `MessageServiceNotifier` 中
4. 颜色/样式从 `AppTheme` 获取，不硬编码
5. 导航使用 `NavigationService` 或 `go_router`，不直接用 Navigator
6. 错误信息用中文：`'操作描述失败: $e'`
7. 日志：`appLog.i('[ModuleName] 描述')`，模块名用英文

### Rust 侧
1. 公开 API 加 `#[flutter_rust_bridge::frb]` 宏，`pub async fn` 返回 `Result<T>`
2. 修改 Rust API 后必须运行 `flutter_rust_bridge_codegen generate`
3. 错误处理统一用 `SdkError`（`thiserror::Error`），桥接层转 `anyhow::Error`
4. 数据存储用 SQLite（sqlx + DAO 模式），`FromRow` 映射模型
5. 日志用 `tracing::info!`/`sdk_info!`，标签：`[Bridge]`, `[DB]`, `[SEND]`
6. 关键桥接方法加 `#[tracing::instrument]` 自动生成 span

### 跨语言边界
1. Dart 不直接操作 IM 数据库，所有 IM 操作通过 Rust API
2. Rust 类型加 `#[serde(rename_all = "camelCase")]` 匹配 Dart 命名
3. 事件流用 `StreamSink<T>` 转发，Dart 侧接收 `Stream<T>`
4. 文件路径传 `String`，Rust 侧解析为 `PathBuf`

## 文件创建位置

| 类型 | 位置 | 示例 |
|------|------|------|
| 页面 | `lib/screens/` | `chat_screen.dart` |
| 组件 | `lib/widgets/` | `message_bubble.dart` |
| 服务 | `lib/services/` | `auth_service.dart` |
| Provider | `lib/providers/` | `user_provider.dart` |
| 模型 | `lib/models/` | `user.dart` |
| Rust API | `rust/src/api/` | `bridge_client.rs` |
| Rust 核心 | `rust/src/core/` | `connection/manager.rs` |
| Rust 领域 | `rust/src/domain/` | `model/message.rs` |
| Rust 基础设施 | `rust/src/infra/` | `database/message_dao.rs` |

## Rust 目录组织约定

### 分层原则
rust/src/
- domain/     # 领域层（最底层，无内部依赖）
- infra/      # 基础设施（依赖 domain）
- event/      # 事件系统（依赖 domain + openim_protocol（外部 crate））
- core/       # 核心业务（依赖 domain + infra + event）
- sdk/        # SDK 门面（依赖 core）
- api/        # FFI 桥接（最上层，依赖 sdk, 供 frb_generated 使用）
- listener/   # 监听器适配器（与 event/ 配合）

### 目录规则
1. 单文件优先：模块只有 1-2 个文件时用单文件，超过 4-5 个才建目录
2. 工具归 infra：工具类代码（bitmap, md5, progress_reader, cb 等）放在 infra/，不放在 core/
3. domain/constant/ 和 domain/error/ 保持目录：因为 frb_generated 自动生成代码依赖 domain::constant::enums:: 和 domain::error::types:: 路径，不可扁平化。通过 mod.rs 中的 pub use enums::*; pub use types::*; 提供新旧路径兼容
4. api/bridge_client.rs 不可删除：frb_generated 自动生成代码依赖此模块作为 re-export 枢纽
5. api/simple.rs 保留为向后兼容 shim：重命名后保留一个 pub use super::ffi_init::*; 的 shim 文件
6. core/file/ 只保留业务逻辑：uploader.rs 是核心业务，其他工具类移入 infra/file/
7. 协议类型统一使用外部 openim-protocol crate（path = ../../protocol）；本地不再有 protocol/ 模块，WS 帧类型与压缩器在 core/connection/ws.rs

### 各层职责
| 层 | 职责 | 不允许 |
|----|------|--------|
| domain/ | 数据模型、错误类型、常量、Repository trait | 不依赖任何其他 crate 模块 |
| infra/ | 数据库 DAO、HTTP 客户端、缓存、日志、文件工具 | 不依赖 core/、sdk/ |
| core/ | 连接管理、消息收发、会话/好友/群组业务逻辑 | 不依赖 api/、sdk/ |
| sdk/ | OpenIMClient 门面，聚合 core 各模块 | 不依赖 api/ |
| api/ | FFI 桥接，#[flutter_rust_bridge::frb] 注解 | 不依赖 core/ 内部细节 |



## IM 协议要点

- **WebSocket** (10001)：实时推送、RPC
- **HTTP REST** (10002)：CRUD 操作
- **ContentType**：Text=101, Picture=102, Sound=103, Video=104, File=105, Quote=114, Typing=113
- **SessionType**：SingleChat=1, WriteGroupChat=2, ReadGroupChat=3
- **消息流**：发送→protobuf→WebSocket；接收→MessageBatcher→MessageHandler→SQLite→事件→Dart

## 命名规范

| 语言 | 文件 | 类/结构体 | 函数/方法 | 常量 |
|------|------|-----------|-----------|------|
| Dart | `snake_case.dart` | `PascalCase` | `camelCase` | `kCamelCase` |
| Rust | `snake_case.rs` | `PascalCase` | `snake_case` | `SCREAMING` |

## 提交规范

- 格式：`type: 中文描述`
- 类型：`feat`, `fix`, `refactor`, `debug`, `log`, `docs`, `test`, `chore`

## 提交前检查

- [ ] `flutter analyze` 无警告
- [ ] `cargo clippy` 无警告
- [ ] 相关测试通过
- [ ] 修改 Dart 模型后运行 `dart run build_runner build`
- [ ] 修改 Rust API 后运行 `flutter_rust_bridge_codegen generate`