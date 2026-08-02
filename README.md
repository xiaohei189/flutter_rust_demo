# flutter_rust_demo

基于 **Flutter + Rust（flutter_rust_bridge）** 的 **OpenIM 即时通讯客户端**：IM 核心逻辑由 Rust 实现（连接、消息、会话、好友、群组、通知），Flutter 通过 FFI 调用并订阅事件流。

## 文档入口

📖 **全部文档请从 [docs/README.md](docs/README.md) 进入**（快速上手、架构、SDK 规范、进度、专项说明）。

常用文档：

- [QUICKSTART.md](QUICKSTART.md) — 环境准备与运行
- [docs/architecture.md](docs/architecture.md) — Rust SDK 架构与数据流
- [docs/sdk-spec/INDEX.md](docs/sdk-spec/INDEX.md) — SDK 模块规范全集
- [docs/sdk-spec/16-LISTENERS.md](docs/sdk-spec/16-LISTENERS.md) — Listener 回调体系
- [docs/SDK_PROGRESS.md](docs/SDK_PROGRESS.md) — 实现进度

## 技术栈

| 层 | 技术 |
|----|------|
| UI | Flutter + Riverpod + go_router |
| 桥接 | flutter_rust_bridge（FRB） |
| 核心 | Rust（tokio + sqlx/SQLite + serde + prost） |
| 服务端 | OpenIM（本地 10001/10002 端口） |

## 快速开始

见 [QUICKSTART.md](QUICKSTART.md)；Rust 核心目录为 `rust/`，单元测试：`cargo test --lib`（在 `rust/` 下执行）。