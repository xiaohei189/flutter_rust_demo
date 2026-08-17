# 编码规范

## 文件命名

| 语言 | 文件 | 文件夹 |
|------|------|--------|
| Dart | `snake_case.dart` | `snake_case` |
| Rust | `snake_case.rs` | `snake_case` |

**特殊命名**：
- 页面：`xxx_screen.dart`（如 `chat_list_screen.dart`）
- Provider：`xxx_provider.dart`（如 `conversation_provider.dart`）
- 服务：`xxx_service.dart`（如 `connection_service.dart`）
- 模型：描述性名称（如 `chat.dart`, `user.dart`）

## Dart 规范

### 类命名

| 类型 | 后缀 | 示例 |
|------|------|------|
| 页面 | - | `ChatListScreen`, `LoginScreen` |
| Widget 组件 | - | `MessageBubble`, `UserAvatar` |
| State 类 | `State` | `ConversationListState` |
| Notifier | `Notifier` | `ConversationListNotifier` |
| Extension | `Ext` / `Extensions` | `MessageInfoExt`, `UserExtensions` |

### 变量命名

- 全局常量：`k` 前缀 camelCase（如 `kWsUrl`, `kApiBaseUrl`）
- 私有字段/方法：`_` 前缀（如 `_ref`, `_client`, `_init()`）
- 一般变量/方法/参数：`camelCase`

### Freezed 模型

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

@freezed
class Chat with _$Chat {
  const factory Chat({
    required String id,
    required String name,
    String? avatar,
    required bool isGroup,
    required int unreadCount,
    required String lastMessage,
    required DateTime lastMessageTime,
  }) = _Chat;

  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);
}
```

规则：
- `const factory` 构造函数，`required` 标记必填字段
- 始终声明 `factory fromJson`
- 修改后运行 `dart run build_runner build`
- 可在同文件定义 Extension 添加便捷方法

### Riverpod Provider

标准文件结构：

```dart
// 1. State 类（不可变，copyWith）
class XxxState {
  final bool isLoading;
  final String? error;
  const XxxState({this.isLoading = false, this.error});
  XxxState copyWith({bool? isLoading, String? error}) =>
      XxxState(isLoading: isLoading ?? this.isLoading, error: error);
}

// 2. Notifier 类
class XxxNotifier extends StateNotifier<XxxState> {
  final Ref _ref;
  XxxNotifier(this._ref) : super(const XxxState());
}

// 3. Provider
final xxxProvider = StateNotifierProvider<XxxNotifier, XxxState>((ref) {
  return XxxNotifier(ref);
});
```

命名约定：
- 主 Provider：`xxxProvider`（如 `conversationListProvider`）
- 派生 Provider：`xxxProvider` 带描述（如 `conversationsProvider`, `totalUnreadCountProvider`）
- Family Provider：`xxxByIdProvider`（如 `conversationByIdProvider`）

### Widget 模式

- 需要 `ref` 和生命周期的页面 → `ConsumerStatefulWidget`
- 纯渲染组件 → `StatelessWidget`
- 始终使用 `super.key` 和 `const` 构造函数
- `initState` / `dispose` 管理 Timer/Subscription
- 异步操作后检查 `mounted`

### Repository / ViewModel 模式

- Repository 位于 `lib/data/repositories/`，消费 Service，负责缓存、重试和 API 模型到领域模型的转换。
- ViewModel 位于 `lib/ui/<feature>/view_models/`，通过构造函数注入 Repository，只暴露不可变状态和命令方法。
- View 只负责渲染和路由/交互反馈，不直接访问 FFI client 或 Service。
- Provider 只做依赖注册和状态桥接，不在 Provider 中实现数据获取。
- Service 使用抽象接口 + 单例实现（如 `FriendService` / `FriendServiceImpl`），Repository 依赖接口以便单测注入 fake。

### 架构边界（强制）

依赖方向固定为 `UI (lib/ui) -> Domain (lib/domain) -> Data (lib/data) -> generated/rust`，任何一层都不允许反向 import：

- `lib/data` 与 `lib/domain` 禁止 import `lib/ui/` 或 `lib/providers/`；日志等基础工具放在 `lib/core/`，不能放在 `lib/ui/core/`。
- `lib/ui` 与 `lib/providers` 禁止 import `generated/rust/ffi/` 和 `generated/rust/client/`；FFI 调用统一收口到 Service/Repository。
- View/ViewModel 只能依赖 Repository/Provider；禁止在 View 内直接调用 `uploadFile`、`sendMergerMessage`、`sendTyping` 等 FFI 函数。
- 同一领域只保留一个状态源（如 `ConnectionService`、`ConversationListProvider`），其他 Provider 通过 `select` 派生；禁止创建并行的双轨 Provider。
- 业务 Service 必须提供抽象接口 + 实现，并由 Riverpod Provider 持有实例；业务代码禁止直接访问 `X.instance`。
- Repository 对外返回 Domain Model，禁止把 generated raw model 直接暴露给 View；存量代码逐步迁移，新增代码不得新增泄漏。

提交前用以下命令做边界回归：

```powershell
rg -n "generated/rust/(ffi|client)" lib/ui lib/providers --glob "!lib/generated/**"
rg -n "ui/core/utils/app_logger|from '\.\./ui/|from '\.\./providers/" lib/data lib/domain
```

两项都应为空（`lib/main.dart` 的 Rust 启动初始化除外）。

```dart
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});
  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}
```

### 错误处理

```dart
Future<void> refreshConversations() async {
  state = state.copyWith(isLoading: true, error: null);
  try {
    await _ref.read(messageServiceProvider.notifier).refreshConversations();
    state = state.copyWith(isLoading: false);
  } catch (e) {
    state = state.copyWith(isLoading: false, error: '刷新会话列表失败: $e');
  }
}
```

规则：
- 错误信息用中文：`'操作描述失败: $e'`
- 操作前 `error: null`
- 返回 `Future<bool>` 表示成功/失败
- 返回 `Future<T?>` 表示可能返回数据

### 主题/颜色

所有颜色从 `AppTheme` 静态常量获取，不硬编码：

```dart
color: AppTheme.primaryColor
backgroundColor: AppTheme.backgroundColor
```

### 日志

```dart
appLog.i('[ModuleName] 操作描述')
appLog.e('[ModuleName] 操作失败: $e')
appLog.d('[ModuleName] 调试信息')
```

格式：`[模块名] 描述`，模块名用英文。

## Rust 规范

### 模块组织

分层架构，每层有 `mod.rs`：

```rust
// rust/src/lib.rs
pub mod api;      // FFI 桥接层
pub mod sdk;      // SDK 入口
pub mod core;     // 业务逻辑
pub mod domain;   // 领域模型
pub mod infra;    // 基础设施
// 协议类型来自外部 openim-protocol crate，无本地 protocol 模块
```

### 命名

| 类型 | 风格 | 示例 |
|------|------|------|
| 文件 | `snake_case` | `bridge_client.rs` |
| 结构体/枚举 | `PascalCase` | `OpenIMBridgeClient`, `SdkError` |
| 函数/方法 | `snake_case` | `send_text_message` |
| 常量 | `SCREAMING_SNAKE_CASE` | `EVENT_CHANNEL_CAPACITY` |
| DAO | `XxxDao` | `MessageDao` |
| Manager | `XxxManager` | `ConnectionManager` |
| Listener | `XxxListener` | `ConversationListener` |
| Event | `XxxEvent` | `ConversationEvent` |

### 错误处理

使用 `SdkError`（`thiserror::Error`）：

```rust
#[derive(Debug, Error)]
pub enum SdkError {
    #[error("网络错误: {message}")]
    NetworkError { message: String },
    #[error("数据库错误: {message}")]
    DatabaseError { message: String },
}

pub type Result<T> = std::result::Result<T, SdkError>;
```

桥接层转换为 `anyhow::Error`：
```rust
.map_err(|e| anyhow::anyhow!("{}", e))
```

### FFI 桥接方法

```rust
#[flutter_rust_bridge::frb(opaque)]
pub struct OpenIMBridgeClient { inner: Arc<OpenIMClient> }

impl OpenIMBridgeClient {
    #[tracing::instrument(skip(self), fields(source_id = %source_id))]
    #[flutter_rust_bridge::frb]
    pub async fn send_text_message(
        &self, text: String, source_id: String, session_type: SessionType
    ) -> Result<Message> {
        self.inner.send_text_message(&text, &source_id, session_type.into()).await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }
}
```

规则：
- `pub async fn` 返回 `Result<T>`
- `#[tracing::instrument]` 标注关键方法
- `StreamSink<T>` 用于事件流

### 数据库 (sqlx)

DAO 模式：
```rust
pub struct MessageDao { pool: SqlitePool }

impl MessageDao {
    pub fn new(pool: SqlitePool) -> Self { Self { pool } }
    
    pub async fn get_by_id(&self, id: &str) -> Result<LocalChatLog> {
        sqlx::query_as::<_, LocalChatLog>("SELECT * FROM local_chat_logs WHERE ...")
            .bind(id).fetch_one(&self.pool).await
            .map_err(|e| SdkError::database(format!("query: {}", e)))
    }
}
```

模型推导 `FromRow`：
```rust
#[derive(Debug, Clone, FromRow)]
pub struct LocalChatLog {
    pub conversation_id: String,
    pub client_msg_id: String,
}
```

### 日志

```rust
// 直接使用 tracing
tracing::info!("[Bridge] 创建客户端实例, user_id={}", user_id);
tracing::error!("[Bridge] 操作失败: {}", e);

// 使用 SDK 宏
sdk_info!("收到推送消息"; "conv_id" => &conv_id);
sdk_error!("连接断开"; "error" => %e);
```

标签格式：`[模块名] 描述`（如 `[Bridge]`, `[DB]`, `[SEND]`）

### 事件系统（Listener 回调）

事件统一经 Listener trait 对外分发，SDK 内置实现为 `EventHub`（见 docs/sdk-spec/16-LISTENERS.md）：

```rust
// Service 侧：构造时注入 Listener，发布事件
self.listener.emit(ConnectionEvent::Connected);

// SDK 侧：EventHub 实现 Listener，把回调转发到领域通道
let hub = EventHub::new();
let mut rx = hub.take_conn_rx().unwrap(); // Dart stream 数据源
```

## 跨语言规范

### 类型序列化

Rust 类型必须：
```rust
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]  // 匹配 Dart 命名
```

### 文件路径

- Dart → Rust：传递 `String`，Rust 侧解析为 `PathBuf`
- 大文件使用流式接口，避免内存复制

### 异步

- Rust：所有桥接方法 `async`，tokio 运行时
- Dart：所有 Rust 调用 `await`
- 事件流：`StreamSink<T>` 转发 mpsc → Dart Stream

### 代码生成

修改 Rust API 后：
```bash
flutter_rust_bridge_codegen generate
```

## Git 规范

### 提交信息

格式：`type: 中文描述`

```
feat: ws 响应添加 tracing span 并对齐 Go SDK 分支处理
fix: Rust conversation.rs 修复误入的 Dart 代码
refactor: bridge_client 彻底移除 SdkEvent，直接用模块事件类型
debug: Rust get_conversations 加 COUNT 诊断
log: 删除 bridge 适配层日志，只保留源头 [SEND] 日志
```

类型：`feat`, `fix`, `refactor`, `debug`, `log`, `docs`, `test`, `chore`

### 分支

- 主分支：`main`
- 功能分支：`feat/xxx`（如需要）

## 分析选项

### Dart (`analysis_options.yaml`)

- `strict-casts: true`
- `strict-raw-types: true`
- `prefer_single_quotes: true`
- `prefer_const_constructors: true`
- `avoid_print: true`
- 生成代码排除：`lib/generated/rust/**`

### Rust (`rustfmt.toml`)

```toml
max_width = 200
```

### Release 构建

```toml
[profile.release]
opt-level = "z"       # 最小体积
lto = true            # 链接时优化
codegen-units = 1     # 单编译单元
strip = true          # 去除调试符号
```

## 提交前检查

- [ ] `flutter analyze` 无警告
- [ ] `cargo clippy` 无警告
- [ ] 相关测试通过
- [ ] 修改 Dart 模型后运行 `dart run build_runner build`
- [ ] 修改 Rust API 后运行 `flutter_rust_bridge_codegen generate`
