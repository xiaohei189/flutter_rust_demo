# 📐 项目架构说明

> ⚠️ **【已过时】本文档为早期骨架说明（setState、screens/widgets 结构、Rust 可选），与当前代码不符。**
> 请以 **[docs/architecture.md](docs/architecture.md)** 为准（当前架构：Riverpod 状态管理 + `data/domain/ui` 分层 + feature-first 目录，Rust SDK 完整实现）。
> 保留本文档仅为历史参考，勿按此修改代码。

## 整体架构

```
┌─────────────────────────────────────────────┐
│           Flutter 聊天应用架构               │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│              Presentation Layer             │
│  ┌────────┐  ┌────────┐  ┌────────┐        │
│  │ 聊天页 │  │联系人页│  │个人中心│        │
│  └────────┘  └────────┘  └────────┘        │
│         ↑          ↑          ↑             │
│         └──────────┴──────────┘             │
│                    │                        │
│            ┌───────┴───────┐                │
│            │  MainScreen   │                │
│            │ (底部导航栏)   │                │
│            └───────────────┘                │
└─────────────────────────────────────────────┘
                     ↕
┌─────────────────────────────────────────────┐
│             Widget Layer                    │
│  ┌─────────────┐  ┌─────────────┐          │
│  │ MessageBubble│  │  ChatInput  │          │
│  └─────────────┘  └─────────────┘          │
│  ┌─────────────┐                            │
│  │ChatListItem │                            │
│  └─────────────┘                            │
└─────────────────────────────────────────────┘
                     ↕
┌─────────────────────────────────────────────┐
│              Data Layer                     │
│  ┌────────┐  ┌─────────┐  ┌──────┐         │
│  │  User  │  │ Message │  │ Chat │         │
│  │ Model  │  │  Model  │  │Model │         │
│  └────────┘  └─────────┘  └──────┘         │
└─────────────────────────────────────────────┘
                     ↕
┌─────────────────────────────────────────────┐
│            Backend (Future)                 │
│  ┌────────────────────────────────┐         │
│  │      Rust Backend (可选)       │         │
│  │  - WebSocket 实时消息          │         │
│  │  - 消息加密                    │         │
│  │  - 数据库操作                  │         │
│  └────────────────────────────────┘         │
└─────────────────────────────────────────────┘
```

## 📂 目录结构详解

```
lib/
│
├── main.dart                     # 应用入口，初始化配置
│   ├── main()                   # 主函数，初始化 RustLib
│   └── MyApp                    # 根组件，配置主题和路由
│
├── 📁 models/                   # 数据模型层
│   ├── user.dart                # 用户数据模型
│   │   ├── User                 # 用户类
│   │   ├── currentUser          # 当前用户（模拟）
│   │   └── mockUsers            # 模拟用户列表
│   │
│   ├── message.dart             # 消息数据模型
│   │   ├── MessageType          # 消息类型枚举
│   │   └── Message              # 消息类
│   │
│   └── chat.dart                # 聊天会话模型
│       ├── Chat                 # 聊天会话类
│       └── mockChats            # 模拟聊天列表
│
├── 📁 screens/                  # 页面层（视图）
│   ├── main_screen.dart         # 主框架页面
│   │   └── MainScreen           # 包含底部导航栏的主页面
│   │       ├── ChatListScreen   
│   │       ├── ContactsScreen   
│   │       └── ProfileScreen    
│   │
│   ├── chat_list_screen.dart    # 聊天列表页
│   │   └── ChatListScreen       # 显示所有聊天会话
│   │       └── ChatListItem (widget)
│   │
│   ├── chat_detail_screen.dart  # 聊天详情页
│   │   └── ChatDetailScreen     # 单个聊天的详细界面
│   │       ├── MessageBubble (widget)
│   │       └── ChatInput (widget)
│   │
│   ├── contacts_screen.dart     # 联系人页
│   │   └── ContactsScreen       # 显示好友列表
│   │
│   └── profile_screen.dart      # 个人中心页
│       └── ProfileScreen        # 用户信息和设置
│
├── 📁 widgets/                  # 通用组件层
│   ├── chat_list_item.dart      # 聊天列表项组件
│   │   └── ChatListItem         # 单个聊天会话的列表项
│   │       ├── 头像显示
│   │       ├── 在线状态
│   │       ├── 最后消息
│   │       └── 未读数量
│   │
│   ├── message_bubble.dart      # 消息气泡组件
│   │   └── MessageBubble        # 单条消息的气泡样式
│   │       ├── 左右对齐
│   │       ├── 颜色区分
│   │       └── 时间显示
│   │
│   └── chat_input.dart          # 聊天输入框组件
│       └── ChatInput            # 多功能输入框
│           ├── 文本输入
│           ├── 语音按钮
│           ├── 更多功能
│           └── 发送按钮
│
├── 📁 theme/                    # 主题配置层
│   └── app_theme.dart           # 应用主题
│       └── AppTheme             # 主题配置类
│           ├── 颜色定义
│           ├── 文字样式
│           └── lightTheme
│
└── 📁 generated/rust/           # Rust 桥接（已有）
    └── ...                      # flutter_rust_bridge 生成的代码
```

## 🔄 数据流

### 1. 消息发送流程

```
用户输入
   ↓
ChatInput 组件捕获
   ↓
ChatDetailScreen 处理
   ↓
创建 Message 对象
   ↓
更新 State (setState)
   ↓
ListView 刷新显示
   ↓
自动滚动到底部
   ↓
(未来) 发送到 Rust 后端
   ↓
(未来) WebSocket 推送到服务器
```

### 2. 页面导航流程

```
MainScreen (底部导航)
   ├─ 点击聊天 Tab → ChatListScreen
   │      ↓
   │   点击聊天项
   │      ↓
   │   Navigator.push → ChatDetailScreen
   │
   ├─ 点击联系人 Tab → ContactsScreen
   │
   └─ 点击我的 Tab → ProfileScreen
```

### 3. 状态管理（当前）

```
┌─────────────────────┐
│  StatefulWidget     │
│  ├─ State          │
│  └─ setState()     │
└─────────────────────┘
         ↓
   局部状态更新
         ↓
    UI 重新渲染
```

**注意**：当前使用基础的 `setState`，建议后续使用 Provider/Riverpod 进行全局状态管理。

## 🎯 组件职责

### Screens（页面）
- 负责页面级别的布局
- 处理用户交互逻辑
- 管理页面状态
- 协调多个 Widget

### Widgets（组件）
- 负责单一功能的 UI 展示
- 可复用的通用组件
- 接收参数配置
- 发送事件回调

### Models（模型）
- 定义数据结构
- 提供模拟数据
- 数据转换和处理
- 业务逻辑封装

### Theme（主题）
- 统一颜色定义
- 统一样式配置
- 支持主题切换
- Material Design 3 配置

## 🚀 扩展建议

### 1. 状态管理集成

```dart
// 推荐使用 Riverpod
lib/
├── providers/
│   ├── chat_provider.dart
│   ├── user_provider.dart
│   └── message_provider.dart
```

### 2. 网络层

```dart
lib/
├── services/
│   ├── api_service.dart       // REST API
│   ├── websocket_service.dart // WebSocket
│   └── auth_service.dart      // 认证
```

### 3. 数据持久化

```dart
lib/
├── repositories/
│   ├── chat_repository.dart
│   ├── user_repository.dart
│   └── message_repository.dart
```

### 4. 路由管理

```dart
lib/
├── routes/
│   ├── app_router.dart        // 路由配置
│   └── route_names.dart       // 路由常量
```

### 5. 工具类

```dart
lib/
├── utils/
│   ├── date_formatter.dart
│   ├── validators.dart
│   └── constants.dart
```

## 🔌 Rust 集成架构

```
Flutter (Dart)
      ↕
flutter_rust_bridge
      ↕
Rust (Native)
   ├── WebSocket 客户端
   ├── 消息加密/解密
   ├── 本地数据库 (SQLite)
   └── 高性能计算
```

## 📊 性能优化建议

1. **ListView.builder**: 已使用，支持懒加载
2. **const 构造函数**: 减少重建
3. **图片缓存**: 使用 `cached_network_image`
4. **消息分页**: 实现历史消息加载
5. **内存管理**: 及时 dispose 控制器

## 🧪 测试策略

```
tests/
├── unit/                 # 单元测试
│   ├── models/
│   └── utils/
├── widget/               # 组件测试
│   ├── widgets/
│   └── screens/
└── integration/          # 集成测试
    └── app_test.dart
```

## 📱 多平台支持

当前架构支持：
- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 🎨 设计模式

- **单一职责原则**: 每个组件负责单一功能
- **组件化**: 通用组件独立封装
- **数据驱动**: UI 由数据状态决定
- **分层架构**: 展示层、业务层、数据层分离

---

**该架构为初始骨架，可根据实际需求扩展和优化。**


