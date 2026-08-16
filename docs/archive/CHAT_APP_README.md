# Flutter 聊天应用骨架

这是一个基于 Flutter 构建的移动端聊天应用骨架，包含完整的基础架构和 UI 组件。

## 📁 项目结构

```
lib/
├── main.dart                      # 应用入口
├── models/                        # 数据模型
│   ├── user.dart                  # 用户模型
│   ├── message.dart               # 消息模型
│   └── chat.dart                  # 聊天会话模型
├── screens/                       # 页面
│   ├── main_screen.dart           # 主页面（底部导航栏）
│   ├── chat_list_screen.dart      # 聊天列表页
│   ├── chat_detail_screen.dart    # 聊天详情页
│   ├── contacts_screen.dart       # 联系人页
│   └── profile_screen.dart        # 个人中心页
├── widgets/                       # 通用组件
│   ├── chat_list_item.dart        # 聊天列表项
│   ├── message_bubble.dart        # 消息气泡
│   └── chat_input.dart            # 聊天输入框
└── theme/                         # 主题配置
    └── app_theme.dart             # 应用主题
```

## 🎨 功能特性

### ✅ 已实现
- **底部导航栏**：聊天、联系人、个人中心三个标签
- **聊天列表页**：显示所有聊天会话，包含未读消息数量
- **聊天详情页**：完整的聊天界面，包含消息气泡和输入框
- **联系人页**：显示好友列表和在线状态
- **个人中心页**：用户信息和设置入口
- **消息气泡组件**：支持左右对齐，显示时间戳
- **聊天输入框**：文本输入、语音、更多功能（相册、拍照、文件等）
- **模拟数据**：包含完整的模拟用户、消息、聊天数据

### 🚀 待扩展功能
- [ ] 实时消息推送（WebSocket）
- [ ] 图片/视频/文件发送
- [ ] 语音/视频通话
- [ ] 表情包支持
- [ ] 消息已读/未读状态
- [ ] 群聊功能
- [ ] 消息搜索
- [ ] 本地数据持久化
- [ ] 用户认证与登录
- [ ] 后端 API 集成（可以使用 Rust 作为后端）

## 🎯 核心组件说明

### 1. 数据模型

#### User（用户）
```dart
- id: 用户 ID
- name: 用户名
- avatar: 头像 URL（可选，支持网络图片）
- avatarColor: 头像背景颜色（离线头像）
- avatarIcon: 头像图标（离线头像）
- status: 在线状态（在线/离线）
```

**头像系统**：应用使用不依赖网络的头像系统，支持彩色图标头像、首字母头像和网络图片三种方式。详见 `AVATAR_UPDATE.md`。

#### Message（消息）
```dart
- id: 消息 ID
- senderId: 发送者 ID
- content: 消息内容
- type: 消息类型（文本/图片/语音等）
- timestamp: 发送时间
- isSent: 是否已发送
```

#### Chat（聊天会话）
```dart
- id: 会话 ID
- user: 聊天对象
- lastMessage: 最后一条消息
- unreadCount: 未读消息数
- lastMessageTime: 最后消息时间
```

### 2. 页面组件

#### MainScreen
- 主框架页面，包含底部导航栏
- 使用 `IndexedStack` 保持各页面状态

#### ChatListScreen
- 显示所有聊天会话
- 支持点击进入聊天详情

#### ChatDetailScreen
- 完整的聊天界面
- 消息列表自动滚动到底部
- 支持发送消息和模拟回复

#### ContactsScreen
- 联系人列表
- 显示在线状态

#### ProfileScreen
- 个人信息展示
- 设置入口

### 3. 通用组件

#### MessageBubble
- 消息气泡组件
- 自动区分发送者和接收者
- 显示时间戳和头像

#### ChatInput
- 多功能输入框
- 支持文本输入、语音、更多功能
- 底部弹出更多选项（相册、拍照、文件等）

#### ChatListItem
- 聊天列表项
- 显示头像、名称、最后消息、时间、未读数

## 🎨 主题配置

在 `lib/theme/app_theme.dart` 中定义了应用的主题色：

```dart
- primaryColor: 主题色（蓝色）
- myMessageColor: 自己的消息气泡颜色
- otherMessageColor: 对方的消息气泡颜色
- backgroundColor: 背景色
```

可以根据需要自定义主题。

## 🔧 技术栈

- **Flutter**: 跨平台 UI 框架
- **Material Design**: 使用 Material 3 组件
- **intl**: 日期时间格式化
- **flutter_rust_bridge**: Flutter 与 Rust 通信（可用于后端逻辑）

## 🚀 运行应用

```bash
# 安装依赖
flutter pub get

# 运行应用（iOS）
flutter run -d ios

# 运行应用（Android）
flutter run -d android

# 运行应用（Web）
flutter run -d chrome
```

## 📱 屏幕截图说明

应用包含以下主要界面：

1. **聊天列表**：显示所有会话，带有未读消息提醒
2. **聊天详情**：完整的聊天界面，消息气泡样式
3. **联系人**：好友列表，在线状态显示
4. **个人中心**：用户信息和设置入口

## 🔌 集成 Rust 后端（可选）

项目已集成 `flutter_rust_bridge`，可以使用 Rust 实现：

- 消息加密/解密
- 本地数据库操作
- WebSocket 连接管理
- 高性能数据处理

## 📝 下一步开发建议

1. **集成状态管理**：推荐使用 Provider、Riverpod 或 Bloc
2. **添加数据持久化**：使用 Hive 或 sqflite 保存聊天记录
3. **实现网络请求**：使用 Dio 与后端 API 通信
4. **添加 WebSocket**：实现实时消息推送
5. **优化 UI/UX**：添加加载状态、错误处理、动画效果
6. **添加测试**：单元测试和集成测试

## 📄 许可证

MIT License

## 👨‍💻 作者

Flutter + Rust 混合开发示例项目

---

**注意**：当前使用的是模拟数据，实际开发中需要替换为真实的后端 API 和数据库。

