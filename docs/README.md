# 📖 Flutter Rust Demo — 文档总入口

> 本项目是基于 **Flutter + Rust**（flutter_rust_bridge）的 **OpenIM 即时通讯客户端**。
> 本文档是全部项目文档的唯一入口，按用途组织；根目录 [README.md](../README.md) 也指向这里。

---

## 🚀 快速上手

| 文档 | 说明 |
|------|------|
| [QUICKSTART.md](../QUICKSTART.md) | 环境准备（Flutter / Rust / OpenIM Server）与运行步骤 |
| [CHAT_APP_README.md](../CHAT_APP_README.md) | Flutter 聊天应用骨架、目录结构与 UI 组件说明 |
| [openim_demo功能清单报告.md](../openim_demo功能清单报告.md) | 已实现功能与 Go SDK 的完整对比清单 |

## 🏗️ 架构总览

| 文档 | 说明 |
|------|------|
| [项目架构以及规划信息.md](../项目架构以及规划信息.md) | 项目概览、技术选型与整体规划 |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | 整体架构说明 |
| [docs/architecture.md](./architecture.md) | **Rust SDK 架构与数据流（当前实现为准）** |
| [rust/ARCHITECTURE.md](../rust/ARCHITECTURE.md) | Rust 分层架构指南 |
| [rust/SDK_ARCHITECTURE_REDESIGN.md](../rust/SDK_ARCHITECTURE_REDESIGN.md) | SDK 重构设计文档（历史参考，92KB） |
| [rust/SDK_IMPLEMENTATION_PLAN.md](../rust/SDK_IMPLEMENTATION_PLAN.md) | SDK 实施计划（历史参考） |

## 📚 SDK 模块规范（docs/sdk-spec/）

规范全集共 17 个文档，**从 [INDEX.md](./sdk-spec/INDEX.md) 进入**：

| 分组 | 文档 | 内容 |
|------|------|------|
| 全局 | [00-OVERVIEW](./sdk-spec/00-OVERVIEW.md) | 系统全景、分层、数据流、功能清单 |
| 连接 | [01-CONNECTION](./sdk-spec/01-CONNECTION.md) | WebSocket、心跳、重连、RPC |
| 消息 | [02-MESSAGE-SYNC](./sdk-spec/02-MESSAGE-SYNC.md) [03-MESSAGE-HANDLER](./sdk-spec/03-MESSAGE-HANDLER.md) [04-MESSAGE-SENDER](./sdk-spec/04-MESSAGE-SENDER.md) | 同步 / 入库 / 发送 |
| 会话 | [05-CONVERSATION](./sdk-spec/05-CONVERSATION.md) | 会话 CRUD、已读、撤回/删除 |
| 通知 | [06-NOTIFICATION](./sdk-spec/06-NOTIFICATION.md) | 通知路由（41 种） |
| 业务 | [07-FRIEND](./sdk-spec/07-FRIEND.md) [08-GROUP](./sdk-spec/08-GROUP.md) [09-USER](./sdk-spec/09-USER.md) | 好友 / 群组 / 用户 |
| 参考 | [10-CONSTANTS](./sdk-spec/10-CONSTANTS.md) [11-DATA-MODELS](./sdk-spec/11-DATA-MODELS.md) [12-HTTP-API](./sdk-spec/12-HTTP-API.md) [13-SYNCER-FRAMEWORK](./sdk-spec/13-SYNCER-FRAMEWORK.md) | 常量 / 模型 / HTTP API / 同步器框架 |
| 生命周期 | [14-SDK-LIFECYCLE](./sdk-spec/14-SDK-LIFECYCLE.md) | Login / Logout / Token |
| 桥接 | [15-FFI-BRIDGE](./sdk-spec/15-FFI-BRIDGE.md) | FFI 函数与 Go SDK API 对照 |
| 事件 | [16-LISTENERS](./sdk-spec/16-LISTENERS.md) | **6 个 Listener trait 回调体系（最新）** |

## 📋 开发规范与进度

| 文档 | 说明 |
|------|------|
| [docs/conventions.md](./conventions.md) | 命名 / 目录 / 提交等编码规范 |
| [docs/SDK_PROGRESS.md](./SDK_PROGRESS.md) | SDK 模块实现进度与缺口 |
| [docs/ui-optimization-plan.md](./ui-optimization-plan.md) | UI 与目录组织优化计划 |

## 🔬 专项实现说明

| 文档 | 说明 |
|------|------|
| [MESSAGE_LOADING_IMPLEMENTATION.md](../MESSAGE_LOADING_IMPLEMENTATION.md) | 消息加载实现（对照 Go SDK） |
| [FILE_UPLOAD_IMPLEMENTATION.md](../FILE_UPLOAD_IMPLEMENTATION.md) | 文件/头像上传实现 |
| [AVATAR_UPDATE.md](../AVATAR_UPDATE.md) | 头像系统更新说明 |
| [RUST_API_IMPLEMENTATION.md](../RUST_API_IMPLEMENTATION.md) | Rust API 与 Go SDK 对照 |
| [docs/go_ws_message_handling.md](./go_ws_message_handling.md) | Go SDK WebSocket 消息处理链路 |
| [docs/message_flow_analysis.md](./message_flow_analysis.md) | 消息收发全链路分析 |

## 🧭 推荐阅读顺序

- **新人上手**：QUICKSTART → 项目架构以及规划信息 → sdk-spec/00-OVERVIEW → sdk-spec/16-LISTENERS
- **开发/改 SDK**：docs/architecture.md → rust/ARCHITECTURE.md → sdk-spec/INDEX.md（按需查模块）
- **了解现状**：docs/SDK_PROGRESS.md + sdk-spec/00-OVERVIEW 实施状态

---

> 文档版本：2026-08-02 · 维护提示：涉及事件体系的内容请以 16-LISTENERS.md 为准（旧 EventBus/SdkEvent 描述已废弃）。
