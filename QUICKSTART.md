# 🚀 快速启动指南

## 前置条件

确保已安装：
- Flutter SDK (3.9.2 或更高版本)
- Android Studio / Xcode（用于模拟器）
- Git

## 启动步骤

### 1. 检查 Flutter 环境

```bash
flutter doctor
```

确保所有检查项都通过（至少有一个平台可用）。

### 2. 安装依赖

```bash
cd /c/Users/11456/workspace/flutter_rust_demo
flutter pub get
```

### 3. 启动模拟器

#### 方式 A：使用命令行

```bash
# 查看可用模拟器
flutter emulators

# 启动 Android 模拟器
flutter emulators --launch <模拟器ID>
```

#### 方式 B：使用 VSCode

1. 打开 VSCode
2. 按 `F5` 或点击 "Run and Debug"
3. 选择 "Flutter (Android)" 配置
4. VSCode 会自动选择可用设备

#### 方式 C：使用 Android Studio

1. 打开 Android Studio
2. Tools → AVD Manager
3. 点击绿色三角按钮启动模拟器

### 4. 运行应用

```bash
# 自动选择可用设备
flutter run

# 或指定设备
flutter run -d <设备ID>

# 查看已连接设备
flutter devices
```

### 5. VSCode 调试（推荐）

项目已配置好 VSCode 调试配置（`.vscode/launch.json`）：

1. 启动模拟器或连接真机
2. 按 `F5` 开始调试
3. 或使用 VSCode 左侧 "Run and Debug" 面板

可用的调试配置：
- **Flutter (Android)**: 标准 Android 调试
- **Flutter (Android Debug)**: 显式 debug 模式
- **Flutter (Android Profile)**: 性能分析模式

## 🎯 功能测试

### 测试聊天列表
1. 应用启动后默认显示聊天列表
2. 可以看到 3 个模拟聊天会话
3. 点击任意会话进入聊天详情

### 测试聊天功能
1. 在聊天详情页底部输入消息
2. 点击发送按钮
3. 2 秒后会收到模拟回复

### 测试更多功能
1. 点击输入框右侧的 "+" 按钮
2. 查看相册、拍照、文件等选项
3. 点击顶部导航栏的电话/视频图标

### 测试底部导航
1. 点击底部 "联系人" 查看好友列表
2. 点击底部 "我的" 查看个人中心
3. 返回 "聊天" 标签

## 🐛 常见问题

### Q1: 模拟器启动失败
```bash
# 重新创建 AVD
flutter emulators --create

# 或使用 Android Studio AVD Manager 手动创建
```

### Q2: 依赖安装失败
```bash
# 清除缓存重新安装
flutter clean
flutter pub get
```

### Q3: Rust 相关错误
```bash
# 如果遇到 Rust 编译问题，确保 Rust 环境正确
rustc --version

# 重新构建 Rust 部分
cd rust
cargo build
```

### Q4: 网络图片无法加载
- 模拟器需要网络连接
- 检查网络设置或使用本地图片替换

### Q5: 热重载不生效
- 按 `r` 进行热重载
- 按 `R` 进行热重启
- 或在 VSCode 中使用工具栏按钮

## 📱 在真机上运行

### Android
1. 开启手机的开发者选项
2. 启用 USB 调试
3. 连接手机到电脑
4. 运行 `flutter devices` 确认手机被识别
5. 运行 `flutter run`

### iOS (需要 macOS)
1. 在 Xcode 中配置签名
2. 连接 iPhone
3. 信任开发者证书
4. 运行 `flutter run`

## 🔥 热重载快捷键

- **r**: 热重载（保持应用状态）
- **R**: 热重启（重置应用状态）
- **h**: 显示帮助
- **q**: 退出应用
- **o**: 切换平台亮度模式
- **p**: 显示网格线
- **w**: 显示 widget 检查器

## 📊 性能分析

```bash
# 以 profile 模式运行
flutter run --profile

# 或使用 VSCode 的 "Flutter (Android Profile)" 配置
```

## 🎨 自定义修改建议

1. **修改主题色**：编辑 `lib/theme/app_theme.dart`
2. **添加新页面**：在 `lib/screens/` 中创建新文件
3. **添加新组件**：在 `lib/widgets/` 中创建新文件
4. **修改模拟数据**：编辑 `lib/models/` 中的静态数据

## 📚 学习资源

- [Flutter 官方文档](https://flutter.dev/docs)
- [Dart 语言指南](https://dart.dev/guides)
- [Material Design 3](https://m3.material.io/)
- [flutter_rust_bridge 文档](https://cjycode.com/flutter_rust_bridge/)

---

**祝您开发愉快！🎉**



