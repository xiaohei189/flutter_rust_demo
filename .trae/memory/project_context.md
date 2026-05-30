# 项目上下文

## 项目基本信息

- **项目名称**: flutter_rust_demo
- **项目类型**: 跨平台 IM 应用（Rust + Flutter）
- **主要用途**: 实现 OpenIM SDK 的 Rust 版本，提供 Flutter 前端界面
- **开发状态**: 进行中

## 技术栈

### 核心框架
- **Flutter**: 跨平台 UI 框架
- **Rust**: 后端逻辑和 IM SDK 实现
- **flutter_rust_bridge**: v2.11.1（FFI 通信）

### Rust 依赖
- **tokio**: 异步运行时
- **sqlx**: 数据库访问（SQLite）
- **anyhow**: 错误处理
- **serde**: 序列化/反序列化
- **tracing**: 日志系统
- **prost**: Protobuf 序列化

### Flutter 依赖
- **Riverpod**: 状态管理
- **GoRouter**: 路由管理
- **freezed**: 不可变数据类生成
- **json_serializable**: JSON 序列化

## 项目目标

### 短期目标
1. 完成 IM SDK 核心功能实现（对齐 Go 版本）
2. 实现基础聊天功能（消息收发、会话管理）
3. 完成用户认证和好友管理
4. 实现群组功能

### 中期目标
1. 实现消息同步和离线消息处理
2. 添加文件上传下载功能
3. 实现音视频通话
4. 优化性能和用户体验

### 长期目标
1. 支持多平台（iOS、Android、Web、Desktop）
2. 实现完整的 OpenIM SDK 功能
3. 提供完善的文档和示例

## 相关项目参考

| 项目路径 | 说明 | 用途 |
|---------|------|------|
| `D:\workspace\openim-docker` | Docker 服务配置 | 本地开发环境 |
| `D:\workspace\chat-server` | 应用服务源码 | 后端参考 |
| `D:\workspace\open-im-server` | IM 服务源码（Go） | 服务端参考 |
| `D:\workspace\openim-sdk-core` | Go 版本 SDK | **主要参考实现** |
| `D:\workspace\openim-flutter-demo` | 官方 Flutter 示例 | UI/交互参考 |

## 架构设计

### 整体架构
```
Flutter UI (Dart)
    ↓ ↑ (FFI via flutter_rust_bridge)
Rust SDK (lib.rs)
    ↓
IM Core (client.rs)
    ↓
├── HTTP Client (API 调用)
├── WebSocket (长连接)
├── SQLite (本地存储)
└── Syncer (数据同步)
```

### 模块职责

| 模块 | 路径 | 职责 |
|------|------|------|
| FFI 桥接 | `rust/src/api/bridge_*.rs` | 导出 Rust 函数给 Flutter |
| 客户端核心 | `rust/src/im/client/client.rs` | IM 核心逻辑 |
| 连接管理 | `rust/src/im/client/connection_handle.rs` | WebSocket 连接 |
| 消息处理 | `rust/src/im/client/message_handle.rs` | 消息同步 |
| 会话处理 | `rust/src/im/client/conversation_handle.rs` | 会话同步 |
| 数据访问 | `rust/src/im/dao/` | SQLite 操作 |
| HTTP 客户端 | `rust/src/im/http_client/` | API 调用 |
| 数据模型 | `rust/src/im/model/` | 数据结构定义 |

## 开发约定

详见 [project_rules.md](./rules/project_rules.md)

### 关键约定摘要
1. FFI 函数使用 `#[flutter_rust_bridge::frb]` 注解
2. 异步函数正确处理 `RwLock` 生命周期
3. 错误统一使用 `anyhow::Result<T>`
4. 参考 Go SDK 实现保持接口一致

## 当前进度

### 已完成
- [x] 项目结构搭建
- [x] FFI 桥接层基础
- [x] 数据库迁移和 DAO 层
- [x] HTTP 客户端实现
- [x] 连接管理基础
- [x] 好友管理功能
- [x] 群组管理功能
- [x] 在线状态模块

### 进行中
- [ ] 消息收发完整实现
- [ ] 会话同步优化
- [ ] 事件监听系统

### 待开始
- [ ] 文件上传下载
- [ ] 音视频通话
- [ ] 推送通知

## 常见问题

### 编译错误
1. **RwLock 生命周期问题**: 避免在 guard 持有期间 await
2. **类型不匹配**: FRB 函数参数用 String，调用时转 &str

### 开发流程
1. 修改 Rust 代码 → `cargo check`
2. 生成 FFI 绑定 → `flutter_rust_bridge_codegen`
3. 运行 Flutter → `flutter run`

## 联系方式

- 开发者: [待补充]
- 项目仓库: [待补充]
